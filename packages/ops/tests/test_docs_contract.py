import tomllib
from pathlib import Path

from ops import orchestrate


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def test_orchestration_docs_contract_passes_current_tree() -> None:
    result = orchestrate.docs_contract(repo_root())

    assert result.status == "passed", result.issues


def test_ops_orchestrate_entrypoint_is_packaged() -> None:
    pyproject = tomllib.loads((repo_root() / "packages/ops/pyproject.toml").read_text(encoding="utf-8"))

    assert pyproject["project"]["scripts"]["ops-orchestrate"] == "ops.orchestrate:main"


def test_agent_workflow_doc_names_every_public_command() -> None:
    text = (repo_root() / "public/docs/agent-workflows.md").read_text(encoding="utf-8")

    for command in orchestrate.COMMANDS:
        assert f"ops-orchestrate {command}" in text
