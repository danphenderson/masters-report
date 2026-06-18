# Masters Report

This repository contains the LaTeX source for the master's report rooted at
`final-report.tex`.

## Build

Use a scratch output directory for validation builds:

```bash
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-build final-report.tex
```

Treat `final-report.pdf` as the final synced render. Validate with a scratch
build first, then refresh the tracked PDF only after checking the rendered
pages.

## Figure Assets

Regenerate the analytic stenosis geometry CSVs and rendered report assets with:

```bash
./scripts/julia-release simulations/export_stenosis_geometry_figures.jl --overwrite
pipenv run python scripts/render_stenosis_geometry_figures.py
```

The exporter also checks for optional resolved 3D data under
`simulations/data/3d/canic_case3/` and writes node-envelope CSVs only when the
local XDMF/HDF5 files are present.

## Package Benchmark Pipeline

Run the reproducible Julia/Python package benchmark through the Julia package
wrapper. The smoke profile is a deterministic wiring check; the overnight
profile expands the same output schemas to the full benchmark matrix.

```bash
./scripts/julia-release simulations/run_package_benchmark.jl \
  --profile smoke \
  --output-dir simulations/output/package_benchmark/smoke \
  --overwrite \
  --include-python
```

Publish benchmark CSVs into the report asset tree and render report figures:

```bash
./scripts/julia-release simulations/run_package_benchmark.jl \
  --profile overnight \
  --output-dir simulations/output/package_benchmark/overnight-YYYYMMDD \
  --overwrite \
  --include-python \
  --include-resolved3d \
  --publish-report-assets

pipenv run python scripts/render_package_benchmark_figures.py \
  --benchmark-dir simulations/output/package_benchmark/overnight-YYYYMMDD
```

The benchmark writes `manifest.json`, `case_results.csv`, `refinement.csv`,
`backend_parity.csv`, `stokes_ic.csv`, `rheology_profile.csv`,
`boundary_openbf.csv`, `resolved3d.csv`, and `python_mps.csv`. Optional inputs
such as local resolved-3D data or SciPy support produce skipped rows when absent
rather than crashing the run.

## Environments

This repository has separate Julia and Python environments.

- Julia simulation work uses `Project.toml` and `Manifest.toml`. Run Julia
  commands through `./scripts/julia-release`, which selects Julia 1.12 or newer
  and binds the project environment automatically. The solver is the root Julia
  package `CanicExtended1D`; programmatic commands should use
  `using CanicExtended1D` from this project.
- Local Julia shells source `~/.config/julia/resource-profile.zsh` for the
  batch profile: 10 Julia threads, 2 GC threads, BLAS/OpenMP/vecLib pinned to 1
  thread, and `JULIA_CASE_WORKERS=10` for independent simulation cases. Set
  `JULIA_RESOURCE_PROFILE=off` before shell startup to skip these defaults.
- Python report/support tooling uses `Pipfile`. Install it with `pipenv install
  --dev` when Python utilities or notebook-style analysis helpers are needed.

The Julia and Python environments are intentionally independent; installing one
does not prepare the other.

## Python Hemodynamics CLI

This repository also includes a self-contained Python package under
`python/src/research_hemodynamics`. It exposes the Julia-compatible
hemodynamics descriptor surface as a Typer CLI named `research-hemodynamics`.
No FNO or operator-learning modules are part of this Python CLI.

Install the package editable into the repo Pipenv environment:

```bash
pipenv install --dev
pipenv run python -m pip install -e .
pipenv run research-hemodynamics --help
```

Core commands:

```bash
pipenv run research-hemodynamics devices
pipenv run research-hemodynamics descriptors --json
pipenv run research-hemodynamics verify --device mps --run-smoke
pipenv run research-hemodynamics compare --left-backend native --right-backend native
```

`devices` and `verify --device mps --run-smoke` use
`torch.backends.mps.is_available()` when Torch is installed. If MPS is not
available, the CLI reports that cleanly; CPU fallback is only used when
`--allow-cpu-fallback` is passed.

Examples:

```bash
pipenv run research-hemodynamics run --space fv-first-order --time-stepper euler --out tmp/python-fv-first-order
pipenv run research-hemodynamics run --space fv-muscl --time-stepper ssprk3 --out tmp/python-fv-muscl
pipenv run research-hemodynamics run --space fv-lax-wendroff --out tmp/python-fv-lax-wendroff
pipenv run research-hemodynamics run --space dg-p0 --out tmp/python-dg-p0
pipenv run research-hemodynamics run --space dg-p1 --out tmp/python-dg-p1
pipenv run research-hemodynamics run --space dg-p2 --out tmp/python-dg-p2
pipenv run research-hemodynamics run --space fem-stationary-stokes --ic stationary-stokes --ic-pressure-drop-pa 100 --out tmp/python-fem-stokes
```

`descriptors --json` exposes Python maturity tiers and forward-model
descriptors. The default `--model canic-extended-1d` keeps the Canic
effective-alpha variable-radius correction. `--model classical-1d-no-slip`
selects the classical parabolic-profile 1D baseline, records the wall no-slip
antecedent as `no-slip-on-wall-Gamma_w-not-inlet-or-outlet`, and disables the
Canic effective-alpha correction. The publication-tier Python spatial surface is
`fv-first-order`, `fv-muscl`, `fv-lax-wendroff`, and `fem-stationary-stokes`.
`fv-lax-wendroff` uses a true Richtmyer/Lax-Wendroff
finite-volume interface predictor, with only a local positivity fallback for
invalid half-step interface states. `dg-p0`, `dg-p1`, and `dg-p2` are
`experimental-smoke` descriptors that run through a cell-average FV update; they
are not finished modal DG solvers and should be treated as Julia-reference-only
for publication-grade DG claims. `fem-stationary-stokes` is a deterministic CPU
stationary-Stokes resistance/projection initializer based on the Julia projection
contract, without adding a heavy Python FEM dependency or claiming transient FEM.

Boundary descriptor parameters are validated and recorded:

```bash
pipenv run research-hemodynamics run \
  --model classical-1d-no-slip \
  --inlet flow-waveform \
  --flow-waveform tmp/waveform.txt \
  --outlet reflection-coefficient \
  --reflection-coefficient 0.25 \
  --reference-flow 0.0 \
  --out tmp/python-boundary-metadata
```

SciPy and SciML comparison surfaces:

```bash
pipenv run research-hemodynamics compare \
  --left-backend native \
  --right-backend torch \
  --device mps \
  --space fv-lax-wendroff \
  --rheology carreau \
  --velocity-profile power \
  --alpha 1.1 \
  --inlet steady-velocity \
  --outlet fixed-area-characteristic

pipenv run research-hemodynamics compare --left-backend native --right-backend scipy
pipenv run research-hemodynamics compare \
  --left-backend native \
  --right-backend sciml-reference \
  --julia-project /Users/doe/hemodynamics/masters-report
```

The SciPy adapter uses `scipy.integrate.solve_ivp` only when SciPy is installed;
SciPy is not a required dependency. The SciML adapter shells out through this
repo's `./scripts/julia-release` and `simulations/run_canic_extended_1d.jl`
when `--julia-project /Users/doe/hemodynamics/masters-report` is supplied.

`run --out PATH` writes `summary.json`, `series.csv`, `solution.npz`, and
`manifest.json`. Use `--dtype auto|float32|float64` to make precision explicit;
`auto` resolves to float64 for native/Torch CPU and float32 for Torch MPS. Use
`--sample-times 0,0.001,0.002` when exact output records are needed instead of
save-interval output.

Manifest reruns use the recorded solver options without CLI overrides:

```bash
pipenv run research-hemodynamics run-manifest \
  tmp/python-fv-muscl/manifest.json \
  --out tmp/python-fv-muscl-rerun
```

Backend-parity experiment records are orchestrated through a scratch-only
experiment command:

```bash
pipenv run research-hemodynamics experiment \
  --experiment backend-parity-v1 \
  --profile smoke \
  --out tmp/experiments/backend-parity-v1-smoke \
  --overwrite
```

The `smoke` profile is the acceptance-scale matrix. The `full` profile expands
to both forward models (`canic-extended-1d` and `classical-1d-no-slip`),
severities 0, 23, 40, and 50 percent, larger grids, and `T=1.0 s`; expect that
profile to be substantially slower. Experiment output includes per-run manifests
under `manifests/`, raw runs under `runs/`, and CSV summaries under `summaries/`
for run diagnostics, field parity, performance, and total-variation diagnostics.

Use ignored scratch locations such as `tmp/**` for CLI output; do not write
Python runs into report PDFs, references, figures, or Julia manifest files.
