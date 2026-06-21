"""External handoff packet checks."""

from __future__ import annotations

from .models import CheckResult
from .policy import OVERBROAD_PACKET_PATTERNS, PACKET_STALE_PATTERNS, PACKET_VALIDATION_NEEDLES


def packet_check(text: str, profile: str = "generic") -> CheckResult:
    issues: list[str] = []
    for label, pattern in PACKET_STALE_PATTERNS:
        if pattern.search(text):
            issues.append(label)
    if "public/final-report.pdf" not in text:
        issues.append("missing final PDF artifact guardrail: public/final-report.pdf")
    if "report/assets/rendered" not in text:
        issues.append("missing rendered report asset guardrail: report/assets/rendered/**")
    if not any(needle in text for needle in PACKET_VALIDATION_NEEDLES):
        issues.append("missing current ops validation command")
    if any(pattern.search(text) for pattern in OVERBROAD_PACKET_PATTERNS):
        issues.append("overbroad packet authority: avoid regenerate/rewrite/modify-as-needed language")
    if profile != "generic" and profile not in text:
        issues.append(f"missing packet profile marker: {profile}")
    return CheckResult(status="failed" if issues else "passed", issues=tuple(dict.fromkeys(issues)))
