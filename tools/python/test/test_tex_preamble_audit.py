import subprocess
import sys
from pathlib import Path


def test_tex_preamble_audit_passes_current_tree() -> None:
    repo = Path(__file__).resolve().parents[3]
    result = subprocess.run(
        [sys.executable, "tools/python/scripts/audit_tex_preamble.py"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
