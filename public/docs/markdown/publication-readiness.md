# GitHub Publication Readiness

Publish this repository as a source tree only after the source, artifact, and
reference boundaries pass review. Track Julia package code, tests, report
source, bibliography metadata, and report-consumed derived assets. Keep
generated final PDFs, third-party full-text references, local review notes,
caches, and unapproved raw 3D inputs out of ordinary source commits.
This source-tree candidate excludes `public/final-report.pdf` from tracking.
Release-mode hygiene flags tracked final PDFs, so publish any rendered PDF only
through a separate release-artifact lane.

Use validation-only report builds for ordinary source review. Use the full
report build only when preparing a release artifact or intentionally refreshing
`public/final-report.pdf`.
Keep `public/reproducibility/release-manifest.json` as the release-provenance
record for the validation command, current final-PDF hash, and tracked Canic
resolved-3D input convention.

## Public Export Rules

- Publish from a clean branch or a fresh source export if historical large blobs
  or third-party full-text files have not been reviewed.
- Do not commit root review/orchestration notes or manuscript workflow YAML
  files.
- Keep `public/references/references.bib` and
  `public/references/source-inventory.tsv`.
- Do not track `public/references/**/*.pdf` or
  `public/references/**/*.html` unless redistribution rights are confirmed for
  every file.
- Publish `public/final-report.pdf` as a release artifact when a rendered PDF is
  needed. Keep `report/final-report.tex` plus tracked inputs as the source of
  record, and keep final PDFs out of source-only public export.
- Keep broad raw resolved-3D inputs out of Git. The approved Canic case3 data
  release is tracked under `public/var/data/simulations/canic_case3/**` with
  checksums in `report/assets/data/canic-replication/canic-section41-provenance.json`.
- Keep local raw-input checksum audits in `/tmp` unless that separate
  data-release strategy is approved.

## Release Checks

Run patch validation during ordinary Codex or development work, including dirty
trees:

```sh
pipenv run ops-release-check --mode patch --report-outdir /tmp/masters-report-build
```

Run release validation before public export:

```sh
pipenv run ops-release-check --mode release --report-outdir /tmp/masters-report-build
```

Release mode enforces a clean `git status --short --branch
--untracked-files=all` result and scans for tracked LaTeX byproducts, caches,
private reference mirrors, final PDFs, and unclassified `public/var/**`
artifacts. `public/var/logs/.gitkeep` is the only trackable file under
`public/var/logs/`; JSON and JSONL logs remain ignored run artifacts.

Before a public push, also run a secret scan:

```sh
rg -n '(token|secret|password|api[_-]?key|BEGIN .*PRIVATE)'
```

Use `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`
instead of the full build when release-PDF refresh is not in scope.
Use `pipenv run ops-release-check --mode release --sync-final-pdf` only when the
release PDF refresh is explicitly in scope.

## Related Policies

- Use `public/docs/markdown/index.md` for the full documentation map.
- Use `public/docs/markdown/policy-vocabulary.md` for shared terms and modal verbs.
- Use `public/docs/markdown/agent-workflows.md` for bounded dispatch and review before
  publication work.
- Use `public/docs/markdown/artifact-policy.md` before moving, deleting, regenerating, or
  publishing artifacts.
- Use `public/docs/markdown/report-builds.md` for report build gates and release PDF
  refresh behavior.
- Use `public/docs/markdown/report-assets-and-provenance.md` before publishing generated
  report assets.
- Use `public/docs/markdown/resolved3d-workflows.md` before relying on
  resolved-3D data.
- Use `public/docs/markdown/benchmark-pipeline.md` before publishing benchmark-generated
  report assets.
