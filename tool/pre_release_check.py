#!/usr/bin/env python3
"""Bugaoshan 发布前检查。

用法:
    python tool/pre_release_check.py          # PR 门禁：检查 CHANGELOG 状态与不变量
    python tool/pre_release_check.py X.Y.Z    # 正式版发布前严格检查

退出码:
    0 全部通过（含仅 WARN）
    1 存在 FAIL 项
    2 参数或运行环境错误
"""

import argparse
import datetime
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / ".github" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from changelog_sections import (
    has_changelog_content,
    normalize_version,
    parse_changelog_document,
    resolve_release_state,
)
from resolve_release_version import get_existing_remote_tags, latest_formal

# 与 android/app/build.gradle.kts 的 ABI override / F-Droid VercodeOperation 一致
ABI_CODES = (1, 2, 4)
METADATA_LANGS = ("en-US", "zh-CN")

OK, WARN, FAIL = "OK", "WARN", "FAIL"
_COLORS = {
    OK: "\033[32m",
    WARN: "\033[33m",
    FAIL: "\033[31m",
}
_RESET = "\033[0m"
_USE_COLOR = False

SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def _try_reconfigure_encoding():
    global _USE_COLOR
    import os
    _USE_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass


class Checker:
    def __init__(self, version="", existing_tags=None):
        self.version = version
        self.strict = bool(version)
        self.existing_tags = existing_tags
        self.state = None
        self.state_error = None
        self.target_version = version
        self.results = []
        self._state_loaded = False
        self.tag = f"v{version}" if version else ""

    # ---- 基础工具 ----

    def run(self, *args, cwd=None, timeout=15):
        try:
            proc = subprocess.run(
                list(args),
                cwd=str(cwd or ROOT),
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
            )
            return proc.returncode, proc.stdout, proc.stderr
        except FileNotFoundError:
            return 127, "", f"command not found: {args[0]}"
        except subprocess.TimeoutExpired:
            return 124, "", f"timeout: {' '.join(args)}"

    def record(self, status, name, message=""):
        self.results.append((status, name, message))

    def _tags(self):
        if self.existing_tags is None:
            self.existing_tags = get_existing_remote_tags(root_dir=ROOT)
        return self.existing_tags

    def _read_changelog(self):
        path = ROOT / "CHANGELOG.md"
        if not path.exists():
            raise FileNotFoundError("未找到 CHANGELOG.md")
        return path.read_text(encoding="utf-8")

    def _ensure_state(self):
        if self.strict or self._state_loaded:
            return self.state, self.state_error
        self._state_loaded = True
        try:
            content = self._read_changelog()
            formal_tag, _ = latest_formal(self._tags())
            latest = formal_tag[1:] if formal_tag else None
            self.state = resolve_release_state(content, latest)
            self.target_version = self.state.version
        except (ValueError, OSError) as error:
            self.state_error = str(error)
        return self.state, self.state_error

    @staticmethod
    def semver_tuple(text):
        m = SEMVER_RE.match(text)
        if not m:
            return None
        return tuple(int(x) for x in m.groups())

    @staticmethod
    def base_version_code(name):
        t = Checker.semver_tuple(name)
        if t is None:
            return None
        return t[0] * 10000 + t[1] * 100 + t[2]

    # ---- 版本号 ----

    def check_version_format(self):
        name = "版本号格式"
        if SEMVER_RE.match(self.version):
            self.record(OK, name, f"{self.version}")
        else:
            self.record(FAIL, name, f"{self.version} 不是合法的 X.Y.Z 版本号")

    def check_git_repo(self):
        name = "Git 仓库"
        code, out, _ = self.run("git", "rev-parse", "--is-inside-work-tree")
        if code == 0 and out.strip() == "true":
            self.record(OK, name, "位于 git 工作树内")
            return True
        self.record(FAIL, name, "当前目录不是 git 仓库，无法继续检查")
        return False

    def check_working_tree(self):
        name = "工作区干净"
        code, out, err = self.run("git", "status", "--porcelain")
        if code != 0:
            self.record(WARN, name, f"git status 失败: {err.strip()}")
            return
        dirty = [line for line in out.splitlines() if line.strip()]
        if dirty:
            preview = "\n".join(f"    {line}" for line in dirty[:10])
            more = f"\n    ... 还有 {len(dirty) - 10} 个文件" if len(dirty) > 10 else ""
            self.record(WARN, name, f"有 {len(dirty)} 个未提交变更:\n{preview}{more}")
        else:
            self.record(OK, name, "无未提交变更")

    def check_branch(self):
        name = "当前分支"
        code, out, err = self.run("git", "branch", "--show-current")
        if code != 0:
            self.record(WARN, name, f"无法读取分支: {err.strip()}")
            return
        branch = out.strip()
        if branch in ("preview", "main"):
            self.record(OK, name, branch)
        elif branch:
            self.record(WARN, name, f"当前分支为 {branch}，发布准备建议在 preview 上执行")
        else:
            self.record(WARN, name, "处于 detached HEAD 状态，请确认在正确的 ref 上发布")

    def check_unpushed_commits(self):
        name = "未推送提交"
        code, out, err = self.run("git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
        if code != 0:
            self.record(WARN, name, "未设置上游分支，无法判断本地是否领先 origin")
            return
        code, out, _ = self.run("git", "rev-list", "--count", "@{u}..HEAD")
        ahead = int(out.strip()) if code == 0 and out.strip().isdigit() else 0
        code, out, _ = self.run("git", "rev-list", "--count", "HEAD..@{u}")
        behind = int(out.strip()) if code == 0 and out.strip().isdigit() else 0
        if ahead > 0:
            self.record(WARN, name, f"本地领先 origin 有 {ahead} 个提交（打 tag 前记得先 push）")
        elif behind > 0:
            self.record(WARN, name, f"本地落后 origin 有 {behind} 个提交（建议先 pull）")
        else:
            self.record(OK, name, "与上游同步")

    def check_tag_not_exists(self):
        name = "tag 冲突"
        if self.tag in self._tags():
            self.record(FAIL, name, f"已存在 tag {self.tag}，发布会冲突")
        else:
            self.record(OK, name, f"tag {self.tag} 尚未使用")

    def check_version_monotonic(self):
        name = "版本号递增"
        stable = []
        for tag in self._tags():
            m = SEMVER_RE.match(tag[1:] if tag.startswith("v") else tag)
            if m and "-" not in tag:
                stable.append((tuple(int(x) for x in m.groups()), tag))
        if not stable:
            self.record(OK, name, "仓库尚无正式 tag，将作为首个正式版本")
            return
        latest_tuple, latest_tag = max(stable, key=lambda x: x[0])
        new_tuple = self.semver_tuple(self.version)
        if new_tuple is None:
            return
        if new_tuple > latest_tuple:
            self.record(OK, name, f"{self.version} > 上一正式版本 {latest_tag[1:]}")
        else:
            self.record(FAIL, name, f"{self.version} 应大于最新正式版本 {latest_tag[1:]}")

    # ---- 版本一致性 ----

    def check_pubspec(self):
        name = "pubspec.yaml 版本"
        pubspec = ROOT / "pubspec.yaml"
        if not pubspec.exists():
            self.record(FAIL, name, "未找到 pubspec.yaml")
            return
        text = pubspec.read_text(encoding="utf-8")
        m = re.search(r"^version:\s*(.+?)\s*$", text, re.MULTILINE)
        if not m:
            self.record(FAIL, name, "未找到 version: 行")
            return
        raw = m.group(1)
        pub_name, sep, pub_build = raw.partition("+")
        expected_build = self.base_version_code(pub_name)

        if self.strict:
            issues = []
            if pub_name != self.version:
                issues.append(f"版本名应为 {self.version}，实际为 {pub_name}")
            if not sep:
                issues.append("缺少 +buildNumber（Android versionCode）")
            elif expected_build is not None and pub_build != str(expected_build):
                issues.append(f"buildNumber 应为 {expected_build}，实际为 {pub_build}")
            if self.semver_tuple(pub_name) is None:
                issues.append("版本名格式非法")
            if issues:
                self.record(FAIL, name, "；".join(issues))
            else:
                self.record(OK, name, f"version: {raw}（versionCode {pub_build}）")
            return

        state, error = self._ensure_state()
        if error:
            return
        if pub_name != state.version:
            self.record(
                FAIL,
                name,
                f"pubspec 版本 {pub_name} 与 CHANGELOG 目标 {state.version} 不一致",
            )
            return
        if not sep or expected_build is None or pub_build != str(expected_build):
            self.record(
                FAIL,
                name,
                f"buildNumber 应为 {expected_build}（X.Y.Z → 主*10000+次*100+修订），实际为 {pub_build or '缺失'}",
            )
            return
        self.record(OK, name, f"version: {raw}（目标 {state.version}）")

    def check_changelog(self):
        name = "CHANGELOG.md"
        try:
            text = self._read_changelog()
        except OSError as error:
            self.record(FAIL, name, str(error))
            return

        try:
            document = parse_changelog_document(text)
        except ValueError as error:
            self.record(FAIL, name, str(error))
            return
        if not document.versions:
            self.record(FAIL, name, "未找到 ## [X.Y.Z] 版本章节")
            return
        for section in document.versions:
            if section.date:
                try:
                    datetime.date.fromisoformat(section.date)
                except ValueError:
                    self.record(FAIL, name, f"[{section.version}] 日期非法: {section.date}")
                    return

        if self.strict:
            formal_tag, _ = latest_formal(self._tags())
            latest = formal_tag[1:] if formal_tag else None
            try:
                state = resolve_release_state(text, latest)
            except ValueError as error:
                self.record(FAIL, "CHANGELOG 状态", str(error))
                return
            if state.mode != "rc":
                self.record(
                    FAIL,
                    "CHANGELOG 状态",
                    f"没有高于最新正式版 {latest} 的新版本",
                )
                return
            if state.version != self.version:
                self.record(
                    FAIL,
                    "CHANGELOG 状态",
                    f"CHANGELOG 目标 {state.version} 与发布目标 {self.version} 不一致",
                )
                return
            section = next((s for s in document.versions if s.version == self.version), None)
            if section is None or not has_changelog_content(section.content):
                self.record(FAIL, name, f"## [{self.version}] 章节缺失或为空")
                return
            if section.date:
                if datetime.date.fromisoformat(section.date) != datetime.date.today():
                    self.record(
                        WARN,
                        "CHANGELOG 日期",
                        f"发布日期 {section.date} 不是今天，确认是否正确",
                    )
            else:
                self.record(WARN, "CHANGELOG 日期", f"[{self.version}] 缺少 YYYY-MM-DD 日期")
            self.record(OK, name, f"[{self.version}] 有更新说明")
            return

        state, error = self._ensure_state()
        if error:
            self.record(FAIL, "CHANGELOG 状态", error)
            return
        if state.mode == "rc":
            if not has_changelog_content(state.notes.content):
                self.record(
                    FAIL,
                    name,
                    f"## [{state.version}] 章节为空；RC 必须有发布说明",
                )
                return
            self.record(OK, name, f"准备期：使用 ## [{state.version}]")
            return

        self.record(OK, name, "常态预览：使用 [Unreleased]")
        if not document.unreleased or not has_changelog_content(document.unreleased.content):
            self.record(WARN, "预览说明", "[Unreleased] 为空，本次预览将使用占位说明")

    # ---- F-Droid ----

    def _metadata_required(self):
        if self.strict:
            return True
        state, _ = self._ensure_state()
        return bool(state and state.mode == "rc")

    def check_metadata_yml(self):
        name = "F-Droid metadata/*.yml"
        if not self._metadata_required():
            self.record(OK, name, "常态预览无需更新 metadata/*.yml")
            return
        ymls = list(ROOT.glob("metadata/*.yml"))
        if not ymls:
            self.record(FAIL, name, "未找到 metadata/*.yml")
            return
        base = self.base_version_code(self.target_version)
        expected_codes = [base * 10 + abi for abi in ABI_CODES]
        text = "\n".join(p.read_text(encoding="utf-8") for p in ymls)
        issues = []
        if not re.search(r"versionName:\s*['\"]?" + re.escape(self.target_version) + r"['\"]?", text):
            issues.append(f"versionName 未包含 {self.target_version}")
        for code in expected_codes:
            if f"versionCode: {code}" not in text:
                issues.append(f"缺少 versionCode: {code}")
        if issues:
            self.record(FAIL, name, "；".join(issues) + "（需更新 metadata/*.yml 的 Builds）")
        else:
            self.record(OK, name, f"versionName={self.target_version}，versionCode={expected_codes}")

    def check_metadata_changelogs(self):
        name = "F-Droid metadata changelogs"
        if not self._metadata_required():
            self.record(OK, name, "常态预览不生成 metadata changelogs")
            return
        base = self.base_version_code(self.target_version)
        expected = [base * 10 + abi for abi in ABI_CODES]
        missing = []
        empty = []
        for lang in METADATA_LANGS:
            for code in expected:
                p = ROOT / "metadata" / lang / "changelogs" / f"{code}.txt"
                if not p.exists():
                    missing.append(str(p.relative_to(ROOT)))
                elif p.read_text(encoding="utf-8").strip() == "":
                    empty.append(str(p.relative_to(ROOT)))
        if missing or empty:
            self.record(
                FAIL,
                name,
                "缺少文件: " + ", ".join(missing + empty)
                + "。运行 python .github/scripts/metadata_changelog.py 生成",
            )
        else:
            self.record(
                OK,
                name,
                f"{len(expected) * len(METADATA_LANGS)} 个文件齐全（{METADATA_LANGS} × {expected}）",
            )

    # ---- 汇总 ----

    def run_all(self):
        if not self.check_git_repo():
            return self.report()

        if self.strict:
            checks = [
                self.check_version_format,
                self.check_working_tree,
                self.check_branch,
                self.check_unpushed_commits,
                self.check_tag_not_exists,
                self.check_version_monotonic,
                self.check_changelog,
                self.check_pubspec,
                self.check_metadata_yml,
                self.check_metadata_changelogs,
            ]
        else:
            checks = [self.check_working_tree, self.check_changelog, self.check_pubspec]
            state, _ = self._ensure_state()
            if state and state.mode == "rc":
                checks += [self.check_metadata_yml, self.check_metadata_changelogs]

        for fn in checks:
            fn()
        return self.report()

    def report(self):
        fails = [r for r in self.results if r[0] == FAIL]
        warns = [r for r in self.results if r[0] == WARN]
        oks = [r for r in self.results if r[0] == OK]

        print()
        print("=" * 64)
        if self.strict:
            print(f"发布前检查结果：{self.version}（正式版）")
        else:
            print("发布前检查结果：PR 门禁")
        print("=" * 64)

        for status, name, message in self.results:
            color = _COLORS[status] if _USE_COLOR else ""
            reset = _RESET if _USE_COLOR else ""
            print(f"[{color}{status}{reset}] {name}")
            if message:
                for line in message.splitlines():
                    print(f"      {line}")

        print("-" * 64)
        print(f"汇总: {len(oks)} OK / {len(warns)} WARN / {len(fails)} FAIL")

        if fails:
            print()
            print("以下项未通过，请修复后再发布:")
            for _, name, message in fails:
                print(f"  - {name}: {message.splitlines()[0] if message else ''}")
            return 1
        print("✅ 检查通过（WARN 项请人工确认）。")
        return 0


def main(argv=None):
    _try_reconfigure_encoding()
    parser = argparse.ArgumentParser(
        description="Bugaoshan 发布前检查。省略版本号时运行 PR 门禁。",
    )
    parser.add_argument(
        "version",
        nargs="?",
        default="",
        help="正式版目标版本 X.Y.Z；省略则运行 PR 门禁",
    )
    args = parser.parse_args(argv)

    version = ""
    if args.version:
        if "-" in args.version:
            parser.error("预览/RC 不需要指定版本；直接运行 PR 门禁")
        try:
            version = normalize_version(args.version)
        except ValueError as error:
            print(f"错误: {error}", file=sys.stderr)
            return 2

    return Checker(version).run_all()


if __name__ == "__main__":
    sys.exit(main())
