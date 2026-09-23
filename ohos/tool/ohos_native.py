"""Connect the original native project to an independent linked Flutter package."""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile

from ohos_links import generated_dart, validate_codegen_isolation, workspace_lock, workspace_path
from ohos_toolchain import validate_flutter_artifacts


RUNTIME_FILE = ".flutter-runtime.json"
ENV_KEYS = (
    "OHOS_SDK_HOME", "HOS_SDK_HOME", "DEVECO_SDK_HOME",
    "PUB_HOSTED_URL", "FLUTTER_STORAGE_BASE_URL", "FLUTTER_OHOS_STORAGE_BASE_URL",
)


class PreparationRequiredError(ValueError):
    """The local Flutter package must be prepared again before Hvigor can continue."""


def pub_cache_path(root):
    """Keep upstream packages separate from the formerly patched Pub cache."""
    return root / "ohos/.pub-cache/upstream"


def write_local(path, content):
    """Atomic ordinary files only; never overwrite a maintained file through a link."""
    if path.resolve() != path or (path.is_file() and path.stat().st_nlink != 1):
        raise ValueError(f"鸿蒙本地输出不能是文件链接：{path}")
    if isinstance(content, str):
        content = content.encode("utf-8")
    if path.is_file() and path.read_bytes() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(content)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def write_json(path, data):
    write_local(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def fingerprint(paths, base):
    digest = hashlib.sha256()
    for path in sorted(paths):
        for data in (path.relative_to(base).as_posix().encode(), path.read_bytes()):
            digest.update(len(data).to_bytes(8, "big"))
            digest.update(data)
    return digest.hexdigest()


def dependency_fingerprint(root):
    config = root / "ohos/flutter"
    files = [root / "pubspec.yaml", root / "pubspec.lock"]
    files.extend(config / name for name in (
        "pubspec_dependencies.json", "toolchain.lock.json",
    ))
    files.extend(p for p in (config / "patches").rglob("*") if p.is_file() and p.suffix != ".md")
    return fingerprint(files, root)


def prepare_hvigor_adapter(native, workspace, sdk):
    """Copy only locked SDK Hvigor sources, then patch that local copy in memory."""
    config = native / "flutter/patches/hvigor/manifest.json"
    manifest = json.loads(config.read_text(encoding="utf-8"))
    toolchain = json.loads((native / "flutter/toolchain.lock.json").read_text(encoding="utf-8"))
    if (manifest.get("schemaVersion") != 1 or
            manifest["frameworkRevision"] != toolchain["flutter"]["frameworkRevision"]):
        raise ValueError("Hvigor 适配与锁定的 Flutter SDK 提交不匹配。")
    sources = {}
    for item in manifest["sources"]:
        relative = PurePosixPath(item["path"])
        if relative.is_absolute() or ".." in relative.parts or "\\" in item["path"] or ":" in item["path"]:
            raise ValueError("Hvigor 适配清单路径越界。")
        source = sdk / "packages/flutter_tools/hvigor" / relative
        content = source.read_text(encoding="utf-8")
        if hashlib.sha256(content.encode("utf-8")).hexdigest() != item["sha256"]:
            raise ValueError(f"SDK Hvigor 源码与适配基线不一致：{relative}")
        sources[item["path"]] = content
    for edit in manifest["edits"]:
        content = sources[edit["path"]]
        if not edit["before"] or content.count(edit["before"]) != edit["count"]:
            raise ValueError(f"Hvigor 补丁上下文不匹配：{edit['path']}")
        sources[edit["path"]] = content.replace(edit["before"], edit["after"])
    output = workspace / "tooling/flutter-hvigor-plugin"
    for relative, content in sources.items():
        write_local(output / relative, content)


def prepare_native_runtime(root, workspace, sdk, env):
    native = root / "ohos"
    # Invalidate first: interrupted re-preparation must never look ready in DevEco.
    (native / RUNTIME_FILE).unlink(missing_ok=True)
    prepare_hvigor_adapter(native, workspace, sdk)
    profile = native / "build-profile.json5"
    if not profile.is_file():
        raise ValueError("缺少 DevEco 工程配置：ohos/build-profile.json5")
    write_json(native / RUNTIME_FILE, {
        "schemaVersion": 1,
        "workspace": str(workspace.resolve()),
        "nativeProject": str(native.resolve()),
        "flutterSdk": str(sdk.resolve()),
        "python": sys.executable,
        "git": shutil.which("git"),
        "environment": {key: env[key] for key in ENV_KEYS if key in env},
        "dependencyFingerprint": dependency_fingerprint(root),
        "packageFingerprint": resolved_fingerprint(workspace),
    })


def resolved_fingerprint(workspace):
    return fingerprint([
        workspace / "pubspec.yaml", workspace / "pubspec.lock",
        workspace / ".dart_tool/package_config.json", workspace / ".flutter-plugins-dependencies",
    ], workspace)


def load_runtime(root):
    native = root / "ohos"
    path = native / RUNTIME_FILE
    if not path.is_file():
        raise PreparationRequiredError("鸿蒙 Flutter 环境尚未初始化，请执行 DevEco Sync。")
    runtime = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(runtime, dict):
        raise PreparationRequiredError("鸿蒙运行配置格式无效，请重新执行 DevEco Sync。")
    workspace = workspace_path(root)
    if (runtime.get("schemaVersion") != 1 or runtime.get("workspace") != str(workspace) or
            runtime.get("nativeProject") != str(native)):
        raise PreparationRequiredError("鸿蒙运行配置路径已变化，请重新执行 DevEco Sync。")
    if (runtime.get("dependencyFingerprint") != dependency_fingerprint(root) or
            runtime.get("packageFingerprint") != resolved_fingerprint(workspace)):
        raise PreparationRequiredError("鸿蒙依赖配置或解析结果已变化，请重新执行 DevEco Sync。")
    return runtime


def _bootstrap_arguments(root):
    """Reuse paths from an older runtime when DevEco did not inherit the shell PATH."""
    path = root / "ohos" / RUNTIME_FILE
    try:
        runtime = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return ["--prepare-only"]
    if not isinstance(runtime, dict):
        return ["--prepare-only"]
    arguments = ["--prepare-only"]
    flutter_sdk = runtime.get("flutterSdk")
    if isinstance(flutter_sdk, str) and Path(flutter_sdk).is_dir():
        arguments.extend(("--flutter-sdk", flutter_sdk))
    environment = runtime.get("environment")
    harmony_sdk = environment.get("DEVECO_SDK_HOME") if isinstance(environment, dict) else None
    if isinstance(harmony_sdk, str) and Path(harmony_sdk).is_dir():
        arguments.extend(("--ohos-sdk", harmony_sdk))
    return arguments


def bootstrap_native(root):
    """Prepare a fresh/stale checkout, otherwise perform the normal incremental refresh."""
    workspace = workspace_path(root)
    required = (
        workspace / "tooling/flutter-hvigor-plugin/index.ts",
    )
    needs_preparation = False
    try:
        load_runtime(root)
        if not all(path.is_file() for path in required):
            raise PreparationRequiredError("鸿蒙 Flutter 本地构建适配不完整。")
    except (OSError, PreparationRequiredError, KeyError, json.JSONDecodeError):
        needs_preparation = True
    if not needs_preparation:
        try:
            refresh_native(root)
            return
        except PreparationRequiredError:
            needs_preparation = True
    if needs_preparation:
        from build_ohos import main as build_main
        print("DevEco Sync 正在准备 Flutter OH 环境…", flush=True)
        result = build_main(_bootstrap_arguments(root))
        if result != 0:
            raise ValueError(f"Flutter OH 初始化失败，退出码：{result}")


def runtime_environment(root, runtime):
    env = os.environ.copy()
    # Only selected non-secret tool settings are persisted, never the whole shell environment.
    env.update({key: value for key, value in runtime["environment"].items() if key in ENV_KEYS})
    env["PUB_CACHE"] = str(pub_cache_path(root))
    sdk = Path(runtime["flutterSdk"])
    bins = [sdk / "bin"]
    if runtime.get("git"):
        bins.append(Path(runtime["git"]).parent)
    harmony_sdk = env.get("DEVECO_SDK_HOME")
    if harmony_sdk:
        tools = Path(harmony_sdk).parent / "tools"
        bins.extend((tools / "node", tools / "ohpm/bin", tools / "hvigor/bin"))
    env["PATH"] = os.pathsep.join(map(str, bins)) + os.pathsep + env.get("PATH", "")
    return env


def generate_code(root, workspace, flutter, dart, env):
    from build_ohos import run
    validate_codegen_isolation(workspace)
    inputs, outputs = [], []
    for name in ("lib", "test"):
        for path in (workspace / name).rglob("*"):
            if path.is_file():
                target = outputs if generated_dart(path.relative_to(workspace), path) else inputs
                target.append(path)
    inputs.extend(workspace / name for name in (
        "pubspec.yaml", "pubspec.lock", "l10n.yaml", ".dart_tool/package_config.json",
    ) if (workspace / name).is_file())
    if (root / "build.yaml").is_file():
        raise ValueError("上游新增了 build.yaml；请先将生成器配置纳入鸿蒙组装规则。")
    state_path = workspace / ".codegen-state.json"
    state = {"inputs": fingerprint(inputs, workspace), "outputs": fingerprint(outputs, workspace)}
    if state_path.is_file() and json.loads(state_path.read_text()) == state:
        return
    run([dart, "run", "build_runner", "build", "--delete-conflicting-outputs"], workspace, env)
    validate_codegen_isolation(workspace)
    run([flutter, "gen-l10n"], workspace, env)
    validate_codegen_isolation(workspace)
    outputs = [p for name in ("lib", "test") for p in (workspace / name).rglob("*.dart")
               if p.is_file() and generated_dart(p.relative_to(workspace), p)]
    state["outputs"] = fingerprint(outputs, workspace)
    write_json(state_path, state)


def render_registrant(plugins):
    imports, registrations = [], []
    for index, plugin in enumerate(plugins):
        name, class_name = plugin["name"], plugin["class"]
        if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_]*", name) or not re.fullmatch(r"[a-zA-Z_$][a-zA-Z0-9_$]*", class_name):
            raise ValueError("鸿蒙插件名称或注册类不合法。")
        alias = f"OhosPlugin{index}"
        imports.append(f"import {alias} from '{name}';")
        registrations.append(f"      flutterEngine.getPlugins()?.add(new {alias}());")
    return (
        "// Generated from .flutter-workspace OH dependencies. Do not edit.\n"
        "import { FlutterEngine, Log } from '@ohos/flutter_ohos';\n"
        + "\n".join(imports) + "\n\n"
        "export class GeneratedPluginRegistrant {\n"
        "  static registerWith(flutterEngine: FlutterEngine) {\n"
        "    try {\n" + "\n".join(registrations) + "\n"
        "    } catch (error) {\n"
        "      Log.e('GeneratedPluginRegistrant', 'Failed to register plugins', error);\n"
        "    }\n  }\n}\n"
    )


