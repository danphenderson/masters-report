# Section 4.1 Native Resolved-FSI Reproduction Spec

This public page is the authoritative copy of the Section 4.1 native
resolved-FSI reproduction note. The package-local note at
`packages/stenotic-hemodynamics/docs/native_resolved_fsi_reproduction.md` now
remains only as a pointer stub. Use
[StenoticHemodynamics Workflow Hub](workflows.md) for the package workflow map
and [Native Resolved-FSI Design](native-resolved-fsi-design.md) for the current
implementation gate.

This note locks the Section 4.1 benchmark contract from
`public/references/02_report_model_hierarchy/2024_canic_extended_1d_stenotic_artery_model.pdf`
for package lanes 2B, 2C, and 2D. It is grounded in the paper text and figures
on PDF pages 21-24 plus the local importer/comparison code under
`packages/stenotic-hemodynamics/src/StenoticHemodynamics/`.

Scope:

- exact benchmark case geometry and physical constants from the paper;
- the local three-field XDMF/HDF5 contract required by the package;
- explicit separation between paper-given facts, local inferences, and unknowns.

## Section 4.1 cases

Common geometry kernel from Figure 3:

```text
g(z) = z - 3.4 + 0.95 exp(-0.5 (z - 2.5)^2)
K(z) = exp(-50 g(z)^4)
R0(z) = Rmax - delta_r K(z),   z in [0, L] cm
```

Common geometric constants:

- `L = 6 cm`
- `Rmax = 0.18 cm`
- inlet at `z = 0 cm`
- outlet at `z = 6 cm`

Case definitions:

| Native case id | Current imported case_label | Paper label | `delta_r` | `Rmin` at `K(z)=1` | Source status |
| --- | --- | --- | --- | --- | --- |
| `sev23` | `77` | `23% stenosis` | `Rmax - Rmin = 0.0406 cm` | `0.1394 cm` | explicit |
| `sev40` | `60` | `40% stenosis` | `0.4 Rmax = 0.072 cm` | `0.108 cm` | explicit formula + inferred numeric |
| `sev50` | none observed locally | `50% stenosis` | `0.5 Rmax = 0.09 cm` | `0.09 cm` | explicit formula + inferred numeric |

Important local constraint:

- The package's shared analytic profile shape in
  `core/geometry.jl::asymmetric_geometry_terms` matches the paper's `g(z)` and
  `K(z)`.
- For the `23%` case, `Params(severity=23)` is not exact enough for paper
  reproduction. The package interprets severity as
  `delta_r = severity/100 * Rmax`,
  which gives `Rmin = 0.1386 cm`. The paper's explicit `Rmin` is `0.1394 cm`.
- Lanes 2B/2D should therefore treat the `23%` case as an explicit
  `Rmin = 0.1394 cm` or `delta_r = 0.0406 cm` override, not as a plain
  `severity=23` shorthand.

Locally sampled throat reference from the shared analytic shape:

- `z_throat ~ 2.451 cm` for the current sampled `stenosis_throat_z(...)`
  helper. This is a local observation helper, not an explicit paper value.

## Requirement matrix

`Blocker` below means "blocks 2B or 2C from starting." Unknowns that matter
later but do not block mesh or writer work are marked `non-blocker`.

