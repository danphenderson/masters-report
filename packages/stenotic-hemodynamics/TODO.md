# StenoticHemodynamics Fleet TODO

Date: 2026-06-22

This file is the dispatch plan for the next supervised fleet round in
`packages/stenotic-hemodynamics`. It is grounded in the cleanup work already
landed in the current dirty tree and replaces the older audit-style plan.

## Current Baseline

The package now has a clearer boundary between the reduced 1D solver, workflow
orchestration, optional data adapters, report assets, and imported resolved-3D
comparison data.

Already landed in this round:

- README wording now states that the primary forward solver is reduced 1D, that
  resolved-3D workflows import external XDMF/HDF5 data, and that stationary
  Stokes initialization is an analytic resistance/pressure-law projection for
  the 1D state rather than direct FE field projection.
- `cli/cli.jl` is now an include-only dispatcher over command-specific files.
  Low-risk spec construction and parsed-value helpers moved into workflow-owned
  modules, especially `workflows/workflow_values.jl`.
- `workflows/verification.jl`, `resolved3d_outputs.jl`, `resolved3d_compare.jl`,
  `geometry_exports.jl`, `benchmarks.jl`, `studies.jl`,
  `operator_validation.jl`, `membrane_fsi_validation.jl`,
  `stationary_stokes_refinement.jl`, and several resolved-3D helper surfaces are
  now thin include targets with role-specific files beneath them.
- `numerics/solver.jl` is now a thin include target over boundary helpers,
  flux/reconstruction helpers, RHS functions, native steppers, and orchestration.
- `resolved3d_types.jl` no longer owns HDF5/EzXML imports. It is a dependency-light
  contract surface for case specs, metadata structs, result rows, and command
  planning.
- `adapters/resolved3d_io.jl` owns XDMF/HDF5 file I/O. `io/waveforms.jl` owns
  file-backed waveform inlet loading while preserving public constructor
  behavior.
- Gridap ownership is more explicit in stationary-Stokes refinement, geometry
  exports, stationary-Stokes initialization, and membrane-FSI adapter surfaces.
- `core/profiles.jl`, `core/rheology.jl`, `core/boundaries.jl`, and
  `core/initial_conditions.jl` have first-stage scalar-generic config types.
- `numerics/state.jl` now has typed `RHSCache{T}` and `NativeStepCache{T}`
  constructors, while `semidiscretize(params)` remains `Float64` by design.
- `numerics/methods.jl` has scalar-generic limiter and Legendre helper kernels.
- Focused seam tests were added for solver helpers, resolved-3D comparison
  helpers, benchmark helpers, CLI export assets, CLI benchmarks, and scalar
  genericity.
- The shared OpenBF test fixture helper now lives in `test_helpers.jl`, so
  focused CLI/OpenBF tests no longer depend on `test_core_model.jl` include
  ordering.

Validation already performed by the fleet:

- CLI-focused tests and full package checks passed during the CLI split.
- Verification, resolved-3D output/report, resolved-3D compare, benchmark,
  geometry export, stationary-Stokes refinement, operator validation, studies,
  membrane-FSI validation/adapter, and scalar-generality lanes each reported
  focused passing validation.
- The resolved-3D CSV split briefly removed and re-added
  `workflows/resolved3d_csv.jl`, which blocked Faraday's first membrane-FSI
  adapter validation with a missing include. This is resolved in the final tree:
  `resolved3d_csv.jl` is present as a stable aggregator. Future split work must
  preserve include targets in place instead of deleting and recreating them.

## Fleet Rules

- Start implementation with `pipenv run ops-orchestrate status --json` and use
  the live tree as authority.
- Use one writer per disjoint file set. Multiple writers may run concurrently
  only when their owned paths do not overlap.
- If a lane discovers that it needs files outside its initial lock, the agent
  must stop and request scope expansion. The orchestrator decides whether to
  approve, redirect, or defer it.
- Do not delete an existing include target during a split. Convert the original
  file into an always-present aggregator first, then add included files. This
  rule comes from the resolved-3D CSV transient include mismatch above.
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

## Step 1: Cleanup Closeout

These lanes finish the cleanup round and prepare the tree for the native
resolved-FSI work. Keep these scoped and do not restart broad refactors.

### Lane 1A: Test Helper Hygiene - Completed In This Round

Objective: make focused CLI and study tests runnable without relying on
`runtests.jl` side effects.

Owned write scope:

- `test/test_helpers.jl`
- `test/test_core_model.jl`
- `test/test_cli_studies.jl`

Implemented:

1. Moved the shared OpenBF fixture helper from `test_core_model.jl` into
   `test_helpers.jl`.
