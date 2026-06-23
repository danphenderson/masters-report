# Coordinated Mathematical-Alignment Plan

## Current Status

The prior final-submission/no-op closeout is withdrawn. Package commits
`2a54a06 Align native FSI mathematical contract` and `f8e247d Refresh native FSI
fleet plan` retire the Lane 11 P0 mathematical-contract blocker at focused
package-test scope. This report TODO remains the report-owner plan for the
manuscript, evidence assets, and final artifact refresh.

The last public PDF remains a useful pre-alignment artifact, not the final
submission artifact after this new lane begins, and
`public/final-report.pdf` must not be treated as final while the alignment lane
is open:

```text
public/final-report.pdf
sha256: a7646013b30307a5adc33d3cecc78a743f9f38e61b4fc025dc5a6993d82d634f
```

Live-tree grounding for this TODO refresh:

- `master` is at `f8e247d Refresh native FSI fleet plan`.
- Lane 11 now has focused contract/smoke-test evidence for density-consistent
  transient and convection terms, symmetric-gradient Cauchy viscous form, and
  boundary-aware pressure-space policy.
- The exact `poiseuille_inlet_zero_outlet_stress_section41` route now records
  no Gridap zero-mean pressure constraint. Pressure-drop smoke mode remains a
  separate additive-nullspace zero-mean check.
- Partitioned membrane forcing now uses raw physical wall-pressure samples;
  outlet-gauge normalization is diagnostic/export-only, and restart metadata
  validates that convention.
- Exact Canic geometry is unified for imported cases `77` and `60`.
- Radial-profile audits now evaluate section and radial-bin observations on
  same-cut slices and classify closure as passed, not evaluated, failed by area
  closure, or failed by flow closure.
- These changes retire the P0 mathematical-contract blocker only at focused
  package-test scope. They do not establish `sev23` preproduction execution,
  production/fleet execution, imported parity, moving-wall/ALE fidelity,
  persisted resume, regenerated report tables, radial-profile evidence
  promotion, or manuscript-grade Section 4.1 reproduction.
- The live dirty tree includes package, viewer, and `public/final-report.pdf`
  changes owned by other lanes. This report lane must not revert, stage, or
  normalize those files.

Grounded audit findings confirmed from the live checkout:

- The focused package-test contract evidence should be reflected in the report
  claim boundary without promoting execution or report-evidence claims.
- The retained report evidence has not yet been regenerated from the new
  geometry and same-cut radial-profile audit conventions.
- Section 4.1 of Canic et al. remains a comparison target, not a manuscript-grade
  reproduction claim.
- Appendix G should keep stable academic numerical-method material separate
  from mutable runtime status, checkpoint schema, restart roadmap, parity
  discrepancy, and artifact-refresh language.

## Objective

Complete the remaining report-side synchronization after the focused package
contract work. Keep the mathematical-contract blocker retired only at focused
package-test scope; then promote report claims only after the preproduction,
production, regenerated-evidence, same-cut radial-profile, imported-parity, and
manuscript-review gates pass.

## Report-Owned Implementation Plan

### 1. Section 2 and Appendix E: Balance Forms

Edit `report/sections/02-continuum/index.tex` and
`report/appendices/continuum-derivation-details.tex`.

- Add a compact Section 2 subsection titled `Integral and Variational Balance
  Forms`.
- State the control-volume form underlying FVM as an integral balance over a
  cell/control volume:

  ```tex
  \frac{d}{dt}\int_K U\,dx
  +\int_{\partial K}F(U)\cdot n\,dS
  =
  \int_K S(U)\,dx .
  ```

- State the fixed-domain mixed incompressible weak form with local boundary
  partition, admissible velocity and pressure test spaces, pressure gauge
  convention, and traction term. Keep the distinction explicit: FVM discretizes
  a control-volume integral balance; FEM discretizes a variational weak form.
- Add a schematic moving-domain/ALE/FSI statement in which the advective
  velocity becomes `u-w`, and state interface kinematic and traction balance:

  ```tex
  u_f=\partial_t d_s,\qquad \sigma_f n_f+\sigma_s n_s=0.
  ```

