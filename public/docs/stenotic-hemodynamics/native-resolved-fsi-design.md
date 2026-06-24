# Native Resolved-FSI Design Boundary

This public page is the authoritative copy of the native resolved-FSI design
boundary. The package-local note at
`packages/stenotic-hemodynamics/docs/native_resolved_fsi_design.md` now remains
only as a pointer stub. Use [StenoticHemodynamics Workflow Hub](workflows.md)
for the surrounding workflow map and validation entrypoints.

This note records the current implementation boundary for the native
resolved-FSI roadmap. It is implementation-facing only. It does not claim that
the package reproduces Section 4.1 numerically at paper grade.

Scope for this boundary:

- define the local Julia backend and solver tiers;
- define the membrane model and prescribed radial wall-velocity coupling
  contract used by the current partitioned smoke tier;
- define the velocity/pressure/displacement output contract and production
  sidecars;
- identify restart metadata, production dry-run, observation artifacts, and
  deferred surfaces without widening them into public CLI or paper-grade
  reproduction claims.

## Current implementation tiers

The implemented native resolved-FSI surface is split into these tiers:

| Tier | Current role | Claim boundary |
| --- | --- | --- |
| Schema workflow | `run_native_resolved_fsi_workflow(...)` writes a generated three-field bundle from `NativeResolvedFSIMesh` and reloads it through the retained resolved-3D importer. | Schema, geometry, time, field, and deformed-coordinate importer checks only. |
| Fixed-wall smoke | `run_native_resolved_fsi_smoke(...)` and `run_native_resolved_fsi_navier_stokes_smoke(...)` run coarse fixed-wall Gridap smoke solves and write zero displacement. | Solver-backed smoke and importer round trip, not moving-wall FSI. |
| Partitioned smoke | `run_native_resolved_fsi_partitioned_smoke(...)` updates a reduced radial membrane state and prescribes radial wall-velocity Dirichlet data on the fluid wall. | Coarse staggered smoke with prescribed wall velocity; not monolithic ALE. |
| Production dry-run | `native_resolved_fsi_partitioned_production_dry_run(...)` resolves output, sidecar, restart, and imported-parity paths without running a solver or writing files. | Side-effect-free planning only. |
| Production sidecars | `run_native_resolved_fsi_partitioned_production(...)` advances one state-carrying partitioned snapshot series within a run and writes importer-compatible snapshot bundles, `snapshot_manifest.csv`, `snapshot_diagnostics.csv`, `restart_metadata.json`, and schema-v3 durable checkpoint sidecars. | Production-control and diagnostics harness with in-run state carry and qualified internal split-run resume; monolithic ALE coupling, public/default resume, and paper-grade reproduction remain deferred. |
| Restart metadata | `native_resolved_fsi_read_restart_metadata(...)` validates current and legacy package-written restart metadata, including versioned `state_payload` audit data and schema-v3 durable checkpoints when present. | Schema-v3 checkpoints support qualified internal split-run resume only; `native_resolved_fsi_resume_partitioned_production(...)` still fails closed for public callers. |
| Observation artifacts | Production parity writes `section41_observations.csv` and `section41_observation_summary.csv`. | Local velocity/pressure observation evidence and optional imported-bundle comparison, not a paper-grade reproduction claim. |

External importer support is retained. Legacy or explicitly supplied
XDMF/HDF5 resolved-3D bundles still enter through the existing importer and
remain skip-safe when optional local data is absent.

## Locked design choices

