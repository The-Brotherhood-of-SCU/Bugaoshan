"""Verify the OH build entry keeps platform dependencies out of the main tree."""

import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import sys
import unittest
from unittest.mock import patch
import zipfile


SCRIPT = Path(__file__).resolve().parents[2] / "tool" / "build_ohos.py"
sys.path.insert(0, str(SCRIPT.parent))
SPEC = importlib.util.spec_from_file_location("build_ohos", SCRIPT)
build_ohos = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(build_ohos)


class OhosBuildTest(unittest.TestCase):
    def test_only_locked_stable_sdk_is_accepted(self):
        self.assertEqual(
            build_ohos.validate_sdk_version({"flutterVersion": "3.41.10-ohos-1.0.1"}),
            "3.41.10-ohos-1.0.1",
        )
        for version in (
            "3.41.10-ohos-1.0.1-beta", "3.44.9+ohos-0.0.1-canary1",
            "3.41.10-ohos-1.0.1-dev", "3.44.9", "3.41.10-ohos-0.0.2", "",
        ):
            with self.subTest(version=version), self.assertRaises(ValueError):
                build_ohos.validate_sdk_version({"flutterVersion": version})

        with self.assertRaises(ValueError):
            build_ohos.validate_sdk_version(
                {"flutterVersion": "3.41.10-ohos-1.0.0"},
                "3.41.10-ohos-1.0.1",
            )

    def test_exact_flutter_sdk_identity_is_required(self):
        expected = {
            "tag": "3.41.10-ohos-1.0.1",
            "flutterVersion": "3.41.10-ohos-1.0.1",
            "repositoryUrl": "https://example.invalid/flutter.git",
            "frameworkRevision": "framework-revision",
            "engineRevision": "engine-revision",
            "dartSdkVersion": "3.11.5",
        }
        info = {
            "flutterVersion": expected["flutterVersion"],
            "frameworkRevision": expected["frameworkRevision"],
            "engineRevision": expected["engineRevision"],
            "dartSdkVersion": expected["dartSdkVersion"],
        }
        with patch.object(
            build_ohos,
            "command_output",
            side_effect=[
                expected["frameworkRevision"],
                expected["frameworkRevision"],
                expected["repositoryUrl"],
            ],
        ):
            self.assertEqual(
                build_ohos.validate_flutter_sdk(Path("sdk"), info, expected, {}),
                expected["flutterVersion"],
            )

        wrong_info = dict(info, engineRevision="other-engine")
        with self.assertRaises(ValueError):
            build_ohos.validate_flutter_sdk(Path("sdk"), wrong_info, expected, {})

    def test_supported_sdk_version_is_read_from_lock_instead_of_a_fixed_release(self):
        version = "4.0.0-ohos-2.1.0"
        with patch.object(build_ohos, "load_toolchain", return_value={
            "flutter": {"flutterVersion": version},
        }):
            self.assertEqual(
                build_ohos.validate_sdk_version({"flutterVersion": version}), version,
            )
            with self.assertRaisesRegex(ValueError, "版本不匹配"):
                build_ohos.validate_sdk_version({"flutterVersion": "3.41.10-ohos-1.0.1"})

    def test_flutter_config_provides_harmony_sdk_without_a_repo_path(self):
        path = build_ohos.parse_flutter_config(
            "All Settings:\n  enable-ohos: (Not set)\n  ohos-sdk: sdk/from/config\n"
        )
        self.assertEqual(path, Path("sdk/from/config").resolve())

    def test_workspace_has_ohos_dependencies_and_does_not_modify_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            files = {
                "pubspec.yaml": (
                    "name: example\n"
                    "dependencies:\n"
                    "  flutter:\n"
                    "    sdk: flutter\n"
                    "  device_info_plus: ^13.2.0\n"
                    "dev_dependencies:\n"
                    "  flutter_test:\n"
                    "    sdk: flutter\n"
                ),
                "pubspec.lock": "upstream lock\n",
                ".dart_tool/package_config.json": "upstream package config\n",
                "lib/main.dart": "original source\n",
                "lib/shared.dart": "shared source\n",
                "lib/models/example.g.dart": "// GENERATED CODE\noriginal generated source\n",
                "assets/libs/data.txt": "application asset\n",
                "ohos/flutter/pubspec.lock": "ohos lock\n",
                "ohos/flutter/pubspec_overrides.yaml": "dependency_overrides: {}\n",
                "ohos/flutter/pubspec_dependencies.json": json.dumps(
                    {
                        "schemaVersion": 1,
                        "excludedDependencies": ["device_info_plus"],
                        "dependencies": {
                            "flutter_secure_storage_ohos": {
                                "git": {
                                    "url": "https://example.invalid/storage.git",
                                    "ref": "a" * 40,
                                    "path": "flutter_secure_storage_ohos",
                                }
                            }
                        },
                    }
                ),
                "ohos/flutter/toolchain.lock.json": '{"schemaVersion": 1}\n',
                "ohos/tests/flutter/platform_adapters_test.dart.template": (
                    "void main() {}\n"
                ),
                "ohos/tests/flutter/course_copy_mode_test.dart.template": (
                    "void main() { /* OH copy test */ }\n"
                ),
                "ohos/tests/flutter/course_duplicate_test.dart.template": (
                    "void main() { /* OH duplicate test */ }\n"
                ),
                "ohos/tests/flutter/theme_page_transitions_test.dart.template": (
                    "void main() { /* OH theme test */ }\n"
                ),
                "ohos/tests/flutter/support/memory_course_database.dart.template": (
                    "class MemoryCourseDatabase {}\n"
                ),
                "test/course_copy_mode_test.dart": (
                    "import 'package:sqflite_common_ffi/sqflite_ffi.dart';\n"
                ),
                "test/course_duplicate_test.dart": (
                    "import 'package:sqflite_common_ffi/sqflite_ffi.dart';\n"
                ),
                "test/theme_page_transitions_test.dart": (
                    "void main() { /* upstream platforms */ }\n"
                ),
                "ohos/flutter/source-manifest.json": json.dumps(
                    {
                        "schemaVersion": 1,
                        "files": [
                            {
                                "path": "lib/main.dart",
                                "upstreamSha256": hashlib.sha256(b"original source\n").hexdigest(),
                            },
                            {"path": "lib/utils/mobile_device_info.dart", "upstreamSha256": None},
                        ],
                        "localizations": [],
                    }
                ),
                "ohos/flutter/overrides/lib/main.dart": "patched source\n",
                "ohos/flutter/overrides/lib/utils/mobile_device_info.dart": "Future<void> deviceInfo() async {}\n",
                "ohos/entry/src/main/ets/EntryAbility.ets": "native entry\n",
                "ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets": "stale plugins\n",
                "ohos/node_modules/package/index.js": "generated module\n",
                "ohos/.hvigor/cache": "native build cache\n",
                "ohos/build-profile.json5": "local build config\n",
                "ohos/local.properties": "local sdk config\n",
            }
            for name, content in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")

            workspace = build_ohos.prepare_workspace(root)
            self.assertEqual(workspace, root / "ohos/.flutter-workspace")
            self.assertTrue((workspace / "lib/main.dart").is_symlink())
            self.assertEqual(
                (workspace / "lib/main.dart").resolve(),
                root / "ohos/flutter/overrides/lib/main.dart",
            )
            self.assertTrue((workspace / "lib/shared.dart").is_symlink())
            self.assertEqual((workspace / "lib/shared.dart").resolve(), root / "lib/shared.dart")
            self.assertTrue((workspace / "assets").is_symlink())
            self.assertEqual((workspace / "assets").resolve(), root / "assets")
            self.assertFalse((workspace / "lib/models/example.g.dart").is_symlink())
            self.assertEqual((workspace / "pubspec.lock").read_text(), "ohos lock\n")
            self.assertEqual(
                (workspace / "pubspec_overrides.yaml").read_text(),
                "dependency_overrides: {}\n",
            )
            workspace_pubspec = (workspace / "pubspec.yaml").read_text()
            self.assertIn("  flutter_secure_storage_ohos:\n", workspace_pubspec)
            self.assertIn(f'      ref: "{"a" * 40}"\n', workspace_pubspec)
            self.assertNotIn("  device_info_plus:", workspace_pubspec)
            self.assertEqual(
                (workspace / "lib/utils/mobile_device_info.dart").read_text(),
                "Future<void> deviceInfo() async {}\n",
            )
            self.assertEqual((workspace / "lib/main.dart").read_text(), "patched source\n")
            self.assertEqual(
                (workspace / "test/ohos/platform_adapters_test.dart").read_text(),
                "void main() {}\n",
            )
            self.assertEqual(
                (
                    workspace / "test/ohos/support/memory_course_database.dart"
                ).read_text(),
                "class MemoryCourseDatabase {}\n",
            )
            self.assertFalse((workspace / "test/course_copy_mode_test.dart").exists())
            self.assertFalse((workspace / "test/course_duplicate_test.dart").exists())
            self.assertFalse(
                (workspace / "test/theme_page_transitions_test.dart").exists()
            )
            self.assertIn(
                "OH copy test",
                (workspace / "test/ohos/course_copy_mode_test.dart").read_text(),
            )
            self.assertIn(
                "OH duplicate test",
                (workspace / "test/ohos/course_duplicate_test.dart").read_text(),
            )
            self.assertIn(
                "OH theme test",
                (
                    workspace / "test/ohos/theme_page_transitions_test.dart"
                ).read_text(),
            )
            self.assertFalse((root / "test/ohos/platform_adapters_test.dart").exists())
            self.assertFalse((root / "lib/utils/mobile_device_info.dart").exists())
            self.assertFalse((workspace / ".git").exists())
            self.assertFalse((workspace / "ohos/flutter/overrides").exists())
            self.assertTrue((workspace / "assets/libs/data.txt").is_file())
            self.assertFalse((workspace / "ohos/local.properties").exists())
            self.assertFalse((workspace / "ohos").exists())
            self.assertFalse((workspace / "ohos/node_modules").exists())
            self.assertFalse((workspace / "ohos/.hvigor").exists())
            self.assertFalse((workspace / "ohos/build").exists())
            self.assertFalse((workspace / ".dart_tool").exists())
            self.assertFalse(
                (workspace / "ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets").exists()
            )
            # Writing generated code must not change the root's tracked output.
            (workspace / "lib/models/example.g.dart").write_text("OH generated source\n")
            for name, content in files.items():
                self.assertEqual((root / name).read_text(), content, name)

            second_workspace = build_ohos.prepare_workspace(root)
            self.assertEqual(workspace, second_workspace)
            self.assertEqual((second_workspace / "lib/main.dart").read_text(), "patched source\n")
            self.assertEqual(
                (second_workspace / "lib/models/example.g.dart").read_text(), "OH generated source\n",
            )
            (root / "lib/shared.dart").write_text("updated shared source\n")
            self.assertEqual((workspace / "lib/shared.dart").read_text(), "updated shared source\n")
            (root / "ohos/flutter/overrides/lib/main.dart").write_text("updated OH source\n")
            self.assertEqual((workspace / "lib/main.dart").read_text(), "updated OH source\n")

            # Removing an OH override restores the shared file at the same URI.
            manifest_path = root / "ohos/flutter/source-manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["files"] = []
            manifest_path.write_text(json.dumps(manifest))
            (root / "ohos/flutter/overrides/lib/main.dart").unlink()
            (root / "ohos/flutter/overrides/lib/utils/mobile_device_info.dart").unlink()
            (root / "ohos/tests/flutter/platform_adapters_test.dart.template").unlink()
            build_ohos.prepare_workspace(root)
            self.assertEqual((workspace / "lib/main.dart").resolve(), root / "lib/main.dart")
            self.assertFalse((workspace / "lib/utils/mobile_device_info.dart").is_symlink())
            self.assertFalse((workspace / "test/ohos/platform_adapters_test.dart").is_symlink())

    def test_flutter_secure_storage_patch_is_exact_and_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            package = workspace / "cache/flutter_secure_storage"
            files = {
                package / "pubspec.yaml": "name: flutter_secure_storage\nversion: 9.2.4\n",
                package / "lib/flutter_secure_storage.dart": (
                    "    } else {\n"
                    "      throw UnsupportedError(UNSUPPORTED_PLATFORM);\n"
                    "    }\n"
                ),
                package / "lib/options/macos_options.dart": (
                    "    bool useDataProtectionKeyChain = true,\n"
                    "  })  : _useDataProtectionKeyChain = useDataProtectionKeyChain,\n"
                ),
            }
            for path, content in files.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            config = workspace / ".dart_tool/package_config.json"
            config.parent.mkdir(parents=True)
            config.write_text(
                json.dumps(
                    {
                        "packages": [
                            {
                                "name": "flutter_secure_storage",
                                "rootUri": package.as_uri(),
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )

            build_ohos.patch_flutter_secure_storage(workspace)
            build_ohos.patch_flutter_secure_storage(workspace)

            storage = (package / "lib/flutter_secure_storage.dart").read_text()
            macos = (package / "lib/options/macos_options.dart").read_text()
            self.assertEqual(storage.count("return <String, String>{};"), 1)
            self.assertEqual(macos.count("bool? usesDataProtectionKeychain,"), 1)
            self.assertIn(
                "usesDataProtectionKeychain ?? useDataProtectionKeyChain", macos,
            )

    def test_flutter_secure_storage_patch_rejects_other_versions(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            package = workspace / "package"
            package.mkdir()
            (package / "pubspec.yaml").write_text(
                "name: flutter_secure_storage\nversion: 9.2.3\n",
                encoding="utf-8",
            )
            config = workspace / ".dart_tool/package_config.json"
            config.parent.mkdir(parents=True)
            config.write_text(
                json.dumps(
                    {
                        "packages": [
                            {
                                "name": "flutter_secure_storage",
                                "rootUri": package.as_uri(),
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaises(ValueError):
                build_ohos.patch_flutter_secure_storage(workspace)

    def test_required_ohos_plugins_must_be_resolved(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            metadata = workspace / ".flutter-plugins-dependencies"
            metadata.write_text(
                json.dumps(
                    {
                        "plugins": {
                            "ohos": [
                                {"name": name}
                                for name in build_ohos.REQUIRED_OHOS_PLUGINS
                            ]
                        }
                    }
                ),
                encoding="utf-8",
            )
            build_ohos.validate_ohos_plugins(workspace)
            for missing in build_ohos.REQUIRED_OHOS_PLUGINS:
                with self.subTest(missing=missing):
                    metadata.write_text(
                        json.dumps(
                            {
                                "plugins": {
                                    "ohos": [
                                        {"name": name}
                                        for name in build_ohos.REQUIRED_OHOS_PLUGINS
                                        if name != missing
                                    ]
                                }
                            }
                        ),
                        encoding="utf-8",
                    )
                    with self.assertRaisesRegex(ValueError, missing):
                        build_ohos.validate_ohos_plugins(workspace)

    def test_harmony_api_and_deveco_tool_versions_are_locked(self):
        expected = {
            "apiVersion": "26",
            "sdkVersion": "26.0.0.105",
            "releaseType": "Release",
            "devecoStudioVersion": "26.0.0.821",
            "hvigorVersion": "6.26.4",
            "ohpmVersion": "26.0.0.630",
            "nodeVersion": "v24.14.1",
        }
        with tempfile.TemporaryDirectory() as directory:
            deveco = Path(directory) / "DevEco Studio"
            sdk = deveco / "sdk"
            files = {
                "sdk/default/openharmony/ets/oh-uni-package.json": {
                    "apiVersion": "26",
                    "version": "26.0.0.105",
                    "releaseType": "Release",
                },
                "product-info.json": {"version": "26.0.0.821"},
                "tools/hvigor/hvigor/package.json": {"version": "6.26.4"},
                "tools/ohpm/package.json": {"version": "26.0.0.630"},
            }
            for name, content in files.items():
                path = deveco / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(content), encoding="utf-8")
            node_name = "node.exe" if build_ohos.os.name == "nt" else "node"
            node = deveco / "tools" / "node" / node_name
            node.parent.mkdir(parents=True)
            node.touch()
            hvigor_name = "hvigorw.bat" if build_ohos.os.name == "nt" else "hvigorw"
            hvigor = deveco / "tools" / "hvigor" / "bin" / hvigor_name
            hvigor.parent.mkdir(parents=True)
            hvigor.touch()

            with (
                patch.object(build_ohos, "command_output", return_value="v24.14.1"),
                patch.object(build_ohos.shutil, "which", return_value=str(hvigor)),
            ):
                self.assertEqual(
                    build_ohos.validate_harmony_toolchain(sdk, expected), deveco,
                )

    def test_workspace_version_is_synced_without_modifying_the_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_pubspec = root / "pubspec.yaml"
            source_app = root / "ohos/AppScope/app.json5"
            source_pubspec.parent.mkdir(parents=True, exist_ok=True)
            source_app.parent.mkdir(parents=True, exist_ok=True)
            source_pubspec.write_text(
                "name: example\nversion: 2.5.1+20501\n", encoding="utf-8",
            )
            source_app.write_text(
                json.dumps(
                    {"app": {"versionName": "2.2.0", "versionCode": 3}},
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            workspace = root / "ohos/.flutter-workspace"
            workspace_pubspec = workspace / "pubspec.yaml"
            workspace_pubspec.parent.mkdir(parents=True, exist_ok=True)
            workspace_pubspec.write_text(source_pubspec.read_text(encoding="utf-8"))

            self.assertEqual(
                build_ohos.sync_workspace_version(root, workspace),
                ("2.5.1", 20501),
            )
            self.assertFalse((workspace / "ohos").exists())
            self.assertEqual(
                json.loads(source_app.read_text(encoding="utf-8"))["app"],
                {"versionName": "2.2.0", "versionCode": 3},
            )

    def test_missing_or_malformed_pubspec_version_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            missing = root / "missing.yaml"
            malformed = root / "malformed.yaml"
            malformed.write_text("name: example\nversion: 2.5.1\n", encoding="utf-8")
            for pubspec in (missing, malformed):
                with self.subTest(pubspec=pubspec), self.assertRaises(ValueError):
                    build_ohos.read_pubspec_version(pubspec)

    def test_workspace_pubspec_version_must_match_the_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            workspace = root / "ohos/.flutter-workspace"
            files = {
                root / "pubspec.yaml": "version: 2.5.1+20501\n",
                workspace / "pubspec.yaml": "version: 2.5.0+20500\n",
            }
            for path, content in files.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            with self.assertRaises(ValueError):
                build_ohos.sync_workspace_version(root, workspace)

    def test_hap_version_must_match_the_root_pubspec(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            files = {
                "pubspec.yaml": "name: example\nversion: 2.5.1+20501\n",
                "ohos/AppScope/app.json5": json.dumps(
                    {"app": {"versionName": "2.5.1", "versionCode": 20501}}
                ),
            }
            for name, content in files.items():
                path = workspace / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            hap = workspace / "ohos/entry/build/default/outputs/default/entry.hap"
            hap.parent.mkdir(parents=True)
            with zipfile.ZipFile(hap, "w") as archive:
                archive.writestr(
                    "pack.info",
                    json.dumps(
                        {"summary": {"app": {"version": {"name": "2.5.1", "code": 20501}}}}
                    ),
                )
            self.assertEqual(build_ohos.verify_hap_version(workspace, hap), hap)

    def test_unsigned_hap_is_required_from_a_successful_build(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            hap = workspace / "entry/build/default/outputs/default/entry-default-unsigned.hap"
            hap.parent.mkdir(parents=True)
            hap.touch()
            with patch.object(build_ohos, "run") as run:
                self.assertEqual(
                    build_ohos.build_hap(["hvigorw", "assembleHap"], workspace, {}),
                    hap,
                )
                run.assert_called_once_with(
                    ["hvigorw", "assembleHap"], workspace, {},
                )

    def test_failed_hap_build_is_not_hidden_by_an_unsigned_artifact(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            hap = workspace / "entry/build/default/outputs/default/entry-default-unsigned.hap"
            hap.parent.mkdir(parents=True)
            hap.touch()
            error = build_ohos.subprocess.CalledProcessError(
                1, ["hvigorw", "assembleHap"],
            )
            with (
                patch.object(build_ohos, "run", side_effect=error),
                self.assertRaises(build_ohos.subprocess.CalledProcessError),
            ):
                build_ohos.build_hap(["hvigorw", "assembleHap"], workspace, {})

    def test_missing_platform_lockfile_fails_before_creating_workspace(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(ValueError):
                build_ohos.prepare_workspace(root)
            self.assertFalse((root / "ohos/.flutter-workspace").exists())

    def test_normal_resolution_enforces_the_platform_lockfile(self):
        with patch.object(build_ohos, "run") as run:
            build_ohos.resolve_dependencies("flutter", Path("workspace"), {})
            run.assert_called_once_with(
                ["flutter", "pub", "get", "--no-example", "--enforce-lockfile"],
                Path("workspace"), {},
            )

    def test_explicit_lock_update_allows_dependency_resolution(self):
        with patch.object(build_ohos, "run") as run:
            build_ohos.resolve_dependencies("flutter", Path("workspace"), {}, True)
            run.assert_called_once_with(
                ["flutter", "pub", "get", "--no-example"], Path("workspace"), {},
            )


if __name__ == "__main__":
    unittest.main()
