#!/usr/bin/env python3
"""Resolve release channel, version, tag, and idempotency status for Bugaoshan CI/CD.

Outputs GitHub Actions variables via GITHUB_OUTPUT or prints to stdout.

发布语义详见 docs/architecture/release-pipeline.md，要点：
- formal：仅来自 push 到 main（或指向 main 顶端的 tag）。tag = pubspec 的 vX.Y.Z，
  远端已存在同名 tag 时幂等跳过。
- preview：push/dispatch 到 preview（或指向 preview 顶端的含 `-` tag）。tag 与 pubspec
  解耦、按阶段命名：
  * 常态（pubspec == 最新正式 tag）：最新正式 tag 严格递增 Z 位 + `-preview[.N]`；
  * 准备期（pubspec 领先最新正式 tag，/release 已 bump）：`vX.Y.Z-rc` / `-rcN`。
  仓库尚无正式 tag 时回退用 pubspec 版本推导。
- 预览构建（含 RC）统一注入「最新正式 tag」的 versionName/versionCode
  （build_version / build_number），pubspec 的 /release bump 不影响预览构建版本。
- build_only：dispatch 于非 main/preview 分支、tag 指向非 main/preview 顶端、
  或正式命名 tag 指向 preview 顶端时，仅构建产物，不推 tag、不发布。
"""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

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
            # Remove +build_number if present
            return raw.split("+")[0].strip()
    raise ValueError(f"No version: line found in {pubspec_path}")