| Item | Choice | Reason |
| --- | --- | --- |
| Spatial backend | Gridap on the package-owned `NativeResolvedFSIMesh` contract | Gridap is the only local 3D FE stack already used in package code, especially in `adapters/stokes_ic.jl`. It already proves P2/P1 spaces, weak outlet traction, and package-owned tetrahedral model construction. |
| Time advancement | Package-owned fixed-step loop | The native resolved-FSI state mixes FE fields, wall state, mesh deformation, writer cadence, and output guards. A local fixed-step loop is easier to reason about than wrapping the current coupled version in `OrdinaryDiffEq`. |
| Fixed-wall target | Fixed-wall 3D Stokes and incompressible Navier-Stokes smoke | This exercises the native mesh, Gridap model build, time loop, and three-field writer without pretending that full transient moving-wall FSI is solved. |
| Coupled strategy | Partitioned, staggered fluid solve plus radial membrane update | This is the smallest local extension from the existing stationary-Stokes and membrane surrogate surfaces. A monolithic moving-domain weak form remains deferred. |
| Deferred approach | Monolithic transient ALE FSI | No local code currently owns a coupled 3D Jacobian, moving-domain transfer, or monolithic solve path. |

Interpretation:

- The schema workflow, fixed-wall smoke, partitioned smoke, production dry-run,
  restart reader/schema-v3 checkpoint validator, qualified internal resume
  controls, and observation summary CSV surfaces are implemented as qualified
  Julia-internal workflows.
- Public CLI exposure remains intentionally narrow in this round:
  `cli/dispatch.jl` exposes only `fsi native-status` for dry-run/status
  reporting. Native resolved-FSI production, restart/resume, parity execution,
  and observation-artifact generation remain qualified Julia-internal surfaces.
- The production tier carries partitioned state through one requested snapshot
  schedule within a run and now writes schema-v3 durable checkpoint sidecars.
  Qualified internal split-run resume can continue from those checkpoints into
  a forked output root, but public/default resume remains closed.
- The moving-wall tier remains partitioned and smoke-backed, not monolithic.

## Backend decision

### Why Gridap is the first backend

Local evidence supports Gridap as the first backend:

- `adapters/stokes_ic.jl` already builds an unstructured tetrahedral
  `UnstructuredDiscreteModel` from package-owned coordinates and topology.
- The same adapter already uses Taylor-Hood style spaces, point evaluation, and
  weak outlet traction in local units.
- The native mesh surface already provides a backend-agnostic linear
  tetrahedral contract, so the Gridap-facing surface can stay thin and
  additive.
- The node-centered writer contract is already established, so the FE solve
  only has to sample fields at the mesh vertices before writing.

Local alternatives are weaker for the first round:

- a hand-rolled tetrahedral FE stack would introduce a second research surface
  with no local precedent;
- a monolithic `OrdinaryDiffEq`-centered design would still need Gridap or an
  equivalent FE layer for the spatial solve, while making the first moving-mesh
  state harder to guard and write deterministically.

## First solver target and staging

### Stage 0: schema workflow

The schema workflow generates a tiny bundle with:

- reference coordinates and topology from `NativeResolvedFSIMesh`;
- synthetic velocity and pressure arrays;
- displacement set either to zero or to a deterministic analytic lift used only
  to test the writer/importer contract.

This is a schema gate only. It uses the same importer contract as external
resolved-3D data, with pressure and displacement required for native generated
bundles.

### Stage 1: fixed-wall smoke

The fixed-wall smoke tier runs before any wall coupling.

Smoke target:

- coarse 3D Stokes and incompressible Navier-Stokes smoke solves on the native
  Section 4.1 mesh;
- fixed wall, so the fluid domain is the reference mesh;
- pressure-drop-driven weak boundary loading in the current Gridap smoke
  harness;
- output at the requested saved time, with displacement written as the zero
  vector field.

This stage is successful when the workflow can:

1. build the Gridap model from `NativeResolvedFSIMesh`;
2. advance at least one stable time step on a coarse smoke mesh;
3. write node-centered velocity, pressure, and zero displacement;
4. reload those files through `load_resolved3d_field_bundle(...)`.

### Stage 2: partitioned smoke with prescribed radial wall velocity

The first wall-coupled target is a partitioned staggered smoke solve. It repeats
fluid solves on the currently deformed domain and updates a reduced radial
membrane state; it is not a monolithic ALE formulation.

