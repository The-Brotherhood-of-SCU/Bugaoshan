"""Extract current and previous version tags for release notes."""

import subprocess
import os
import re

def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()

def main():
    current_tag = os.environ.get("VERSION", "").lstrip("v")
    if not current_tag:
        current_tag = os.environ.get("GITHUB_REF_NAME", "").replace("refs/tags/", "").lstrip("v")

    all_tags = run(["git", "tag", "--sort=-version:refname"]).split("\n")
    version_tags = [t for t in all_tags if re.match(r"^v\d+\.\d+\.\d+$", t)]

    prev_tag = next((t for t in version_tags if t != f"v{current_tag}"), None)

    if not prev_tag:
        prev_tag = run(["git", "rev-list", "--max-parents=0", "HEAD"])
        tag_range = f"{prev_tag}..HEAD"
        prev_display = f"{prev_tag[:7]} (initial commit)"
    else:
        tag_range = f"{prev_tag}..HEAD"
        prev_display = prev_tag

    output = os.environ.get("GITHUB_OUTPUT", "")
    if output:
        with open(output, "a", encoding="utf-8") as f:
            f.write(f"tag=v{current_tag}\n")
            f.write(f"range={tag_range}\n")
            f.write(f"prev={prev_display}\n")
    else:
        print(f"tag=v{current_tag}")
        print(f"range={tag_range}")
        print(f"prev={prev_display}")

if __name__ == "__main__":
    main()