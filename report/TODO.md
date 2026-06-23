# Final Submission Closeout Plan

## Current Status

The targeted mathematical/numerical narrative pass is complete. Section 5.1 now
introduces finite-element incompressible-flow and FSI discretization by
cross-referencing the continuum fields and weak balances already established in
Section~\ref{sec:continuum-description}, instead of restating continuum
foundations inside the numerical-methods chapter.

The native resolved-FSI package boundary has one manuscript-facing open
requirement that must stay visible in editorial planning after Lane 9B. The
low-level native Gridap Navier--Stokes adapter has smoke-tested exact Section
4.1 inlet/outlet boundary-mode support:
`poiseuille_inlet_zero_outlet_stress_section41` applies a strong inlet
Dirichlet Poiseuille velocity with $u_{\max}=45\,\mathrm{cm/s}$, omits weak
pressure-drop inlet/outlet loading, leaves the outlet as natural zero traction,
and records an internal diagnostic boundary-status string. Boundary-status
fields now propagate through production dry-run plans, production diagnostics
and restart metadata, and parity/status rows. Production execution for the
exact mode remains fail-closed until the next package lane threads the exact
boundary mode and pressure fallback through partitioned production solves.
Manuscript prose must therefore not claim that native production, parity
artifacts, CLI defaults, or restart metadata reproduce the Section 4.1 boundary
conditions yet.

Validation for the source-only pass:

- `git diff --check -- report/sections/05-numerical-methods/index.tex report/TODO.md`
  passed.
- `pipenv run ops-audit-report-prose --json` returned zero findings.
- `pipenv run ops-audit-references` passed.
- `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`
  passed.
- Scratch build consumed `63` report inputs and reported no untracked consumed
  inputs.
- Rendered-text scan of `/tmp/masters-report-build/final-report.pdf` found no
  matches for:

```text
backend parity
implementation-check
accepted-reference
validation workflow
regeneration command
Newtonian wall
clinical validation result
reference standard
pending_final_release
```

`public/final-report.pdf` was intentionally not refreshed during this
source-only pass. The last synced PDF commit remains
`7920835 Refresh final report PDF`; the current source tree now has a small
new TeX improvement that should be synced into the public PDF only if the next
lane explicitly requests an artifact refresh.

## Current Grades

| Area | Grade | Editorial assessment |
| --- | --- | --- |
| Abstract/front matter | A+ | Clear scope, bounded contribution, and clean review-first framing. |
| 1 Introduction | A+ | Strong motivation and correct positioning of the case study as illustrative evidence. |
| 2 Continuum | A | Mathematically precise and well organized; dense, but appropriate for the audience. |
| 3 Model hierarchy | A+ | Retained-state and dimension language are explicit and useful. |
| 4 Closures/observables | A+ | Constitutive roles, wall closure, geometry, boundary data, and observables are cleanly separated. |
| 5 Numerical methods | A+ | Stencil language, method-family distinctions, and FEM/FSI weak-form ownership are now cleanly aligned. |
| 6 Synthesis | A | Compact proposition-family summary; effective as a bridge to the case study. |
| 7 Case-study overview | A+ | The chapter opens with positive evidence, negative limitation, and comparison target. |
| 7.1 Methodology | A | Model contract leads; table/equation density remains high but defensible. |
| 7.2 Verification | A | MMS evidence, rest-state limitation, and admissibility distinction are clear. |
| 7.3 Comparison | A | The 23%/40% result is interpreted rather than merely reported; secondary diagnostics remain dense. |
| 8 Discussion | A+ | Research questions and claim boundaries are answered directly. |
| 9 Conclusion | A | Submission-ready and accurate; intentionally concise. |
| Appendices | A | Long and command-heavy where appropriate; appendix scope keeps main prose clean. |

## Next Round Objective

Treat the manuscript as final-submission material. Do not reopen broad prose,
literature review, numerical methods, or case-study interpretation unless a
committee/advisor comment identifies a concrete issue. The expected next lane is
either:

1. final public PDF sync from the current source tree;
2. a native resolved-FSI boundary-status wording check if package docs change
   again; or
3. no-op closeout with only status reporting.

## Implementation Plan For Next Round

### Step 1 - Re-Anchor

Run:

```sh
git status --short
pipenv run ops-orchestrate status --json
```

Confirm the only intended manuscript delta is the committed Section 5/TODO
source patch, or explicitly classify any newer dirty files before acting.

### Step 2 - Native Resolved-FSI Boundary Check

If any package-native resolved-FSI docs or code changed since the last report
closeout, run this active-manuscript scan before editing prose or syncing the
PDF:

```sh
rg -n "native resolved-FSI|native resolved FSI|native_resolved|Section 4\\.1|Poiseuille|zero-outlet|zero outlet|pressure_drop_weak_inlet_outlet_gauge_smoke|poiseuille_inlet_zero_outlet_stress_section41|boundary mode|boundary contract|paper-grade|production execution|dry-run|state_payload|persisted restart|persisted resume" \
  report/sections report/appendices report/frontmatter report/final-report.tex -g '*.tex' || true
```

