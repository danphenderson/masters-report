# Native Resolved-FSI First-Implementation Design Gate

This note locks the first implementation design for the native resolved-FSI
roadmap after the Lane 2A spec, Lane 2B mesh contract, and Lane 2C writer
contract. It is implementation-facing only. It does not claim that the package
already reproduces the paper numerically.

Scope for this gate:

- choose the first local Julia backend and the first solver target;
- define the first membrane model and coupling contract;
- define the staged velocity/pressure/displacement output contract;
- name the first files, structs, workflow entrypoints, tests, and guards for
  the next implementation lanes.

## Locked design choices

| Item | Choice | Reason |
| --- | --- | --- |
| Spatial backend | Gridap on the package-owned `NativeResolvedFSIMesh` contract | Gridap is the only local 3D FE stack already used in package code, especially in `adapters/stokes_ic.jl`. It already proves P2/P1 spaces, weak outlet traction, and package-owned tetrahedral model construction. |
| Time advancement | Package-owned fixed-step loop | The first native resolved-FSI state mixes FE fields, wall state, mesh deformation, writer cadence, and output guards. A local fixed-step loop is easier to reason about than wrapping the first coupled version in `OrdinaryDiffEq`. |
| First implementation target | Fixed-wall 3D incompressible Navier-Stokes smoke | This is the smallest honest next patch after mesh plus writer. It exercises the native mesh, Gridap model build, time loop, and three-field writer without pretending that full transient moving-wall FSI is already solved. |
| First coupled strategy | Partitioned, staggered fluid solve plus radial membrane update | This is the smallest local extension from the existing stationary-Stokes and membrane surrogate surfaces. A monolithic moving-domain weak form is too large for the next patch. |
| Deferred approach | Monolithic transient ALE FSI | No local code currently owns a coupled 3D Jacobian, moving-domain transfer, or monolithic solve path. That work should follow only after the partitioned path proves the field contract. |

Interpretation for next lanes:

- Lane 2E may build the workflow skeleton and tiny three-field writer round-trip
  from this design immediately.
- Lane 2F should start with the fixed-wall smoke target below.
- The first moving-wall step after smoke is partitioned and staged, not
  monolithic.

## Backend decision

### Why Gridap is the first backend

Local evidence supports Gridap as the first backend:

- `adapters/stokes_ic.jl` already builds an unstructured tetrahedral
  `UnstructuredDiscreteModel` from package-owned coordinates and topology.
- The same adapter already uses Taylor-Hood style spaces, point evaluation, and
  weak outlet traction in local units.
- Lane 2B already produced a backend-agnostic linear tetrahedral mesh contract,
  so the Gridap-facing surface can stay thin and additive.
- Lane 2C already produced the node-centered writer contract, so the FE solve
  only has to sample fields at the mesh vertices before writing.

Local alternatives are weaker for the first round:

- a hand-rolled tetrahedral FE stack would introduce a second research surface
  with no local precedent;
- a monolithic `OrdinaryDiffEq`-centered design would still need Gridap or an
  equivalent FE layer for the spatial solve, while making the first moving-mesh
  state harder to guard and write deterministically.

## First solver target and staging

### Stage 0: workflow skeleton

Lane 2E may generate a tiny synthetic bundle with:

- reference coordinates and topology from `NativeResolvedFSIMesh`;
- synthetic velocity and pressure arrays;
- displacement set either to zero or to a deterministic analytic lift used only
  to test the writer/importer contract.

This is a schema gate only.

### Stage 1: fixed-wall smoke

Lane 2F should implement a fixed-wall smoke solve before any wall coupling.

Smoke target:

- 3D incompressible Navier-Stokes on the native Section 4.1 mesh;
- fixed wall, so the fluid domain is the reference mesh;
- constant Poiseuille inlet with `u_max = 45 cm/s`;
- zero outlet traction;
- output at the requested saved times, with displacement written as the zero
  vector field.

This stage is successful when the workflow can:

1. build the Gridap model from `NativeResolvedFSIMesh`;
2. advance at least one stable time step on a coarse smoke mesh;
3. write node-centered velocity, pressure, and zero displacement;
4. reload those files through `load_resolved3d_field_bundle(...)`.

### Stage 2: first coupled target

After the smoke stage passes, the first wall-coupled target is a partitioned
staggered solve:

1. advance the fluid step on the current geometry;
2. sample the wall pressure load from that fluid state;
3. update the radial membrane state;
4. lift the radial wall state into a volumetric displacement field;
5. rebuild the geometry for the next macro step from the reference coordinates
   plus the lifted displacement.

This is still a research infrastructure step. It is not a claim of monolithic
paper-grade transient FSI.

## Fluid model

### Unknowns and spaces

The first fluid solve should use:

