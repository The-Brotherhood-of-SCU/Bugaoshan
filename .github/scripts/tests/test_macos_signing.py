"""Release integrity checks reject wrong sources, unsigned fallbacks and tampering."""

import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import call, patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tool"))
sys.path.insert(0, str(ROOT / ".github/scripts"))
import macos_dmg
import macos_signing
import release_prepare


class MacDistributionTest(unittest.TestCase):
    def test_stapler_recovers_from_transient_network_failures(self):
        for path in [Path("test.app"), Path("test.dmg")]:
            with self.subTest(path=path), patch.object(
                macos_dmg, "run", side_effect=[RuntimeError("-1005"), RuntimeError("-1005"), "stapled"]
            ) as run, patch.object(macos_dmg.time, "sleep") as sleep:
                self.assertEqual(macos_dmg.staple(path), "stapled")
                self.assertEqual(run.call_args_list, [call("xcrun", "stapler", "staple", path)] * 3)
                self.assertEqual(sleep.call_args_list, [call(10), call(20)])

    def test_stapler_stops_after_three_failures(self):
        with patch.object(macos_dmg, "run", side_effect=RuntimeError("staple failed")) as run, \
                patch.object(macos_dmg.time, "sleep") as sleep:
            with self.assertRaisesRegex(RuntimeError, "staple failed"):
                macos_dmg.staple(Path("test.dmg"))
            self.assertEqual(run.call_count, 3)
            self.assertEqual(sleep.call_count, 2)

    def test_stapler_success_does_not_retry(self):
        with patch.object(macos_dmg, "run", return_value="stapled") as run, \
                patch.object(macos_dmg.time, "sleep") as sleep:
            self.assertEqual(macos_dmg.staple(Path("test.app")), "stapled")
            run.assert_called_once()
            sleep.assert_not_called()

    def test_source_and_payload_integrity(self):
        with tempfile.TemporaryDirectory() as temporary:
            dmg = Path(temporary) / macos_dmg.asset_name("v2.5.4-preview.13")
            dmg.write_bytes(b"notarized-test-fixture")
            manifest = {"schema": 1, "source_repository": macos_dmg.SOURCE_REPOSITORY,
                        "source_tag": "v2.5.4-preview.13", "source_sha": "a" * 40,
                        "version": "2.5.3", "build": "20503", "team_id": macos_dmg.TEAM_ID,
                        "asset": dmg.name, "notarization_status": "Accepted", "notarization_id": "receipt",
                        "sha256": hashlib.sha256(dmg.read_bytes()).hexdigest()}
            args = (dmg, "v2.5.4-preview.13", "a" * 40, "2.5.3", "20503")
            macos_dmg.check_manifest(manifest, *args)
            for key, wrong in [("source_sha", "b" * 40), ("source_tag", "v2.5.3"),
                               ("team_id", "OTHER"), ("build", "20504"),
                               ("notarization_status", "In Progress"), ("source_repository", "other/repo")]:
                with self.subTest(key=key), self.assertRaises(ValueError):
                    macos_dmg.check_manifest(dict(manifest, **{key: wrong}), *args)
            dmg.write_bytes(b"tampered")
            with self.assertRaisesRegex(ValueError, "checksum"):
                macos_dmg.check_manifest(manifest, *args)

    def test_invalid_tag_cannot_be_used_as_asset_path(self):
        for tag in ["../../file", "v1.2.3/evil", "--help", "v1.2.3\n"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                macos_dmg.asset_name(tag)

    def test_missing_signed_asset_never_falls_back_to_validation_zip(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ["android-apk", "windows-release", "macos-validation-unsigned"]:
                (root / name).mkdir()
            (root / "android-apk/app-release.apk").write_bytes(b"android")
            (root / "windows-release/Bugaoshan.exe").write_bytes(b"windows")
            (root / "macos-validation-unsigned/Bugaoshan-unsigned.zip").write_bytes(b"unsigned")
            with self.assertRaises(FileNotFoundError):
                release_prepare.prepare_release_files("v2.5.3", root, macos_signed=True)
            self.assertFalse(list(root.glob("*.dmg")))

    def test_no_download_link_when_signing_is_disabled(self):
        script = ROOT / ".github/scripts/release_body.py"
        env = dict(os.environ, VERSION="v2.5.3", REPO="https://github.com/test/repo", GITHUB_OUTPUT="")
        result = subprocess.check_output([sys.executable, str(script)], env=dict(env, MACOS_SIGNED=""), text=True)
        self.assertNotIn(".dmg)", result)
        result = subprocess.check_output([sys.executable, str(script)], env=dict(env, MACOS_SIGNED="true"), text=True)
        self.assertIn("bugaoshan_2.5.3_macos_universal.dmg", result)

    def test_wait_timeout_is_a_failure_not_an_unsigned_download(self):
        args = type("Args", (), {"tag": "v2.5.3", "timeout": 0})()
        with tempfile.TemporaryDirectory() as temporary:
            args.output = Path(temporary)
            with patch.object(macos_signing, "run", return_value=subprocess.CompletedProcess([], 1, "", "404")):
                with self.assertRaises(TimeoutError):
                    macos_signing.fetch(args)

    def test_mac_store_and_dmg_use_the_explicit_mac_version_not_android_preview_version(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=source, text=True).strip()
            git("init", "-q")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            (source / ".github").mkdir()
            (source / ".github/macos-signing.json").write_text('{"schema":1,"version":"2.5.4","build":"20513"}')
            (source / "pubspec.yaml").write_text("version: 2.5.3+20503\n")
            git("add", ".")
            git("commit", "-qm", "stable")
            git("tag", "v2.5.3")
            (source / "change").write_text("preview")
            git("add", ".")
            git("commit", "-qm", "preview")
            git("tag", "v2.5.4-preview.13")
            expected_sha = git("rev-parse", "HEAD")
            git("update-ref", "refs/remotes/origin/preview", "HEAD")
            (source / "pubspec.yaml").write_text("version: 2.5.4+20504\n")
            git("add", ".")
            git("commit", "-qm", "later stable")
            git("tag", "v2.5.4")
            git("update-ref", "refs/remotes/origin/main", "HEAD")
            actual_run = macos_signing.run
            def missing_release(*args, **kwargs):
                if args[0] == "gh":
                    return subprocess.CompletedProcess(args, 1, "", "404")
                return actual_run(*args, **kwargs)
            with patch.object(macos_signing, "run", side_effect=missing_release):
                result = macos_signing.select(source, "v2.5.4-preview.13")
            self.assertEqual(result["sha"], expected_sha)
            self.assertEqual(result["version"], "2.5.4")
            self.assertEqual(result["build"], "20513")


if __name__ == "__main__":
    unittest.main()
