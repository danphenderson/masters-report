#!/usr/bin/env python3
"""Build a scratch literature-review depth matrix.

The matrix is a non-excerpting planning artifact.  It combines the curated
source inventory with the scratch claim/evidence matrix and records how each
source can support review synthesis without copying full-text passages.
"""

from __future__ import annotations

import argparse
import csv
import re
from collections import defaultdict
from pathlib import Path


INVENTORY_PATH = Path("references/source-inventory.tsv")
BIB_PATH = Path("references/references.bib")
CLAIM_MATRIX_PATH = Path("tmp/reference-evidence/claim-evidence-matrix.csv")
DEFAULT_OUTPUT_DIR = Path("tmp/lit-review-depth")

OUTPUT_FIELDS = (
    "bib_key",
    "source_id",
    "status",
    "review_axis",
    "model_tier",
    "retained_variables",
    "closures",
    "numerics",
    "validation_evidence",
    "observable",
    "source_to_source_contrast",
    "target_section",
    "action",
)

PROMOTE_IF_USED = {
    "Peskin1977NumericalAnalysisBloodFlowHeart",
    "ToninoEtAl2010FAMEAngioFunctional",
    "KelleEtAl2011CoronaryDistensibility",
    "NorgaardEtAl2014NXTFFRCT",
    "TebaldiEtAl2015FFROverview",
    "Blanco2018FFR1D3D",
    "ShaikhEtAl2025CTFFR",
    "Colebank2025HemodynamicsIdentifiability",
    "SimVascular2026Platform",
    "SimVascular2026VascularModelRepository",
}

COMPACT_FUTURE_WORK = {
    "CsalaEtAl2025PCNDE",
    "VelikorodnyEtAl2025DeepOperatorStenosed",
}

FOCUS_TO_AXIS = {
    "model_hierarchy": "model hierarchy",
    "closures": "closures",
    "verification_well_balancing": "verification and well-balancing",
    "comparison_observation": "observation operators",
}

AXIS_TARGETS = {
    "model hierarchy": "report/sections/03-model-hierarchy/index.tex",
    "closures": "report/sections/04-modeling-closures/index.tex",
    "verification and well-balancing": "report/sections/05-numerical-methods/index.tex",
    "observation operators": "report/sections/05-numerical-methods/index.tex; report/sections/06-synthesis/index.tex",
    "clinical observables": "report/sections/04-modeling-closures/index.tex; report/sections/06-synthesis/index.tex",
    "learned methods": "report/sections/03-model-hierarchy/index.tex; report/sections/06-synthesis/index.tex",
    "deferred metadata": "references/source-inventory.tsv",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="repository root")
    parser.add_argument("--claim-matrix", type=Path, default=CLAIM_MATRIX_PATH, help="claim/evidence matrix CSV")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help="scratch output directory")
    return parser.parse_args()


def read_csv(path: Path, *, delimiter: str = ",") -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=delimiter))


def bib_keys(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r"@\w+\s*\{\s*([^,\s]+)", text))


def text_blob(row: dict[str, str], evidence_rows: list[dict[str, str]]) -> str:
    chunks = [
        row.get("source_id", ""),
        row.get("bib_key", ""),
        row.get("status", ""),
        row.get("manuscript_role", ""),
        row.get("notes", ""),
    ]
    for evidence in evidence_rows:
        chunks.extend(
            [
                evidence.get("evidence_focus", ""),
                evidence.get("evidence_signal", ""),
                evidence.get("manuscript_target", ""),
                evidence.get("notes", ""),
            ]
        )
    return " ".join(chunks).lower()


def infer_axes(row: dict[str, str], evidence_rows: list[dict[str, str]], blob: str) -> list[str]:
    axes = sorted(
        {
            FOCUS_TO_AXIS[evidence["evidence_focus"]]
            for evidence in evidence_rows
            if evidence.get("evidence_focus") in FOCUS_TO_AXIS
        }
    )
    if axes:
        return axes
    if any(token in blob for token in ("ffr", "ct-ffr", "functional", "pressure-ratio", "clinical")):
        return ["clinical observables"]
    if any(token in blob for token in ("pinn", "neural", "operator", "surrogate", "deep")):
        return ["learned methods"]
    if not row.get("bib_key"):
        return ["deferred metadata"]
    return ["model hierarchy"]


def infer_model_tier(blob: str) -> str:
    if any(token in blob for token in ("pinn", "neural", "operator", "surrogate", "deep")):
        return "learned map"
    if any(token in blob for token in ("multiscale", "3d-1d", "1d-3d")):
        return "geometrical multiscale"
    if any(token in blob for token in ("zero", "0d", "network", "windkessel", "terminal")):
        return "0D/network"
    if any(token in blob for token in ("one-dimensional", "1d", "area-flow", "arterial")):
        return "1D"
    if any(token in blob for token in ("fsi", "fluid-structure", "compliant wall")):
        return "FSI"
    if any(token in blob for token in ("three-dimensional", "3d", "cfd", "navier-stokes", "stokes", "heart")):
        return "3D CFD"
    if any(token in blob for token in ("ffr", "ct-ffr", "pressure-ratio", "functional")):
        return "clinical/diagnostic observable"
    return "cross-tier review"


