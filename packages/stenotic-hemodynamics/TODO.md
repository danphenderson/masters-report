# StenoticHemodynamics Authoritative Fleet TODO

Date: 2026-06-23

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
  `state_payload` remains versioned audit metadata, and persisted resume
  remains fail-closed.
- Lane 10D-1 restart schema boundary: production metadata now writes explicit
  schema-v1 audit fields, legacy metadata without `restart_schema_version`
  remains readable, schema-v2 checkpoint-manifest metadata is shape-validated,
  and `resume_supported=true` remains rejected until durable FE-state
  serialization and a reconstruction runner land.
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

## Non-Negotiable Claim Boundary

- Exact Section 4.1 boundary-mode support exists in the low-level Gridap path
  and in the tiny partitioned production smoke-scale harness.
- This is not paper-grade Section 4.1 numerical reproduction, not validated
  parity against imported external data, and not monolithic ALE FSI.
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
- Restart `state_payload` is audit metadata only; persisted restart/resume is
  unsupported and fail-closed.
- CLI/status surfaces must continue to expose these boundaries and must not
  imply paper-grade reproduction.
- Status strings such as `exact_section41`,
  `implemented_smoke_validated`, and `zero_outlet_stress_natural_traction`
  remain implementation/status labels. After `2a54a06`, they are backed by the
  focused mathematical-contract tests, but they still do not imply
  production-scale execution, imported parity, moving-wall/ALE fidelity, or
  manuscript-grade Section 4.1 reproduction.
- Native resolved-FSI production arrays and Gridap adapter surfaces remain
  `Float64`-oriented unless a future lane explicitly generalizes them. Local
  scalar helpers should avoid unnecessary downcasts when they can preserve
  `AbstractFloat` values safely.
- Manufactured-solution MMS observed orders are discrete metric-specific
  verification evidence only. They do not establish physical validation,
  resolved-FSI parity, or manuscript-grade Section 4.1 reproduction.
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
- The partitioned Navier-Stokes pressure space now uses a Gridap zero-mean
  pressure constraint and records `pressure_nullspace_status` through dry-run,
  `fsi native-status`, diagnostics, and restart metadata. Scratch probing
  showed this is pressure-gauge hygiene only: it did not reduce the exact-mode
  wall-pressure/load scale and is not accepted as wall-stability remediation.
- The partitioned wall update now has a fail-fast pressure-load plausibility
  gate that predicts radius inversion before mutating wall state and reports
  the semi-implicit displacement increment used by the current reduced wall
  step.
- Lane 10D records the persisted restart/resume design in
  `public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`.
  Schema-v1 audit metadata and schema-v2 checkpoint-manifest reader boundaries
  are implemented. Current `state_payload` remains audit metadata, and resume
  remains fail-closed until durable wall/mesh/FE-state serialization, a
  reconstruction runner, sidecar ownership, and split-run equivalence tests
  land.
- Lane 10C batch-prep is implemented for preproduction launch readiness.
  Dry-run/status output now includes estimated time steps, a conservative fluid
  solve upper bound, status/benchmark/failure sidecar paths, checkpoint roles,
  and a production spec digest. The full `sev23` preproduction solve has not
  been launched or validated.
- The first `sev23` preproduction evidence attempt at `(80, 4, 24)`,
  `dt_s=1e-4`, `T=0.1` stopped without completion artifacts after reaching
  step 40/1000. Treat its sidecars as incomplete runtime diagnostics only.

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

## Remaining Dispatch Priority

## Next-Round Concurrency Plan

Wave 1 can run concurrently if write locks stay disjoint:

- Lane 10C-P1 timing-sidecar review: run or inspect a tiny/development native
  FSI pilot on `d52dcb1` or newer, then classify whether wall time is dominated
  by Gridap lifecycle setup, matrix/RHS extraction, symbolic factorization,
  numeric factorization, backsolve, wall sampling/update, diagnostics, or
  output. This is read-only unless an instrumentation bug is found.
- Lane 12C focused test hardening follow-up if any remaining test-quality
  audit items reopen outside the already-landed membrane/Python benchmark
  hardening.
- Lane 12D viewer visual diagnostics follow-up:
  `packages/stenotic-hemodynamics-viewer/**`, visualization docs, and
  visualization tests only. The serve-command docs are already landed; future
  work should expand displayed scientific/operator diagnostics.

