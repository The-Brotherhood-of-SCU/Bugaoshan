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

    def test_linux_artifact_is_built_downloaded_and_required(self):
        workflow = (REPOSITORY_ROOT / ".github/workflows/release.yml").read_text(
            encoding="utf-8"
        )
        prepare_script = (
            REPOSITORY_ROOT / ".github/scripts/release_prepare.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "  build-linux:\n    uses: ./.github/workflows/build-linux.yml",
            workflow,
        )
        self.assertIn(
            "needs: [ build-android, build-windows, build-linux ]",
            workflow,
        )
        self.assertIn("name: linux-release", workflow)
        self.assertIn("path: linux-release", workflow)

        # 发布正文固定提供 Linux 链接，因此制品缺失必须令准备步骤失败，
        # 不能静默跳过后继续发布一个失效链接。
        self.assertNotIn("if os.path.exists(linux_src)", prepare_script)
        self.assertNotIn("Skipped linux artifact", prepare_script)


if __name__ == "__main__":
    unittest.main()
