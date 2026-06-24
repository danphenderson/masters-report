# Report Orchestration TODO

## Current Status

This TODO is refreshed after the latest report-side cohesion pass and artifact
sync:

- `33f7f3f` polished the numerical narrative across Sections 5--8 and the
  notation appendix.
- `adf831b` harmonized residual terminology drift across the hierarchy,
  closures, and case-study opening.
- `513702e` refreshed the tracked
  [public/final-report.pdf](/Users/doe/hemodynamics/masters-report/public/final-report.pdf)
  from the current accepted sources.
- `pipenv run ops-audit-report-prose --json` passed with no findings on the
  current manuscript.
- `pipenv run ops-build-report --outdir /tmp/masters-report-build` passed, and
  the synced public PDF matches the scratch build byte-for-byte.

The active manuscript now has the following report-side narrative state:

- Section 5 states a common numerical template and stencil bridge without
  turning the chapter into a reproducibility ledger.
- Section 6 now bridges directly into Section 7's worked-example frame.
- Section 7 comparison leads with the result, then the retained discrepancy
  evidence, then the interpretive budget and its limits.
- Section 8 now states more directly that interpretation depends on the
  declared equation, retained state, discretization, observation operator, and
  metric.
- The mathematical-notation appendix now reads as reference material rather
  than a theorem-style object.

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

Run one bounded committee-polish pass over the active manuscript TeX, then
refresh and commit the public PDF as part of the same editorial lane. The goal
is not new scientific depth. The goal is to eliminate the remaining small
register inconsistencies so the report reads as one continuous mathematical
argument from Introduction through Conclusion.

The next round should stay report-owned and source-grounded:

- no new package/runtime implementation;
- no new bibliography entries or source-inventory work;
- no new numerical claims, tables, or figures unless already generated and
  accepted elsewhere;
- no claim promotion for native resolved-FSI production, imported parity,
  moving-wall/ALE fidelity, persisted resume, or manuscript-grade Section 4.1
  reproduction.

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

### 2. Remaining Terminology Sweep

Goal: remove the last nonessential drift among `contract`, `specification`,
`template`, `rule`, and `declaration`.

Primary files:

- `report/sections/03-model-hierarchy/index.tex`
- `report/sections/04-modeling-closures/index.tex`
- `report/sections/05-numerical-methods/index.tex`
- `report/sections/06-synthesis/index.tex`
- `report/sections/07-case-study/index.tex`
- `report/sections/07-case-study/comparison.tex`
- `report/sections/08-discussion-conclusion/index.tex`
- `report/appendices/mathematical-notation.tex`

Working rule:

- keep `contract` only where it names a genuinely mathematical or comparison
  boundary;
- prefer `model specification`, `closure specification`, `observation rule`,
  `metric definition`, or `comparison setup` where those are more exact;
- keep `template` only for the Section 5 interpretive chain and direct
  descendants of that construction.

Suggested scan:

```sh
rg -n "contract|specification|template|declaration|observation map|comparison setup" \
  report/sections report/appendices -g '*.tex'
```

### 3. Comparison Cadence Audit

Re-read the full `report/sections/07-case-study/comparison.tex` narrative as
one unit and check that the result cadence still holds after all recent edits:

1. result summary;
2. main discrepancy table and figure;
3. short interpretive budget;
4. explicit interpretation limits.

Audit for:

- first mention of every main table/figure before detailed interpretation;
- no paragraph that sounds like process bookkeeping rather than numerical
  interpretation;
- no repeated statement of the same limitation in adjacent paragraphs.

### 4. Appendix Linkage Compression

Check whether the body still repeats appendix-level mechanics that can now be
forwarded cleanly.

Primary surfaces:

- `report/appendices/mathematical-notation.tex`
- `report/appendices/domain-notation.tex`
- `report/appendices/code-and-ai-use.tex`
- nearby body references in Sections 5, 7, and 8

Acceptance:

- appendix references should behave like one-hop support, not duplicate
  arguments;
- notation appendix stays compact and reference-like;
- Appendix H should capture provenance/AI-use detail without intruding on the
  mathematical narrative.

### 5. Section-Transition Normalization

Check the starts and ends of the main report sections as a single argument arc.

Priority surfaces:

- `report/sections/01-intro/index.tex`
- `report/sections/02-continuum/index.tex`
- `report/sections/03-model-hierarchy/index.tex`
- `report/sections/04-modeling-closures/index.tex`
- `report/sections/07-case-study/index.tex`
- `report/sections/08-discussion-conclusion/index.tex`

Goal:

- each section should end by handing the reader to the next question;
- each next section should open by answering that question, not by restarting
  the narrative cold.

### 6. Final Scope-Language Sweep

Run one final prose check on synthesis and conclusion language so the closing
claims remain bounded to the actual evidence chain.

Primary files:

- `report/sections/06-synthesis/index.tex`
- `report/sections/08-discussion-conclusion/index.tex`

Target language:

- interpretation depends on the declared equation, retained state,
  discretization, observation operator, and metric;
- evidence categories remain distinct;
- no slide back into generic `evidence type / claim type` wording where the
  newer direct formulation is stronger.

### 7. Standard PDF Refresh

After accepted report-side source edits, refresh the public PDF as part of the
same handback.

Required commands:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/scratch-final-report.txt
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
```

Also visually spot-check the pages most likely to drift:

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
