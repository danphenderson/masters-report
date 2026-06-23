# StenoticHemodynamics Workflow Hub

This page maps `packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/**`.
Use it alongside [Julia CLI Workflows](../julia-cli-workflows.md): that page
covers command syntax, while this hub names the package workflow families,
entrypoints, artifact posture, optional-data behavior, and the narrowest useful
validation surface for each family.

Plain one-off forward solves still enter through `simulate(params, backend)` or
the `simulate` CLI command. The workflow files documented here are the study,
verification, validation, comparison, benchmark, and report-support layers that
sit on top of that core solver path.

## Simulation And Studies

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/studies/studies.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/studies/studies.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/studies/studies_types.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/studies/studies_types.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/studies/studies_outputs.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/studies/studies_outputs.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/studies/refinement.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/studies/refinement.jl)
- Entrypoints:
  - CLI: `study severity`, `study grid`, `study refinement`
  - Julia: `run_study(...)`, `run_refinement_study(...)`, with spec types such as `SeveritySweepSpec`, `GridConvergenceStudySpec`, and `RefinementStudySpec`
  - Lower-level single-run simulations stay outside `workflows/**` and use `simulate(...)`
- Surface: `CLI-facing`
- Expected outputs and artifact class:
  - Ignored scratch outputs under `tmp/simulations/output/studies/**`
  - Ignored scratch refinement outputs under `tmp/simulations/output/refinement/**`
  - Summary CSVs, per-run CSVs, and optional SVGs remain scratch unless an explicit publication lane promotes them
- Optional-data behavior: no optional external data required
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_cli_studies.jl")'`

## Verification: MMS, Rest State, And P/H Refinement

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/verification.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/verification.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/verification_mms_types.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/verification_mms_types.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/verification_rest_state_types.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/verification_rest_state_types.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/verification_ph_refinement.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/verification_ph_refinement.jl)
- Entrypoints:
  - CLI: `verify mms`, `verify rest`, `verify ph-refinement`
  - Julia: `run_manufactured_verification(...)`, `run_rest_state_drift(...)`, `run_ph_refinement_demo(...)`
- Surface: `CLI-facing`
- Expected outputs and artifact class:
  - Ignored scratch outputs under `tmp/simulations/output/verification/**`
  - CSV summaries, TeX fragments, and figures become report-consumed artifacts only in an explicit refresh lane
- Optional-data behavior: no optional external data required
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_verification.jl")'`

## Membrane-FSI Validation

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/membrane_fsi/membrane_fsi_validation.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/membrane_fsi/membrane_fsi_validation.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/membrane_fsi/membrane_fsi_validation_spec.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/membrane_fsi/membrane_fsi_validation_spec.jl)
- Entrypoints:
  - CLI: `fsi validate`
  - Julia: `run_membrane_fsi_validation(...)`, `MembraneFSIValidationSpec(...)`
- Surface: `CLI-facing`
- Expected outputs and artifact class:
  - Ignored scratch outputs under `tmp/simulations/output/membrane_fsi_validation/**`
  - Optional published assets under `report/assets/data/membrane-fsi/**` and `report/assets/tables/membrane-fsi/**`
- Optional-data behavior: no optional resolved-3D inputs required
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_membrane_fsi.jl")'`

Dynamic wall mode is still a reduced radial membrane time integrator coupled to
repeated quasi-steady Stokes solves. It is not a transient moving-boundary
fluid solve.

## Stationary-Stokes Refinement

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/stationary_stokes_refinement.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/stationary_stokes_refinement.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/stationary_stokes_refinement_spec.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/verification/stationary_stokes_refinement_spec.jl)
- Entrypoints:
  - CLI: `stokes refine`
  - Julia: `run_stationary_stokes_refinement(...)`, `StationaryStokesRefinementSpec(...)`
- Surface: `CLI-facing`
- Expected outputs and artifact class:
  - Ignored scratch outputs under `tmp/simulations/output/stationary_stokes_refinement/**`
  - Published tables or figures are report-consumed artifacts only when explicitly requested
- Optional-data behavior: no optional external data required
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_openbf_stokes.jl")'`

## Geometry Export

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/geometry_exports/geometry_exports.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/geometry_exports/geometry_exports.jl)
- Entrypoints:
  - CLI: `export-assets`
  - Julia: `export_all(...)`, `export_stenosis_geometry_figures(...)`, `GeometryExportOptions(...)`
