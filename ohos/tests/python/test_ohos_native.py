"""Native/Flutter path separation, generator isolation and SDK adapter drift checks."""

import base64
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tool"))
import build_ohos
import ohos_native
from ohos_links import LinkedSource, assemble_linked_workspace


class OhosNativeTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.native = self.root / "ohos"
        self.workspace = self.native / ".flutter-workspace"

    def write(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def test_hvigor_adapter_only_changes_local_copy_and_rejects_sdk_drift(self):
        sdk = self.root / "SDK with spaces"
        original = "export const nativeRoot = 'implicit';\n"
        source = self.write("SDK with spaces/packages/flutter_tools/hvigor/index.ts", original)
        self.write("ohos/flutter/toolchain.lock.json", json.dumps({"flutter": {"frameworkRevision": "pinned"}}))
        self.write("ohos/flutter/patches/hvigor/manifest.json", json.dumps({
            "schemaVersion": 1, "frameworkRevision": "pinned",
            "sources": [{"path": "index.ts", "sha256": hashlib.sha256(original.encode()).hexdigest()}],
            "edits": [{"path": "index.ts", "before": "implicit", "after": "explicit", "count": 1}],
        }))
        ohos_native.prepare_hvigor_adapter(self.native, self.workspace, sdk)
        target = self.workspace / "tooling/flutter-hvigor-plugin/index.ts"
        self.assertIn("explicit", target.read_text())
        self.assertEqual(source.read_text(), original)
        source.write_text("new SDK content\n")
        with self.assertRaisesRegex(ValueError, "适配基线"):
            ohos_native.prepare_hvigor_adapter(self.native, self.workspace, sdk)
        self.assertIn("explicit", target.read_text())

    def test_version_uses_native_properties_preserving_deveco_settings(self):
        app = self.write("ohos/AppScope/app.json5", "maintained app config\n")
        profile = self.write("ohos/build-profile.json5", "local DevEco config\n")
        properties = self.write("ohos/local.properties", "sdk.dir=custom\nflutter.sdk=old\nflutter.versionName=old\n")
        ohos_native.write_properties(self.native, self.root / "SDK with spaces", ("2.5.1", 20501))
        content = properties.read_text()
        self.assertIn("sdk.dir=custom", content)
        self.assertIn("flutter.versionName=2.5.1", content)
        self.assertIn("flutter.versionCode=20501", content)
        self.assertEqual(content.count("flutter.sdk="), 1)
        self.assertEqual(app.read_text(), "maintained app config\n")
        self.assertEqual(profile.read_text(), "local DevEco config\n")
        self.assertFalse((self.workspace / "ohos").exists())

    def test_changed_dependency_resolution_is_rejected_before_preparation(self):
        self.write("ohos/.flutter-runtime.json", json.dumps({
            "schemaVersion": 1, "workspace": str(self.workspace), "nativeProject": str(self.native),
            "dependencyFingerprint": "prepared", "packageFingerprint": "old resolution",
        }))
        with (
            patch.object(ohos_native, "dependency_fingerprint", return_value="prepared"),
            patch.object(ohos_native, "resolved_fingerprint", return_value="different resolution"),
            patch.object(build_ohos, "prepare_workspace") as prepare,
            self.assertRaisesRegex(ValueError, "重新执行 DevEco Sync"),
        ):
            ohos_native.refresh_native(self.root)
        prepare.assert_not_called()

    def test_bootstrap_prepares_missing_runtime_and_reuses_recorded_sdk_paths(self):
        flutter_sdk = self.root / "Flutter OH"
        harmony_sdk = self.root / "DevEco/sdk"
        flutter_sdk.mkdir(parents=True)
        harmony_sdk.mkdir(parents=True)
        self.write("ohos/.flutter-runtime.json", json.dumps({
            "flutterSdk": str(flutter_sdk),
            "environment": {"DEVECO_SDK_HOME": str(harmony_sdk)},
        }))
        with (
            patch.object(
                ohos_native,
                "load_runtime",
                side_effect=ohos_native.PreparationRequiredError("stale"),
            ),
            patch.object(build_ohos, "main", return_value=0) as prepare,
            patch.object(ohos_native, "refresh_native") as refresh,
        ):
            ohos_native.bootstrap_native(self.root)
        prepare.assert_called_once_with([
            "--prepare-only", "--flutter-sdk", str(flutter_sdk),
            "--ohos-sdk", str(harmony_sdk),
        ])
        refresh.assert_not_called()

    def test_bootstrap_refreshes_complete_runtime_without_full_preparation(self):
        self.write("ohos/.flutter-workspace/tooling/flutter-hvigor-plugin/index.ts", "export {}\n")
        with (
            patch.object(ohos_native, "load_runtime", return_value={}),
            patch.object(build_ohos, "main") as prepare,
            patch.object(ohos_native, "refresh_native") as refresh,
        ):
            ohos_native.bootstrap_native(self.root)
        prepare.assert_not_called()
        refresh.assert_called_once_with(self.root)

    def test_codegen_detects_shared_file_changes_and_missing_generated_output(self):
        source = self.write("lib/example.dart", "shared source\n")
        generated = self.write("lib/example.g.dart", "// GENERATED CODE\nupstream output\n")
        workspace = assemble_linked_workspace(self.root, {
            "lib/example.dart": LinkedSource(source), "lib/example.g.dart": generated,
        })

        def generate(command, cwd, env):
            self.assertEqual(cwd, workspace)
            (workspace / "lib/example.g.dart").write_text("// GENERATED CODE\nOH output\n")

        with patch.object(build_ohos, "run", side_effect=generate) as run:
            ohos_native.generate_code(self.root, workspace, "flutter", "dart", {})
            self.assertEqual(run.call_count, 2)
            ohos_native.generate_code(self.root, workspace, "flutter", "dart", {})
            self.assertEqual(run.call_count, 2)
            source.write_text("updated source\n")
            ohos_native.generate_code(self.root, workspace, "flutter", "dart", {})
            self.assertEqual(run.call_count, 4)
            (workspace / "lib/example.g.dart").unlink()
            ohos_native.generate_code(self.root, workspace, "flutter", "dart", {})
            self.assertEqual(run.call_count, 6)
        self.assertEqual(generated.read_text(), "// GENERATED CODE\nupstream output\n")

    def test_assemble_keeps_arguments_and_metadata_in_oh_package(self):
        flutter = self.root / "SDK with spaces/bin/flutter.bat"
        upstream_pub = self.write("pubspec.lock", "upstream lock\n")
        self.workspace.mkdir(parents=True, exist_ok=True)
        runtime = {
            "flutterSdk": str(flutter.parent.parent), "environment": {},
            "dartDefines": {"GIT_COMMIT": "prepared", "GIT_TAG": "v1.0"},
        }
        explicit = base64.b64encode(b"GIT_TAG=override").decode()
        arguments = [str(flutter), "assemble", f"--DartDefines={explicit}",
                     "-dBuildMode=release", "-dOhosArchs=ohos-arm64 ohos-x64",
                     "release_ohos_application"]
        with (
            patch.object(ohos_native, "load_runtime", return_value=runtime),
            patch.object(ohos_native, "refresh_native"),
            patch.object(build_ohos, "sdk_commands", return_value=(str(flutter), "dart")),
            patch.object(build_ohos, "run") as run,
        ):
            ohos_native.assemble(self.root, arguments)
        command, cwd, env = run.call_args.args
        self.assertEqual(cwd, self.workspace)
        self.assertEqual(command[0], str(flutter))
        self.assertIn("-dOhosArchs=ohos-arm64 ohos-x64", command)
        self.assertIn(
            f"-dSplitDebugInfo={self.workspace / 'build/symbols/release'}",
            command,
        )
        self.assertEqual(env["PUB_CACHE"], str(self.native / ".pub-cache/upstream"))
        encoded = next(a.split("=", 1)[1] for a in command if a.startswith("--DartDefines="))
        values = dict(base64.b64decode(value).decode().split("=", 1) for value in encoded.split(","))
        self.assertEqual(values["GIT_TAG"], "override")
        self.assertEqual(values["GIT_COMMIT"], "prepared")
        self.assertIn("BUILD_TIME", values)
        self.assertEqual(upstream_pub.read_text(), "upstream lock\n")
        self.assertFalse((self.workspace / "ohos").exists())

    def test_default_split_debug_info_preserves_explicit_path_and_debug_mode(self):
        profile = ["flutter", "assemble", "-dBuildMode=profile", "profile_ohos_application"]
        command = ohos_native._with_default_split_debug_info(profile, self.workspace)
        self.assertIn(
            f"-dSplitDebugInfo={self.workspace / 'build/symbols/profile'}",
            command,
        )
        self.assertEqual(profile, [
            "flutter", "assemble", "-dBuildMode=profile", "profile_ohos_application",
        ])

        explicit = f"-dSplitDebugInfo={self.root / 'symbols with spaces'}"
        release = ["flutter", "assemble", "-dBuildMode=release", explicit,
                   "release_ohos_application"]
        self.assertEqual(
            ohos_native._with_default_split_debug_info(release, self.workspace),
            release,
        )

        debug = ["flutter", "assemble", "-dBuildMode=debug", "debug_ohos_application"]
        self.assertEqual(
            ohos_native._with_default_split_debug_info(debug, self.workspace),
            debug,
        )

    def test_registrant_uses_resolved_packages_and_handles_duplicate_class_names(self):
        result = ohos_native.render_registrant([
            {"name": "first_ohos", "class": "ExamplePlugin"},
            {"name": "second_ohos", "class": "ExamplePlugin"},
        ])
        self.assertIn("import OhosPlugin0 from 'first_ohos'", result)
        self.assertIn("import OhosPlugin1 from 'second_ohos'", result)
        self.assertIn("new OhosPlugin1()", result)
        with self.assertRaises(ValueError):
            ohos_native.render_registrant([{"name": "invalid'name", "class": "Plugin"}])


if __name__ == "__main__":
    unittest.main()
