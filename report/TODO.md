# Committee Submission Closeout Plan

## Current Status

The committee-facing prose lane has been implemented on top of commit
`9604de9` (`Plan next prose polish lane`). The scratch report build passes, and
the public PDF has not been refreshed in this lane.

Validation already run for the implemented prose lane:

```sh
git diff --check -- report/sections report/appendices report/assets/tables/package-benchmark \
  packages/ops/src/ops/render_package_benchmark_figures.py \
  packages/ops/tests/test_python_package_benchmark.py report/TODO.md
pipenv run pytest packages/ops/tests/test_python_package_benchmark.py -q
pipenv run ops-audit-references
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/final-report-prose-lane.txt
rg -n "backend parity|implementation-check|accepted-reference|validation workflow|regeneration command|Newtonian wall|clinical validation result|reference standard" \
  /tmp/final-report-prose-lane.txt
```

The final `rg` command is expected to return no matches.

## Current Grades

| Area | Grade | Current finding |
| --- | --- | --- |
| Abstract and front matter | A+ | Scope, evidence categories, and limits are explicit. |
| 1 Introduction and report methodology | A+ | The review-first contract and illustrative case-study role are clear. |
| 2 Continuum description | A | Dense but well-oriented mathematical setup. |
| 3 Model hierarchy | A+ | Retained-state and reduced-dimension distinctions are clear. |
| 4 Closures and observables | A+ | Constitutive, membrane-wall, and observable language is bounded. |
| 5 Numerical methods | A | Stencil and evidence standards are strong; catalog density is acceptable. |
| 6 Literature synthesis | A | Proposition-family synthesis is coherent and concise. |
| 7 Case-study overview | A+ | The reader now sees the chapter route before the details. |
| 7.1 Methodology | A | The model contract now leads the implementation labels. |
| 7.2 Verification | A | Interpretation leads the MMS/rest-state evidence more clearly. |
| 7.3 Comparison | A | The 23%/40% result reads as an interpreted diagnostic comparison. |
| 8 Integrated discussion | A+ | The case-study evidence categories are harvested without overclaiming. |
| 9 Conclusion | A | Clean and bounded; no broad rewrite recommended. |
| Appendices | A | Appendix G no longer exposes the reader-visible `backend parity` label; it remains long but useful as evidence support. |

Overall readiness: `A` to `A+` committee-ready, with the remaining work limited
to final artifact hygiene and visual spot checks rather than another broad prose
rewrite.

## Implemented This Round

- Tightened the Section 7 entry paragraph so methodology, verification, and
  comparison are routed before technical detail.
- Compressed methodology prose around retained state, closures, boundary
  approximation, finite-volume operator, and observation map.
- Rebalanced verification prose toward the evidence hierarchy:
  manufactured-solution verification, geometry-rest limitation, and diagnostic
  comparison status.
- Added one bounded comparison interpretation sentence after the main velocity
  discrepancy summary.
- Added one discussion sentence explaining why the positive MMS result,
  negative rest-state result, and final-time comparator cannot be collapsed into
  one validation grade.
- Replaced reader-visible `backend parity` wording with
  `time-integrator comparison` in the appendix table and generated figure, and
  updated the renderer/test so regeneration keeps the committee-facing label.

## Remaining Closeout Objective

Prepare the final handoff artifact without reopening the manuscript's claim
structure. The next round should be a final artifact-readiness lane, not a new
prose-development lane.

## Files in Scope for Final Closeout

Primary:

- `public/final-report.pdf`, only if the user explicitly wants the public PDF
  refreshed from the passing scratch build.
- `report/TODO.md`, only to record final closeout status.

Conditional typo-only source edits:

- `report/**/*.tex`
- `report/assets/tables/**/*.tex`
- `packages/ops/src/ops/render_package_benchmark_figures.py`
- `packages/ops/tests/test_python_package_benchmark.py`

Out of scope unless explicitly assigned:

- `packages/stenotic-hemodynamics/**`
- `public/var/data/**`
- bibliography/source-inventory rows
- public claim registers
- broad mathematical rewrites

## Final Closeout Steps

### Step 1 - Re-Anchor

```sh
git status --short
git log --oneline -5
pipenv run ops-orchestrate status --json
```

Do not stage unrelated package/runtime work.

### Step 2 - Rebuild and Extract the Current Manuscript

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/final-report-final-check.txt
```

Use the scratch PDF as the review target unless the lane explicitly refreshes
`public/final-report.pdf`.

### Step 3 - Run Final Prose and Claim-Boundary Scans

```sh
rg -n "backend parity|implementation-check|accepted-reference|validation workflow|regeneration command|Newtonian wall|clinical validation result|reference standard" \
  /tmp/final-report-final-check.txt
rg -n "TODO|FIXME|pending_final_release" report public/reproducibility
```

Expected result:

- No reader-visible internal benchmark wording.
- No accidental clinical-validation or reference-standard overclaim.
- No placeholder release wording in the submitted report path.

### Step 4 - Visual Spot Check

Spot-check the scratch PDF around:

- Section 7 opening pages.
- Section 7 verification tables.
- Section 7 comparison tables and figures.
- Appendix G package benchmark table and figure.
- Appendix H release/provenance summary.

Look only for layout defects, orphaned captions, overfull table text, or stale
reader-facing labels. Do not rewrite settled prose unless the rendered PDF shows
a real defect.

### Step 5 - Optional Public PDF Refresh

If the user wants the tracked public PDF refreshed:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf
```

Then commit the refreshed artifact separately from any typo-only source patch if
practical.

### Step 6 - Final Commit Discipline

Use one final source commit for any typo-only closeout patch. Use a separate PDF
artifact commit only if `public/final-report.pdf` is intentionally refreshed.

Do not stage unrelated package/runtime files or local raw data.