def get_existing_remote_tags(root_dir: Path | None = None) -> list[str]:
    """Fetch existing git tags from local and remote if possible."""
    code, out, _ = run_git(["tag", "--list", "v*"], root_dir=root_dir)
    tags = set(out.splitlines()) if code == 0 and out else set()

    # Also attempt ls-remote
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
    """Return head SHAs of remote main/preview branches.

    优先 ls-remote（实时）；失败时回退本地 remote-tracking ref。
    """
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
    event_name: str = "push",
    ref_name: str = "",
    ref_type: str = "branch",
    channel_input: str = "auto",
    version_override: str = "",
    existing_tags: list[str] | None = None,
    main_head: str = "",
    preview_head: str = "",
    head_sha: str = "",
    root_dir: Path | None = None,
) -> dict[str, str]:
    """Determine channel, tag, version, build injection values, and publish eligibility.

    Returns dict with keys:
      channel: 'formal' | 'preview'
      tag: resolved tag string (e.g. 'v2.5.2', 'v2.5.2-preview.2', 'v2.5.2-rc')
      version_name: tag 的基础版本号（不含 v 与后缀）
      is_prerelease: 'true' | 'false'
      should_release: 'true' | 'false'（是否发布 Release；build_only 时恒为 false）
      build_only: 'true' | 'false'（仅构建产物：不推 tag、不发布）
      build_version: 构建注入的 versionName（预览=上一正式版；formal=pubspec）
      build_number: 构建注入的 versionCode 基数
      release_title: human readable release title
      skip_reason: explanation if should_release is 'false'
    """
    if existing_tags is None:
        existing_tags = get_existing_remote_tags(root_dir=root_dir)

    pubspec_ver = extract_pubspec_version(pubspec_path)
    m = SEMVER_RE.match(pubspec_ver)
    pubspec_tuple = (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else None

    formal_tag, formal_tuple = latest_formal(existing_tags)

    # ── pubspec 与最新正式 tag 的三态自检 ─────────────────
    pubspec_state = "no-formal"
    if formal_tuple and pubspec_tuple:
        if pubspec_tuple < formal_tuple:
            pubspec_state = "behind"
        elif pubspec_tuple > formal_tuple:
            pubspec_state = "ahead"
        else:
            pubspec_state = "aligned"
    if pubspec_state == "behind":
        print(
            f"::warning::pubspec 版本 {pubspec_ver} 落后于最新正式 tag {formal_tag}"
            "——下一次正式发布会被幂等守卫卡住，请尽快 bump pubspec 对齐。"
        )
    elif pubspec_state == "ahead":
        print(
            f"::notice::pubspec 版本 {pubspec_ver} 领先于最新正式 tag {formal_tag}"
            "——处于 /release 准备期，本轮预览 tag 使用 rc 命名。"
        )

    # ── 通道判定 ─────────────────────────────────────
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
                # 正式命名的 tag 不允许指向 preview——formal 仅允许指向 main
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

    if version_override:
        is_pre = "-" in version_override.lstrip("v")
        channel = "preview" if is_pre else "formal"
        if channel_input in ("formal", "preview"):
            channel = channel_input
    elif ref_type == "tag":
        channel = "preview" if "-" in ref_name.lstrip("v") else "formal"
    elif ref_name == "main":
        channel = channel_input if channel_input in ("formal", "preview") else "formal"
    elif ref_name == "preview":
        channel = channel_input if channel_input in ("formal", "preview") else "preview"
    else:
        # dispatch 于其他分支（build_only）：按状态给预览命名通道
        channel = "preview"

    # ── tag / version_name 计算 ──────────────────────
    if version_override:
        clean_override = version_override.lstrip("v")
        tag = f"v{clean_override}"
        version_name = clean_override.split("-")[0]
        is_prerelease = "-" in clean_override
    elif ref_type == "tag":
        tag = ref_name
        version_name = ref_name.lstrip("v").split("-")[0]
        is_prerelease = "-" in ref_name.lstrip("v")
    elif channel == "formal":
        version_name = pubspec_ver
        tag = f"v{pubspec_ver}"
        is_prerelease = False
        # Idempotency guard for formal releases:
        # If tag already exists on remote, avoid re-releasing or erroring out
        if tag in existing_tags:
            should_release = "false"
            skip_reason = f"Formal release tag {tag} already exists on remote."
    else:
        # preview 命名状态机：常态锚定最新正式 tag 递增 Z 位；准备期用 rc 命名
        is_prerelease = True
        if pubspec_state == "ahead":
            version_name = pubspec_ver
            tag = calculate_next_rc_tag(pubspec_ver, existing_tags)
        elif formal_tuple is not None:
            version_name = f"{formal_tuple[0]}.{formal_tuple[1]}.{formal_tuple[2] + 1}"
            tag = calculate_next_preview_tag(version_name, existing_tags)
        else:
            version_name = pubspec_ver
            tag = calculate_next_preview_tag(pubspec_ver, existing_tags)

    # ── 构建注入：formal 用 version_name（分支推送=pubspec；tag/override=显式声明的
    # 版本号），预览（含 RC）统一用上一正式版，pubspec 的 /release bump 不影响预览 ──
    if channel == "preview" or is_prerelease:
        build_version = (
            f"{formal_tuple[0]}.{formal_tuple[1]}.{formal_tuple[2]}"
            if formal_tuple is not None
            else pubspec_ver
        )
    else:
        build_version = version_name
    build_number = build_number_of(build_version)

    # ── 发布资格 ─────────────────────────────────────
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
    channel_input = os.environ.get("INPUT_CHANNEL", "auto").strip().lower()
    version_override = os.environ.get("INPUT_VERSION_OVERRIDE", "").strip()

    main_head = preview_head = ""
    if ref_type == "tag":
        heads = get_branch_heads(root_dir=root)
        main_head = heads.get("main", "")
        preview_head = heads.get("preview", "")
        # GITHUB_SHA 对 annotated tag（git tag -a）是 tag 对象 SHA 而非其指向的
        # commit——本地剥离到 commit 再与分支 head 比对（fetch-depth: 0 会带上
        # 全部 tag，rev-parse 可靠）；失败时回退 GITHUB_SHA。
        code, peeled, _ = run_git(["rev-parse", f"refs/tags/{ref_name}^{{commit}}"], root_dir=root)
        if code == 0 and peeled:
            head_sha = peeled

    result = resolve_release(
        pubspec_path=pubspec_path,
        event_name=event_name,
        ref_name=ref_name,
        ref_type=ref_type,
        channel_input=channel_input,
        version_override=version_override,
        main_head=main_head,
        preview_head=preview_head,
        head_sha=head_sha,
        root_dir=root,
    )

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
