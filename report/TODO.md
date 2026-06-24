# Report Orchestration TODO

## Current Status

This TODO is refreshed after the report-owned final submission-readiness sweep.

The active manuscript now has the following report-side narrative state:

- Section 5 keeps the stable `Numerical contract stack` anchor while using
  more precise surrounding language for model specification, observation
  operator, and metric interpretation.
- Section 7 methodology and comparison now read more consistently with the
  result-first worked-example frame, without reopening the underlying
  derivations or boundary design.
- Section 7 now uses one consistent boundary for deferred radial-profile
  evidence: same-cut radial-profile outputs remain unpromoted until regenerated
  report assets are reviewed and accepted.
- Section 8 states the contribution and limitations through the direct
  interpretive chain rather than through a more schematic template description.
- The mathematical-notation appendix remains reference-style, and Appendix G
  preserves the accepted package evidence boundary without widening into a
  runtime roadmap.
- Appendix H now matches the live `main` branch layout and records the clean
  submission-readiness base used for this sweep.

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

Unless committee or advisor feedback opens a new lane, the manuscript is now in
final-freeze territory rather than active prose development. The next report
round should therefore be limited to one of the following:

- a committee-feedback correction lane with explicitly bounded file scope;
- a final archival/release lane that records the accepted source commit or
  release tag for the committee-submitted PDF;
- a no-op verification handback confirming that the tracked PDF, source tree,
  and release metadata remain aligned.

Do not reopen broad editorial work without a new manuscript finding. Keep the
same report-owned boundaries:

- no package/runtime implementation;
- no bibliography entries or source-inventory work;
- no new figures/tables or regenerated evidence unless a separate accepted lane
  supplies them;
- no claim promotion for native resolved-FSI production, imported parity,
  moving-wall/ALE fidelity, persisted restart/resume, or manuscript-grade
  Section 4.1 reproduction.

## Post-Sweep Verification Shape

If a later report-owned lane touches source again, start with:

```sh
git status --short
git log -8 --oneline
pipenv run ops-orchestrate status --json
```

Then rerun the standing claim-boundary and report gates:

```sh
rg -n "Section 4\\.1 reproduction|paper-grade|preproduction|production execution|imported parity|moving-wall/ALE fidelity|persisted restart|restart/resume" \
  report/sections report/appendices report/TODO.md -g '*.tex' -g '*.md'
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

Refresh the tracked PDF whenever reader-facing source changes are accepted:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
```

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
- Native resolved-FSI timing/fingerprint work is execution-readiness metadata
  only. The current tiny two-step timing pilot indicates first-use Gridap
  lifecycle and affine-operator setup dominate that small run, while numeric
  factorization is not the first observed bottleneck. This does not change any
  manuscript claim boundary.

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
