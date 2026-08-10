"""Generate F-Droid metadata changelog files from CHANGELOG.md.

Reads the current version from pubspec.yaml, derives the base versionCode
using Flutter's formula (major*10000 + minor*100 + patch), computes
ABI-specific versionCodes (+1000/+2000/+4000, matching the abiCode*1000+base
rule Flutter's --split-per-abi applies), and writes changelog
files to metadata/{lang}/changelogs/ for each ABI.
"""

import os
import re
import sys
import yaml

# 与 flutter_tools FlutterPlugin.kt 的 ABI_VERSION 表一致：
# versionCode = abiCode * 1000 + base（v7a=1, v8a=2, x86_64=4）
ABI_OFFSETS = {
    "armeabi-v7a": 1000,
    "arm64-v8a": 2000,
    "x86_64": 4000,
}

METADATA_LANGS = ["en-US", "zh-CN"]


def derive_version_code(version_name: str) -> int:
    """Derive Flutter versionCode from versionName using Flutter's formula."""
    parts = version_name.split(".")
    major = int(parts[0])
    minor = int(parts[1]) if len(parts) > 1 else 0
    patch = int(parts[2]) if len(parts) > 2 else 0
    return major * 10000 + minor * 100 + patch


def extract_changelog(version: str, changelog_path: str = "CHANGELOG.md") -> str:
    """Extract the changelog section for the given version from CHANGELOG.md."""
    with open(changelog_path, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    is_prerelease = "-" in version

    if is_prerelease:
        for i, line in enumerate(lines):
            if re.match(r"^##\s", line.strip()):
                start_idx = i
                break
        else:
            return "*No changelog entry for this version.*"
    else:
        pattern = rf"^##\s*\[?{re.escape(version)}\]?(?:\s*-\s*\d{{4}}-\d{{2}}-\d{{2}})?\s*$"
        start_idx = None
        for i, line in enumerate(lines):
            if re.match(pattern, line.strip(), re.IGNORECASE):
                start_idx = i
                break
        if start_idx is None:
            for i, line in enumerate(lines):
                if re.match(r"^##\s*\[Unreleased\]", line.strip(), re.IGNORECASE):
                    start_idx = i
                    break
            if start_idx is None:
                print(f"::error::No changelog entry found for version {version}", file=sys.stderr)
                return None

    end_idx = len(lines)
    for i in range(start_idx + 1, len(lines)):
        if re.match(r"^##\s", lines[i].strip()):
            end_idx = i
            break

    changelog_lines = lines[start_idx + 1:end_idx]
    while changelog_lines and changelog_lines[0].strip() == "":
        changelog_lines.pop(0)
    while changelog_lines and changelog_lines[-1].strip() == "":
        changelog_lines.pop()

    if not changelog_lines:
        return None

    result = []
    for line in changelog_lines:
        stripped = line.strip()
        if re.match(r"^###\s", stripped):
            continue
        result.append(stripped)

    return "\n".join(result) if result else None


def _install_argos_model():
    """Download and install the Argos Translate zh→en model."""
    import argostranslate.package

    argostranslate.package.update_package_index()
    available = argostranslate.package.get_available_packages()
    pkg = next(
        (p for p in available if p.from_code == "zh" and p.to_code == "en"),
        None,
    )
    if pkg is None:
        raise RuntimeError("Argos Translate zh→en package not found in index")
    print("  Downloading Argos Translate zh→en model (~50MB)...")
    pkg_path = pkg.download()
    argostranslate.package.install_from_path(pkg_path)
    print("  Model installed")


def translate_zh_to_en(text: str) -> str:
    """Translate Chinese text to English.

    Layer 1: googletrans (free, best quality)
    Layer 2: Argos Translate (offline OpenNMT, free, no limits)
    Layer 3: Google Translate raw API (free, no key required)
    Layer 4: Original text (fallback)
    """
    # Method 1: deep-translator GoogleTranslator (free, best quality)
    try:
        from deep_translator import GoogleTranslator
        translated = GoogleTranslator(source='zh-CN', target='en').translate(text)
        print("  Translated via Google (deep-translator)")
        return translated
    except Exception as e:
        print(f"  deep-translator failed: {e}")

    # Method 2: Argos Translate (offline, free, no API limits)
    try:
        import argostranslate.package
        import argostranslate.translate

        installed = argostranslate.translate.get_installed_languages()
        zh_lang = next((l for l in installed if l.code == "zh"), None)
        en_lang = next((l for l in installed if l.code == "en"), None)

        if zh_lang is None or en_lang is None or zh_lang.get_translation(en_lang) is None:
            _install_argos_model()
            installed = argostranslate.translate.get_installed_languages()
            zh_lang = next(l for l in installed if l.code == "zh")
            en_lang = next(l for l in installed if l.code == "en")

        translated = zh_lang.get_translation(en_lang).translate(text)
        print("  Translated via Argos Translate")
        return translated
    except Exception as e:
        print(f"  Argos Translate failed: {e}")

    # Method 3: fall back to raw Google Translate API
    try:
        import urllib.parse
        import urllib.request
        import json

        url = "https://translate.googleapis.com/translate_a/single"
        params = urllib.parse.urlencode({
            "client": "gtx",
            "sl": "zh-cn",
            "tl": "en",
            "dt": "t",
            "q": text,
        })
        full_url = f"{url}?{params}"
        req = urllib.request.Request(full_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
        translated = "".join([part[0] for part in data[0] if part[0]])
        print("  Translated via Google Translate API")
        return translated
    except Exception as e:
        print(f"  Google Translate API failed: {e}")

    # Method 4: give up, return original
    print("  All translation methods failed, using original Chinese text")
    return text


def write_changelogs(version_code: int, zh_text: str, en_text: str, root_dir: str = ".") -> list[str]:
    """Write changelog files for all ABIs and languages."""
    created = []
    lang_texts = {"en-US": en_text, "zh-CN": zh_text}
    for lang, text in lang_texts.items():
        changelog_dir = os.path.join(root_dir, "metadata", lang, "changelogs")
        os.makedirs(changelog_dir, exist_ok=True)
        for _abi_name, offset in ABI_OFFSETS.items():
            vc = version_code + offset
            filepath = os.path.join(changelog_dir, f"{vc}.txt")
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(text)
            created.append(filepath)
    return created


def get_version_from_pubspec(pubspec_path: str = "pubspec.yaml") -> str:
    """Extract the version name (without build number) from pubspec.yaml."""
    with open(pubspec_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    raw_version = str(data["version"])
    return raw_version.split("+")[0]


def main():
    version_name = get_version_from_pubspec()
    base_vc = derive_version_code(version_name)

    changelog_zh = extract_changelog(version_name)
    if changelog_zh is None:
        print(f"Warning: No changelog content found for {version_name}, skipping.")
        sys.exit(1)

    print("Translating changelog to English...")
    changelog_en = translate_zh_to_en(changelog_zh)

    created = write_changelogs(base_vc, changelog_zh, changelog_en)
    for f in created:
        print(f"  Created: {f}")

    print(f"\nVersion: {version_name}, base versionCode: {base_vc}")
    for name, offset in ABI_OFFSETS.items():
        print(f"  {name}: {base_vc + offset}")
    print(f"Total files created: {len(created)}")


if __name__ == "__main__":
    main()