- velocity `u(x,t)` and pressure `p(x,t)` as the primary unknowns;
- Taylor-Hood `P2/P1` spaces on the linear tetrahedral mesh, matching the local
  Gridap precedent in `adapters/stokes_ic.jl`.

The writer contract remains node-centered, so the exported arrays are sampled at
the linear mesh vertices, not written in FE-DOF order.

### Weak form

The first fluid step should use backward Euler in time with Picard
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

For the smoke stage the domain is the fixed reference mesh. For the first
coupled stage the same weak form is solved on the current displaced geometry,
but the writer still exports the original reference coordinates plus the
displacement field.

### Boundary conditions

Fluid boundary conditions are locked as:

- inlet: strong Dirichlet Poiseuille profile with axial component
  `u_z(r) = 45 * (1 - (r / R_in)^2) cm/s`;
- wall, smoke stage: `u = 0`;
- wall, coupled stage: `u = d_t` on wall nodes, where `d_t` is the lifted wall
  displacement time derivative;
- outlet: natural zero traction
  `(-p I + 2 mu eps(u)) n = 0`.

The first coupled target must not reinterpret the 1D characteristic outlet as a
3D outlet condition.

## Membrane model

### Structural state

The first membrane model is an axisymmetric radial membrane surrogate on the
native axial stations:

- radial displacement `eta(z,t)` in `cm`;
- radial wall velocity `weta(z,t) = d eta / dt` in `cm/s`.

The wall state is stored on the axial coordinates already present in
`NativeResolvedFSIGeometry.axial_coordinates_cm`. It is constant in `theta` at
each axial station in the first coupled target.

### Parameters

The first membrane model uses:

- wall density `rho_s = 1.055 g/cm^3`;
- wall thickness `h = p.wall_h = 0.06 cm`;
- Young modulus `E = p.young = 5.02e6 dyn/cm^2`;
- Poisson ratio `sigma = p.sigma = 0.5`;
- optional numerical damping coefficient `c_m` in
  `g/(cm^2*s)`, default `0.0`.

The first stiffness scale is the package-local linear membrane coefficient

```text
C0 = E h / ((1 - sigma^2) R_ref^2)
```

with `R_ref = wall_reference_radius(p) = p.rmax` for the first implementation.
This matches the current local `canic_membrane_c0(...)` convention. It is a
local implementation choice, not a claim that the exact paper-side `R0*`
constant has already been identified.

### Governing update

The first membrane update is the clamped radial ODE

```text
rho_s h eta_tt + c_m eta_t + C0 eta = p_wall - p_ext
```

with:

- `p_ext = 0` gauge pressure;
- clamped ends `eta(0,t) = eta(L,t) = 0`;
- clamped end velocities `eta_t(0,t) = eta_t(L,t) = 0`.

The first coupled target does not add axial shell tension or a full surface
membrane PDE. That would be a later expansion and should not be implied by the
first patch.

### Coupling terms

Fluid to wall:

- circumferentially averaged wall pressure sampled slightly inside the wall,
  following the local guarded sampling pattern already used in
  `membrane_wall_pressure_profile(...)`;
- wall shear stress is not included in the first membrane RHS.

Wall to fluid:

- wall displacement changes the geometry for the next macro step;
- wall velocity supplies the no-slip boundary condition on the moved wall.

## Volumetric displacement convention

The package needs a node-centered displacement field even though the first wall
state is axisymmetric. Lane 2D locks the following export convention:

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

- explicit second-order update using `eta` and `weta`, following the same local
  stability model as the current `DynamicMembraneMode`;
- clamped endpoints enforced after every wall update.

Partitioned coupling:

- staggered one-way sequence inside each macro step:
  fluid -> wall load -> wall update -> geometry update;
- optional displacement under-relaxation `omega in (0, 1]` for the first
  moving-wall stage.

### Stability guards

The next implementation lane should enforce these guards:

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
- smoke tests may additionally save `t = 0` when explicitly requested.

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

## Proposed files

The first implementation lane should add or update only the following source
surfaces:

| File | Role |
| --- | --- |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi.jl` | Always-present aggregator for the native resolved-FSI adapter family. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_types.jl` | Typed solver, wall, coupling, output, and result contracts. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl` | `NativeResolvedFSIMesh` to Gridap model conversion, FE spaces, weak forms, and node sampling helpers. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_membrane.jl` | Axisymmetric wall state, clamped update, pressure-load reduction, and volumetric displacement lift. |
| `src/StenoticHemodynamics/adapters/native_resolved_fsi_solve.jl` | Fixed-step smoke loop first, then partitioned moving-wall macro step orchestration. |
| `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow.jl` | Workflow-facing spec construction, scratch output planning, and writer round-trip orchestration. |

This keeps the new surface additive and avoids repurposing `stokes_ic.jl` or the
current membrane validation workflow into something stronger than they are.

## Proposed structs

The first implementation lane should introduce these structs:

- `NativeResolvedFSISpec`:
  case id, mesh resolution, `dt_s`, `tfinal_s`, saved times, output directory,
  and stage selection.
- `NativeResolvedFSIFluidOptions`:
  Picard controls, FE order choice, and outlet pressure normalization policy.
- `NativeResolvedFSIMembraneOptions`:
  `rho_s`, `h`, `E`, `sigma`, `c_m`, reference radius policy, and endpoint
  clamp policy.
- `NativeResolvedFSICouplingOptions`:
  wall-update mode, under-relaxation, coupling tolerance, and iteration cap.
- `NativeResolvedFSIOutputOptions`:
  snapshot times, overwrite, and output-volume guards.
- `NativeResolvedFSIState`:
  current time, FE solution, `eta`, `weta`, current displacement lift, and
  current geometry status.
- `NativeResolvedFSIResult`:
  saved snapshot metadata, writer results, convergence metadata, and any guard
  failures.

## Workflow entrypoints

The first implementation lane should expose these internal entrypoints:

- `run_native_resolved_fsi(spec::NativeResolvedFSISpec)`:
  main workflow runner.
- `native_resolved_fsi_smoke_spec(case_id; kwargs...)`:
  convenience constructor for the fixed-wall smoke stage.
- `native_resolved_fsi_zero_displacement(mesh::NativeResolvedFSIMesh)`:
  deterministic smoke-stage displacement helper.
- `native_resolved_fsi_lifted_displacement(mesh::NativeResolvedFSIMesh, eta)`:
  volumetric displacement lift for the coupled stage.

Public CLI exposure is not required for the first lane.

## Proposed tests and first acceptance tolerances

Lane 2E / 2F should add the following tests:

| Test file | Purpose | First acceptance tolerance |
| --- | --- | --- |
| `test/test_native_resolved_fsi_workflow.jl` | Tiny bundle write/reload without a production fluid solve | coordinates/topology exact; time and field arrays `atol=1e-12` |
| `test/test_native_resolved_fsi_smoke.jl` | Fixed-wall smoke solve on a coarse mesh plus writer round-trip | all fields finite; saved final time `atol=1e-12`; displacement identically zero `atol=1e-12` |
| `test/test_native_resolved_fsi_partitioned.jl` | First moving-wall partitioned step on a tiny mesh | endpoint clamps `atol=1e-12`; coupling residual `<= 1e-6 cm`; no inverted tetrahedra |

Lane 2G later adds parity tests. The paper-backed velocity target stays:

- maximum relative error in the longitudinal velocity curve within `10%`.

Pressure parity tolerance remains a later local choice and is not required to
start 2E or the first smoke implementation.

## Reuse and separation

### Reuse directly

The next implementation lane may reuse these existing surfaces or patterns:

- `NativeResolvedFSIMesh`, `NativeResolvedFSIGeometry`, and the stable tag
  contract from `workflows/native_resolved_fsi_mesh.jl`;
- `Resolved3DWriterPaths`, `Resolved3DWriterResult`, and
  `write_resolved3d_field_bundle(...)` from `adapters/resolved3d_writer.jl`;
- `wall_stiffness(...)`, `wall_reference_radius(...)`, and
  `canic_membrane_c0(...)` as the local stiffness reference;
- `clamp_membrane_endpoints!`, `should_capture_membrane_history(...)`, and the
  history-row pattern from the existing membrane adapter;
- guarded pressure sampling and gauge normalization patterns from
  `membrane_fsi_gridap.jl`;
- the `GeneratedStokesMesh` to Gridap model construction pattern in
  `stokes_ic.jl` as a template for the new native mesh adapter;
- `safe_section_average_pressure(...)` as the local numerical pattern for later
  pressure-observation parity work.

### Keep separate

The next implementation lane must not present these existing surfaces as the new
native resolved-FSI solver:

- `solve_membrane_fsi(...)`, `QuasiStaticMembraneMode`, and
  `DynamicMembraneMode` remain a stationary-Stokes-based wall surrogate;
- `membrane_fsi_validation` remains a validation workflow, not the native
  generator;
- `StationaryStokesIC` and `project_stationary_stokes(...)` remain reduced-1D
  initial-condition machinery;
- `generated_stokes_mesh(...)` remains separate from the Lane 2B native mesh
  contract.

## Remaining non-blockers

These items remain open but do not block Lane 2E or the first smoke lane:

- whether the first coupled stage needs outlet-node mean or outlet-quadrature
  mean for pressure gauge normalization;
- whether the pressure-observation parity path should extend the existing
  resolved-3D operator family or add a dedicated scalar-field helper;
- whether later paper-parity calibration should replace `R_ref = p.rmax` with a
  different constant `R0*`.

## Blockers

No blocker remains for Lane 2E or for the first fixed-wall smoke
implementation. The design intentionally defers monolithic moving-wall FSI
instead of pretending that it fits in the next patch.
