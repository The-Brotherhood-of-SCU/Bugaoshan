"""Tests for release artifact preparation."""

import tempfile
import unittest
from pathlib import Path

import release_prepare


class ReleasePrepareTest(unittest.TestCase):
    def test_keeps_universal_and_split_android_packages(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            android_dir = root / "android-apk"
            windows_dir = root / "windows-release"
            linux_dir = root / "linux-release"
            android_dir.mkdir()
            windows_dir.mkdir()
            linux_dir.mkdir()

            packages = {
                "app-universal-release.apk": b"universal",
                "app-arm64-v8a-release.apk": b"arm64",
                "app-armeabi-v7a-release.apk": b"armv7",
                "app-x86_64-release.apk": b"x64",
            }
            for name, content in packages.items():
                (android_dir / name).write_bytes(content)
            (windows_dir / "windows-release.zip").write_bytes(b"windows")
            (linux_dir / "linux-release.tar.gz").write_bytes(b"linux")

            release_prepare.prepare_release_files("v2.2.0", root=root)

            expected = {
                "bugaoshan_2.2.0_universal.apk": b"universal",
                "bugaoshan_2.2.0_arm64-v8a.apk": b"arm64",
                "bugaoshan_2.2.0_armeabi-v7a.apk": b"armv7",
                "bugaoshan_2.2.0_x86_64.apk": b"x64",
            }
            for name, content in expected.items():
                self.assertEqual((root / name).read_bytes(), content)

    def test_requires_the_universal_updater_package(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            android_dir = root / "android-apk"
            windows_dir = root / "windows-release"
            android_dir.mkdir()
            windows_dir.mkdir()
            (android_dir / "app-arm64-v8a-release.apk").write_bytes(b"arm64")
            (windows_dir / "windows-release.zip").write_bytes(b"windows")

            with self.assertRaises(FileNotFoundError):
                release_prepare.prepare_release_files("v2.2.0", root=root)


if __name__ == "__main__":
    unittest.main()