- Surface: `report/support infrastructure`
- Expected outputs and artifact class:
  - Report-consumed CSV assets under `report/assets/data/stenosis-geometry/**`
  - Renderer inputs for analytic, stationary-Stokes, and resolved-flow figure generation
- Optional-data behavior:
  - Analytic and stationary-Stokes exports are self-contained
  - Resolved-flow helper exports skip cleanly when optional local resolved-3D inputs are absent
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_resolved3d_geometry.jl")'`

## Resolved-3D Import, Comparison, And Report Assets

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d/resolved3d_compare.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d/resolved3d_compare.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d/resolved3d_types_comparison.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d/resolved3d_types_comparison.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d/resolved3d_types_grid_sensitivity.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d/resolved3d_types_grid_sensitivity.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d/resolved3d_types_contracts.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d/resolved3d_types_contracts.jl)
- Entrypoints:
  - CLI: `compare-3d`
  - Julia: `run_comparison(...)`, `run_grid_sensitivity(...)`, `run_available_resolved3d_comparison(...)`, `run_available_resolved3d_grid_sensitivity(...)`
- Surface: `CLI-facing`
- Expected outputs and artifact class:
  - Ignored scratch outputs under `tmp/simulations/output/3d_comparison/**`
  - Optional report-consumed assets under `report/assets/data/stenosis-comparison/**` and `report/assets/tables/stenosis-comparison/**`
- Optional-data behavior:
  - Depends on ignored local XDMF/HDF5 inputs under `public/var/data/simulations/**`
  - Missing inputs must produce skips, not failures, for public-clone validation
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_resolved3d_writer.jl")'`

Use [Resolved-3D Workflows](../resolved3d-workflows.md) for the data-root
contract, skip behavior, and report publication boundaries.

## Operator Validation

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/operator_validation/operator_validation.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/operator_validation/operator_validation.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/operator_validation/operator_validation_types.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/operator_validation/operator_validation_types.jl)
- Entrypoints:
  - CLI: `operator-validation`
  - Julia: `run_operator_validation(...)`, `OperatorValidationSpec(...)`
- Surface: `CLI-facing`
- Expected outputs and artifact class:
  - Ignored scratch outputs under `tmp/simulations/output/operator_validation/**`
  - Optional report-consumed summary tables under `report/assets/data/stenosis-comparison/**` and `report/assets/tables/stenosis-comparison/**`
- Optional-data behavior: no optional resolved-3D inputs required; the workflow uses synthetic in-memory tetrahedral cuts
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_operator_validation.jl")'`

## Package Benchmarks

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/benchmarks/benchmarks.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/benchmarks/benchmarks.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/benchmarks/benchmark_spec.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/benchmarks/benchmark_spec.jl)
- Entrypoints:
  - CLI: `benchmark`
  - Julia: `run_package_benchmark(...)`, `PackageBenchmarkSpec(...)`
- Surface: `CLI-facing`
- Expected outputs and artifact class:
  - Ignored scratch outputs under `tmp/simulations/output/package_benchmark/**`
  - Optional published benchmark tables under `report/assets/data/package-benchmark/**`
- Optional-data behavior:
  - Core benchmark profiles are self-contained
  - Optional resolved-3D rows remain skip-safe when local data is absent
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_package_benchmark.jl")'`

## Native Resolved-FSI Mesh, Smoke, Production Sidecars, And Parity

- Representative files:
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_mesh.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_mesh.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_workflow.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_workflow.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_parity.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_parity.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_workflow_production.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_workflow_production.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_parity_production.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_parity_production.jl)
  - [`packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_restart.jl`](../../../packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_restart.jl)
