if VERSION < v"1.12"
    error(
        "StenosisHemodynamics requires Julia 1.12 or newer. " *
        "Run it with ./scripts/julia-release ... or julia +release --project=....",
    )
end

"""
Finite-volume Canic extended 1D stenotic artery simulation.

Public protocol:

`Params` -> `semidiscretize`/packed RHS -> time backend and `SolveSpec` ->
`simulate` -> `SimulationResult` -> diagnostics or `run_study`.

The package is organized into explicit architecture layers:

- core physical/data model definitions;
- numerical kernels and backend dispatch;
- shared I/O and manifest helpers;
- adapters for external ecosystems and data formats;
- reproducible research workflows;
- a thin command-line interface.

The native backend is the default fixed-step SSP RK3 path. Optional external
ecosystem support is isolated in adapter and workflow files so the core model
can remain small, testable, and extension-friendly.
"""
module StenosisHemodynamics

using SHA
using Statistics

export AbstractTimeBackend,
       AbstractAlgorithmPolicy,
       AbstractInletBoundary,
       AbstractOutletBoundary,
       AbstractRheology,
       AbstractLimiter,
       AbstractInitialConditionSpec,
       AbstractForwardModel,
       AbstractForcingTerm,
       AbstractNativeTimeStepper,
       AbstractSpatialMethod,
       AbstractVelocityProfile,
       AbstractWallLaw,
       AutoPolicy,
       CanicKoiterWallLaw,
       CanicExtendedOneDModel,
       CarreauRheology,
       CarreauYasudaRheology,
       CassonRheology,
       ClassicalNoSlip1DModel,
       AbstractStudySpec,
       CrossSectionQuadratureOperator,
       ComparisonResult,
       ComparisonSpec,
       DGMethod,
       FVFirstOrderMethod,
       FVLaxWendroffMethod,
       FVMUSCLMethod,
       FVWENO3Method,
       FixedAreaCharacteristicOutlet,
       FlatVelocityProfile,
       FlowWaveformInlet,
       ForwardEulerStepper,
       GeometryRestIC,
       GeometryExportOptions,
       GridConvergenceStudySpec,
       InitialConditionSummary,
       MinmodLimiter,
       ManufacturedForcing,
       ManufacturedSolutionIC,
       ManufacturedVerificationResult,
       ManufacturedVerificationSpec,
       NativeSSPRKPolicy,
       NativeRK3Backend,
       NoForcing,
       NodeSlabOperator,
       NewtonianRheology,
       Params,
       OutputSpec,
       OpenBFRunSpec,
       PackageBenchmarkResult,
       PackageBenchmarkSpec,
       PackedStateLayout,
       PHRefinementDemoResult,
       PHRefinementDemoSpec,
       ParabolicVelocityProfile,
       PowerLawRheology,
       PowerVelocityProfile,
       RefinementStudyResult,
       RefinementStudySpec,
       ReflectionCoefficientOutlet,
       Rodas5PPolicy,
       RestStateDriftResult,
       RestStateDriftSpec,
       SciMLTimeBackend,
       Resolved3DCaseSpec,
       Resolved3DVelocityField,
       SimulationResult,
       SimulationDiagnostics,
       SemiDiscreteSimulation,
       SolveSpec,
       SSPRK2Stepper,
       SSPRK3Stepper,
       SSPRK54Stepper,
       StationaryStokesIC,
       StationaryStokesRefinementResult,
       StationaryStokesRefinementSpec,
       SteadyVelocityInlet,
       SeveritySweepSpec,
       StudyResult,
       Tsit5Policy,
       Vern7Policy,
       Vern9Policy,
       algorithm_name,
       algorithm_policy,
       available_resolved3d_cases,
       backend_algorithm_name,
       backend_name,
       characteristic_shear_rate,
       characteristic_speeds,
       default_resolved3d_cases,
       default_resolved3d_data_root,
       degrees_of_freedom,
       effective_dynamic_viscosity,
       effective_kinematic_viscosity,
       export_stenosis_geometry_figures,
       forcing_name,
       forward_model,
       forward_model_name,
       initial_condition,
       initial_condition_name,
       initial_condition_values,
       initial_state_result,
       inlet_boundary_name,
       inlet_flow,
       load_openbf_config,
       load_resolved3d_velocity,
       limiter_name,
       mean_to_max_velocity_ratio,
       minmod,
       model_name,
       momentum_alpha,
       ode_problem,
       outlet_boundary_name,
       pack_state,
       params_from_openbf_config,
       pressure,
       profile_exponent,
       profile_name,
       publish_resolved3d_report_assets,
       radial_profile_velocity,
       run_refinement_study,
       run_manufactured_verification,
       run_ph_refinement_demo,
       run_stationary_stokes_refinement,
       run_rest_state_drift,
       run_available_resolved3d_comparison,
       run_package_benchmark,
       run_cli,
       run_comparison,
       run_simulation,
       rhs!,
       rheology_name,
       run_study,
       semidiscretize,
       shear_rate_factor,
       simulate,
       solve_stationary_stokes,
       spatial_method_name,
       stenosis_throat_z,
       time_stepper_name,
       unpack_state,
       variable_radius_terms_enabled,
       velocity,
       wall_boundary_condition,
       wall_law_name,
       write_csv,
       write_svg

include("StenosisHemodynamics/layers.jl")

include("StenosisHemodynamics/core/logging.jl")
include("StenosisHemodynamics/numerics/methods.jl")
include("StenosisHemodynamics/core/rheology.jl")
include("StenosisHemodynamics/core/initial_conditions.jl")
include("StenosisHemodynamics/core/profiles.jl")
include("StenosisHemodynamics/core/forward_models.jl")
include("StenosisHemodynamics/core/wall_laws.jl")
include("StenosisHemodynamics/core/boundaries.jl")
include("StenosisHemodynamics/core/verification_types.jl")
include("StenosisHemodynamics/core/types.jl")
include("StenosisHemodynamics/workflows/parallel.jl")
include("StenosisHemodynamics/numerics/policies.jl")
include("StenosisHemodynamics/core/geometry.jl")
include("StenosisHemodynamics/numerics/state.jl")
include("StenosisHemodynamics/numerics/model.jl")
include("StenosisHemodynamics/core/diagnostics.jl")
include("StenosisHemodynamics/adapters/stokes_ic.jl")
include("StenosisHemodynamics/numerics/solver.jl")
include("StenosisHemodynamics/numerics/dg.jl")
include("StenosisHemodynamics/adapters/sciml_problem.jl")
include("StenosisHemodynamics/numerics/backends.jl")
include("StenosisHemodynamics/io/writers.jl")
include("StenosisHemodynamics/io/outputs.jl")
include("StenosisHemodynamics/adapters/openbf_protocol.jl")
include("StenosisHemodynamics/workflows/studies.jl")
include("StenosisHemodynamics/workflows/refinement.jl")
include("StenosisHemodynamics/workflows/resolved3d_types.jl")
include("StenosisHemodynamics/adapters/resolved3d_io.jl")
include("StenosisHemodynamics/workflows/resolved3d_compare.jl")
include("StenosisHemodynamics/workflows/resolved3d_outputs.jl")
include("StenosisHemodynamics/workflows/stationary_stokes_refinement.jl")
include("StenosisHemodynamics/workflows/verification.jl")
include("StenosisHemodynamics/workflows/geometry_exports.jl")
include("StenosisHemodynamics/workflows/benchmarks.jl")
include("StenosisHemodynamics/cli/cli.jl")

end
