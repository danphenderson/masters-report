# Policy Vocabulary

Use these terms consistently across `public/docs/**.md`, handoff packets, and
review handbacks.

## Modal Verbs

| Term | Meaning |
| --- | --- |
| `Must` | Required for correctness or repository safety. |
| `Must not` | Forbidden. |
| `Should` | Recommended, with exceptions allowed when the handback states why. |
| `May` | Permitted, not required. |
| `Use` | Default instruction. |
| `Treat` | Classification rule. |

Prefer direct imperatives for procedure: `Run`, `Keep`, `Validate`, `Inspect`,
`Record`, and `Do not`.

## Shared Terms

- `validation-only build`: `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`.
  Use it for ordinary report source review and report-consumed asset checks when
  `public/final-report.pdf` is not in scope.
- `artifact-refresh build`: `pipenv run ops-build-report --outdir /tmp/masters-report-build`.
  Use it only when a task explicitly includes `public/final-report.pdf` or
  generated report assets after the owning gate passes.
- `scratch output`: ignored local output under paths such as
  `/tmp/masters-report-build`, `tmp/**`, or `tmp/simulations/output/**`.
  Scratch output supports validation and experiments; it is not ordinary source.
- `report-consumed asset`: a figure, table, CSV, static data file, or rendered
  asset referenced by the current TeX source or appendix provenance.
- `private mirror`: a local third-party full-text reference copy, such as
  ignored `public/references/**/*.pdf` or `public/references/**/*.html`.
  Private mirrors are not public Git release artifacts.
- `published asset`: a tracked report asset under `report/assets/**` that the
  manuscript consumes or a release artifact distributed outside ordinary source
  commits.
- `bounded edit`: a mutation limited to explicitly named files while preserving
  unrelated dirty work.
- `protected/generated artifact drift`: dirty state in generated, ignored,
  private, raw, or publication artifact paths that requires explicit scope
  before staging, deleting, or refreshing.

## Related Policies

- Use `public/docs/agent-workflows.md` for bounded agent dispatch and review.
- Use `public/docs/artifact-policy.md` before moving, deleting, regenerating, or
  publishing artifacts.
- Use `public/docs/benchmark-pipeline.md` when generating package benchmark
  outputs or report-consumed benchmark assets.
- Use `public/docs/publication-readiness.md` before public export or release
  publication.
