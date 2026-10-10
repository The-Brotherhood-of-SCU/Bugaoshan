"""Check the built Mac app and its embedded widget, not just project settings."""

import argparse
import plistlib
import subprocess
import tempfile
from pathlib import Path

BUNDLE_ID = "io.github.thebrotherhoodofscu.bugaoshan.ios"
APP_GROUP = f"group.{BUNDLE_ID}"
TEAM_ID = "2MDTD66RDG"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def signed_entitlements(bundle):
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(bundle)],
        capture_output=True, check=True,
    )
    return plistlib.loads(result.stdout)


def verify(bundle, signed=False, version=None, build=None):
    bundle = Path(bundle)
    app_info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
    require(app_info.get("LSApplicationCategoryType") == "public.app-category.education",
            "Missing Mac App Store education category")
    if version:
        require(app_info["CFBundleShortVersionString"] == version, "Unexpected app version")
    if build:
        require(app_info["CFBundleVersion"] == build, "Unexpected app build number")

    widget = bundle / "Contents/PlugIns/CourseWidgetExtension.appex"
    # Include Flutter, plugins and FFI native assets: a universal launcher alone
    # does not make the application runnable on Intel and Apple Silicon.
    macho_magic = {bytes.fromhex(value) for value in ["cafebabe", "bebafeca", "cffaedfe", "feedfacf"]}
    for binary in bundle.rglob("*"):
        if not binary.is_file() or binary.is_symlink():
            continue
        with binary.open("rb") as stream:
            is_macho = stream.read(4) in macho_magic
        if is_macho:
            architectures = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
            require({"arm64", "x86_64"}.issubset(architectures), f"Non-universal binary: {binary}")
    for target, identifier in [(bundle, BUNDLE_ID), (widget, f"{BUNDLE_ID}.CourseWidget")]:
        contents = target / "Contents"
        info = plistlib.loads((contents / "Info.plist").read_bytes())
        require(info["CFBundleIdentifier"] == identifier, f"Unexpected Bundle ID in {target}")
        for key in ["CFBundleVersion", "CFBundleShortVersionString"]:
            require(info[key] == app_info[key], f"Widget/app {key} mismatch")
        manifest = plistlib.loads((contents / "Resources/PrivacyInfo.xcprivacy").read_bytes())
        require(bool(manifest.get("NSPrivacyAccessedAPITypes")), f"Missing privacy reasons in {target}")
        binary = contents / "MacOS" / info["CFBundleExecutable"]
        architectures = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
        require({"arm64", "x86_64"}.issubset(architectures), f"Non-universal executable: {binary}")
        if signed:
            subprocess.run(["codesign", "--verify", "--deep", "--strict", str(target)], check=True)
            entitlements = signed_entitlements(target)
            require(entitlements.get("com.apple.security.app-sandbox") is True,
                    f"Signed sandbox entitlement missing: {target}")
            require(APP_GROUP in entitlements.get("com.apple.security.application-groups", []),
                    f"Signed App Group missing: {target}")
            require(not entitlements.get("com.apple.security.cs.allow-jit"),
                    f"Release must not contain debug JIT entitlement: {target}")
            require(not entitlements.get("com.apple.security.network.server"),
                    f"Release must not contain debug server entitlement: {target}")
    if signed:
        entitlements = signed_entitlements(bundle)
        for key in ["com.apple.security.network.client", "com.apple.security.files.user-selected.read-write",
                    "com.apple.security.personal-information.calendars"]:
            require(entitlements.get(key) is True, f"Signed capability missing: {key}")
        require(bool(entitlements.get("keychain-access-groups")), "Signed Keychain group missing")
    print(f"Verified {'signed' if signed else 'unsigned'} universal macOS app: {bundle}")


def verify_package(package):
    signature = subprocess.check_output(["pkgutil", "--check-signature", str(package)], text=True)
    require(f"3rd Party Mac Developer Installer: Jialin Wang ({TEAM_ID})" in signature,
            "Unexpected App Store installer signing certificate")
    with tempfile.TemporaryDirectory(prefix="bugaoshan-macos-export-") as temporary:
        expanded = Path(temporary) / "expanded"
        subprocess.run(["pkgutil", "--expand-full", str(package), str(expanded)], check=True)
        applications = list(expanded.glob("*.pkg/Payload/Bugaoshan.app"))
        require(len(applications) == 1, "Expected one application in the exported package")
        application = applications[0]
        verify(application, signed=True)
        for target in [application, application / "Contents/PlugIns/CourseWidgetExtension.appex"]:
            details = subprocess.run(["codesign", "-d", "--verbose=2", str(target)],
                                     capture_output=True, text=True, check=True).stderr
            require(f"Authority=Apple Distribution: Jialin Wang ({TEAM_ID})" in details,
                    f"Unexpected store distribution signature: {target}")
            entitlements = signed_entitlements(target)
            require(not entitlements.get("get-task-allow"), "Store package contains debug entitlement")
    print(f"Verified App Store package: {package}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--signed", action="store_true")
    parser.add_argument("--version")
    parser.add_argument("--build")
    parser.add_argument("--package", action="store_true")
    args = parser.parse_args()
    if args.package:
        verify_package(args.bundle)
    else:
        verify(args.bundle, args.signed, args.version, args.build)
