# Section 4.1 Production-Scale Validation Plan

This roadmap converts the current smoke-scale exact-boundary native
resolved-FSI support into a production-scale Section 4.1 evidence program. It
is a planning document, not a claim that the package already reproduces Section
4.1 at paper grade.

The current implementation has:

- exact Section 4.1 inlet/outlet boundary threading in the low-level Gridap
  path and tiny partitioned production smoke harness;
- exact-mode reduced partitioned solves that use stationary no-slip wall data
  on deformed geometry, with a semi-implicit reduced membrane update;
- status-only CLI reporting through `fsi native-status`;
- state-carrying in-run production sidecars, schema-v3 checkpoint metadata,
  and qualified internal split-run resume into a forked output root;
- internal Gridap reuse diagnostics, symbolic/numeric factorization cache
  status fields, phase timing fields, and batch status/benchmark sidecars for
  operational review;
- local native/imported observation rows and parity summary surfaces.

The current implementation does not yet have:

- production-scale exact-boundary native generation for all Section 4.1 cases;
- monolithic ALE FSI or a validated moving-wall fluid boundary handoff for
  paper-grade FSI fidelity;
- validated imported-data parity for the exact-boundary generated outputs;
- public/default restart or resume, or public native production CLI execution;
- public performance, scalability, or timing claims from the current telemetry;
- paper-grade native resolved-FSI Section 4.1 numerical reproduction.

## Claim Tiers

Keep the evidence tiers separate in implementation, docs, and manuscript
handoffs.

1. **Operator-readiness.** The package can construct Section 4.1 cases, apply
   the exact boundary mode, write three-field bundles, reload them, and compute
   section observations. This checks plumbing, not numerical reproduction.
2. **Smoke-scale evidence.** Tiny exact-boundary runs exercise the boundary
   mode, pressure sampling, state carry, sidecars, and status rows on cheap
   meshes. This is implementation evidence only.
3. **Production-scale native generation.** Exact-boundary runs for the Section
   4.1 case set complete on a mesh/time schedule sized to the published
   benchmark and emit finite, importer-compatible artifacts and sidecars.
4. **Imported-data parity.** Native observations are compared with optional
   external imported bundles through skip-safe parity rows and summaries.
5. **Paper-grade reproduction readiness.** Only after the production-scale and
   imported-data gates pass for the case set may the manuscript claim move from
   "operator/local evidence" toward "Section 4.1 reproduction evidence"; even
   then the claim must state the solver, mesh, boundary, observation, and
   comparison limits.

## Case Matrix

Production-scale planning should cover all Section 4.1 native cases:

| Native case | Imported case | Paper label | Native geometry requirement | Imported-data posture |
| --- | --- | --- | --- | --- |
| `sev23` | `77` | 23% stenosis | Use explicit `Rmin = 0.1394 cm` / `delta_r = 0.0406 cm`, not plain `severity=23`. | Optional external bundle under the local data root; skip safely when absent. |
| `sev40` | `60` | 40% stenosis | Use `Rmin = 0.108 cm` / `delta_r = 0.072 cm`. | Optional external bundle under the local data root; skip safely when absent. |
| `sev50` | `50` | 50% stenosis | Use `Rmin = 0.09 cm` / `delta_r = 0.09 cm`. | Optional external bundle under the local data root; skip safely when absent. |

All cases use:

- vessel length `L = 6 cm`;
- baseline radius `Rmax = 0.18 cm`;
- Section 4.1 exact mode
  `:poiseuille_inlet_zero_outlet_stress_section41`;
- Poiseuille inlet `u_max = 45 cm/s`;
- natural zero outlet traction;
- source-artifact observation/parity snapshot targets must use the imported
  case time recorded in the source bundle.

Current imported-case targets are `0.99949999999994532 s` for `sev23`/case
`77`, `0.99949999999994532 s` for `sev40`/case `60`, and
`1.4994999999998904 s` for `sev50`/case `50`. A separate stand-alone native
generation at nominal `T = 1.0 s` is not source-artifact parity evidence unless
the corresponding imported case is also aligned to that time within the
declared tolerance.

