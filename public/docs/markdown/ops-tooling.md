# Ops Tooling

Use the root Pipenv environment for Python support tooling. The `packages/ops`
package owns report audits, renderers, orchestration checks, evidence
summaries, and simulation experiment execution. It is not a hemodynamics solver
implementation; experiment runs delegate numerical work to the Julia CLI and own
the process logs.

Install the environment when Python tools are needed:

```sh
PIPENV_VENV_IN_PROJECT=1 pipenv install --dev
```

## Pre-Commit Hook

The repository tracks a pre-commit configuration. Local hook installation is an
explicit developer action:

```sh
pipenv run pre-commit install --install-hooks
```

Run the same fast hook stack manually with:

```sh
pipenv run pre-commit run --all-files
```

The hook intentionally stays lightweight. Run the aggregate patch gate
explicitly before major handbacks, pushes, or release-readiness decisions:

```sh
pipenv run ops-release-check --mode patch --report-outdir /tmp/masters-report-build
```

For ordinary managed commits, use the orchestrator-owned focused gate:

```sh
pipenv run ops-orchestrate ready-to-commit
```

`ready-to-commit` selects focused validation from the dirty surfaces and runs
the lightweight hook as one gate. Use `--all` when the aggregate patch gate is
required. Worker agents should hand back validation scope; the orchestrator or
commit wrapper runs this command immediately before commit.

## Audit And Build Commands

- `pipenv run ops-experiment <julia-command> [options]`: run a Julia simulation,
  study, verification, comparison, or benchmark command while streaming terminal
  output and writing JSONL plus summary JSON logs under `public/var/logs/`.
- `pipenv run ops-julia-check`: run the Julia package test suite through the
  Python ops validation surface. This is the agent-facing wrapper around the
  repository-managed Julia launcher.
- `pipenv run ops-python-check`: run Python tests, Ruff, and Black checks for
  support tooling.
- `pipenv run ops-release-check --mode patch`: run the aggregate validation
  gates on a dirty development tree before major handbacks, pushes, or
  release-readiness decisions.
- `pipenv run ops-release-check --mode release`: run the aggregate validation
  gates with clean-status enforcement and release hygiene scans. Add
  `--sync-final-pdf` only when release-PDF refresh is explicitly in scope.
- `pipenv run ops-audit-tex-preamble`: audit current TeX files for preamble
  boundary violations.
- `pipenv run ops-audit-report-prose --json`: audit the live tracked
  `report/**/*.tex` tree for exact duplicates, near duplicates, and
  topic-owner drift.
- `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`:
  run the validation-only report build gate.
- `pipenv run ops-build-report --outdir /tmp/masters-report-build`: run the full
  report build gate only when `public/final-report.pdf` refresh is in scope.

Use `public/docs/markdown/report-builds.md` for wrapper details and failure handling.

## Experiment Runner

Use `ops-experiment` for reviewer-facing simulation and benchmark runs:

```sh
pipenv run ops-experiment benchmark \
  --profile smoke \
  --output-dir tmp/simulations/output/package_benchmark/smoke \
  --overwrite
```

The runner prints the run id, JSONL log path, summary JSON path, and exact Julia
command before streaming process output. It preserves raw stdout/stderr lines,
parses Julia telemetry blocks when present, records summary artifact lines such
as `benchmark_manifest,...`, and writes a final summary JSON.

Each summary records start and end git snapshots, including dirty status lines.
Use `--dirty-policy warn` by default for ordinary Codex runs, `--dirty-policy
allow` only when the dirty tree is already explained elsewhere, and
`--dirty-policy fail` when a run must not start from a dirty checkout.
Generated log files under `public/var/logs/*.json` and
`public/var/logs/*.jsonl` are ignored local run artifacts; only
`public/var/logs/.gitkeep` is trackable.

## Reference And Literature Commands

- `pipenv run ops-audit-references`: validate bibliography and
  `public/references/source-inventory.tsv` consistency.
- `pipenv run ops-extract-reference-claims`: write scratch claim evidence under
  `tmp/reference-evidence` from the public reference metadata. This produces
  `claim-evidence-matrix.csv` and `claim-evidence-matrix.md` for the literature
  depth workflow.
- `pipenv run ops-build-lit-review-depth`: build scratch literature-depth
  summaries under `tmp/lit-review-depth`; by default it reads the scratch claim
  matrix written by `ops-extract-reference-claims`.

Follow `public/references/AGENTS.md` before editing `public/references/**`.
Do not track private full-text PDF or HTML mirrors.

## Renderer Commands

- `pipenv run ops-render-stenosis-geometry-figures`: render stenosis geometry and
  resolved-flow figures from `report/assets/data/stenosis-geometry` into
  `report/assets/rendered`. Run
  `packages/stenotic-hemodynamics/bin/stenotic-hemodynamics export-assets --overwrite` first
  when the analytic, mesh-view, and Stokes trajectory CSV exports are absent.
- `pipenv run ops-render-package-benchmark-figures --benchmark-dir PATH`: render
  benchmark figures into `report/assets/rendered` and the benchmark summary
  table into `report/assets/tables/package-benchmark`.
- `pipenv run ops-render-ph-refinement-demo`: render the tracked p/h refinement
  PDF figure from `report/assets/data/verification/p_h_refinement_demo.csv`
  into `report/assets/rendered` and the companion table into
  `report/assets/tables/verification`. Use `--formats png --output-dir tmp/...`
  only for scratch review exports.

Treat renderer outputs as report-consumed assets. Publish them only when the TeX
source consumes them and the task explicitly opens an artifact-refresh or asset
refresh scope.

## Orchestration Commands

- `pipenv run ops-orchestrate status`: classify the live dirty tree by handoff
  surface using expanded untracked-file reporting.
- `pipenv run ops-orchestrate sessions --source codex-jsonl --date YYYY-MM-DD --json`:
  summarize local Codex JSONL sessions for the current repository.
- `pipenv run ops-orchestrate dispatch`: print bounded task packets.
- `pipenv run ops-orchestrate review`: print read-only delegated review packets.
- `pipenv run ops-orchestrate bundle`: create a `.tar.gz` ChatGPT PRO dispatch
  bundle, write the exact prompt as `CHATGPT_PRO_PROMPT.md`, and print the
  browser launch prompt derived from the archive's actual included evidence.
- `pipenv run ops-orchestrate handback-check`: validate worker handbacks.
- `pipenv run ops-orchestrate packet-check`: validate external handoff text.
- `pipenv run ops-orchestrate docs-contract`: check the documented
  orchestration contract.
- `pipenv run ops-orchestrate ready-to-commit`: run the centralized
  commit-readiness gate selected from the current dirty surfaces, including the
  report prose audit when report surfaces are dirty.

Use `public/docs/markdown/agent-workflows.md` for modes, profiles, and guardrails.

## Evidence Summary Commands

- `pipenv run ops-summarize-revision-evidence`: write compact revision-evidence
  summaries under `tmp/revision-evidence/summary` by default. It can read
  rest-state CSVs, comparison roots, and optional resolved-3D data under
  `public/var/data/simulations/canic_case3`.

Keep evidence summaries in ignored scratch paths unless a separate policy says
they are report-consumed assets.

## Related Policies

- Use `public/docs/markdown/policy-vocabulary.md` for shared artifact terms.
- Use `public/docs/markdown/report-builds.md` for report wrapper behavior.
- Use `public/docs/markdown/report-assets-and-provenance.md` before rendering tracked
  report assets.
- Use `public/docs/markdown/resolved3d-workflows.md` before using optional resolved-3D
  inputs.