Wave 2 starts after Wave 1 handbacks:

- Lane 10C-P2 native-FSI measured optimization only if timing sidecars prove
  repeated Gridap lifecycle, assembly, matrix/RHS extraction, or
  factorization cost and explicit invariants can gate reuse. Start with a
  Gridap-context/factorization-invariant design; do not change solver physics.
- Lane 11 P1 mathematical-contract stewardship if it touches disjoint
  observation/model/API files from any optimization lane.

Wave 3 starts only after timing/optimization evidence is accepted:

- `sev23` preproduction batch execution and imported parity staging. Do not
  relaunch long runs before the instrumentation review and any accepted
  measured optimization lane complete.

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

Status: largely implemented in `a8aa77b`. Keep this lane open only for newly
identified non-vacuity issues from future audits.

Priority: P2 unless a test failure reopens it.

Objective: address the remaining non-vacuity improvements identified by the
read-only test-quality audit without broadening into speculative test churn.

Remaining targets, only if reopened:

- Strengthen `test_membrane_fsi.jl` dynamic membrane validation so
  wall-velocity maxima are asserted nonzero and agree with written history or
  profile rows.
- Strengthen `packages/ops/tests/test_python_package_benchmark.py` with
  nonempty rendered artifact and key numeric/stage-count assertions.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_membrane_fsi.jl")'
