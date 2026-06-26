# Section 4.1 Native Resolved-FSI Reproduction Spec

This public page is the authoritative copy of the Section 4.1 native
resolved-FSI reproduction note. The package-local note at
`packages/stenotic-hemodynamics/docs/native_resolved_fsi_reproduction.md` now
remains only as a pointer stub. Use
[StenoticHemodynamics Workflow Hub](workflows.md) for the package workflow map
and [Native Resolved-FSI Design](native-resolved-fsi-design.md) for the current
implementation boundary.

This note locks the Section 4.1 benchmark contract from
`public/references/02_report_model_hierarchy/2024_canic_extended_1d_stenotic_artery_model.pdf`
and maps it to the current generated-artifact and observation-operator surface.
It is grounded in the paper text and figures on PDF pages 21-24 plus the local
importer/comparison code under
`packages/stenotic-hemodynamics/src/StenoticHemodynamics/`. It does not claim
that the current package has reproduced the paper numerically.

Scope:

- exact benchmark case geometry and physical constants from the paper;
- the local three-field XDMF/HDF5 contract required by the package;
- the current schema, smoke, production-sidecar, restart-metadata, dry-run, and
  observation-artifact tiers;
- explicit separation between paper-given facts, local inferences, and unknowns.

P3/P4 in this note means internal smoke/operator-readiness only. Exact
boundary-mode status, bounded observation rows, production sidecars, and
qualified internal split-run resume may be documented, but public native
production CLI execution, public/default resume, production-scale Section 4.1
reproduction, monolithic ALE, clinical/patient validation, and report-evidence
promotion remain deferred.

## Current package status

The current native resolved-FSI implementation supports generated artifacts and
local operator evidence in separate tiers:

- Schema workflow: generated velocity/pressure/displacement bundles from
  `run_native_resolved_fsi_workflow(...)`, loaded through the retained
  resolved-3D importer.
- Fixed-wall smoke: coarse fixed-wall Stokes and Navier-Stokes smoke bundles
  with explicit zero displacement and package-local pressure-drop weak
  inlet/outlet loading.
- Partitioned smoke: repeated deformed-domain fluid solves with a reduced
  membrane update and prescribed radial wall-velocity Dirichlet data on the
  fluid wall, still using the same pressure-drop-driven inlet/outlet smoke
  loading by default, not a monolithic ALE formulation.
- Boundary-condition audit: the current Gridap smoke path still records
  pressure-drop weak inlet/outlet loading as local boundary evidence. The
  low-level internal `poiseuille_inlet_zero_outlet_stress_section41` mode is
  now implemented and threaded through the tiny partitioned production harness,
  but remains smoke-scale/operator-readiness evidence only. Neither path is a
  validated native resolved-FSI Section 4.1 reproduction claim.
- Production dry-run: `native_resolved_fsi_partitioned_production_dry_run(...)`
  resolves snapshot, sidecar, restart, and imported-parity paths without
  running a solver or writing files.
- Production sidecars: `run_native_resolved_fsi_partitioned_production(...)`
  writes state-carrying-in-run partitioned snapshot bundles plus
  `snapshot_manifest.csv`, `snapshot_diagnostics.csv`, and
  `restart_metadata.json` with schema-v3 durable checkpoint sidecars. The
  diagnostics include Gridap quadrature degree, higher-degree assembly
  sensitivity, and outlet node backflow/open-boundary indicators; these are
  observability fields, not convergence or parity claims.
- Restart metadata: `native_resolved_fsi_read_restart_metadata(...)` validates
  current and legacy metadata, including versioned `state_payload` audit
  metadata and schema-v3 durable checkpoints when present. Qualified internal
  split-run resume can continue into a forked output root for smoke-scale
  operator validation; `native_resolved_fsi_resume_partitioned_production(...)`
  still intentionally fails closed for public callers.
- Observation artifacts: native/imported/parity rows are written to
  `section41_observations.csv` and summarized in
  `section41_observation_summary.csv`. These rows are bounded local-data
  observation rows; pressure differences use the common Section 4.1
  outlet-quadrature gauge and remain diagnostic, not paper-grade native FSI
  reproduction evidence.

External importer support is retained and supported. The tracked Canic upstream
XDMF/HDF5 velocity bundles, and explicitly supplied three-field bundles, remain
valid inputs for local comparison workflows. Missing explicitly selected
imported data must remain an expected skip, not a public-clone failure.

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
- Native Section 4.1 case construction therefore treats the `23%` case as an
  explicit `Rmin = 0.1394 cm` or `delta_r = 0.0406 cm` override, not as a
  plain `severity=23` shorthand.

