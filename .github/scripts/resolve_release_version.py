#!/usr/bin/env python3
"""Resolve release channel, tag, and build injection values for Bugaoshan CI/CD.

发布状态由 `CHANGELOG.md` 与最新正式 tag 决定，`pubspec.yaml` 必须与目标版本一致：

- 最高版本 == 最新正式 tag：常态预览，tag = 最新正式版递增 patch 位 + `-preview[.N]`。
- 最高版本 > 最新正式 tag：准备期，tag = `v<最高版本>-rc[.N]`。
- 最高版本 < 最新正式 tag：非法，直接失败。

正式版只在 `main` 上发布；其他分支或 tag 指向不满足条件时仅构建产物。
预览/RC 构建统一注入最新正式版的 versionName/versionCode。
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

from changelog_sections import normalize_version, resolve_release_state

SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
STABLE_TAG_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")


def run_git(args: list[str], root_dir: Path | None = None) -> tuple[int, str, str]:
    """Execute git command and return (code, stdout, stderr)."""
    try:
        proc = subprocess.run(
            ["git"] + args,
            cwd=str(root_dir) if root_dir else None,
            capture_output=True,
            text=True,
            check=False,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except Exception as e:
        return 1, "", str(e)


def extract_pubspec_version(pubspec_path: Path) -> str:
    """Extract version string from pubspec.yaml (e.g. '2.5.1+20501' -> '2.5.1')."""
    if not pubspec_path.exists():
        raise FileNotFoundError(f"{pubspec_path} does not exist")
    for line in pubspec_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("version:"):
            raw = line.split(":", 1)[1].strip()
            return raw.split("+")[0].strip()
    raise ValueError(f"No version: line found in {pubspec_path}")


def get_existing_remote_tags(root_dir: Path | None = None) -> list[str]:
    """Fetch existing git tags from local and remote if possible."""
    code, out, _ = run_git(["tag", "--list", "v*"], root_dir=root_dir)
    tags = set(out.splitlines()) if code == 0 and out else set()

    code, remote_out, _ = run_git(["ls-remote", "--tags", "origin", "refs/tags/v*"], root_dir=root_dir)
    if code == 0 and remote_out:
        for line in remote_out.splitlines():
            parts = line.split()
            if len(parts) >= 2:
                ref = parts[1]
                if ref.startswith("refs/tags/"):
                    tag_name = ref[len("refs/tags/"):]
                    if not tag_name.endswith("^{}"):
                        tags.add(tag_name)
    return sorted(tags)


def get_branch_heads(root_dir: Path | None = None) -> dict[str, str]:
    """Return head SHAs of remote main/preview branches."""
    heads: dict[str, str] = {}
    code, out, _ = run_git(
        ["ls-remote", "origin", "refs/heads/main", "refs/heads/preview"],
        root_dir=root_dir,
    )
    if code == 0 and out:
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[1].startswith("refs/heads/"):
                heads[parts[1].rsplit("/", 1)[-1]] = parts[0]
    for name in ("main", "preview"):
        if name not in heads:
            code, out, _ = run_git(
                ["rev-parse", "--verify", f"refs/remotes/origin/{name}"],
                root_dir=root_dir,
            )
            if code == 0 and out:
                heads[name] = out.strip()
    return heads


def parse_stable_tag(tag: str) -> tuple[int, int, int] | None:
    m = STABLE_TAG_RE.match(tag)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def latest_formal(existing_tags: list[str]) -> tuple[str | None, tuple[int, int, int] | None]:
    """Return the greatest vX.Y.Z tag (semver order) and its tuple."""
    best: tuple[str, tuple[int, int, int]] | None = None
    for tag in existing_tags:
        tup = parse_stable_tag(tag)
        if tup and (best is None or tup > best[1]):
            best = (tag, tup)
    if best is None:
        return None, None
    return best


def build_number_of(version: str) -> str:
    """buildNumber = major*10000 + minor*100 + patch（与 F-Droid versionCode 公式同源）。"""
    m = SEMVER_RE.match(version)
    if not m:
        return ""
    major, minor, patch = (int(x) for x in m.groups())
    return str(major * 10000 + minor * 100 + patch)


def next_patch_version(version: str) -> str:
    major, minor, patch = (int(x) for x in version.split("."))
    return f"{major}.{minor}.{patch + 1}"


def calculate_next_preview_tag(last_formal_version: str, existing_tags: list[str]) -> str:
    """Next preview tag anchored to last_formal_version (v2.5.1 -> v2.5.1-preview / v2.5.1-preview.2)."""
    first_tag = f"v{last_formal_version}-preview"
    if first_tag not in existing_tags:
        return first_tag

    pattern = re.compile(rf"^v{re.escape(last_formal_version)}-preview\.(\d+)$")
    max_num = 1
    for t in existing_tags:
        m = pattern.match(t)
        if m:
            num = int(m.group(1))
            if num > max_num:
                max_num = num

    return f"v{last_formal_version}-preview.{max_num + 1}"


def calculate_next_rc_tag(target_version: str, existing_tags: list[str]) -> str:
    """Next RC tag for target_version (v2.5.2 -> v2.5.2-rc / v2.5.2-rc1 / v2.5.2-rc2)."""
    base = f"v{target_version}-rc"
    if base not in existing_tags:
        return base

    pattern = re.compile(rf"^v{re.escape(target_version)}-rc(\d+)$")
    max_num = 0
    for t in existing_tags:
        m = pattern.match(t)
        if m:
            num = int(m.group(1))
            if num > max_num:
                max_num = num

    return f"v{target_version}-rc{max_num + 1}"


def resolve_release(
    pubspec_path: Path,
    changelog_path: Path | None = None,
    event_name: str = "push",
    ref_name: str = "",
    ref_type: str = "branch",
    existing_tags: list[str] | None = None,
    main_head: str = "",
    preview_head: str = "",
    head_sha: str = "",
    root_dir: Path | None = None,
) -> dict[str, str]:
    """Determine channel, tag, version, build injection values, and publish eligibility.

    Returns dict with keys:
      channel: 'formal' | 'preview'
      tag: resolved tag string (e.g. 'v2.5.2', 'v2.5.4-preview.2', 'v2.6.0-rc1')
      version_name: tag 的基础版本号（不含 v 与后缀）
      is_prerelease: 'true' | 'false'
      should_release: 'true' | 'false'（是否发布 Release；build_only 时恒为 false）
      build_only: 'true' | 'false'（仅构建产物：不推 tag、不发布）
      build_version: 构建注入的 versionName（预览=上一正式版；formal=目标版本）
      build_number: 构建注入的 versionCode 基数
      release_title: human readable release title
      skip_reason: explanation if should_release is 'false'
    """
    if existing_tags is None:
        existing_tags = get_existing_remote_tags(root_dir=root_dir)

    pubspec_ver = extract_pubspec_version(pubspec_path)
    changelog_path = changelog_path or pubspec_path.parent / "CHANGELOG.md"
    formal_tag, _ = latest_formal(existing_tags)
    latest_formal_version = formal_tag[1:] if formal_tag else None

    skip_reason = ""
    should_release = "true"
    build_only = "false"

    if event_name == "workflow_dispatch" and ref_type == "branch" and ref_name not in ("main", "preview"):
        build_only = "true"
        skip_reason = f"build-only：dispatch 于非 main/preview 分支 {ref_name}，仅构建产物。"
        print("::warning::dispatch 于非 main/preview 分支，本次仅构建产物、不发布。")
    elif ref_type == "tag":
        if not head_sha:
            build_only = "true"
            skip_reason = "build-only：无法解析 main/preview 分支顶端 SHA，保守处理仅构建产物。"
            print("::warning::无法解析 main/preview 分支顶端 SHA，保守起见本次仅构建产物、不发布。")
        elif main_head and head_sha == main_head:
            pass  # 指向 main 顶端：按名称发布
        elif preview_head and head_sha == preview_head:
            if "-" not in ref_name.lstrip("v"):
                build_only = "true"
                skip_reason = f"build-only：正式 tag {ref_name} 指向 preview 顶端，formal 仅允许指向 main。"
                print(
                    f"::warning::正式 tag {ref_name} 指向 preview 顶端，本次仅构建产物、不发布；"
                    "formal tag 仅允许指向 main。"
                )
        else:
            build_only = "true"
            skip_reason = f"build-only：tag {ref_name} 未指向 main/preview 顶端，仅构建产物；若为误推请删除该 tag。"
            print(f"::warning::tag {ref_name} 未指向 main/preview 顶端，本次仅构建产物、不发布；若为误推请删除该 tag。")

    if ref_type == "tag":
        tag = ref_name
        channel = "preview" if "-" in ref_name.lstrip("v") else "formal"
        version_name = ref_name.lstrip("v").split("-", 1)[0]
        is_prerelease = channel == "preview"
        if channel == "formal" and normalize_version(ref_name) != pubspec_ver:
            raise ValueError(f"正式 tag {ref_name} 与 pubspec 版本 {pubspec_ver} 不一致")
    else:
        content = changelog_path.read_text(encoding="utf-8")
        state = resolve_release_state(content, latest_formal_version)
        if pubspec_ver != state.version:
            raise ValueError(
                f"pubspec 版本 {pubspec_ver} 与 CHANGELOG 目标 {state.version} 不一致"
            )

        if ref_name == "main":
            channel = "formal"
            is_prerelease = False
            version_name = state.version
            tag = f"v{version_name}"
            if state.mode == "preview":
                should_release = "false"
                skip_reason = (
                    f"CHANGELOG 最高版本 {state.version} 已正式发布，main 本次没有新版本。"
                )
        else:
            channel = "preview"
            is_prerelease = True
            if state.mode == "rc":
                version_name = state.version
                tag = calculate_next_rc_tag(version_name, existing_tags)
                print(f"::notice::CHANGELOG 已准备 {version_name}，本轮发布 RC。")
            else:
                base = latest_formal_version or pubspec_ver
                version_name = next_patch_version(base)
                tag = calculate_next_preview_tag(version_name, existing_tags)

    if channel == "preview" or is_prerelease:
        build_version = latest_formal_version or pubspec_ver
    else:
        build_version = version_name
    build_number = build_number_of(build_version)

    if build_only == "true":
        should_release = "false"
        if not skip_reason:
            skip_reason = "build-only：仅构建产物。"

    title = f"Release {tag}" if not is_prerelease else f"Preview {tag}"

    return {
        "channel": channel,
        "tag": tag,
        "version_name": version_name,
        "is_prerelease": "true" if is_prerelease else "false",
        "should_release": should_release,
        "build_only": build_only,
        "build_version": build_version,
        "build_number": build_number,
        "release_title": title,
        "skip_reason": skip_reason,
    }


def main():
    root = Path(__file__).resolve().parents[2]
    pubspec_path = root / "pubspec.yaml"

    event_name = os.environ.get("GITHUB_EVENT_NAME", "push")
    ref_name = os.environ.get("GITHUB_REF_NAME", "")
    ref_type = os.environ.get("GITHUB_REF_TYPE", "branch")
    head_sha = os.environ.get("GITHUB_SHA", "")

    main_head = preview_head = ""
    if ref_type == "tag":
        heads = get_branch_heads(root_dir=root)
        main_head = heads.get("main", "")
        preview_head = heads.get("preview", "")
        # GITHUB_SHA 对 annotated tag 是 tag 对象 SHA，先剥离到 commit。
        code, peeled, _ = run_git(["rev-parse", f"refs/tags/{ref_name}^{{commit}}"], root_dir=root)
        if code == 0 and peeled:
            head_sha = peeled

    try:
        result = resolve_release(
            pubspec_path=pubspec_path,
            event_name=event_name,
            ref_name=ref_name,
            ref_type=ref_type,
            main_head=main_head,
            preview_head=preview_head,
            head_sha=head_sha,
            root_dir=root,
        )
    except (ValueError, OSError) as error:
        print(f"::error::{error}", file=sys.stderr)
        sys.exit(1)

    output_path = os.environ.get("GITHUB_OUTPUT", "")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as f:
            for k, v in result.items():
                f.write(f"{k}={v}\n")

    print("Resolved Release Metadata:")
    for k, v in result.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
