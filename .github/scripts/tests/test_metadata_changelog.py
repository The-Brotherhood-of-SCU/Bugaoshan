import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from metadata_changelog import extract_changelog


class MetadataChangelogTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "CHANGELOG.md"

    def extract(self, content, version):
        self.path.write_text(content, encoding="utf-8")
        with contextlib.redirect_stderr(io.StringIO()):
            return extract_changelog(version, str(self.path))

    def test_exact_formal_notes_without_category_headings(self):
        content = "## [2.5.2-preview]\n- preview\n## [2.5.1]\n### Fixed\n- stable\n"
        self.assertEqual(self.extract(content, "2.5.1"), "- stable")

    def test_missing_version_does_not_fall_back_to_another_section(self):
        self.assertIsNone(self.extract("## [2.5.2-preview]\n- preview\n", "2.5.2"))

    def test_empty_or_duplicate_version_does_not_generate_metadata(self):
        for content in ("## [2.5.2]\n### Added\n", "## [2.5.2]\n- A\n## [2.5.2]\n- B\n"):
            with self.subTest(content=content):
                self.assertIsNone(self.extract(content, "2.5.2"))

    def test_preview_extraction_also_uses_exact_version(self):
        content = "## [2.5.2-rc]\n- rc\n## [2.5.2-preview.2]\n### Added\n- preview\n"
        self.assertEqual(self.extract(content, "2.5.2-preview.2"), "- preview")


if __name__ == "__main__":
    unittest.main()
