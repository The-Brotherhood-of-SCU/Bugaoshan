#!/usr/bin/env python3
"""Bugaoshan 发布前检查脚本。

用法:
    python tool/pre_release_check.py <version>
    python tool/pre_release_check.py <version> --prerelease
    python tool/pre_release_check.py 2.3.0

检查 .claude/commands/release.md / prerelease.md 描述的发布流程中容易遗漏的项，
只做静态检查，不修改任何文件。

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

from changelog_sections import has_changelog_content, normalize_version, parse_changelog

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
    def __init__(self, version, ci=False, changelog_structure_only=False):
        self.version = version
        self.base_version = version.split("-", 1)[0]
        self.is_prerelease = "-" in version
        self.ci = ci
        self.changelog_structure_only = changelog_structure_only
        self.results = []  # (status, name, message)
        self.tag = f"v{self.version}"
        self.base_tag = f"v{self.base_version}"

    def _release_timing_status(self):
        """发布时机类检查（版本递增 / tag 冲突 / 预览版说明缺失）的状态。

        CI 门禁（--ci）跑在任意 PR/push 上，代码库经常处于「两个版本之间」
        的正常状态（刚发完 X.Y.Z、pubspec 还未 bump），此时这些检查必然
        不满足，硬 FAIL 会让 main/preview 的门禁长期挂红。CI 模式下降级为
        WARN 供人工确认；本地手动 /release 流程保持 FAIL 严格拦截。
        """
        return WARN if self.ci else FAIL

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

    # ---- 版本号 ----

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

    # ---- 各项检查 ----

    def check_version_format(self):
        name = "版本号格式"
        if self.is_prerelease:
            if SEMVER_RE.match(self.base_version):
                self.record(OK, name, f"预览版 {self.version}（基础版本 {self.base_version}）")
            else:
                self.record(FAIL, name, f"预览版基础版本格式非法: {self.base_version}，应为 X.Y.Z")
            return
        if SEMVER_RE.match(self.version):
            self.record(OK, name, f"{self.version}")
        else:
            self.record(FAIL, name, f"{self.version} 不是合法的 X.Y.Z 版本号（不应带 v 前缀或 -suffix）")

    def check_git_repo(self):
        name = "Git 仓库"
        code, out, err = self.run("git", "rev-parse", "--is-inside-work-tree")
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
        if not branch:
            self.record(WARN, name, "处于 detached HEAD 状态，请确认在正确的分支上发布")
        elif branch not in ("main", "master"):
            self.record(WARN, name, f"当前分支为 {branch}，发布流程通常应在 main 上执行")
        else:
            self.record(OK, name, f"{branch}")

    def check_unpushed_commits(self):
        name = "未推送提交"
        code, out, err = self.run("git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
        if code != 0:
            self.record(WARN, name, "未设置上游分支，无法判断本地是否领先 origin")
            return
        code, out, err = self.run("git", "rev-list", "--count", "@{u}..HEAD")
        ahead = int(out.strip()) if code == 0 and out.strip().isdigit() else 0
        code, out, err = self.run("git", "rev-list", "--count", "HEAD..@{u}")
        behind = int(out.strip()) if code == 0 and out.strip().isdigit() else 0
        if ahead > 0:
            self.record(WARN, name, f"本地领先 origin 有 {ahead} 个提交（打 tag 前记得先 push）")
        elif behind > 0:
            self.record(WARN, name, f"本地落后 origin 有 {behind} 个提交（建议先 pull）")
        else:
            self.record(OK, name, "与上游同步")

    def check_tag_not_exists(self):
        name = "本地/远端 tag 冲突"
        if self.changelog_structure_only:
            self.record(OK, name, "日常预览门禁未指定发布 tag，实际冲突由发布流程检查")
            return
        timing = self._release_timing_status()
        if not self.is_prerelease:
            code, out, err = self.run("git", "tag", "--list", self.tag)
            if code == 0 and out.strip():
                self.record(timing, name, f"本地已存在 tag {self.tag}，发布会冲突")
                return
        code, out, err = self.run("git", "ls-remote", "--tags", "origin", f"refs/tags/{self.tag}", timeout=20)
        if code == 0:
            if out.strip():
                self.record(timing, name, f"远端 origin 已存在 tag {self.tag}")
            else:
                self.record(OK, name, f"tag {self.tag} 尚未使用")
        else:
            self.record(WARN, name, f"无法检查远端 tag（离线或无 origin）: {err.strip()[:200]}")

    def check_version_monotonic(self):
        name = "版本号递增"
        code, out, err = self.run("git", "tag", "--list", "v*")
        if code != 0:
            self.record(WARN, name, f"git tag 读取失败: {err.strip()}")
            return
        stable = []
        for t in out.splitlines():
            m = SEMVER_RE.match(t[1:] if t.startswith("v") else t)
            if m and not ("-" in t):
                stable.append((tuple(int(x) for x in m.groups()), t))
        if not stable:
            self.record(WARN, name, "仓库尚无稳定 tag，将作为首个稳定版本")
            return
        latest_tuple, latest_tag = max(stable, key=lambda x: x[0])
        new_tuple = self.semver_tuple(self.base_version)
        if new_tuple is None:
            return
        timing = self._release_timing_status()
        if new_tuple > latest_tuple:
            self.record(OK, name, f"{self.base_version} > 上一稳定版本 {latest_tag[1:]}")
        elif new_tuple == latest_tuple:
            self.record(timing, name, f"{self.base_version} 与最新稳定版本 {latest_tag} 相同")
        else:
            self.record(timing, name, f"{self.base_version} < 最新稳定版本 {latest_tag}，版本号应递增")

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
        pub_tuple = self.semver_tuple(pub_name)
        expected_build = self.base_version_code(pub_name)

        if self.is_prerelease:
            new_tuple = self.semver_tuple(self.base_version)
            if pub_tuple and new_tuple and new_tuple >= pub_tuple:
                self.record(OK, name, f"pubspec {raw}（预览版基础版本 {self.base_version} 合法）")
            elif pub_tuple and new_tuple:
                self.record(FAIL, name, f"预览版基础版本 {self.base_version} 应大于或等于 pubspec 当前 {raw}")
            else:
                self.record(FAIL, name, f"pubspec 版本 {raw} 格式非法")
            return

        issues = []
        if pub_name != self.version:
            issues.append(f"版本名应为 {self.version}，实际为 {pub_name}")
        if not sep:
            issues.append("缺少 +buildNumber（Android versionCode）")
        elif expected_build is not None and pub_build != str(expected_build):
            issues.append(f"buildNumber 应为 {expected_build}（X.Y.Z → 主*10000+次*100+修订），实际为 {pub_build}")
        if pub_tuple is None:
            issues.append("版本名格式非法")

        if issues:
            self.record(FAIL, name, "；".join(issues))
        else:
            self.record(OK, name, f"version: {raw}（versionCode {pub_build}）")

    def check_changelog(self):
        name = "CHANGELOG.md"
        path = ROOT / "CHANGELOG.md"
        if not path.exists():
            self.record(FAIL, name, "未找到 CHANGELOG.md")
            return
        text = path.read_text(encoding="utf-8")

        try:
            sections = parse_changelog(text)
        except ValueError as error:
            self.record(FAIL, name, str(error))
            return
        if not sections:
            self.record(FAIL, name, "未找到 ## [版本号] 章节")
            return
        for section in sections:
            if section.date:
                try:
                    datetime.date.fromisoformat(section.date)
                except ValueError:
                    self.record(FAIL, name, f"[{section.version}] 日期非法: {section.date}")
                    return
        if self.changelog_structure_only:
            self.record(OK, name, f"{len(sections)} 个版本章节结构正确；发布时按实际目标版本检查内容")
            return

        target = next((section for section in sections if section.version == self.version), None)
        status = self._release_timing_status() if self.is_prerelease else FAIL
        if target is None:
            self.record(status, name, f"未找到 ## [{self.version}] 章节")
            return
        if not has_changelog_content(target.content):
            self.record(status, name, f"[{self.version}] 章节为空")
            return
        if target.date:
            date = datetime.date.fromisoformat(target.date)
            if date != datetime.date.today():
                self.record(WARN, "CHANGELOG 日期", f"发布日期 {date} 不是今天，确认是否正确")
        elif not self.is_prerelease:
            self.record(WARN, "CHANGELOG 日期", f"[{self.version}] 缺少 YYYY-MM-DD 日期")
        self.record(OK, name, f"[{self.version}] 有更新说明")

    def check_metadata_yml(self):
        name = "F-Droid metadata/*.yml"
        if self.is_prerelease:
            self.record(OK, name, "预览版无需更新 metadata/*.yml")
            return
        ymls = list(ROOT.glob("metadata/*.yml"))
        if not ymls:
            self.record(FAIL, name, "未找到 metadata/*.yml")
            return
        base = self.base_version_code(self.version)
        expected_codes = [base * 10 + abi for abi in ABI_CODES]
        text = "\n".join(p.read_text(encoding="utf-8") for p in ymls)
        issues = []
        if not re.search(r"versionName:\s*['\"]?" + re.escape(self.version) + r"['\"]?", text):
            issues.append(f"versionName 未包含 {self.version}")
        for code in expected_codes:
            if f"versionCode: {code}" not in text:
                issues.append(f"缺少 versionCode: {code}")
        if issues:
            self.record(FAIL, name, "；".join(issues) + "（需更新 metadata/*.yml 的 Builds）")
        else:
            self.record(OK, name, f"versionName={self.version}，versionCode={expected_codes}")

    def check_metadata_changelogs(self):
        name = "F-Droid metadata changelogs"
        if self.is_prerelease:
            self.record(OK, name, "预览版不生成 metadata changelogs（CI 会跳过）")
            return
        base = self.base_version_code(self.version)
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
            self.record(OK, name, f"{len(expected) * len(METADATA_LANGS)} 个文件齐全（{METADATA_LANGS} × {expected}）")

    # ---- 汇总 ----

    def run_all(self):
        if not self.check_git_repo():
            self.report()
            return 2
        checks = [
            self.check_version_format,
            self.check_working_tree,
            self.check_branch,
            self.check_unpushed_commits,
            self.check_tag_not_exists,
            self.check_version_monotonic,
            self.check_pubspec,
            self.check_changelog,
            self.check_metadata_yml,
            self.check_metadata_changelogs,
        ]
        for fn in checks:
            fn()
        return self.report()

    def report(self):
        fails = [r for r in self.results if r[0] == FAIL]
        warns = [r for r in self.results if r[0] == WARN]
        oks = [r for r in self.results if r[0] == OK]

        print()
        print("=" * 64)
        kind = "预览版" if self.is_prerelease else "稳定版"
        print(f"发布前检查结果：{self.version}（{kind}）")
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
        print("✅ 静态检查通过（WARN 项请人工确认）。")
        return 0


def main(argv=None):
    _try_reconfigure_encoding()
    parser = argparse.ArgumentParser(
        description="Bugaoshan 发布前检查。用法示例: python tool/pre_release_check.py 2.3.0",
    )
    parser.add_argument("version", nargs="?", default="", help="目标版本号，如 2.3.0 或 2.3.0-preview（在 CI 模式下可省略）")
    parser.add_argument(
        "--prerelease",
        action="store_true",
        help="按预览版检查；精确检查时需提供完整预览/RC 版本号",
    )
    parser.add_argument(
        "--ci",
        action="store_true",
        help="CI 门禁模式：自动从 pubspec.yaml 读取版本号，发布时机类检查"
             "（版本递增 / tag 冲突 / 预览版说明缺失）降级为 WARN，其余检查未通过时退出码为 1",
    )
    parser.add_argument(
        "--changelog-structure-only",
        action="store_true",
        help="日常预览 CI 仅检查版本章节结构，目标内容由发布流程按实际 tag 检查",
    )
    args = parser.parse_args(argv)

    if args.changelog_structure_only and (not args.ci or not args.prerelease or args.version):
        parser.error("--changelog-structure-only 仅用于未指定目标版本的 --ci --prerelease 门禁")
    if args.prerelease and not args.version and not args.changelog_structure_only:
        parser.error("请提供完整预览/RC 版本号；日常 CI 可使用 --changelog-structure-only")

    version = args.version
    if not version and args.ci:
        # Auto-read from pubspec.yaml
        pub_path = ROOT / "pubspec.yaml"
        if pub_path.exists():
            for line in pub_path.read_text(encoding="utf-8").splitlines():
                if line.strip().startswith("version:"):
                    raw = line.split(":", 1)[1].strip().split("+")[0].strip()
                    version = raw
                    break

    if not version:
        print("错误: 未指定版本号，且无法从 pubspec.yaml 解析", file=sys.stderr)
        return 2

    if args.changelog_structure_only:
        version = f"{version}-prerelease"
    elif args.prerelease and "-" not in version:
        parser.error("预览版检查需要完整目标版本号，如 2.3.0-preview.2 或 2.3.0-rc")

    try:
        version = normalize_version(version)
    except ValueError as error:
        print(f"错误: {error}", file=sys.stderr)
        return 2

    return Checker(version, ci=args.ci, changelog_structure_only=args.changelog_structure_only).run_all()


if __name__ == "__main__":
    sys.exit(main())