def write_properties(native, sdk, version):
    path = native / "local.properties"
    previous = path.read_text(encoding="utf-8") if path.is_file() else ""
    lines = [line for line in previous.splitlines() if not re.match(
        r"\s*flutter\.(sdk|versionName|versionCode)\s*=", line,
    )]
    lines.extend((f"flutter.sdk={sdk.as_posix()}",
                  f"flutter.versionName={version[0]}", f"flutter.versionCode={version[1]}"))
    write_local(path, "\n".join(lines) + "\n")


def refresh_native(root):
    from build_ohos import (
        command_output, load_toolchain, package_root, prepare_workspace, sdk_commands, source_git_metadata,
        sync_workspace_version, validate_ohos_plugins,
    )
    root = root.resolve()
    with workspace_lock(root):
        runtime = load_runtime(root)
        sdk = Path(runtime["flutterSdk"])
        # DevEco may reuse its task graph after the shared SDK cache changes.
        validate_flutter_artifacts(sdk, load_toolchain(root)["flutter"])
        if package_root(workspace_path(root), "flutter") != (sdk / "packages/flutter").resolve():
            raise PreparationRequiredError(
                "鸿蒙工作区仍使用其他 Flutter framework（可能是旧诊断副本），请重新执行 DevEco Sync。"
            )
        workspace = prepare_workspace(root)
        # Link/ARB refresh is allowed; dependency resolution belongs to --prepare-only.
        if runtime["packageFingerprint"] != resolved_fingerprint(workspace):
            raise PreparationRequiredError("组装后的鸿蒙依赖声明变化，请重新执行 DevEco Sync。")
        flutter, dart = sdk_commands(sdk)
        env = runtime_environment(root, runtime)
        generate_code(root, workspace, flutter, dart, env)
        validate_ohos_plugins(workspace)
        plugins = json.loads(command_output([
            dart, "--packages=.dart_tool/package_config.json", "tooling/plugin_registrant.dart",
        ], workspace, env))
        native = root / "ohos"
        write_local(native / "entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets", render_registrant(plugins))
        write_properties(native, sdk, sync_workspace_version(root, workspace))
        runtime["dartDefines"] = source_git_metadata(root, runtime["git"])
        write_json(native / RUNTIME_FILE, runtime)


