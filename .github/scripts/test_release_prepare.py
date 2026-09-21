"""Tests for release artifact preparation."""

import tempfile
import unittest
import zipfile
from pathlib import Path

import release_prepare


class ReleasePrepareTest(unittest.TestCase):
    def test_keeps_universal_and_split_android_packages(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            android_dir = root / "android-apk"
            windows_dir = root / "windows-release"
            android_dir.mkdir()
            windows_dir.mkdir()

            packages = {
                "app-universal-release.apk": b"universal",
                "app-arm64-v8a-release.apk": b"arm64",
                "app-armeabi-v7a-release.apk": b"armv7",
                "app-x86_64-release.apk": b"x64",
            }
            for name, content in packages.items():
                (android_dir / name).write_bytes(content)
            (windows_dir / "Bugaoshan.exe").write_bytes(b"dummy content")

            release_prepare.prepare_release_files("v2.2.0", root=root)

            expected = {
                "bugaoshan_2.2.0_universal.apk": b"universal",
                "bugaoshan_2.2.0_arm64-v8a.apk": b"arm64",
                "bugaoshan_2.2.0_armeabi-v7a.apk": b"armv7",
                "bugaoshan_2.2.0_x86_64.apk": b"x64",
            }
            for name, content in expected.items():
                self.assertEqual((root / name).read_bytes(), content)
            
            windows_zip = root / "bugaoshan_2.2.0_windows_x64.zip"
            self.assertTrue(windows_zip.exists(), "Windows zip file was not created")
            
            with zipfile.ZipFile(windows_zip, 'r') as zf:
                self.assertIn("Bugaoshan.exe", zf.namelist())


    def test_requires_the_universal_updater_package(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            android_dir = root / "android-apk"
            windows_dir = root / "windows-release"
            android_dir.mkdir()
            windows_dir.mkdir()
            (android_dir / "app-arm64-v8a-release.apk").write_bytes(b"arm64")
            (windows_dir / "Bugaoshan.exe").write_bytes(b"dummy content")

            with self.assertRaises(FileNotFoundError):
                release_prepare.prepare_release_files("v2.2.0", root=root)


    def test_invalid_windows_artifact_raises_error(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            android_dir = root / "android-apk"
            windows_dir = root / "windows-release"
            android_dir.mkdir()
            windows_dir.mkdir()

            (android_dir / "app-universal-release.apk").write_bytes(b"universal")
            (android_dir / "app-release.apk").write_bytes(b"raw")

            # empty
            with self.assertRaisesRegex(FileNotFoundError, "Windows release directory is empty"):
                release_prepare.prepare_release_files("v2.2.0", root=root)

            def assert_invalid_zip_error():
                try:
                    release_prepare.prepare_release_files("v2.2.0", root=root)
                    self.fail("Expected exception was not raised.")
                except FileNotFoundError as e:
                    self.assertRegex(str(e), "Invalid Windows artifact")

            # invalid main program
            (windows_dir / "Bugaoshan.pdb").write_bytes(b"just a pdb")
            assert_invalid_zip_error()

            # nested dir
            (windows_dir / "Bugaoshan.pdb").unlink() 
            nested_dir = windows_dir / "windows-release"
            nested_dir.mkdir()
            (nested_dir / "Bugaoshan.exe").write_bytes(b"nested exe")
            assert_invalid_zip_error()


if __name__ == "__main__":
    unittest.main()
