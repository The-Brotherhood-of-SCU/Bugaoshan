"""Share handwritten sources through symlinks, keeping writable outputs local."""

from contextlib import contextmanager
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import tempfile


STATE_FILE = ".ohos-links.json"


@dataclass(frozen=True)
class LinkedSource:
    source: Path
    directory: bool = False


def generated_dart(relative, source=None):
    """The current build_runner/l10n outputs must never be linked to maintained files."""
    path = Path(relative)
    if path.suffix != ".dart":
        return False
    if path.name.endswith((".g.dart", ".freezed.dart", ".config.dart")):
        return True
    if path.name.startswith("app_localizations"):
        return True
    if source is not None and source.is_file():
        with source.open("rb") as stream:
            header = stream.read(2048).upper()
        return b"GENERATED CODE" in header or b"DO NOT EDIT" in header
    return False


def workspace_path(root):
    workspace = root.resolve() / "ohos/.flutter-workspace"
    if workspace.resolve() != workspace:
        raise ValueError("鸿蒙编译目录不能通过链接指向其他位置。")
    return workspace


@contextmanager
def workspace_lock(root):
    workspace = workspace_path(root)
    workspace.parent.mkdir(parents=True, exist_ok=True)
    path = workspace.parent / ".flutter-workspace.lock"
    if path.resolve() != path:
        raise ValueError("鸿蒙构建锁不能是文件链接。")
    with path.open("a+b") as lock:
        if lock.tell() == 0:
            lock.write(b"\0")
            lock.flush()
        lock.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            raise ValueError("另一个脚本正在使用鸿蒙编译目录，请等待该命令结束。") from error
        try:
            yield workspace
        finally:
            lock.seek(0)
            if os.name == "nt":
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def _target(workspace, relative):
    if not isinstance(relative, str):
        raise ValueError("链接清单路径必须是字符串。")
    path = PurePosixPath(relative)
    # Keep pubspec_overrides.yaml accepted here only so old journal entries
    # can be removed when assembling a workspace without dependency overrides.
    root_files = {
        "pubspec.yaml", "pubspec.lock", "pubspec_overrides.yaml", "analysis_options.yaml",
        "l10n.yaml", ".metadata", "CHANGELOG.md", "LICENSE",
    }
    if (
        not path.parts or path.is_absolute() or ".." in path.parts
        or "\\" in relative or ":" in relative or path.as_posix() != relative
        or any(part.endswith((".", " ")) for part in path.parts)
        or (relative not in root_files and relative != "tooling/plugin_registrant.dart"
            and path.parts[0] not in {"lib", "assets", "test"})
    ):
        raise ValueError(f"链接清单路径无效：{relative}")
    target = workspace / relative
    # The leaf may be a shared link. Its parent must always be a local directory.
    if target.parent.resolve() != target.parent:
        raise ValueError(f"不能在共享目录链接内写入文件：{relative}")
    return target


def _digest(source):
    if isinstance(source, bytes):
        return hashlib.sha256(source).hexdigest()
    digest = hashlib.sha256()
    with source.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_state(workspace):
    path = workspace / STATE_FILE
    if path.resolve() != path:
        raise ValueError("链接清单不能是文件链接。")
    if not path.exists():
        if workspace.exists() and any(workspace.iterdir()):
            raise ValueError("鸿蒙编译目录非空且没有链接清单，请先移走该目录再准备工程。")
        return {}
    state = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(state, dict) or state.get("schemaVersion") != 1 or not isinstance(state.get("files"), dict):
        raise ValueError("鸿蒙链接清单格式无效。")
    for relative, signature in state["files"].items():
        _target(workspace, relative)
        if signature is not None and not isinstance(signature, str):
            raise ValueError(f"鸿蒙链接清单记录无效：{relative}")
    return state["files"]


