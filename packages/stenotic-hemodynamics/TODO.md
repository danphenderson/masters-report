# StenoticHemodynamics Fleet TODO

Date: 2026-06-22

This file is the forward-looking dispatch plan for the next supervised fleet
round in `packages/stenotic-hemodynamics`. It is grounded in the clean local
`master` checkout on 2026-06-22 and treats the current split package surfaces
as the starting point for new work.

## Baseline Preflight

The audit immediately before this TODO update found the local checkout on
`master` at `f2e7e2254a43417ff2cedf19d97c89d83f09bc8a`, with no local `main`
branch. Treat that as a recorded observation, not as permission to ignore branch
requirements in the next round.

Before assigning background workers, the orchestrator for
`019ef0fb-4b63-7f43-9874-0c63aa9378ab` must:

1. Run `pipenv run ops-orchestrate status --json`.
2. Record `git status --short --branch`, `git rev-parse HEAD`, and
   `git branch --list main master`.
3. Confirm whether the fleet is meant to run on the observed local branch or on
   a required `main` branch.
4. Stop before edits if `main` is still absent and the round must run on `main`;
   resolve branch setup first, then restart the preflight.

## Current Baseline

- Local authority for this document is the observed `master` checkout from the
  preflight above.
- The package remains reduced-1D-first. Native resolved-FSI work is additive
  research infrastructure and must not blur the current 1D/public-facing scope.
- The resolved-3D importer already supports companion pressure/displacement XDMF
  paths and deformed-coordinate observation. Velocity-only bundles remain
  supported as a compatibility mode for imported legacy data, not as the target
  output of the new native generator.
- Current split surfaces such as `cli/cli.jl`, `numerics/solver.jl`,
  `workflows/resolved3d_types.jl`, `workflows/resolved3d_compare.jl`,
  `workflows/resolved3d_outputs.jl`, and `io/waveforms.jl` are landed and
  should be treated as stable include targets.
- Scalar-generic footholds now exist in config types, typed caches, and local
  kernels, but the main solver/runtime remains largely `Float64`.

## Fleet Rules

- Start implementation with `pipenv run ops-orchestrate status --json` and use
  the live tree as authority.
- Use one writer per disjoint file set. Multiple writers may run concurrently
  only when their owned paths do not overlap.
- If a lane discovers that it needs files outside its initial lock, the agent
  must stop and request scope expansion. The orchestrator decides whether to
  approve, redirect, or defer it.
- Do not delete an existing include target during a split. Convert the original
  file into an always-present aggregator first, then add included files.
- Every code lane owns docstrings and comments in its assigned files. Agents
  must check whether existing docstrings are accurate and update stale wording.
- Do not repeat another agent's validation by default. Review the diff, accept
  focused validation when it matches the touched scope, and run broader gates
  only once at a round boundary or when review finds a concrete risk.
- Optional resolved-3D data under `public/var/data/simulations/**` may be
  absent. Tests for importer/writer behavior should use generated fixtures unless
  a lane explicitly requires local external data.
- Preserve all public CLI command names, option names, stdout keys, file names,
  CSV/Tex/HDF5/XDMF schemas, and numerical algorithms unless a lane explicitly
  widens scope.
- The native resolved-FSI generator target schema for this round is
  `velocity + pressure + displacement`; deformed coordinates must load from the
  displacement field. Velocity-only bundles are a compatibility mode for
  imported legacy data and do not satisfy the new-generator acceptance criteria.
- Preserve the existing importer contract as authoritative unless a writer
  round-trip test exposes a concrete bug.
- Only the orchestrator, Lane 2A, and Lane 2D may edit this TODO file.
  Implementation workers should report handbacks instead of independently
  revising the plan.
- Every worker handback must list touched files, validation commands and
  results, skipped optional inputs, blockers or unknowns, public API/schema
  changes, and whether the next dependent lane is ready to start.

## Step 1: Boundary Gate And Remaining Concentration Points

Start the round with one boundary gate, then treat the remaining large-file list
as a constraint on later split work rather than as a new cleanup campaign.

### Lane 1B: Round Boundary Sanity Check

Objective: verify the current package boundary once, without duplicating every
agent lane.

Owned write scope:

- None unless a concrete failure is found.

Implementation:

1. Run `git diff --check -- packages/stenotic-hemodynamics`.
2. Run a package-load smoke:

   ```bash
   packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using StenoticHemodynamics; println("package-load-ok")'
   ```

3. Run `pipenv run ops-julia-check` only once if the orchestrator wants a full
   round-boundary gate after reviewing the focused handbacks.
4. If the gate fails because optional external resolved-3D data are missing,
   record the expected skip. Do not treat absent ignored data as a source
   failure.

