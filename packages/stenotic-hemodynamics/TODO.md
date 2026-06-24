# StenoticHemodynamics Authoritative Fleet TODO

Date: 2026-06-24

This is the current implementation plan for `packages/stenotic-hemodynamics`.
Treat the live checkout as authority before dispatch.

## Current Baseline

Implemented and committed:

- `aafec81` / `9dd964b`: exact Section 4.1
  `poiseuille_inlet_zero_outlet_stress_section41` boundary mode in the
  low-level Gridap path, validated at tiny smoke-test scale.
- `cbf054f`: boundary mode, boundary class, Section 4.1 evidence status, and
  boundary-equivalence disclaimers propagated through production dry-run,
  diagnostics, restart metadata, and parity/status rows.
- `1832e1e`: exact boundary mode threaded through the tiny partitioned
  production smoke-scale harness. Exact-mode production disables pressure-drop
  wall-pressure fallback and requires direct finite pressure sampling.
- `f972368`: parity/status wording bounded so `ready` means
  artifact/operator readiness, not paper-grade reproduction or validated
  Section 4.1 parity.
- `d6ba01e`: `fsi native-status` CLI added as a status-only dry-run surface.
  It reports guard status, output paths, boundary status, and imported-bundle
  status without running production or writing solver outputs.
- `362940d`: workflow files split into responsibility subdirectories under
  `src/StenoticHemodynamics/workflows/` without changing behavior, exports,
  CLI commands, artifact filenames, restart/importer schemas, or public API.
- `f7934bb`: package/public docs synced to the post-9C/9D/10A evidence
  boundary.
- `fc8bbad`: local native resolved-FSI sampling helpers now preserve finite
  real scalar pressure/velocity values instead of downcasting before the
  existing `Float64` production-array boundary.
- `df95c58`: follow-up scalar helper audit extended the same boundary to outlet
  pressure gauging and wall-pressure plane sampling, with focused
  `Float32`/`BigFloat` tests.
- `b8451e4` / `3f1b7c7`: wall-stability and pressure-load diagnostics now
  surface through dry-run/status and fail fast before mutating wall state when
  a pressure load would invert a radius.
- Lane 10E CLI follow-up: top-level `fsi` help now describes membrane-FSI
  validation and native resolved-FSI status workflows, while `fsi
  native-status` remains dry-run/status-only and cannot trigger production
  execution by default.
- Lane 9F restart stewardship audit: no patch required after 9C. Old metadata
  remains readable, exact metadata requires positive `inlet_umax_cm_s`,
  `state_payload` remains versioned audit metadata, and public/default resume
  remains fail-closed.
- Lane 10D restart/resume boundary: production metadata now writes schema-v3
  durable checkpoint sidecars for wall, mesh, fluid-state, coupling, cursor,
  and output linkage. Legacy schema-v1 audit metadata and schema-v2
  checkpoint-manifest metadata remain readable. A qualified internal split-run
  resume path can continue into a forked output root at smoke/operator scope;
  public/default resume and CLI exposure remain fail-closed.
- Lane 10C batch-prep: the partitioned production runner now preflights output
  ownership before Gridap work, writes `batch_status.jsonl`,
  `batch_status.csv`, `batch_benchmark.json`, and fail-fast
  `batch_failure.json` sidecars, and reports step/time/radius/mesh/field/
  coupling/path status for long batch runs. This is observability and batch
  safety, not preproduction execution evidence.
- `2c765ee`: native resolved-FSI batch prep now supports process-level batch
  execution with per-worker thread requests, records process/thread provenance
  in dry-run/status/restart/benchmark artifacts, and threads only deterministic
  helper loops. Gridap field evaluation remains serial until thread-safety and
  phase-profiling evidence justify widening that boundary.
- `2a54a06`: Lane 11 P0 mathematical-contract alignment landed at focused
  contract/smoke-test scope. The native Gridap adapter now uses
  density-consistent transient/convection terms, symmetric-gradient Cauchy
  viscous stress, and a boundary-aware pressure-space policy; exact mode no
  longer claims a Gridap zero-mean pressure constraint. Partitioned wall
  forcing now uses raw physical wall-pressure samples while outlet-gauge
  normalization is diagnostic/export-only. Exact Canic geometry is unified for
  imported cases `77`/`60`, and radial-profile audits classify same-cut area
  and flow closure with `passed`, `not_evaluated`, `failed_area_closure`, or
  `failed_flow_closure`.
- `bbf485e` / `d73afa9`: manufactured-solution verification now reports
  metric-specific observed orders for the discrete `L1`, `L2`, and `Linf`
  area/flow errors, and the report-prose audit catches stale L2-only MMS-order
  wording.
- `56e68e1`: the p/h verification demo now labels fixed-mesh DG p-sweep rows
  with conservative diagnostic status (`baseline`, `regressed`, `plateau`,
  `not_evaluated`) instead of allowing plateaued or regressed rows to read as
  accepted p-convergence evidence.
- `0413a97`: DG smooth-verification runs can now disable the modal limiter
  explicitly while preserving the existing limited default. Focused
  verification tests show the limiter-disabled smooth MMS p-sweep restores
  rapid area/flow p-improvement.
- `a89f6fd`: scalar-generic core helper continuation landed for velocity
  profiles, geometry, wall coefficients, characteristic invariants, and
  variable-radius correction terms. Native resolved-FSI production/Gridap
  arrays remain `Float64`-oriented.
- `c9a85c3`: the inlet characteristic area solve no longer hides root-solve
  policy as magic loop limits. It now uses validated internal
  `InletAreaSolveControls`, preserves finite `AbstractFloat` scalar inputs
  where applicable, and has seam tests for custom controls and invalid
  policies.
- `49e0ba8`: CLI refinement-study tests are standalone-include safe and assert
  finite, nonzero p-refinement errors in addition to metadata.
