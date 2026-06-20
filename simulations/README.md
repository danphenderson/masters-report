# StenosisHemodynamics Simulation Notes

This folder contains generated-data locations and usage notes for the Julia
package `StenosisHemodynamics`. The default forward model,
`canic-extended-1d`, is the historical manifest token for the
Rmax-normalized Canic-derived extended 1D stenotic artery model used in the
report. Its source model is:

Canic, Guo, Wang, Yue, and Zheng, "Extended one-dimensional reduced model for
blood flow within a stenotic artery" (2024).

The implementation uses the paper's closed conservative `(A,Q)` system as the
starting point, the C^infinity asymmetric stenosis profile used as the report's
idealized-vessel baseline, Riemann-invariant boundary treatment, Rusanov
fluxes, and third-order SSP Runge-Kutta stepping. The report documents the
source-to-implementation differences, including the constant `Rmax` pressure
denominator, parabolic-profile main case, locally frozen-viscosity `p2`
derivative, and non-well-balanced finite-volume rest state. Units follow the
paper and the authors' MATLAB code: centimeters, grams, seconds, and dynes.
The smooth profile is also used by the local fixed-wall stationary-Stokes study:
one analytic vessel definition supplies the 1D finite-volume geometry, generated
tetrahedral Gridap meshes, wall normals, and repeatable mesh-refinement cases.

This is not a line-for-line port of the authors' DG MATLAB code. It is a
compact finite-volume implementation for reproducible local experiments,
backend comparisons, and report figures.

## Simulation Protocol

The exported core workflow is:

1. Define a case with `Params`.
2. Choose a time backend:
   - `NativeRK3Backend()` for the built-in fixed-step SSP RK3 path.
   - `SciMLTimeBackend(solve=SolveSpec(...))` for SciML/OrdinaryDiffEq.
3. Run `simulate(params, backend)` to obtain a `SimulationResult`.
4. Derive diagnostics with exported helpers such as `velocity(result)` and
   `pressure(result, params)`.

The CLI follows the same protocol internally and owns ordinary CSV/SVG output
writing. Study, benchmark, adapter, and report-asset helpers are intentionally
qualified module internals, for example `StenosisHemodynamics.run_study(...)`.
The default command uses
`NativeRK3Backend()` with finite-volume MUSCL reconstruction, the minmod TVD
limiter, and SSPRK3 stepping unless options override that method stack.
Finite-volume MUSCL and Lax-Wendroff methods accept limiter objects in the API
and `--limiter minmod|van-leer` in the CLI. New limiters should implement
`limiter_name`, `validate`, and `limited_slope` while leaving solver dispatch
unchanged.
The default initial condition is `StationaryStokesIC`, so CLI and API runs must
provide a positive pressure drop with `--ic-pressure-drop-pa`,
`--ic-pressure-drop-dyn-cm2`, or `StationaryStokesIC(pressure_drop_pa=...)`.
Use `--ic geometry-rest` or `GeometryRestIC()` for the previous baseline
area-at-rest, zero-flow initialization.

The default rheology is Newtonian and uses `Params.nu` as the kinematic
viscosity. Non-Newtonian closure objects are available for the next comparison
phase:

- `CarreauRheology`
- `CarreauYasudaRheology`
- `CassonRheology`
- `PowerLawRheology`

These closures compute a local effective kinematic viscosity from the current
1D state and a wall-shear-rate proxy. The finite-volume equation structure is
unchanged; the closure-aware viscosity is used where the earlier implementation
used the scalar `nu`.

## Velocity Profiles and Alpha

The solver now records a velocity-profile closure instead of treating `alpha`
as a free scalar. The default is `ParabolicVelocityProfile()`, equivalent to
Poiseuille transport with `alpha = 4/3`, shear-rate factor `4`, and
`inlet_uavg = 0.5 * inlet_umax`.

Supported CLI profiles are:

- `--velocity-profile parabolic`: default Poiseuille profile.
- `--velocity-profile flat --profile-shear-factor 4`: plug transport with
  `alpha = 1` and a finite explicit shear/friction multiplier.
- `--velocity-profile power --profile-exponent GAMMA`: power-family profile
  with `alpha = (GAMMA + 2) / (GAMMA + 1)`.