Expected result: active manuscript prose should not imply that native
production, parity, CLI, or restart paths already reproduce the paper's Section
4.1 inlet/outlet boundary contract. If native resolved-FSI wording is added
later, it must preserve these boundaries:

- production may be described as carrying partitioned state within one run and
  writing importer-compatible velocity/pressure/displacement bundles plus
  manifest, diagnostics, and restart metadata;
- restart metadata may include versioned `state_payload` audit data, but
  persisted restart/resume remains unsupported and fail-closed;
- the low-level native Gridap Navier--Stokes adapter has smoke-tested exact
  Section 4.1 boundary-mode support through
  `poiseuille_inlet_zero_outlet_stress_section41`;
- production dry-run plans, production diagnostics and restart metadata, and
  parity/status rows may report boundary-status fields;
- `pressure_drop_weak_inlet_outlet_gauge_smoke` remains a separate local
  pressure-drop loading smoke mode and is not exact Section 4.1 boundary
  reproduction;
- production and parity `ready` rows mean artifact/operator readiness, not exact
  Section 4.1 boundary equivalence;
- post-sampling outlet pressure normalization must not be described as a Gridap
  pressure-nullspace constraint;
- exact Section 4.1 production execution remains fail-closed until the exact
  boundary mode and pressure fallback are threaded through partitioned
  production solves and validated;
- native production, parity artifacts, CLI defaults, and restart metadata must
  not be described as reproducing Section 4.1 boundary conditions until that
  production integration exists and is validated;
- planned CLI expansion is dry-run/status-first and must not imply production
  execution from CLI defaults.

### Step 3 - Optional Public PDF Sync

Only run this step if the next lane explicitly scopes the public artifact:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
jq '{status, consumed_count: (.consumed_inputs|length), untracked_consumed_inputs, synced_pdf, warning_counts}' \
  /tmp/masters-report-build/report-build-summary.json
```

Expected result: build status `passed`, consumed-input count `63` unless
explained, no untracked consumed inputs, and matching public/scratch PDF hashes.

### Step 4 - Final Rendered Claim-Boundary Scan

After any PDF sync, run:

```sh
pdftotext -layout public/final-report.pdf /tmp/final-report-release-check.txt
rg -n "backend parity|implementation-check|accepted-reference|validation workflow|regeneration command|Newtonian wall|clinical validation result|reference standard|pending_final_release|TODO|FIXME" \
  /tmp/final-report-release-check.txt || true
```

Expected result: no reader-visible internal process language, no clinical
validation overclaim, and no release placeholders in rendered report text.

### Step 5 - Visual Spot Check

Spot-check the public PDF if it is refreshed:

- Section 5 opening pages around the FEM/FSI subsection;
- Section 7 opening pages;
- Section 7 verification and comparison tables;
- Appendix G package-benchmark material;
- Appendix H software and AI-use disclosure.

Fix only real rendered defects: broken cross-references, orphaned captions,
overfull table text, stale reader-facing labels, or typo-level issues.

### Step 6 - Commit Discipline

For a source-only closeout, stage only:

```sh
git add report/sections/05-numerical-methods/index.tex report/TODO.md
```

For a later PDF-sync lane, stage only:

```sh
git add public/final-report.pdf
```

Suggested source patch commit subject:

```text
Tighten numerical methods continuum bridge
```

Suggested PDF sync commit subject:

```text
Refresh final report PDF
```

## Do Not Reopen

Do not reopen:

- the report spine or section order;
- broad mathematical derivations;
- new literature review sources;
- manuscript wording that treats native production, parity artifacts, CLI
  defaults, restart metadata, or the separate pressure-drop smoke mode as exact
  Section 4.1 Poiseuille-inlet / zero-outlet-stress reproduction;
- bibliography entries or `public/references/source-inventory.tsv`;
- public claim registers or reproducibility metadata;
- package/runtime code;
- raw data under `public/var/data/**`;
- generated report assets, unless a build reports a missing consumed input;
- `public/final-report.pdf`, unless the next instruction explicitly requests a
  synced artifact refresh.

## Live Layout Guardrails

Use the current layout, not stale historical paths:

- manuscript entrypoint: `report/final-report.tex`;
- discussion and conclusion: `report/sections/08-discussion-conclusion/index.tex`;
- Appendix G: `report/appendices/numerical-methods-details.tex`;
- Appendix H: `report/appendices/code-and-ai-use.tex`;
- repo documentation: `public/docs/**`.

Do not reference nonexistent root `docs/revision-claim-ledger.md`,
`docs/revision-release-gates.md`, or
`report/sections/03-conclusions/index.tex`.
