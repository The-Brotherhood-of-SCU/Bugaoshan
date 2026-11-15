import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from resolve_release_version import (
    build_number_of,
    calculate_next_preview_tag,
    calculate_next_rc_tag,
    extract_pubspec_version,
    latest_formal,
    next_patch_version,
    resolve_release,
)


class ResolveReleaseVersionTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.pubspec = self.root / "pubspec.yaml"
        self.changelog = self.root / "CHANGELOG.md"
        self.set_pubspec_version("2.5.1")
        self.set_changelog("## [2.5.1]\n- old\n")

    def tearDown(self):
        self.temp_dir.cleanup()

    def set_pubspec_version(self, version):
        self.pubspec.write_text(f"name: bugaoshan\nversion: {version}\n", encoding="utf-8")

    def set_changelog(self, text):
        self.changelog.write_text(text, encoding="utf-8")

    def resolve(self, **kwargs):
        kwargs.setdefault("existing_tags", ["v2.5.1"])
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            result = resolve_release(
                pubspec_path=self.pubspec,
                changelog_path=self.changelog,
                **kwargs,
            )
        return result, stdout.getvalue()

    # ── 基础工具 ─────────────────────────────────────

    def test_extract_pubspec_version(self):
        self.pubspec.write_text("name: bugaoshan\nversion: 2.5.1+20501\n", encoding="utf-8")
        self.assertEqual(extract_pubspec_version(self.pubspec), "2.5.1")

    def test_build_number_formula(self):
        self.assertEqual(build_number_of("2.5.1"), "20501")
        self.assertEqual(build_number_of("2.6.0"), "20600")

    def test_next_patch_version(self):
        self.assertEqual(next_patch_version("2.5.1"), "2.5.2")

    def test_latest_formal_ignores_prerelease_tags(self):
        tag, tup = latest_formal(["v2.5.1", "v2.5.1-preview.2", "v2.4.0", "v2.5.2-rc"])
        self.assertEqual(tag, "v2.5.1")
        self.assertEqual(tup, (2, 5, 1))

    def test_calculate_next_preview_tag_first(self):
        self.assertEqual(
            calculate_next_preview_tag("2.5.1", ["v2.4.0", "v2.5.0-preview", "v2.5.0"]),
            "v2.5.1-preview",
        )

    def test_calculate_next_preview_tag_increment(self):
        self.assertEqual(
            calculate_next_preview_tag("2.5.1", ["v2.5.1-preview", "v2.5.1-preview.2", "v2.4.0"]),
            "v2.5.1-preview.3",
        )

    def test_calculate_next_rc_tag_first_and_increment(self):
        self.assertEqual(calculate_next_rc_tag("2.5.2", ["v2.5.1"]), "v2.5.2-rc")
        self.assertEqual(calculate_next_rc_tag("2.5.2", ["v2.5.1", "v2.5.2-rc"]), "v2.5.2-rc1")
        self.assertEqual(
            calculate_next_rc_tag("2.5.2", ["v2.5.1", "v2.5.2-rc", "v2.5.2-rc1"]),
            "v2.5.2-rc2",
        )

    # ── 常态预览：CHANGELOG 最高版本 == 最新正式 tag ─────

    def test_preview_anchored_to_last_formal(self):
        res, _ = self.resolve(ref_name="preview", ref_type="branch")
        self.assertEqual(res["channel"], "preview")
        self.assertEqual(res["tag"], "v2.5.2-preview")
        self.assertEqual(res["build_version"], "2.5.1")
        self.assertEqual(res["build_number"], "20501")
        self.assertEqual(res["should_release"], "true")
        self.assertEqual(res["build_only"], "false")

    def test_preview_increments_sequence(self):
        res, _ = self.resolve(
            ref_name="preview",
            ref_type="branch",
            existing_tags=["v2.5.1", "v2.5.2-preview", "v2.5.2-preview.2"],
        )
        self.assertEqual(res["tag"], "v2.5.2-preview.3")
        self.assertEqual(res["build_version"], "2.5.1")

    def test_preview_is_silent(self):
        _, out = self.resolve(ref_name="preview", ref_type="branch")
        self.assertNotIn("::warning::", out)
        self.assertNotIn("::notice::", out)

    def test_preview_allows_unreleased_notes(self):
        self.set_changelog("## [Unreleased]\n- pending\n\n## [2.5.1]\n- old\n")
        res, _ = self.resolve(ref_name="preview", ref_type="branch")
        self.assertEqual(res["tag"], "v2.5.2-preview")

    # ── 准备期：CHANGELOG 最高版本 > 最新正式 tag ────────

    def test_rc_naming_when_changelog_ahead(self):
        self.set_pubspec_version("2.5.2")
        self.set_changelog("## [2.5.2]\n- target\n\n## [2.5.1]\n- old\n")
        res, out = self.resolve(ref_name="preview", ref_type="branch")
        self.assertEqual(res["tag"], "v2.5.2-rc")
        self.assertEqual(res["build_version"], "2.5.1")
        self.assertIn("::notice::", out)

    def test_rc_increment_when_changelog_ahead(self):
        self.set_pubspec_version("2.5.2")
        self.set_changelog("## [2.5.2]\n- target\n\n## [2.5.1]\n- old\n")
        res, _ = self.resolve(
            ref_name="preview",
            ref_type="branch",
            existing_tags=["v2.5.1", "v2.5.2-rc", "v2.5.2-rc1"],
        )
        self.assertEqual(res["tag"], "v2.5.2-rc2")

    def test_rc_rejects_unreleased_content(self):
        self.set_pubspec_version("2.5.2")
        self.set_changelog(
            "## [Unreleased]\n- pending\n\n## [2.5.2]\n- target\n\n## [2.5.1]\n- old\n"
        )
        with self.assertRaises(ValueError):
            self.resolve(ref_name="preview", ref_type="branch")

    def test_multiple_unpublished_versions_fail(self):
        self.set_pubspec_version("2.5.2")
        self.set_changelog(
            "## [2.6.0]\n- next\n\n## [2.5.2]\n- target\n\n## [2.5.1]\n- old\n"
        )
        with self.assertRaises(ValueError):
            self.resolve(ref_name="preview", ref_type="branch")

    def test_changelog_behind_latest_formal_fails(self):
        with self.assertRaises(ValueError):
            self.resolve(
                ref_name="preview",
                ref_type="branch",
                existing_tags=["v2.5.1", "v2.5.2"],
            )

    def test_pubspec_must_match_changelog_target(self):
        self.set_changelog("## [2.5.2]\n- target\n\n## [2.5.1]\n- old\n")
        with self.assertRaises(ValueError):
            self.resolve(ref_name="preview", ref_type="branch")

    # ── 无正式 tag ───────────────────────────────────

    def test_no_formal_tag_uses_rc_naming(self):
        res, _ = self.resolve(
            ref_name="preview",
            ref_type="branch",
            existing_tags=[],
        )
        self.assertEqual(res["tag"], "v2.5.1-rc")
        self.assertEqual(res["build_version"], "2.5.1")

    # ── formal 通道 ─────────────────────────────────

    def test_formal_release_main_branch_new(self):
        res, _ = self.resolve(
            ref_name="main",
            ref_type="branch",
            existing_tags=["v2.4.0"],
        )
        self.assertEqual(res["channel"], "formal")
        self.assertEqual(res["tag"], "v2.5.1")
        self.assertEqual(res["is_prerelease"], "false")
        self.assertEqual(res["should_release"], "true")
        self.assertEqual(res["build_only"], "false")
        self.assertEqual(res["build_version"], "2.5.1")
        self.assertEqual(res["build_number"], "20501")
        self.assertEqual(res["release_title"], "Release v2.5.1")

    def test_formal_release_main_branch_without_new_version_skips(self):
        res, _ = self.resolve(ref_name="main", ref_type="branch")
        self.assertEqual(res["should_release"], "false")
        self.assertIn("没有新版本", res["skip_reason"])

    def test_formal_after_release_prep_bump(self):
        self.set_pubspec_version("2.5.2")
        self.set_changelog("## [2.5.2]\n- target\n\n## [2.5.1]\n- old\n")
        res, _ = self.resolve(ref_name="main", ref_type="branch")
        self.assertEqual(res["tag"], "v2.5.2")
        self.assertEqual(res["build_version"], "2.5.2")
        self.assertEqual(res["build_number"], "20502")
        self.assertEqual(res["should_release"], "true")

    # ── build_only：dispatch 于非 main/preview 分支 ────

    def test_dispatch_on_feature_branch_is_build_only(self):
        res, out = self.resolve(
            event_name="workflow_dispatch",
            ref_name="feat/foo",
            ref_type="branch",
        )
        self.assertEqual(res["build_only"], "true")
        self.assertEqual(res["should_release"], "false")
        self.assertEqual(res["tag"], "v2.5.2-preview")
        self.assertIn("::warning::", out)

    def test_dispatch_on_main_is_not_build_only(self):
        res, _ = self.resolve(
            event_name="workflow_dispatch",
            ref_name="main",
            ref_type="branch",
        )
        self.assertEqual(res["build_only"], "false")
        self.assertEqual(res["should_release"], "false")

    # ── tag 事件：按指向判定发布资格 ──────────────────

    def test_tag_on_main_head_publishes_formal(self):
        self.set_pubspec_version("2.5.2")
        res, _ = self.resolve(
            ref_type="tag",
            ref_name="v2.5.2",
            existing_tags=["v2.5.1"],
            main_head="m1",
            preview_head="p1",
            head_sha="m1",
        )
        self.assertEqual(res["channel"], "formal")
        self.assertEqual(res["build_only"], "false")
        self.assertEqual(res["should_release"], "true")
        self.assertEqual(res["build_version"], "2.5.2")

    def test_formal_tag_must_match_pubspec(self):
        with self.assertRaises(ValueError):
            self.resolve(
                ref_type="tag",
                ref_name="v2.5.2",
                existing_tags=["v2.5.1"],
                main_head="m1",
                preview_head="p1",
                head_sha="m1",
            )

    def test_formal_named_tag_on_preview_head_is_build_only(self):
        self.set_pubspec_version("2.5.2")
        res, out = self.resolve(
            ref_type="tag",
            ref_name="v2.5.2",
            existing_tags=["v2.5.1"],
            main_head="m1",
            preview_head="p1",
            head_sha="p1",
        )
        self.assertEqual(res["build_only"], "true")
        self.assertEqual(res["should_release"], "false")
        self.assertIn("::warning::", out)

    def test_rc_named_tag_on_preview_head_publishes_prerelease(self):
        res, _ = self.resolve(
            ref_type="tag",
            ref_name="v2.5.2-rc1",
            existing_tags=["v2.5.1"],
            main_head="m1",
            preview_head="p1",
            head_sha="p1",
        )
        self.assertEqual(res["channel"], "preview")
        self.assertEqual(res["is_prerelease"], "true")
        self.assertEqual(res["build_only"], "false")
        self.assertEqual(res["should_release"], "true")

    def test_tag_on_other_commit_is_build_only(self):
        self.set_pubspec_version("2.5.2")
        res, out = self.resolve(
            ref_type="tag",
            ref_name="v2.5.2",
            existing_tags=["v2.5.1"],
            main_head="m1",
            preview_head="p1",
            head_sha="deadbeef",
        )
        self.assertEqual(res["build_only"], "true")
        self.assertEqual(res["should_release"], "false")
        self.assertIn("::warning::", out)

    def test_tag_with_unresolvable_heads_is_build_only(self):
        self.set_pubspec_version("2.5.2")
        res, out = self.resolve(
            ref_type="tag",
            ref_name="v2.5.2",
            existing_tags=["v2.5.1"],
            main_head="",
            preview_head="",
            head_sha="abc123",
        )
        self.assertEqual(res["build_only"], "true")
        self.assertEqual(res["should_release"], "false")
        self.assertIn("::warning::", out)


if __name__ == "__main__":
    unittest.main()