## Mesh Schedule

The published Section 4.1 figure cites roughly `100k` tetrahedra. The package
mesh contract has

```text
tetrahedra = 3 * axial * angular * (2 * radial - 1)
nodes      = (axial + 1) * (1 + radial * angular)
```

Use a staged schedule:

| Stage | Resolution `(axial, radial, angular)` | Tetrahedra | Role | Claim boundary |
| --- | --- | ---: | --- | --- |
| smoke | `(2, 1, 6)` | 36 | Existing tiny exact-boundary smoke. | Operator-readiness only. |
| development | `(40, 3, 16)` | 9,600 | Cheap finite-field and sidecar debugging. | No production claim. |
| preproduction | `(80, 4, 24)` | 40,320 | First meaningful stability/output guard run. | Native generation rehearsal. |
| production target | `(120, 5, 32)` | 103,680 | Closest package-owned target to the published `~100k` scale. | Candidate production-scale native evidence if all gates pass. |
| sensitivity | `(160, 6, 40)` | 211,200 | Optional mesh-sensitivity run if compute budget allows. | Sensitivity only, not required for first claim gate. |

The production target and sensitivity stages must be started through dry-run or
status reporting first. Any run whose guard report requires overrides must not
be launched until the override rationale, expected output size, and scratch
output root are recorded in the handoff.

## Time Schedule

Recommended staged schedule:

| Stage | `dt_s` | `tfinal_s` | `snapshot_times_s` | Purpose |
| --- | ---: | ---: | --- | --- |
| smoke | `1e-4` | `1e-4` | `(1e-4,)` | Existing tiny exact-boundary path. |
| development | `1e-4` | `1e-2` | `(1e-2,)` | Catch nonfinite fields and sidecar issues cheaply. |
| preproduction | `1e-4` | `0.1` | `(0.1,)` | Exercise longer state carry before full target time. |
| production target | `1e-4` | `1.0` | `(1.0,)` | Section 4.1 native benchmark snapshot. |
| optional time history | `1e-4` | `1.0` | `(0.25, 0.5, 0.75, 1.0)` | Diagnostic history only; not required for first parity claim. |

The first production claim gate should use the final snapshot only. Time
history is useful for diagnosing instabilities, but it increases output volume
and should not become a default artifact requirement.

## Bounded Exact-Boundary Probe Ledger

The next bounded exact-boundary probe is a single-snapshot `sev23` run at the
preproduction mesh target, but with a one-step time horizon so it remains a
probe rather than production-scale validation:

```julia
using StenoticHemodynamics

resolution = NativeResolvedFSIMeshResolution(axial=80, radial=4, angular=24)
spec = NativeResolvedFSIPartitionedProductionSpec(
    case_id=:sev23,
    resolution=resolution,
    output_root="tmp/simulations/output/native-resolved-fsi-exact-boundary-probes/sev23-mesh80x4x24-tfinal0p0001",
    dt_s=1.0e-4,
    tfinal_s=1.0e-4,
    snapshot_times_s=[1.0e-4],
    inlet_outlet_boundary_mode=:poiseuille_inlet_zero_outlet_stress_section41,
    inlet_umax_cm_s=45.0,
    pressure_drop_dyn_cm2=0.0,
    status_every=1,
)
result = run_native_resolved_fsi_partitioned_production(spec)
```

The scratch output location is:

```text
tmp/simulations/output/native-resolved-fsi-exact-boundary-probes/sev23-mesh80x4x24-tfinal0p0001/sev23/
```

This bounded probe plan records the following required review gates in the
production dry-run policy string
`sev23_preproduction_mesh_exact_boundary_probe_mesh80x4x24_tfinal0p0001_planned`.
The dry run does not certify these artifact gates; they remain pending until a
reviewed execution artifact is produced:

| Gate | Status |
| --- | --- |
| finite velocity, pressure, and displacement fields | pending artifact review |
| positive current radii and positive signed tetrahedra | pending artifact review |
| outlet-gauge pressure normalization | pending artifact review |
| native writer/importer round trip | pending artifact review |
| coupling status | pending execution |

