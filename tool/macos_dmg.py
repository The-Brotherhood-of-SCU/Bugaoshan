"""Sign, notarize and verify the universal Mac app distributed outside the store.

Run from reviewed main/preview code after the macos-signing environment approval,
with an unsigned bundle built in a separate job. Credentials are passed as file
paths; never print private key material.
"""

import argparse
import datetime
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

from verify_macos_bundle import APP_GROUP, BUNDLE_ID, TEAM_ID, require, verify

SOURCE_REPOSITORY = "The-Brotherhood-of-SCU/Bugaoshan"
TAG_RE = re.compile(r"v\d+\.\d+\.\d+(?:-[A-Za-z0-9][A-Za-z0-9.-]*)?\Z")
MACHO_MAGIC = {bytes.fromhex(x) for x in ("cafebabe", "bebafeca", "cffaedfe", "feedfacf")}


def run(*args):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"{args[0]} failed: {result.stderr}\n{result.stdout}")
    return result.stdout


def asset_name(tag):
    require(bool(TAG_RE.fullmatch(tag)), "Invalid upstream release tag")
    return f"bugaoshan_{tag[1:]}_macos_universal.dmg"


def distribution_version(config):
    require(bool(re.fullmatch(r"\d+\.\d+\.\d+", config.get("version", ""))), "Invalid Mac distribution version")
    require(bool(re.fullmatch(r"[1-9]\d*", config.get("build", ""))), "Invalid Mac distribution build")
    return config["version"], config["build"]


def check_manifest(manifest, dmg, tag, sha, version, build):
    expected = {"schema": 1, "source_repository": SOURCE_REPOSITORY,
                "source_tag": tag, "source_sha": sha, "version": version,
                "build": str(build), "team_id": TEAM_ID, "asset": asset_name(tag),
                "notarization_status": "Accepted"}
    for key, value in expected.items():
        require(manifest.get(key) == value, f"DMG manifest mismatch: {key}")
    require(bool(re.fullmatch(r"[0-9a-f]{40}", sha)), "Invalid source commit")
    require(bool(manifest.get("notarization_id")), "Missing notarization receipt")
    require(Path(dmg).name == expected["asset"], "Unexpected DMG filename")
    require(hashlib.sha256(Path(dmg).read_bytes()).hexdigest() == manifest.get("sha256"),
            "DMG checksum mismatch")


def profile_entitlements(profile_path, bundle_id, certificate_der):
    profile = plistlib.loads(run("security", "cms", "-D", "-i", profile_path).encode())
    require(profile.get("TeamIdentifier") == [TEAM_ID], "Wrong provisioning team")
    require(profile.get("ProvisionsAllDevices") is True, "Profile is not Developer ID distribution")
    expiry = profile["ExpirationDate"].replace(tzinfo=datetime.timezone.utc)
    require(expiry > datetime.datetime.now(datetime.timezone.utc), "Expired Developer ID profile")
    require(certificate_der in profile.get("DeveloperCertificates", []), "Profile does not authorize signing certificate")
    allowed = profile["Entitlements"]
    require(allowed.get("com.apple.application-identifier") == f"{TEAM_ID}.{bundle_id}", "Wrong profile application ID")
    require(APP_GROUP in allowed.get("com.apple.security.application-groups", []), "Profile lacks App Group")
    require(not allowed.get("get-task-allow"), "Development profile cannot ship")
    return allowed


def verify_developer_id(target):
    result = subprocess.run(["codesign", "-d", "--verbose=4", str(target)],
                            capture_output=True, text=True, check=True)
    details = result.stderr
    require(f"Authority=Developer ID Application: Jialin Wang ({TEAM_ID})" in details,
            f"Wrong Developer ID identity: {target}")
    require(f"TeamIdentifier={TEAM_ID}" in details, "Wrong signed team")
    require("Timestamp=" in details, "Missing secure timestamp")
    if Path(target).suffix != ".dmg":
        require("runtime" in details, f"Hardened runtime missing: {target}")


def verify_dmg(dmg, version, build):
    run("codesign", "--verify", "--strict", dmg)
    verify_developer_id(dmg)
    run("xcrun", "stapler", "validate", dmg)
    run("spctl", "--assess", "--type", "open", "--context", "context:primary-signature", "--verbose=2", dmg)
    with tempfile.TemporaryDirectory(prefix="bugaoshan-dmg-check-") as temporary:
        mount = Path(temporary) / "volume"
        run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, dmg)
        try:
            app = mount / "不高山上.app"
            verify(app, signed=True, version=version, build=str(build))
            for target in (app, app / "Contents/PlugIns/CourseWidgetExtension.appex"):
                verify_developer_id(target)
                entitlements = plistlib.loads(run("codesign", "-d", "--entitlements", ":-", target).encode())
                require(not entitlements.get("get-task-allow"), "Debug entitlement in release")
            run("xcrun", "stapler", "validate", app)
            run("spctl", "--assess", "--type", "execute", "--verbose=2", app)
        finally:
            run("hdiutil", "detach", mount)


def notarize(path, credentials):
    result = json.loads(run("xcrun", "notarytool", "submit", path, "--key", credentials["key"],
                            "--key-id", credentials["key_id"], "--issuer", credentials["issuer"],
                            "--wait", "--timeout", "45m", "--output-format", "json"))
    require(result.get("status") == "Accepted", f"Apple notarization failed: {result}")
    return result["id"]


def staple(path):
    # Apple ticket downloads can fail transiently (for example NSURLError -1005).
    # Bound retries and preserve the final failure; never ship an unstapled app.
    for attempt in range(3):
        try:
            return run("xcrun", "stapler", "staple", path)
        except RuntimeError:
            if attempt == 2:
                raise
            print(f"Stapler attempt {attempt + 1}/3 failed for {path}; retrying...", flush=True)
            time.sleep(10 * (attempt + 1))


