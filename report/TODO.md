# Coordinated Mathematical-Alignment Plan

## Current Status

The prior final-submission/no-op closeout is withdrawn. A grounded review of the
independent audit found that the manuscript and package now need a coordinated
mathematical-alignment pass before the report can be treated as final. Package
commit `5aafb22 Plan native FSI math contract alignment` has established the
package-owned Lane 11 boundary after `2c765ee Prepare native FSI hybrid
batches`; this report TODO remains the report-owner plan for manuscript and
appendix alignment.

The last public PDF remains a useful pre-alignment artifact, not the final
submission artifact after this new lane begins, and
`public/final-report.pdf` must not be treated as final while the alignment lane
is open:

```text
public/final-report.pdf
sha256: a7646013b30307a5adc33d3cecc78a743f9f38e61b4fc025dc5a6993d82d634f
```

Live-tree grounding for this TODO refresh:

- `master` is at `5aafb22 Plan native FSI math contract alignment`.
- The package TODO now owns `Lane 11: Mathematical Contract Alignment` as a P0
  gate before native Section 4.1 preproduction execution, production
  execution, imported parity promotion, or manuscript-facing reproduction
  claims.
- The package-owned hybrid batch runner/process-thread work from `2c765ee` is
  observability and batch-safety work only. It does not establish production
  parity, imported parity, moving-wall/ALE fidelity, restart/resume support, or
  manuscript-grade Section 4.1 reproduction.
- The live dirty tree includes package, viewer, and `public/final-report.pdf`
  changes owned by other lanes. This report lane must not revert, stage, or
  normalize those files.

Grounded audit findings confirmed from the live checkout:

- Appendix E currently says no weak formulation is asserted, while Section 5.1
  says FEM discretizes a weak incompressible-flow or FSI problem. That
  contradiction must be removed by adding the missing integral and variational
  balance material, not by cross-reference wording alone.
- Section 5.1 conflates pressure uniqueness, discrete velocity-pressure
  inf-sup stability, advective stabilization, and divergence control.
- `native_resolved_fsi_gridap.jl` still has a transient convective term missing
  the density factor under a dimensional formulation.
- The Stokes/Navier-Stokes Gridap routes use vector-Laplacian viscous forms
  while package status text refers to zero outlet stress/Cauchy traction.
- The transient Gridap route still uses an unconditional zero-mean pressure
  constraint, even for traction-referenced problems.
- The reduced comparison still maps imported case `77` to generic severity
  `23.0`, while the native Section 4.1 mesh uses the paper-specific
  `delta_r_cm=0.0406`, `rmin_cm=0.1394` geometry.
- The radial-profile audit still looks for an exact same-plane row in the
  retained 200-section target grid and maps a missing section observation to
  "radial area closure exceeds 1%."
- `radial_profile_velocity` returns reconstructed axial velocity, not radial
  velocity.
- Appendix G mixes stable academic numerical-method material with mutable
  runtime status, checkpoint schema, restart roadmap, parity discrepancy, and
  artifact-refresh language.

## Objective

Complete a coordinated manuscript/package mathematical-alignment pass. Establish
integral and variational balance forms in Section 2 and Appendix E; correct the
mixed-FEM discussion; resolve the Gridap momentum, traction, pressure-space, and
wall-load contracts; unify the exact Canic case geometries; repair the
same-plane radial-profile closure audit; rerun affected evidence; rewrite
Appendix G in stable academic form; then rebuild and freeze the submitted
artifact.

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
Radial distributions of axial velocity are not promoted because the current
observation audit does not evaluate section and radial-bin closure on identical
axial cuts. The selected profile slices are not members of the retained
200-section target grid, so the present audit returns an unevaluable closure
status rather than evidence of a physical profile-closure failure. The retained
comparison therefore remains a section-mean axial-velocity comparison.
```

Do not claim a physical radial-profile closure failure until OBS-01 is
implemented and regenerated.

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

Lane 11 is P0 before native Section 4.1 preproduction execution, production
execution, imported parity promotion, or manuscript-facing reproduction claims.
Current exact-boundary strings such as `exact_section41`,
`implemented_smoke_validated`, and `zero_outlet_stress_natural_traction` are
provisional implementation/status labels until FEM-01 through FEM-04 pass.

P0 package items:

- FEM-01: make transient convection density-consistent or explicitly
  density-divide the whole weak form.
- FEM-02: use symmetric-gradient Cauchy traction for Newtonian stress claims,
  or downgrade zero-stress/exact status language.
- FEM-03: implement a boundary-aware pressure-space policy; use zero mean only
  when pressure is genuinely defined up to an additive constant.
- FEM-04: compute transmural or full-traction wall load; do not
  gauge-normalize wall pressure before using it as physical wall forcing.
- GEOM-01: unify exact Canic case geometry across resolved/reduced comparison;
  case `77` must use `delta_r_cm=0.0406`, `rmin_cm=0.1394`, while case `60`
  uses `delta_r_cm=0.072`, `rmin_cm=0.108`.
- OBS-01: compute section and radial-bin observations on identical axial cuts
  and classify `not_evaluated`, `failed_area_closure`,
  `failed_flow_closure`, or `passed`.

P1 package items:

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

After the package mathematical-contract fixes land:

- rerun affected section-area, flow, velocity, rest-state, radial-profile, and
  comparison table generation;
- regenerate any changed `report/assets/data/**`, `report/assets/tables/**`,
  and rendered figures consumed by the report build;
- rerun native/FEM mathematical-contract tests before promoting any Section 4.1
  status;
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
- same-plane radial area and flow closure;
- axial-profile helper naming and any future distinct radial-velocity
  reconstruction.

## Commit Discipline

Immediate report TODO refresh:

```sh
git add report/TODO.md
git commit -m "Plan coordinated mathematical alignment"
```

Do not stage the current dirty Julia files from the report lane. The principal
Julia thread owns the package TODO refresh and any package implementation
commits.

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
