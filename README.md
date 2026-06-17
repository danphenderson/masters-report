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