| Requirement | Value or rule | Status | Blocker? | Notes |
| --- | --- | --- | --- | --- |
| Benchmark severities | `23%, 40%, 50%` | explicit | no | Section 4.1 and Figure 3. |
| Vessel length | `L = 6 cm` | explicit | no | Table 1. |
| Baseline radius | `Rmax = 0.18 cm` | explicit | no | Table 1. |
| `23%` throat radius | `Rmin = 0.1394 cm` | explicit | no | Table 1 plus Figure 3 formula. |
| `40%` throat radius | `0.6 Rmax = 0.108 cm` | inferred | no | Numeric value inferred from explicit formula and `Rmax`. |
| `50%` throat radius | `0.5 Rmax = 0.09 cm` | inferred | no | Numeric value inferred from explicit formula and `Rmax`. |
| Fluid density | `rho_f = 1.055 g/cm^3` | explicit | no | Table 1. |
| Fluid viscosity field | `0.04 cm^2/s` | explicit | no | Table 1 labels this `mu_f`, but the unit is kinematic viscosity; map to `Params.nu`. |
| Wall density | `rho_s = 1.055 g/cm^3` | explicit | no | Table 1; maps to membrane density `rho_m` for dynamic wall modes. |
| Wall thickness | `h = 0.06 cm` | explicit | no | Table 1. |
| Poisson ratio | `nu = 0.5` | explicit | no | Table 1; map to package `sigma`. |
| Young modulus | `E = 5.02e6 dyn/cm^2` | explicit | no | Table 1. |
| Inlet condition | Poiseuille inflow with `u_max = 45 cm/s` | explicit | no | Section 4.1 text. Mean inflow is inferred as `22.5 cm/s`. |
| Outlet condition | zero stress `sigma n = 0` at `Gamma_out` | explicit | no | Section 4.1 text. |
| End constraint | artery clamped at both ends, radial deformation allowed | explicit | no | Section 4.1 text. |
| Comparison time | steady-state 3D snapshot at `T = 1 s` | explicit | no | Section 4.1 text. |
| Legacy imported XDMF time | current local cases expect `0.9995 +/- time_atol` | inferred/local | no | From `Resolved3DCaseSpec` defaults and README; keep for importer compatibility only. |
| Published 3D mesh size | around `100k` tetrahedra | explicit | no | Figure 3 caption. |
| Exact tetrahedral generator and grading | not given | unknown | non-blocker | 2B can start with a deterministic package-owned mesh contract. |
| Full 3D solver details from reference `[21]` | not given in Section 4.1 | unknown | non-blocker | 2D must choose a local implementation strategy. |
| Wall displacement state | radial displacement `eta_r` on the structure | explicit | no | Equation (35). |
| Volumetric displacement field over exported mesh | not specified by paper | unknown | non-blocker | Required by package output contract, so 2D must define it locally. |
| Pressure comparison observable | averaged cross-sectional pressure vs. `z` | explicit | no | Section 4.1 text and Figure 5. |
| Velocity comparison observable | averaged cross-sectional longitudinal velocity vs. `z` | explicit | no | Section 4.1 text and Figure 4. |
| Displacement comparison observable | none reported | explicit absence | no | Displacement is a state/output requirement, not a published parity curve in Section 4.1. |
| Velocity parity number | maximum error within `10%` for extended 1D vs 3D longitudinal velocity | explicit | no | Section 4.1 text. |
| Pressure parity number | no numeric tolerance reported | unknown | non-blocker | Only qualitative agreement and mismatch regions are described. |
| Constant wall coefficient radius `R0*` | paper says `C0` uses a constant `R0*`, but value is not stated here | mixed: explicit + unknown | non-blocker | Nearby Section 3.2 fixes `C0` as constant; exact `R0*` choice is not restated in Section 4.1. |

## Package mapping

| Paper quantity | Package unit / contract | Likely package name or surface | Notes |
| --- | --- | --- | --- |
| `L` | `cm` | `Params.length_cm` | Exact match. |
| `Rmax` | `cm` | `Params.rmax` | Exact match. |
| `23/40/50` stenosis label | percent label | `Resolved3DCaseSpec.severity` or native case spec severity field | `sev23`, `sev40`, `sev50` are clearer native ids than legacy `77` / `60`. |
| `Rmin` for `23%` | `cm` | explicit case override, not plain `Params(severity=23)` | Needed for exact paper geometry. |
| `rho_f` | `g/cm^3` | `Params.rho` | Exact match. |
| `mu_f = 0.04 cm^2/s` | `cm^2/s` | `Params.nu` | The table symbol is misleading for local code; use the unit. |
| `E` | `dyn/cm^2` | `Params.young` | Exact match. |
| `nu` (Poisson ratio) | dimensionless | `Params.sigma` | Same physical role, different field name. |
| `h` | `cm` | `Params.wall_h` | Exact match. |
| Poiseuille inlet with `u_max = 45 cm/s` | `cm/s` | `SteadyVelocityInlet(umax=45.0)` or `Params.inlet_umax` | Native 3D solver should preserve the max-velocity statement. |
| zero outlet stress | traction BC | native 3D outlet BC in Lane 2D | Do not map this to the current 1D characteristic outlet literally. |
| `eta_r` | `cm` | displacement state and exported displacement field | At minimum this is a wall radial displacement; full node-centered export is a local package extension. |
| `C0` | `dyn/cm^3` after dividing force by displacement | closest local surfaces: `wall_stiffness`, `wall_elastic_coefficient`, `canic_membrane_c0` | Current local wall helpers are the nearest fit but do not, by themselves, prove exact Section 4.1 parity. |
| benchmark time `T = 1 s` | `s` | native `Resolved3DCaseSpec.target_time = 1.0` | Do not inherit `0.9995` for new native outputs. |
| XDMF velocity file | vector node field | `velocity.xdmf` / `velocity.h5` | Imported by `parse_xdmf_velocity(...)`. |
| XDMF pressure file | scalar node field | `pressure.xdmf` / `pressure.h5` | Imported by `parse_xdmf_field(..., "Scalar")`. |
| XDMF displacement file | vector node field | `displace.xdmf` / `displace.h5` | Imported by `parse_xdmf_field(..., "Vector")`; required for `coordinate_mode=deformed`. |
| cross-sectional averaged velocity | section operator result | current `CrossSectionQuadratureOperator` path | Already implemented for axial velocity. |
| cross-sectional averaged pressure | scalar section operator result | missing local operator extension | Needed later for full Figure 5 parity. |