The legacy `--alpha VALUE` option remains as an alias for the power-family
profile, so `--alpha 1.1` is equivalent to `--velocity-profile power
--profile-exponent 9`. Single-run summaries record `velocity_profile`,
derived `alpha`, `profile_exponent`, and `shear_rate_factor`; the per-cell CSV
schema is unchanged. Default single-run output stems and default study summary
CSV paths now include `vp_<profile-token>` so parabolic, flat, and power-family
cases do not collide; flat and power tokens also encode the selected
shear-factor or exponent.

The primary command surface is `./scripts/stenosis-hemodynamics <command>`.
It internally uses `./scripts/julia-release`, which prefers the latest installed
`release` channel and falls back to a directly-invoked `julia` binary only when
that binary is already `1.12+`. Programmatic runs should load the root package
with `using StenosisHemodynamics`.

The forward-model descriptor defaults to `--model canic-extended-1d`. Use
`--model classical-1d-no-slip` for the classical parabolic-profile baseline; it
requires `--velocity-profile parabolic` and disables the Canic variable-radius
effective-alpha correction terms.

Local zsh startup sources `~/.config/julia/resource-profile.zsh`. The batch
profile sets `JULIA_NUM_THREADS=10`, `JULIA_NUM_GC_THREADS=2`,
`OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1`, `VECLIB_MAXIMUM_THREADS=1`, and
`JULIA_CASE_WORKERS=10`. Use `julia-batch` for single-process threaded runs,
`julia-cases [N]` for process-parallel case studies, and `julia-blas [N]` for
BLAS-heavy serial checks. Set `JULIA_RESOURCE_PROFILE=off` before shell startup
to disable the profile.

## Spatial Methods and Steppers

The simulation case records the spatial method and native time stepper:

- `--space fv-first-order`: legacy first-order Rusanov finite volume.
- `--space fv-muscl`: TVD MUSCL finite volume, defaulting to `--limiter minmod`.
- `--space fv-lax-wendroff`: native fixed-step Richtmyer/Lax-Wendroff finite
  volume with limited interface states.
- `--space dg --degree 0|1|2`: modal Legendre DG. Degree zero uses the
  finite-volume-equivalent cell-mean path; degrees one and two use the native
  modal DG solver and return cell means through `SimulationResult`.

Native time steppers are selected with `--time-stepper euler`, `--time-stepper
ssprk2`, or `--time-stepper ssprk3`. SciML remains available for
semi-discrete methods that do not require a fixed-step predictor. The
Lax-Wendroff method is native-only.

## Initial Conditions

Two deterministic initial-condition modes are available:

- `--ic stationary-stokes`: default. Builds a generated 3D stenotic vessel mesh,
  assembles a Gridap Taylor-Hood stationary Stokes solve driven by the requested
  pressure drop, and projects deterministic Stokes section averages back to the
  1D `(A,Q)` state.
- `--ic geometry-rest`: legacy baseline with `A=R0^2` and `Q=0`.

Stationary Stokes pressure drops are stored internally in dyn/cm^2. The CLI
also accepts Pa and converts with `1 Pa = 10 dyn/cm^2`. The generated FEM mesh
defaults are `--ic-mesh-nz 64 --ic-mesh-nr 6 --ic-mesh-ntheta 32`; small smoke
tests can lower these values. Single-run summaries report IC kind, pressure
drop, mesh size, FEM degrees of freedom, residual normalization, projected
velocity/pressure ranges, and a reproducibility hash.

The initializer remains a projection contract for the 1D state. For fixed-wall
3D diagnostics, use the CLI or the qualified helper
`StenosisHemodynamics.run_stationary_stokes_refinement`, which solves generated
stationary-Stokes cases and writes FE section-average, projection-comparison,
and sampled wall-traction/WSS metrics. It does not solve structural deformation
or transient FSI.

## Recommended Commands

Exploratory native smoke test:

```bash
./scripts/stenosis-hemodynamics simulate --tfinal 0.01 --nx 120 --ic-pressure-drop-pa 40 --ic-mesh-nz 2 --ic-mesh-nr 2 --ic-mesh-ntheta 8 --progress-every 0 --output simulations/output/verification_001s.csv --svg simulations/output/verification_001s.svg
```

