import csv
import runpy
from pathlib import Path


def write_csv(path: Path, fieldnames: tuple[str, ...], rows: list[dict[str, str]], *, delimiter: str = ",") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter=delimiter)
        writer.writeheader()
        writer.writerows(rows)


def test_lit_review_depth_matrix_flags_blank_bib_key(tmp_path: Path) -> None:
    repo = tmp_path
    (repo / "references").mkdir()
    (repo / "references/references.bib").write_text(
        "@article{KnownKey,\n  title = {Known Source},\n  author = {A. Author},\n  year = {2026},\n}\n",
        encoding="utf-8",
    )
    write_csv(
        repo / "references/source-inventory.tsv",
        ("source_id", "bib_key", "local_path", "status", "manuscript_role", "notes"),
        [
            {
                "source_id": "known_source",
                "bib_key": "KnownKey",
                "local_path": "references/known.pdf",
                "status": "current-cited",
                "manuscript_role": "1D model hierarchy",
                "notes": "one-dimensional area-flow benchmark context",
            },
            {
                "source_id": "missing_metadata",
                "bib_key": "",
                "local_path": "references/missing.pdf",
                "status": "report-adjacent",
                "manuscript_role": "multiscale source",
                "notes": "needs BibLaTeX entry before citation",
            },
        ],
        delimiter="\t",
    )
    write_csv(
        repo / "tmp/reference-evidence/claim-evidence-matrix.csv",
        (
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
        ),
        [
            {
                "source_id": "known_source",
                "bib_key": "KnownKey",
                "status": "current-cited",
                "title": "Known Source",
                "year": "2026",
                "author": "A. Author",
                "manuscript_role": "1D model hierarchy",
                "evidence_focus": "model_hierarchy",
                "evidence_signal": "1d",
                "page_cue": "inventory metadata",
                "local_mirror_present": "false",
                "manuscript_target": "report/sections/03-model-hierarchy/index.tex",
                "notes": "",
            }
        ],
    )

    module = runpy.run_path(str(Path(__file__).resolve().parents[3] / "tools/python/scripts/build_lit_review_depth.py"))
    rows = module["build_rows"](repo, repo / "tmp/reference-evidence/claim-evidence-matrix.csv")

    assert module["OUTPUT_FIELDS"] == tuple(rows[0].keys())
    assert any(row["action"] == "retain as cited evidence for comparative review claim" for row in rows)
    assert any(
        row["source_id"] == "missing_metadata"
        and row["action"] == "metadata-first; do not cite until BibLaTeX entry is resolved"
        for row in rows
    )
