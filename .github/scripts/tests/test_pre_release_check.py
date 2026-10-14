import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tool"))

import pre_release_check


class PreReleaseChangelogTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.patch = mock.patch.object(pre_release_check, "ROOT", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        (self.root / "pubspec.yaml").write_text("version: 2.5.1+20501\n", encoding="utf-8")

    def check(self, text, version, **kwargs):
        (self.root / "CHANGELOG.md").write_text(text, encoding="utf-8")
        checker = pre_release_check.Checker(version, **kwargs)
        checker.check_changelog()
        return checker.results

    def test_matching_formal_or_preview_needs_no_placeholder_section(self):
        text = "## [2.5.2-preview.2]\n- preview\n## [2.5.1]\n- formal\n"
        for version in ("2.5.1", "2.5.2-preview.2"):
            with self.subTest(version=version):
                results = self.check(text, version)
                self.assertTrue(any(s == "OK" and n == "CHANGELOG.md" for s, n, _ in results))
                self.assertFalse(any(s == "FAIL" for s, _, _ in results))

    def test_missing_preview_warns_in_ci_but_fails_strict_check(self):
        text = "## [2.5.1]\n- old\n"
        for ci, expected in ((True, "WARN"), (False, "FAIL")):
            with self.subTest(ci=ci):
                results = self.check(text, "2.5.2-rc1", ci=ci)
                self.assertEqual(results[0][0], expected)
                self.assertIn("[2.5.2-rc1]", results[0][2])

    def test_missing_formal_fails_even_in_ci(self):
        results = self.check("## [2.5.2-preview]\n- preview\n", "2.5.2", ci=True)
        self.assertEqual(results[0][0], "FAIL")

    def test_empty_target_does_not_borrow_other_content(self):
        results = self.check("## [2.5.2]\n### Fixed\n## [2.5.1]\n- old\n", "2.5.2")
        self.assertEqual(results[0][0], "FAIL")

    def test_structure_only_accepts_history_without_guessing_future_tag(self):
        results = self.check(
            "## [2.5.1]\n- old\n", "2.5.1-prerelease", ci=True, changelog_structure_only=True
        )
        self.assertEqual(results[0][0], "OK")
        self.assertIn("1 个版本章节", results[0][2])

    def test_duplicate_and_invalid_dates_fail_even_in_structure_only_mode(self):
        for text in (
            "## [2.5.1]\n- A\n## [2.5.1]\n- B\n",
            "## [2.5.1] - 2026-02-30\n- A\n",
        ):
            with self.subTest(text=text):
                results = self.check(text, "2.5.1-prerelease", ci=True, changelog_structure_only=True)
                self.assertEqual(results[0][0], "FAIL")

    def test_structure_only_skips_checks_for_a_fabricated_tag(self):
        checker = pre_release_check.Checker("2.5.1-prerelease", ci=True, changelog_structure_only=True)
        with mock.patch.object(checker, "run") as run:
            checker.check_tag_not_exists()
        run.assert_not_called()

    def test_cli_requires_full_preview_target_outside_daily_ci(self):
        with mock.patch.object(pre_release_check, "_try_reconfigure_encoding"), contextlib.redirect_stderr(io.StringIO()):
            for args in (("--ci", "--prerelease"), ("2.5.2", "--prerelease"), ("--changelog-structure-only",)):
                with self.subTest(args=args), self.assertRaises(SystemExit):
                    pre_release_check.main(list(args))


if __name__ == "__main__":
    unittest.main()
