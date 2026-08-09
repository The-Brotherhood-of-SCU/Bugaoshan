"""Extract git metadata for CI builds and output to GITHUB_OUTPUT."""

import subprocess
import os
import shlex

def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()

def main():
    # Priority: explicit VERSION (workflow_dispatch) > GITHUB_REF_NAME (push tag) > latest tag
    tag = os.environ.get("VERSION", "")
    if not tag:
        ref_name = os.environ.get("GITHUB_REF_NAME", "")
        if ref_name.startswith("v"):
            tag = ref_name
    if not tag:
        tag = run(["git", "tag", "--sort=-version:refname"]).split("\n")[0]

    git_commit = run(["git", "rev-parse", "HEAD"])
    git_commit_date = run(["git", "log", "-1", "--format=%ci"])

    # 注意：不要在这里加入构建时间戳等非确定性输出。
    # Android release 需要与 F-Droid 构建服务器产出逐字节一致的 APK（可复制构建），
    # 同一 commit 的任何两次构建必须得到完全相同的结果。
    outputs = {
        "GIT_TAG": tag,
        "GIT_COMMIT": git_commit,
        "GIT_COMMIT_DATE": git_commit_date,
    }

    output_path = os.environ.get("GITHUB_OUTPUT", "")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as f:
            for k, v in outputs.items():
                v = v.replace("\n", "\\n")
                f.write(f"{k}={shlex.quote(v)}\n")
    else:
        # Local fallback: print to stdout
        for k, v in outputs.items():
            print(f"{k}={v}")

if __name__ == "__main__":
    main()