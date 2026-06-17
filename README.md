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
