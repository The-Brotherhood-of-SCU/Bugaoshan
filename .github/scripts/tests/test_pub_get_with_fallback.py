import hashlib
import io
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPOSITORY_ROOT / ".github" / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import pub_get_with_fallback as fallback  # noqa: E402


def _make_tar_gz(files: dict[str, bytes]) -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tf:
        for name, data in files.items():
            info = tarfile.TarInfo(name=name)
            info.size = len(data)
            tf.addfile(info, io.BytesIO(data))
    return buf.getvalue()


class PubGetWithFallbackTest(unittest.TestCase):
    def test_parses_real_pubspec_lock(self):
        lockfile = REPOSITORY_ROOT / "pubspec.lock"
        packages = fallback.parse_hosted_packages(lockfile.read_text(encoding="utf-8"))
        self.assertGreater(len(packages), 100)
        by_name = {pkg.name: pkg for pkg in packages}
        self.assertIn("file_selector_platform_interface", by_name)
        target = by_name["file_selector_platform_interface"]
        self.assertEqual(target.version, "2.7.0")
        self.assertEqual(
            target.sha256,
            "35e0bd61ebcdb91a3505813b055b09b79dfdc7d0aee9c09a7ba59ae4bb13dc85",
        )
        self.assertEqual(target.host_dir, "pub.flutter-io.cn")

    def test_resolve_pub_cache_dir_respects_env_and_os(self):
        self.assertEqual(
            fallback.resolve_pub_cache_dir({"PUB_CACHE": "/custom/cache"}, os_name="posix"),
            Path("/custom/cache"),
        )
        self.assertEqual(
            fallback.resolve_pub_cache_dir(
                {"LOCALAPPDATA": "/win/appdata"}, os_name="nt"
            ),
            Path("/win/appdata/Pub/Cache"),
        )

    def test_install_archive_verifies_sha256_and_marks_cached(self):
        archive = _make_tar_gz(
            {
                "pubspec.yaml": b"name: demo_pkg\nversion: 1.2.3\n",
                "lib/demo_pkg.dart": b"library demo_pkg;\n",
            }
        )
        sha256 = hashlib.sha256(archive).hexdigest()
        pkg = fallback.HostedPackage(
            name="demo_pkg",
            version="1.2.3",
            sha256=sha256,
            url="https://pub.flutter-io.cn",
        )

        with tempfile.TemporaryDirectory() as tmp:
            cache_dir = Path(tmp)
            self.assertFalse(fallback.is_package_cached(cache_dir, pkg))
            fallback.install_archive_to_cache(cache_dir, pkg, archive)
            self.assertTrue(fallback.is_package_cached(cache_dir, pkg))
            self.assertTrue(
                (
                    cache_dir
                    / "hosted"
                    / "pub.flutter-io.cn"
                    / "demo_pkg-1.2.3"
                    / "lib"
                    / "demo_pkg.dart"
                ).is_file()
            )

            # Corrupting the recorded hash invalidates the cache entry.
            hash_file = (
                cache_dir
                / "hosted-hashes"
                / "pub.flutter-io.cn"
                / "demo_pkg-1.2.3.sha256"
            )
            hash_file.write_text("0" * 64, encoding="utf-8")
            self.assertFalse(fallback.is_package_cached(cache_dir, pkg))

    def test_install_archive_rejects_mismatched_sha256(self):
        archive = _make_tar_gz({"pubspec.yaml": b"name: bad_pkg\n"})
        pkg = fallback.HostedPackage(
            name="bad_pkg",
            version="0.0.1",
            sha256="a" * 64,
            url="https://pub.flutter-io.cn",
        )
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(RuntimeError):
                fallback.install_archive_to_cache(Path(tmp), pkg, archive)

    def test_mirror_pub_dev_cache_copies_into_mirror_host(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache_dir = Path(tmp)
            src_pkg = cache_dir / "hosted" / "pub.dev" / "foo-1.0.0"
            src_pkg.mkdir(parents=True)
            (src_pkg / "pubspec.yaml").write_text("name: foo\n", encoding="utf-8")

            src_hash = cache_dir / "hosted-hashes" / "pub.dev"
            src_hash.mkdir(parents=True)
            (src_hash / "foo-1.0.0.sha256").write_text("b" * 64, encoding="utf-8")

            fallback.mirror_pub_dev_cache_to_mirror_host(
                cache_dir, mirror_host="pub.flutter-io.cn"
            )
            pkg = fallback.HostedPackage(
                name="foo",
                version="1.0.0",
                sha256="b" * 64,
                url="https://pub.flutter-io.cn",
            )
            self.assertTrue(fallback.is_package_cached(cache_dir, pkg))


if __name__ == "__main__":
    unittest.main()
