# Report Builds

Use `ops-build-report` for report validation. Treat the wrapper as the report
build gate because it runs the TeX preamble audit, runs `latexmk` in a scratch
directory, records consumed inputs, and writes a machine-readable summary.

## Build Modes

Use a validation-only build for ordinary source review:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

Use an artifact-refresh build only when the task explicitly includes
`public/final-report.pdf`:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
```

Do not refresh `public/final-report.pdf` during routine prose, TeX, citation, or
asset validation. Use the full build only for release preparation or an explicit
artifact-refresh handoff.

Successful builds are concise by default: the wrapper prints commands, status,
failure reasons when present, and the summary path, but it does not replay the
full preamble or LaTeX transcript unless a command fails. Add `--verbose` when
the full captured process output is needed for debugging.

## Wrapper Inputs And Outputs

Default inputs:

- `report/final-report.tex`: report entrypoint.
- `public/references/references.bib`: bibliography entrypoint.
- `report/frontmatter/**`, `report/sections/**`, `report/appendices/**`,
  `report/preamble/**`: TeX source consumed by the entrypoint.
- `report/assets/tikz/**`, `report/assets/data/**`, `report/assets/tables/**`,
  and `report/assets/rendered/**`: report-consumed assets.

Default scratch outputs under `/tmp/masters-report-build`:

- `final-report.pdf`: validated scratch PDF.
- `final-report.log`: LaTeX log.
- `final-report.fls`: recorder file used for consumed-input tracking.
- `report-build-summary.json`: wrapper status and evidence summary.

The full build also syncs the validated scratch PDF to the ignored local
artifact `public/final-report.pdf` after all gates pass.

## Summary JSON

Inspect `report-build-summary.json` after every run. Treat these fields as the
review record:

- `status`: `passed` or `failed`.
- `failure_reasons`: gate-level reasons such as `preamble_audit_failed`,
  `latexmk_failed`, `missing_pdf`, `missing_fls`, `missing_log`,
  `untracked_consumed_inputs`, or `blocking_log_issues`.
- `consumed_inputs`: tracked report inputs found through the `.fls` recorder.
- `untracked_consumed_inputs`: report-consumed files that are not tracked by
  Git.
- `blocking_log_issues`: unresolved references, citations, labels, or hard LaTeX
  issues detected from the log.
- `warning_counts`: layout and warning counts for reviewer inspection.
- `synced_pdf`: target path and hash details when the full build refreshes the
  local release PDF.
- `verbose`: whether full process-output replay was requested.

## Failure Handling

- If `preamble_audit_failed` appears, run or inspect
  `pipenv run ops-audit-tex-preamble` before changing TeX content.
- If `untracked_consumed_inputs` appears, inspect the summary. Do not stage or
  delete the listed files automatically.
- If `blocking_log_issues` appears, fix the cited TeX/citation issue before
  treating the PDF as valid.
- If only layout warnings remain, record them as layout polish unless the task
  requires visual cleanup.

## Related Policies

- Use `public/docs/policy-vocabulary.md` for shared build terms.
- Use `public/docs/artifact-policy.md` before artifact cleanup or refresh.
- Use `public/docs/report-assets-and-provenance.md` when report-consumed assets
  change.
- Use `public/docs/publication-readiness.md` before publishing a release PDF.
