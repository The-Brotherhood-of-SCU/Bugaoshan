"""Parse CHANGELOG.md, resolve the release state, and select release notes.

状态只由 CHANGELOG 与最新正式 tag 决定：
- 最高版本 == 最新正式 tag：常态预览，说明取 `[Unreleased]`。
- 最高版本 > 最新正式 tag：准备期，说明取 `## [最高版本]`。
- 最高版本 < 最新正式 tag：非法。

预览/RC 不做章节回退：`-preview` 只认 `[Unreleased]`，`-rc` 只认基础版本章节。
"""

from dataclasses import dataclass
import re


VERSION_RE = re.compile(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?")
FORMAL_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
HEADER_RE = re.compile(
    r"^##[ \t]+(?P<label>\[[^\]]+\]|\S+)"
    r"(?:[ \t]+-[ \t]+(?P<date>\d{4}-\d{2}-\d{2}))?[ \t]*$"
)


@dataclass(frozen=True)
class ChangelogSection:
    version: str
    date: str | None
    content: str


@dataclass(frozen=True)
class Changelog:
    unreleased: ChangelogSection | None
    versions: list[ChangelogSection]


@dataclass(frozen=True)
class ReleaseState:
    """mode 为 "preview" 或 "rc"；version 是当前目标版本。"""

    mode: str
    version: str
    notes: ChangelogSection | None


def normalize_version(version: str) -> str:
    version = version.strip().removeprefix("v")
    if not VERSION_RE.fullmatch(version):
        raise ValueError(f"Invalid release version: {version!r}")
    return version


def formal_version_tuple(version: str) -> tuple[int, int, int] | None:
    match = FORMAL_RE.fullmatch(version)
    return tuple(int(part) for part in match.groups()) if match else None


def is_preview_tag(version: str) -> bool:
    version = normalize_version(version)
    if "-" not in version:
        return False
    suffix = version.split("-", 1)[1]
    return suffix == "preview" or suffix.startswith("preview.")


def _split_sections(content: str) -> list[tuple[str, str | None, str]]:
    """Split level-2 sections, ignoring headings inside fenced code blocks."""
    sections = []
    current = None
    body = []
    fence = None

    def finish():
        if current is not None:
            sections.append((current[0], current[1], "\n".join(body).strip()))

    for line in content.splitlines():
        marker = re.match(r"^[ \t]*(`{3,}|~{3,})(.*)$", line)
        if marker:
            token, suffix = marker.groups()
            if fence is None:
                fence = token
            elif token[0] == fence[0] and len(token) >= len(fence) and not suffix.strip():
                fence = None
        elif fence is None and re.match(r"^##[ \t]+", line):
            finish()
            current, body = None, []
            header = HEADER_RE.fullmatch(line)
            if header:
                current = (header["label"], header["date"])
            continue
        if current is not None:
            body.append(line)
    finish()
    return sections


def parse_changelog_document(content: str) -> Changelog:
    """Return `[Unreleased]` and formal `## [X.Y.Z]` sections.

    预览/RC 章节（`## [2.6.0-rc1]`）不再参与发布，直接忽略。
    """
    unreleased = None
    versions = []
    seen = set()

    for label, date, text in _split_sections(content):
        clean = label.strip("[]").strip()
        if clean.lower() == "unreleased":
            if unreleased is not None:
                raise ValueError("Duplicate changelog section: [Unreleased]")
            unreleased = ChangelogSection("unreleased", None, text)
            continue

        try:
            version = normalize_version(clean)
        except ValueError:
            continue
        if formal_version_tuple(version) is None:
            continue
        if version in seen:
            raise ValueError(f"Duplicate changelog section: [{version}]")
        seen.add(version)
        versions.append(ChangelogSection(version, date, text))

    return Changelog(unreleased, versions)


def parse_changelog(content: str) -> list[ChangelogSection]:
    return parse_changelog_document(content).versions


def find_version_section(content: str, version: str) -> ChangelogSection | None:
    target = normalize_version(version)
    return next((s for s in parse_changelog(content) if s.version == target), None)


def has_changelog_content(content: str) -> bool:
    """Category headings and blank separators alone are not release notes."""
    return any(
        line.strip()
        and not re.match(r"^#{1,6}\s", line.strip())
        and not re.fullmatch(r"[-*_]{3,}", line.strip())
        for line in content.splitlines()
    )


def resolve_release_state(content: str, latest_formal_version: str | None) -> ReleaseState:
    """Resolve the only valid release state from CHANGELOG and tags.

    Raises ValueError when the changelog cannot describe exactly one next release.
    """
    document = parse_changelog_document(content)
    if not document.versions:
        raise ValueError("CHANGELOG.md 缺少 ## [X.Y.Z] 版本章节")

    highest = max(document.versions, key=lambda s: formal_version_tuple(s.version))
    highest_tuple = formal_version_tuple(highest.version)

    if latest_formal_version is None:
        return ReleaseState("rc", highest.version, highest)

    latest = normalize_version(latest_formal_version)
    latest_tuple = formal_version_tuple(latest)
    if latest_tuple is None:
        raise ValueError(f"Invalid latest formal tag: {latest!r}")

    if highest_tuple < latest_tuple:
        raise ValueError(
            f"CHANGELOG 最高版本 {highest.version} 低于最新正式版 {latest}，请补充新版本章节"
        )
    if highest_tuple == latest_tuple:
        return ReleaseState("preview", latest, document.unreleased)

    unpublished = [
        section
        for section in document.versions
        if formal_version_tuple(section.version) > latest_tuple
    ]
    if len(unpublished) != 1:
        names = "、".join(section.version for section in unpublished)
        raise ValueError(f"CHANGELOG 同时包含多个未发布版本（{names}），请只保留一个")

    if document.unreleased and has_changelog_content(document.unreleased.content):
        raise ValueError(
            f"[Unreleased] 与未发布版本 {highest.version} 同时有内容；"
            f"请先并入 ## [{highest.version}] 并清空 [Unreleased]"
        )

    return ReleaseState("rc", highest.version, highest)


def select_release_notes(content: str, version: str) -> ChangelogSection | None:
    """Return the single section that a release may use.

    - 正式 tag：`## [X.Y.Z]`
    - `-preview` tag：`[Unreleased]`
    - `-rc` / 其他预发布 tag：基础版本 `## [X.Y.Z]`
    """
    document = parse_changelog_document(content)
    target = normalize_version(version)

    if "-" not in target:
        return next((s for s in document.versions if s.version == target), None)

    if is_preview_tag(target):
        return document.unreleased

    base = target.split("-", 1)[0]
    return next((s for s in document.versions if s.version == base), None)
