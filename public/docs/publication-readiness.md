# GitHub Publication Readiness

Publish this repository as a source tree only after the source, artifact, and
reference boundaries pass review. Track Julia package code, tests, report
source, bibliography metadata, and report-consumed derived assets. Keep
generated final PDFs, third-party full-text references, local review notes,
caches, and raw optional 3D inputs out of ordinary source commits.

Use validation-only report builds for ordinary source review. Use the full
report build only when preparing a release artifact or intentionally refreshing
`public/final-report.pdf`.

## Public Export Rules

- Publish from a clean branch or a fresh source export if historical large blobs
  or third-party full-text files have not been reviewed.
- Do not commit root review/orchestration notes such as
  `executive-assessment.md` or manuscript workflow YAML files.
- Keep `public/references/references.bib` and
  `public/references/source-inventory.tsv`.
- Do not track `public/references/**/*.pdf` or
  `public/references/**/*.html` unless redistribution rights are confirmed for
  every file.
- Publish `public/final-report.pdf` as a release artifact when a rendered PDF is
  needed. Keep `report/final-report.tex` plus tracked inputs as the source of
  record.
- Keep raw resolved-3D inputs out of Git unless a separate data-release strategy
  with checksums is approved.

## Release Checks

Run these checks before public export:

```sh
git status --short --ignored
git ls-files | rg '(__pycache__|\.pyc$|\.aux$|\.log$|\.bbl$)'
git ls-files public/references | rg '\.(pdf|html?)$'
pipenv run ops-audit-references
packages/julia/bin/julia-release packages/julia/test/runtests.jl
pipenv run ops-python-check
pipenv run ops-build-report --outdir /tmp/masters-report-build
```

Before a public push, also run a secret scan:

```sh
rg -n '(token|secret|password|api[_-]?key|BEGIN .*PRIVATE)'
```

Use `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`
instead of the full build when release-PDF refresh is not in scope.

## Related Policies

- Use `public/docs/policy-vocabulary.md` for shared terms and modal verbs.
- Use `public/docs/agent-workflows.md` for bounded dispatch and review before
  publication work.
- Use `public/docs/artifact-policy.md` before moving, deleting, regenerating, or
  publishing artifacts.
- Use `public/docs/benchmark-pipeline.md` before publishing benchmark-generated
  report assets.