1. advance the fluid step on the current geometry;
2. sample the wall pressure load from that fluid state;
3. update the radial membrane state;
4. lift the radial wall state into a volumetric displacement field;
5. prescribe the reduced wall velocity as radial wall-velocity Dirichlet data
   on the fluid wall;
6. rebuild the geometry for the next macro step from the reference coordinates
   plus the lifted displacement.

This is still a research infrastructure step. It is not a claim of monolithic
paper-grade transient FSI.

### Stage 3: production sidecars and observation artifacts

The production-oriented tier is a control and artifact harness around one
state-carrying partitioned snapshot series:

- `native_resolved_fsi_partitioned_production_dry_run(...)` resolves snapshot
  bundle paths, sidecar paths, imported parity availability, and estimated
  payload without writing files.
- `run_native_resolved_fsi_partitioned_production(...)` advances the partitioned
  state through the requested snapshot schedule and writes importer-compatible
  velocity/pressure/displacement bundles, `snapshot_manifest.csv`,
  `snapshot_diagnostics.csv`, `restart_metadata.json`, and schema-v3
  checkpoint sidecars under `checkpoint/`.
- `native_resolved_fsi_read_restart_metadata(...)` validates current and legacy
  restart metadata, including versioned `state_payload` audit metadata and
  schema-v3 durable checkpoint sidecars when present. Qualified internal
  resume can continue a split production run into a forked output root;
  `native_resolved_fsi_resume_partitioned_production(...)` validates metadata
  and then fails closed for public callers.
- Production parity writes `section41_observations.csv` and
  `section41_observation_summary.csv` using the local cross-section velocity
  and pressure observation operators.

## Fluid model

### Unknowns and spaces

The current fluid solves use:

- velocity `u(x,t)` and pressure `p(x,t)` as the primary unknowns;
- Taylor-Hood `P2/P1` spaces on the linear tetrahedral mesh, matching the local
  Gridap precedent in `adapters/stokes_ic.jl`.

The writer contract remains node-centered, so the exported arrays are sampled at
the linear mesh vertices, not written in FE-DOF order.

### Weak form

The current Navier-Stokes step uses backward Euler in time with Picard
linearization of convection:

```text
rho ((u^(n+1) - u^n) / dt, v)
+ rho ((u^k . grad) u^(n+1), v)
+ (2 mu eps(u^(n+1)), eps(v))
- (p^(n+1), div(v))
+ (q, div(u^(n+1)))
= 0
```

with:

- `rho = p.rho` in `g/cm^3`;
- `mu = p.rho * p.nu` in `g/(cm*s)`.

For the fixed-wall smoke tier the domain is the fixed reference mesh. For the
partitioned smoke tier the same weak form is solved on the current displaced
geometry, but the writer still exports the original reference coordinates plus
the displacement field.

The native Navier-Stokes adapter records the Gridap quadrature degree used for
the assembled operator and a higher-degree assembly comparison in
`solver_diagnostics`. That comparison is a sensitivity diagnostic only; it does
not claim quadrature convergence, solver equivalence, or a stronger numerical
method.

### Boundary conditions

The paper boundary data and current execution evidence are deliberately kept
separate. Section 4.1 states a Poiseuille inlet with `u_max = 45 cm/s` and zero
outlet stress. The default Gridap smoke path still uses pressure-drop-driven
weak boundary loading and records that as local implementation evidence. The
low-level Gridap/native production harness also carries an internal exact mode,
`poiseuille_inlet_zero_outlet_stress_section41`, and the tiny partitioned
production harness can thread that mode through for smoke-scale/operator-readiness
evidence. Neither path should be described as a validated paper-grade
boundary-condition reproduction.

The current wall boundary modes are:

- wall, smoke stage: `u = 0`;
- wall, partitioned smoke: radial wall-velocity Dirichlet data from the
  reduced membrane velocity, implemented through
  `native_resolved_fsi_radial_wall_velocity_function(...)`.
