import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]


class ReleaseWorkflowTest(unittest.TestCase):
    def test_macos_download_points_to_shared_app_store_listing(self):
        release_body = (
            REPOSITORY_ROOT / ".github/scripts/release_body.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "https://apps.apple.com/app/id6813305962",
            release_body,
        )
        self.assertNotIn("macos_arm64.dmg", release_body)

    def test_release_has_no_macos_job_secrets_or_wait(self):
        workflow = (REPOSITORY_ROOT / ".github/workflows/release.yml").read_text()
        for removed in ["build-macos", "MACOS_SIGN", "macos-release", "macos-signing", "*.dmg"]:
            self.assertNotIn(removed, workflow)
        body = (REPOSITORY_ROOT / ".github/scripts/release_body.py").read_text()
        self.assertIn("https://github.com/wjlfish/Bugaoshan-macos/releases", body)

    def test_ios_download_points_to_apple_mirror_release(self):
        release_body = (
            REPOSITORY_ROOT / ".github/scripts/release_body.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "[ipa](https://github.com/Visio-Vanitas/Bugaoshan/releases/download/"
            "v{version}/bugaoshan_{version}_ios_unsigned.ipa)",
            release_body,
        )
        self.assertIn(
            "ipa仅供理解有关技术的同学测试使用，非技术背景同学请勿下载",
            release_body,
        )

    def test_linux_artifact_is_built_downloaded_and_required(self):
        workflow = (REPOSITORY_ROOT / ".github/workflows/release.yml").read_text(
            encoding="utf-8"
        )
        prepare_script = (
            REPOSITORY_ROOT / ".github/scripts/release_prepare.py"
        ).read_text(encoding="utf-8")
        release_body = (
            REPOSITORY_ROOT / ".github/scripts/release_body.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "  build-linux:\n    name: Linux Build\n    needs: resolve-metadata",
            workflow,
        )
        self.assertIn(
            "    uses: ./.github/workflows/build-linux.yml",
            workflow,
        )
        self.assertIn(
            "needs: [resolve-metadata, build-android, build-windows, build-linux]",
            workflow,
        )
        self.assertIn("name: linux-release", workflow)
        self.assertIn("path: linux-release", workflow)
        self.assertIn("bugaoshan_*.tar.gz", workflow)

        # 发布正文固定提供 Linux 链接，因此制品缺失必须令准备步骤失败，
        # 不能静默跳过后继续发布一个失效链接。
        self.assertNotIn("if os.path.exists(linux_src)", prepare_script)
        self.assertNotIn("Skipped linux artifact", prepare_script)
        self.assertIn("linux-release.tar.gz", prepare_script)
        self.assertIn("bugaoshan_{version}_linux_x64.tar.gz", release_body)


if __name__ == "__main__":
    unittest.main()
