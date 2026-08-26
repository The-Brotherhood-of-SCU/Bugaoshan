import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]


class ReleaseWorkflowTest(unittest.TestCase):
    def test_macos_download_points_to_apple_mirror_release(self):
        release_body = (
            REPOSITORY_ROOT / ".github/scripts/release_body.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "https://github.com/Visio-Vanitas/Bugaoshan/releases/download/"
            "v{version}/bugaoshan_{version}_macos_arm64.dmg",
            release_body,
        )

    def test_linux_release_artifacts_removed(self):
        workflow = (REPOSITORY_ROOT / ".github/workflows/release.yml").read_text(
            encoding="utf-8"
        )
        prepare_script = (
            REPOSITORY_ROOT / ".github/scripts/release_prepare.py"
        ).read_text(encoding="utf-8")
        release_body = (
            REPOSITORY_ROOT / ".github/scripts/release_body.py"
        ).read_text(encoding="utf-8")

        self.assertNotIn("build-linux", workflow)
        self.assertNotIn("linux-release", workflow)
        self.assertNotIn("linux-release.tar.gz", prepare_script)
        self.assertNotIn("linux_x64", release_body)


if __name__ == "__main__":
    unittest.main()