Locally sampled throat reference from the shared analytic shape:

- `z_throat ~ 2.451 cm` for the current sampled `stenosis_throat_z(...)`
  helper. This is a local observation helper, not an explicit paper value.

## Requirement matrix

`Blocker` below means "blocks current generated native artifacts." Unknowns
that matter for later paper-grade reproduction but do not block generated
artifacts or local operator summaries are marked `non-blocker`.

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
| Inlet condition | Poiseuille inflow with `u_max = 45 cm/s` | explicit; internal exact mode implemented, broader parity validation deferred | not blocking generated artifacts; blocking any validated exact-boundary parity claim | Section 4.1 text. Mean inflow is inferred as `22.5 cm/s`. Pressure-drop weak loading remains the default smoke evidence path; the internal exact mode is smoke-scale/operator-readiness evidence only. |
| Outlet condition | zero stress `sigma n = 0` at `Gamma_out` | explicit; internal exact mode implemented, broader parity validation deferred | not blocking generated artifacts; blocking any validated exact-boundary parity claim | Section 4.1 text. Pressure-drop weak loading remains the default smoke evidence path; the internal exact mode is smoke-scale/operator-readiness evidence only. |
| End constraint | artery clamped at both ends, radial deformation allowed | explicit | no | Section 4.1 text. |
| Comparison time | steady-state 3D snapshot at `T = 1 s` | explicit | no | Section 4.1 text. |
| Legacy imported XDMF time | current local cases expect `0.9995 +/- time_atol` | inferred/local | no | From `Resolved3DCaseSpec` defaults and README; keep for importer compatibility only. |
| Published 3D mesh size | around `100k` tetrahedra | explicit | no | Figure 3 caption. |
| Exact tetrahedral generator and grading | not given | unknown | non-blocker | The package uses a deterministic package-owned mesh contract for generated artifacts. |
| Full 3D solver details from reference `[21]` | not given in Section 4.1 | unknown | non-blocker | Current local smoke-backed solvers are implementation evidence, not a paper solver reconstruction. |
| Wall displacement state | radial displacement `eta_r` on the structure | explicit | no | Equation (35). |
| Volumetric displacement field over exported mesh | not specified by paper | unknown | non-blocker | Required by package output contract; the package uses a local linear radial lift. |
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
| Poiseuille inlet with `u_max = 45 cm/s` | `cm/s` | Section 4.1 paper contract; qualified internal exact mode `poiseuille_inlet_zero_outlet_stress_section41` | Current Gridap smoke still uses pressure-drop-driven weak loading by default. The internal exact mode is smoke-scale/operator-readiness evidence only and should not be described as paper-grade inlet reproduction. |
| zero outlet stress | traction BC | Section 4.1 paper contract; qualified internal exact mode `poiseuille_inlet_zero_outlet_stress_section41` | Do not map this to the current smoke outlet gauge or to the current 1D characteristic outlet literally; the internal exact mode is still bounded to smoke-scale/operator-readiness evidence. |
| `eta_r` | `cm` | displacement state and exported displacement field | At minimum this is a wall radial displacement; full node-centered export is a local package extension. |
| `C0` | `dyn/cm^3` after dividing force by displacement | closest local surfaces: `wall_stiffness`, `wall_elastic_coefficient`, `canic_membrane_c0` | Current local wall helpers are the nearest fit but do not, by themselves, prove exact Section 4.1 parity. |
| benchmark time `T = 1 s` | `s` | native `Resolved3DCaseSpec.target_time = 1.0` | Do not inherit `0.9995` for new native outputs. |
| XDMF velocity file | vector node field | `velocity.xdmf` / `velocity.h5` | Imported by `parse_xdmf_velocity(...)`. |
| XDMF pressure file | scalar node field | `pressure.xdmf` / `pressure.h5` | Imported by `parse_xdmf_field(..., "Scalar")`. |
| XDMF displacement file | vector node field | `displace.xdmf` / `displace.h5` | Imported by `parse_xdmf_field(..., "Vector")`; required for `coordinate_mode=deformed`. |
| cross-sectional averaged velocity | section operator result | current `CrossSectionQuadratureOperator` path | Already implemented for axial velocity. |
| cross-sectional averaged pressure | scalar section operator result | current local pressure section-observation path | Written into Section 4.1 observation artifacts and summarized in `section41_observation_summary.csv`. |

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

