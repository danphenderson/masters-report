import subprocess
import sys
from pathlib import Path


def test_references_inventory_audit_passes_current_tree() -> None:
    repo = Path(__file__).resolve().parents[1]
    result = subprocess.run(
        [sys.executable, "scripts/audit_references.py"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