- Entrypoints:
  - Julia: `native_resolved_fsi_case_spec(...)`,
    `run_native_resolved_fsi_workflow(...)`,
    `run_native_resolved_fsi_smoke(...)`,
    `run_native_resolved_fsi_navier_stokes_smoke(...)`,
    `run_native_resolved_fsi_partitioned_smoke(...)`,
    `run_native_resolved_fsi_parity(...)`,
    `native_resolved_fsi_production_workflow_plans(...)`,
    `native_resolved_fsi_partitioned_production_dry_run(...)`,
    `native_resolved_fsi_partitioned_production_default_guard_report(...)`,
    `native_resolved_fsi_read_restart_metadata(...)`,
    `native_resolved_fsi_resume_partitioned_production(...)`,
    `run_native_resolved_fsi_partitioned_production(...)`
  - CLI: `fsi native-status` prints dry-run/status fields for production guard
    checks, boundary mode, output paths, and optional imported-bundle status.
    Production execution, restart reading/resume, parity execution, and
    observation-artifact generation remain qualified Julia-internal and are not
    CLI commands.
- Surface: `qualified-internal`
- Expected outputs and artifact class:
  - Ignored scratch schema-workflow outputs under `tmp/simulations/output/native-resolved-fsi/**`
  - Ignored scratch fixed-wall and partitioned smoke outputs under `tmp/simulations/output/native-resolved-fsi-smoke/**`
  - Ignored scratch production sidecars and snapshot bundles under `tmp/simulations/output/native-resolved-fsi-production/**`
  - State-carrying production sidecars include `snapshot_manifest.csv`,
    `snapshot_diagnostics.csv`, `restart_metadata.json`, and optional
    Section 4.1 observation artifacts such as
    `section41_observation_summary.csv`
  - High-output generation remains guarded by explicit
    `NativeResolvedFSIPartitionedProductionSpec` values, production workflow
    plans, and dry-run checks
- Optional-data behavior:
  - Mesh generation and native schema smoke are package-owned and do not require a public resolved-3D data root
  - External resolved-3D importer support is retained and supported for legacy
    and supplied XDMF/HDF5 bundles
  - Parity workflows compare against explicitly supplied bundle paths when
    present, and otherwise produce expected skips for unavailable optional
    imported cases
- Focused validation command:
  - `packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'`

Current tiers are intentionally separate:

- Schema workflow: `run_native_resolved_fsi_workflow(...)` writes and reloads a
  generated three-field bundle, including deformed-coordinate importer checks.
- Fixed-wall smoke: the fixed-wall Stokes and Navier-Stokes smoke paths exercise
  the native mesh, Gridap solve, writer, and importer with zero displacement.
- Partitioned smoke: `run_native_resolved_fsi_partitioned_smoke(...)` advances a
  coarse partitioned wall update and prescribes radial wall-velocity Dirichlet
  data on the fluid wall; this is not an ALE formulation.
- Production dry-run: `native_resolved_fsi_partitioned_production_dry_run(...)`
  resolves output, sidecar, guard-report, restart, and imported-parity paths
  without running a solver or writing files. The `fsi native-status` CLI command
  exposes this status boundary without exposing production execution.
- Production sidecars: `run_native_resolved_fsi_partitioned_production(...)`
  runs one state-carrying partitioned snapshot series and writes manifest,
  diagnostics, and restart metadata.
- Restart metadata: `native_resolved_fsi_read_restart_metadata(...)` validates
  legacy and current package-written metadata, including versioned
  `state_payload` audit metadata when present, while
  `native_resolved_fsi_resume_partitioned_production(...)` fails closed because
  persisted state-carrying resume is deferred.
- Observation artifacts: production parity writes native/imported/parity
  observation rows and `section41_observation_summary.csv` through the local
  cross-section velocity and pressure observation operators.
- Boundary-mode status: fixed-wall and partitioned native runs exercise
  package-owned boundary modes. Exact mode is smoke-scale/operator-readiness
  evidence only, not paper-grade Section 4.1 reproduction.

The current family documents generated artifacts, local operator evidence, and
production-control sidecars. Persisted restart, production execution from CLI,
and paper-grade Section 4.1 reproduction claims remain deferred.

## Native Resolved-FSI Notes

- [Native Resolved-FSI Design](native-resolved-fsi-design.md)
- [Native Resolved-FSI Section 4.1 Reproduction](native-resolved-fsi-section-4-1-reproduction.md)

The old package-local copies under `packages/stenotic-hemodynamics/docs/` stay
only as pointer stubs so the public docs tree remains the authoritative site.

## Related Docs

- [Julia CLI Workflows](../julia-cli-workflows.md)
- [Resolved-3D Workflows](../resolved3d-workflows.md)
- [Benchmark Pipeline](../benchmark-pipeline.md)