2. Left fixture contents unchanged.
3. Removed the old helper definition from `test_core_model.jl`.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_helpers.jl"); include("packages/stenotic-hemodynamics/test/test_cli_studies.jl")'
```

Result in this round: passed after the helper move.

Acceptance:

- `test_cli_studies.jl` runs as a focused test file after including only
  `test_helpers.jl`.

### Lane 1B: Round Boundary Sanity Check

Objective: verify the cleanup tree once, without duplicating every agent lane.

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

### Lane 1C: Remaining Large-File Triage

Objective: leave a short, evidence-based list of remaining large files without
splitting more surfaces before the native resolved-FSI roadmap starts.

Current largest implementation files after this round:

- `numerics/dg.jl` around 600 lines.
- `workflows/benchmark_stage_rows.jl` around 490 lines.
- `numerics/solver_fluxes.jl` around 450 lines.
- `adapters/stokes_ic.jl` around 420 lines.
- `workflows/verification_mms.jl` and `verification_ph_refinement.jl` around
  400 lines each.
- `workflows/resolved3d_compare_rows.jl` around 380 lines.
- `core/rheology.jl`, `core/diagnostics.jl`, `adapters/openbf_protocol.jl`, and
  `adapters/resolved3d_io.jl` remain medium-large.

Do not split these opportunistically during the native-FSI planning round unless
the split directly unblocks that roadmap.

## Step 2: Native Resolved-FSI Generator Roadmap

Objective: add a Julia-native resolved-FSI generator that can produce velocity,
pressure, and wall-displacement XDMF/HDF5 data for the paper's Section 4.1
benchmark cases, then compare those generated fields against imported external
fields through the existing resolved-3D comparison workflow.

This is additive. The existing importer remains valid and important. Faraday's
importer/adapter work should be treated as a supported project goal, not as
temporary scaffolding. The native generator must write data compatible with the
same importer and parity harness.

Interpret "native Julia" as no MATLAB or external paper codebase dependency.
Using Julia FE libraries such as Gridap is acceptable unless a later design
decision explicitly narrows the requirement.

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
2. Identify which values are explicit in the paper, which are inferred from the
   supplemental MATLAB data, and which remain unknown.
3. Map the paper variables to package units and names.
4. Define acceptance tiers:
   - schema parity: generated HDF5/XDMF loads through the existing importer;
   - geometry parity: mesh/domain sections match the analytic stenosis profile;
   - operator parity: existing section/radial observation workflow runs;
   - numerical parity: generated fields agree with imported external fields
     within documented tolerances.
5. Record any blocked items as explicit unknowns, not TODO placeholders.

Validation:

- Documentation review against the PDF and local code only.
- No generated data required.

Acceptance:

- The next implementation agents can work from concrete case specs rather than
  re-reading the paper independently.

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
2. Produce a Gridap-compatible model or mesh object with stable boundary tags
   for inlet, outlet, wall, and interior.
3. Expose deterministic mesh parameters for axial, radial, and angular
   resolution.
4. Add geometry tests for section area, radius profile, length, boundary tags,
   and deterministic node/cell counts.
5. Keep this lane independent of the Navier-Stokes/membrane solver.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_mesh.jl")'
```

Acceptance:

- Mesh/domain generation is deterministic and can be consumed by later solver
  and writer lanes.

### Lane 2C: XDMF/HDF5 Writer Compatible With Importer

Agent type: implementation worker.

Owned write scope:

- New writer files, for example
  `src/StenoticHemodynamics/adapters/resolved3d_writer.jl` and helper files.
- Existing include file `src/StenoticHemodynamics.jl` only if required.
- New focused tests, for example `test/test_resolved3d_writer.jl`.

Implementation:

1. Define a writer contract for velocity, pressure, and displacement fields
   using the same metadata model as `Resolved3DFieldBundle`.
2. Write HDF5 datasets and companion XDMF files with paths and attribute names
   accepted by `adapters/resolved3d_io.jl`.
3. Include pressure and displacement even if early solver fixtures use analytic
   placeholder arrays.
4. Add round-trip tests that write a tiny synthetic field bundle, load it with
   the existing importer, and verify coordinates, connectivity, time selection,
   velocity, pressure, and displacement arrays.
5. Preserve the existing importer. Do not rewrite importer behavior unless a
   writer test exposes a real contract bug.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_resolved3d_writer.jl")'
