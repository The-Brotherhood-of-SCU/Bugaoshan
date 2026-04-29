"""Extract git metadata for CI builds and output to GITHUB_OUTPUT."""

import subprocess
import datetime
import os

def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()

def main():
    # Get most recent tag (version sorted), not derived from GITHUB_REF
    tag = run(["git", "tag", "--sort=-version:refname"]).split("\n")[0]

    git_commit = run(["git", "rev-parse", "HEAD"])
    git_commit_date = run(["git", "log", "-1", "--format=%ci"])

    build_time = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+0000")

    outputs = {
        "GIT_TAG": tag,
        "GIT_COMMIT": git_commit,
        "GIT_COMMIT_DATE": git_commit_date,
        "BUILD_TIME": build_time,
    }

    output_path = os.environ.get("GITHUB_OUTPUT", "")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as f:
            for k, v in outputs.items():
                v = v.replace("\n", "\\n")
                # Quote value to preserve spaces/special chars in workflow
                f.write(f'{k}="{v}"\n')
    else:
        # Local fallback: print to stdout
        for k, v in outputs.items():
            print(f"{k}={v}")

if __name__ == "__main__":
    main()