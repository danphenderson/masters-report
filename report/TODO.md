# Report Orchestration TODO

## Current Status

This TODO is refreshed after the report/package mathematical-contract alignment
round and the latest report PDF refresh.

Grounding at the start of this round:

- Report source synchronization is landed through
  `72bb504 Sync report with focused FSI contract evidence`.
- The tracked PDF artifact was refreshed in
  `d0b08da Refresh final report PDF`.
- Package-side planning has advanced through
  `c503231 Plan native FSI phase timing gate`.
- `pipenv run ops-orchestrate status --json` reported only one report source
  edit and one protected PDF edit; the source edit was a transient Section 1
  prose regression and has been restored to the committed text.
- The current working tree still has a protected
  `public/final-report.pdf` modification. Treat it as unaccepted artifact
  churn until an explicit PDF artifact lane compares, refreshes, and commits
  it or intentionally restores the tracked artifact.

Latest PDF artifact decision:

- A scratch report build passed with no untracked consumed inputs.
- `pdftotext -layout` output is identical for the tracked PDF, working-tree
  PDF, and scratch-built PDF.
- `pdfinfo` reports the same title, metadata fields, page count, page size, and
  file size; the differing SHA values are explained by PDF creation/modification
  timestamps.
- Do not commit the dirty `public/final-report.pdf` as a reader-facing report
  update. Leave it for an explicit artifact-owner cleanup or restore decision.

Latest verification-reporting decision:

- Package/report commit `bbf485e Report MMS metric-specific orders` updated the
  MMS verification workflow, generated verification table, and Section 7 prose
  so observed orders are reported separately for the discrete $L_1$, $L_2$,
  and $L_\infty$ area/flow metrics.
- Commit `d73afa9 Guard MMS metric order prose` added an ops prose-audit guard
  against stale L2-only MMS-order wording.
- Commit `56e68e1 Classify DG p-sweep diagnostics` classifies fixed-mesh DG
  p-sweep rows as `baseline`, `regressed`, or `plateau`; Appendix G now treats
  plateau/regressed p rows as diagnostics, not accepted DG p-convergence
  evidence.
- Package commit `0413a97 Add DG limiter policy for smooth verification`
  implements an explicit limiter-disabled smooth MMS verification policy while
  preserving the conservative limited default. Focused package tests show
  restored fixed-mesh DG p-improvement for smooth MMS rows, but tracked report
  assets have not yet been regenerated from that policy.
- Package commits `a89f6fd`, `c9a85c3`, and `49e0ba8` landed scalar-generic
  helper continuation, explicit inlet-area solve controls, and stronger
  refinement-study CLI tests. These are package correctness/maintenance
  changes and do not alter manuscript claims.
- These are verification-reporting refinements only. They do not promote native
  resolved-FSI Section 4.1 production, imported parity, moving-wall/ALE
  fidelity, or manuscript-grade reproduction claims.

The Lane 11 P0 mathematical-contract blocker is retired at focused package-test
scope only. The report may describe focused package evidence for the
density-consistent transient/convection terms, symmetric-gradient Cauchy viscous
form, boundary-aware pressure-space policy, raw physical wall-pressure forcing,
exact Canic case geometry, and same-cut radial-profile closure classification.
The report must still withhold claims of `sev23` preproduction completion,
production/fleet execution, imported parity, moving-wall/ALE fidelity,
persisted restart/resume, promoted radial-profile evidence, or manuscript-grade
Section 4.1 reproduction.

## Completed Report-Source Alignment

Do not reopen these lanes without a new technical finding:

- Section 2 and Appendix E now distinguish control-volume integral balance
  forms from variational weak forms and include compact moving-domain/FSI
  interface statements.
- Section 5.1 now separates pressure gauge, velocity-pressure inf-sup
  stability, advective stabilization, and divergence control.
- Section 7.3.6 now treats radial profiles as secondary output pending
  regenerated same-cut report evidence instead of claiming a physical closure
  failure.
- Appendix G now keeps stable academic numerical-method material separate from
  mutable runtime status, restart roadmap, parity discrepancy, and live
  execution details.
- Appendix G and Section 5 now state that focused native-FSI mathematical
  contract evidence exists without promoting Section 4.1 reproduction or
  production parity.
- Section 7 verification and the generated MMS table now report
  metric-specific observed orders for discrete $L_1$, $L_2$, and $L_\infty$
  manufactured-solution errors.
- Appendix G now classifies the DG fixed-grid p-sweep as diagnostic when rows
  plateau or regress, not as accepted p-convergence evidence.
- Package-side smooth MMS DG p-improvement now exists at focused test scope,
  but Appendix G and generated report assets still need a coordinated
  regeneration/review lane before any accepted p-convergence prose changes.

## Next Round Objective

Close the artifact/evidence-readiness gap without changing scientific claims.
The next round should decide what to do with the dirty `public/final-report.pdf`
and then prepare for regenerated evidence only after the package fleet gates
produce accepted inputs.

## Immediate Execution Plan

### 1. Re-anchor

Run:

```sh
git status --short
git log -8 --oneline
pipenv run ops-orchestrate status --json
```

Expected starting condition:

- no report TeX source diff unless another editor has landed a new prose lane;
- `public/final-report.pdf` may be dirty and protected;
- package code/docs are owned by the package orchestrator unless explicitly
  assigned back to the report lane.

### 2. PDF Artifact Decision

If the only dirty file is `public/final-report.pdf`, do not commit it blindly.
First compare the tracked, working-tree, and scratch-build PDFs:

```sh
git show HEAD:public/final-report.pdf > /tmp/head-final-report.pdf
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/head-final-report.pdf /tmp/head-final-report.txt
pdftotext -layout public/final-report.pdf /tmp/worktree-final-report.txt
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/scratch-final-report.txt
diff -u /tmp/head-final-report.txt /tmp/scratch-final-report.txt
diff -u /tmp/worktree-final-report.txt /tmp/scratch-final-report.txt
```

Then choose one path:

- If source is clean and scratch text/layout matches the tracked PDF, restore
  or leave the working-tree PDF only by explicit artifact-owner decision.
- If scratch output reflects intentional source or asset changes, run
  `pipenv run ops-build-report --outdir /tmp/masters-report-build` to sync the
  public PDF, visually spot-check the changed pages, and commit the PDF alone.
- If text/layout differs unexpectedly, inspect the affected pages before any
  PDF commit.

Do not use SHA equality alone as the acceptance criterion for PDFs; build
metadata can change even when reader-facing text is unchanged.

### 3. Evidence-Regeneration Readiness

Do not regenerate report comparison assets until the package side hands off
accepted evidence for the relevant gate. The report lane needs explicit
package-side handoff for:

- `sev23` preproduction execution;
- production/fleet execution;
- regenerated section-area, flow, velocity, rest-state, radial-profile, and
  comparison rows;
- same-cut radial-profile evidence promotion;
- imported parity classification;
- manuscript-grade Section 4.1 claim review.

Once handed off, regenerate only the affected report assets:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pipenv run ops-audit-report-prose --json
```

Add package/evidence-specific commands from `packages/stenotic-hemodynamics/TODO.md`
when that lane supplies them.

### 4. Claim-Boundary Scan

Before any claim promotion or final PDF refresh, scan active manuscript prose:

```sh
rg -n "Section 4\\.1 reproduction|paper-grade|production parity|imported parity|monolithic ALE|moving-wall/ALE fidelity|persisted restart|radial area-closure gate fails|FEM-01 through FEM-04|blocks exact" report/sections report/appendices report/TODO.md -g '*.tex' -g '*.md'
```

Allowed matches should be bounded negative claims or TODO gate descriptions.
Any positive reproduction/parity claim must be backed by accepted package and
report evidence.

For verification-reporting language, also scan:

```sh
rg -n "L2-only|L_2-only|observed \\$L_2\\$ rates|order columns use adjacent-grid \\$L_2\\$|accepted DG p-convergence|accepted p-convergence" report/sections report/appendices report/assets/tables report/TODO.md -g '*.tex' -g '*.md'
```

Allowed matches should be guardrail text only. MMS spatial orders should be
metric-specific, and DG fixed-grid p-sweep rows should remain diagnostic unless
a future numerical-method repair supplies accepted p-convergence evidence.

### 5. Final Editorial Closeout

After evidence assets and source prose are stable:

- record the exact source commit for the submitted PDF in Appendix H;
- replace any remaining tautological conclusion opening if it reappears;
- inspect pages affected by Appendix G, Section 7, and the final PDF refresh;
- run the report build once without syncing, then once with PDF sync if the
  artifact is in scope;
- commit source and PDF artifacts separately unless the PDF depends on the same
  source change.

## Package Coordination Boundary

The report lane does not own package implementation. Current package-side
follow-ups remain:

- 12B regenerated DG p/h verification assets and Appendix G wording, coordinated
  with the package orchestrator so limiter-policy metadata is visible and the
  conservative production limiter is not misrepresented;
- 12C focused test hardening for dynamic membrane output and Python renderers;
- 10C-P native resolved-FSI phase timing before solver/numerics changes;
- FEM-05 quadrature sensitivity and open-boundary/backflow diagnostics;
- OBS-02 radial-coordinate and excluded-area policy;
- OBS-03 axial/reconstructed axial velocity naming;
- MODEL-01 `ClassicalParabolicOneDModel` rename with deprecated alias;
- MODEL-02 split evolution-pressure and diagnostic-pressure APIs;
- FSI-01 classify the current native path as repeated deformed-domain fluid
  solves with a reduced membrane update, not monolithic ALE.

Gridap remains the current backend. The next performance claims require phase
telemetry and baseline comparisons before factorization reuse, Krylov solvers,
new sparse-solver dependencies, or backend replacement can be justified.

## Validation Commands

For report source edits:

```sh
git diff --check -- report/TODO.md report/sections report/appendices
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

For PDF artifact lanes:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/scratch-final-report.txt
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
```

## Live Layout Guardrails

- manuscript entrypoint: `report/final-report.tex`;
- Section 2: `report/sections/02-continuum/index.tex`;
- Section 5: `report/sections/05-numerical-methods/index.tex`;
- Section 7 comparison: `report/sections/07-case-study/comparison.tex`;
- discussion and conclusion: `report/sections/08-discussion-conclusion/index.tex`;
- Appendix E: `report/appendices/continuum-derivation-details.tex`;
- Appendix G: `report/appendices/numerical-methods-details.tex`;
- Appendix H: `report/appendices/code-and-ai-use.tex`;
- package code: `packages/stenotic-hemodynamics/src/StenoticHemodynamics/**`;
- package TODO owner: `packages/stenotic-hemodynamics/TODO.md`;
- repo documentation: `public/docs/**`.

Do not reference stale root `docs/**` revision-ledger paths or
`report/sections/03-conclusions/index.tex`.
