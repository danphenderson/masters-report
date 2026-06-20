# StenosisHemodynamics

This repository contains the Julia package, simulations, tests, and LaTeX
source for an idealized stenotic-vessel hemodynamics master's report. The
report source is rooted at `report/final-report.tex`; the solver package is
`StenosisHemodynamics` under `packages/julia/src/`.

The project is prepared for public peer review as a source tree. It does not
track generated final PDFs, third-party full-text reference mirrors, private
review notes, local caches, raw optional resolved-3D inputs, or ordinary
simulation outputs.

## Prerequisites

- macOS or Linux shell environment.
- Julia 1.12 or newer for package tests, simulations, and benchmarks.
- Python 3 with Pipenv for auxiliary report audits and figure renderers.
- A TeX distribution with `latexmk` and `biber` for report builds.

Optional resolved-3D comparison workflows require local XDMF/HDF5 inputs that
are not tracked in this repository.

## What Reproduces from a Clean Clone?

| Workflow | Clean public clone? | Notes |
| --- | --- | --- |
| Julia tests | Yes | Uses the repository-managed Julia launcher. |
| Report build | Yes | Uses tracked TeX inputs and derived report assets; writes scratch outputs. |
| Solver smoke simulation | Yes | Writes local output under the requested scratch path. |
| Python audits and render helpers | Yes | Requires `PIPENV_VENV_IN_PROJECT=1 pipenv install --dev` first. |
| Figure rendering | Mostly | Analytic and package-benchmark figures use tracked or locally generated inputs; some resolved-3D assets require optional local data. |
| Full resolved-3D comparison | No | Requires untracked XDMF/HDF5 inputs under `public/var/data/simulations/canic_case3/`. |

## Reviewer Quick Start

Run Julia package validation with the repository-managed Julia launcher:

```bash
packages/julia/bin/julia-release packages/julia/test/runtests.jl
```

Build the report from source in a scratch directory:

```bash
pipenv run ops-build-report --outdir /tmp/masters-report-build
```

The report wrapper runs the TeX preamble audit, calls `latexmk -g -pdf
-interaction=nonstopmode -halt-on-error` underneath, writes
`report-build-summary.json` in the scratch outdir, and fails if the `.fls`
recorder shows untracked report inputs consumed by the build.

On success, the scratch directory contains `final-report.pdf`,
`final-report.log`, `final-report.fls`, and `report-build-summary.json`; the
validated scratch PDF is also synced to the ignored local artifact
`public/final-report.pdf`. If the build fails, inspect the summary JSON and the
`latexmk` log in the same scratch directory. Use `--no-sync-final-pdf` only when
you explicitly need a validation-only build.

Run a small solver smoke case:

```bash
packages/julia/bin/stenosis-hemodynamics simulate \
  --nx 32 \
  --tfinal 1e-5 \
  --output tmp/smoke/simulate.csv
```

Install and validate Python support tooling only when report audits or figure
renderers are needed:

```bash
PIPENV_VENV_IN_PROJECT=1 pipenv install --dev
pipenv run ops-python-check
pipenv run ops-orchestrate status
```

Artifact classes, cleanup guardrails, and public-release checks are documented
in [`public/docs/artifact-policy.md`](public/docs/artifact-policy.md) and
[`public/docs/publication-readiness.md`](public/docs/publication-readiness.md).
For bounded agent handoffs, see
[`public/docs/agent-workflows.md`](public/docs/agent-workflows.md).

## Optional Resolved-3D Inputs

Resolved-3D XDMF/HDF5 inputs under `public/var/data/simulations/canic_case3/` are
intentionally untracked. Workflows that depend on them either skip cleanly or
emit skipped rows when the files are absent. Published report assets derived
from available resolved-3D inputs are tracked only when consumed by the TeX
source.

## Data and References

Tracked report assets under `report/assets/` are derived artifacts used
by the current TeX source.

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
packages/julia/bin/stenosis-hemodynamics export-assets --overwrite
pipenv run ops-render-stenosis-geometry-figures
```

The exporter also checks for optional resolved-3D data under
`public/var/data/simulations/canic_case3/` when local inputs are available.

## Package Benchmark Pipeline

Run the reproducible package benchmark through the Julia package wrapper. The
smoke profile is a deterministic wiring check:

```bash
packages/julia/bin/stenosis-hemodynamics benchmark \
  --profile smoke \
  --output-dir tmp/simulations/output/package_benchmark/smoke \
  --overwrite
```

For the full overnight benchmark, report-asset publishing workflow, output
schemas, and resolved-3D skip behavior, see
[`public/docs/benchmark-pipeline.md`](public/docs/benchmark-pipeline.md).

## Environments

This repository has separate Julia and Python environments.

- Julia simulation work uses `packages/julia/Project.toml` and `packages/julia/Manifest.toml`. Run Julia
  commands through `packages/julia/bin/julia-release`, which selects Julia 1.12 or newer
  and binds the project environment automatically. The solver is the root Julia
  package `StenosisHemodynamics`; programmatic commands should use
  `using StenosisHemodynamics` from this project.
- Local Julia shells source `~/.config/julia/resource-profile.zsh` for the
  batch profile: 10 Julia threads, 2 GC threads, BLAS/OpenMP/vecLib pinned to 1
  thread, and `JULIA_CASE_WORKERS=10` for independent simulation cases. Set
  `JULIA_RESOURCE_PROFILE=off` before shell startup to skip these defaults.
- Python report/support tooling uses the root `Pipfile`, which installs
  `packages/ops` as an editable package. Install it with
  `PIPENV_VENV_IN_PROJECT=1 pipenv install --dev` when audit or
  render utilities are needed.

The Julia and Python environments are intentionally independent; installing one
does not prepare the other.

## Julia Extension Points

The solver package is organized around explicit layers documented in
`packages/julia/src/StenosisHemodynamics/layers.jl`. New numerical methods should enter
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

Python remains in this repository only for auxiliary report tooling: TeX and
reference audits, figure/table rendering commands, and compact
revision-evidence summaries. It is packaged as `masters-report-ops`; it is not
a hemodynamics solver surface and has no Python simulation CLI.

```bash
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

Run simulations and benchmarks with `packages/julia/bin/stenosis-hemodynamics`.
Programmatic use through `using StenosisHemodynamics` exposes the core modeling
and `simulate` API; report and benchmark workflow helpers remain available only
as qualified names such as `StenosisHemodynamics.run_package_benchmark`.
