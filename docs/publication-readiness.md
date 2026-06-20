# GitHub Publication Readiness

This repository is prepared for public peer review as a source tree: Julia
package code, simulations, tests, report source, bibliography metadata, and
report-consumed derived assets are tracked. Generated final PDFs, third-party
full-text references, local review notes, caches, and raw optional 3D inputs are
kept out of ordinary source commits.

## Public Export Rules

- Publish from a clean branch or a fresh source export if historical large blobs
  or third-party full-text files have not been reviewed.
- Do not commit root review/orchestration notes such as `executive-assessment.md`
  or manuscript workflow YAML files.
- Keep `references.bib` and `references/source-inventory.tsv`; do not track
  `references/**/*.pdf` or `references/**/*.html` unless redistribution rights
  are confirmed for every file.
- Publish `final-report.pdf` as a release artifact when a rendered PDF is
  needed. The source of record remains `final-report.tex` plus tracked inputs.
- Keep raw resolved-3D inputs out of Git unless a separate data-release strategy
  with checksums is approved.

## Release Checks

```sh
git status --short --ignored
git ls-files | rg '(__pycache__|\.pyc$|\.aux$|\.log$|\.bbl$)'
git ls-files references | rg '\.(pdf|html?)$'
python3 scripts/audit_references.py
./scripts/julia-release test/runtests.jl
pipenv run pytest
pipenv run ruff check .
pipenv run black --check .
python3 scripts/build_report.py --outdir /tmp/masters-report-build
```

Before a public push, also run a secret scan such as:

```sh
rg -n '(token|secret|password|api[_-]?key|BEGIN .*PRIVATE)'
```
