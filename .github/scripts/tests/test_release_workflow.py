import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]


class ReleaseWorkflowTest(unittest.TestCase):
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
            "needs: [ build-android, build-windows, build-linux, build-macos, build-ios ]",
            workflow,
        )
        self.assertIn("name: linux-release", workflow)
        self.assertIn("path: linux-release", workflow)

        # 发布正文固定提供 Linux 链接，因此制品缺失必须令准备步骤失败，
        # 不能静默跳过后继续发布一个失效链接。
        self.assertNotIn("if os.path.exists(linux_src)", prepare_script)
        self.assertNotIn("Skipped linux artifact", prepare_script)

    def test_apple_artifacts_are_built_and_released(self):
        workflow = (REPOSITORY_ROOT / ".github/workflows/release.yml").read_text(
            encoding="utf-8"
        )
        prepare_script = (
            REPOSITORY_ROOT / ".github/scripts/release_prepare.py"
        ).read_text(encoding="utf-8")

        self.assertIn("uses: ./.github/workflows/build-macos.yml", workflow)
        self.assertIn("uses: ./.github/workflows/build-ios.yml", workflow)
        self.assertIn("name: macos-dmg", workflow)
        self.assertIn("name: ios-ipa", workflow)
        self.assertIn("bugaoshan_*.dmg", workflow)
        self.assertIn("bugaoshan_*.ipa", workflow)
        self.assertIn("Bugaoshan.dmg", prepare_script)
        self.assertIn("Bugaoshan.ipa", prepare_script)

    def test_ios_release_can_upload_to_testflight(self):
        workflow = (REPOSITORY_ROOT / ".github/workflows/build-ios.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn("apple-actions/upload-testflight-build@v4", workflow)
        self.assertIn("if: inputs.upload_testflight", workflow)
        self.assertIn("wait-for-processing: \"true\"", workflow)

    def test_macos_release_downloads_developer_id_profile(self):
        workflow = (REPOSITORY_ROOT / ".github/workflows/build-macos.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn("profile-type: MAC_APP_DIRECT", workflow)
        project = (
            REPOSITORY_ROOT / "macos/Runner.xcodeproj/project.pbxproj"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'PROVISIONING_PROFILE_SPECIFIER = "Bugaoshan Developer ID";', project
        )


if __name__ == "__main__":
    unittest.main()