- Expand Appendix E with:
  - E.4 `Control-volume balance and FVM bridge`;
  - E.5 `Fixed-domain mixed weak incompressible formulation`;
  - E.6 `Pressure uniqueness, gauge conditions, and inf-sup stability`;
  - E.7 `ALE and FSI interface virtual-work form`.
- Remove or rewrite the Appendix E sentence that says no weak formulation is
  being asserted.

### 2. Section 5.1: Separate Numerical Contracts

Edit `report/sections/05-numerical-methods/index.tex`.

- Replace the current mixed-space paragraph with four distinct claims:
  pressure uniqueness/gauge fixing, discrete velocity-pressure inf-sup
  stability, advective stabilization, and divergence control.
- State that quotient pressure spaces or equivalent gauges handle additive
  pressure constants when the continuous problem leaves pressure determined
  only up to a constant.
- State that Taylor-Hood and appropriate divergence-conforming pairs address
  the mixed-space requirement directly; equal-order pairs generally require
  PSPG, pressure-projection, local-projection, or related stabilization.
- State that SUPG addresses advective instability and grad-div improves
  divergence control; neither alone repairs an inf-sup-unstable pressure space.
- Update package-specific wording so the Gridap routes are described as using a
  continuous P2 velocity/P1 pressure pair, without implying a broad collection
  of pressure stabilization, SUPG, and grad-div methods.

### 3. Section 7.3.6: Interim Radial-Profile Limitation

Edit `report/sections/07-case-study/comparison.tex`.

Replace the current radial-profile limitation with the bounded audit result:

```text
Radial distributions of axial velocity are not promoted because the retained
report evidence has not yet accepted regenerated same-cut radial-profile rows.
The package audit now classifies section and radial-bin closure on identical
cuts, but the manuscript retains only the section-mean axial-velocity comparison
until the regenerated report assets are reviewed and accepted.
```

Do not claim a physical radial-profile closure failure or a passing radial
profile until the regenerated report evidence is accepted.

### 4. Appendix G: Stable Academic Restructure

Edit `report/appendices/numerical-methods-details.tex`.

Use this stable structure:

- G.1 `Rheology closures and regularization`;
- G.2 `Relationship to the extended 1D model of Canic et al.`;
- G.3 `Selected specialization and source-to-implementation differences`;
- G.4 `Finite-volume realization and equilibrium properties`;
- G.5 `Cross-dimensional observation operators`;
- G.6 `Resolved and membrane comparator formulations`;
- G.7 `Reproducibility and evidence boundary`.

Appendix G.2 must identify:

- the source `(A,Q)` equations;
- `\alpha_c`, the viscous correction `p_2`, wall law, and profile closure;
- the paper's `\gamma=9`, `\alpha=1.1` simulation choice;
- the package's parabolic `\alpha=4/3`, `g=4` specialization;
- the `R_{\max}^{-2}` wall-law normalization;
- the locally frozen effective-viscosity treatment in the `p_2` derivative;
- the approximate characteristic boundary rule;
- the fact that Canic-style `u_r` reconstruction is not implemented by the
  current axial-profile helper.

Use the phrase `Section 4.1 of Canic et al.` rather than an unqualified
`Section 4.1 reproduction`.

Move commit hashes, development mesh outcomes, checkpoint-sidecar schemas,
restart roadmaps, parity discrepancies, and live execution status out of the
academic numerical-method appendix. Those details belong in package
documentation, manifests, and `packages/stenotic-hemodynamics/TODO.md`.

### 5. Final Editorial Corrections

After the mathematical and evidence work lands:

- fix the clipped long identifier on page 78;
- remove revision-history language from page 49;
- record the exact source commit for the submitted PDF in Appendix H;
- replace the tautological opening sentence of the conclusion;
- rebuild and visually inspect pages affected by the weak-form expansion and
  Appendix G rewrite.

## Package Coordination Requirements

