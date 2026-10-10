"""Generate GitHub release body markdown."""

import os

def main():
    version = os.environ.get("VERSION", "").lstrip("v")
    repo = os.environ.get("REPO", "")
    changelog = os.environ.get("CHANGELOG", "")
    prev = os.environ.get("PREV", "").lstrip("v")

    body = f"""## ⬇️ 下载 (Downloads)
- Android: [arm64-Apk]({repo}/releases/download/v{version}/bugaoshan_{version}_arm64-v8a.apk)
- Windows: [x64 Zip]({repo}/releases/download/v{version}/bugaoshan_{version}_windows_x64.zip)
- macOS: 与 iOS 共用 [App Store 条目](https://apps.apple.com/app/id6813305962)，Mac 版可用状态与版本以商店为准（支持 Apple Silicon 与 Intel）。CI 未签名验证包不作为安装版发布。
- iOS: [App Store](https://apps.apple.com/app/id6813305962) · [TestFlight](https://testflight.apple.com/join/Vyenb6gC)；另提供 [ipa](https://github.com/Visio-Vanitas/Bugaoshan/releases/download/v{version}/bugaoshan_{version}_ios_unsigned.ipa)（ipa仅供理解有关技术的同学测试使用，非技术背景同学请勿下载）

> 💡 **Note**: 当前项目优先保障 Android 端的稳定与体验。 Windows 版本可能存在部分兼容性或体验问题。

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