```

Acceptance:

- A generated synthetic resolved-3D fixture round-trips through the same loader
  used for external MATLAB/supplement data.

### Lane 2D: 3D Navier-Stokes Plus Membrane Coupling Design

Agent type: architecture worker, then implementation worker after approval.

Owned write scope for design:

- `packages/stenotic-hemodynamics/TODO.md`
- optional design doc under `packages/stenotic-hemodynamics/docs/`

Design requirements:

1. Choose a minimal first implementation target for unsteady incompressible
   Navier-Stokes in the stenotic tube using Gridap-centered components.
2. Specify the membrane model for an isotropic homogeneous elastic vessel:
   state variables, wall displacement variable, stiffness/mass/damping inputs,
   and coupling terms.
3. Decide the first coupling strategy:
   - partitioned fluid solve plus membrane update;
   - monolithic weak form;
   - or an explicitly staged surrogate if a full solve is too large for the
     first implementation.
4. Define time integration, boundary conditions, units, and stability guards.
5. Define what fields are written at each time step: velocity, pressure, and
   displacement.
6. Identify which existing quasi-static membrane-FSI adapter code can be reused
   and which must remain separate to avoid overstating current capability.

Acceptance:

- The design names concrete files, structs, workflow entrypoints, tests, and
  acceptance tolerances before numerical implementation begins.

### Lane 2E: Native Generator Workflow Skeleton

Agent type: implementation worker after Lane 2D is accepted.

Owned write scope:

- New prefix `native_resolved_fsi*` under workflows/adapters.
- CLI files only if the orchestrator explicitly assigns a CLI lane.
- New focused tests.

Implementation:

1. Add a typed generator spec for Section 4.1 cases and mesh/solver/writer
   options.
2. Add a workflow runner that can generate a tiny synthetic or analytic smoke
   field, write XDMF/HDF5 through Lane 2C, and return paths.
3. Keep public CLI exposure optional until the internal workflow is stable.
4. Make output paths default to ignored scratch locations under
   `tmp/simulations/output/**`.

Acceptance:

- The workflow can produce a tiny loadable XDMF/HDF5 bundle without external
  data and without running a production 3D solve.

### Lane 2F: Native Solver Smoke, Then Section 4.1 Cases

Agent type: implementation worker.

Owned write scope:

- Native resolved-FSI solver files from Lane 2D/2E.
- Focused native resolved-FSI tests.

Implementation:

1. Start with the smallest stable 3D solve that writes velocity and pressure on
   the native mesh.
2. Add membrane displacement coupling only after fixed-wall Navier-Stokes smoke
   tests pass.
3. Add energy/positivity/residual diagnostics appropriate to the chosen weak
   form and time stepper.
4. Add production guards for mesh size, time step, wall displacement, and output
   volume.
5. Only then run the exact Section 4.1 case specs from Lane 2A.

Acceptance:

- A smoke case writes loadable velocity, pressure, and displacement fields.
- Production Section 4.1 runs are reproducible from a spec and write provenance
  alongside XDMF/HDF5 outputs.

### Lane 2G: Parity Harness Against Imported External Fields

Agent type: implementation worker.

Owned write scope:

- Existing resolved-3D comparison workflow only if explicitly assigned.
- New native-vs-imported parity workflow/test files.

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

Acceptance:

- Native-generated fields and imported external fields can be compared through
  one reproducible workflow with expected skips when external data are absent.

## Step 3: Deferred Cleanup After Native-FSI Skeleton

Defer these until the native resolved-FSI generator has a working mesh, writer,
and smoke workflow:

- Full `Params{T}` and solver genericization. Current footholds are config
  types, typed caches, limiter helpers, and Legendre helpers. The solver RHS,
  native steppers, DG solver, diagnostics, `SimulationResult`, and workflow rows
  remain largely `Float64`.
- Weak dependency split into package extensions for SciML, YAML/OpenBF,
  HDF5/EzXML resolved-3D I/O, and Gridap Stokes/FSI surfaces.
- More large-file splits for `numerics/dg.jl`, `adapters/stokes_ic.jl`,
  `benchmark_stage_rows.jl`, `solver_fluxes.jl`,
  `verification_mms.jl`, `verification_ph_refinement.jl`,
  `resolved3d_compare_rows.jl`, and `adapters/resolved3d_io.jl`.

## Next-Round Dispatch Template

Use this order unless the live tree has changed:

1. Assign Lane 1B to the orchestrator or a verification worker, with no broad
   reruns beyond one boundary gate.
2. Assign Lane 2A to a spec/planning agent.
3. In parallel after Lane 2A identifies no blockers, assign Lane 2B
   mesh/domain generation and Lane 2C writer round-trip, because their file
   scopes are disjoint.
4. Assign Lane 2D design before any full Navier-Stokes/membrane implementation.
5. Assign Lane 2E workflow skeleton only after the mesh and writer contracts are
   stable.
6. Assign Lane 2F and Lane 2G only after the skeleton can write and reload a
   tiny native bundle.

Keep the existing external resolved-3D importer as a first-class supported path
throughout this roadmap.