Default 50% stenosis native run:

```bash
./scripts/stenosis-hemodynamics simulate --tfinal 1.0 --nx 400 --severity 50 --ic-pressure-drop-pa 40 --progress-every 10000
```

Legacy first-order run:

```bash
./scripts/stenosis-hemodynamics simulate --space fv-first-order --ic geometry-rest --tfinal 0.001 --nx 80 --progress-every 0
```

DG quadratic smoke run:

```bash
./scripts/stenosis-hemodynamics simulate --space dg --degree 2 --time-stepper ssprk3 --ic-pressure-drop-pa 40 --ic-mesh-nz 2 --ic-mesh-nr 2 --ic-mesh-ntheta 8 --tfinal 0.001 --nx 80 --progress-every 0
```

Carreau-Yasuda smoke run:

```bash
./scripts/stenosis-hemodynamics simulate --tfinal 0.001 --nx 80 --severity 40 --ic geometry-rest --rheology carreau-yasuda --eta0 0.56 --eta-inf 0.0345 --lambda-s 3.313 --yasuda-a 2.0 --flow-index 0.3568 --progress-every 0
```

Other supported CLI rheology names are `newtonian`, `carreau`, `casson`, and
`power-law`. Dynamic-viscosity parameters use g/(cm*s), yield stress uses
dyn/cm^2, and `--nu` remains the Newtonian kinematic viscosity in cm^2/s.

SciML runs with explicit policies:

```bash
./scripts/stenosis-hemodynamics simulate --backend sciml --alg auto --ic geometry-rest --tfinal 0.001 --nx 40 --progress-every 0
./scripts/stenosis-hemodynamics simulate --backend sciml --alg tsit5 --abstol 1e-7 --reltol 1e-7 --ic geometry-rest --tfinal 0.001 --nx 40 --progress-every 0
./scripts/stenosis-hemodynamics simulate --backend sciml --alg rodas5p --maxiters 1000000 --ic geometry-rest --tfinal 0.001 --nx 40 --progress-every 0
```

Supported solver policy names are `auto`, `tsit5`, `rodas5p`, and `ssprk`.
The `ssprk` policy is the native fixed-step RK3 path; `auto`, `tsit5`, and
`rodas5p` require `--backend sciml`. SciML solve options such as `--abstol`,
`--reltol`, `--save-everystep`, and `--maxiters` also require
`--backend sciml`.

Validation test suite:

```bash
./scripts/julia-release test/runtests.jl
```

Show CLI options:

```bash
./scripts/stenosis-hemodynamics simulate --help
```

Run small studies through the command dispatcher:

```bash
./scripts/stenosis-hemodynamics study severity --severities 23,50 --nx 40 --tfinal 0.001 --ic geometry-rest --overwrite
./scripts/stenosis-hemodynamics study grid --nxs 40,80 --severity 50 --tfinal 0.001 --ic geometry-rest --overwrite
./scripts/stenosis-hemodynamics study refinement --nxs 50,100,200,400 --severity 40 --tfinal 0.001 --ic geometry-rest --overwrite
./scripts/stenosis-hemodynamics stokes refine --nx 80 --parallel-workers 1 --overwrite
```

Study summaries are written to deterministic CSV paths under
`simulations/output/` by default. Existing summary files are not overwritten
unless `overwrite=true` is set. The summary CSV format is separate from the
single-run profile CSV and includes study kind, severity, grid size, backend,
algorithm, velocity-profile provenance (`velocity_profile`, `alpha`,
`profile_exponent`, `shear_rate_factor`), step count, final time, velocity and
pressure ranges, and minimum area.
Stationary-Stokes refinement summaries are written under
`simulations/output/stationary_stokes_refinement/` by default and include mesh
size, FE degrees of freedom, section-average ranges, relative errors against the
finest successful mesh, sampled wall traction, sampled WSS, status, and any
per-case error message.

Programmatic severity, grid, refinement, and Stokes trajectory-export jobs use
`JULIA_CASE_WORKERS` by default and cap workers to the number of independent
cases. Pass `parallel_workers=1` to the relevant spec or export helper for a
serial debug run.