- `d52dcb1`: native resolved-FSI Gridap solve instrumentation now splits
  model setup, FE-space setup, measure setup, affine-operator construction,
  matrix extraction, RHS extraction, symbolic factorization, numeric
  factorization, and backsolve timing. Production status/benchmark sidecars
  also record instrumentation-only matrix/RHS fingerprints, pressure policy,
  boundary mode, wall-boundary mode, and explicit
  `reuse_not_attempted_instrumentation_only` status.
- `cf2d78c`: the web viewer has a documented production-bundle serve command
  (`npm run serve` / `pipenv run ops-serve-stenotic-hemodynamics-viewer`) with
  README and public-doc coverage.
- `ab258bc`: Wave 1 viewer evidence controls landed. The viewer field rail is
  manifest/frame-backed for velocity magnitude, pressure, and displacement
  magnitude; missing fields disable cleanly; colorbar labels report
  current/global ranges; evidence badges cover claim boundary, coordinate
  mode, skipped snapshots, sidecars, and observations; browser smoke covers a
  generated missing-field manifest. The package TODO was refreshed to close
  obsolete Wave 1 lanes before Wave 2 review.
- `b394c18`: Wave 2 warmed timing decision recorded. The representative
  `(12, 2, 12)` pilot found repeated affine-operator assembly cost, stable
  sparse structure, and changing matrix/RHS values. No factorization-reuse or
  Gridap-context reuse patch is accepted from that evidence; future
  optimization must be assembly-specific and invariant-gated.
- `5136a67`: report-side asset-promotion planning refreshed after the package
  viewer/timing handoff. Current viewer controls, evidence badges, timing
  sidecars, and matrix fingerprints remain package/operator metadata only; they
  do not require report asset/PDF refresh or promote native resolved-FSI
  claims.
- Current integration round: Lane 11 P1, FEM-05, FSI-01, and Lane 10D are
  implemented in this handoff. This adds canonical
  parabolic-model/profile/pressure API names with deprecated compatibility
  aliases, radial-bin policy tests/docs, quadrature/backflow diagnostics,
  repeated deformed-domain fluid-solve classification, schema-v3 durable
  restart checkpoints, and qualified internal split-run resume. It does not
  promote native resolved-FSI reproduction, imported parity, monolithic ALE, or
  manuscript evidence.

## Non-Negotiable Claim Boundary

- Exact Section 4.1 boundary-mode support exists in the low-level Gridap path
  and in the tiny partitioned production smoke-scale harness.
- Paper-grade native resolved-FSI reproduction, imported parity for the Gridap
  production path, and monolithic ALE FSI remain unestablished. The separate
  `canic-replication section41` source-artifact workflow now owns the promoted
  manuscript Section 4.1 comparison against restored upstream bundles.
- `:pressure_drop_weak_inlet_outlet_gauge_smoke` remains local smoke/loading
  evidence.
- `:poiseuille_inlet_zero_outlet_stress_section41` remains smoke-scale
  exact-boundary/operator-readiness evidence until production-scale validation
  and imported-data parity evidence land.
- The current exact-boundary reduced partitioned path uses stationary no-slip
  wall solves on deformed geometry, not a monolithic ALE or strong moving-wall
  fluid boundary claim.
- Post-sampling outlet pressure normalization is not a Gridap pressure
  nullspace constraint.
- Restart `state_payload` is audit metadata only. Schema-v3 durable
  checkpoints support qualified internal split-run resume for package/operator
  validation, but public/default restart/resume and CLI exposure are
  unsupported and fail-closed.
- CLI/status surfaces must continue to expose these boundaries and must not
  imply paper-grade reproduction.
- Status strings such as `exact_section41`,
  `implemented_smoke_validated`, and `zero_outlet_stress_natural_traction`
  remain implementation/status labels. After `2a54a06`, they are backed by the
  focused mathematical-contract tests, but they still do not imply
  production-scale execution, imported parity, moving-wall/ALE fidelity, or
  native resolved-FSI Section 4.1 reproduction.
- Native resolved-FSI production arrays and Gridap adapter surfaces remain
  `Float64`-oriented unless a future lane explicitly generalizes them. Local
  scalar helpers should avoid unnecessary downcasts when they can preserve
  `AbstractFloat` values safely.
- Manufactured-solution MMS observed orders are discrete metric-specific
  verification evidence only. They do not establish physical validation,
  resolved-FSI parity, or native resolved-FSI Section 4.1 reproduction.
- Fixed-mesh DG p-sweep rows are diagnostic unless the row metadata identifies
  the smooth-verification limiter policy that produced accepted p-improvement.
  The tracked Lane 12B report assets and final PDF now reflect the accepted
  limiter-disabled smooth MMS verification configuration; this does not change
  the conservative limited default or promote native resolved-FSI claims.

## Current Planning Artifact

- Lane 10C records the production-scale Section 4.1 validation roadmap in
  `public/docs/stenotic-hemodynamics/section-4-1-production-validation-plan.md`.
  The plan keeps smoke-scale exact-boundary evidence, production-scale native
  generation, imported-data parity, and manuscript claim readiness separate.
- Lane 10C preflight dry-run matrix completed as status-only planning evidence.
  In the current checkout, `sev23`, `sev40`, and `sev50` development,
  preproduction, and production-target single-snapshot plans all reported
  snapshot-count and payload guards passing, no required override flags, and a
  provisional exact-boundary status string. Imported bundles were observed for
  `sev23` and `sev40`; `sev50` remains expected-skip unless a bundle is
  explicitly supplied. This did not run production or write solver outputs.
  Lane 11 P0 now supplies focused mathematical-contract evidence, but
  production-scale execution and imported parity remain separate gates.