Acceptance:

- No whitespace errors.
- Package load succeeds.
- Any full-gate failure is either fixed in-scope or recorded with exact command
  output and file ownership.

### Remaining Large-File Note

These are still the main concentration points. Do not split them opportunistically
during Step 2. Split work belongs to Step 3 and only when it directly enables
the active roadmap with disjoint file ownership.

- `numerics/dg.jl` around 600 lines.
- `workflows/benchmark_stage_rows.jl` around 490 lines.
- `numerics/solver_fluxes.jl` around 450 lines.
- `adapters/stokes_ic.jl` around 420 lines.
- `workflows/verification_mms.jl` and `verification_ph_refinement.jl` around
  400 lines each.
- `workflows/resolved3d_compare_rows.jl` around 380 lines.
- `core/rheology.jl`, `core/diagnostics.jl`, `adapters/openbf_protocol.jl`, and
  `adapters/resolved3d_io.jl` remain medium-large.

## Step 2: Native Resolved-FSI Generator Roadmap

Objective: add a Julia-native resolved-FSI generator that can produce velocity,
pressure, and displacement XDMF/HDF5 data for the paper's Section 4.1 benchmark
cases, reload those fields through the package importer, and compare them
against imported external fields through the existing resolved-3D observation
workflow.

This is additive. The existing importer remains valid and important. Importer
and adapter work should be treated as a supported project goal, not as temporary
scaffolding. The native generator must write data compatible with the same
importer and parity harness.

The next-round native surface must obtain, write, reload, and compare velocity,
pressure, and displacement. Imported velocity-only bundles remain valid for
legacy/external comparison cases, but they are not a successful output target
for the new native generator lanes.

Interpret "native Julia" as no MATLAB or external paper codebase dependency.
Backend choice remains intentionally open until Lane 2D locks it.

### Lane 2A: Exact Section 4.1 Reproduction Spec

Agent type: read-mostly planner with a small documentation patch.

Owned write scope:

- `packages/stenotic-hemodynamics/TODO.md`
- optional new package doc, for example
  `packages/stenotic-hemodynamics/docs/native_resolved_fsi_reproduction.md`

Inputs:

- `public/references/02_report_model_hierarchy/2024_canic_extended_1d_stenotic_artery_model.pdf`
- Existing resolved-3D comparison defaults under `resolved3d_types*`.
- README scope language.

Implementation:

1. Extract the exact Section 4.1 benchmark cases: case identifiers, stenosis
   severity, geometry, units, fluid constants, wall constants, inflow/outflow
   data, target times, stored variables, and expected comparison observables.
2. Produce a case/spec table that marks every required value as explicit,
   inferred, or unknown.
3. Map the paper variables to package units and names, including target times,
   field names, pressure and displacement requirements, and comparison
   observables.
4. Classify every unknown as either a blocker or a documented non-blocker.
   Unknowns must not remain as placeholder TODO text for implementation agents.
5. Define acceptance tiers:
   - schema parity: generated HDF5/XDMF loads through the existing importer;
   - geometry parity: mesh/domain sections match the analytic stenosis profile;
   - time parity: stored times and importer tolerances match the Section 4.1
     case spec;
   - field parity: velocity, pressure, and displacement fields exist and meet
     documented tolerances;
   - operator parity: existing section/radial observation workflow runs and
     reports discrepancies separately from raw field differences.

Validation:

- Documentation review against the PDF and local code only.
- No generated data required.

Acceptance:

- The next implementation agents can work from concrete case specs rather than
  re-reading the paper independently.
- The case/spec table includes explicit/inferred/unknown values, units mapping,
  target times, field names, pressure and displacement requirements, and
  comparison observables.
- Any missing Section 4.1 value is marked as a blocker or documented non-blocker.

Lane 2A handback recorded on 2026-06-22:

- Exact Section 4.1 reproduction spec is now locked in
  `packages/stenotic-hemodynamics/docs/native_resolved_fsi_reproduction.md`.
- 2B may start from the paper geometry now, but it must treat the `23%` case
  as an explicit `Rmin = 0.1394 cm` / `delta_r = 0.0406 cm` override instead
  of a plain `Params(severity=23)` shorthand.
- 2C may start from the local importer contract now: shared tetrahedral
  geometry/topology plus node-centered `velocity + pressure + displacement`
  XDMF/HDF5 files, with native benchmark snapshots written at `T = 1.0 s`.
- No blocker unknowns remain for 2B or 2C.
- Remaining non-blockers for later lanes are recorded in the doc above:
  exact tetrahedral meshing recipe, volumetric displacement-field convention,
  paper-side pressure tolerance, the exact constant `R0*` choice in `C0`, and
  any legacy external case label for a `50%` imported bundle.