pipenv run pytest packages/ops/tests/test_python_package_benchmark.py
pipenv run ruff check packages/ops/tests/test_python_package_benchmark.py
pipenv run black --check packages/ops/tests/test_python_package_benchmark.py
git diff --check -- packages/stenotic-hemodynamics/test/test_membrane_fsi.jl packages/ops/tests/test_python_package_benchmark.py
```

### Lane 12D: Viewer Evidence Enhancements

Status: baseline viewer evidence controls landed in `a8aa77b`; serve-command
docs landed in `cf2d78c`. Remaining work is visual diagnostic expansion only.

Priority: P2 nonblocking visualization lane. Do not let this collide with
native-FSI numerics, report PDF, or package validation-automation work.

Objective: expand displayed visual diagnostics after the coordinate-mode and
browser-smoke fixes are accepted, while preserving the evidence boundary that
viewer artifacts are inspection/operator aids.

Targets:

- Keep `coordinate_mode` semantics explicit so reference/deformed geometry is
  never double-applied.
- Add or polish manifest-backed toggles for velocity magnitude, pressure, and
  displacement magnitude, with missing fields disabled cleanly.
- Add a colorbar with min/max ticks, units, and current/global range labeling.
- Surface claim-boundary/evidence badges from manifest metadata, skipped
  snapshots, sidecars, and observations when present.
- If parity or observation artifacts are loaded, show discrepancy summaries as
  artifact/operator evidence only, not production validation.
- Maintain desktop/mobile browser-smoke evidence for nonblank canvas rendering
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

Status: implemented as instrumentation-only package code in `d52dcb1`. The
preproduction
attempt was naturally classified as incomplete at step 40/1000, so subsequent
long `sev23` launches are blocked on reviewing phase sidecars and deciding
whether a measured optimization lane is justified.

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

Next timing review dispatch:

1. Run a cheap current-HEAD pilot through `ops-experiment` on the tiny
   production path and preserve the generated summary JSON and sidecar paths
   in the handback.
2. Parse `batch_status.jsonl`, `batch_status.csv`, and
   `batch_benchmark.json` for the new Gridap lifecycle/fingerprint fields.
3. Classify the dominant measured phase and whether repeated matrix
   structure/value digests prove a reuse opportunity.
4. If the dominant cost is first-call/precompile/setup overhead only, do not
   implement a cache under the preproduction banner; document the launch
   planning implication instead.
5. If repeated per-step lifecycle/assembly or factorization is dominant,
   proceed to the measured optimization dispatch below.

Measured optimization dispatch after timing evidence:

1. Reuse the linear solve/factorization object when the matrix, coefficients,
   boundary-condition sparsity pattern, pressure policy, mesh topology, and
   constrained DOF maps are unchanged and only the RHS changes.
2. If coefficients change but sparsity is stable, evaluate symbolic/permutation
   reuse with fresh numeric factorization.
3. If assembly changes sparse structure, stabilize connectivity, sparsity
   pattern, row/column maps, constrained DOF maps, and boundary operators before
   changing solver algorithms.
4. Consider Krylov plus reusable preconditioners only after the direct-solve
   baseline is instrumented and reuse boundaries are tested.
5. Consider parallel sparse direct solvers only after algorithmic reuse is
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
- Faster execution never upgrades production parity, moving-wall/ALE fidelity,
  or manuscript-grade Section 4.1 reproduction claims.

### Lane 11 Follow-Up: Mathematical Contract Stewardship

Priority: P1 maintenance after `2a54a06`, unless a regression reopens any
FEM-01 through FEM-04, GEOM-01, or OBS-01 contract item. This lane remains a
claim gate for manuscript-facing reproduction language.

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

Required P1 items:

- FEM-05: add quadrature sensitivity and backflow/open-boundary diagnostics for
  the native Navier-Stokes adapter.
- OBS-02: document and test the radial-coordinate convention and excluded-area
  policy used by radial-bin observations.
- OBS-03: rename current `radial_profile_velocity` surfaces to axial or
  reconstructed axial velocity terminology so the observation name matches the
  quantity.
- MODEL-01: rename `ClassicalNoSlip1DModel` to
  `ClassicalParabolicOneDModel`, keeping the current CLI alias deprecated and
  tested for compatibility.
- MODEL-02: split the ambiguous `pressure()` API into evolution-pressure and
  diagnostic-pressure conventions.
- FSI-01: classify the current native path as repeated deformed-domain fluid
  solves with a reduced membrane update, not monolithic ALE.

Acceptance criteria:

- Status strings and dry-run/CLI/parity rows continue to distinguish
  mathematical-contract support from production execution, imported parity, and
  manuscript-grade reproduction.
- The integrated mathematical-contract suite covers density scaling, traction
  form, pressure-space policy, wall-load convention, global mass balance, exact
  case geometry, and radial area/flow closure classification.
- Existing smoke, workflow, parity, public API, and extension-contract tests
  remain green or are updated with explicit, bounded claim-language changes.
- Public/docs and report synchronization occurs only after package tests land;
  report files remain under editorial ownership.

Validation:

- Start with `pipenv run ops-orchestrate status --json`.
- Run focused Julia tests for every touched surface, including
  `test_native_resolved_fsi_smoke.jl`,
  `test_native_resolved_fsi_workflow.jl`,
  `test_native_resolved_fsi_parity.jl`, `test_public_api.jl`, and
  `test_extension_contracts.jl` when status/API/dependency boundaries move.
- Add or update dedicated mathematical-contract tests for FEM-01 through
  FEM-04, GEOM-01, and OBS-01.
- Run `git diff --check -- packages/stenotic-hemodynamics public/docs`.

### Lane 10C Follow-Up: Sev23 Preproduction Batch Execution

Priority: P0 next execution gate. This lane is still P0 relative to any native
reproduction claim; `2a54a06` clears the mathematical-contract prerequisite at
focused test scope, but production evidence still requires actual execution and
parity review.

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
   and must be scheduled as long-running compute work, not assumed
   interactive.
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

### Lane 10D Follow-Up: Restart Resume Implementation

Priority: P1 after 10C planning and before any resume claim.

Objective: implement the staged design in
`public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`
while preserving the current fail-closed behavior for legacy audit metadata.

Recommended dispatch order:

1. Treat schema-v1 audit metadata and schema-v2 checkpoint-manifest validation
   as landed. Do not add public exports or CLI resume commands.
2. Add durable wall, mesh, FE fluid, coupling, and cursor state
   serialization. Node-centered XDMF/HDF5 output bundles are not enough for
   exact solver resume.
3. Implement a qualified-internal resume runner that validates the checkpoint,
   reconstructs state, and continues from the next pending snapshot without
   exposing production resume through default CLI paths.
4. Add metadata, serialization, split-run/resume, sidecar ownership, exact
   boundary status, and skip-safe imported parity tests.
5. Update public docs and editorial handoff text only after implementation and
   tests land. Preserve the Section 4.1 claim boundary: persisted restart does
   not imply paper-grade reproduction or monolithic ALE FSI.

Until then, `native_resolved_fsi_resume_partitioned_production(...)` must keep
validating metadata and failing closed.