- Lane 10C development execution probes reached the exact-boundary partitioned
  production path for `sev23` at `(40, 3, 16)`, `dt_s=1e-4`. Earlier probes
  failed closed at time steps 2-4 before writing solver artifacts because the
  moving-wall/explicit membrane handoff produced non-positive current radii.
  The current patch changes exact-mode fluid solves to stationary no-slip wall
  data on deformed geometry and advances the reduced membrane with a
  semi-implicit update. The full development-mesh gate (`tfinal_s=1e-2`, final
  snapshot only) now completes, writes solver artifacts, and reports finite
  fields, positive current radii, positive tetrahedron orientation, direct
  finite wall-pressure sampling, importer-compatible sidecars, and exact
  stationary-wall handoff metadata. This resolves the immediate early-step P0
  failure at development scope. The run used one coupling iteration per step
  and records bounded, non-converged coupling history, so preproduction,
  production target, imported-data parity, stronger coupling evidence, and the
  moving-wall ALE-fidelity question remain open.
- Lane 10C development-output parity artifact generation ran on the completed
  `sev23` development bundle against imported case `77`. The observation and
  summary CSVs were written under the scratch snapshot directory, imported
  observations loaded, and parity rows remained exact-boundary/status-bounded.
  Development-scale differences were nonzero (`max_mean_velocity_abs_difference_cm_s
  ≈ 2.317`, `max_mean_pressure_abs_difference_dyn_cm2 ≈ 813.906`), so this is
  operator/artifact evidence and discrepancy classification, not production
  parity.
- Wall-stability observability now propagates through production dry-run plans
  and `fsi native-status`: dry-run reports the membrane oscillator `dt_s`
  guard, the mass/stiffness scale, and whether the exact-mode development
  artifact gate is the strongest observed evidence. Historical smaller
  `dt_s` scratch probes alone did not clear the gate: one `dt_s=1e-5` run
  reached the deformed-mesh guard and failed on an inverted/degenerate
  tetrahedron, while a longer `dt_s=1e-5` probe was runtime-inconclusive.
- The partitioned Navier-Stokes pressure-space policy is boundary-aware:
  pressure-drop smoke loading uses a Gridap additive-nullspace zero-mean
  constraint, while exact Poiseuille/natural-traction mode uses no Gridap
  zero-mean pressure constraint. `pressure_nullspace_status` is recorded
  through dry-run, `fsi native-status`, diagnostics, and restart metadata.
  Scratch probing showed this is pressure-gauge hygiene only: it did not
  reduce the exact-mode wall-pressure/load scale and is not accepted as
  wall-stability remediation.
- The partitioned wall update now has a fail-fast pressure-load plausibility
  gate that predicts radius inversion before mutating wall state and reports
  the semi-implicit displacement increment used by the current reduced wall
  step.
- Lane 10D records the persisted restart/resume design in
  `public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`.
  Schema-v1 audit metadata, schema-v2 checkpoint-manifest validation, schema-v3
  durable checkpoint sidecars, and a qualified internal split-run resume path
  are implemented at smoke/operator scope. Current `state_payload` remains
  audit metadata, and public/default resume remains fail-closed. Production-scale
  resume validation, imported-parity resume coverage, CLI exposure, and claim
  promotion remain future work.
- Lane 10C batch-prep is implemented for preproduction launch readiness.
  Dry-run/status output now includes estimated time steps, a conservative fluid
  solve upper bound, status/benchmark/failure sidecar paths, checkpoint roles,
  and a production spec digest. The full `sev23` preproduction solve has not
  been launched or validated.
- Current-source `fsi native-status` was refreshed on 2026-06-24 for the
  exact-boundary `sev23` preproduction plan at `(80, 4, 24)`, `dt_s=1e-4`,
  `T=0.1`, final snapshot only. It reported production spec digest
  `9d1cfb96eb525113`, 1000 estimated time steps, expected fluid-solve upper
  bound 1001, estimated preproduction runtime 63000 s, no required override
  flags, passing snapshot/payload guards, Section 4.1 boundary status
  `implemented_smoke_validated`, and imported case `77` available. This is a
  dry-run/status result only; it wrote no solver outputs and did not launch the
  many-hour preproduction solve.
- The first `sev23` preproduction evidence attempt at `(80, 4, 24)`,
  `dt_s=1e-4`, `T=0.1` stopped without completion artifacts after reaching
  step 40/1000. Treat its sidecars as incomplete runtime diagnostics only.
- Current-HEAD timing pilot
  `native-fsi-timing-pilot-current-head-20260624-103257` on `5b73e64`
  completed a tiny two-step `sev23` run through the internal Julia production
  runner. Sidecars live under
  `tmp/simulations/output/native-fsi-timing-pilot-current-head-20260624-103257/.../batch_status.jsonl`,
  `batch_status.csv`, and `batch_benchmark.json`. The per-step
  `time_step_completed` rows classify the run as first-use/setup dominated:
  step 1 reported `step_total_s` about 43.205 s and `fluid_solve_total_s`
  about 42.353 s, dominated by Gridap model/space/measure setup
  (`3.052`, `6.318`, and `6.330` s) plus affine-operator construction
  (`24.475` s). Numeric factorization and backsolve were small
  (`0.085` s and `0.024` s). Step 2 then reported `step_total_s` about
  0.098 s, with warmed model/space/measure setup below 0.006 s combined,
  affine-operator construction about 0.089 s, numeric factorization about
  0.0013 s, and backsolve about 0.00004 s. The sparse structure digest stayed
  stable (`46fc7ac62087e904`), while matrix/RHS value digests changed. This
  completed Lane 10C-P1 for the current wave and did not justify
  factorization or Gridap-context reuse from tiny timing evidence alone. Wave
  2 subsequently ran the representative warmed/development-scale timing pilot
  recorded below.
