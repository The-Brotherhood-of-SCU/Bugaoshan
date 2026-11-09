#!/usr/bin/env python3
"""Run `flutter pub get` against the locked mirror with automatic `pub.dev` fallback.

Why this exists:
The committed `pubspec.lock` pins `https://pub.flutter-io.cn` so local developers in
China, GitHub Actions, and F-Droid reproducible builds all resolve identical dependency
versions and codegen outputs. However, overseas GitHub Actions runners (e.g. `macos-15`
in `westus`) occasionally hit corrupted CDN edge objects or 502 responses on
`pub.flutter-io.cn` when cold-downloading packages (exit code 75: "Downloaded archive
for <pkg> had wrong content-hash").

This script keeps the fast path (`flutter pub get` against `pub.flutter-io.cn`) and, on
failure:
1. Parses `pubspec.lock`, downloads any missing/corrupted hosted archives from the
   official `https://pub.dev/api/archives/<name>-<version>.tar.gz`, verifies the exact
   locked SHA-256, and populates `$PUB_CACHE/hosted/pub.flutter-io.cn/` +
   `$PUB_CACHE/hosted-hashes/pub.flutter-io.cn/`, then retries `flutter pub get`.
2. If `pub.flutter-io.cn` metadata endpoints are completely unreachable, temporarily
   switches `pubspec.lock` to `https://pub.dev` to run `flutter pub get --enforce-lockfile`
   (which also clones git dependencies), mirrors cached packages into the
   `pub.flutter-io.cn` cache namespace, restores `pubspec.lock` byte-for-byte, and
   finishes with `flutter pub get --offline`.
"""

from __future__ import annotations

import concurrent.futures
import hashlib
import io
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

MIRROR_URL = "https://pub.flutter-io.cn"
OFFICIAL_URL = "https://pub.dev"

_HOSTED_PACKAGE_RE = re.compile(
    r"^  [a-zA-Z0-9_]+:\r?\n"
    r"    dependency: [^\r\n]+\r?\n"
    r"    description:\r?\n"
    r"      name: \"?([^\r\n\"]+)\"?\r?\n"
    r"      sha256: \"?([0-9a-fA-F]{64})\"?\r?\n"
    r"      url: \"?([^\r\n\"]+)\"?\r?\n"
    r"    source: hosted\r?\n"
    r"    version: \"?([^\r\n\"]+)\"?",
    re.MULTILINE,
)


@dataclass(frozen=True)
class HostedPackage:
    name: str
    version: str
    sha256: str
    url: str

    @property
    def host_dir(self) -> str:
        parsed = urllib.parse.urlparse(self.url)
        return parsed.netloc or "pub.flutter-io.cn"


def resolve_pub_cache_dir(
    env: dict[str, str] | None = None,
    os_name: str = os.name,
) -> Path:
    env_map = env if env is not None else os.environ
    explicit = env_map.get("PUB_CACHE", "").strip()
    if explicit:
        return Path(explicit).expanduser()
    if os_name == "nt":
        local_app_data = env_map.get("LOCALAPPDATA", "").strip()
        base = Path(local_app_data) if local_app_data else (Path.home() / "AppData" / "Local")
        return base / "Pub" / "Cache"
    return Path.home() / ".pub-cache"


def parse_hosted_packages(lockfile_text: str) -> list[HostedPackage]:
    packages: list[HostedPackage] = []
    for match in _HOSTED_PACKAGE_RE.finditer(lockfile_text):
        name, sha256, url, version = match.groups()
        packages.append(
            HostedPackage(
                name=name.strip(),
                version=version.strip(),
                sha256=sha256.strip().lower(),
                url=url.strip(),
            )
        )
    return packages


def is_package_cached(pub_cache: Path, pkg: HostedPackage) -> bool:
    pkg_dir = pub_cache / "hosted" / pkg.host_dir / f"{pkg.name}-{pkg.version}"
    hash_file = pub_cache / "hosted-hashes" / pkg.host_dir / f"{pkg.name}-{pkg.version}.sha256"
    if not (pkg_dir / "pubspec.yaml").is_file() or not hash_file.is_file():
        return False
    try:
        recorded = hash_file.read_text(encoding="utf-8").strip().lower()
    except OSError:
        return False
    return recorded == pkg.sha256.lower()