The package TODO introduced `Lane 11: Mathematical Contract Alignment` in
`5aafb22`. The principal Julia developer thread owns
`packages/stenotic-hemodynamics/TODO.md` and package implementation; the report
lane should not edit package TODO or package code unless explicitly reassigned.
This file remains the report-owner alignment plan.

Package commits `2a54a06` and `f8e247d` retire the Lane 11 P0 mathematical
contract blocker at focused package-test scope. Remaining report gates before
claim promotion:

- `sev23` preproduction execution;
- production/fleet execution;
- regenerated reduced/resolved report tables and rendered assets;
- same-cut radial-profile evidence promotion after report-asset review;
- imported parity classification;
- manuscript-grade Section 4.1 claim review;
- final PDF refresh after source and assets are consistent.

Retained package follow-up items:

- 10C-P: add native resolved-FSI phase timing before changing numerics. The
  next solver patch after Hypatia's active run must instrument matrix assembly,
  symbolic factorization, numeric factorization, backsolve, wall update,
  diagnostics, checkpoint/output, and total step time in batch status and
  benchmark sidecars. Factorization reuse, symbolic reuse, Krylov solvers, or
  new sparse-solver dependencies remain blocked until timing evidence and
  baseline comparisons justify them.
- FEM-05: increase convection quadrature and add open-boundary/backflow
  diagnostics.
- OBS-02: clarify radial-coordinate and excluded-area policy.
- OBS-03: rename `radial_profile_velocity` to axial/reconstructed axial
  velocity terminology.
- MODEL-01: rename `ClassicalNoSlip1DModel` to
  `ClassicalParabolicOneDModel`, keeping `classical-1d-no-slip` as a
  deprecated CLI alias.
- MODEL-02: split the ambiguous `pressure()` API into evolution and diagnostic
  pressure conventions.
- FSI-01: classify the current path as repeated deformed-domain solves with a
  reduced membrane update, not monolithic ALE.

Gridap remains in place for now. The package review found no evidence
justifying backend replacement yet; the next performance work is phase
telemetry and wrapper-allocation fixes, not manuscript claim promotion.

## Evidence Regeneration Plan

After the focused package mathematical-contract fixes have landed, remaining
report evidence work is:

- rerun affected section-area, flow, velocity, rest-state, radial-profile, and
  comparison table generation;
- regenerate any changed `report/assets/data/**`, `report/assets/tables/**`,
  and rendered figures consumed by the report build;
- confirm native/FEM mathematical-contract tests together with the regenerated
  report evidence before promoting any Section 4.1 status;
- rerun the report build without syncing the PDF first;
- only refresh `public/final-report.pdf` after code, evidence assets, and TeX
  are all consistent.

The current PDF must not be treated as the final frozen artifact after this
alignment lane begins.

## Validation Commands

For this report-side alignment patch:

```sh
git diff --check -- report/TODO.md report/sections report/appendices
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

For the later manuscript/package implementation:

```sh
git diff --check -- report packages/stenotic-hemodynamics
pipenv run ops-audit-report-prose --json
pipenv run ops-audit-references
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics packages/stenotic-hemodynamics/test/test_public_api.jl
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_resolved3d.jl")'
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

Add or extend focused tests for:

- manufactured transient convection with nonzero convection and density
  scaling;
- Cauchy traction versus vector-Laplacian natural boundary form;
- pressure-space policy for all-Dirichlet and traction-referenced cases;
- global discrete divergence and inlet/outlet flow balance;
- pressure-shift invariance of transmural wall load;
- exact Canic case geometry and geometry hash;
- same-cut radial area and flow closure;
- axial-profile helper naming and any future distinct radial-velocity
  reconstruction.

## Commit Discipline

Do not commit this report-side synchronization lane unless explicitly asked.
Do not stage the current dirty Julia files from the report lane. The principal
Julia thread owns package TODO refreshes and package implementation commits.

Later implementation commits should be split by surface:

- package mathematical-contract fixes and tests;
- regenerated package/report evidence assets;
- manuscript TeX revisions;
- final PDF refresh.

## Live Layout Guardrails

Use the current layout:

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