- Wave 2 warmed/development timing pilot
  `native-fsi-wave2-warmed-timing-current-head-ab258bc-12x2x12-20260624-104028`
  completed four `sev23` time steps at `(12, 2, 12)` with final-only output.
  Sidecars live under
  `tmp/simulations/output/native-fsi-wave2-warmed-timing-current-head-ab258bc-12x2x12-20260624-104028/.../batch_status.jsonl`,
  `batch_status.csv`, and `batch_benchmark.json`. The first step still carried
  first-use Gridap lifecycle cost (`step_total_s` about 42.415 s). Warm steps
  2-4 averaged about 1.229 s each, with repeated affine-operator assembly
  dominant at about 0.792 s, numeric factorization secondary at about 0.266 s,
  and backsolve about 0.008 s. Model/space/measure setup averaged only about
  0.013 s combined on warm steps. The sparse structure digest stayed stable
  (`f792679cae71ca24`), but every matrix-value digest and RHS digest changed.
  Wave 2 therefore does not land a factorization-reuse or Gridap-context reuse
  patch in this pass: numeric reuse is unsafe when matrix values change,
  symbolic setup is not a measured bottleneck, and context setup is no longer
  the repeated warm-step cost. Future optimization should target
  assembly-specific design only after preserving the changing-geometry,
  changing-advection, and changing-boundary-value invariants.
- Report asset-promotion refresh `5136a67` confirms that the current
  viewer/timing package handoff does not create manuscript assets. Keep viewer
  bundles, browser-smoke fixtures, timing sidecars, and reuse/fingerprint
  metadata out of `report/assets/**` and `public/final-report.pdf` unless a
  separate accepted report-evidence lane explicitly promotes them.

## Orchestration Rules

- Start substantial work with:

  ```bash
  pipenv run ops-orchestrate status --json
  ```

- Treat the live dirty tree as authority.
- Use one writer per disjoint file set. Workers must stop before expanding
  scope.
- Prefer structural boundaries before new CLI/API surface area.
- Worker agents should not run official validation directly in the next round.
  They must hand back touched files, intended validation scope, known optional
  skips, and risk notes. The orchestrator or automated commit wrapper runs the
  official focused validation immediately before commit.
- Review worker diffs and validation handbacks. Do not repeat tests unless
  integration risk demands it or the orchestrator edits after handback.
- Preserve public exports, CLI command semantics, artifact filenames, importer
  schemas, and restart metadata compatibility unless a lane explicitly widens
  scope.
- Keep report/manuscript files under editorial ownership. Send sync notes for
  package claim-boundary changes instead of editing report files directly.
- Do not touch unrelated dirty state, including `public/reproducibility` or
  `report/**`, unless explicitly assigned.

## Current Dispatch Priority

Wave 1 closeout status:

- Lane 10C-P1 timing-sidecar review is complete for the current wave. The tiny
  current-HEAD sidecars classify the observed cost as first-use/setup
  dominated and do not justify immediate reuse work.
- Lane 12C focused test hardening was re-audited and requires no patch. The
  owned tests already assert nonzero membrane wall-velocity agreement,
  nonempty rendered artifacts, and numeric/stage-count fields.
- Lane 12D viewer evidence enhancements are implemented in the current
  checkout: manifest-backed scalar toggles, missing-field disabled states,
  colorbar range labeling, evidence badge coverage, and browser-smoke fixtures
  for skipped snapshots, sidecars, and observations. Viewer diagnostics remain
  inspection/operator aids only.

Wave 2 closeout status:

- Lane 10C-P2 timing review ran at `(12, 2, 12)` for four warmed-scale steps.
  It found repeated affine-operator assembly cost, stable sparse structure, and
  changing matrix/RHS values. No solver reuse patch is accepted in this pass.
  A future optimization lane must be assembly-specific and fail closed unless
  it preserves changing geometry, Picard/advection state, Dirichlet boundary
  values, pressure policy, mesh topology, and constrained DOF maps.
- Lane 11 P1 mathematical-contract stewardship is implemented in the current
  integration round. The canonical model/profile/pressure names landed with
  deprecated compatibility aliases, radial-bin policy tests/docs, and bounded
  resolved3D observation terminology updates.
- FEM-05/FSI-01 native diagnostics/classification updates are implemented in
  the current integration round: Gridap quadrature/backflow diagnostics are
  reported as observability fields, and the native path is classified as
  repeated deformed-domain fluid solves with a reduced membrane update rather
  than monolithic ALE.
- Lane 10D restart/resume implementation is implemented at package-internal
  smoke/operator scope with schema-v3 durable checkpoint sidecars and a
  qualified internal split-run resume path. Public/default resume remains
  fail-closed.

Wave 3 is no longer waiting on an unresolved Wave 2 decision, but it remains a
scheduled long-running compute lane:

- `sev23` preproduction batch execution and imported parity staging. Do not
  relaunch long runs from opportunistic package-worker rounds; proceed only
  when the orchestrator deliberately schedules the current no-reuse baseline or
  after a future assembly-specific optimization lands with validation.
- Latest current-source dry-run: production spec digest `9d1cfb96eb525113`,
  1000 estimated steps, expected fluid-solve upper bound 1001, estimated
  runtime 63000 s, no required override flags, and imported case `77`
  available. The actual preproduction execution is still open because it is a
  deliberate many-hour compute job, not stale TODO text.

### Lane 12V: Centralized Validation Automation

Status: implemented. Keep this as the official commit-readiness policy for
future lanes.

Official command:

```bash
pipenv run ops-orchestrate ready-to-commit
```

Objective: automate official validation at commit time without pushing slow
full-gate validation back into the local pre-commit hook.

Current policy baseline:

- `a836353` keeps the tracked pre-commit hook lightweight: merge conflicts,
  YAML/TOML/JSON syntax, case conflicts, private-key scan, and large-file
  guard.
- `ops-release-check --mode patch` remains the explicit aggregate
  integration/release gate.

Implemented:

1. Defined a lane handback contract for workers: touched files, intended
   validation scope, optional input skips, and risk notes.
2. Added a lane-aware `ops-orchestrate ready-to-commit` entrypoint that maps
   changed surfaces to focused validation commands before commit.
3. The orchestrator/commit wrapper runs those commands immediately before
   staging or committing managed lane changes.
