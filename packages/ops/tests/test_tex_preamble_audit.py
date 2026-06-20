import os
import subprocess
import sys
from pathlib import Path


def test_tex_preamble_audit_passes_current_tree() -> None:
    repo = Path(__file__).resolve().parents[3]
    env = os.environ.copy()
    env["PYTHONPATH"] = str(repo / "packages/ops/src")
    result = subprocess.run(
        [sys.executable, "-m", "ops.audit_tex_preamble", "--repo", repo.as_posix()],
        cwd=repo,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