## Local three-field schema locked for native output

The paper does not define an XDMF/HDF5 export schema. The package must therefore
use its own contract, which is already implied by
`adapters/resolved3d_io.jl` and the lane constraints.

Required native bundle:

- one shared tetrahedral topology with `Dimensions = (cell_count, 4)`;
- one shared node coordinate array with `Dimensions = (node_count, 3)`;
- one node-centered velocity attribute with `Dimensions = (node_count, 3)`;
- one node-centered pressure attribute with `Dimensions = (node_count, 1)`;
- one node-centered displacement attribute with `Dimensions = (node_count, 3)`;
- one XDMF time value per field file, with native benchmark output written at
  `1.0 s`.

Default companion filenames should stay:

```text
velocity.xdmf
pressure.xdmf
displace.xdmf
```

The loader computes deformed coordinates as:

```text
x_deformed = x_reference + displacement
```

Velocity-only bundles remain supported for legacy imported data, but they do
not satisfy the native Section 4.1 generator target.

## Acceptance tiers

### 1. Schema tier

- `load_resolved3d_field_bundle(...)` succeeds on generated output.
- Velocity, pressure, and displacement all load from the same geometry and
  topology without compatibility errors.
- `coordinate_mode=deformed` succeeds on generated output.

### 2. Geometry tier

- Domain length is exactly `6 cm`.
- Boundary tags distinguish inlet, outlet, wall, and interior.
- Radius law matches the Figure 3 formulas case by case.
- `23%` geometry uses `Rmin = 0.1394 cm` exactly, not the package's plain
  `severity=23` shorthand.
- Straight inlet/outlet sections and a single asymmetric throat follow the
  shared `g(z)` / `K(z)` shape.

### 3. Time tier

- Native Section 4.1 reproduction writes its benchmark snapshot at `T = 1.0 s`.
- Writer tests may use synthetic times, but production case specs should record
  `target_time = 1.0`.
- Legacy imported case support may keep `target_time = 0.9995` plus tolerance
  without changing the native target.

### 4. Field tier

- Velocity units: `cm/s`.
- Pressure units: `dyn/cm^2`.
- Displacement units: `cm`.
- Pressure and displacement files are required even if an early smoke solve
  uses analytic or staged placeholder arrays.
- For wall-coupled cases, clamped-end displacement should evaluate to zero at
  inlet and outlet boundary nodes.

### 5. Observation-operator parity tier

- Full Section 4.1 parity requires longitudinal curves of cross-sectional
  average axial velocity and cross-sectional average pressure versus `z`.
- The current package already has a velocity section operator path through
  `CrossSectionQuadratureOperator`.
- The current package does not yet have the matching pressure section-averaging
  path; that is a later implementation requirement, not a 2B/2C blocker.
- The only explicit published numeric parity statement is the velocity claim:
  extended 1D maximum error within `10%`.
- Pressure parity is qualitative in the paper; a local numeric tolerance still
  needs to be chosen later.
- Radial profile comparisons are local diagnostics and are not the published
  Section 4.1 observables.

## Lane readiness

2B mesh lane may start now if it:

- uses the exact Section 4.1 radius laws above;
- treats the `23%` case as an explicit `Rmin` override;
- keeps boundary tagging backend-agnostic.

2C writer lane may start now if it:

- writes a three-field node-centered bundle compatible with the existing
  importer;
- writes native benchmark times at `1.0 s`;
- keeps legacy velocity-only import behavior intact.

2D design lane still needs to choose, from local evidence:

- the exact volumetric displacement-field convention for exported meshes;
- the first native 3D solver strategy and outlet traction realization;
- the local pressure-operator parity path and its acceptance tolerance;
- the exact interpretation of the paper's constant `R0*` in `C0` if stronger
  wall-model parity is required.
