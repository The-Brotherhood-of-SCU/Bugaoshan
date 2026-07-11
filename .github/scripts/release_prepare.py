"""Prepare release files for upload."""

import os
import glob
import shutil

def main():
    version = os.environ.get("VERSION", "")
    version = version.lstrip("v")

    # Rename APKs
    for apk in glob.glob("android-apk/*.apk"):
        filename = os.path.basename(apk)
        arch = filename.replace("app-", "").replace("-release.apk", "")
        dst = f"bugaoshan_{version}_{arch}.apk"
        shutil.copy(apk, dst)
        print(f"Copied {apk} -> {dst}")

    # Copy zip and tar.gz
    shutil.copy("windows-release/windows-release.zip", f"bugaoshan_{version}_windows_x64.zip")
    print("Copied windows artifact")

    linux_src = "linux-release/linux-release.tar.gz"
    shutil.copy(linux_src, f"bugaoshan_{version}_linux_x64.tar.gz")
    print("Copied linux artifact")

if __name__ == "__main__":
    main()
