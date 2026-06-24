# Report Orchestration TODO

## Current Status

This TODO is refreshed after the committee-polish report-boundary pass.

The active manuscript now has the following report-side narrative state:

- Section 5 keeps the stable `Numerical contract stack` anchor while using
  more precise surrounding language for model specification, observation
  operator, and metric interpretation.
- Section 7 methodology and comparison now read more consistently with the
  result-first worked-example frame, without reopening the underlying
  derivations or boundary design.
- Section 8 states the contribution and limitations through the direct
  interpretive chain rather than through a more schematic template description.
- The mathematical-notation appendix remains reference-style, and Appendix G
  preserves the accepted package evidence boundary without widening into a
  runtime roadmap.

## Completed Report Alignment

Do not reopen these report lanes without a new technical or editorial finding:

- Section 2 and Appendix E distinguish control-volume integral balance forms
  from variational weak forms and include compact ALE/FSI interface statements.
- Section 5.1 separates pressure gauge, velocity-pressure inf-sup stability,
  advective stabilization, and divergence control.
- Section 5, Section 7, and Appendix notation now use a shared numerical
  template for interpreting model, discretization, observation, and metric
  choices.
- Section 7.3.6 treats radial profiles as deferred secondary evidence rather
  than as accepted physical closure failure.
- Appendix G keeps stable numerical-method exposition separate from mutable
  runtime status, restart design, and parity-roadmap details.
- The DG p/h demo now states exactly that accepted p-improvement belongs only
  to the explicit limiter-disabled smooth MMS verification configuration.
- Section 2.3 rheology reintegration remains closed as a broad editorial lane;
  the current continuum/generalized-Newtonian framing is retained unless a
  concrete live-text inconsistency is found later.
- Section 7 methodology no longer carries the densest visible terminology drift
  around `contract` in reader-facing prose; stable labels remain in place.

## Standard Closeout Rule

For report-side handbacks, synced PDF refresh is now the default closeout
behavior. Treat a source-only lane as an exception that should be named
explicitly in the task.

Default report-side closeout sequence:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
```

If source and PDF changes are both in scope, prefer separate commits unless the
artifact refresh depends immediately on the same source patch and splitting
would only create noise.

## Next Round Objective

Run a final submission-readiness sweep rather than another broad prose lane.
The manuscript narrative is now close to stable. The next round should focus on
final claim-boundary inspection, page-level visual checks, Appendix H source
record accuracy, and any last reader-facing cleanup discovered through those
checks.

The next round should stay report-owned and source-grounded:

- no package/runtime implementation;
- no bibliography entries or source-inventory work;
- no new figures/tables or regenerated evidence unless a separate accepted lane
  supplies them;
- no claim promotion for native resolved-FSI production, imported parity,
  moving-wall/ALE fidelity, persisted restart/resume, or manuscript-grade
  Section 4.1 reproduction.

## Immediate Execution Plan

### 1. Re-anchor

Run:

```sh
git status --short
git log -8 --oneline
pipenv run ops-orchestrate status --json
```

Expected starting condition:

- no unexpected report-source drift outside the accepted editorial lane;
- `public/final-report.pdf` may be dirty only if the current lane has already
  modified reader-facing report source or assets and has not yet run the sync
  build;
- package code remains out of scope unless a separate package handoff changes
  the report claim boundary.

### 2. Final Claim-Boundary Scan

Re-scan the active manuscript for any accidental claim promotion:

```sh
rg -n "Section 4\\.1 reproduction|paper-grade|preproduction|production execution|imported parity|moving-wall/ALE fidelity|persisted restart|restart/resume" \
  report/sections report/appendices report/TODO.md -g '*.tex' -g '*.md'
```

Allowed matches should be bounded negative claims or explicit planning
guardrails only.

### 3. Comparison and Methodology Read-Through

Re-read the full Section 7 worked-example chain as one unit:

- `report/sections/07-case-study/index.tex`
- `report/sections/07-case-study/methodology.tex`
- `report/sections/07-case-study/verification.tex`
- `report/sections/07-case-study/comparison.tex`

Check that the result cadence still holds:

1. result summary;
2. main discrepancy table and figure;
3. short interpretive budget;
4. explicit interpretation limits.

Audit for:

- first mention of every main table/figure before detailed interpretation;
- no paragraph that sounds like process bookkeeping rather than numerical
  interpretation;
- no repeated statement of the same limitation in adjacent paragraphs.

### 4. Appendix H Source Record and Final Appendix Linkage

Check whether the body still repeats appendix-level mechanics that can now be
forwarded cleanly.

Primary surfaces:

- `report/appendices/code-and-ai-use.tex`
- `report/appendices/mathematical-notation.tex`
- nearby body references in Sections 5, 7, and 8

Acceptance:

- appendix references should behave like one-hop support, not duplicate
  arguments;
- notation appendix stays compact and reference-like;
- Appendix H should capture provenance/AI-use detail without intruding on the
  mathematical narrative, and it should record the exact source commit used for
  the submitted PDF.

### 5. Page-Level Visual Check and Standard PDF Refresh

After accepted report-side source edits, refresh the public PDF as part of the
same handback and visually inspect the pages most likely to drift.

Required commands:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/scratch-final-report.txt
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
```

Also visually spot-check the pages most likely to drift:

- Section 7 methodology pages;
- Section 7 comparison pages;
- Appendix G pages with DG verification language;
- conclusion pages.

## Package Coordination Boundary

The report lane still does not own package implementation. Keep report wording
aligned to the current accepted package evidence boundary:

- focused mathematical-contract package evidence is accepted;
- exact Section 4.1 boundary support is not yet a manuscript-grade reproduction
  claim;
- imported parity, preproduction/production execution, moving-wall/ALE
  fidelity, and persisted restart/resume remain unpromoted from the report
  side;
- DG p-improvement language remains limited to the explicit limiter-disabled
  smooth MMS verification configuration.

If a future package handoff changes those boundaries, refresh this TODO before
changing manuscript claims.

## Validation Commands

For `report/TODO.md` only:

```sh
git diff --check -- report/TODO.md
sed -n '1,260p' report/TODO.md
```

For report-source editorial lanes:

```sh
git diff --check -- report/TODO.md report/sections report/appendices
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

For report-source lanes that close with synced PDF refresh:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
```

## Live Layout Guardrails

- manuscript entrypoint: `report/final-report.tex`
- Section 2: `report/sections/02-continuum/index.tex`
- Section 5: `report/sections/05-numerical-methods/index.tex`
- Section 7 overview: `report/sections/07-case-study/index.tex`
- Section 7 comparison: `report/sections/07-case-study/comparison.tex`
- discussion and conclusion: `report/sections/08-discussion-conclusion/index.tex`
- Appendix E: `report/appendices/continuum-derivation-details.tex`
- Appendix G: `report/appendices/numerical-methods-details.tex`
- Appendix H: `report/appendices/code-and-ai-use.tex`
- repo documentation: `public/docs/**`

Do not reference stale root `docs/**` paths or
`report/sections/03-conclusions/index.tex`.
