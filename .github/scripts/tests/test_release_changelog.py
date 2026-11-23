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
    """预览只认 [Unreleased]，RC/正式只认基础版本章节，不做回退。"""

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

    # ── 常态预览：只使用 [Unreleased] ─────────────────

    def test_preview_uses_unreleased(self):
        self.write_changelog(
            "## [Unreleased]\n\n### Added\n- 待发布 A\n\n"
            "## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n"
        )
        out, _ = self.run_extract("v2.5.2-preview.1")
        self.assertIn("- 待发布 A", out)
        self.assertNotIn("修复 B", out)

    def test_preview_does_not_use_version_section(self):
        self.write_changelog(
            "## [2.5.2]\n\n### Added\n- 目标版本\n\n"
            "## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n"
        )
        out, warn = self.run_extract("v2.5.2-preview.1")
        self.assertIn("No changelog entry", out)
        self.assertNotIn("目标版本", out)
        self.assertIn("::warning::", warn)

    def test_preview_empty_unreleased_gets_placeholder_and_warning(self):
        self.write_changelog(
            "## [Unreleased]\n\n### Added\n\n"
            "## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n"
        )
        out, warn = self.run_extract("v2.5.2-preview.1")
        self.assertIn("No changelog entry", out)
        self.assertNotIn("修复 B", out)
        self.assertIn("::warning::", warn)

    # ── RC：只使用基础版本章节 ───────────────────────

    def test_rc_uses_base_version_section(self):
        self.write_changelog(
            "## [2.5.2] - 2026-11-10\n\n### Fixed\n- 目标版本说明\n\n"
            "## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n"
        )
        out, _ = self.run_extract("v2.5.2-rc")
        self.assertIn("- 目标版本说明", out)
        self.assertNotIn("修复 B", out)

    def test_rc_ignores_unreleased(self):
        self.write_changelog(
            "## [Unreleased]\n\n### Added\n- 待发布 A\n\n"
            "## [2.5.2] - 2026-11-10\n\n### Added\n- 目标版本说明\n"
        )
        out, _ = self.run_extract("v2.5.2-rc1")
        self.assertIn("- 目标版本说明", out)
        self.assertNotIn("- 待发布 A", out)

    def test_rc_missing_base_fails(self):
        self.write_changelog("## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n")
        with self.assertRaises(SystemExit) as ctx:
            self.run_extract("v2.5.2-rc")
        self.assertEqual(ctx.exception.code, 1)
        self.assertIn("## [2.5.2]", self.stderr.getvalue())

    def test_rc_empty_base_fails(self):
        self.write_changelog("## [2.5.2]\n\n### Fixed\n\n## [2.5.1]\n\n- old\n")
        with self.assertRaises(SystemExit) as ctx:
            self.run_extract("v2.5.2-rc")
        self.assertEqual(ctx.exception.code, 1)
        self.assertIn("empty", self.stderr.getvalue())

    def test_rc_does_not_use_legacy_exact_rc_section(self):
        self.write_changelog(
            "## [2.5.2-rc]\n\n- 旧 RC 说明\n\n"
            "## [2.5.2]\n\n- 目标版本说明\n"
        )
        out, _ = self.run_extract("v2.5.2-rc")
        self.assertIn("- 目标版本说明", out)
        self.assertNotIn("旧 RC 说明", out)

    # ── 正式版：只使用精确版本章节 ───────────────────

    def test_formal_uses_matching_section(self):
        self.write_changelog(
            "## [Unreleased]\n\n- 未发布\n\n"
            "## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n"
        )
        out, _ = self.run_extract("v2.5.1")
        self.assertIn("- 修复 B", out)
        self.assertNotIn("未发布", out)

    def test_formal_missing_section_fails(self):
        self.write_changelog("## [2.5.0]\n\n- old\n")
        with self.assertRaises(SystemExit) as ctx:
            self.run_extract("v2.5.1")
        self.assertEqual(ctx.exception.code, 1)
        self.assertIn("::error::Changelog entry in ## [2.5.1] is missing.", self.stderr.getvalue())

    def test_formal_empty_section_fails(self):
        self.write_changelog("## [2.5.1] - 2026-09-11\n\n### Fixed\n")
        with self.assertRaises(SystemExit) as ctx:
            self.run_extract("v2.5.1")
        self.assertEqual(ctx.exception.code, 1)
        self.assertIn("empty", self.stderr.getvalue())

    # ── 结构 ────────────────────────────────────────

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

    def test_invalid_version_fails_before_selecting_content(self):
        self.write_changelog("## [2.5.1]\n- A\n")
        with self.assertRaises(SystemExit):
            self.run_extract("")
        self.assertIn("Invalid release version", self.stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
