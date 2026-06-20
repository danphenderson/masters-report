#!/usr/bin/env python3
"""Build a scratch claim/evidence matrix from the reference inventory.

The output is intentionally compact and non-excerpting: it records source
metadata, evidence categories, and page/section cues where a local mirror is
available, but it does not copy source passages.
"""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
from dataclasses import dataclass
from html import unescape
from pathlib import Path


INVENTORY_PATH = Path("public/references/source-inventory.tsv")
BIB_PATH = Path("public/references/references.bib")
DEFAULT_OUTPUT_DIR = Path("tmp/reference-evidence")

FOCUS_KEYWORDS = {
    "model_hierarchy": (
        "three-dimensional",
        "3d",
        "one-dimensional",
        "1d",
        "zero-dimensional",
        "0d",
        "multiscale",
        "reduced model",
        "fluid-structure",
    ),
    "closures": (
        "rheology",
        "wall",
        "boundary condition",
        "outlet",
        "inlet",
        "friction",
        "stenosis",
        "pressure-area",
    ),
    "verification_well_balancing": (
        "verification",
        "validation",
        "manufactured",
        "well-balanced",
        "well balanced",
        "benchmark",
        "convergence",
    ),
    "comparison_observation": (
        "cross-section",
        "section",
        "interface",
        "coupling",
        "observable",
        "flow rate",
        "mean velocity",
        "fractional flow reserve",
    ),
}

TARGET_BY_FOCUS = {
    "model_hierarchy": "report/sections/03-model-hierarchy/index.tex",
    "closures": "report/sections/04-modeling-closures/index.tex",
    "verification_well_balancing": "report/sections/05-numerical-methods/index.tex",
    "comparison_observation": "report/sections/07-case-study/comparison.tex",
}


@dataclass(frozen=True)
class BibEntry:
    title: str = ""
    author: str = ""
    year: str = ""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="repository root")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help="scratch output directory")
    parser.add_argument(
        "--statuses",
        default="current-cited,report-adjacent",
        help="comma-separated source-inventory statuses to scan",
    )
    return parser.parse_args(argv)


def read_inventory(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def read_bib_entries(path: Path) -> dict[str, BibEntry]:
    text = path.read_text(encoding="utf-8")
    entries: dict[str, BibEntry] = {}
    for match in re.finditer(r"@\w+\s*\{\s*([^,\s]+)\s*,(.*?)(?=\n@\w+\s*\{|\Z)", text, re.S):
        key = match.group(1)
        body = match.group(2)
        entries[key] = BibEntry(
            title=bib_field(body, "title"),
            author=bib_field(body, "author"),
            year=bib_field(body, "year"),
        )
    return entries


def bib_field(body: str, field: str) -> str:
    match = re.search(rf"\b{re.escape(field)}\s*=\s*[\{{\"](.*?)[\}}\"]\s*,", body, re.S | re.I)
    if not match:
        return ""
    value = re.sub(r"\s+", " ", match.group(1)).strip()
    return value.replace("{", "").replace("}", "")


def extract_text(path: Path) -> tuple[str, bool]:
    if not path.exists():
        return "", False
    suffix = path.suffix.lower()
    if suffix == ".pdf":
        result = subprocess.run(
            ["pdftotext", "-layout", path.as_posix(), "-"],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            return "", True
        return result.stdout, True
    if suffix in {".html", ".htm"}:
        raw = path.read_text(encoding="utf-8", errors="replace")
        text = re.sub(r"(?is)<(script|style).*?</\1>", " ", raw)
        text = re.sub(r"(?s)<[^>]+>", " ", text)
        return unescape(re.sub(r"\s+", " ", text)), True
    return "", True


def focus_hits(text: str) -> dict[str, tuple[int, str]]:
    lower = text.lower()
    pages = lower.split("\f") if text else [""]
    hits: dict[str, tuple[int, str]] = {}
    for focus, keywords in FOCUS_KEYWORDS.items():
        for page_index, page in enumerate(pages, start=1):
            for keyword in keywords:
                if keyword in page:
                    hits[focus] = (page_index, keyword)
                    break
            if focus in hits:
                break
    return hits


def infer_focus_from_metadata(row: dict[str, str]) -> dict[str, tuple[int, str]]:
    haystack = f"{row.get('manuscript_role', '')} {row.get('notes', '')} {row.get('source_id', '')}".lower()
    hits: dict[str, tuple[int, str]] = {}
    for focus, keywords in FOCUS_KEYWORDS.items():
        for keyword in keywords:
            if keyword in haystack:
                hits[focus] = (0, keyword)
                break
    return hits


def build_rows(repo: Path, statuses: set[str]) -> list[dict[str, object]]:
    inventory = read_inventory(repo / INVENTORY_PATH)
    bib_entries = read_bib_entries(repo / BIB_PATH)
    evidence_rows: list[dict[str, object]] = []
    for row in inventory:
        if row["status"] not in statuses:
            continue
        local_path = repo / row["local_path"]
        text, local_present = extract_text(local_path)
        hits = focus_hits(text) if text else infer_focus_from_metadata(row)
        if not hits:
            continue
        bib = bib_entries.get(row["bib_key"], BibEntry())
        for focus, (page, keyword) in sorted(hits.items()):
            evidence_rows.append(
                {
                    "source_id": row["source_id"],
                    "bib_key": row["bib_key"],
                    "status": row["status"],
                    "title": bib.title,
                    "year": bib.year,
                    "author": bib.author,
                    "manuscript_role": row["manuscript_role"],
                    "evidence_focus": focus,
                    "evidence_signal": keyword,
                    "page_cue": f"p. {page}" if page else "inventory metadata",
                    "local_mirror_present": str(local_present).lower(),
                    "manuscript_target": TARGET_BY_FOCUS[focus],
                    "notes": row["notes"],
                }
            )
    return evidence_rows


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    fieldnames = (
        "source_id",
        "bib_key",
        "status",
        "title",
        "year",
        "author",
        "manuscript_role",
        "evidence_focus",
        "evidence_signal",
        "page_cue",
        "local_mirror_present",
        "manuscript_target",
        "notes",
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_markdown(path: Path, rows: list[dict[str, object]]) -> None:
    counts: dict[str, int] = {}
    for row in rows:
        focus = str(row["evidence_focus"])
        counts[focus] = counts.get(focus, 0) + 1
    lines = [
        "# Reference Claim/Evidence Matrix",
        "",
        "Scratch, non-excerpting support matrix generated from `public/references/source-inventory.tsv`,",
        "`public/references/references.bib`, and available local mirrors.",
        "",
        "## Counts",
        "",
    ]
    lines.extend(f"- {focus}: {counts[focus]}" for focus in sorted(counts))
    lines.extend(["", "## Manuscript Targets", ""])
    for target in sorted({str(row["manuscript_target"]) for row in rows}):
        target_rows = [row for row in rows if row["manuscript_target"] == target]
        lines.append(f"- `{target}`: {len(target_rows)} supporting rows")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    repo = args.repo.resolve()
    statuses = {status.strip() for status in args.statuses.split(",") if status.strip()}
    rows = build_rows(repo, statuses)
    output_dir = args.output_dir if args.output_dir.is_absolute() else repo / args.output_dir
    csv_path = output_dir / "claim-evidence-matrix.csv"
    md_path = output_dir / "claim-evidence-matrix.md"
    write_csv(csv_path, rows)
    write_markdown(md_path, rows)
    print(f"claim_evidence_matrix_csv,{csv_path}")
    print(f"claim_evidence_matrix_md,{md_path}")
    print(f"claim_evidence_rows,{len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