def _with_default_split_debug_info(arguments, workspace):
    """Keep AOT symbols for profile/release unless Hvigor supplied a path."""
    result = list(arguments)
    if any(argument.startswith("-dSplitDebugInfo=") for argument in result):
        return result
    mode = next((
        argument.split("=", 1)[1]
        for argument in result
        if argument.startswith("-dBuildMode=")
    ), None)
    if mode not in ("profile", "release"):
        return result
    index = result.index("assemble") + 1
    symbol_dir = workspace / "build" / "symbols" / mode
    result.insert(index, f"-dSplitDebugInfo={symbol_dir}")
    return result


def assemble(root, arguments):
    from build_ohos import run, sdk_commands
    # Refresh even when DevEco reuses an already configured task graph.
    refresh_native(root)
    with workspace_lock(root):
        runtime = load_runtime(root)
        workspace = workspace_path(root)
        validate_codegen_isolation(workspace)
        flutter, _ = sdk_commands(Path(runtime["flutterSdk"]))
        if (not arguments or Path(arguments[0]).resolve() != Path(flutter).resolve() or
                "assemble" not in arguments):
            raise ValueError("Hvigor 传入了不匹配的 Flutter assemble 命令。")
        # DevEco and CLI receive identical metadata. Explicit Hvigor defines take precedence.
        defines = dict(runtime["dartDefines"])
        defines["BUILD_TIME"] = datetime.now(timezone.utc).isoformat()
        rest = []
        for argument in arguments:
            if argument.startswith("--DartDefines="):
                for encoded in argument.split("=", 1)[1].split(","):
                    key, value = base64.b64decode(encoded).decode().split("=", 1)
                    defines[key] = value
            else:
                rest.append(argument)
        rest = _with_default_split_debug_info(rest, workspace)
        encoded = ",".join(base64.b64encode(f"{key}={value}".encode()).decode() for key, value in defines.items())
        # Insert the option before the target names; subprocess preserves spaces in each argument.
        index = rest.index("assemble") + 1
        rest.insert(index, "--DartDefines=" + encoded)
        run(rest, workspace, runtime_environment(root, runtime))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument("--bootstrap", action="store_true")
    actions.add_argument("--refresh", action="store_true")
    actions.add_argument("--assemble", help="JSON argument array from the local Hvigor adapter")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.bootstrap:
        bootstrap_native(root)
    elif args.refresh:
        refresh_native(root)
    else:
        assemble(root, json.loads(args.assemble))


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"鸿蒙原生构建准备失败：{error}", file=sys.stderr)
        sys.exit(1)