- wall, exact Section 4.1 production harness: stationary no-slip wall solves
  on deformed geometry while the reduced membrane update advances the next
  geometry; this is not a strong moving-wall fluid-boundary or monolithic ALE
  claim.

The current inlet/outlet realizations are:

- smoke evidence path: pressure-drop-driven weak loading in the fixed-wall and
  partitioned smoke harnesses;
- exact Section 4.1 internal mode: strong Poiseuille inlet with
  `u_max = 45 cm/s` plus zero outlet stress, threaded through the tiny
  partitioned production harness for operator-readiness evidence only.

The native Navier-Stokes adapter also records outlet normal-velocity diagnostics
in `solver_diagnostics`: outlet node count, fallback sampling count, backflow
node count, and min/max/mean sampled outlet normal velocity. These diagnostics
classify the current open-boundary evidence and possible backflow at sampled
mesh nodes only. They do not add convective-outflow stabilization and do not
turn either boundary mode into validated Section 4.1 parity.

The partitioned target must not reinterpret the 1D characteristic outlet as a
3D outlet condition or present either current internal path as validated
Section 4.1 parity.

## Membrane model

### Structural state

The current membrane model is an axisymmetric radial membrane surrogate on the
native axial stations:

- radial displacement `eta(z,t)` in `cm`;
- radial wall velocity `weta(z,t) = d eta / dt` in `cm/s`.

The wall state is stored on the axial coordinates already present in
`NativeResolvedFSIGeometry.axial_coordinates_cm`. It is constant in `theta` at
each axial station in the partitioned smoke tier.

### Parameters

The current membrane model uses:

- wall density `rho_s = 1.055 g/cm^3`;
- wall thickness `h = p.wall_h = 0.06 cm`;
- Young modulus `E = p.young = 5.02e6 dyn/cm^2`;
- Poisson ratio `sigma = p.sigma = 0.5`;
- optional numerical damping coefficient `c_m` in
  `g/(cm^2*s)`, default `0.0`.

The stiffness scale is the package-local linear membrane coefficient

```text
C0 = E h / ((1 - sigma^2) R_ref^2)
```

with `R_ref = wall_reference_radius(p) = p.rmax` for the current implementation.
This matches the current local `canic_membrane_c0(...)` convention. It is a
local implementation choice, not a claim that the exact paper-side `R0*`
constant has already been identified.

### Governing update

The membrane update is the clamped radial ODE

```text
rho_s h eta_tt + c_m eta_t + C0 eta = p_wall - p_ext
```

with:

- `p_ext = 0` gauge pressure;
- clamped ends `eta(0,t) = eta(L,t) = 0`;
- clamped end velocities `eta_t(0,t) = eta_t(L,t) = 0`.

The partitioned smoke target does not add axial shell tension or a full surface
membrane PDE. That would be a later expansion and should not be implied by the
current implementation.

### Coupling terms

Fluid to wall:

- circumferentially averaged wall pressure sampled slightly inside the wall,
  following the local guarded sampling pattern already used in
  `membrane_wall_pressure_profile(...)`;
- wall shear stress is not included in the current membrane RHS.

Wall to fluid:

- wall displacement changes the geometry for the next macro step;
- wall velocity supplies the prescribed radial wall Dirichlet condition on the
  moved wall.

## Volumetric displacement convention

The package needs a node-centered displacement field even though the wall state
is axisymmetric. The current export convention is:

```text
d(r, theta, z, t) = chi(r / R_ref_geom(z)) eta(z,t) e_r
chi(xi) = xi
```

where:

- `R_ref_geom(z)` is the reference wall radius from the native Section 4.1
  geometry;
- `e_r` is the cylindrical radial unit vector;
- centerline nodes remain fixed because `chi(0) = 0`;
- wall nodes match the membrane state exactly because `chi(1) = 1`.