def infer_retained_variables(model_tier: str) -> str:
    if model_tier == "3D CFD":
        return "velocity, pressure, stress-derived wall quantities"
    if model_tier == "FSI":
        return "fluid velocity/pressure plus wall displacement or structural state"
    if model_tier == "1D":
        return "cross-sectional area, flow, mean velocity, pressure or wall-law surrogate"
    if model_tier == "0D/network":
        return "lumped pressures, flows, volumes, terminal states"
    if model_tier == "geometrical multiscale":
        return "tier-specific states linked by pressure, flow, traction, or impedance"
    if model_tier == "learned map":
        return "learned solution, inverse, or function-to-function map"
    if model_tier == "clinical/diagnostic observable":
        return "pressure ratio, flow reserve, imaging-derived geometry or function"
    return "source-specific"


def infer_closures(blob: str) -> str:
    closures: list[str] = []
    if any(token in blob for token in ("rheology", "viscosity", "carreau", "casson", "hematocrit")):
        closures.append("rheology")
    if any(token in blob for token in ("wall", "pressure-area", "distensibility", "compliance", "fsi")):
        closures.append("wall mechanics")
    if any(token in blob for token in ("boundary", "inlet", "outlet", "windkessel", "terminal", "impedance")):
        closures.append("boundary data")
    if any(token in blob for token in ("stenosis", "geometry", "radius", "lesion", "segmentation")):
        closures.append("geometry/stenosis representation")
    if any(token in blob for token in ("profile", "friction", "alpha", "momentum")):
        closures.append("velocity profile/friction")
    return "; ".join(closures) if closures else "not primary"


def infer_numerics(blob: str, model_tier: str) -> str:
    if any(token in blob for token in ("finite-volume", "finite volume", "lax", "well-balanced", "benchmark", "weno")):
        return "finite-volume/high-resolution balance-law methods"
    if any(token in blob for token in ("finite-element", "finite element", "stokes", "navier-stokes", "fsi")):
        return "finite-element or coupled FSI methods"
    if any(token in blob for token in ("verification", "validation", "manufactured", "repository", "platform")):
        return "verification, validation, or reproducibility infrastructure"
    if model_tier == "learned map":
        return "training loss, residual, operator-learning, or surrogate numerics"
    return "not primary"


def infer_validation(blob: str, status: str) -> str:
    if any(token in blob for token in ("benchmark", "repository", "platform", "openbf", "simvascular")):
        return "benchmark/open-resource reproducibility evidence"
    if any(token in blob for token in ("verification", "manufactured", "convergence", "well-balanced")):
        return "verification or equilibrium-preservation evidence"
    if any(token in blob for token in ("clinical", "ffr", "ct-ffr", "mri", "patient")):
        return "clinical or diagnostic comparison context"
    if status == "needs-review":
        return "not usable until metadata is resolved"
    return "review-context evidence"


def infer_observable(blob: str, model_tier: str) -> str:
    observables: list[str] = []
    if any(token in blob for token in ("ffr", "pressure-ratio", "pressure ratio", "ct-ffr")):
        observables.append("FFR/pressure ratio")
    if "pressure" in blob:
        observables.append("pressure")
    if any(token in blob for token in ("flow", "q", "fractional flow reserve")):
        observables.append("flow")
    if any(token in blob for token in ("velocity", "mean velocity", "profile")):
        observables.append("velocity")
    if any(token in blob for token in ("wss", "wall shear", "traction")):
        observables.append("WSS")
    if any(token in blob for token in ("area", "radius", "distensibility", "compliance")):
        observables.append("area/radius")
    if not observables and model_tier == "learned map":
        observables.append("learned target map")
    return "; ".join(dict.fromkeys(observables)) if observables else "source-specific"


def contrast_for(axis: str, model_tier: str) -> str:
    if axis == "model hierarchy":
        if model_tier == "3D CFD":
            return "resolved velocity/pressure fields vs reduced axial or lumped states"
        if model_tier == "1D":
            return "area-flow propagation vs resolved velocity/stress observables"
        if model_tier == "0D/network":
            return "lumped pressure-flow closure vs distributed local geometry"
        if model_tier == "geometrical multiscale":
            return "interface compatibility vs standalone single-tier modeling"
    if axis == "closures":
        return "same tier can change mathematically through rheology, wall, boundary, profile, or geometry closure"
    if axis == "verification and well-balancing":
        return "implementation verification, equilibrium preservation, benchmarks, and validation are distinct evidence categories"
    if axis == "observation operators":
        return "native model state must be mapped to a common pressure, flow, velocity, WSS, or FFR observable"
    if axis == "clinical observables":
        return "anatomical stenosis severity is not equivalent to pressure-flow functional severity"
    if axis == "learned methods":
        return (
            "surrogate speed and fit must be interpreted through training tier, loss, data, and validation observable"
        )
    return "metadata gap prevents reliable source-to-source comparison"