This probe is not paper-grade Section 4.1 parity, not moving-wall ALE
validation, and not production-scale all-case validation. It exercises the
exact Poiseuille inlet / natural zero-outlet-stress mode with the current
stationary-wall-on-deformed-geometry handoff only.

## Boundary And Pressure Handling

Exact Section 4.1 production-scale runs must select:

```julia
inlet_outlet_boundary_mode = :poiseuille_inlet_zero_outlet_stress_section41
inlet_umax_cm_s = 45.0
```

The pressure-drop weak inlet/outlet mode remains valid local smoke evidence,
but it cannot be used for exact Section 4.1 parity claims.

Pressure handling gates:

- exact mode must use the strong Poiseuille inlet and natural zero outlet
  traction path;
- exact mode must not fall back to pressure-drop resistance wall-pressure
  loading;
- wall pressure used by the membrane update must be finite at every axial
  station;
- exported pressure must be finite at every mesh node;
- exported pressure must be outlet-gauged by subtracting the arithmetic mean on
  outlet boundary nodes after sampling;
- the Gridap Navier-Stokes solve must record its pressure-nullspace treatment
  separately from the post-sampling outlet normalization used for exported
  fields and wall-pressure profiles.

Current reduced-partitioned wall-boundary evidence:

- exact inlet/outlet mode currently selects stationary no-slip wall solves on
  the deformed geometry to avoid feeding reduced membrane wall velocity back
  into the fluid Dirichlet data;
- pressure-drop smoke mode retains the prescribed radial wall-velocity
  Dirichlet handoff;
- this distinction must remain visible in diagnostics and restart metadata;
- stationary-wall-on-deformed-geometry evidence is a stability step for the
  current reduced partitioned implementation, not monolithic ALE or paper-grade
  moving-wall FSI validation.

## Wall Parameters

Use Section 4.1/Table 1 physical parameters for production-scale planning:

| Quantity | Value | Package mapping |
| --- | --- | --- |
| Fluid density | `1.055 g/cm^3` | `Params.rho` and native fluid setup. |
| Fluid kinematic viscosity | `0.04 cm^2/s` | `Params.nu`. |
| Wall density | `1.055 g/cm^3` | Production `wall_density_g_cm3`; current smoke default `1.0` should not be reused for claim-scale runs without justification. |
| Wall thickness | `0.06 cm` | `Params.wall_h`. |
| Poisson ratio | `0.5` | `Params.sigma`. |
| Young modulus | `5.02e6 dyn/cm^2` | `Params.young`. |
| Wall stiffness policy | `:canic_membrane_c0` | Use current production policy, with a pre-run check that the resulting `C0` is finite and positive. |
| Reference radius policy | `:params_rmax` | Accept for first production validation; record as a modeling assumption because the paper's constant `R0*` value is not restated in Section 4.1. |
| Wall damping | `0.0 g/cm^2/s` unless explicitly calibrated | Keep explicit in run metadata; do not tune without a separate calibration lane. |

## Output And Parity Artifacts

Every production-scale native run should write only under ignored scratch roots,
normally below:

```text
tmp/simulations/output/native-resolved-fsi-production/
```

For each saved native snapshot, expected bundle files are:

```text
velocity.xdmf
velocity.h5
pressure.xdmf
pressure.h5
displace.xdmf
displace.h5
```

Expected production sidecars are:

```text
snapshot_manifest.csv
snapshot_diagnostics.csv
restart_metadata.json
```

Expected Section 4.1 observation/parity artifacts are:

```text
section41-observations/section41_observations.csv
section41-observations/section41_observation_summary.csv
```

Imported-data parity remains optional and skip-safe:

- `sev23` maps to imported case `77`;
- `sev40` maps to imported case `60`;
- `sev50` remains expected-skip unless an imported bundle is explicitly
  supplied;
- missing external XDMF/HDF5 inputs must produce expected-skip rows, not
  validation failures;
