import csv
from pathlib import Path

from ops import extract_reference_claims


def write_tsv(path: Path, fieldnames: tuple[str, ...], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)


def test_extract_reference_claims_writes_scratch_outputs_and_live_target_mapping(tmp_path: Path) -> None:
    repo = tmp_path
    (repo / "public/references").mkdir(parents=True)
    (repo / "public/references/references.bib").write_text(
        "@article{FormaggiaEtAl2003OneDimensionalBloodFlow,\n"
        "  title = {One-Dimensional Models for Blood Flow},\n"
        "  author = {L. Formaggia},\n"
        "  year = {2003},\n"
        "}\n",
        encoding="utf-8",
    )
    write_tsv(
        repo / "public/references/source-inventory.tsv",
        ("source_id", "bib_key", "local_path", "status", "manuscript_role", "notes"),
        [
            {
                "source_id": "formaggia_review",
                "bib_key": "FormaggiaEtAl2003OneDimensionalBloodFlow",
                "local_path": "public/references/missing-local-mirror.pdf",
                "status": "current-cited",
                "manuscript_role": "1D model hierarchy review support",
                "notes": "one-dimensional reduced model overview for the hierarchy section",
            }
        ],
    )

    exit_code = extract_reference_claims.main(["--repo", repo.as_posix()])

    csv_path = repo / "tmp/reference-evidence/claim-evidence-matrix.csv"
    md_path = repo / "tmp/reference-evidence/claim-evidence-matrix.md"

    assert exit_code == 0
    assert csv_path.exists()
    assert md_path.exists()

    with csv_path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    assert any(
        row["evidence_focus"] == "model_hierarchy"
        and row["manuscript_target"] == "report/sections/03-model-hierarchy/index.tex"
        for row in rows
    )
    assert "report/sections/03-model-hierarchy/index.tex" in md_path.read_text(encoding="utf-8")
