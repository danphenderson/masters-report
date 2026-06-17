# Canic Extended 1D Stenosis Simulation

This folder contains a Julia finite-volume reproduction of the extended 1D
stenotic artery model from:

Canic, Guo, Wang, Yue, and Zheng, "Extended one-dimensional reduced model for
blood flow within a stenotic artery" (2024).

The implementation uses the paper's closed conservative `(A,Q)` system, the
C^infinity asymmetric stenosis profile used as the report's idealized-vessel
baseline, Riemann-invariant boundary treatment, Rusanov fluxes, and third-order
SSP Runge-Kutta stepping. Units follow the paper and the authors' MATLAB code:
centimeters, grams, seconds, and dynes.

This is not a line-for-line port of the authors' DG MATLAB code. It is a
compact finite-volume implementation for reproducible local experiments,
backend comparisons, and report figures.

## Simulation Protocol

The public workflow is:

1. Define a case with `Params`.
2. Build the semi-discrete finite-volume system with `semidiscretize(params)`.
3. Choose a time backend:
   - `NativeRK3Backend()` for the built-in fixed-step SSP RK3 path.
   - `SciMLTimeBackend(solve=SolveSpec(...))` for SciML/OrdinaryDiffEq.
4. Run `simulate(params, backend)` to obtain a `SimulationResult`.
5. Derive diagnostics with `velocity(result)`, `pressure(result, params)`,
   `write_csv`, `write_svg`, or study summaries from `run_study`.

The CLI follows the same protocol internally. The default command uses
`NativeRK3Backend()` with finite-volume MUSCL reconstruction, the minmod TVD
limiter, and SSPRK3 stepping unless options override that method stack.
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

Use `./scripts/julia-release` for repo commands. It prefers the latest installed
`release` channel and falls back to a directly-invoked `julia` binary only when
that binary is already `1.12+`.

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

## Recommended Commands

Exploratory native smoke test:

```bash
./scripts/julia-release simulations/run_canic_extended_1d.jl --tfinal 0.01 --nx 120 --ic-pressure-drop-pa 40 --ic-mesh-nz 2 --ic-mesh-nr 2 --ic-mesh-ntheta 8 --progress-every 0 --output simulations/output/verification_001s.csv --svg simulations/output/verification_001s.svg
```

Default 50% stenosis native run:

```bash
./scripts/julia-release simulations/run_canic_extended_1d.jl --tfinal 1.0 --nx 400 --severity 50 --ic-pressure-drop-pa 40 --progress-every 10000
```

Legacy first-order run:

```bash
./scripts/julia-release simulations/run_canic_extended_1d.jl --space fv-first-order --ic geometry-rest --tfinal 0.001 --nx 80 --progress-every 0
```

DG quadratic smoke run:

```bash
./scripts/julia-release simulations/run_canic_extended_1d.jl --space dg --degree 2 --time-stepper ssprk3 --ic-pressure-drop-pa 40 --ic-mesh-nz 2 --ic-mesh-nr 2 --ic-mesh-ntheta 8 --tfinal 0.001 --nx 80 --progress-every 0
```

Carreau-Yasuda smoke run:

```bash
./scripts/julia-release simulations/run_canic_extended_1d.jl --tfinal 0.001 --nx 80 --severity 40 --ic geometry-rest --rheology carreau-yasuda --eta0 0.56 --eta-inf 0.0345 --lambda-s 3.313 --yasuda-a 2.0 --flow-index 0.3568 --progress-every 0
```

Other supported CLI rheology names are `newtonian`, `carreau`, `casson`, and
`power-law`. Dynamic-viscosity parameters use g/(cm*s), yield stress uses
dyn/cm^2, and `--nu` remains the Newtonian kinematic viscosity in cm^2/s.

SciML runs with explicit policies:

```bash
./scripts/julia-release simulations/run_canic_extended_1d.jl --backend sciml --alg auto --ic geometry-rest --tfinal 0.001 --nx 40 --progress-every 0
./scripts/julia-release simulations/run_canic_extended_1d.jl --backend sciml --alg tsit5 --abstol 1e-7 --reltol 1e-7 --ic geometry-rest --tfinal 0.001 --nx 40 --progress-every 0
./scripts/julia-release simulations/run_canic_extended_1d.jl --backend sciml --alg rodas5p --maxiters 1000000 --ic geometry-rest --tfinal 0.001 --nx 40 --progress-every 0
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
./scripts/julia-release simulations/run_canic_extended_1d.jl --help
```

Run small programmatic studies from the shared simulation protocol:

```bash
./scripts/julia-release -e 'include("simulations/canic_extended_1d/CanicExtended1D.jl"); using .CanicExtended1D; run_study(SeveritySweepSpec(base_params=Params(nx=40,tfinal=0.001,initial_condition=GeometryRestIC()), severities=[23,50], overwrite=true))'
./scripts/julia-release -e 'include("simulations/canic_extended_1d/CanicExtended1D.jl"); using .CanicExtended1D; run_study(GridConvergenceStudySpec(base_params=Params(tfinal=0.001,severity=50,initial_condition=GeometryRestIC()), nxs=[40,80], overwrite=true))'
./scripts/julia-release -e 'include("simulations/canic_extended_1d/CanicExtended1D.jl"); using .CanicExtended1D; run_refinement_study(RefinementStudySpec(base_params=Params(tfinal=0.001,severity=40,initial_condition=GeometryRestIC()), nxs=[50,100,200,400], overwrite=true))'
```

Study summaries are written to deterministic CSV paths under
`simulations/output/` by default. Existing summary files are not overwritten
unless `overwrite=true` is set. The summary CSV format is separate from the
single-run profile CSV and includes study kind, severity, grid size, backend,
algorithm, step count, final time, velocity and pressure ranges, and minimum
area.

Refinement studies write self-convergence h- and p-refinement CSV files plus
LaTeX table fragments under `simulations/output/refinement/<study-token>/`.
Observed orders are computed from doubled-resolution errors against the
method-specific finest self-reference.

## Resolved 3D Comparison

The resolved-data comparison layer reads upstream XDMF/HDF5 velocity output,
runs the matching 1D case, and writes section-mean and radial-profile
diagnostics under `simulations/output/3d_comparison/`.

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
./scripts/julia-release -e 'include("simulations/canic_extended_1d/CanicExtended1D.jl"); using .CanicExtended1D; run_available_resolved3d_comparison(overwrite=true)'
```

To select a SciML backend programmatically:

```bash
./scripts/julia-release -e 'include("simulations/canic_extended_1d/CanicExtended1D.jl"); using .CanicExtended1D; backend=SciMLTimeBackend(solve=SolveSpec(algorithm=Tsit5Policy(), abstol=1e-7, reltol=1e-7)); run_available_resolved3d_comparison(backend=backend, overwrite=true)'
```

The comparison uses node-centered 3D data. Section means average `u_z` over
nodes in a small axial slab and compare against interpolated 1D `Q/A`. Radial
profiles bin the same slab nodes by `sqrt(x^2+y^2)/R0(z)` and compare against
the 1D closure profile. This is a resolved-node diagnostic, not exact
tetrahedral cross-section quadrature.

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
- A `SemiDiscreteSimulation` owns mutable RHS cache arrays. Do not share one
  instance across concurrent solves.
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
