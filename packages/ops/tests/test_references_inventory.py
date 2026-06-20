import subprocess
import sys
from pathlib import Path

from ops import audit_references


def test_references_inventory_audit_passes_current_tree() -> None:
    repo = Path(__file__).resolve().parents[3]
    result = subprocess.run(
        [sys.executable, "-m", "ops.audit_references"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr


def test_references_inventory_allows_public_metadata_without_tracked_full_text() -> None:
    repo = Path(__file__).resolve().parents[3]
    rows = [
        {
            "_line": "2",
            "source_id": "example",
            "bib_key": "KnownKey",
            "local_path": "public/references/01_report_foundations/example.pdf",
            "status": "current-cited",
            "manuscript_role": "example",
            "notes": "public metadata row",
        }
    ]

    issues = audit_references.check_archive_coverage(repo, rows, set(), {"KnownKey"}, {"KnownKey"})

    assert not [issue for issue in issues if issue.rule == "inventory-path-not-tracked-artifact"]