Velocity-only bundles remain supported for legacy imported data and optional
upstream comparison workflows. Native generated artifacts require pressure and
displacement and therefore do not use the velocity-only schema as their target.

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

- Native generated Section 4.1 artifacts target a benchmark snapshot at
  `T = 1.0 s`.
- Writer tests may use synthetic times, but production case specs should record
  `target_time = 1.0`.
- Legacy imported case support may keep `target_time = 0.9995` plus tolerance
  without changing the native target.

### 4. Field tier

- Velocity units: `cm/s`.
- Pressure units: `dyn/cm^2`.
- Displacement units: `cm`.
- Pressure and displacement files are required for native generated artifacts.
  Fixed-wall smoke writes zero displacement; partitioned smoke writes the local
  lifted wall displacement.
- For wall-coupled cases, clamped-end displacement should evaluate to zero at
  inlet and outlet boundary nodes.

### 5. Boundary-condition tier

- Current smoke outputs must report
  `pressure_drop_weak_inlet_outlet_gauge_smoke` as local smoke boundary
  evidence.
- Exact-mode outputs may report
  `poiseuille_inlet_zero_outlet_stress_section41` as internal
  smoke-scale/operator-readiness evidence.
- The weak pressure-drop smoke path remains the default native smoke evidence
  path until exact-boundary parity is validated beyond the tiny production
  harness.
- Current outputs must not report validated Section 4.1 boundary reproduction
  or parity.
- Exact paper boundary parity remains deferred until the implemented internal
  mode is validated beyond the tiny smoke-scale production harness, without
  removing the pressure-drop smoke path.

### 6. Observation-operator parity tier

- Full Section 4.1 parity requires longitudinal curves of cross-sectional
  average axial velocity and cross-sectional average pressure versus `z`.
- The current package has a velocity section operator path through
  `CrossSectionQuadratureOperator`.
- The current package also writes pressure section-average observation rows for
  native and imported bundles when pressure is available.
- Production observation artifacts write `section41_observations.csv` and
  `section41_observation_summary.csv`.
- The only explicit published numeric parity statement is the velocity claim:
  extended 1D maximum error within `10%`.
- Pressure parity is qualitative in the paper; a local numeric tolerance still
  needs to be chosen later. Current pressure differences are outlet-gauged
  diagnostics only.
- Radial profile comparisons are local diagnostics and are not the published
  Section 4.1 observables.

## Current boundary and deferred claims

Current generated artifacts may support these bounded statements:

- the package owns explicit Section 4.1 case specifications for `sev23`,
  `sev40`, and `sev50`;
- the retained importer can load native generated three-field bundles and
  external imported bundles under the existing optional-data rules;
- fixed-wall and partitioned smoke outputs can be written, reloaded, and
  summarized locally;
- production sidecars document state-carrying behavior within a production run,
  schema-v3 durable checkpoint state, and qualified internal split-run resume,
  not public/default process resume or a paper-grade transient reproduction;
- restart metadata may carry versioned `state_payload` audit state for the last
  in-run snapshot without turning public/default resume into a supported
  workflow;
- local velocity and pressure observation artifacts can be generated and
  summarized in `section41_observation_summary.csv`.
- smoke results now carry executable boundary-condition status showing
  pressure-drop weak inlet/outlet loading as local evidence, not exact Section
  4.1 inlet/outlet reproduction.
- the internal `poiseuille_inlet_zero_outlet_stress_section41` mode is
  implemented and can be threaded through the tiny partitioned production
  harness, but only as smoke-scale/operator-readiness evidence.

Deferred claims:

- public CLI exposure for native resolved-FSI production, restart, and
  observation-artifact workflows beyond the status-only `fsi native-status`
  dry-run/status command;
- public/default restart and resume beyond the current metadata reader and
  qualified internal split-run path;
- production-scale restart/resume validation and any manuscript claim promotion
  from schema-v3 checkpoint sidecars;
- validated native resolved-FSI Section 4.1 boundary parity and paper-grade
  numerical reproduction of the Poiseuille-inlet / zero-outlet-stress case;
- monolithic ALE FSI;
- clinical or patient-specific validation;
- report-evidence promotion from P3/P4 smoke/operator-readiness rows;
- paper-grade native resolved-FSI Section 4.1 numerical reproduction or
  validation.