def sign(args):
    app = args.bundle.resolve()
    verify(app, version=args.version, build=args.build)
    identity = f"Developer ID Application: Jialin Wang ({TEAM_ID})"
    certificate = subprocess.check_output(["security", "find-certificate", "-c", identity, "-p", str(args.keychain)])
    certificate_der = subprocess.check_output(["openssl", "x509", "-outform", "DER"], input=certificate)
    widget = app / "Contents/PlugIns/CourseWidgetExtension.appex"
    with tempfile.TemporaryDirectory(prefix="bugaoshan-entitlements-") as temporary:
        for target, profile, source, identifier in (
            (widget, args.widget_profile, "CourseWidget/CourseWidgetExtension.entitlements", BUNDLE_ID + ".CourseWidget"),
            (app, args.app_profile, "Runner/Release.entitlements", BUNDLE_ID),
        ):
            allowed = profile_entitlements(profile, identifier, certificate_der)
            entitlements = plistlib.loads((args.source / "macos" / source).read_bytes())
            # Expand Xcode placeholders explicitly because this bundle is signed
            # after compilation, outside Xcode's automatic signing machinery.
            if target == app:
                group = f"{TEAM_ID}.{BUNDLE_ID}"
                require(any(group == x or (x.endswith("*") and group.startswith(x[:-1]))
                            for x in allowed.get("keychain-access-groups", [])), "Profile lacks credential Keychain access")
                entitlements["keychain-access-groups"] = [group]
            entitlements["com.apple.application-identifier"] = f"{TEAM_ID}.{identifier}"
            entitlements["com.apple.developer.team-identifier"] = TEAM_ID
            entitlements_file = Path(temporary) / (identifier + ".plist")
            entitlements_file.write_bytes(plistlib.dumps(entitlements))
            shutil.copy2(profile, target / "Contents/embedded.provisionprofile")
            if target == widget:
                # Sign embedded native code inside out. No --deep signing: each
                # framework/plugin receives its own timestamp and runtime flag.
                binaries = []
                for path in app.rglob("*"):
                    if path.is_file() and not path.is_symlink():
                        with path.open("rb") as stream:
                            if stream.read(4) in MACHO_MAGIC:
                                binaries.append(path)
                for binary in sorted(binaries, key=lambda p: len(p.parts), reverse=True):
                    run("codesign", "--force", "--sign", identity, "--keychain", args.keychain,
                        "--timestamp", "--options", "runtime", binary)
                for framework in sorted(app.rglob("*.framework"), key=lambda p: len(p.parts), reverse=True):
                    run("codesign", "--force", "--sign", identity, "--keychain", args.keychain,
                        "--timestamp", "--options", "runtime", framework)
            run("codesign", "--force", "--sign", identity, "--keychain", args.keychain,
                "--timestamp", "--options", "runtime", "--entitlements", entitlements_file, target)
    verify(app, signed=True, version=args.version, build=args.build)
    credentials = {"key": args.notary_key, "key_id": args.notary_key_id, "issuer": args.notary_issuer}
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bugaoshan-notary-") as temporary:
        archive = Path(temporary) / "Bugaoshan.zip"
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, archive)
        notarize(archive, credentials)
        staple(app)
        staging = Path(temporary) / "image"
        staging.mkdir()
        shutil.copytree(app, staging / app.name, symlinks=True)
        (staging / "Applications").symlink_to("/Applications")
        dmg = args.output / asset_name(args.tag)
        run("hdiutil", "create", "-volname", "不高山上", "-srcfolder", staging, "-format", "UDZO", dmg)
        run("codesign", "--sign", identity, "--keychain", args.keychain, "--timestamp", dmg)
        receipt = notarize(dmg, credentials)
        staple(dmg)
    verify_dmg(dmg, args.version, args.build)
    manifest = {"schema": 1, "source_repository": SOURCE_REPOSITORY, "source_tag": args.tag,
                "source_sha": args.sha, "version": args.version, "build": str(args.build),
                "team_id": TEAM_ID, "asset": dmg.name,
                "sha256": hashlib.sha256(dmg.read_bytes()).hexdigest(),
                "notarization_status": "Accepted", "notarization_id": receipt}
    check_manifest(manifest, dmg, args.tag, args.sha, args.version, args.build)
    (args.output / "macos-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Verified notarized Developer ID DMG: {dmg}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["sign", "verify"])
    parser.add_argument("--tag", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--version")
    parser.add_argument("--build")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--source", type=Path, default=Path("."))
    parser.add_argument("--keychain", type=Path)
    parser.add_argument("--app-profile", type=Path)
    parser.add_argument("--widget-profile", type=Path)
    parser.add_argument("--notary-key", type=Path)
    parser.add_argument("--notary-key-id", default=os.environ.get("NOTARY_KEY_ID"))
    parser.add_argument("--notary-issuer", default=os.environ.get("NOTARY_ISSUER_ID"))
    args = parser.parse_args()
    if not args.version or not args.build:
        args.version, args.build = distribution_version(json.loads((args.source / ".github/macos-signing.json").read_text()))
    if args.mode == "sign":
        sign(args)
    else:
        manifest = json.loads((args.output / "macos-manifest.json").read_text())
        dmg = args.output / asset_name(args.tag)
        check_manifest(manifest, dmg, args.tag, args.sha, args.version, args.build)
        verify_dmg(dmg, args.version, args.build)


if __name__ == "__main__":
    main()
