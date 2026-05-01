"""Generate GitHub release body markdown."""

import os

def main():
    version = os.environ.get("VERSION", "").lstrip("v")
    repo = os.environ.get("REPO", "")
    changelog = os.environ.get("CHANGELOG", "")
    prev = os.environ.get("PREV", "").lstrip("v")

    body = f"""## ⬇️ 下载 (Downloads)
- Android: [64位]({repo}/releases/download/v{version}/bugaoshan_{version}_arm64-v8a.apk)
- Windows: [x64 Zip]({repo}/releases/download/v{version}/bugaoshan_{version}_windows_x64.zip)
- Linux: [x64 Tar.gz]({repo}/releases/download/v{version}/bugaoshan_{version}_linux_x64.tar.gz)

> 💡 **Note**: 当前项目优先保障 Android 端的稳定与体验。 Windows 和 Linux 版本可能存在部分兼容性或体验问题。

{changelog}

**Full diff:** {repo}/compare/v{prev}...v{version}"""

    output = os.environ.get("GITHUB_OUTPUT", "")
    if output:
        with open(output, "a", encoding="utf-8") as f:
            f.write(f"body<<BODY_EOF\n")
            f.write(body + "\n")
            f.write("BODY_EOF\n")
    else:
        print(body)

if __name__ == "__main__":
    main()