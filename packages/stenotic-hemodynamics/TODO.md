# StenoticHemodynamics Next-Round Fleet TODO

Date: 2026-06-22

This is the next supervised implementation plan for
`packages/stenotic-hemodynamics`. It starts from local `master` commit
`a00efaa` (`Add native resolved FSI scaffolding`) and assumes the orchestrator
will continue the native resolved-FSI roadmap.

## Baseline

The previous round landed:

- Section 4.1 reproduction notes in
  `docs/native_resolved_fsi_reproduction.md`.
- First implementation design in `docs/native_resolved_fsi_design.md`.
- Native Section 4.1 mesh/domain contract in
  `workflows/native_resolved_fsi_mesh.jl`.
- Importer-compatible three-field XDMF/HDF5 writer in
  `adapters/resolved3d_writer.jl`.
- Schema-only native workflow skeleton in
  `workflows/native_resolved_fsi_workflow.jl`.
- Fixed-wall Gridap stationary-Stokes smoke in
  `adapters/native_resolved_fsi.jl`.
- Fixture/direct-bundle native-vs-imported parity harness in
  `workflows/native_resolved_fsi_parity.jl`.
- Focused tests included from `test/runtests.jl`.

The package can now generate, write, reload, and compare tiny
`velocity + pressure + displacement` resolved-FSI bundles through the same
importer used for external data. The solver-backed smoke is stationary Stokes,
not transient Navier-Stokes and not moving-wall membrane FSI.

## Orchestration Rules

- Start with `pipenv run ops-orchestrate status --json` and treat the live tree
  as authority.
- At the time this plan was written, unrelated dirty files existed outside the
  committed native resolved-FSI patch:
  - `packages/stenotic-hemodynamics/src/StenoticHemodynamics/AGENTS.md`
  - `report/sections/03-model-hierarchy/index.tex`
  - `report/sections/04-modeling-closures/index.tex`
  - `report/sections/07-case-study/comparison.tex`
  Do not stage, revert, normalize, or route those files unless the user
  explicitly assigns that lane.
- Use one writer per disjoint file set. Concurrent workers may proceed only
  when their owned paths do not overlap.
- If a worker needs files outside its lock, it must stop and request expansion.
  The orchestrator decides whether to approve, redirect, or defer.
- Do not delete existing include targets. Convert files into aggregators before
  splitting them.
- Code lanes own docstrings and comments in their assigned files.
- Do not repeat worker validation by default. Review the diff, accept focused
  validation when it matches the touched scope, and run one broader gate at the
  round boundary.
- External resolved-3D data under `public/var/data/simulations/**` may be
  absent. Tests should use generated fixtures unless a lane explicitly requires
  local external data.
- Preserve public CLI commands, option names, stdout keys, file names, and
  XDMF/HDF5 schemas unless a lane explicitly widens scope.
- The target native bundle remains `velocity + pressure + displacement`; native
  velocity-only output is not an accepted result.
- Keep imported external data support first-class. Native generation augments
  the importer; it does not replace it.

## Step 0: Boundary Gate

Owned write scope: none unless a concrete failure is found.

Run once before dispatching workers:

```bash
git diff --check -- packages/stenotic-hemodynamics
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using StenoticHemodynamics; println("package-load-ok")'
```

Run `pipenv run ops-julia-check` only once at the end of the round, or earlier
if an integration review finds a real cross-surface risk.

Acceptance:

- Whitespace check passes.
- Package load succeeds.
- Any failure is assigned to a narrow owner before further implementation.

## Step 1: Native Resolved-FSI Critical Path

### Lane 2H: Fixed-Wall Navier-Stokes Smoke Upgrade

Objective: upgrade the current fixed-wall stationary-Stokes smoke to the first
fixed-wall incompressible Navier-Stokes smoke without adding moving-wall
coupling.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi.jl`
- Optional new files with prefix
  `src/StenoticHemodynamics/adapters/native_resolved_fsi_*.jl`
- `test/test_native_resolved_fsi_smoke.jl`
- Optional new focused test file such as
  `test/test_native_resolved_fsi_navier_stokes.jl`
- `test/runtests.jl` only to include a new focused test
- `test/test_public_api.jl` only if new qualified internal names are added

Implementation:

1. Preserve the existing stationary-Stokes smoke API and tests.
2. Add a clearly named Navier-Stokes smoke stage, for example
   `NativeResolvedFSINavierStokesSmokeSpec`,
   `NativeResolvedFSINavierStokesSmokeResult`, and
   `run_native_resolved_fsi_navier_stokes_smoke(...)`.
3. Use the accepted Gridap backend and `NativeResolvedFSIMesh`.
4. Implement a coarse fixed-wall time stepper with explicit `dt_s`,
   `tfinal_s`, Picard iteration count, and Picard tolerance. A minimal
   backward-Euler/Picard step is acceptable if it is documented and guarded.
5. Keep displacement output explicit and identically zero.
6. Write through `write_resolved3d_field_bundle(...)` and reload through
   `load_resolved3d_field_bundle(...; require_pressure=true,
   require_displacement=true)`.
7. Return schema, geometry, time, and field statuses comparable to the existing
   Stokes smoke.
8. Add guards for positive `dt_s`, positive `tfinal_s`, finite pressure/velocity
   fields, nonempty mesh, positive reference radii, and estimated output payload.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
```

Acceptance:

- Existing Stokes smoke remains valid.
- Navier-Stokes smoke writes and reloads velocity, pressure, and zero
  displacement.
- The handback states whether the new smoke is transient Navier-Stokes,
  linearized Navier-Stokes, or another explicitly staged approximation.
- No moving-wall or membrane-coupled claim is made in this lane.

