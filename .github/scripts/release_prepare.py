"""Prepare release files for upload."""

import os
import shutil
import zipfile
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

    windows_src_dir = root / "windows-release"
    if not windows_src_dir.exists() or not windows_src_dir.is_dir():
        raise FileNotFoundError(f"Missing windows release directory: {windows_src_dir}")

    if not any(windows_src_dir.iterdir()):
        raise FileNotFoundError(f"Windows release directory is empty: {windows_src_dir}")
    
    zip_base_name = root / f"bugaoshan_{version}_windows_x64"
    zip_path = root / f"bugaoshan_{version}_windows_x64.zip"

    shutil.make_archive(str(zip_base_name), 'zip', windows_src_dir)

    with zipfile.ZipFile(zip_path, 'r') as zf:
        namelist = zf.namelist()

    if "Bugaoshan.exe" not in namelist:
        zip_path.unlink()
        raise FileNotFoundError(
            f"Invalid Windows artifact: 'Bugaoshan.exe' not found at the root of {zip_path.name}. "
            f"Found contents: {namelist[:5]}..."
        )

    print(f"Archived windows artifact -> {zip_base_name}.zip")


def main():
    version = os.environ.get("VERSION", "")
    prepare_release_files(version)


if __name__ == "__main__":
    main()
