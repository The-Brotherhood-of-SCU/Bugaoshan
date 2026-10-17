import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import release_changelog


class ReleaseChangelogTest(unittest.TestCase):
    """Every channel selects its exact version, without borrowing other notes."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        (self.root / "CHANGELOG.md").write_text("", encoding="utf-8")
        self._old_cwd = os.getcwd()
        os.chdir(self.root)
        self._old_env = {k: os.environ.get(k) for k in ("VERSION", "GITHUB_OUTPUT")}

    def tearDown(self):
        os.chdir(self._old_cwd)
        for k, v in self._old_env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        self.temp_dir.cleanup()

    def write_changelog(self, text):
        (self.root / "CHANGELOG.md").write_text(text, encoding="utf-8")

    def run_extract(self, version):
        os.environ["VERSION"] = version
        output = self.root / "github_output.txt"
        if output.exists():
            output.unlink()
        os.environ["GITHUB_OUTPUT"] = str(output)
        stdout = io.StringIO()
        self.stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(self.stderr):
            release_changelog.main()
        return output.read_text(encoding="utf-8"), stdout.getvalue()

    CHANGELOG_WITH_SECTIONS = (
        "## [2.5.2-rc] - 2026-10-14\n\n### Fixed\n- RC 修复\n\n"
        "## [2.5.2-preview.1]\n"
        "\n"
        "### Added\n"
        "- 新功能 A\n"
        "\n"
        "## [2.5.1] - 2026-09-11\n"
        "\n"
        "### Fixed\n"
        "- 修复 B\n"
    )

    def test_prerelease_uses_exact_version_section(self):
        self.write_changelog(self.CHANGELOG_WITH_SECTIONS)
        out, _ = self.run_extract("v2.5.2-preview.1")
        self.assertIn("- 新功能 A", out)
        self.assertNotIn("修复 B", out)
        self.assertNotIn("RC 修复", out)

    def test_prerelease_empty_section_gets_placeholder_and_warning(self):
        self.write_changelog("## [2.5.2-preview.1]\n\n### Fixed\n\n## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n")
        out, warn = self.run_extract("v2.5.2-preview.1")
        self.assertIn("No changelog entry", out)
        self.assertNotIn("修复 B", out)
        self.assertIn("::warning::", warn)

    def test_missing_rc_never_borrows_formal_or_other_preview(self):
        self.write_changelog("## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n")
        out, warn = self.run_extract("v2.5.2-rc")
        self.assertIn("No changelog entry", out)
        self.assertNotIn("修复 B", out)
        self.assertIn("::warning::", warn)

    def test_rc_uses_its_own_section(self):
        self.write_changelog(self.CHANGELOG_WITH_SECTIONS)
        out, _ = self.run_extract("v2.5.2-rc")
        self.assertIn("RC 修复", out)
        self.assertNotIn("新功能 A", out)
        self.assertNotIn("修复 B", out)

    def test_formal_uses_matching_section(self):
        self.write_changelog(self.CHANGELOG_WITH_SECTIONS)
        out, _ = self.run_extract("v2.5.1")
        self.assertIn("- 修复 B", out)
        self.assertNotIn("新功能 A", out)

    def test_formal_missing_section_fails(self):
        self.write_changelog(self.CHANGELOG_WITH_SECTIONS)
        with self.assertRaises(SystemExit) as ctx:
            self.run_extract("v9.9.9")
        self.assertEqual(ctx.exception.code, 1)
        self.assertIn(
            "::error::Changelog entry for 9.9.9 is missing.",
            self.stderr.getvalue(),
        )

    def test_formal_empty_section_fails(self):
        self.write_changelog("## [2.5.2-preview.1]\n\n- 预览内容\n\n## [2.5.1] - 2026-09-11\n")
        with self.assertRaises(SystemExit) as ctx:
            self.run_extract("v2.5.1")
        self.assertEqual(ctx.exception.code, 1)
        self.assertIn(
            "::error::Changelog entry for 2.5.1 is empty.",
            self.stderr.getvalue(),
        )

    def test_duplicate_version_fails_instead_of_picking_one(self):
        self.write_changelog("## [2.5.1]\n- A\n## [2.5.1]\n- B\n")
        with self.assertRaises(SystemExit):
            self.run_extract("v2.5.1")
        self.assertIn("Duplicate changelog section", self.stderr.getvalue())

    def test_code_example_heading_does_not_end_version_section(self):
        self.write_changelog(
            "## [2.5.1]\n- A\n```markdown\n## [9.9.9]\nexample\n```\n- B\n"
            "## [2.5.0]\n- old\n"
        )
        out, _ = self.run_extract("v2.5.1")
        self.assertIn("- B", out)
        self.assertNotIn("- old", out)

    def test_version_prefix_does_not_match_another_preview_sequence(self):
        self.write_changelog("## [2.5.2-preview.10]\n- other\n")
        out, _ = self.run_extract("v2.5.2-preview.1")
        self.assertIn("No changelog entry", out)
        self.assertNotIn("- other", out)

    def test_invalid_version_fails_before_selecting_content(self):
        self.write_changelog(self.CHANGELOG_WITH_SECTIONS)
        with self.assertRaises(SystemExit):
            self.run_extract("")
        self.assertIn("Invalid release version", self.stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