Refinement studies write self-convergence h- and p-refinement CSV files plus
LaTeX table fragments under `simulations/output/refinement/<study-token>/`.
Observed orders are computed from doubled-resolution errors against the
method-specific finest self-reference.

## Resolved 3D Comparison

The resolved-data comparison layer reads upstream XDMF/HDF5 velocity output,
runs the matching 1D case, and writes quadrature-backed section and radial
profile diagnostics under `simulations/output/3d_comparison/`.

The supported default cases are:

- upstream case `77`, severity `23`, expected XDMF time near `0.9995`
- upstream case `60`, severity `40`, expected XDMF time near `0.9995`

Full HDF5/XDMF files are intentionally ignored by git. Use this local layout:

```text
simulations/data/3d/canic_case3/77/velocity.xdmf
simulations/data/3d/canic_case3/77/velocity.h5
simulations/data/3d/canic_case3/60/velocity.xdmf
simulations/data/3d/canic_case3/60/velocity.h5
```

For example, from an upstream checkout or extraction directory containing
`case3_all_3d_results`:

```bash
mkdir -p simulations/data/3d/canic_case3
cp -R /path/to/case3_all_3d_results/77 simulations/data/3d/canic_case3/
cp -R /path/to/case3_all_3d_results/60 simulations/data/3d/canic_case3/
```

Run the default comparison when the data root is present:

```bash
./scripts/stenosis-hemodynamics compare-3d \
  --target-time 0.9995 \
  --time-atol 1e-6 \
  --overwrite \
  --publish-report-assets
```

To select a SciML backend:

```bash
./scripts/stenosis-hemodynamics compare-3d --backend sciml --alg tsit5 --abstol 1e-7 --reltol 1e-7 --overwrite
```

The default comparison operator intersects the tetrahedral 3D mesh with each
target plane, linearly interpolates $u_z$ on cut edges, triangulates each cut
polygon, and integrates physical area and flow. The resulting mean velocity is
compared against the interpolated 1D $q/a$ value. Radial profiles use the same
cut triangles binned by centroid $\sqrt{x^2+y^2}/R_0(z)$. Node-slab arithmetic
means are still emitted as supplemental sensitivity rows, not as the main
resolved-velocity result.

## Native vs SciML

Use the native backend for deterministic fixed-step smoke runs, continuity with
the original finite-volume implementation, and quick report-oriented checks.
The native path uses `Params.dt` and `Params.cfl` to choose SSP RK3 steps.

Use the SciML backend when comparing OrdinaryDiffEq algorithms, testing
adaptive tolerances, or preparing a future path to events, callbacks, and
ensembles. `SolveSpec` owns SciML solver options such as `abstol`, `reltol`,
`save_everystep`, and `maxiters`; these are intentionally separate from
`Params`, which describes the physical/numerical case.

## Current Limitations

- The RHS and caches are currently `Float64`-specialized. Stiff SciML solvers
  use finite-difference Jacobians (`AutoFiniteDiff`) rather than ForwardDiff.
- Internal semi-discrete simulation objects own mutable RHS cache arrays. Do not
  share one instance across concurrent solves.
- Studies run sequentially. SciML ensemble execution is a future adapter-layer
  addition.
- Study summary CSVs use simple scalar fields and minimal CSV escaping.
- Stationary Stokes IC assembly uses Gridap on the generated 3D mesh. The 1D
  projection uses deterministic Stokes/Poiseuille section averages from the
  same pressure drop and radius profile so coarse generated meshes do not depend
  on brittle arbitrary point-location queries.
- The model is a finite-volume reproduction for local experimentation, not a
  full validation of the paper's DG solver or clinical predictions.
- Non-Newtonian rheology support currently supplies pointwise effective
  viscosity values to the existing reduced source and pressure terms. It is a
  controlled comparison hook, not a replacement for a closure-specific 1D
  derivation.

If the `julia` launcher cannot resolve `+release`, install Julia via `juliaup`
or invoke a direct `1.12+` binary. The repo wrapper falls back to plain
`julia` only when that binary already satisfies the `1.12+` floor.
