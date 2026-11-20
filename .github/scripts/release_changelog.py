"""Select the release notes for the target tag.

- `-preview` tag -> `[Unreleased]`; empty is allowed and falls back to a placeholder.
- `-rc` / other prerelease tag -> base `## [X.Y.Z]`; empty is an error.
- formal tag -> `## [X.Y.Z]`; empty is an error.
"""

import os
import sys

from changelog_sections import (
    has_changelog_content,
    is_preview_tag,
    normalize_version,
    select_release_notes,
)


def main():
    try:
        version = normalize_version(os.environ.get("VERSION", ""))
        with open("CHANGELOG.md", "r", encoding="utf-8") as f:
            section = select_release_notes(f.read(), version)
    except (ValueError, OSError) as error:
        print(f"::error::{error}", file=sys.stderr)
        sys.exit(1)

    preview = is_preview_tag(version)
    source = "[Unreleased]" if preview else f"## [{version.split('-', 1)[0]}]"

    if section is None or not has_changelog_content(section.content):
        reason = "missing" if section is None else "empty"
        message = f"Changelog entry in {source} is {reason}."
        if preview:
            print(f"::warning::{message} 本次预览使用占位说明。")
            changelog = "*No changelog entry for this version.*"
        else:
            print(f"::error::{message} 请先补充 {source}。", file=sys.stderr)
            sys.exit(1)
    else:
        changelog = section.content

    output = os.environ.get("GITHUB_OUTPUT", "")
    if output:
        with open(output, "a", encoding="utf-8") as f:
            f.write("changelog<<CHANGELOG_EOF\n")
            f.write(changelog + "\n")
            f.write("CHANGELOG_EOF\n")
    else:
        print(changelog)


if __name__ == "__main__":
    main()
