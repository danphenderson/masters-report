# Report Orchestration TODO

Date: 2026-06-24

This file is the live report-side coordination document. Completed package and
report lanes were removed from the active queue during this refresh; use git
history for detailed closed-lane records.

## Live State

- Current branch state at refresh start: `main...origin/main [ahead 5]`, clean.
- Latest package coordination commit:
  `20f487a Refresh native FSI contract and resume stewardship`.
- The manuscript remains in final-freeze territory unless committee/advisor
  feedback opens a bounded source lane.
- The latest package handoff is package/operator evidence only: canonical API
  naming, native diagnostics, timing decisions, viewer controls, and schema-v3
  internal restart/resume support do not require report assets or PDF refresh.

## Current Report TODOs

No report-source, report-asset, or tracked-PDF work is open from the current
package handoff.

The next report round should be one of:

- a committee/advisor correction with explicit file scope;
- a final archival/release lane that records the accepted source commit or
  release tag for the committee-submitted PDF;
- a no-op verification handback confirming that source, tracked PDF, and
  release metadata remain aligned.

Do not reopen broad editorial work without a concrete manuscript finding.

## Package Coordination Boundary

- Manuscript-grade Canic Section 4.1 source-artifact reproduction is tracked
  through `canic-replication section41`, not through the native Gridap
  resolved-FSI production path.
- Native resolved-FSI preproduction/production execution, imported parity,
  moving-wall/ALE fidelity, public/default restart/resume, and
  production-scale restart/resume claims remain unpromoted from the report
  side.
- Native resolved-FSI timing/fingerprint work is execution-readiness metadata
  only. The warmed `12x2x12` timing review found repeated affine-operator
  assembly cost with stable sparsity but changing matrix and RHS values, so no
  factorization-reuse or Gridap-context reuse patch was accepted.
- Schema-v3 checkpoint sidecars and the qualified internal split-run resume
  path are package/operator controls only. They do not change manuscript
  claims, do not justify public/default restart wording, and do not require
  report assets or PDF refresh.
- Viewer scalar toggles, colorbar ranges, evidence badges, missing-field
  disabled states, and surface slice diagnostics are inspection aids only.
  They are not cross-section integration, production validation, imported
  parity, or native moving-wall/ALE evidence.

Refresh this TODO before changing manuscript claims if a future package handoff
changes any boundary above.

## Asset Regeneration And Promotion Plan

No manuscript asset regeneration is required for the current package changes.
Do not promote viewer screenshots, browser bundles, timing sidecars,
reuse/fingerprint metadata, restart checkpoint sidecars, or dry-run status rows
into figures, tables, or claims without a separate accepted report-evidence
lane.

If a future package handoff supplies accepted report evidence:

1. Identify the source workflow and artifact class. The accepted Section 4.1
   manuscript assets still come from
   `canic-replication section41 --publish-report-assets`, not from native
   Gridap production timing or viewer exports.
2. Regenerate into ignored scratch first.
3. Publish only reviewed derived artifacts into `report/assets/**` with the
   workflow's explicit `--publish-report-assets` or documented report-output
   flags.
4. Review generated CSV/JSON/TeX fragments for provenance, optional-input
   skips, source inconsistencies, and claim-boundary language before touching
   `report/sections/**` or `report/appendices/**`.
5. If regeneration crosses package naming changes, update generated assets and
   consuming TeX/TikZ together. Current package code emits canonical
   `classical-parabolic-1d` and axial-observation labels, while some accepted
   tracked report assets still carry historical `classical-1d-no-slip`,
   `u1d`, and `u3d` labels from the source-artifact lane.
6. Build source-only first:

   ```bash
   pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
   ```

7. Refresh `public/final-report.pdf` only after reader-facing source/assets are
   accepted:

   ```bash
   pipenv run ops-build-report --outdir /tmp/masters-report-build
   shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
   ```

Current Section 4.1 promotion command, retained for reference:

```bash
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics canic-replication section41 \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/canic-replication/section41 \
  --coordinate-mode deformed \
  --nx 100 \
  --dt 1e-5 \
  --tfinal 1.0 \
  --section-count 200 \
  --radial-sample-count 41 \
  --publish-report-assets \
  --report-assets-dir report/assets \
  --overwrite
```

For future native resolved-FSI preproduction or imported-parity evidence, keep
raw bundles, observation CSVs, parity summaries, restart/checkpoint sidecars,
and status files in scratch until a report-evidence lane explicitly approves a
reader-facing figure/table. Only then should reviewed derived artifacts enter
`report/assets/**` and the manuscript.

## Standard Report Closeout

For report-source lanes, source-only validation is:

```bash
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

For reader-facing source changes that are accepted for publication, refresh the
tracked PDF:

```bash
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
```

## Validation

For this TODO-only refresh:

```bash
git diff --check -- packages/stenotic-hemodynamics/TODO.md report/TODO.md
pipenv run ops-orchestrate docs-contract
```

For future report-source lanes:

```bash
git diff --check -- report/TODO.md report/sections report/appendices
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

## Live Layout Guardrails

- manuscript entrypoint: `report/final-report.tex`
- prose: `report/sections/**`
- appendices: `report/appendices/**`
- shared setup: `report/preamble/**`
- bibliography: `public/references/references.bib`
- report assets: `report/assets/**`
- repo documentation: `public/docs/**`

Do not reference stale root `docs/**` paths or
`report/sections/03-conclusions/index.tex`.