### Lane 2B: Native Stenotic Tube Mesh and Boundary Tags

Agent type: implementation worker.

Owned write scope:

- New files under `src/StenoticHemodynamics/adapters/` or
  `src/StenoticHemodynamics/workflows/` with prefix
  `native_resolved_fsi_mesh*`.
- New focused test file, for example `test/test_native_resolved_fsi_mesh.jl`.
- `test/runtests.jl` only to include the new test.

Implementation:

1. Build a Julia-native stenotic tube domain generator using the package's
   existing stenosis profile and units.
2. Produce a backend-agnostic mesh/domain contract with stable boundary tags for
   inlet, outlet, wall, and interior.
3. Expose deterministic mesh parameters and geometry metadata for axial, radial,
   and angular resolution.
4. Add geometry tests for section area, radius profile, length, boundary tags,
   and deterministic node/cell counts.
5. Keep this lane independent of the Navier-Stokes/membrane solver. Do not
   hard-code Gridap or another backend here before Lane 2D locks that decision.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_mesh.jl")'
```

Acceptance:

- Mesh/domain generation is deterministic, backend-agnostic at the contract
  level, and can be consumed by later solver and writer lanes.
- If a backend-specific adapter is required later, this lane leaves that adapter
  as a thin follow-on boundary instead of implementing it here.

Lane 2B handback recorded on 2026-06-22:

- `workflows/native_resolved_fsi_mesh.jl` now provides the backend-agnostic
  Section 4.1 case, geometry, mesh, and boundary-tag contract.
- The `sev23` case uses the explicit paper override
  `Rmin = 0.1394 cm` / `delta_r = 0.0406 cm` instead of the generic
  `23% * Rmax` shorthand.
- Focused validation passed for
  `test/test_native_resolved_fsi_mesh.jl`.
- Small deterministic smoke mesh `sev23`, `axial=2`, `radial=2`, `angular=8`
  has `51` nodes, `144` tetrahedra, `24` inlet faces, `24` outlet faces, and
  `32` wall faces.
- Lane 2D, 2E, and solver/writer follow-ons may consume this mesh contract.

### Lane 2C: XDMF/HDF5 Writer Compatible With Importer

Agent type: implementation worker.

Owned write scope:

- New writer files, for example
  `src/StenoticHemodynamics/adapters/resolved3d_writer.jl` and helper files.
- Existing include file `src/StenoticHemodynamics.jl` only if required.
- New focused tests, for example `test/test_resolved3d_writer.jl`.

Implementation:

1. Add a package-owned production writer adapter for velocity, pressure, and
   displacement fields. This is new package code, not a promotion of the current
   test helper.
2. Write HDF5 datasets and companion XDMF files with paths and attribute names
   accepted by `adapters/resolved3d_io.jl`.
3. Include pressure and displacement even if early solver fixtures use analytic
   placeholder arrays.
4. Add round-trip tests that write a tiny synthetic field bundle, load it with
   `load_resolved3d_field_bundle`, and verify coordinates, connectivity, time
   selection, velocity, pressure, displacement, and deformed-coordinate
   behavior.
5. Preserve the existing importer. Do not rewrite importer behavior unless a
   writer test exposes a real contract bug.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_resolved3d_writer.jl")'
```

Acceptance:

- A generated synthetic resolved-3D fixture round-trips through the same loader
  used for external MATLAB/supplement data.
- `coordinate_mode=deformed` succeeds when displacement is present.
- Velocity-only writer output is not acceptable for this lane except when
  explicitly exercising legacy-compatibility behavior.

Lane 2C handback recorded on 2026-06-22:

- `adapters/resolved3d_writer.jl` now provides
  `Resolved3DWriterPaths`, `Resolved3DWriterResult`, and
  `write_resolved3d_field_bundle(...)`.
- The writer stores shared `mesh.h5` geometry/topology plus node-centered
  `velocity.xdmf/h5`, `pressure.xdmf/h5`, and `displace.xdmf/h5`.
- Round-trip tests require pressure and displacement and verify deformed
  coordinates through the existing importer.
- Focused validation passed for `test/test_resolved3d_writer.jl` after a
  Julia 1.12 compatibility fix to use positional `relpath(...)`.
- Lane 2D, 2E, 2F, and 2G may consume this writer contract.

### Lane 2D: 3D Navier-Stokes Plus Membrane Coupling Design

Agent type: architecture worker only until the design gate is accepted.

Owned write scope for design:

- `packages/stenotic-hemodynamics/TODO.md`
- optional design doc under `packages/stenotic-hemodynamics/docs/`

Start gate:

- Lane 2D may start after Lane 2A records the Section 4.1 requirements. In the
  default dispatch order, it should consume the Lane 2B and 2C contract
  handbacks before the backend/coupling design is locked.

Design requirements:

1. Choose the backend for the first implementation target from local Julia
   options and record why it is the best fit for the round.
2. Choose the minimal first implementation target:
   - fixed-wall smoke;
   - partitioned fluid solve plus membrane update;
   - monolithic weak form;
   - or an explicitly staged surrogate if a full solve is too large for the
     first implementation.
3. Specify the membrane model for an isotropic homogeneous elastic vessel:
   state variables, wall displacement variable, stiffness/mass/damping inputs,
   and coupling terms.
4. Define time integration, boundary conditions, units, stability guards, and
   output-volume guards.
5. Name the first files, structs, workflow entrypoints, tests, and acceptance
   tolerances before solver implementation begins.
6. Define what fields are written at each time step: velocity, pressure, and
   displacement, including any staged treatment of displacement for early smoke
   solves.
7. Identify which existing quasi-static membrane-FSI adapter code can be reused
   and which must remain separate to avoid overstating current capability.

Stop condition:

- If the design cannot choose fixed-wall smoke, partitioned coupling, monolithic
  coupling, or staged surrogate from local evidence, stop with the tradeoff and
  required decision recorded. Do not start solver implementation in this lane.

Acceptance:

- The design names the backend, concrete files, structs, workflow entrypoints,
  tests, stability guards, and acceptance tolerances before numerical
  implementation begins.
- The design explicitly chooses the first implementation target and coupling
  strategy, including any staged displacement treatment for smoke solves.
- No full native resolved-FSI solver lane starts until this design is accepted.

Lane 2D handback recorded on 2026-06-22:

- The implementation-facing design is now locked in
  `packages/stenotic-hemodynamics/docs/native_resolved_fsi_design.md`.
- Backend choice is Gridap on the package-owned `NativeResolvedFSIMesh`
  contract, with a package-owned fixed-step loop instead of a first-pass
  `OrdinaryDiffEq` wrapper.
- The minimal first implementation target is a fixed-wall 3D incompressible
  Navier-Stokes smoke solve. The first coupled follow-on remains partitioned and
  staggered; monolithic moving-wall FSI is explicitly deferred.
- The staged output contract is locked as node-centered
  `velocity + pressure + displacement` at each saved time on the reference
  native mesh, with pressure gauge-normalized at the outlet and displacement set
  to the zero vector during the fixed-wall smoke stage.
- The first coupled-stage displacement convention is a package-owned linear
  radial lift from the axisymmetric wall state into the volume so
  `coordinate_mode=deformed` stays valid through the existing importer.
- Proposed implementation files, structs, workflow entrypoints, tests, and
  first acceptance tolerances are named in the design doc above.
- Stability and output guards are locked: positive `dt`, Picard and coupling
  tolerances, explicit membrane stability limit, positive radius / no inverted
  tetrahedra, finite written fields, and default final-snapshot-only output with
  hard caps on snapshot count and estimated field payload.
- Remaining non-blockers are the later pressure-observation parity helper, the
  exact outlet pressure normalization reduction, and any later replacement of
  the local `R_ref = p.rmax` stiffness choice by a paper-specific `R0*`.
- No blocker remains for Lane 2E or for the first fixed-wall smoke
  implementation lane.

### Lane 2E: Native Generator Workflow Skeleton

Agent type: implementation worker after Lane 2D is accepted.

Owned write scope:

- New prefix `native_resolved_fsi*` under workflows/adapters.
- New focused test file, for example `test/test_native_resolved_fsi_workflow.jl`.
- `test/runtests.jl` only to include the new test.
- CLI files only if the orchestrator explicitly assigns a CLI lane.

Implementation:

1. Add a typed generator spec for Section 4.1 cases and mesh/solver/writer
   options.
2. Add a workflow runner that can generate a tiny synthetic or analytic smoke
   bundle with velocity, pressure, and displacement, write XDMF/HDF5 through
   Lane 2C, and return paths.
3. Reload the bundle through the existing importer and report schema, time, and
   field checks before handing the lane off.
4. Keep public CLI exposure optional until the internal workflow is stable.
5. Make output paths default to ignored scratch locations under
   `tmp/simulations/output/**`.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl")'
