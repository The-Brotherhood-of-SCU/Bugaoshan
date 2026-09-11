import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from resolve_release_version import (
    calculate_next_preview_tag,
    extract_pubspec_version,
    resolve_release,
)


class ResolveReleaseVersionTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.pubspec = self.root / "pubspec.yaml"
        self.pubspec.write_text("name: bugaoshan\nversion: 2.5.1+20501\n", encoding="utf-8")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_extract_pubspec_version(self):
        ver = extract_pubspec_version(self.pubspec)
        self.assertEqual(ver, "2.5.1")

    def test_calculate_next_preview_tag_first(self):
        existing = ["v2.4.0", "v2.5.0-preview", "v2.5.0"]
        tag = calculate_next_preview_tag("2.5.1", existing)
        self.assertEqual(tag, "v2.5.1-preview")

    def test_calculate_next_preview_tag_increment(self):
        existing = ["v2.5.1-preview", "v2.5.1-preview.2", "v2.4.0"]
        tag = calculate_next_preview_tag("2.5.1", existing)
        self.assertEqual(tag, "v2.5.1-preview.3")

    def test_resolve_formal_release_main_branch_new(self):
        res = resolve_release(
            pubspec_path=self.pubspec,
            ref_name="main",
            ref_type="branch",
            existing_tags=["v2.4.0"],
        )
        self.assertEqual(res["channel"], "formal")
        self.assertEqual(res["tag"], "v2.5.1")
        self.assertEqual(res["is_prerelease"], "false")
        self.assertEqual(res["should_release"], "true")
        self.assertEqual(res["release_title"], "Release v2.5.1")

    def test_resolve_formal_release_main_branch_already_tagged(self):
        res = resolve_release(
            pubspec_path=self.pubspec,
            ref_name="main",
            ref_type="branch",
            existing_tags=["v2.5.1", "v2.4.0"],
        )
        self.assertEqual(res["channel"], "formal")
        self.assertEqual(res["tag"], "v2.5.1")
        self.assertEqual(res["should_release"], "false")
        self.assertIn("already exists", res["skip_reason"])

    def test_resolve_preview_release_preview_branch(self):
        res = resolve_release(
            pubspec_path=self.pubspec,
            ref_name="preview",
            ref_type="branch",
            existing_tags=["v2.5.1-preview"],
        )
        self.assertEqual(res["channel"], "preview")
        self.assertEqual(res["tag"], "v2.5.1-preview.2")
        self.assertEqual(res["is_prerelease"], "true")
        self.assertEqual(res["should_release"], "true")
        self.assertEqual(res["release_title"], "Preview v2.5.1-preview.2")

    def test_resolve_push_tag_formal(self):
        res = resolve_release(
            pubspec_path=self.pubspec,
            ref_name="v2.5.1",
            ref_type="tag",
            existing_tags=[],
        )
        self.assertEqual(res["channel"], "formal")
        self.assertEqual(res["tag"], "v2.5.1")
        self.assertEqual(res["is_prerelease"], "false")
        self.assertEqual(res["should_release"], "true")

    def test_resolve_push_tag_prerelease(self):
        res = resolve_release(
            pubspec_path=self.pubspec,
            ref_name="v2.5.1-rc1",
            ref_type="tag",
            existing_tags=[],
        )
        self.assertEqual(res["channel"], "preview")
        self.assertEqual(res["tag"], "v2.5.1-rc1")
        self.assertEqual(res["is_prerelease"], "true")
        self.assertEqual(res["should_release"], "true")


if __name__ == "__main__":
    unittest.main()