- velocity-only imported bundles can support velocity-only comparisons, but
  pressure and displacement parity gates require imported pressure/displacement
  bundles or must be marked unavailable.

## Validation Gates

### Gate 1: Dry-Run And Guard Review

Before any non-smoke production execution:

- run or inspect `fsi native-status` / qualified dry-run output for every case;
- confirm exact boundary mode, `u_max = 45 cm/s`, output root, snapshot schedule,
  guard status, and imported-bundle status;
- record required override flags from the guard report;
- reject default production execution from CLI paths.

### Gate 2: Native Finite-Field Gate

For each native generated snapshot:

- velocity, pressure, and displacement arrays exist with expected dimensions;
- every field value is finite;
- current radii stay positive;
- deformed tetrahedra are not inverted;
- velocity and pressure solves report converged or explicitly bounded status;
- no pressure-drop fallback is used in exact boundary mode.

### Gate 3: Displacement And Wall-State Gate

For each production run:

- wall displacement, wall velocity, and wall pressure arrays are finite;
- clamped inlet/outlet wall displacement is zero within tolerance;
- lifted displacement is radial and consistent with the wall state;
- `state_payload` records the final in-run wall state as audit metadata;
- persisted resume remains unsupported and fail-closed.

### Gate 4: Pressure Normalization Gate

For each saved pressure field:

- pressure sampling succeeds directly and finitely;
- the outlet-node mean after export normalization is near zero within a
  predeclared numerical tolerance;
- pressure summary rows record the gauge convention;
- pressure comparisons do not use un-gauged native pressure against gauged
  imported pressure or vice versa.

### Gate 5: Importer Round-Trip Gate

For every native bundle:

- `load_resolved3d_field_bundle(...)` succeeds;
- velocity, pressure, and displacement share topology and reference geometry;
- reference and deformed coordinate modes load when displacement is present;
- loaded time equals the planned native snapshot time within `time_atol`;
- reloaded observations match writer-side row counts and section positions.

### Gate 6: Observation Row Gate

For each case:

- native velocity and pressure section rows are finite;
- observation rows include case id, severity, boundary mode, boundary class,
  section41 boundary status, and boundary-equivalence status;
- imported rows are finite when imported bundles are present;
- absent imported bundles produce expected-skip status with the missing path or
  missing bundle reason.

### Gate 7: Parity Summary Gate

For each case with imported data:

- `section41_observation_summary.csv` is written and contains native/imported
  summary rows plus parity rows;
- velocity parity uses a predeclared Section 4.1 observable: cross-sectional
  average axial velocity versus `z`;
- pressure section rows use the common Section 4.1 outlet-quadrature gauge and
  remain diagnostics, not validation, FFR, or paper-grade reproduction evidence;
- boundary-equivalence fields must say whether exact Section 4.1 mode was used;
- summary status must not call artifact readiness "validated reproduction".

### Gate 8: Manuscript Claim Readiness

Manuscript wording may advance only after:

- all required native cases complete at production target mesh/time scale;
- optional imported bundles are present or explicitly reported as unavailable;
- native/imported observation summaries pass their predeclared checks;
- pressure gauge and boundary-mode language is reviewed;
- an editorial note distinguishes implementation, verification, imported-data
  comparison, and reproduction claims.

Until then, the manuscript-safe claim is limited to smoke-scale exact-boundary
support and a planned production-scale validation path.

## Compute And Output Guards

Current hard guards:

- `snapshot_times_s` must be finite, strictly increasing, and within
  `[0, tfinal_s]`;
- more than `50` saved snapshots requires `allow_many_snapshots=true`;
- estimated raw field payload above `1 GiB` requires
  `allow_large_output=true`;
- estimated raw field payload is
  `snapshot_count * node_count * 7 * sizeof(Float64)`;
- nonpositive `dt_s`, `tfinal_s`, Picard tolerance, wall density, or coupling
  tolerance is invalid;
- `coupling_under_relaxation` must lie in `(0, 1]`;
- exact boundary mode requires positive finite `inlet_umax_cm_s`.

