# Lightweight Agent Workflows

This repository uses a small `ops-orchestrate` command surface for bounded
agent handoffs. It is a planning and checking aid, not an executor.

No repo-managed commit hooks are part of this workflow. There is no background
automation and no persistent orchestration receipts. Agents should re-anchor on
the live checkout, use local files and validation output as evidence, and keep
mutation scoped to explicitly named files.

## Command Surface

```sh
pipenv run ops-orchestrate status
pipenv run ops-orchestrate dispatch --surface report --mode inspect --objective "Review section scope"
pipenv run ops-orchestrate handback-check --path /tmp/handback.md --surface report --mode inspect
pipenv run ops-orchestrate docs-contract
```

`status` classifies dirty paths by surface and flags protected/generated
artifact drift. Use `--strict` when protected artifacts or unclassified paths
should fail a readiness check.

`dispatch` prints a copy-paste-ready task packet. It does not write files. Name
exact files with `--files` before allowing edits.

`handback-check` validates that a worker handback includes `Status`, `Scope`,
`Files`, `Validation`, and `Risks`, and that the expected validation command is
present or deliberately skipped with a reason.

`docs-contract` checks that the documented orchestration surface still matches
the live lightweight contract.

## Surfaces And Modes

Supported surfaces are `report`, `julia`, `ops`, `references`, `assets`, and
`release`.

Supported modes are:

- `inspect`: read and report only.
- `bounded-edit`: edit only named files and preserve unrelated dirty work.
- `hard-review`: findings-first review; no edits.
- `artifact-refresh`: explicitly allows generated report-artifact refreshes
  after the owning gate passes.

## Validation Defaults

- `report`: `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`
- `julia`: `packages/julia/bin/julia-release packages/julia/test/runtests.jl`
- `ops`: `pipenv run ops-python-check`
- `references`: `pipenv run ops-audit-references`, targeted reference/preamble
  tests, and `biber --tool --validate-datamodel`
- `assets`: the owning renderer or Julia workflow, followed by a report build
  with `--no-sync-final-pdf`
- `release`: the publication-readiness checks plus Julia, Python, reference, and
  report validation

Use `artifact-refresh` only when a tracked rendered asset or
`public/final-report.pdf` is intentionally in scope.
