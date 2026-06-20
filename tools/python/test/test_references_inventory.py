import subprocess
import sys
import runpy
from pathlib import Path


def test_references_inventory_audit_passes_current_tree() -> None:
    repo = Path(__file__).resolve().parents[3]
    result = subprocess.run(
        [sys.executable, "tools/python/scripts/audit_references.py"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr


def test_references_inventory_allows_public_metadata_without_tracked_full_text() -> None:
    repo = Path(__file__).resolve().parents[3]
    check_archive_coverage = runpy.run_path(str(repo / "tools/python/scripts/audit_references.py"))[
        "check_archive_coverage"
    ]
    rows = [
        {
            "_line": "2",
            "source_id": "example",
            "bib_key": "KnownKey",
            "local_path": "references/01_report_foundations/example.pdf",
            "status": "current-cited",
            "manuscript_role": "example",
            "notes": "public metadata row",
        }
    ]

    issues = check_archive_coverage(repo, rows, set(), {"KnownKey"}, {"KnownKey"})

    assert not [issue for issue in issues if issue.rule == "inventory-path-not-tracked-artifact"]
