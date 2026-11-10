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


def parse_changelog(content: str) -> list[ChangelogSection]:
    sections = []
    seen = set()
    current = None
    body = []
    fence = None

    def finish():
        if current is not None:
            sections.append(ChangelogSection(*current, "\n".join(body).strip()))

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
                label = header["label"]
                if label.startswith("["):
                    label = label[1:-1]
                try:
                    version = normalize_version(label)
                except ValueError:
                    continue
                if version in seen:
                    raise ValueError(f"Duplicate changelog section: [{version}]")
                seen.add(version)
                current = (version, header["date"])
            continue
        if current is not None:
            body.append(line)
    finish()
    return sections


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


def has_unreleased_content(content: str) -> bool:
    """Return True if a legacy ## [Unreleased] section exists and has non-empty notes."""
    in_unreleased = False
    body: list[str] = []
    fence: str | None = None

    for line in content.splitlines():
        marker = re.match(r"^[ \t]*(`{3,}|~{3,})(.*)$", line)
        if marker:
            token, suffix = marker.groups()
            if fence is None:
                fence = token
            elif token[0] == fence[0] and len(token) >= len(fence) and not suffix.strip():
                fence = None
        elif fence is None and re.match(r"^##[ \t]+", line):
            if in_unreleased and has_changelog_content("\n".join(body)):
                return True
            header = HEADER_RE.fullmatch(line)
            label = header["label"].strip("[]").lower() if header else ""
            in_unreleased = label == "unreleased"
            body = []
            continue
        if in_unreleased:
            body.append(line)

    return in_unreleased and has_changelog_content("\n".join(body))