4. Validation commands/results are recorded in final handbacks.
5. Expensive aggregate validation remains explicit; do not restore a full
   `ops-release-check` pre-commit hook.

Acceptance criteria:

- Official validation is centralized and repeatable at commit time.
- Worker agents do not spend cycles running the same official gates
  independently.
- Focused lane validation remains available for package Julia, ops/Python,
  report/PDF, docs-contract, and viewer surfaces.
- Failed validation blocks managed commits until the owner fixes or explicitly
  defers the issue.

Validation:

```bash
pipenv run ops-orchestrate ready-to-commit
pipenv run ops-orchestrate docs-contract
pipenv run pre-commit run --all-files
git diff --check -- README.md CONTRIBUTING.md AGENTS.md public/docs packages/ops
```

### Lane 12A: Smooth-DG p-Convergence Repair

Status: implemented in `0413a97` at package-test scope and synchronized to
report assets/prose through Lane 12B and final PDF commit `f939ef9`.

Priority: completed code lane; keep as evidence background for Lane 12B. This
lane does not alter native resolved-FSI production claims.

Objective: determine whether the fixed-mesh DG p-sweep failure is caused by
the limiter/boundary-cell mode policy or by deeper flux/source/timestep
inconsistency, then implement the smallest repair that preserves production
defaults.

Current read-only triage:

- The raw manufactured initial projection improves rapidly with polynomial
  degree, but `limit_dg_coefficients!` collapses smooth modal accuracy before
  the solve starts and zeroes boundary-cell nonconstant modes.
- The limiter is invoked after projection and after RK stages in
  `numerics/dg.jl`. This is likely the primary p-sweep error floor.
- Flow p rows are more sensitive than area because flow is dynamically
  generated from forcing/flux/source terms from an initially zero profile.
- Rusanov dissipation, finite-difference manufactured forcing, nonlinear
  source quadrature, and timestep sensitivity are secondary suspects to test
  only after the limiter policy is isolated.

Owned files for the first repair slice:

- `src/StenoticHemodynamics/numerics/dg.jl`
- `src/StenoticHemodynamics/workflows/verification/verification_ph_refinement.jl`
- `test/test_verification.jl`

Conditional files only after improved numerical evidence exists:

- `report/assets/data/verification/p_h_refinement_demo.csv`
- `report/assets/tables/verification/p_h_refinement_demo.tex`
- `packages/ops/src/ops/render_ph_refinement_demo.py`
- `packages/ops/tests/test_python_ph_refinement_demo.py`
- `report/appendices/numerical-methods-details.tex`

Implemented:

1. Added `apply_limiter::Bool = true` through the DG coefficient-simulation
   path and `PHRefinementDemoSpec`.
2. Guarded the initial modal-projection limiter and RK-stage limiter calls
   while leaving default production/simulation behavior unchanged.
3. Added `dg_limiter_policy` metadata to p/h refinement rows and CSV output.
4. Focused tests cover default-policy preservation and limiter-disabled smooth
   MMS p-improvement for area and flow.

Remaining: no further action unless a future verification audit reopens the
limiter-policy or p/h evidence boundary.

Validation commands:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_verification.jl")'
pipenv run ops-render-ph-refinement-demo --csv report/assets/data/verification/p_h_refinement_demo.csv --output-dir report/assets/rendered --table-dir report/assets/tables/verification
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
git diff --check -- packages/stenotic-hemodynamics packages/ops report
```

Acceptance criteria:

- Default DG production/simulation behavior remains unchanged unless a
  separate scientific review explicitly approves a default limiter-policy
  change.
- Scratch and focused tests show whether disabling the limiter restores smooth
  MMS p-sweep improvement.
- Report assets and prose are regenerated only after new numerical evidence
  exists.
- Any accepted p-convergence claim is bounded to the specific smooth MMS
  verification configuration that produced it.

### Lane 12B: Regenerate DG p/h Verification Assets

Status: implemented in the current 12B source/asset lane. The public PDF was
refreshed afterward in `f939ef9 Refresh final report PDF`.

Priority: completed source/asset lane; keep as the DG p/h verification
evidence baseline for the next report artifact refresh.

Objective: update the generated p/h verification demonstration assets and
manuscript wording to report the smooth MMS limiter policy honestly: the
default production limiter remains conservative, while the limiter-disabled
smooth-verification policy demonstrates expected p-improvement for the
manufactured smooth problem.

Owned files:

- `report/assets/data/verification/p_h_refinement_demo.csv`
- `report/assets/tables/verification/p_h_refinement_demo.tex`
- `packages/ops/src/ops/render_ph_refinement_demo.py`
- `packages/ops/tests/test_python_ph_refinement_demo.py`
- `report/appendices/numerical-methods-details.tex`
- `report/TODO.md`

Implemented:

1. Added `verify ph-refinement --disable-dg-limiter` so the limiter-disabled
   smooth MMS report asset can be regenerated from an auditable CLI command.
2. Regenerated `p_h_refinement_demo.csv` with `dg_limiter_policy=disabled`,
   `dt`, `tfinal`, `steps`, `degree`, `nx`, and DOF metadata.
3. Updated the Python renderer and generated LaTeX table so the policy and
   solver controls are reader-visible.
4. Regenerated the p/h refinement figure from the new CSV.
5. Updated Appendix G wording to bound the evidence to smooth MMS
   limiter-disabled DG verification and explicitly preserve the conservative
   default limiter boundary.
6. Refreshed `public/final-report.pdf` in a separate artifact commit after
   scratch-build and extracted-text comparison.

Validation commands:

See the 12B commit handback for exact generation and validation commands.
The PDF refresh was validated separately by scratch build, PDF text
comparison, prose audit, diff check, and the configured lightweight pre-commit
suite.

Acceptance criteria:

- The regenerated table includes metric-specific values and limiter-policy
  metadata sufficient to distinguish diagnostic limited-policy rows from
  smooth-verification rows.
- Appendix G does not describe fixed-mesh p rows as accepted convergence unless
  those rows are the limiter-disabled smooth MMS verification rows.
- No native resolved-FSI production, parity, restart/resume, moving-wall/ALE,
  or Section 4.1 reproduction claim changes.

### Lane 12C: Focused Test Hardening Follow-Up

Status: closed for the current wave. Re-audited on 2026-06-24 with no patch
required; keep this lane dormant unless future tests regress.

Priority: closed unless a future test failure or audit reopens it.

Objective: address the remaining non-vacuity improvements identified by the
read-only test-quality audit without broadening into speculative test churn.

Covered targets:

- `test_membrane_fsi.jl` already asserts nonzero dynamic wall-velocity maxima
  and agreement between in-memory solution rows, validation rows, profile CSV,
  and history CSV outputs.
- `packages/ops/tests/test_python_package_benchmark.py` already asserts
  fixture stage counts, finite required numeric fields, nonempty rendered
  figures/tables, and rendered stage counts.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_membrane_fsi.jl")'
pipenv run pytest packages/ops/tests/test_python_package_benchmark.py
pipenv run ruff check packages/ops/tests/test_python_package_benchmark.py
pipenv run black --check packages/ops/tests/test_python_package_benchmark.py
git diff --check -- packages/stenotic-hemodynamics/test/test_membrane_fsi.jl packages/ops/tests/test_python_package_benchmark.py
```

