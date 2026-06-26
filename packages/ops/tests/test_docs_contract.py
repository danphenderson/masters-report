import tomllib
from pathlib import Path

from ops import orchestrate


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def write_minimal_docs_contract(root: Path) -> None:
    (root / "public/docs/markdown").mkdir(parents=True)
    command_lines = "\n".join(f"pipenv run ops-orchestrate {command}" for command in orchestrate.COMMANDS)
    profile_lines = "\n".join(orchestrate.PROFILES)
    contract_text = "\n".join(
        [
            command_lines,
            profile_lines,
            "Tracked pre-commit config is allowed; local hook installation is explicit.",
            "No background automation.",
            "No persistent orchestration receipts.",
            "Use GitHub issues with ops-orchestrate status for coordination.",
        ]
    )
    for relative in orchestrate.DOC_CONTRACT_PATHS:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contract_text, encoding="utf-8")


def test_orchestration_docs_contract_passes_current_tree() -> None:
    result = orchestrate.docs_contract(repo_root())

    assert result.status == "passed", result.issues


def test_ops_orchestrate_entrypoint_is_packaged() -> None:
    pyproject = tomllib.loads((repo_root() / "packages/ops/pyproject.toml").read_text(encoding="utf-8"))

    assert pyproject["project"]["scripts"]["ops-orchestrate"] == "ops.orchestrate:main"


def test_validation_entrypoints_are_packaged_and_declared_in_pipfile() -> None:
    root = repo_root()
    pyproject = tomllib.loads((root / "packages/ops/pyproject.toml").read_text(encoding="utf-8"))
    pipfile = tomllib.loads((root / "Pipfile").read_text(encoding="utf-8"))

    assert pyproject["project"]["scripts"]["ops-experiment"] == "ops.experiment_runner:main"
    assert pyproject["project"]["scripts"]["ops-julia-check"] == "ops.julia_check:main"
    assert pyproject["project"]["scripts"]["ops-release-check"] == "ops.release_check:main"
    assert pipfile["scripts"]["ops-experiment"] == "python -m ops.experiment_runner"
    assert pipfile["scripts"]["ops-julia-check"] == "python -m ops.julia_check"
    assert pipfile["scripts"]["ops-release-check"] == "python -m ops.release_check"


def test_agent_workflow_doc_names_every_public_command() -> None:
    text = (repo_root() / "public/docs/markdown/agent-workflows.md").read_text(encoding="utf-8")

    for command in orchestrate.COMMANDS:
        assert f"ops-orchestrate {command}" in text


def test_agent_workflow_doc_names_every_profile() -> None:
    text = (repo_root() / "public/docs/markdown/agent-workflows.md").read_text(encoding="utf-8")

    for profile in orchestrate.PROFILES:
        assert profile in text


def test_docs_index_does_not_link_archived_executive_assessment() -> None:
    text = (repo_root() / "public/docs/markdown/index.md").read_text(encoding="utf-8")

    assert "](executive-assessment.md)" not in text


def test_archived_executive_assessment_declares_audited_tree_state() -> None:
    text = (repo_root() / "public/docs/markdown/executive-assessment.md").read_text(encoding="utf-8")

    assert "# Archived Executive Assessment" in text
    assert "Repository state evaluated: `main...origin/main [ahead 4]` with a dirty working" in text
    assert "## Repository State Evaluated" in text


def test_docs_contract_rejects_stale_active_paths(tmp_path: Path) -> None:
    write_minimal_docs_contract(tmp_path)
    (tmp_path / "README.md").write_text(
        "\n".join(
            [
                "pipenv run ops-orchestrate status",
                "Tracked pre-commit config is allowed; local hook installation is explicit.",
                "No background automation.",
                "No persistent orchestration receipts.",
                "Old command: tools/python/build_report.py",
            ]
        ),
        encoding="utf-8",
    )

    result = orchestrate.docs_contract(tmp_path)

    assert result.status == "failed"
    assert any("stale active path reference in README.md" in issue for issue in result.issues)


def test_docs_contract_scans_new_active_public_docs(tmp_path: Path) -> None:
    write_minimal_docs_contract(tmp_path)
    extra_doc = tmp_path / "public/docs/markdown/new-policy.md"
    extra_doc.write_text("Old wrapper: tools/python/build_report.py\n", encoding="utf-8")

    result = orchestrate.docs_contract(tmp_path)

    assert result.status == "failed"
    assert any("stale active path reference in public/docs/markdown/new-policy.md" in issue for issue in result.issues)


def test_docs_contract_scans_nested_public_docs(tmp_path: Path) -> None:
    write_minimal_docs_contract(tmp_path)
    extra_doc = tmp_path / "public/docs/markdown/stenotic-hemodynamics/native.md"
    extra_doc.parent.mkdir(parents=True, exist_ok=True)
    extra_doc.write_text("Old handoff route: packages/stenotic-hemodynamics/TODO.md\n", encoding="utf-8")

    result = orchestrate.docs_contract(tmp_path)

    assert result.status == "failed"
    assert any(
        "stale active path reference in public/docs/markdown/stenotic-hemodynamics/native.md" in issue
        for issue in result.issues
    )


def test_docs_contract_rejects_public_docs_markdown_outside_markdown_dir(tmp_path: Path) -> None:
    write_minimal_docs_contract(tmp_path)
    (tmp_path / "public/docs/old-location.md").write_text("Moved docs source.\n", encoding="utf-8")

    result = orchestrate.docs_contract(tmp_path)

    assert result.status == "failed"
    assert any(
        "public docs Markdown must live under public/docs/markdown: public/docs/old-location.md" in issue
        for issue in result.issues
    )


def test_docs_contract_ignores_generated_docusaurus_markdown(tmp_path: Path) -> None:
    write_minimal_docs_contract(tmp_path)
    node_readme = tmp_path / "public/docs/node_modules/example/README.md"
    node_readme.parent.mkdir(parents=True)
    node_readme.write_text("Dependency package notes.\n", encoding="utf-8")

    result = orchestrate.docs_contract(tmp_path)

    assert result.status == "passed", result.issues


def test_stale_path_check_allows_historical_archive_paths(tmp_path: Path) -> None:
    archive_path = tmp_path / "report/archive/old-notes.md"
    archive_path.parent.mkdir(parents=True)
    archive_path.write_text("Historical command: tools/python/build_report.py\n", encoding="utf-8")

    issues = orchestrate.stale_path_issues(tmp_path, ("report/archive/old-notes.md",))

    assert issues == ()