def action_for(row: dict[str, str], known_bib_keys: set[str]) -> str:
    bib_key = row.get("bib_key", "")
    status = row.get("status", "")
    if not bib_key:
        return "metadata-first; do not cite until BibLaTeX entry is resolved"
    if bib_key not in known_bib_keys:
        return "metadata-first; bib_key is absent from references/references.bib"
    if status == "current-cited":
        return "retain as cited evidence for comparative review claim"
    if status == "report-adjacent" and bib_key in PROMOTE_IF_USED:
        return "candidate promotion: cite only for a concrete synthesis gap, then set current-cited"
    if status == "future-work" and bib_key in COMPACT_FUTURE_WORK:
        return "compact future-work citation only if it sharpens hemodynamics surrogate limitations"
    if status == "report-adjacent":
        return "keep adjacent unless the writing pass exposes a concrete gap"
    if status == "future-work":
        return "defer from main review unless needed for compact future-work framing"
    if status == "background":
        return "background only; exclude from claim-bearing prose"
    return "defer pending review"


def target_for(axis: str, evidence_rows: list[dict[str, str]]) -> str:
    if axis in AXIS_TARGETS:
        return AXIS_TARGETS[axis]
    targets = sorted({row.get("manuscript_target", "") for row in evidence_rows if row.get("manuscript_target", "")})
    return "; ".join(targets) if targets else "report/sections/06-synthesis/index.tex"


def build_rows(repo: Path, claim_matrix_path: Path) -> list[dict[str, str]]:
    inventory_rows = read_csv(repo / INVENTORY_PATH, delimiter="\t")
    claim_rows = read_csv(claim_matrix_path)
    known_bib_keys = bib_keys(repo / BIB_PATH)
    evidence_by_source: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in claim_rows:
        evidence_by_source[row["source_id"]].append(row)

    output_rows: list[dict[str, str]] = []
    for inventory_row in inventory_rows:
        source_evidence = evidence_by_source.get(inventory_row["source_id"], [])
        blob = text_blob(inventory_row, source_evidence)
        model_tier = infer_model_tier(blob)
        for axis in infer_axes(inventory_row, source_evidence, blob):
            output_rows.append(
                {
                    "bib_key": inventory_row.get("bib_key", ""),
                    "source_id": inventory_row.get("source_id", ""),
                    "status": inventory_row.get("status", ""),
                    "review_axis": axis,
                    "model_tier": model_tier,
                    "retained_variables": infer_retained_variables(model_tier),
                    "closures": infer_closures(blob),
                    "numerics": infer_numerics(blob, model_tier),
                    "validation_evidence": infer_validation(blob, inventory_row.get("status", "")),
                    "observable": infer_observable(blob, model_tier),
                    "source_to_source_contrast": contrast_for(axis, model_tier),
                    "target_section": target_for(axis, source_evidence),
                    "action": action_for(inventory_row, known_bib_keys),
                }
            )
    return output_rows


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def write_markdown(path: Path, rows: list[dict[str, str]]) -> None:
    axis_counts: dict[str, int] = defaultdict(int)
    action_counts: dict[str, int] = defaultdict(int)
    blank_bib_rows = 0
    for row in rows:
        axis_counts[row["review_axis"]] += 1
        action_counts[row["action"]] += 1
        if not row["bib_key"]:
            blank_bib_rows += 1

    lines = [
        "# Literature Review Depth Matrix",
        "",
        "Scratch, non-excerpting source triage generated from the source inventory,",
        "bibliography, and claim/evidence matrix. Blank `bib_key` rows are not",
        "usable for citation until metadata is resolved.",
        "",
        f"- matrix rows: {len(rows)}",
        f"- blank-bib rows: {blank_bib_rows}",
        "",
        "## Review Axes",
        "",
    ]
    lines.extend(f"- {axis}: {axis_counts[axis]}" for axis in sorted(axis_counts))
    lines.extend(["", "## Actions", ""])
    lines.extend(f"- {action}: {action_counts[action]}" for action in sorted(action_counts))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    repo = args.repo.resolve()
    claim_matrix_path = args.claim_matrix
    if not claim_matrix_path.is_absolute():
        claim_matrix_path = repo / claim_matrix_path
    output_dir = args.output_dir
    if not output_dir.is_absolute():
        output_dir = repo / output_dir

    rows = build_rows(repo, claim_matrix_path)
    csv_path = output_dir / "review-depth-matrix.csv"
    md_path = output_dir / "review-depth-matrix.md"
    write_csv(csv_path, rows)
    write_markdown(md_path, rows)
    print(f"review_depth_matrix_csv,{csv_path}")
    print(f"review_depth_matrix_md,{md_path}")
    print(f"review_depth_rows,{len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