### Lane 12D: Viewer Evidence Enhancements

Status: implemented in the current Wave 1 viewer lane. Baseline viewer
evidence controls landed in `a8aa77b`; serve-command docs landed in
`cf2d78c`; the current checkout adds manifest-backed scalar toggles,
missing-field disabled states, current/global colorbar range labeling, evidence
badge coverage, and browser-smoke fixtures for skipped snapshots, sidecars,
observations, and missing pressure/displacement fields. The surface-node slice
panel remains an inspection aid only.

Priority: complete for this wave. Future visualization work is P2 and must not
collide with native-FSI numerics, report PDF, or package validation-automation
work.

Objective: expand displayed visual diagnostics after the coordinate-mode and
browser-smoke fixes are accepted, while preserving the evidence boundary that
viewer artifacts are inspection/operator aids.

Implemented targets:

- Kept `coordinate_mode` semantics explicit so reference/deformed geometry is
  never double-applied.
- Added/polished manifest-backed toggles for velocity magnitude, pressure, and
  displacement magnitude, with missing fields disabled cleanly.
- Added a colorbar with min/max ticks, units, and current/global range
  labeling.
- Surfaced claim-boundary/evidence badges from manifest metadata, skipped
  snapshots, sidecars, and observations when present.
- If parity or observation artifacts are loaded, show discrepancy summaries as
  artifact/operator evidence only, not production validation.
- Preserved the surface slice diagnostics as viewer-derived surface-node
  summaries, not cross-section integration, imported parity, or physical
  validation evidence.
- Maintained desktop/mobile browser-smoke evidence for nonblank canvas rendering
  and non-overlapping controls. Re-run browser smoke for any visual layout,
  scene, control, or manifest-loading change.

Validation:

```bash
cd packages/stenotic-hemodynamics-viewer
npm run validate-demo
npm run typecheck
npm run build
npm run test:browser
cd /Users/doe/hemodynamics/masters-report
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, SHA, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_helpers.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_visualization.jl")'
pipenv run ops-experiment visualization --help
git diff --check -- packages/stenotic-hemodynamics-viewer packages/stenotic-hemodynamics public/docs
```

### Lane 10C-P: Native FSI Phase Timing Before Numerics Optimization

Status: instrumentation implemented as package code in `d52dcb1`; current
Wave 1 and Wave 2 timing reviews complete. The preproduction attempt was
naturally classified as incomplete at step 40/1000. Subsequent long `sev23`
launches are not waiting on an unresolved reuse decision, but remain scoped to
deliberately scheduled compute under the accepted no-reuse baseline or to a
future assembly-specific optimization lane with validation.

Objective: instrument before changing numerics so future preproduction and
production launches report where wall time and memory are spent. The current
process-level sampling suggested sparse direct factorization may be hot; the
production sidecars now split Gridap model setup, FE-space setup, measure
setup, affine-operator construction, matrix extraction, RHS extraction,
symbolic factorization, numeric factorization, backsolve, wall-pressure
sampling, wall update, diagnostics, checkpoint, output, and total-step timing.
They also record matrix/RHS fingerprints and explicit rebuild/reuse status.

Implemented first patch:

- Add phase timers only. Emit per-step and aggregate phase timing fields to
  `batch_status.jsonl`, `batch_status.csv`, and `batch_benchmark.json`.
- Emit instrumentation-only solver diagnostics:
  `gridap_rebuild_status="rebuild_unconditionally_current_path"`,
  `gridap_reuse_status="reuse_not_attempted_instrumentation_only"`, matrix
  dimensions/nnz, sparse-structure digest, matrix-value digest, RHS digest,
  pressure policy, inlet/outlet boundary mode, wall-boundary mode, `dt_s`,
  time-step index, Picard iteration, linear solve count, and rebuild count.
- Preserve physics, boundary conditions, discretization, pressure gauge, wall
  model, coupling semantics, observation operators, artifact filenames, and
  restart/importer schemas.
- Validate on tiny smoke/development runs before any new long preproduction
  launch.

Completed timing review:

1. A cheap current-HEAD pilot was run through the internal Julia production
   runner on the tiny production path, and the generated sidecar paths are
   preserved in the current planning artifact above.
2. `batch_status.jsonl`, `batch_status.csv`, and `batch_benchmark.json` were
   parsed for Gridap lifecycle and fingerprint fields.
3. The dominant measured phase was first-use Gridap lifecycle/setup and
   affine-operator construction. The warmed second step did not show repeated
   factorization or backsolve cost at a scale that justifies reuse work.