### Lane 2I: Partitioned Membrane Coupling

Start gate: Lane 2H passes and preserves the three-field writer/importer round
trip.

Objective: add the first moving-wall partitioned membrane-coupling smoke using
the Lane 2D design.

Owned write scope:

- Native resolved-FSI adapter files explicitly assigned by the orchestrator
- Focused partitioned-coupling tests
- `test/runtests.jl` only to include a new focused test
- `test/test_public_api.jl` only if new qualified internal names are added

Implementation:

1. Add an axisymmetric wall state on native axial stations:
   radial displacement, wall velocity, wall mass, stiffness, optional damping,
   and clamped endpoints.
2. Use the local stiffness convention from `canic_membrane_c0(...)` with
   `R_ref = p.rmax` unless the lane explicitly widens to resolve the paper's
   unstated `R0*`.
3. Couple fluid pressure load to the wall update with a staggered sequence:
   fluid solve, wall-pressure sampling, membrane update, radial lift, next
   geometry.
4. Use the established linear radial volumetric lift so
   `deformed = reference + displacement` remains importer-compatible.
5. Guard explicit membrane stability,
   `dt_s <= 1.9 * sqrt((rho_s * h) / C0_max)`, positive radius, no inverted
   tetrahedra, finite fields, and output payload.
6. Keep the first coupled lane coarse and reproducible; do not attempt full
   Section 4.1 production runs here.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
```

Acceptance:

- A coarse partitioned smoke writes and reloads velocity, pressure, and nonzero
  clamped displacement.
- Deformed coordinates load through the existing importer.
- The handback explicitly says this is staged partitioned FSI, not monolithic
  paper-grade FSI.

### Lane 2J: Section 4.1 Production Specs And Operator Parity

Start gate: Lane 2I has a stable partitioned smoke, or the orchestrator splits
out a pressure-operator-only sublane that is disjoint from solver files.

Objective: move from fixture/direct-bundle parity toward Section 4.1 production
and observation-operator parity.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_parity.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow.jl`
- Optional new `native_resolved_fsi_*` workflow helper files
- Focused production/parity tests
- `test/runtests.jl` only to include new focused tests

Implementation:

1. Add reproducible native specs for `sev23`, `sev40`, and `sev50` using
   `docs/native_resolved_fsi_reproduction.md`.
2. Add pressure section-average observation support or a dedicated pressure
   parity seam so Figure 5-style comparisons are not raw nodewise arrays only.
3. Keep current velocity section/radial/node-slab operator parity working.
4. Run external-data production parity only when imported bundles are present;
   otherwise return expected skip statuses.
5. Report schema, geometry, time, velocity, pressure, displacement, and operator
   discrepancies separately.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl")'
```

Acceptance:

- Fixture parity remains green.
- Pressure operator parity is represented separately from velocity operator
  parity.
- Production Section 4.1 parity reports expected skips when external data are
  absent.

## Step 2: Disjoint Parallel Maintainability Lanes

These may run in parallel with Lane 2H only when file ownership is disjoint from
`adapters/native_resolved_fsi*`, `workflows/native_resolved_fsi*`, and native
resolved-FSI tests.

### Lane 3B: Scalar Genericity Propagation

Owned write scope:

- One low-risk core/numerics family per worker, such as:
  - `core/profiles.jl`
  - `core/rheology.jl`
  - `core/boundaries.jl`
  - `core/initial_conditions.jl`
  - `numerics/state.jl`
  - `numerics/methods.jl`
- `test/test_scalar_generality.jl`
- `test/runtests.jl` only if a new focused test is added

Implementation:

1. Propagate typed footholds into helper structs and local kernels where it does
   not force a full solver rewrite.
2. Leave the main solver entrypoints `Float64` unless explicitly widened.
3. Document remaining `Float64` choke points in test names or comments.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_scalar_generality.jl")'
```

### Lane 3C: Targeted Large-File Reduction

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
- Focused tests for that surface

Implementation:

1. Preserve the original include target as an aggregator.
2. Split by role-specific helpers, not arbitrary line count.
3. Do not mix large-file reduction with algorithm changes.

Validation:

- `git diff --check -- packages/stenotic-hemodynamics`
- Focused tests for the touched surface

### Lane 3A: Dependency-Boundary Hardening

Run after native resolved-FSI write scopes are quiet unless an active lane needs
the split to proceed.

Owned write scope:

- One dependency family per worker:
  - Gridap native/stokes/fsi surfaces
  - HDF5/EzXML resolved-3D I/O and writer surfaces
  - YAML/OpenBF surfaces
  - SciML surfaces
- `Project.toml`, `src/StenoticHemodynamics.jl`, and related adapter/workflow
  files only for that dependency family

Implementation:

1. Narrow dependency-specific imports to adapter/workflow seams.
2. Introduce package extensions only one dependency family at a time.
3. Preserve public workflow and CLI names.

Validation:

- Package-load smoke.
- Focused dependency-surface tests.

## Dispatch Order

1. Run Step 0 preflight.
2. Assign Lane 2H as the critical path.
3. In parallel with 2H, assign either one Lane 3B worker or one Lane 3C worker
   only if the write lock is disjoint.
4. Review 2H before starting 2I.
5. Start 2I only after 2H writes and reloads a stable three-field
   Navier-Stokes smoke bundle.
6. Start 2J after 2I, or split out pressure-operator parity earlier only if it
   avoids solver files.
7. Run Lane 3A after native resolved-FSI write scopes are quiet.
8. Finish with one `git diff --check -- packages/stenotic-hemodynamics` and, if
   the round touched includes or multiple surfaces, one `pipenv run
   ops-julia-check`.