```

Acceptance:

- The workflow can produce and reload a tiny three-field XDMF/HDF5 bundle
  without external data and without running a production 3D solve.
- The handback separates schema readiness, geometry readiness, time readiness,
  field readiness, and operator readiness for Lane 2F and Lane 2G.

Lane 2E handback recorded on 2026-06-22:

- `workflows/native_resolved_fsi_workflow.jl` now provides
  `NativeResolvedFSIWorkflowSpec`, `NativeResolvedFSIWorkflowStatus`,
  `NativeResolvedFSIWorkflowResult`, `run_native_resolved_fsi_workflow(...)`,
  and the internal alias `run_native_resolved_fsi(...)`.
- The workflow produces a tiny schema-only three-field bundle from
  `NativeResolvedFSIMesh`, writes through `write_resolved3d_field_bundle(...)`,
  reloads through `load_resolved3d_field_bundle(...; require_pressure=true,
  require_displacement=true)`, and reports schema, geometry, time, field, and
  operator readiness.
- Default output is under
  `tmp/simulations/output/native-resolved-fsi/**`.
- Zero displacement and deterministic synthetic radial-lift modes are available
  for schema testing only; they are not physical FSI claims.
- Focused validation passed for `test/test_native_resolved_fsi_workflow.jl`.
- Lane 2F may start from this skeleton. Lane 2G can use the contract, but full
  parity still requires solver-backed native outputs.

### Lane 2F: Native Solver Smoke, Then Section 4.1 Cases

Agent type: implementation worker.

Owned write scope:

- Native resolved-FSI solver files from Lane 2D/2E.
- Focused native resolved-FSI tests, for example
  `test/test_native_resolved_fsi_smoke.jl`.
- `test/runtests.jl` only to include the new test.

Implementation:

1. Start with the smallest stable smoke target chosen by Lane 2D. If the first
   target is fixed-wall or otherwise staged, still emit explicit displacement
   output consistent with the accepted design so the three-field contract
   remains intact.
2. Add membrane displacement coupling only after the accepted smoke target
   passes its stability and writer round-trip checks.
3. Add energy/positivity/residual diagnostics appropriate to the chosen weak
   form and time stepper.
4. Add production guards for mesh size, time step, wall displacement, and output
   volume.
5. Only then run the exact Section 4.1 case specs from Lane 2A.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
```

Acceptance:

- A smoke case writes and reloads loadable velocity, pressure, and displacement
  fields.
- If the first target is staged, the displacement treatment is explicit and
  matches the accepted Lane 2D contract.
- The smoke handback records schema, geometry, time, and field status for the
  generated bundle before Lane 2G begins full operator parity work.
- Production Section 4.1 runs are reproducible from a spec and write provenance
  alongside XDMF/HDF5 outputs.

Lane 2F handback recorded on 2026-06-22:

- `adapters/native_resolved_fsi.jl` now provides
  `NativeResolvedFSISmokeSpec`, `NativeResolvedFSISmokeResult`,
  `native_resolved_fsi_smoke_spec(...)`,
  `default_native_resolved_fsi_smoke_output_dir(...)`,
  `run_native_resolved_fsi_smoke(...)`, and the internal overload
  `run_native_resolved_fsi(::NativeResolvedFSISmokeSpec)`.
- The delivered smoke is a staged fixed-wall stationary-Stokes solve on the
  native mesh, not the full transient Navier-Stokes target. This was accepted as
  the smallest honest Gridap-backed solver target for this round.
- Velocity and pressure are sampled from the Gridap stationary-Stokes solution,
  pressure is outlet-gauge normalized, displacement is the explicit zero vector
  field, and the three-field bundle reloads through the existing importer.
- Focused validation passed for `test/test_native_resolved_fsi_smoke.jl`.
- Lane 2G may begin fixture/native-bundle parity from this output. Full
  Section 4.1 Navier-Stokes or moving-wall FSI parity remains a follow-up.

### Lane 2G: Parity Harness Against Imported External Fields

Agent type: implementation worker.

Owned write scope:

- Existing resolved-3D comparison workflow only if explicitly assigned.
- New native-vs-imported parity workflow/test files, for example
  `test/test_native_resolved_fsi_parity.jl`.
- `test/runtests.jl` only to include the new test.

Implementation:

1. Reuse the existing resolved-3D observation operators for section quadrature,
   radial profiles, node-slab sensitivity, and grid sensitivity.
2. Compare native-generated bundles against imported external bundles through
   the same observation workflow, not by ad hoc array comparisons alone.
3. Add a fixture-level parity test using tiny generated fields.
4. Add optional production parity commands that run only when external data are
   present.
5. Report schema, geometry, time, velocity, pressure, displacement, and
   observation-operator discrepancies separately.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl")'
```

Acceptance:

- Native-generated fields and imported external fields can be compared through
  one reproducible workflow with expected skips when external data are absent.
- Parity outputs separate schema, geometry, time, field, and operator
  discrepancies instead of merging them into one summary.

Lane 2G handback recorded on 2026-06-22:

- `workflows/native_resolved_fsi_parity.jl` now provides
  `NativeResolvedFSIParitySpec`, `NativeResolvedFSIParityStatus`,
  `NativeResolvedFSIParityResult`, `native_resolved_fsi_parity_spec(...)`,
  `run_native_resolved_fsi_parity(...)`, and the internal overload
  `run_native_resolved_fsi(::NativeResolvedFSIParitySpec)`.
- The harness loads both sides through
  `load_resolved3d_field_bundle(...; require_pressure=true,
  require_displacement=true)` and reports separate schema, geometry, time,
  velocity, pressure, displacement, and operator statuses.
- Missing imported external inputs return typed skipped statuses when
  `require_imported=false` and throw when `require_imported=true`.
- Focused validation passed for `test/test_native_resolved_fsi_parity.jl`.
- Operator parity is intentionally partial: existing velocity observation
  operators are reused, but pressure/displacement operator parity and full
  Section 4.1 transient Navier-Stokes plus membrane parity remain deferred.

### Lane 2H: Upgrade Smoke To Time-Dependent Navier-Stokes

Agent type: implementation worker.

Owned write scope:

- `adapters/native_resolved_fsi.jl` and optional
  `adapters/native_resolved_fsi_*.jl` helper files.
- Focused tests under `test/test_native_resolved_fsi_*.jl`.
- `test/runtests.jl` only to include new focused tests.

Implementation:

1. Extend the fixed-wall Gridap smoke from stationary Stokes to the accepted
   fixed-wall incompressible Navier-Stokes smoke target from Lane 2D.
2. Keep displacement output explicit and zero during the fixed-wall stage.
3. Preserve the writer/importer round-trip and status fields from Lane 2F.
4. Add Picard/time-step guards, finite-field checks, and output-volume guards.
5. Do not add moving-wall membrane coupling in this lane.

Acceptance:

- A coarse fixed-wall Navier-Stokes smoke writes and reloads velocity, pressure,
  and zero displacement.
- The handback clearly distinguishes Stokes smoke, Navier-Stokes smoke, and
  deferred moving-wall FSI capability.

### Lane 2I: Partitioned Membrane Coupling

Agent type: implementation worker after Lane 2H.

Owned write scope:

- Native resolved-FSI adapter files explicitly assigned by the orchestrator.
- Focused partitioned-coupling tests.

Implementation:

1. Add the axisymmetric membrane state from the Lane 2D design:
   radial displacement, wall velocity, clamped endpoints, wall mass, stiffness,
   and optional damping.
2. Couple fluid pressure load to the membrane update with a partitioned,
   staggered sequence.
3. Lift wall displacement into node-centered volumetric displacement using the
   Lane 2D linear radial convention.
4. Guard membrane stability, positive radius, no inverted tetrahedra, and finite
   written fields.

Acceptance:

- A coarse partitioned smoke writes and reloads velocity, pressure, and
  nonzero clamped displacement.
- The result remains documented as a staged partitioned approximation, not
  monolithic paper-grade FSI.

### Lane 2J: Section 4.1 Production And Operator Parity

Agent type: implementation worker after Lane 2I.

Owned write scope:

- Native resolved-FSI workflow/parity files explicitly assigned by the
  orchestrator.
- Focused production/parity tests with expected skips for absent external data.

Implementation:

1. Add reproducible specs for the `sev23`, `sev40`, and `sev50` Section 4.1
   cases using the locked reproduction doc.
2. Add pressure section-average observation support or a dedicated pressure
   parity seam so Figure 5-style comparisons are not reduced to raw nodewise
   arrays.
3. Run production parity only when external imported bundles are available;
   otherwise report expected skips.
4. Separate schema, geometry, time, velocity, pressure, displacement, and
   observation-operator discrepancies in output summaries.

Acceptance:

- Native production outputs can be compared against imported external bundles
  when data are present, with explicit expected skips otherwise.
- Pressure and displacement parity limitations are reported separately from
  velocity observation parity.

## Step 3: Next-Round Maintainability Lanes

These lanes are part of the next round instead of being deferred indefinitely.
Lane 2G is now complete at fixture/direct-bundle scope. The orchestrator may run
these lanes next round in parallel with Lane 2H only when file ownership is
disjoint from active native resolved-FSI implementation work.

### Lane 3A: Dependency-Boundary Hardening

Objective: narrow dependency ownership around SciML, Gridap, HDF5/EzXML, and
YAML/OpenBF so optional ecosystems stay behind explicit adapter/workflow seams.

Owned write scope:

- `Project.toml`
- `src/StenoticHemodynamics.jl`
- Touched files under `src/StenoticHemodynamics/adapters/`,
  `src/StenoticHemodynamics/workflows/`, or `ext/` for exactly one dependency
  family per worker
- Focused tests for the touched dependency surface

Implementation:

1. Reinforce or move seams so dependency-specific imports stay in narrow,
   reviewable files.
2. If package extensions are introduced, do it one dependency family at a time
   without renaming public workflow or CLI entrypoints.
3. Do not mix this lane with solver-algorithm changes.

Validation:

- Package-load smoke from Lane 1B.
- Focused tests for each touched dependency family.

Acceptance:

- Dependency ownership is narrower and easier to audit.
- Public CLI names, workflow names, and file schemas remain unchanged.

### Lane 3B: Scalar Genericity Propagation

Objective: carry the current typed footholds beyond cache constructors and local
kernels without forcing a full `Params{T}` rewrite in the same lane.

Owned write scope:

- Low-risk numerics/core files such as `numerics/state.jl`, `numerics/methods.jl`,
  `core/profiles.jl`, `core/rheology.jl`, `core/boundaries.jl`, and
  `core/initial_conditions.jl`
- `test/test_scalar_generality.jl`
- `test/runtests.jl` only to include new focused tests if needed

Implementation:

1. Propagate typed footholds into additional low-risk helpers, diagnostics, or
   support structs where that does not force a full solver rewrite.
2. Leave the main `Float64` solver entrypoints in place unless this lane
   explicitly widens scope and proves the broader change safe.
3. Update docstrings where typed behavior changes.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_scalar_generality.jl")'
```

Acceptance:

- Typed behavior progresses beyond cache allocation alone.
- Remaining `Float64` choke points are documented rather than silently expanded.

### Lane 3C: Targeted Large-File Reduction

Objective: reduce one concentration point at a time only where the split
directly improves the native resolved-FSI roadmap or testability.

Owned write scope:

- Exactly one file family per worker from:
  - `numerics/dg.jl`
  - `numerics/solver_fluxes.jl`
  - `adapters/stokes_ic.jl`
  - `workflows/benchmark_stage_rows.jl`
  - `workflows/verification_mms.jl`
  - `workflows/verification_ph_refinement.jl`
  - `workflows/resolved3d_compare_rows.jl`
  - `adapters/resolved3d_io.jl`
- Focused tests for the touched surface

Implementation:

1. Convert the original file into an always-present aggregator before moving any
   helpers out.
2. Split by role-specific helpers, not by arbitrary line count.
3. Do not assign more than one concentration family to one worker.

Validation:

- `git diff --check -- packages/stenotic-hemodynamics`
- Focused tests for the touched surface

Acceptance:

- The stable include target remains in place.
- Public behavior is unchanged and the split leaves a cleaner ownership boundary.

## Next-Round Dispatch Template

Use this control table for provenance unless the live tree has changed. Lanes
1B through 2G were executed in the 2026-06-22 supervised round and should not be
redispatched except for targeted fixes. The next active implementation lanes are
2H, 2I, 2J, and the maintainability lanes in Step 3.

| Lane | Start gate | Write ownership | Stop condition | Validation and handback |
| --- | --- | --- | --- | --- |
| 1B round boundary sanity | Starts immediately after baseline preflight. | None unless a concrete failure is found. | Stop on whitespace, package-load, or full-gate failure that needs a scoped owner. | Run `git diff --check -- packages/stenotic-hemodynamics`, package-load smoke, and at most one `pipenv run ops-julia-check`; hand back exact command results. |
| 2A Section 4.1 spec | Starts after 1B succeeds or records only expected optional-data skips. | `TODO.md` and optional package docs only. | Stop implementation lanes if required Section 4.1 values remain blocker unknowns. | Hand back the case/spec table, unknown ledger, units mapping, required fields, acceptance tiers, and readiness for 2B/2C. |
| 2B mesh/domain | Starts only after 2A locks geometry and units. | `native_resolved_fsi_mesh*` source files, focused mesh tests, and `test/runtests.jl`. | Stop if mesh requirements depend on unresolved Section 4.1 blockers, cannot stay backend-agnostic, or need files outside the lock. | Run focused mesh tests; hand back touched files, deterministic counts, boundary tags, and readiness for 2D/2E. |
| 2C writer round-trip | Starts only after 2A locks required fields and XDMF/HDF5 schema. | Production writer adapter files, focused writer tests, and includes needed for them. | Stop if importer behavior would need a schema-breaking rewrite or if the lane would reduce the target to velocity-only output. | Run focused writer tests through `load_resolved3d_field_bundle`; hand back schema notes, deformed-coordinate behavior, and readiness for 2D/2E/2G. |
| 2D solver design | Starts after 2A records Section 4.1 requirements and should normally consume the 2B/2C handbacks before the design is locked. | `TODO.md` and optional design docs only. | Stop if the backend, first target, or coupling strategy cannot be chosen from local evidence. | Hand back the accepted design gate: backend, first target, files, structs, tests, stability guards, tolerances, and implementation readiness. |
| 2E workflow skeleton | Starts only after 2B, 2C, and accepted 2D are stable. | `native_resolved_fsi*` workflow/adapters plus focused tests; CLI only if separately assigned. | Stop if a tiny three-field bundle cannot be written and reloaded without external data. | Run focused workflow tests; hand back tiny-bundle paths, schema/geometry/time/field/operator readiness, scratch-output location, and readiness for 2F/2G. |
| 2F solver smoke | Starts only after 2E writes and reloads a tiny native bundle. | Native solver files explicitly assigned by the orchestrator plus focused smoke tests. | Stop on unstable smoke solve, output-volume risk, or unaccepted design changes. | Run focused smoke checks; hand back generated-field provenance, displacement treatment, schema/geometry/time/field status, and readiness for Section 4.1 production runs or 2G parity. |
| 2G parity harness | Starts only after 2F produces a stable smoke solve and bundle format. | Native-vs-imported parity workflow/test files explicitly assigned by the orchestrator. | Stop on missing external data for production parity, schema mismatch, or unresolved observation-operator drift. | Run focused parity checks; hand back expected skips and separate schema, geometry, time, field, and operator discrepancy categories. |
| 2H Navier-Stokes smoke upgrade | Starts from the completed fixed-wall Stokes smoke and Lane 2D design. | Native resolved-FSI adapter files plus focused tests. | Stop if the lane cannot preserve three-field writer/importer round trip or would introduce moving-wall coupling prematurely. | Run focused Navier-Stokes smoke tests; hand back solver stage, guards, field provenance, and readiness for 2I. |
| 2I partitioned membrane coupling | Starts after 2H produces a stable fixed-wall Navier-Stokes smoke. | Native resolved-FSI adapter files plus focused partitioned-coupling tests. | Stop on unstable wall update, nonpositive radius, inverted tetrahedra, or unaccepted coupling changes. | Run focused partitioned smoke tests; hand back displacement lift, wall state, stability guards, and readiness for 2J. |
| 2J Section 4.1 production/operator parity | Starts after 2I, or earlier for pressure-operator-only work if disjoint. | Native workflow/parity files and focused tests. | Stop if external data are absent and production parity is required; record expected skips otherwise. | Run focused production/parity checks; hand back Section 4.1 case status and separated schema/geometry/time/field/operator discrepancies. |
| 3A dependency boundaries | Starts next round when disjoint from active 2H/2I/2J files. | One dependency family across `Project.toml`, `src/StenoticHemodynamics.jl`, and related adapter/workflow files. | Stop if the lane requires public API renames or overlaps active native resolved-FSI implementation. | Run package-load smoke plus focused dependency-surface tests; hand back narrowed ownership and remaining extension work. |
| 3B scalar genericity | Starts next round when disjoint from active 2H/2I/2J files. | Low-risk numerics/core files plus scalar-generality tests. | Stop if the lane would force a full solver rewrite without explicit scope expansion. | Run `test/test_scalar_generality.jl` and focused follow-on tests; hand back newly typed surfaces and remaining `Float64` choke points. |
| 3C large-file reduction | Starts next round when disjoint from active 2H/2I/2J files. | Exactly one concentration family plus focused tests. | Stop if the split does not directly improve the roadmap or cannot preserve the original include target. | Run `git diff --check -- packages/stenotic-hemodynamics` and focused tests; hand back the new file boundary and preserved include target. |

Default dispatch order:

1. Run Lane 1B once after baseline preflight.
2. Do not redispatch completed Lanes 2A through 2G except for targeted fixes to
   the files already landed in this round.
3. Assign Lane 2H to the native solver worker first; it is the next critical
   path from Stokes smoke to fixed-wall Navier-Stokes smoke.
4. In parallel with Lane 2H, assign Lane 3B scalar-genericity or one Lane 3C
   large-file split only if the write scope is disjoint from
   `adapters/native_resolved_fsi*`, `workflows/native_resolved_fsi*`, and the
   native resolved-FSI tests.
5. Assign Lane 2I only after Lane 2H has a stable three-field
   Navier-Stokes smoke round trip.
6. Assign Lane 2J pressure/operator/production parity after Lane 2I, or split a
   pressure-operator-only sublane earlier if it stays out of the solver files.
7. Run Lane 3A dependency-boundary work one dependency family at a time after
   the native resolved-FSI write scopes are quiet, unless an active lane
   explicitly needs that dependency split to proceed.

Keep the existing external resolved-3D importer as a first-class supported path
throughout this roadmap.