4. Matrix sparse structure stayed stable across the two steps, but matrix and
   RHS values changed. This is useful invariant evidence for a future
   representative review, not enough to ship reuse now.
5. Do not implement a cache or solver optimization under the preproduction
   banner from this tiny timing evidence.

Completed Wave 2 warmed timing review:

1. The `12x2x12` four-step pilot on `ab258bc` confirmed a repeated warm-step
   cost after first-use setup.
2. Warm steps were dominated by affine-operator assembly; numeric
   factorization was secondary; backsolve, matrix/RHS extraction, and
   model/space/measure setup were not the main repeated costs.
3. Sparse structure was stable, but matrix values and RHS changed each step.
   This blocks numeric factorization reuse for the current path.
4. Symbolic setup was effectively zero in the timing sidecars, so
   symbolic/permutation reuse is not a measured priority for this workload.
5. Gridap context setup is already small on warm steps; a context-cache patch
   would not address the dominant repeated phase observed here.
6. No Wave 2 solver patch is accepted in this pass. Keep the optimization
   path design-only until an assembly-specific proposal preserves all
   changing-state invariants and compares outputs against the current direct
   baseline.

Future measured optimization dispatch after assembly-specific design:

1. Start with an assembly-specific design that identifies which parts of the
   Gridap affine-operator construction are invariant under changing geometry,
   Picard/advection state, wall/inlet boundary values, pressure policy, and
   constrained DOF maps.
2. Reuse the linear solve/factorization object only when the matrix, coefficients,
   boundary-condition sparsity pattern, pressure policy, mesh topology, and
   constrained DOF maps are unchanged and only the RHS changes.
3. If coefficients change but sparsity is stable, evaluate symbolic/permutation
   reuse with fresh numeric factorization.
4. If assembly changes sparse structure, stabilize connectivity, sparsity
   pattern, row/column maps, constrained DOF maps, and boundary operators before
   changing solver algorithms.
5. Consider Krylov plus reusable preconditioners only after the direct-solve
   baseline is instrumented and reuse boundaries are tested.
6. Consider parallel sparse direct solvers only after algorithmic reuse is
   addressed; dependency changes are not the first response to repeated
   refactorization.

Acceptance criteria:

- Timing sidecars prove the dominant phase before optimization lands.
- Any factorization reuse is gated by explicit invariants and fails closed when
  those invariants change.
- Any Gridap context reuse is gated by explicit mesh topology, coordinate
  state, FE order, boundary tags, pressure-space policy, wall-boundary mode,
  inlet/outlet mode, `dt_s`, and Picard-form invariants.
- Optimized tiny/development outputs compare against the current direct-solve
  baseline before another long `sev23` preproduction launch.
- Faster execution never upgrades production parity or moving-wall/ALE fidelity
  claims. The promoted Section 4.1 comparison claim belongs to the separate
  source-artifact `canic-replication section41` workflow.

### Lane 11 Follow-Up: Mathematical Contract Stewardship

Status: implemented for the current P1 maintenance wave. Reopen only if a
regression appears in FEM-01 through FEM-05, GEOM-01, OBS-01 through OBS-03,
MODEL-01, MODEL-02, or FSI-01.

Priority: closed for this wave. This lane remains a claim gate for future
manuscript-facing reproduction language.

Objective: keep the native resolved-FSI mathematical contract, geometry,
observation operators, model names, and status language aligned while the
batch-safe runner is used for Section 4.1 evidence.

Completed P0 items in `2a54a06`:

- FEM-01: density-consistent transient/convection terms in
  `native_resolved_fsi_gridap.jl`.
- FEM-02: symmetric-gradient Newtonian Cauchy viscous form for exact-mode
  zero-traction language.
- FEM-03: boundary-aware pressure-space policy: smoke pressure-drop uses the
  additive-nullspace zero-mean constraint; exact Poiseuille/natural-traction
  mode uses no Gridap zero-mean pressure constraint.
- FEM-04: membrane wall forcing uses raw physical wall-pressure samples;
  outlet-gauge normalization is diagnostic/export-only and is validated in
  restart metadata.
- GEOM-01: exact Canic geometry is unified for native cases and imported
  case labels `77`/`60`.
- OBS-01: radial profile audit uses same axial cuts as section observations and
  reports explicit closure classifications.

Implemented P1 items in the current integration round:

- FEM-05: quadrature sensitivity and backflow/open-boundary diagnostics were
  added for the native Navier-Stokes adapter.
- OBS-02: the radial-coordinate convention and excluded-area policy used by
  radial-bin observations are documented and tested.
- OBS-03: canonical `reconstructed_axial_velocity(...)` terminology was added,
  with `radial_profile_velocity(...)` retained as a deprecated compatibility
  alias.
- MODEL-01: `ClassicalParabolicOneDModel` was added as the canonical model
  name, with `ClassicalNoSlip1DModel` and the current CLI alias retained as
  deprecated compatibility surfaces.
- MODEL-02: `diagnostic_pressure(...)` and `evolution_pressure(...)` split the
  ambiguous pressure conventions, with `pressure(...)` retained as a deprecated
  diagnostic-pressure alias.
- FSI-01: the current native path is classified as repeated deformed-domain
  fluid solves with a reduced membrane update, not monolithic ALE.

Compatibility boundary:

- `ClassicalNoSlip1DModel`, `classical-1d-no-slip`, `radial_profile_velocity`,
  and `pressure(...)` remain deprecated compatibility surfaces where existing
  callers require them.
- Canonical new surfaces are `ClassicalParabolicOneDModel`,
  `classical-parabolic-1d`, `reconstructed_axial_velocity(...)`,
  `diagnostic_pressure(...)`, and `evolution_pressure(...)`.
- Resolved3D output labels now use axial/reconstructed-axial terminology for
  observation quantities.

Acceptance criteria:

- Status strings and dry-run/CLI/parity rows continue to distinguish
  mathematical-contract support from production execution, imported parity, and
  native resolved-FSI reproduction.