Operational policy for non-smoke runs:

- do not run production from default CLI paths;
- require dry-run/status review before launching;
- record requested mesh resolution, case set, snapshot count, estimated bytes,
  output root, and override flags in the handoff;
- enable batch status sidecars for long runs: `batch_status.jsonl`,
  `batch_status.csv`, `batch_benchmark.json`, and fail-fast
  `batch_failure.json`;
- treat phase timing fields, Gridap reuse status, and symbolic/numeric
  factorization cache fields as internal diagnostics only. Nested timing fields
  must not be summed into an elapsed-time claim, and cache/reuse observations
  must not be promoted into performance or production-scale evidence;
- preflight output ownership before the solver starts; a preproduction batch
  should fail before Gridap work if the deterministic output directory already
  exists and `overwrite=false`;
- keep outputs in ignored scratch directories until an explicit artifact
  publication lane exists;
- do not refresh report/manuscript artifacts from this lane.

## Follow-Up Implementation Lanes

1. **10C-impl1: production-scale dry-run matrix.** Completed as status-only
   planning evidence. The dry-run matrix confirmed guard flags and output paths
   without running production or writing solver artifacts.
2. **10C-impl2a: development wall-stability remediation.** Completed at
   development-artifact scope. Earlier exact-mode probes failed closed before
   output artifacts because the moving-wall/explicit membrane handoff produced
   non-positive current radii. The current reduced path uses stationary
   no-slip wall solves on deformed geometry for exact inlet/outlet mode and
   advances the membrane with a semi-implicit update. The full `sev23`
   development-mesh gate at `(40, 3, 16)`, `dt_s=1e-4`, `tfinal_s=1e-2`
   writes solver artifacts with finite fields, positive current radii,
   positive tetrahedron orientation, direct finite wall-pressure sampling, and
   importer-compatible sidecars. The run uses one coupling iteration per step
   and records bounded but non-converged coupling history, so this is not
   preproduction, production, parity, or moving-wall ALE evidence.
3. **10C-impl2b: preproduction batch preparation.** Completed as operational
   readiness work. The production runner now preflights owned output paths
   before solving, emits JSONL/CSV heartbeat rows with step count, physical
   time, elapsed time, estimated remaining time, memory footprint when
   available, minimum current radius, minimum signed tetra volume, field
   finite status, coupling residual/convergence status, and output/status
   paths, and writes final benchmark or failure sidecars. This is not
   preproduction execution evidence.
4. **10C-impl2c: preproduction execution.** Run exact-boundary `sev23` at
   preproduction scale, exercising finite fields, pressure normalization,
   importer round-trip, sidecars, observation rows, and stronger coupling
   settings or explicitly bounded coupling status. Keep
   `wall_stability_status`, `pressure_nullspace_status`, fluid wall-boundary
   handoff status, and pressure-load plausibility diagnostics visible. The
   development gate took about 25 minutes for 101 steps at 9,600 tetrahedra;
   preproduction and production-target execution should be treated as
   long-running batch work, not as an interactive smoke test.
5. **10C-impl3: full case-set production generation.** Run `sev23`, `sev40`,
   and `sev50` at `(120, 5, 32)`, `dt_s=1e-4`, `T=1.0`, final snapshot only.
6. **10C-impl4: imported-data parity.** Development-output parity has run for
   `sev23` against imported case `77`: observation and summary artifacts were
   written, imported observations loaded, and nonzero development-scale
   discrepancies were recorded (`max_mean_velocity_abs_difference_cm_s ≈
   2.317`, `max_mean_pressure_abs_difference_dyn_cm2 ≈ 813.906`). This is
   operator/artifact and discrepancy-classification evidence only. Production
   parity still requires generated production-target outputs paired with
   optional imported bundles; keep `sev50` and missing pressure/displacement
   data skip-safe.
7. **10C-editorial: manuscript claim review.** Update manuscript/report claims
   only after gates 1-8 are reviewed and accepted by the editorial owner.
