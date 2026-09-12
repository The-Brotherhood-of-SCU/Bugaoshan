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
    """回归重点：预览/RC 的发布说明只能来自 [Unreleased] 章节，
    绝不允许在章节缺失时借用其他版本（通常是上一个正式版）的内容。"""

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
        with contextlib.redirect_stdout(stdout):
            release_changelog.main()
        return output.read_text(encoding="utf-8"), stdout.getvalue()

    CHANGELOG_WITH_SECTIONS = (
        "## [Unreleased]\n"
        "\n"
        "### Added\n"
        "- 新功能 A\n"
        "\n"
        "## [2.5.1] - 2026-09-11\n"
        "\n"
        "### Fixed\n"
        "- 修复 B\n"
    )

    def test_prerelease_uses_unreleased_section(self):
        self.write_changelog(self.CHANGELOG_WITH_SECTIONS)
        out, _ = self.run_extract("v2.5.2-preview.1")
        self.assertIn("- 新功能 A", out)
        self.assertNotIn("修复 B", out)

    def test_prerelease_empty_unreleased_gets_placeholder_and_warning(self):
        self.write_changelog("## [Unreleased]\n\n## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n")
        out, warn = self.run_extract("v2.5.2-preview.1")
        self.assertIn("No changelog entry", out)
        self.assertNotIn("修复 B", out)
        self.assertIn("::warning::", warn)

    def test_prerelease_missing_unreleased_never_borrows_last_formal(self):
        self.write_changelog("## [2.5.1] - 2026-09-11\n\n### Fixed\n- 修复 B\n")
        out, warn = self.run_extract("v2.5.2-rc")
        self.assertIn("No changelog entry", out)
        self.assertNotIn("修复 B", out)
        self.assertIn("::warning::", warn)

    def test_formal_uses_matching_section(self):
        self.write_changelog(self.CHANGELOG_WITH_SECTIONS)
        out, _ = self.run_extract("v2.5.1")
        self.assertIn("- 修复 B", out)
        self.assertNotIn("新功能 A", out)

    def test_formal_missing_section_fails(self):
        self.write_changelog("## [Unreleased]\n\n- 未发布\n")
        with self.assertRaises(SystemExit) as ctx:
            self.run_extract("v9.9.9")
        self.assertEqual(ctx.exception.code, 1)

    def test_formal_empty_section_fails(self):
        self.write_changelog("## [Unreleased]\n\n## [2.5.1] - 2026-09-11\n")
        with self.assertRaises(SystemExit) as ctx:
            self.run_extract("v2.5.1")
        self.assertEqual(ctx.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
