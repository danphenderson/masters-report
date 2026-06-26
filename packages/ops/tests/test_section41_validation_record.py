from pathlib import Path


def test_section41_production_validation_record_covers_required_gate_contracts() -> None:
    root = Path(__file__).resolve().parents[3]
    record = root / "public/docs/stenotic-hemodynamics/section-4-1-production-validation-record.md"
    text = record.read_text(encoding="utf-8")

    assert "danphenderson/masters-report#9" in text
    assert "poiseuille_inlet_zero_outlet_stress_section41" in text
    assert "/home/runner/work/masters-report/masters-report" not in text
    assert "tmp/simulations/output/native-resolved-fsi-production" in text

    for case_id in ("sev23", "sev40", "sev50"):
        assert f"--case-id {case_id}" in text
        assert f"native-resolved-fsi-production/{case_id}/120x5x32" in text

    for gate in (
        "Dry-run and guard review",
        "Native finite-field gate",
        "Displacement and wall-state gate",
        "Pressure normalization gate",
        "Importer round-trip gate",
        "Observation row gate",
        "Parity summary gate",
        "Manuscript claim readiness",
    ):
        assert gate in text

    for imported_case in ("77", "60", "50"):
        assert f"| `{imported_case}` | `public/var/data/simulations/canic_case3/{imported_case}` |" in text

    assert "not-executed" in text
    assert "No manuscript claim advances from this record" in text
