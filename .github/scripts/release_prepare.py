"""Prepare release files for upload."""

import os
import shutil
from pathlib import Path


def _android_asset_suffix(filename):
    if filename in ("app-release.apk", "app-universal-release.apk"):
        return "universal"
    prefix = "app-"
    suffix = "-release.apk"
    if filename.startswith(prefix) and filename.endswith(suffix):
        return filename[len(prefix) : -len(suffix)]
    return None


def prepare_release_files(version, root=Path(".")):
    root = Path(root)
    version = version.lstrip("v")
    android_dir = root / "android-apk"

    universal = android_dir / "app-universal-release.apk"
    raw_universal = android_dir / "app-release.apk"
    if not universal.exists() and not raw_universal.exists():
        raise FileNotFoundError("Missing universal Android updater APK")

    for apk in sorted(android_dir.glob("*.apk")):
        arch = _android_asset_suffix(apk.name)
        if arch is None:
            continue
        if arch == "universal" and apk == raw_universal and universal.exists():
            continue
        dst = root / f"bugaoshan_{version}_{arch}.apk"
        shutil.copy2(apk, dst)
        print(f"Copied {apk} -> {dst}")

    windows_src = root / "windows-release" / "windows-release.zip"
    shutil.copy2(windows_src, root / f"bugaoshan_{version}_windows_x64.zip")
    print("Copied windows artifact")

    linux_src = root / "linux-release" / "linux-release.tar.gz"
    shutil.copy2(linux_src, root / f"bugaoshan_{version}_linux_x64.tar.gz")
    print("Copied linux artifact")


def main():
    version = os.environ.get("VERSION", "")
    prepare_release_files(version)


if __name__ == "__main__":
    main()
