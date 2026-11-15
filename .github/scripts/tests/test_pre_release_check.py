import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tool"))

import pre_release_check


class PreReleaseCheckTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.patch = mock.patch.object(pre_release_check, "ROOT", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.write_pubspec("2.5.1+20501")

    def write_pubspec(self, version):
        (self.root / "pubspec.yaml").write_text(f"version: {version}\n", encoding="utf-8")

    def write_changelog(self, text):
        (self.root / "CHANGELOG.md").write_text(text, encoding="utf-8")

    def run_checks(self, text, version="", tags=("v2.5.1",), pubspec=None):
        if pubspec:
            self.write_pubspec(pubspec)
        self.write_changelog(text)
        checker = pre_release_check.Checker(version, existing_tags=list(tags))
        checker.check_changelog()
        checker.check_pubspec()
        return checker.results

    def has(self, results, status, name=None):
        return any(
            s == status and (name is None or n == name)
            for s, n, _ in results
        )

    def message(self, results, name):
        return next(message for _, n, message in results if n == name)

    # ── PR 门禁：常态 ────────────────────────────────

    def test_preview_state_passes(self):
        results = self.run_checks("## [2.5.1]\n- old\n")
        self.assertTrue(self.has(results, "OK", "CHANGELOG.md"))
        self.assertTrue(self.has(results, "OK", "pubspec.yaml 版本"))
        self.assertFalse(self.has(results, "FAIL"))

    def test_preview_with_unreleased_passes(self):
        results = self.run_checks(
            "## [Unreleased]\n- pending\n\n## [2.5.1]\n- old\n"
        )
        self.assertTrue(self.has(results, "OK", "CHANGELOG.md"))
        self.assertFalse(self.has(results, "FAIL"))

    def test_preview_empty_unreleased_warns(self):
        results = self.run_checks("## [2.5.1]\n- old\n")
        self.assertTrue(self.has(results, "WARN", "预览说明"))

    # ── PR 门禁：准备期 ──────────────────────────────

    def test_rc_state_passes(self):
        results = self.run_checks(
            "## [2.6.0]\n- target\n\n## [2.5.1]\n- old\n",
            pubspec="2.6.0+20600",
        )
        self.assertTrue(self.has(results, "OK", "CHANGELOG.md"))
        self.assertTrue(self.has(results, "OK", "pubspec.yaml 版本"))
        self.assertFalse(self.has(results, "FAIL"))

    def test_rc_with_unreleased_content_fails(self):
        results = self.run_checks(
            "## [Unreleased]\n- pending\n\n## [2.6.0]\n- target\n\n## [2.5.1]\n- old\n",
            pubspec="2.6.0+20600",
        )
        self.assertTrue(self.has(results, "FAIL", "CHANGELOG 状态"))

    def test_rc_empty_target_fails(self):
        results = self.run_checks(
            "## [2.6.0]\n\n### Fixed\n\n## [2.5.1]\n- old\n",
            pubspec="2.6.0+20600",
        )
        self.assertTrue(self.has(results, "FAIL", "CHANGELOG.md"))

    def test_multiple_unpublished_versions_fail(self):
        results = self.run_checks(
            "## [2.7.0]\n- next\n\n## [2.6.0]\n- target\n\n## [2.5.1]\n- old\n",
            pubspec="2.6.0+20600",
        )
        self.assertTrue(self.has(results, "FAIL", "CHANGELOG 状态"))

    def test_pubspec_must_match_changelog_target(self):
        results = self.run_checks(
            "## [2.6.0]\n- target\n\n## [2.5.1]\n- old\n",
            pubspec="2.5.1+20501",
        )
        self.assertTrue(self.has(results, "FAIL", "pubspec.yaml 版本"))

    def test_changelog_behind_latest_formal_fails(self):
        results = self.run_checks(
            "## [2.5.1]\n- old\n",
            tags=("v2.5.1", "v2.5.2"),
        )
        self.assertTrue(self.has(results, "FAIL", "CHANGELOG 状态"))

    def test_preview_state_skips_metadata(self):
        self.write_changelog("## [2.5.1]\n- old\n")
        checker = pre_release_check.Checker(existing_tags=["v2.5.1"])
        checker._ensure_state()
        checker.check_metadata_yml()
        checker.check_metadata_changelogs()
        self.assertTrue(self.has(checker.results, "OK", "F-Droid metadata/*.yml"))
        self.assertTrue(self.has(checker.results, "OK", "F-Droid metadata changelogs"))

    # ── 正式版严格检查 ───────────────────────────────

    def test_strict_formal_passes(self):
        results = self.run_checks(
            "## [2.5.2] - 2026-11-16\n- target\n\n## [2.5.1]\n- old\n",
            version="2.5.2",
            pubspec="2.5.2+20502",
        )
        self.assertTrue(self.has(results, "OK", "CHANGELOG.md"))
        self.assertTrue(self.has(results, "OK", "pubspec.yaml 版本"))
        self.assertFalse(self.has(results, "FAIL"))

    def test_strict_formal_missing_section_fails(self):
        results = self.run_checks(
            "## [2.5.1]\n- old\n",
            version="2.5.2",
            pubspec="2.5.2+20502",
        )
        self.assertTrue(self.has(results, "FAIL", "CHANGELOG 状态"))

    def test_strict_formal_empty_section_fails(self):
        results = self.run_checks(
            "## [2.5.2] - 2026-11-16\n\n### Fixed\n\n## [2.5.1]\n- old\n",
            version="2.5.2",
            pubspec="2.5.2+20502",
        )
        self.assertTrue(self.has(results, "FAIL", "CHANGELOG.md"))

    def test_strict_formal_rejects_unreleased_content(self):
        results = self.run_checks(
            "## [Unreleased]\n- pending\n\n## [2.5.2] - 2026-11-16\n- target\n",
            version="2.5.2",
            pubspec="2.5.2+20502",
        )
        self.assertTrue(self.has(results, "FAIL", "CHANGELOG 状态"))

    def test_strict_formal_date_warns(self):
        results = self.run_checks(
            "## [2.5.2] - 2000-01-01\n- target\n\n## [2.5.1]\n- old\n",
            version="2.5.2",
            pubspec="2.5.2+20502",
        )
        self.assertTrue(self.has(results, "WARN", "CHANGELOG 日期"))

    def test_strict_formal_rejects_changelog_highest_mismatch(self):
        results = self.run_checks(
            "## [2.5.3]\n- newer\n\n## [2.5.2]\n- target\n",
            version="2.5.2",
            pubspec="2.5.2+20502",
        )
        self.assertTrue(self.has(results, "FAIL", "CHANGELOG 状态"))

    def test_strict_formal_tag_conflict_fails(self):
        checker = pre_release_check.Checker("2.5.2", existing_tags=["v2.5.1", "v2.5.2"])
        checker.check_tag_not_exists()
        self.assertTrue(self.has(checker.results, "FAIL", "tag 冲突"))

    def test_strict_formal_version_must_increase(self):
        checker = pre_release_check.Checker("2.5.1", existing_tags=["v2.5.1"])
        checker.check_version_monotonic()
        self.assertTrue(self.has(checker.results, "FAIL", "版本号递增"))

    # ── 结构错误 ────────────────────────────────────

    def test_duplicate_and_invalid_dates_fail(self):
        for text in (
            "## [2.5.1]\n- A\n## [2.5.1]\n- B\n",
            "## [2.5.1] - 2026-02-30\n- A\n",
        ):
            with self.subTest(text=text):
                results = self.run_checks(text)
                self.assertTrue(self.has(results, "FAIL", "CHANGELOG.md"))

    # ── CLI ────────────────────────────────────────

    def test_cli_rejects_prerelease_target(self):
        with mock.patch.object(
            pre_release_check, "_try_reconfigure_encoding"
        ), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                pre_release_check.main(["2.5.2-preview"])

    def test_cli_rejects_removed_modes(self):
        with mock.patch.object(
            pre_release_check, "_try_reconfigure_encoding"
        ), contextlib.redirect_stderr(io.StringIO()):
            for args in (("--ci",), ("--prerelease",), ("--changelog-structure-only",)):
                with self.subTest(args=args), self.assertRaises(SystemExit):
                    pre_release_check.main(list(args))


if __name__ == "__main__":
    unittest.main()
