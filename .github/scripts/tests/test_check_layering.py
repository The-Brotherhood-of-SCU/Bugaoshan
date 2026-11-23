"""``check_layering.py`` 的单元测试。

用临时目录构造最小仓库树，只验证判定逻辑，不依赖真实代码状态。
最后一个用例对真实仓库做一次自检，确保 ALLOWLIST 与实际违例同步。
"""

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from check_layering import ALLOWLIST, RULES, check, main

REPO_ROOT = Path(__file__).resolve().parents[3]


class LayeringGuardTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def write(self, relative: str, content: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def inspect(self, allowlist=None):
        return check(self.root, rules=RULES, allowlist=allowlist or {})

    def test_missing_lib_directory_is_ok(self):
        result = self.inspect()
        self.assertTrue(result.ok)
        self.assertEqual(result.scanned, 0)

    def test_missing_backend_scope_is_ok(self):
        self.write("lib/pages/a.dart", "import 'package:flutter/material.dart';\n")
        result = self.inspect()
        self.assertTrue(result.ok)
        self.assertEqual(result.scanned, 0)

    def test_clean_backend_file_passes(self):
        self.write(
            "lib/scu_backend/core/a.dart",
            "import 'package:http/http.dart' as http;\n"
            "import 'package:bugaoshan/models/course.dart';\n",
        )
        result = self.inspect()
        self.assertTrue(result.ok)
        self.assertEqual(result.scanned, 1)

    def test_material_import_in_backend_fails(self):
        self.write(
            "lib/scu_backend/core/a.dart",
            "import 'package:flutter/material.dart' show Colors;\n",
        )
        result = self.inspect()
        self.assertEqual(len(result.violations), 1)
        self.assertEqual(result.violations[0].rule.name, "backend-no-material")
        self.assertEqual(result.violations[0].line, 1)

    def test_upper_layer_import_in_backend_fails(self):
        self.write(
            "lib/scu_backend/gs/a.dart",
            "import 'package:bugaoshan/pages/home_page.dart';\n",
        )
        result = self.inspect()
        self.assertEqual(len(result.violations), 1)
        self.assertEqual(result.violations[0].rule.name, "backend-no-upper")

    def test_providers_import_in_backend_fails(self):
        self.write(
            "lib/scu_backend/gs/a.dart",
            "import 'package:bugaoshan/providers/course_provider.dart';\n",
        )
        result = self.inspect()
        self.assertEqual(len(result.violations), 1)

    def test_utils_importing_backend_fails(self):
        self.write(
            "lib/utils/a.dart",
            "import 'package:bugaoshan/scu_backend/core/scu_auth.dart';\n",
        )
        result = self.inspect()
        self.assertEqual(len(result.violations), 1)
        self.assertEqual(result.violations[0].rule.name, "utils-no-backend")

    def test_commented_import_is_ignored(self):
        self.write(
            "lib/scu_backend/core/a.dart",
            "// import 'package:flutter/material.dart';\n"
            "/// import 'package:flutter/material.dart';\n",
        )
        result = self.inspect()
        self.assertTrue(result.ok)

    def test_export_is_checked_too(self):
        self.write(
            "lib/scu_backend/core/a.dart",
            "export 'package:flutter/material.dart';\n",
        )
        result = self.inspect()
        self.assertEqual(len(result.violations), 1)

    def test_allowlisted_violation_passes(self):
        path = "lib/scu_backend/gs/graduate_schedule_parser.dart"
        self.write(path, "import 'package:flutter/material.dart' show Colors;\n")
        result = self.inspect(allowlist={path: {"backend-no-material": "已知债务"}})
        self.assertTrue(result.ok)
        self.assertEqual(len(result.allowed), 1)
        self.assertEqual(result.allowed[0].path, path)

    def test_allowlist_is_scoped_per_rule(self):
        """豁免按 (文件, 规则) 生效，不因为文件在表里就放过其它规则。"""
        path = "lib/scu_backend/gs/graduate_schedule_parser.dart"
        self.write(
            path,
            "import 'package:flutter/material.dart' show Colors;\n"
            "import 'package:bugaoshan/pages/home_page.dart';\n",
        )
        result = self.inspect(allowlist={path: {"backend-no-material": "已知债务"}})
        self.assertEqual(len(result.allowed), 1)
        self.assertEqual(len(result.violations), 1)
        self.assertEqual(result.violations[0].rule.name, "backend-no-upper")

    def test_violation_reports_all_rules_for_one_file(self):
        self.write(
            "lib/scu_backend/core/a.dart",
            "import 'package:flutter/material.dart';\n"
            "import 'package:bugaoshan/widgets/common/dialog.dart';\n",
        )
        result = self.inspect()
        names = sorted(v.rule.name for v in result.violations)
        self.assertEqual(names, ["backend-no-material", "backend-no-upper"])

    def test_main_returns_zero_when_clean(self):
        self.write("lib/scu_backend/core/a.dart", "import 'dart:async';\n")
        with contextlib.redirect_stdout(io.StringIO()):
            code = main(["--root", str(self.root)])
        self.assertEqual(code, 0)

    def test_main_returns_one_and_prints_detail(self):
        self.write(
            "lib/scu_backend/core/a.dart",
            "import 'package:flutter/material.dart';\n",
        )
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            code = main(["--root", str(self.root)])
        self.assertEqual(code, 1)
        self.assertIn("backend-no-material", output.getvalue())
        self.assertIn("lib/scu_backend/core/a.dart", output.getvalue())

    def test_real_repository_has_no_unregistered_violation(self):
        """真实仓库自检：ALLOWLIST 必须覆盖全部既有违例。"""
        result = check(REPO_ROOT)
        detail = "\n".join(v.format() for v in result.violations)
        self.assertTrue(result.ok, f"存在未登记的分层违规：\n{detail}")


if __name__ == "__main__":
    unittest.main()