def _validate_tar_members(tf: tarfile.TarFile, dest_dir: Path) -> None:
    resolved_dest = dest_dir.resolve()
    for member in tf.getmembers():
        member_path = (resolved_dest / member.name).resolve()
        if member_path != resolved_dest and resolved_dest not in member_path.parents:
            raise ValueError(f"Unsafe tar member path in archive: {member.name!r}")
        if member.issym() or member.islnk():
            link_target = (member_path.parent / member.linkname).resolve()
            if link_target != resolved_dest and resolved_dest not in link_target.parents:
                raise ValueError(
                    f"Unsafe tar link target in archive: {member.name!r} -> {member.linkname!r}"
                )


def download_and_verify_archive(
    pkg: HostedPackage,
    official_base_url: str = OFFICIAL_URL,
    retries: int = 3,
    timeout: int = 30,
) -> bytes:
    quoted_name = urllib.parse.quote(pkg.name, safe="")
    quoted_version = urllib.parse.quote(pkg.version, safe="")
    archive_url = f"{official_base_url.rstrip('/')}/api/archives/{quoted_name}-{quoted_version}.tar.gz"

    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(
                archive_url,
                headers={"User-Agent": "Bugaoshan-CI-PubFallback/1.0"},
            )
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                data = resp.read()
            actual_sha256 = hashlib.sha256(data).hexdigest().lower()
            if actual_sha256 != pkg.sha256.lower():
                raise RuntimeError(
                    f"SHA-256 mismatch for {pkg.name}-{pkg.version} from {archive_url}: "
                    f"expected {pkg.sha256}, got {actual_sha256}"
                )
            return data
        except Exception as exc:
            last_error = exc
            if attempt < retries:
                time.sleep(1.0 * attempt)
    raise RuntimeError(
        f"Failed to download verified archive for {pkg.name}-{pkg.version} after {retries} attempts: {last_error}"
    ) from last_error


def install_archive_to_cache(pub_cache: Path, pkg: HostedPackage, archive_bytes: bytes) -> None:
    actual_sha256 = hashlib.sha256(archive_bytes).hexdigest().lower()
    if actual_sha256 != pkg.sha256.lower():
        raise RuntimeError(
            f"Refusing to install unverified archive for {pkg.name}-{pkg.version}: "
            f"expected {pkg.sha256}, got {actual_sha256}"
        )

    hosted_root = pub_cache / "hosted" / pkg.host_dir
    hashes_root = pub_cache / "hosted-hashes" / pkg.host_dir
    temp_root = pub_cache / "_temp"
    hosted_root.mkdir(parents=True, exist_ok=True)
    hashes_root.mkdir(parents=True, exist_ok=True)
    temp_root.mkdir(parents=True, exist_ok=True)

    target_dir = hosted_root / f"{pkg.name}-{pkg.version}"
    hash_file = hashes_root / f"{pkg.name}-{pkg.version}.sha256"

    extract_dir = Path(tempfile.mkdtemp(prefix=f"{pkg.name}-{pkg.version}-", dir=temp_root))
    try:
        with tarfile.open(fileobj=io.BytesIO(archive_bytes), mode="r:gz") as tf:
            _validate_tar_members(tf, extract_dir)
            tf.extractall(path=extract_dir)
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.move(str(extract_dir), str(target_dir))
        hash_file.write_text(pkg.sha256.lower(), encoding="utf-8")
    finally:
        if extract_dir.exists():
            shutil.rmtree(extract_dir, ignore_errors=True)


def hydrate_missing_hosted_packages(
    lockfile_path: Path,
    pub_cache: Path,
    official_base_url: str = OFFICIAL_URL,
    max_workers: int = 8,
) -> int:
    packages = parse_hosted_packages(lockfile_path.read_text(encoding="utf-8"))
    missing = [pkg for pkg in packages if not is_package_cached(pub_cache, pkg)]
    if not missing:
        print("All hosted packages in pubspec.lock are already verified in PUB_CACHE.", flush=True)
        return 0

    print(
        f"Hydrating {len(missing)}/{len(packages)} hosted package(s) from {official_base_url} "
        f"with SHA-256 verification...",
        flush=True,
    )

    def _fetch_and_install(pkg: HostedPackage) -> str:
        archive_bytes = download_and_verify_archive(pkg, official_base_url=official_base_url)
        install_archive_to_cache(pub_cache, pkg, archive_bytes)
        return f"{pkg.name}-{pkg.version}"

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = {pool.submit(_fetch_and_install, pkg): pkg for pkg in missing}
        for future in concurrent.futures.as_completed(futures):
            pkg = futures[future]
            try:
                future.result()
            except Exception as exc:
                raise RuntimeError(f"Error hydrating {pkg.name}-{pkg.version}: {exc}") from exc

    print(f"Successfully hydrated {len(missing)} package(s) into {pub_cache}.", flush=True)
    return len(missing)