def _write_state(workspace, files):
    content = (json.dumps({"schemaVersion": 1, "files": files}, indent=2, sort_keys=True) + "\n").encode()
    path = workspace / STATE_FILE
    if path.is_file() and path.read_bytes() == content:
        return
    with tempfile.NamedTemporaryFile(dir=workspace, prefix=".links-", delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(content)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def _unlink_leaf(target):
    # Never recursively delete: unlinking a shared file/assets symlink only
    # removes the link. A real directory (or Windows junction) is not ours to remove.
    if target.is_symlink() or target.is_file():
        target.unlink()
    elif target.exists():
        raise ValueError(f"预期文件或符号链接的位置被目录占用：{target}")


def assemble_linked_workspace(root, inputs, *, preserve_generated=()):
    root = root.resolve()
    workspace = workspace_path(root)
    previous = _read_state(workspace)
    targets = {}
    folded = set()
    for relative in set(inputs) | set(previous):
        target = _target(workspace, relative)
        if relative.casefold() in folded:
            raise ValueError(f"链接清单包含大小写冲突：{relative}")
        folded.add(relative.casefold())
        if target.exists() and not target.is_file() and not target.is_symlink():
            raise ValueError(f"预期文件或符号链接的位置被目录占用：{relative}")
        targets[relative] = target

    desired = {}
    for relative, source in inputs.items():
        if isinstance(source, LinkedSource):
            origin = source.source.resolve(strict=True)
            if not origin.is_relative_to(root) or any(
                origin.is_relative_to(root / "ohos" / name)
                for name in ("build", ".flutter-workspace", ".pub-cache")
            ):
                raise ValueError(f"共享源码链接必须指向维护目录：{relative}")
            if origin.is_dir() != source.directory:
                raise ValueError(f"共享源码链接类型不匹配：{relative}")
            if source.directory and relative != "assets":
                raise ValueError("只允许 assets 使用目录链接；源码目录必须为真实目录。")
            if generated_dart(relative, origin):
                raise ValueError(f"生成代码不能链接到维护源码：{relative}")
            desired[relative] = "link:" + str(origin)
        else:
            desired[relative] = "file:" + _digest(source)
    preserve_generated = set(preserve_generated)

    updates = []
    for relative, source in inputs.items():
        target = targets[relative]
        if isinstance(source, LinkedSource):
            if target.is_symlink() and target.resolve() == source.source.resolve():
                continue
        elif target.is_file() and not target.is_symlink() and target.stat().st_nlink == 1:
            if relative in preserve_generated and previous.get(relative) == desired[relative]:
                continue
            if "file:" + _digest(target) == desired[relative]:
                continue
        updates.append(relative)

    workspace.mkdir(parents=True, exist_ok=True)
    # Journal pending additions before creating links, so interrupted preparation
    # can be retried without losing track of stale links or partial local files.
    pending = dict(previous)
    pending.update({name: None for name in updates})
    _write_state(workspace, pending)
    removed = set(previous) - set(inputs)
    for relative in sorted(removed):
        _unlink_leaf(_target(workspace, relative))
    for relative in sorted(updates):
        target = _target(workspace, relative)
        _unlink_leaf(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        source = inputs[relative]
        if isinstance(source, LinkedSource):
            try:
                target.symlink_to(source.source.resolve(), target_is_directory=source.directory)
            except OSError as error:
                if os.name == "nt" and getattr(error, "winerror", None) == 1314:
                    raise ValueError(
                        "Windows 无权创建符号链接。请启用 Windows 开发者模式，"
                        "或在管理员 PowerShell 中重新执行；不会退回复制共用源码。"
                    ) from error
                raise
        elif isinstance(source, bytes):
            target.write_bytes(source)
        else:
            shutil.copy2(source, target)
    _write_state(workspace, desired)
    links = sum(isinstance(source, LinkedSource) for source in inputs.values())
    print(f"鸿蒙链接工程：{links} 个共享链接，更新 {len(updates)} 项、移除 {len(removed)} 项。", flush=True)
    return workspace


def validate_codegen_isolation(workspace):
    """Check output directories and existing generated Dart files before Pub/codegen."""
    workspace = workspace.resolve()
    if (workspace / "ohos").exists() or (workspace / "ohos").is_symlink():
        raise ValueError("Flutter 工作目录内不能再创建或链接原生 ohos 工程。")
    for relative in ("lib", "test", "tooling", ".dart_tool", "build"):
        target = workspace / relative
        if target.resolve() != target:
            raise ValueError(f"鸿蒙生成目录不能链接到其他位置：{relative}")
    for name in ("lib", "test"):
        for current, directories, files in os.walk(workspace / name, followlinks=False):
            current = Path(current)
            for directory in directories:
                path = current / directory
                if path.resolve() != path:
                    raise ValueError(f"生成代码的父目录不能是链接：{path.relative_to(workspace)}")
            for filename in files:
                path = current / filename
                relative = path.relative_to(workspace).as_posix()
                if generated_dart(relative, path) and (
                    path.is_symlink() or path.stat().st_nlink != 1
                ):
                    raise ValueError(f"生成代码必须为鸿蒙工程内的独立文件：{relative}")
    config = workspace / "l10n.yaml"
    if config.is_file():
        for line in config.read_text(encoding="utf-8").splitlines():
            match = re.fullmatch(r"\s*(arb-dir|output-dir|output-localization-file):\s*(.*?)\s*", line)
            if not match:
                continue
            value = match.group(2).split(" #", 1)[0].strip().strip("\"'")
            relative = PurePosixPath(value)
            if not relative.parts or relative.is_absolute() or ".." in relative.parts or ":" in value or "\\" in value:
                raise ValueError(f"本地化生成路径必须位于鸿蒙工程：{match.group(1)}")
            if match.group(1) == "output-localization-file":
                if len(relative.parts) != 1 or relative.suffix != ".dart":
                    raise ValueError("本地化输出文件名必须是普通 Dart 文件名。")
            elif relative.parts[0] != "lib" or (workspace / value).resolve() != workspace / value:
                raise ValueError(f"本地化目录必须位于鸿蒙工程的真实 lib 目录：{value}")
