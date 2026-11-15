"""Select the release notes for the target version."""

import os
import sys

from changelog_sections import find_release_notes, has_changelog_content, normalize_version


def main():
    try:
        version = normalize_version(os.environ.get("VERSION", ""))
        with open("CHANGELOG.md", "r", encoding="utf-8") as f:
            section = find_release_notes(f.read(), version)
    except (ValueError, OSError) as error:
        print(f"::error::{error}", file=sys.stderr)
        sys.exit(1)

    if section is None or not has_changelog_content(section.content):
        reason = "missing" if section is None else "empty"
        hint = f"## [{version}]"
        if "-" in version:
            hint += " or ## [Unreleased]"
        message = f"Changelog entry for {version} is {reason}. Please add {hint} before releasing."
        if "-" not in version:
            print(f"::error::{message}", file=sys.stderr)
            sys.exit(1)
        print(f"::warning::{message}")
        changelog = "*No changelog entry for this version.*"
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
