#!/usr/bin/env python3
"""Resolve release channel, version, tag, and idempotency status for Bugaoshan CI/CD.

Outputs GitHub Actions variables via GITHUB_OUTPUT or prints to stdout.
"""

from __future__ import annotations

import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$")


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


def calculate_next_preview_tag(base_version: str, existing_tags: list[str]) -> str:
    """Calculate next preview tag for base_version (e.g. '2.5.1' -> 'v2.5.1-preview' or 'v2.5.1-preview.2')."""
    first_tag = f"v{base_version}-preview"
    if first_tag not in existing_tags:
        return first_tag

    # Scan for existing preview tags matching v{base_version}-preview.N or v{base_version}-previewN
    max_num = 1
    pattern = re.compile(rf"^v{re.escape(base_version)}-preview(?:\.|-)?(\d+)$")
    for t in existing_tags:
        if t == first_tag:
            continue
        m = pattern.match(t)
        if m:
            try:
                num = int(m.group(1))
                if num > max_num:
                    max_num = num
            except ValueError:
                pass

    return f"v{base_version}-preview.{max_num + 1}"


def resolve_release(
    pubspec_path: Path,
    ref_name: str = "",
    ref_type: str = "",
    channel_input: str = "auto",
    version_override: str = "",
    existing_tags: list[str] | None = None,
    root_dir: Path | None = None,
) -> dict[str, str]:
    """Determine channel, tag, version, and whether release creation should proceed.

    Returns dict with keys:
      channel: 'formal' | 'preview'
      tag: resolved tag string (e.g. 'v2.5.1', 'v2.5.1-preview.2')
      version_name: clean semver without v (e.g. '2.5.1')
      is_prerelease: 'true' | 'false'
      should_release: 'true' | 'false'
      release_title: human readable release title
      skip_reason: explanation if should_release is 'false'
    """
    if existing_tags is None:
        existing_tags = get_existing_remote_tags(root_dir=root_dir)

    pubspec_ver = extract_pubspec_version(pubspec_path)

    # 1. Determine channel
    channel = "formal"
    if channel_input in ("formal", "preview"):
        channel = channel_input
    elif ref_type == "tag" or ref_name.startswith("v"):
        tag_val = version_override or ref_name
        channel = "preview" if "-" in tag_val else "formal"
    elif ref_name == "preview" or ref_name.startswith("preview/") or ref_name.startswith("pre/"):
        channel = "preview"
    elif ref_name == "main":
        channel = "formal"
    else:
        # Default based on version string if explicit
        channel = "preview" if ("-" in version_override or "-" in pubspec_ver) else "formal"

    # 2. Resolve version and tag
    is_prerelease = "true" if channel == "preview" else "false"
    skip_reason = ""
    should_release = "true"

    if version_override:
        clean_override = version_override.lstrip("v")
        tag = f"v{clean_override}"
        version_name = clean_override.split("-")[0]
        if "-" in clean_override:
            is_prerelease = "true"
            channel = "preview"
    elif ref_type == "tag" and ref_name.startswith("v"):
        tag = ref_name
        version_name = ref_name.lstrip("v").split("-")[0]
    elif channel == "formal":
        version_name = pubspec_ver
        tag = f"v{pubspec_ver}"
        # Idempotency guard for formal releases:
        # If tag already exists on remote, avoid re-releasing or erroring out
        if tag in existing_tags:
            should_release = "false"
            skip_reason = f"Formal release tag {tag} already exists on remote."
    else:
        # channel == 'preview'
        version_name = pubspec_ver
        tag = calculate_next_preview_tag(pubspec_ver, existing_tags)

    title = f"Release {tag}" if is_prerelease == "false" else f"Preview {tag}"

    return {
        "channel": channel,
        "tag": tag,
        "version_name": version_name,
        "is_prerelease": is_prerelease,
        "should_release": should_release,
        "release_title": title,
        "skip_reason": skip_reason,
    }


def main():
    root = Path(__file__).resolve().parents[2]
    pubspec_path = root / "pubspec.yaml"

    ref_name = os.environ.get("GITHUB_REF_NAME", "")
    ref_type = os.environ.get("GITHUB_REF_TYPE", "")
    channel_input = os.environ.get("INPUT_CHANNEL", "auto").strip().lower()
    version_override = os.environ.get("INPUT_VERSION_OVERRIDE", "").strip()

    result = resolve_release(
        pubspec_path=pubspec_path,
        ref_name=ref_name,
        ref_type=ref_type,
        channel_input=channel_input,
        version_override=version_override,
        root_dir=root,
    )

    output_path = os.environ.get("GITHUB_OUTPUT", "")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as f:
            for k, v in result.items():
                f.write(f"{k}={v}\n")

    print(f"Resolved Release Metadata:")
    for k, v in result.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