- The integrated mathematical-contract suite covers density scaling, traction
  form, pressure-space policy, wall-load convention, global mass balance, exact
  case geometry, and radial area/flow closure classification.
- Existing smoke, workflow, parity, public API, and extension-contract tests
  remain green or are updated with explicit, bounded claim-language changes.
- Public/docs and report synchronization occurs only after package tests land;
  report files remain under editorial ownership.

Validation:

- `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using StenoticHemodynamics; println("loaded")'`
- `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl"); include("packages/stenotic-hemodynamics/test/test_scalar_generality.jl"); include("packages/stenotic-hemodynamics/test/test_cli_studies.jl")'`
- `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics, HDF5; include("packages/stenotic-hemodynamics/test/test_resolved3d_geometry.jl")'`
- `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics, HDF5; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl"); include("packages/stenotic-hemodynamics/test/test_extension_contracts.jl")'`
- `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics, HDF5; include("packages/stenotic-hemodynamics/test/test_extension_contracts.jl")'`

### Lane 10C Follow-Up: Sev23 Preproduction Batch Execution

Status: open as a scheduled long-running compute lane. Current-source
dry-run/status evidence is refreshed; actual preproduction execution and
imported parity remain unrun.

Priority: P0 next execution gate. This lane is still P0 relative to any native
reproduction claim; current package integration clears the mathematical-
contract and restart/resume prerequisites at focused package scope, but
production evidence still requires actual execution and parity review.

Objective: use the batch-safe runner to execute the exact-boundary `sev23`
preproduction gate from
`public/docs/stenotic-hemodynamics/section-4-1-production-validation-plan.md`
without broadening numerical semantics or bypassing Lane 11.

Recommended dispatch order:

1. Confirm `2a54a06` remains in the baseline and no Lane 11 P0 regression is
   present. If any mathematical-contract item reopens, stop and keep this lane
   as dry-run/planning only.
2. Start from the completed status-only dry-run matrix. Refresh it only if
   case parameters, guard policy, imported-data roots, or output schedules
   change.
   The latest current-source dry-run for the `sev23` preproduction plan
   reported production spec digest `9d1cfb96eb525113`, 1000 estimated time
   steps, expected fluid-solve upper bound 1001, estimated runtime 63000 s, no
   required override flags, passing snapshot/payload guards, and imported case
   `77` available.
3. Treat the `sev23` full development gate (`tfinal_s=1e-2`) as completed for
   artifact readiness, with the explicit caveat that one-iteration coupling
   was bounded but not converged. Diagnostics must continue to report the
   failing station, pressure load, radius, mass/stiffness/damping, stability
   scale, wall-boundary handoff mode, coupling status, and deformed-mesh
   cell/volume details when mesh orientation fails.
4. Launch the exact-boundary `sev23` preproduction gate with the batch-prep
   sidecars enabled. Validate finite fields, wall displacement, pressure
   normalization, importer round-trip, `batch_status.*`,
   `batch_benchmark.json`, restart/checkpoint metadata, observation rows, and
   stronger coupling settings or explicitly bounded coupling status. The
   development gate took about 25 minutes at 9,600 tetrahedra for `T=0.01`;
   the `(80, 4, 24)`, `T=0.1` preproduction run is expected to be many hours
   and the current-source dry-run estimates about 63000 s. It must be
   scheduled as long-running compute work, not assumed interactive.
5. Execute the full case set at the production target mesh
   `(axial=120, radial=5, angular=32)`, `dt_s=1e-4`, `T=1.0 s`, final snapshot
   only, with `u_max=45 cm/s` and
   `:poiseuille_inlet_zero_outlet_stress_section41`.
6. Run imported-data parity as a separate skip-safe lane. `sev23` maps to
   imported case `77`, `sev40` maps to `60`, and `sev50` remains expected-skip
   unless a bundle is explicitly supplied.
7. Send the manuscript owner a claim-readiness handoff only after the roadmap
   gates pass; do not edit report/manuscript files from package lanes.

Validation is lane-specific. At minimum, start with dry-run/status output and
run `git diff --check` on any touched docs or package files.

### Lane 10D Follow-Up: Restart Resume Stewardship

Status: implemented at package-internal smoke/operator scope. Public/default
resume, CLI exposure, production-scale resume validation, imported-parity
resume coverage, and manuscript claim promotion remain future work.

Priority: closed for this implementation wave; reopen only for the explicitly
remaining future-work items above.

Objective: steward the implemented restart/resume boundary in
`public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`
while preserving fail-closed behavior for legacy audit metadata and public
callers.

Implemented:

1. Schema-v1 audit metadata and schema-v2 checkpoint-manifest validation
   remain readable and fail-closed.
2. Schema-v3 durable checkpoint sidecars now cover wall state, mesh identity,
   fluid-state/restart representation, coupling state, cursor state, and
   output linkage. Node-centered XDMF/HDF5 output bundles remain observation
   artifacts, not the checkpoint source by themselves.
3. The qualified internal resume runner validates the checkpoint, reconstructs
   state, and continues from the next pending snapshot into a forked output
   root.
4. Tests cover metadata validation, sidecar ownership/checksum failures,
   non-forked output-root rejection, exact-boundary status, public fail-closed
   resume, and split-run/resume smoke-scale execution.
5. Public docs and this TODO now record the boundary. Preserve the Section 4.1
   claim boundary: restart support does not imply paper-grade reproduction,
   production-scale parity, or monolithic ALE FSI.

Remaining future work:

- broaden numerical equivalence against uninterrupted runs across more cases
  and schedules;
- add imported-parity skip-safe resume coverage when optional upstream bundles
  are present or absent;
- validate production-scale resume behavior on long `sev23` runs;
- review any public API or CLI exposure in a separate lane.

`native_resolved_fsi_resume_partitioned_production(...)` must keep validating
metadata and failing closed for public callers until such a lane explicitly
changes that contract.
