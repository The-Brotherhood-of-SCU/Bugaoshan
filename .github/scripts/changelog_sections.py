"""Parse version-scoped changelog sections shared by release consumers."""

from dataclasses import dataclass
import re


VERSION_RE = re.compile(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?")
HEADER_RE = re.compile(
    r"^##[ \t]+(?P<label>\[[^\]]+\]|\S+)"
    r"(?:[ \t]+-[ \t]+(?P<date>\d{4}-\d{2}-\d{2}))?[ \t]*$"
)


@dataclass(frozen=True)
class ChangelogSection:
    version: str
    date: str | None
    content: str


def normalize_version(version: str) -> str:
    version = version.strip().removeprefix("v")
    if not VERSION_RE.fullmatch(version):
        raise ValueError(f"Invalid release version: {version!r}")
    return version


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


def parse_changelog(content: str) -> list[ChangelogSection]:
    sections = []
    seen = set()
    for label, date, text in _split_sections(content):
        if label.startswith("["):
            label = label[1:-1]
        try:
            version = normalize_version(label)
        except ValueError:
            continue
        if version in seen:
            raise ValueError(f"Duplicate changelog section: [{version}]")
        seen.add(version)
        sections.append(ChangelogSection(version, date, text))
    return sections


def find_version_section(content: str, version: str) -> ChangelogSection | None:
    target = normalize_version(version)
    return next((s for s in parse_changelog(content) if s.version == target), None)


def find_unreleased_section(content: str) -> ChangelogSection | None:
    """Return the legacy `## [Unreleased]` staging section, if present."""
    for label, _, text in _split_sections(content):
        if label.strip("[]").strip().lower() == "unreleased":
            return ChangelogSection("unreleased", None, text)
    return None


def find_release_notes(content: str, version: str) -> ChangelogSection | None:
    """Select the section to publish for a release version.

    Formal releases only accept their exact section. Prereleases fall back to
    the legacy [Unreleased] staging section and then to the base version's
    section, so an RC can reuse the notes prepared for its target release.
    """
    target = normalize_version(version)
    sections = parse_changelog(content)
    exact = next((s for s in sections if s.version == target), None)
    if exact is not None and has_changelog_content(exact.content):
        return exact
    if "-" not in target:
        return exact

    unreleased = find_unreleased_section(content)
    if unreleased is not None and has_changelog_content(unreleased.content):
        return unreleased

    base = target.split("-", 1)[0]
    base_section = next((s for s in sections if s.version == base), None)
    if base_section is not None and has_changelog_content(base_section.content):
        return base_section

    # 都为空时返回首个存在的章节，供调用方区分「空置」与「缺失」
    return exact or unreleased or base_section


def has_changelog_content(content: str) -> bool:
    """Category headings and blank separators alone are not release notes."""
    return any(
        line.strip()
        and not re.match(r"^#{1,6}\s", line.strip())
        and not re.fullmatch(r"[-*_]{3,}", line.strip())
        for line in content.splitlines()
    )


def has_unreleased_content(content: str) -> bool:
    """Return True if a legacy ## [Unreleased] section exists with non-empty notes."""
    section = find_unreleased_section(content)
    return section is not None and has_changelog_content(section.content)
