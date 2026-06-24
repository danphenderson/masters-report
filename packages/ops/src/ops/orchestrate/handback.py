"""Worker handback parsing and validation."""

from __future__ import annotations

import re
from dataclasses import dataclass

from .models import CheckResult
from .policy import (
    ALL_HANDBACK_SECTIONS,
    BOILERPLATE_SECTION_BODIES,
    PENDING_VALIDATION_PATTERNS,
    SUCCESS_STATUS_PATTERNS,
    UNSUCCESSFUL_STATUS_PATTERNS,
    VALIDATION_MARKERS,
    handback_sections_for,
)


@dataclass(frozen=True)
class ParsedHandback:
    sections: dict[str, str]


def section_header_pattern(sections: tuple[str, ...] = ALL_HANDBACK_SECTIONS) -> re.Pattern[str]:
    section_names = "|".join(re.escape(name) for name in sections)
    return re.compile(
        rf"^[^\S\r\n]*(?:#+[^\S\r\n]*)?(?P<section>{section_names})\b[^\S\r\n]*:?[^\S\r\n]*(?P<inline>[^\r\n]*)$",
        re.IGNORECASE,
    )


def parse_handback(text: str, sections: tuple[str, ...] = ALL_HANDBACK_SECTIONS) -> ParsedHandback:
    header_pattern = section_header_pattern(sections)
    canonical = {section.lower(): section for section in sections}
    parsed: dict[str, list[str]] = {}
    current: str | None = None
    for line in text.splitlines():
        match = header_pattern.match(line)
        if match is not None:
            current = canonical[match.group("section").lower()]
            parsed.setdefault(current, [])
            inline = match.group("inline").strip()
            if inline:
                parsed[current].append(inline)
            continue
        if current is not None:
            parsed[current].append(line)
    return ParsedHandback(
        sections={
            section: "\n".join(part for part in (body_part.strip() for body_part in body) if part).strip()
            for section, body in parsed.items()
        }
    )


def section_present(text: str, section: str) -> bool:
    return section in parse_handback(text).sections


def section_body(text: str, section: str) -> str:
    return parse_handback(text).sections.get(section, "")


def is_boilerplate_section_body(body: str) -> bool:
    normalized = re.sub(r"\s+", " ", body).strip().strip(".:").lower()
    return normalized in BOILERPLATE_SECTION_BODIES


def has_validation_skip_reason(text: str) -> bool:
    return re.search(r"(?is)\b(skipped|not run)\b.*\b(because|reason|unavailable|optional)\b", text) is not None


def has_orchestrator_validation_scope(text: str) -> bool:
    return re.search(r"(?is)\borchestrator\s+validation\s+scope\b", text) is not None


def has_pending_validation_intent(text: str) -> bool:
    return any(pattern.search(text) for pattern in PENDING_VALIDATION_PATTERNS)


def validation_present(text: str, surface: str, mode: str) -> bool:
    markers = VALIDATION_MARKERS[surface]
    if has_orchestrator_validation_scope(text):
        return all(marker in text for marker in markers)
    if surface == "report" and mode != "artifact-refresh":
        return all(marker in text for marker in markers) and "--no-sync-final-pdf" in text
    return all(marker in text for marker in markers)


def status_allows_validation_skip(status_body: str) -> bool:
    normalized = re.sub(r"\s+", " ", status_body).strip().lower()
    if not normalized:
        return False
    if any(pattern.search(normalized) for pattern in UNSUCCESSFUL_STATUS_PATTERNS):
        return True
    if any(pattern.search(normalized) for pattern in SUCCESS_STATUS_PATTERNS):
        return False
    return False


def check_handback(
    text: str, surface: str | None = None, mode: str = "inspect", profile: str = "generic"
) -> CheckResult:
    handback = parse_handback(text)
    issues = [
        f"missing handback section: {section}"
        for section in handback_sections_for(profile)
        if section not in handback.sections
    ]
    for section in ("Validation", "Risks"):
        if section in handback.sections and is_boilerplate_section_body(handback.sections[section]):
            issues.append(f"insufficient handback section: {section}")

    validation_body = handback.sections.get("Validation", "")
    if has_pending_validation_intent(validation_body):
        issues.append(f"pending validation evidence for surface: {surface or '<unspecified>'}")

    has_skip_reason = has_validation_skip_reason(validation_body)
    if has_skip_reason and not status_allows_validation_skip(handback.sections.get("Status", "")):
        issues.append("validation skip requires a blocked, failed, or no-send Status")

    if surface is not None and not validation_present(validation_body, surface, mode) and not has_skip_reason:
        issues.append(f"missing validation evidence for surface: {surface}")

    return CheckResult(status="failed" if issues else "passed", issues=tuple(issues))
