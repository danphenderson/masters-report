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

## Environments

This repository has separate Julia and Python environments.

- Julia simulation work uses `Project.toml` and `Manifest.toml`. Run Julia
  commands through `./scripts/julia-release`, which selects Julia 1.12 or newer
  and binds the project environment automatically.
- Python report/support tooling uses `Pipfile`. Install it with `pipenv install
  --dev` when Python utilities or notebook-style analysis helpers are needed.

The Julia and Python environments are intentionally independent; installing one
does not prepare the other.
