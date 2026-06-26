# StenoticHemodynamics

[![Documentation](https://img.shields.io/badge/docs-online-176d72?logo=githubpages&logoColor=white)](https://danphenderson.github.io/masters-report/)

This repository contains the Julia package, simulations,
tests, and LaTeX source for an idealized stenotic-vessel
hemodynamics master's report. The report source is rooted
at `report/final-report.tex`; the solver package is
`StenoticHemodynamics` under `packages/stenotic-hemodynamics/src/`.

The project is prepared for public peer review as a source tree. It tracks the
current report source and excludes final PDFs from source tracking. A local
ignored `public/final-report.pdf` may exist as a release-artifact candidate, but
ordinary report builds should write to scratch space unless the task explicitly
refreshes that PDF. The repository does not track third-party full-text
reference mirrors, private review notes, local caches, unapproved raw 3D data,
or ordinary simulation outputs. The approved Canic case3 XDMF/HDF5 bundle is
tracked as source data under `public/var/data/simulations/canic_case3/**` with
checksum provenance.

## Prerequisites

- macOS or Linux shell environment.
- Julia 1.12 or newer for package tests, simulations, and benchmarks.
- Python 3 with Pipenv for auxiliary report audits and figure renderers.
- A TeX distribution with `latexmk` and `biber` for report builds.

Resolved-3D comparison workflows use the tracked Canic case3 XDMF/HDF5 source
inputs. Additional external resolved-3D bundles remain out of ordinary source
commits unless a separate data-release policy approves them.

## What Reproduces from a Clean Clone?

| Workflow | Clean public clone? | Notes |
| --- | --- | --- |
| Julia tests | Yes | Uses the ops validation wrapper around the repository-managed Julia launcher; requires the Pipenv environment. |
| Report build | Yes | Uses tracked TeX inputs and derived report assets; writes scratch outputs. |
| Solver smoke simulation | Yes | Writes local output under the requested scratch path. |
| Python audits and render helpers | Yes | Requires `PIPENV_VENV_IN_PROJECT=1 pipenv install --dev` first. |
| Figure rendering | Mostly | Analytic and package-benchmark figures use tracked or locally generated inputs; retained Canic resolved-3D inputs are tracked, while additional external data remains optional. |
| Full resolved-3D comparison | Yes | The approved Canic case3 XDMF/HDF5 bundle is tracked under `public/var/data/simulations/canic_case3/`; explicit missing-root checks still exercise skip behavior. |

## Reviewer Quick Start

Install the ops command surface:

```bash
PIPENV_VENV_IN_PROJECT=1 pipenv install --dev
```

Install the explicit local pre-commit hook when fast commit-time hygiene checks
should run automatically:

```bash
pipenv run pre-commit install --install-hooks
```

Run the same fast hook stack manually with:

```bash
pipenv run pre-commit run --all-files
```

The hook intentionally stays lightweight. Run the aggregate patch gate
explicitly before major handbacks, pushes, or release-readiness decisions:

```bash
pipenv run ops-release-check --mode patch --report-outdir /tmp/masters-report-build
```

Run the official focused commit-readiness gate before staging or committing a
managed lane:

```bash
pipenv run ops-orchestrate ready-to-commit
```

This command selects the focused validation gates from the current dirty
surfaces and also runs the lightweight pre-commit stack. Use
`pipenv run ops-orchestrate ready-to-commit --all` when the full aggregate
patch gate is required.

Run Julia package validation through the agent-facing ops wrapper:

```bash
pipenv run ops-julia-check
```

Build the report from source in a scratch directory:

```bash
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

The report wrapper runs the TeX preamble audit, calls `latexmk -g -pdf
-interaction=nonstopmode -halt-on-error` underneath, writes
`report-build-summary.json` in the scratch outdir, and fails if the `.fls`
recorder shows untracked report inputs consumed by the build.

On success, the scratch directory contains `final-report.pdf`,
`final-report.log`, `final-report.fls`, and `report-build-summary.json`. If the
build fails, inspect the summary JSON and the `latexmk` log in the same scratch
directory. Omit `--no-sync-final-pdf` only when the task explicitly refreshes
the protected release artifact `public/final-report.pdf`.

Run a small solver smoke case:

```bash
pipenv run ops-experiment simulate \
  --nx 32 \
  --tfinal 1e-5 \
  --ic geometry-rest \
  --output tmp/smoke/simulate.csv
```

Validate Python support tooling when report audits or figure renderers are
needed:

```bash
pipenv run ops-julia-check
pipenv run ops-python-check
pipenv run ops-orchestrate status --json
pipenv run ops-orchestrate sessions --source codex-jsonl --date YYYY-MM-DD --json
pipenv run ops-orchestrate ready-to-commit
pipenv run ops-release-check --mode patch --report-outdir /tmp/masters-report-build
```

## Documentation Map

- [`public/docs/markdown/index.md`](public/docs/markdown/index.md): task-oriented map for public
  docs.
- [`public/docs/markdown/report-builds.md`](public/docs/markdown/report-builds.md): report build
  modes, summary JSON, and failure handling.
- [`public/docs/markdown/julia-cli-workflows.md`](public/docs/markdown/julia-cli-workflows.md):
  Julia command families and artifact posture.
- [`public/docs/markdown/stenotic-hemodynamics/workflows.md`](public/docs/markdown/stenotic-hemodynamics/workflows.md):
  Julia package workflow ownership, validation commands, and workflow
  subdirectories.
- [`public/docs/markdown/stenotic-hemodynamics/section-4-1-production-validation-plan.md`](public/docs/markdown/stenotic-hemodynamics/section-4-1-production-validation-plan.md):
  native resolved-FSI Section 4.1 validation roadmap and claim gates.
- [`public/docs/markdown/stenotic-hemodynamics/web-visualization.md`](public/docs/markdown/stenotic-hemodynamics/web-visualization.md):
  static browser visualization export schema and viewer checks.
- [`public/docs/markdown/ops-tooling.md`](public/docs/markdown/ops-tooling.md): Python support
  commands, renderers, and evidence summaries.
- [`public/docs/markdown/report-assets-and-provenance.md`](public/docs/markdown/report-assets-and-provenance.md):
  report asset ownership, TeX consumers, and refresh gates.
- [`public/docs/markdown/resolved3d-workflows.md`](public/docs/markdown/resolved3d-workflows.md):
  tracked Canic resolved-3D data, skip behavior, and publication boundaries.
- [`public/docs/markdown/artifact-policy.md`](public/docs/markdown/artifact-policy.md):
  artifact classes and cleanup guardrails.
- [`public/docs/markdown/agent-workflows.md`](public/docs/markdown/agent-workflows.md): bounded
  agent handoffs and GitHub issue coordination with `ops-orchestrate status`.
- [`public/docs/markdown/publication-readiness.md`](public/docs/markdown/publication-readiness.md):
  public export and release checks.

## Resolved-3D Source Inputs

The approved Canic case3 XDMF/HDF5 inputs under
`public/var/data/simulations/canic_case3/` are tracked source-data inputs for
regenerating derived comparison assets. They are not duplicated under
`report/assets/**`; that tree remains for TeX-consumed or documented published
derived assets. Workflows still skip cleanly or emit skipped rows when pointed
at an explicit missing data root. Additional raw resolved-3D bundles remain out
of ordinary source commits until an archival policy approves them.

## Native Resolved-FSI Status

The Julia package includes native resolved-FSI infrastructure for Section 4.1
case generation, status-only dry runs, three-field XDMF/HDF5 output, restart
audit metadata, schema-v3 durable checkpoint sidecars, qualified internal
split-run resume into forked output roots, and local/imported observation
surfaces. Current evidence is bounded: exact Section 4.1 boundary-mode support,
the mathematical-contract gate, checkpoint metadata validation, and split-run
resume have focused smoke/contract-test coverage. The source tree documents a
bounded one-step `sev23` exact-boundary probe at the `(80, 4, 24)` mesh target
with explicit output ownership and claim-boundary review; it is not full
preproduction execution. The repository does not yet claim public/default
resume, public native production CLI execution, production-scale Section 4.1
reproduction, imported-data parity, monolithic ALE FSI, moving-wall fidelity,
paper-grade reproduction, or clinical validation.

Use `fsi native-status` for status-only planning; it does not run production:

```bash
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics fsi native-status \
  --case-id sev23 \
  --mesh 80x4x24 \
  --dt 1e-4 \
  --tfinal 0.1 \
  --snapshot-times 0.1 \
  --inlet-outlet-boundary-mode poiseuille_inlet_zero_outlet_stress_section41 \
  --inlet-umax 45.0
```

Actual long-running preproduction or production execution remains a qualified
internal workflow and should be launched only with explicit output ownership,
issue-tracker handoff, and claim-boundary review.

## Data and References

Tracked report assets under `report/assets/` include both live TeX-consumed
inputs and documented published support/provenance assets. Rendered PDF/PNG
figure assets remain tracked only when the current TeX source consumes them.

Bibliography metadata lives in `public/references/references.bib`; source provenance lives in
[`public/references/source-inventory.tsv`](public/references/source-inventory.tsv). Public
Git releases do not track third-party full-text PDFs or publisher HTML mirrors
under `public/references/`.

## Licensing

Original code is licensed under the MIT license in [`LICENSE`](LICENSE).
Original report prose and original derived figures are covered by the
documentation notice in [`LICENSE-docs`](LICENSE-docs). Third-party references,
external datasets, and publisher artifacts are excluded from those grants.

## Figure Assets

Regenerate the analytic stenosis geometry CSVs and rendered report assets with:

```bash
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics export-assets --overwrite
pipenv run ops-render-stenosis-geometry-figures
```

The exporter also checks the tracked Canic resolved-3D data under
`public/var/data/simulations/canic_case3/` when resolved-flow figure inputs are
in scope.

## Package Benchmark Pipeline

Run the reproducible package benchmark through the Python ops experiment runner.
The runner streams the underlying Julia CLI output in the terminal and records
JSONL/session-summary logs under `public/var/logs/`. The smoke profile is a
deterministic wiring check:

```bash
pipenv run ops-experiment benchmark \
  --profile smoke \
  --output-dir tmp/simulations/output/package_benchmark/smoke \
  --overwrite
```

For the full overnight benchmark, report-asset publishing workflow, output
schemas, and resolved-3D skip behavior, see
[`public/docs/markdown/benchmark-pipeline.md`](public/docs/markdown/benchmark-pipeline.md).

## Environments

This repository has separate Julia and Python environments.

- Julia simulation work uses `packages/stenotic-hemodynamics/Project.toml` and `packages/stenotic-hemodynamics/Manifest.toml`. Run Julia
  commands through `packages/stenotic-hemodynamics/bin/julia-release`, which selects Julia 1.12 or newer
  and binds the project environment automatically. The solver is the root Julia
  package `StenoticHemodynamics`; programmatic commands should use
  `using StenoticHemodynamics` from this project.
- Local Julia shells source `~/.config/julia/resource-profile.zsh` for the
  batch profile: 10 Julia threads, 2 GC threads, BLAS/OpenMP/vecLib pinned to 1
  thread, and `JULIA_CASE_WORKERS=10` for independent simulation cases. Set
  `JULIA_RESOURCE_PROFILE=off` before shell startup to skip these defaults.
- Python report/support tooling uses the root `Pipfile`, which installs
  `packages/ops` as an editable package. Install it with
  `PIPENV_VENV_IN_PROJECT=1 pipenv install --dev` when audit or
  render utilities are needed. Agent validation commands are exposed as
  `pipenv run ops-*` scripts, including the Julia validation wrapper
  `pipenv run ops-julia-check`.

The Julia and Python environments are intentionally independent; installing one
does not prepare the other.

## Julia Extension Points

The solver package is organized around explicit layers documented in
`packages/stenotic-hemodynamics/src/StenoticHemodynamics/layers.jl`. New numerical methods should enter
through the numerics protocols: spatial methods subtype `AbstractSpatialMethod`,
limiters subtype `AbstractLimiter`, and time backends subtype
`AbstractTimeBackend`. Capability checks are expressed with internal trait
queries such as `supports_backend` and `requires_fixed_timestep`; user-facing
method-size calculations should use the exported
`degrees_of_freedom(nx, method)`.

Optional integrations belong behind adapter files rather than solver kernels:
SciML/OrdinaryDiffEq in `adapters/sciml_problem.jl`, Gridap stationary-Stokes
initialization in `adapters/stokes_ic.jl`, OpenBF-style YAML in
`adapters/openbf_protocol.jl`, and resolved-3D XDMF/HDF5 in
`adapters/resolved3d_io.jl`.

## Python Support Tooling

Python remains in this repository for report tooling and experiment operations:
TeX and reference audits, figure/table rendering commands, compact
revision-evidence summaries, and the `ops-experiment` runner. It is packaged as
`masters-report-ops`; it does not reimplement hemodynamics solvers, but it is
the reviewer-facing simulation experiment runner over the Julia CLI.

```bash
pipenv run ops-experiment benchmark --profile smoke \
  --output-dir tmp/simulations/output/package_benchmark/smoke --overwrite
pipenv run ops-julia-check
pipenv run ops-python-check
pipenv run ops-orchestrate status
pipenv run ops-render-package-benchmark-figures \
  --benchmark-dir tmp/simulations/output/package_benchmark/overnight-YYYYMMDD
```

Revision evidence summaries are scratch artifacts by default:

```bash
pipenv run ops-summarize-revision-evidence \
  --rest-csv report/assets/tables/verification/rest_state_drift.csv \
  --comparison-root tmp/simulations/output/3d_comparison/full_t1_native_nx400 \
  --data-root public/var/data/simulations/canic_case3
```

Run simulation experiments and benchmarks with `pipenv run ops-experiment ...`
so terminal output and JSON logs are captured together. Direct Julia CLI usage
through `packages/stenotic-hemodynamics/bin/stenotic-hemodynamics` remains available for solver
development. Programmatic use through `using StenoticHemodynamics` exposes the
core modeling and `simulate` API; report and benchmark workflow helpers remain
available only as qualified names such as
`StenoticHemodynamics.run_package_benchmark`.