This is a package-owned lifting convention for writing and geometry updates. It
is not stated by the paper.

## Time integration and guards

### Time integration

Fluid:

- backward Euler in physical time;
- Picard iteration for convection on each step;
- package-owned fixed-step loop, with `dt_s` carried explicitly in the native
  spec.

Membrane:

- semi-implicit reduced radial wall update for `eta` and `weta`, following the
  same local stability model as the current `DynamicMembraneMode`;
- clamped endpoints enforced after every wall update.

Partitioned coupling:

- staggered one-way sequence inside each macro step:
  fluid -> wall load -> wall update -> geometry update;
- optional displacement under-relaxation `omega in (0, 1]` for the partitioned
  smoke stage.

### Stability guards

The implementation enforces these guards across smoke and production specs:

1. `dt_s > 0`.
2. `max_picard_iterations >= 1`.
3. Picard relative-change tolerance `picard_rtol > 0`, with first acceptance at
   `1e-6`.
4. Partitioned coupling tolerance `coupling_tol_cm > 0`, with first acceptance
   at `1e-6 cm`.
5. Explicit membrane stability guard
   `dt_s <= 1.9 * sqrt((rho_s * h) / C0_max)`.
6. No negative or zero current radius anywhere along the wall.
7. No inverted tetrahedra after applying the lifted displacement to the
   reference mesh coordinates.
8. All written field values must be finite.

### Output-volume guards

Default output policy:

- write only the final requested benchmark snapshot by default;
- production runner snapshots must be positive; `t = 0` initial-condition
  bundle output remains unimplemented.

Hard guards:

- reject unsorted or repeated `snapshot_times_s`;
- reject any `snapshot_times_s` outside `[0, tfinal_s]`;
- reject output requests with more than `50` saved snapshots unless an explicit
  large-output override is set;
- reject output requests whose estimated raw field payload exceeds `1 GiB`.

Estimate field payload as:

```text
bytes ~= snapshot_count * node_count * 7 * 8
```

for `3` velocity components, `1` pressure value, and `3` displacement
components per node.

## Output contract at each saved time

Each saved time step writes one importer-compatible bundle through
`write_resolved3d_field_bundle(...)` with:

- reference coordinates from `NativeResolvedFSIMesh.coordinates`;
- topology from `NativeResolvedFSIMesh.topology`;
- node-centered velocity sampled from the FE velocity field at every reference
  mesh vertex;
- node-centered pressure sampled from the FE pressure field at every reference
  mesh vertex;
- node-centered displacement from the lifted membrane state at every reference
  mesh vertex.

Pressure normalization:

- subtract the arithmetic mean pressure on the outlet boundary nodes before
  writing so the exported field is outlet-gauge pressure.

Staged displacement treatment:

- workflow skeleton: either zero displacement everywhere or a deterministic
  synthetic lift used only for writer/importer validation;
- fixed-wall smoke: zero displacement everywhere;
- coupled stage: lifted radial displacement field from `eta(z,t)`.

The importer-facing contract therefore stays:

```text
x_deformed = x_reference + displacement
```

and `coordinate_mode=deformed` remains valid at every saved step.

## Implemented files

The current implementation lives on these source surfaces:

| File | Role |
| --- | --- |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi.jl` | Always-present aggregator for the native resolved-FSI adapter family. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_types.jl` | Fixed-wall and partitioned smoke specs, results, validation, writer round trips, and status construction. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl` | `NativeResolvedFSIMesh` to Gridap model conversion, FE spaces, weak forms, prescribed radial wall-velocity helper, and smoke solves. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_partitioned.jl` | Partitioned smoke wall update, pressure sampling, lifted-geometry solve orchestration, and reduced wall-state output. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_sampling.jl` | Node sampling, fallback sampling, and outlet gauge normalization for smoke bundles. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_roundtrip.jl` | Resolved-3D writer/importer round-trip checks for schema and smoke bundles. |
| `src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_workflow.jl` | Schema workflow spec construction, scratch output planning, synthetic fields, displacement lift, and writer round trip. |
| `src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_workflow_production.jl` | Partitioned production spec policy, production dry-run, state-carrying in-run snapshot runner, manifest, diagnostics, and restart metadata writer. |
| `src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_restart.jl` | Current and legacy restart-metadata reader, schema-v3 durable checkpoint validation, qualified internal resume context builder, and public fail-closed resume API. |
| `src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_parity.jl` | Native/imported three-field parity and observation operators. |
| `src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_parity_production.jl` | Production observation artifact and summary CSV writer, including `section41_observation_summary.csv`. |

This keeps the native resolved-FSI surface additive and avoids repurposing
`stokes_ic.jl` or the membrane validation workflow into something stronger
than they are.

## Implemented structs

The current public-by-qualification contract centers on these structs:

- `NativeResolvedFSIWorkflowSpec` / `NativeResolvedFSIWorkflowResult`:
  schema-only generated bundle and importer round-trip contract.
- `NativeResolvedFSISmokeSpec` / `NativeResolvedFSISmokeResult`:
  fixed-wall Stokes smoke bundle contract.
- `NativeResolvedFSINavierStokesSmokeSpec` /
  `NativeResolvedFSINavierStokesSmokeResult`: fixed-wall Navier-Stokes smoke
  contract with backward-Euler/Picard controls.
- `NativeResolvedFSIPartitionedSmokeSpec` /
  `NativeResolvedFSIPartitionedSmokeResult`: partitioned smoke contract with
  reduced wall state, prescribed radial wall velocity, diagnostics, and
  deformed-geometry output.
- `NativeResolvedFSIPartitionedProductionSpec` /
  `NativeResolvedFSIPartitionedProductionResult`: production-oriented snapshot
  policy, sidecars, and state-carrying partitioned execution result.
- `NativeResolvedFSIProductionWorkflowPlan` and
  `NativeResolvedFSIProductionDryRunPlan`: deterministic Section 4.1 workflow
  plans and side-effect-free dry-run records.
- `NativeResolvedFSIProductionParityPlan`: pairing between a native production
  plan and an optional imported resolved-3D bundle.

## Workflow entrypoints

The current internal entrypoints are qualified Julia functions, with one narrow
status-only CLI surface:

- `run_native_resolved_fsi_workflow(...)` and
  `run_native_resolved_fsi(...)` for schema-only generated bundles.
- `run_native_resolved_fsi_smoke(...)` and
  `run_native_resolved_fsi_navier_stokes_smoke(...)` for fixed-wall smoke.
- `run_native_resolved_fsi_partitioned_smoke(...)` for the partitioned
  prescribed radial wall-velocity smoke tier.
- `native_resolved_fsi_zero_displacement(...)` and
  `native_resolved_fsi_lifted_displacement(...)` for deterministic displacement
  fields.
- `native_resolved_fsi_production_workflow_plans(...)`,
  `native_resolved_fsi_partitioned_production_dry_run(...)`, and
  `run_native_resolved_fsi_partitioned_production(...)` for production planning
  and state-carrying partitioned snapshot sidecars.
- `native_resolved_fsi_read_restart_metadata(...)` and
  `native_resolved_fsi_resume_partitioned_production(...)` for
  restart-identification metadata validation and public fail-closed resume;
  qualified internal production-run controls can resume schema-v3 checkpoints
  into a forked output root.
- `run_native_resolved_fsi_parity(...)` for native/imported observation and
  parity artifacts.
- `fsi native-status` for dry-run/status reporting only; it does not run
  production and does not write solver outputs.

No CLI path exposes native resolved-FSI production execution, restart/resume,
parity execution, or observation-artifact generation in this round.

## Tests and acceptance tolerances

The current narrow tests are:

