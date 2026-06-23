# Final Submission Closeout Checklist

## Current Status

The broad manuscript prose refresh is complete. The current report is
committee-ready at an overall `A` to near-`A+` level, with remaining work limited
to final submission readiness rather than another mathematical or prose rewrite.

The latest scratch critique/build basis was:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-plan-audit --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-plan-audit/final-report.pdf /tmp/final-report-plan-audit.txt
```

That scratch build passed with 63 consumed report inputs and no untracked
consumed inputs. `public/final-report.pdf` remains intentionally unsynced unless
an artifact refresh is explicitly requested.

The current live dirty tree includes unrelated Julia package/runtime work under
`packages/stenotic-hemodynamics/**`. That work is out of scope for this report
submission checklist and must not be staged, normalized, or reverted as part of
the final manuscript closeout.

Memory/layout cleanup is complete: the live manuscript spine starts at
`report/final-report.tex`, the discussion and conclusion live in
`report/sections/08-discussion-conclusion/index.tex`, repo documentation lives
under `public/docs/**`, and old references to root `docs/**` revision-ledger
paths are stale in this checkout.

## Prose Critique and Grades

| Area | Grade | Critique |
| --- | --- | --- |
| Abstract/front matter | A+ | Clear scope, model-tier framing, and bounded case-study role. |
| 1 Introduction | A+ | Strong review-first setup; the case study is correctly positioned as illustrative, not controlling. |
| 2 Continuum | A | Mathematically precise and well-oriented; still dense, but acceptable for the audience. |
| 3 Model hierarchy | A+ | Excellent retained-state and observation-map framing; dimension language is clean. |
| 4 Closures/observables | A+ | Wall, rheology, geometry, boundary, and observable distinctions are clear and bounded. |
| 5 Numerical methods | A | Strong stencil/evidence standard; method catalog remains dense but defensible. |
| 6 Synthesis | A | Coherent proposition-family synthesis; compact and effective. |
| 7 Case-study overview | A+ | The chapter now opens with positive result, negative limitation, and comparison target. |
| 7.1 Methodology | A | Model contract leads, but table/equation density still makes this the heaviest reading surface. |
| 7.2 Verification | A | Evidence hierarchy is right; MMS/rest-state distinction is clear. |
| 7.3 Comparison | A | Main 23%/40% result is interpreted, not just reported; still table-heavy by necessity. |
| 8 Discussion | A+ | Research questions are answered directly and with bounded claim language. |
| 9 Conclusion | A | Clean, accurate, and submission-ready; brief relative to report length, but not underdeveloped. |
| Appendices | A | Appendix G/H are long and command-heavy, but now appropriately appendix-scoped. |

## Do Not Reopen

This closeout lane should not reopen settled manuscript structure or claim
boundaries. Keep the following out of scope unless a later instruction assigns
them explicitly:

- broad mathematical rewrites or new prose-development rounds;
- bibliography entries or `public/references/source-inventory.tsv`;
- package/runtime work under `packages/stenotic-hemodynamics/**`;
- public claim-register or reproducibility-metadata changes;
- raw-data work under `public/var/data/**`;
- `public/final-report.pdf` refreshes, unless explicitly requested.

## Layout and Path Guardrails

Use the live layout, not stale historical paths:

- manuscript entrypoint: `report/final-report.tex`;
- discussion and conclusion: `report/sections/08-discussion-conclusion/index.tex`;
- Appendix G: `report/appendices/numerical-methods-details.tex`;
- Appendix H: `report/appendices/code-and-ai-use.tex`;
- repo docs: `public/docs/**`.

Do not reference nonexistent root `docs/revision-claim-ledger.md`,
`docs/revision-release-gates.md`, or
`report/sections/03-conclusions/index.tex` in future closeout plans.

## Final Readiness Steps

### Step 1 - Re-Anchor

```sh
git status --short
pipenv run ops-orchestrate status --json
```

Confirm that any dirty `packages/stenotic-hemodynamics/**` files remain
unrelated and unstaged for report submission closeout.

### Step 2 - Rebuild the Scratch Manuscript

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/final-report-final-check.txt
jq '{status: .status, consumed_count: (.consumed_inputs|length), untracked_consumed_inputs: .untracked_consumed_inputs}' \
  /tmp/masters-report-build/report-build-summary.json
```

Expected result: build status is `passed`, consumed-input count is stable or
explained, and `untracked_consumed_inputs` is empty.

### Step 3 - Run Claim-Boundary Scans on Rendered Text

```sh
rg -n "backend parity|implementation-check|accepted-reference|validation workflow|regeneration command|Newtonian wall|clinical validation result|reference standard|pending_final_release" \
  /tmp/final-report-final-check.txt
rg -n "TODO|FIXME|pending_final_release" report public/reproducibility -g '!report/TODO.md'
```

Expected result: no reader-visible internal benchmark wording, no accidental
clinical-validation or reference-standard overclaim, and no placeholder release
wording in submitted report paths. Source filenames, TeX labels, or this TODO
file are not reader-visible manuscript prose and should be interpreted
separately.

### Step 4 - Visual Spot Check

Spot-check the scratch PDF, not stale local artifacts:

- Section 7 opening pages;
- Section 7 verification tables;
- Section 7 comparison tables and figures;
- Appendix G package-benchmark table and figure;
- Appendix H release/provenance summary.

Only fix real rendered defects: layout breaks, orphaned captions, overfull table
text, stale reader-facing labels, or obvious typo-level issues. Do not rewrite
settled prose during this pass.

### Step 5 - Optional Public PDF Refresh

Refresh `public/final-report.pdf` only when explicitly requested:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf
```

Commit a refreshed public PDF separately from any source-only typo patch when
practical.

### Step 6 - Commit Discipline

For a TODO-only closeout refresh, stage only:

```sh
git add report/TODO.md
```

For a later typo-only report source patch, stage only the edited report source
files. Do not stage unrelated Julia package/runtime files, local raw data, or
artifact refreshes outside the explicitly assigned lane.
