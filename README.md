# StenosisHemodynamics

This repository contains the Julia package, simulations, tests, and LaTeX
source for an idealized stenotic-vessel hemodynamics master's report. The
report source is rooted at `final-report.tex`; the solver package is
`StenosisHemodynamics` under `src/`.

The project is prepared for public peer review as a source tree. It does not
track generated final PDFs, third-party full-text reference mirrors, private
review notes, local caches, raw optional resolved-3D inputs, or ordinary
simulation outputs.

## Reviewer Quick Start

Run Julia package validation with the repository-managed Julia 1.12+ launcher:

```bash
./scripts/julia-release test/runtests.jl
```

Build the report from source in a scratch directory:

```bash
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-build final-report.tex
```

Run a small solver smoke case:

```bash
./scripts/stenosis-hemodynamics simulate \
  --nx 32 \
  --tfinal 1e-5 \
  --output tmp/smoke/simulate.csv
```

Install and validate Python support tooling only when report audits or figure
renderers are needed:

```bash
pipenv install --dev
pipenv run pytest
pipenv run ruff check .
pipenv run black --check .
```

Artifact classes, cleanup guardrails, and public-release checks are documented
in [`docs/artifact-policy.md`](docs/artifact-policy.md) and
[`docs/publication-readiness.md`](docs/publication-readiness.md).

## Data and References

Tracked report assets under `figures/static/static/` are derived artifacts used
by the current TeX source. Optional raw resolved-3D inputs are intentionally not
tracked; workflows that depend on them skip cleanly when the local files are
absent.

Bibliography metadata lives in `references.bib`; source provenance lives in
[`references/source-inventory.tsv`](references/source-inventory.tsv). Public
Git releases do not track third-party full-text PDFs or publisher HTML mirrors
under `references/`.

## Licensing

Original code is licensed under the MIT license in [`LICENSE`](LICENSE).
Original report prose and original derived figures are covered by the
documentation notice in [`LICENSE-docs`](LICENSE-docs). Third-party references,
external datasets, and publisher artifacts are excluded from those grants.

## Figure Assets

Regenerate the analytic stenosis geometry CSVs and rendered report assets with:

```bash
./scripts/stenosis-hemodynamics export-assets --overwrite
pipenv run python scripts/render_stenosis_geometry_figures.py
```

The exporter also checks for optional resolved 3D data under
`simulations/data/3d/canic_case3/` and writes node-envelope CSVs only when the
local XDMF/HDF5 files are present.

## Package Benchmark Pipeline

Run the reproducible package benchmark through the Julia package
wrapper. The smoke profile is a deterministic wiring check; the overnight
profile expands the same output schemas to the full benchmark matrix.

```bash
./scripts/stenosis-hemodynamics benchmark \
  --profile smoke \
  --output-dir simulations/output/package_benchmark/smoke \
  --overwrite
```

Publish benchmark CSVs into the report asset tree and render report figures:

```bash
./scripts/stenosis-hemodynamics benchmark \
  --profile overnight \
  --output-dir simulations/output/package_benchmark/overnight-YYYYMMDD \
  --overwrite \
  --include-resolved3d \
  --publish-report-assets

pipenv run python scripts/render_package_benchmark_figures.py \
  --benchmark-dir simulations/output/package_benchmark/overnight-YYYYMMDD
```

The benchmark writes `manifest.json`, `case_results.csv`, `refinement.csv`,
`backend_parity.csv`, `stokes_ic.csv`, `rheology_profile.csv`,
`boundary_openbf.csv`, and `resolved3d.csv`. Optional inputs such as local
resolved-3D data produce skipped rows when absent rather than crashing the run.

## Environments

This repository has separate Julia and Python environments.

- Julia simulation work uses `Project.toml` and `Manifest.toml`. Run Julia
  commands through `./scripts/julia-release`, which selects Julia 1.12 or newer
  and binds the project environment automatically. The solver is the root Julia
  package `StenosisHemodynamics`; programmatic commands should use
  `using StenosisHemodynamics` from this project.
- Local Julia shells source `~/.config/julia/resource-profile.zsh` for the
  batch profile: 10 Julia threads, 2 GC threads, BLAS/OpenMP/vecLib pinned to 1
  thread, and `JULIA_CASE_WORKERS=10` for independent simulation cases. Set
  `JULIA_RESOURCE_PROFILE=off` before shell startup to skip these defaults.
- Python report/support tooling uses `Pipfile`. Install it with `pipenv install
  --dev` when audit or render utilities are needed.

The Julia and Python environments are intentionally independent; installing one
does not prepare the other.

## Julia Extension Points

The solver package is organized around explicit layers documented in
`src/StenosisHemodynamics/layers.jl`. New numerical methods should enter
through the numerics protocols: spatial methods subtype `AbstractSpatialMethod`,
limiters subtype `AbstractLimiter`, and time backends subtype
`AbstractTimeBackend`. Capability checks are expressed with internal trait
queries such as `supports_backend` and `requires_fixed_timestep`; user-facing
method size should use the exported `degrees_of_freedom(nx, method)`.

Optional integrations belong behind adapter files rather than solver kernels:
SciML/OrdinaryDiffEq in `adapters/sciml_problem.jl`, Gridap stationary-Stokes
initialization in `adapters/stokes_ic.jl`, OpenBF-style YAML in
`adapters/openbf_protocol.jl`, and resolved-3D XDMF/HDF5 in
`adapters/resolved3d_io.jl`.

## Python Support Tooling

Python remains in this repository only for auxiliary report tooling: TeX and
reference audits, figure/table rendering scripts, and compact revision-evidence
summaries. It is not a hemodynamics solver surface, and there is no Python
simulation CLI or editable package to install.

```bash
pipenv install --dev
pipenv run pytest
pipenv run python scripts/render_package_benchmark_figures.py \
  --benchmark-dir simulations/output/package_benchmark/overnight-YYYYMMDD
```

Revision evidence summaries are scratch artifacts by default:

```bash
pipenv run python scripts/summarize_revision_evidence.py \
  --rest-csv figures/static/static/tables/verification/rest_state_drift.csv \
  --comparison-root simulations/output/3d_comparison/full_t1_native_nx400 \
  --data-root simulations/data/3d/canic_case3
```

Run simulations and benchmarks with `./scripts/stenosis-hemodynamics` or
programmatically through `using StenosisHemodynamics`.