| Test file | Purpose | First acceptance tolerance |
| --- | --- | --- |
| `test/test_native_resolved_fsi_workflow.jl` | Schema workflow, production spec policy, dry-run, production sidecars, schema-v3 restart metadata reader, qualified internal split-run resume, and public fail-closed resume | coordinates/topology exact; time `atol=1e-12`; sidecars present; resumed fork preserves parent rows and public resume error remains explicit |
| `test/test_native_resolved_fsi_smoke.jl` | Fixed-wall Stokes/Navier-Stokes smoke and partitioned prescribed radial wall-velocity smoke | all fields finite; saved final time `atol=1e-12`; fixed-wall displacement zero; partitioned wall displacement and velocity nonzero away from clamped endpoints; no inverted tetrahedra |
| `test/test_native_resolved_fsi_parity.jl` | Native/imported parity contracts and Section 4.1 observation artifact CSVs | operator rows sorted and finite where ready; absent optional imported bundles produce expected skips |

The paper-backed velocity statement remains a benchmark context, not a current
pass/fail production claim:

- maximum relative error in the longitudinal velocity curve within `10%`.

The current observation artifacts record velocity and pressure section
averages and differences. A paper-grade pressure parity tolerance remains a
later local choice.

## Reuse and separation

### Reuse directly

The implementation reuses these existing surfaces or patterns:

- `NativeResolvedFSIMesh`, `NativeResolvedFSIGeometry`, and the stable tag
  contract from `workflows/native_resolved_fsi/native_resolved_fsi_mesh.jl`;
- `Resolved3DWriterPaths`, `Resolved3DWriterResult`, and
  `write_resolved3d_field_bundle(...)` from `adapters/resolved3d_writer.jl`;
- `wall_stiffness(...)`, `wall_reference_radius(...)`, and
  `canic_membrane_c0(...)` as the local stiffness reference;
- `clamp_membrane_endpoints!`, `should_capture_membrane_history(...)`, and the
  history-row pattern from the existing membrane adapter;
- guarded pressure sampling and gauge normalization patterns from the local
  Gridap and smoke sampling adapters;
- the `GeneratedStokesMesh` to Gridap model construction pattern in
  `stokes_ic.jl` as a template for the new native mesh adapter;
- `safe_section_average_pressure(...)` as the local numerical pattern for later
  pressure-observation parity work.

### Keep separate

These existing surfaces must remain separate from the native resolved-FSI
claim:

- `solve_membrane_fsi(...)`, `QuasiStaticMembraneMode`, and
  `DynamicMembraneMode` remain a stationary-Stokes-based wall surrogate;
- `membrane_fsi_validation` remains a validation workflow, not the native
  generator;
- `StationaryStokesIC` and `project_stationary_stokes(...)` remain reduced-1D
  initial-condition machinery;
- `generated_stokes_mesh(...)` remains separate from the native resolved-FSI
  mesh contract.

## Remaining deferred items

These items remain open and should not be implied by current documentation:

- whether a later paper-parity stage needs outlet-node mean or
  outlet-quadrature mean for pressure gauge normalization;
- whether later paper-parity calibration should replace `R_ref = p.rmax` with a
  different constant `R0*`.
- public/default process resume from restart metadata;
- production-scale restart/resume validation and any claim promotion from
  schema-v3 checkpoints;
- public CLI exposure beyond the status-only `fsi native-status` surface for
  native resolved-FSI production, restart/resume, parity, or
  observation-artifact workflows;
- paper-grade transient Section 4.1 reproduction.

## Blockers

No documentation blocker remains for the implemented schema, smoke, production
dry-run, restart metadata, sidecar, and observation-artifact tiers. The design
intentionally defers monolithic moving-wall FSI, public/default process resume,
CLI surfaces beyond `fsi native-status`, production-scale resume claim
promotion, and paper-grade reproduction claims instead of presenting the
current qualified-internal harness as those stronger surfaces.