def mirror_pub_dev_cache_to_mirror_host(
    pub_cache: Path,
    mirror_host: str = "pub.flutter-io.cn",
) -> None:
    src_hosted = pub_cache / "hosted" / "pub.dev"
    dst_hosted = pub_cache / "hosted" / mirror_host
    if src_hosted.is_dir():
        dst_hosted.mkdir(parents=True, exist_ok=True)
        for item in src_hosted.iterdir():
            if item.name.startswith(".") or not item.is_dir():
                continue
            target = dst_hosted / item.name
            if not (target / "pubspec.yaml").is_file():
                if target.exists():
                    shutil.rmtree(target)
                shutil.copytree(item, target)

    src_hashes = pub_cache / "hosted-hashes" / "pub.dev"
    dst_hashes = pub_cache / "hosted-hashes" / mirror_host
    if src_hashes.is_dir():
        dst_hashes.mkdir(parents=True, exist_ok=True)
        for item in src_hashes.iterdir():
            if not item.is_file():
                continue
            target = dst_hashes / item.name
            if not target.is_file():
                shutil.copy2(item, target)


def run_flutter_pub_get(extra_args: list[str] | None = None, hosted_url: str = MIRROR_URL) -> int:
    flutter_bin = shutil.which("flutter") or "flutter"
    cmd = [flutter_bin, "pub", "get", *(extra_args or [])]
    env = os.environ.copy()
    env["PUB_HOSTED_URL"] = hosted_url
    print(f"+ PUB_HOSTED_URL={hosted_url} {' '.join(cmd)}", flush=True)
    proc = subprocess.run(cmd, env=env)
    return proc.returncode


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    lockfile_path = repo_root / "pubspec.lock"
    pub_cache = resolve_pub_cache_dir()
    mirror_url = os.environ.get("PUB_HOSTED_URL", MIRROR_URL).strip() or MIRROR_URL

    # Fast path: standard `flutter pub get` against the configured mirror.
    rc = run_flutter_pub_get(hosted_url=mirror_url)
    if rc == 0:
        return 0

    print(
        f"::warning::`flutter pub get` against {mirror_url} failed with exit code {rc}. "
        f"Falling back to verified archive hydration from {OFFICIAL_URL}...",
        flush=True,
    )

    # Tier 1 fallback: hydrate missing/corrupted hosted packages from pub.dev and retry.
    hydrate_missing_hosted_packages(lockfile_path, pub_cache, official_base_url=OFFICIAL_URL)
    rc = run_flutter_pub_get(hosted_url=mirror_url)
    if rc == 0:
        return 0

    print(
        f"::warning::`flutter pub get` against {mirror_url} still failed (exit code {rc}) "
        f"after cache hydration. Running full lockfile fallback via {OFFICIAL_URL}...",
        flush=True,
    )

    # Tier 2 fallback: full metadata outage on mirror — resolve & fetch git deps via pub.dev
    # while keeping `pubspec.lock` byte-for-byte unchanged afterwards.
    original_lock_bytes = lockfile_path.read_bytes()
    try:
        rewritten_text = original_lock_bytes.decode("utf-8").replace(mirror_url, OFFICIAL_URL)
        lockfile_path.write_text(rewritten_text, encoding="utf-8")
        rc = run_flutter_pub_get(
            extra_args=["--enforce-lockfile"],
            hosted_url=OFFICIAL_URL,
        )
        if rc != 0:
            return rc
        mirror_host = urllib.parse.urlparse(mirror_url).netloc or "pub.flutter-io.cn"
        mirror_pub_dev_cache_to_mirror_host(pub_cache, mirror_host=mirror_host)
    finally:
        lockfile_path.write_bytes(original_lock_bytes)

    return run_flutter_pub_get(extra_args=["--offline"], hosted_url=mirror_url)


if __name__ == "__main__":
    sys.exit(main())
