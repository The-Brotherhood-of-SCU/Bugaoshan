#!/usr/bin/env python3
"""分层约束守卫（layering guard）。

校验 ``lib/scu_backend`` 的架构边界，防止「后端层」在后续重构中逐步退化为
第二个 UI 层。这类退化 ``dart analyze`` 抓不到、测试也不会失败，只能在
review 时靠人眼，因而需要一个可执行的检查。

规则（只匹配 ``package:`` 形式的导入；本仓库跨层引用均为该形式）：

``backend-no-material``
    ``lib/scu_backend/`` 下不得导入 ``package:flutter/material.dart``。
    后端层应保持与 Flutter Widget 无关，颜色/图标/TimeOfDay 等展示类型
    留在页面侧。

``backend-no-upper``
    ``lib/scu_backend/`` 下不得导入 ``package:bugaoshan/{pages,providers,widgets}/``。
    后端层不得反向依赖 UI 层与状态层。

``utils-no-backend``
    ``lib/utils/`` 下不得导入 ``package:bugaoshan/scu_backend/``。
    utils 是更底层的共享工具，依赖 backend 会形成目录级环。

存量债务处理：既有违例登记在 ``ALLOWLIST`` 中，属豁免项，不计入失败。
这样脚本可以立刻上线而不被历史债务卡住，同时保证「只减不增」——任何
未登记的新违例都会让检查失败。

``scope`` 目录不存在时（例如 scu_backend 尚未合入）对应规则自动跳过。

用法::

    python .github/scripts/check_layering.py [--root .]

退出码：``0`` 通过，``1`` 存在未登记的新违规。
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Rule:
    """一条分层规则。"""

    name: str
    scope: str
    forbidden: tuple[str, ...]
    hint: str


RULES: tuple[Rule, ...] = (
    Rule(
        name="backend-no-material",
        scope="lib/scu_backend/",
        forbidden=("package:flutter/material.dart",),
        hint=(
            "后端层不应依赖 Material。展示类型（Color / IconData / TimeOfDay）"
            "留在页面侧，解析器只返回纯数据。"
        ),
    ),
    Rule(
        name="backend-no-upper",
        scope="lib/scu_backend/",
        forbidden=(
            "package:bugaoshan/pages/",
            "package:bugaoshan/providers/",
            "package:bugaoshan/widgets/",
        ),
        hint="后端层不得反向依赖 UI / 状态层，需要的逻辑应下沉到 core 或对应子系统。",
    ),
    Rule(
        name="utils-no-backend",
        scope="lib/utils/",
        forbidden=("package:bugaoshan/scu_backend/",),
        hint="lib/utils 属更底层共享工具，依赖 scu_backend 会形成目录级循环。",
    ),
)

# 存量债务：文件 -> {规则名: 豁免原因}。只允许随债务清理而删除，不允许新增。
ALLOWLIST: dict[str, dict[str, str]] = {
    "lib/scu_backend/gs/graduate_schedule_parser.dart": {
        "backend-no-material": (
            "解析结果直接带课程配色（Colors.primaries 索引）与节次 TimeOfDay；"
            "待剥离为纯数据后移除本条。"
        ),
    },
    "lib/scu_backend/service_hall/service_form_fields.dart": {
        "backend-no-material": (
            "办事大厅表单字段元数据自带 Icons 常量与中文标签；"
            "待把展示配置移回页面侧后移除本条。"
        ),
    },
}

# 只匹配行首的 import / export，避免把注释里的示例代码当成真实依赖。
_DIRECTIVE_RE = re.compile(
    r"""^[ \t]*(?:import|export)[ \t]+['"]([^'"]+)['"]""",
    re.MULTILINE,
)


@dataclass
class Violation:
    """一处未登记的分层违规。"""

    path: str
    rule: Rule
    uri: str
    line: int

    def format(self) -> str:
        return (
            f"  {self.path}:{self.line}  [{self.rule.name}]\n"
            f"      import '{self.uri}';\n"
            f"      {self.rule.hint}"
        )


@dataclass
class Allowed:
    """一处已登记的存量违例。"""

    path: str
    rule: Rule
    reason: str


@dataclass
class Result:
    violations: list[Violation] = field(default_factory=list)
    allowed: list[Allowed] = field(default_factory=list)
    scanned: int = 0

    @property
    def ok(self) -> bool:
        return not self.violations


def iter_dart_files(root: Path):
    """产出 ``(相对路径, 绝对路径)``，仅限 lib 目录下的 Dart 文件。"""
    lib = root / "lib"
    if not lib.is_dir():
        return
    for path in sorted(lib.rglob("*.dart")):
        yield path.relative_to(root).as_posix(), path


def check(root: Path, rules: tuple[Rule, ...] = RULES,
          allowlist: dict[str, dict[str, str]] | None = None) -> Result:
    """扫描 ``root`` 并按规则收集违规。"""
    if allowlist is None:
        allowlist = ALLOWLIST

    result = Result()
    for rel, path in iter_dart_files(root):
        matched = [rule for rule in rules if rel.startswith(rule.scope)]
        if not matched:
            continue
        result.scanned += 1

        text = path.read_text(encoding="utf-8", errors="replace")
        directives = [
            (m.group(1), text.count("\n", 0, m.start()) + 1)
            for m in _DIRECTIVE_RE.finditer(text)
        ]
        if not directives:
            continue

        exemptions = allowlist.get(rel, {})
        for rule in matched:
            for uri, line in directives:
                if not any(fragment in uri for fragment in rule.forbidden):
                    continue
                reason = exemptions.get(rule.name)
                if reason:
                    result.allowed.append(Allowed(rel, rule, reason))
                else:
                    result.violations.append(Violation(rel, rule, uri, line))
                break

    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="校验 lib/scu_backend 的分层边界（只减不增）。",
    )
    parser.add_argument(
        "--root",
        default=".",
        help="仓库根目录，默认为当前目录。",
    )
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    if not (root / "lib").is_dir():
        print(f"[layering] 跳过：{root} 下没有 lib 目录", file=sys.stderr)
        return 0

    result = check(root)

    if result.violations:
        print(f"[layering] 发现 {len(result.violations)} 处未登记的分层违规：")
        print()
        for violation in result.violations:
            print(violation.format())
            print()
        print(
            "处理方式：优先改代码（把展示逻辑移回页面、把依赖下沉到 core）；\n"
            "若确属合理例外，在 .github/scripts/check_layering.py 的 ALLOWLIST 中\n"
            "登记文件与原因——登记项会被打印出来持续可见，不接受静默豁免。",
            file=sys.stderr,
        )
        return 1

    summary = (
        f"[layering] 通过：扫描 {result.scanned} 个文件，"
        f"0 处新增违规，{len(result.allowed)} 处已登记例外"
    )
    print(summary)
    for allowed in result.allowed:
        print(f"  · {allowed.path} [{allowed.rule.name}] — {allowed.reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
