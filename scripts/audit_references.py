#!/usr/bin/env python3
"""Audit the local reference archive against the current manuscript."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


INVENTORY_PATH = Path("references/source-inventory.tsv")
INVENTORY_FIELDS = ("source_id", "bib_key", "local_path", "status", "manuscript_role", "notes")
ALLOWED_STATUSES = {
    "current-cited",
    "report-adjacent",
    "future-work",
    "background",
    "needs-review",
    "duplicate-superseded",
}
CURRENT_CITED_ARCHIVE_PREFIXES = (
    "references/70_report_adjacent_candidates/",
    "references/80_future_surrogates_and_pinns/",
    "references/90_background_archive/",
    "references/98_needs_review/",
    "references/99_duplicates_superseded/",
)
REFERENCE_NON_ARTIFACTS = {
    "references/AGENTS.md",
    "references/README.md",
    INVENTORY_PATH.as_posix(),
}


@dataclass(frozen=True)
class AuditIssue:
    path: str
    line: int
    rule: str
    message: str


def strip_latex_comment(line: str) -> str:
    """Remove a LaTeX comment, preserving escaped percent signs."""
    for index, character in enumerate(line):
        if character != "%":
            continue
        backslashes = 0
        cursor = index - 1
        while cursor >= 0 and line[cursor] == "\\":
            backslashes += 1
            cursor -= 1
        if backslashes % 2 == 0:
            return line[:index]
    return line


def git_lines(repo: Path, args: list[str]) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return [line for line in result.stdout.splitlines() if line]


def tracked_reference_artifacts(repo: Path) -> set[str]:
    files = git_lines(repo, ["ls-files", "--", "references"])
    return {path for path in files if path not in REFERENCE_NON_ARTIFACTS}


def tracked_tex_files(repo: Path) -> list[Path]:
    return [repo / path for path in git_lines(repo, ["ls-files", "--", "*.tex"])]


def bib_keys(repo: Path) -> set[str]:
    text = (repo / "references.bib").read_text(encoding="utf-8")
    return set(re.findall(r"@\w+\s*\{\s*([^,\s]+)", text))


def cited_keys(repo: Path) -> set[str]:
    cite_pattern = re.compile(r"\\[A-Za-z]*(?:cite|Cite)[A-Za-z]*\*?(?:\[[^\]]*\])*\{([^{}]+)\}")
    keys: set[str] = set()
    for path in tracked_tex_files(repo):
        for line in path.read_text(encoding="utf-8").splitlines():
            stripped = strip_latex_comment(line)
            for match in cite_pattern.finditer(stripped):
                keys.update(key.strip() for key in match.group(1).split(",") if key.strip())
    return keys


def read_inventory(repo: Path) -> tuple[list[dict[str, str]], list[AuditIssue]]:
    path = repo / INVENTORY_PATH
    if not path.exists():
        return [], [AuditIssue(INVENTORY_PATH.as_posix(), 1, "inventory-missing", "inventory file is missing")]

    rows: list[dict[str, str]] = []
    issues: list[AuditIssue] = []
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if tuple(reader.fieldnames or ()) != INVENTORY_FIELDS:
            observed = ", ".join(reader.fieldnames or ())
            expected = ", ".join(INVENTORY_FIELDS)
            issues.append(
                AuditIssue(
                    INVENTORY_PATH.as_posix(),
                    1,
                    "inventory-header",
                    f"expected header [{expected}], observed [{observed}]",
                )
            )
            return rows, issues
        for line_number, row in enumerate(reader, start=2):
            normalized = {field: (row.get(field) or "").strip() for field in INVENTORY_FIELDS}
            rows.append(normalized | {"_line": str(line_number)})
    return rows, issues


def check_inventory_rows(rows: list[dict[str, str]]) -> list[AuditIssue]:
    issues: list[AuditIssue] = []
    seen_source_ids: dict[str, int] = {}
    seen_paths: dict[str, int] = {}

    for row in rows:
        line = int(row["_line"])
        source_id = row["source_id"]
        local_path = row["local_path"]
        status = row["status"]

        if not source_id:
            issues.append(AuditIssue(INVENTORY_PATH.as_posix(), line, "source-id-empty", "source_id is required"))
        elif source_id in seen_source_ids:
            issues.append(
                AuditIssue(
                    INVENTORY_PATH.as_posix(),
                    line,
                    "source-id-duplicate",
                    f"source_id duplicates line {seen_source_ids[source_id]}: {source_id}",
                )
            )
        else:
            seen_source_ids[source_id] = line

        if not local_path:
            issues.append(AuditIssue(INVENTORY_PATH.as_posix(), line, "local-path-empty", "local_path is required"))
        elif local_path in seen_paths:
            issues.append(
                AuditIssue(
                    INVENTORY_PATH.as_posix(),
                    line,
                    "local-path-duplicate",
                    f"local_path duplicates line {seen_paths[local_path]}: {local_path}",
                )
            )
        else:
            seen_paths[local_path] = line

        if status not in ALLOWED_STATUSES:
            allowed = ", ".join(sorted(ALLOWED_STATUSES))
            issues.append(
                AuditIssue(
                    INVENTORY_PATH.as_posix(),
                    line,
                    "status-invalid",
                    f"status must be one of [{allowed}], observed [{status}]",
                )
            )
    return issues


def check_archive_coverage(
    repo: Path,
    rows: list[dict[str, str]],
    artifacts: set[str],
    known_bib_keys: set[str],
    known_cited_keys: set[str],
) -> list[AuditIssue]:
    issues: list[AuditIssue] = []
    inventory_paths = {row["local_path"] for row in rows}

    for path in sorted(artifacts - inventory_paths):
        issues.append(AuditIssue(path, 1, "artifact-not-in-inventory", "tracked reference artifact is missing"))

    for row in rows:
        line = int(row["_line"])
        local_path = row["local_path"]
        bib_key = row["bib_key"]
        status = row["status"]

        if local_path and not local_path.startswith("references/"):
            issues.append(
                AuditIssue(
                    INVENTORY_PATH.as_posix(),
                    line,
                    "inventory-path-outside-references",
                    f"local_path must stay under references/ or point to a private references mirror: {local_path}",
                )
            )
        elif local_path and local_path in artifacts:
            pass
        elif local_path and Path(local_path).suffix.lower() not in {".pdf", ".html", ".htm"}:
            issues.append(
                AuditIssue(
                    INVENTORY_PATH.as_posix(),
                    line,
                    "inventory-path-not-tracked-artifact",
                    f"non-full-text local_path is not a tracked reference artifact: {local_path}",
                )
            )

        if bib_key and bib_key not in known_bib_keys:
            issues.append(
                AuditIssue(
                    INVENTORY_PATH.as_posix(),
                    line,
                    "bib-key-missing",
                    f"bib_key is not present in references.bib: {bib_key}",
                )
            )

        if status == "current-cited":
            if not bib_key:
                issues.append(
                    AuditIssue(
                        INVENTORY_PATH.as_posix(),
                        line,
                        "current-cited-bib-key-empty",
                        "current-cited rows must declare a bib_key",
                    )
                )
            elif bib_key not in known_cited_keys:
                issues.append(
                    AuditIssue(
                        INVENTORY_PATH.as_posix(),
                        line,
                        "current-cited-key-not-cited",
                        f"current-cited bib_key is not cited by tracked TeX: {bib_key}",
                    )
                )
            if local_path.startswith(CURRENT_CITED_ARCHIVE_PREFIXES):
                issues.append(
                    AuditIssue(
                        INVENTORY_PATH.as_posix(),
                        line,
                        "current-cited-archived",
                        f"current-cited source cannot live in an archive bucket: {local_path}",
                    )
                )

        filename = Path(local_path).name
        if filename.startswith("unknown_") and not local_path.startswith("references/98_needs_review/"):
            issues.append(
                AuditIssue(
                    INVENTORY_PATH.as_posix(),
                    line,
                    "unknown-outside-review",
                    f"unknown metadata files must live under references/98_needs_review/: {local_path}",
                )
            )

    return issues


def check_tex_citations(known_bib_keys: set[str], known_cited_keys: set[str]) -> list[AuditIssue]:
    issues: list[AuditIssue] = []
    for key in sorted(known_cited_keys - known_bib_keys):
        issues.append(AuditIssue("references.bib", 1, "cited-key-missing", f"cited key is missing: {key}"))
    return issues


def audit(repo: Path) -> list[AuditIssue]:
    rows, issues = read_inventory(repo)
    if issues:
        return issues

    artifacts = tracked_reference_artifacts(repo)
    known_bib_keys = bib_keys(repo)
    known_cited_keys = cited_keys(repo)

    issues.extend(check_inventory_rows(rows))
    issues.extend(check_tex_citations(known_bib_keys, known_cited_keys))
    issues.extend(check_archive_coverage(repo, rows, artifacts, known_bib_keys, known_cited_keys))
    return sorted(issues, key=lambda issue: (issue.path, issue.line, issue.rule, issue.message))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="repository root to audit")
    args = parser.parse_args(argv)

    repo = args.repo.resolve()
    issues = audit(repo)
    if issues:
        print(f"Reference audit failed with {len(issues)} issue(s):")
        for issue in issues:
            print(f"{issue.path}:{issue.line}: {issue.rule}: {issue.message}")
        return 1

    print("Reference audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
