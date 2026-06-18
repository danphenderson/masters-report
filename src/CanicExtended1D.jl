if VERSION < v"1.12"
    error(
        "CanicExtended1D requires Julia 1.12 or newer. " *
        "Run it with ./scripts/julia-release ... or julia +release --project=....",
    )
end

"""
Finite-volume Canic extended 1D stenotic artery simulation.

Public protocol:

`Params` -> `semidiscretize`/packed RHS -> time backend and `SolveSpec` ->
`simulate` -> `SimulationResult` -> diagnostics or `run_study`.

The native backend is the default fixed-step SSP RK3 path. SciML support is
kept behind backend/adapter code so geometry, model equations, and output code
do not depend directly on SciML packages.
"""
module CanicExtended1D

using SHA

export AbstractTimeBackend,
       AbstractAlgorithmPolicy,
       AbstractInletBoundary,
       AbstractOutletBoundary,
       AbstractRheology,
       AbstractLimiter,
       AbstractInitialConditionSpec,
       AbstractNativeTimeStepper,
       AbstractSpatialMethod,
       AbstractVelocityProfile,
       AutoPolicy,
       CarreauRheology,
       CarreauYasudaRheology,
       CassonRheology,
       AbstractStudySpec,
       CrossSectionQuadratureOperator,
       ComparisonResult,
       ComparisonSpec,
       ComparisonSummaryRow,
       DGMethod,
       FVFirstOrderMethod,
       FVLaxWendroffMethod,
       FVMUSCLMethod,
       FixedAreaCharacteristicOutlet,
       FlatVelocityProfile,
       FlowWaveformInlet,
       ForwardEulerStepper,
       GeneratedStokesMesh,
       GeometryRestIC,
       GeometryExportOptions,
       GridConvergenceStudySpec,
       InitialConditionSummary,
       MinmodLimiter,
       NativeSSPRKPolicy,
       NativeRK3Backend,
       NodeSlabOperator,
       NodeSlabSensitivityRow,
       NewtonianRheology,
       Params,
       OutputSpec,
       OpenBFRunSpec,
       PackageBenchmarkResult,
       PackageBenchmarkSpec,
       PackedStateLayout,
       ParabolicVelocityProfile,
       PowerLawRheology,
       PowerVelocityProfile,
       RefinementStudyResult,
       RefinementStudySpec,
       RefinementStudyRow,
       ReflectionCoefficientOutlet,
       Rodas5PPolicy,
       SciMLTimeBackend,
       RadialProfileRow,
       Resolved3DCaseSpec,
       Resolved3DVelocityField,
       SectionComparisonRow,
       SimulationResult,
       SemiDiscreteSimulation,
       SolveSpec,
       SSPRK2Stepper,
       SSPRK3Stepper,
       StationaryStokesIC,
       StationaryStokesRefinementResult,
       StationaryStokesRefinementRow,
       StationaryStokesRefinementSpec,
       SteadyVelocityInlet,
       SeveritySweepSpec,
       StudyResult,
       StudyRunSummary,
       Tsit5Policy,
       XDMFVelocityMetadata,
       area_view,
       algorithm_name,
       algorithm_policy,
       available_resolved3d_cases,
       backend_algorithm_name,
       backend_name,
       characteristic_shear_rate,
       default_output_stub,
       default_resolved3d_cases,
       default_resolved3d_data_root,
       default_refinement_output_dir,
       default_study_summary_path,
       dg_degrees_of_freedom,
       dg_quadrature,
       effective_dynamic_viscosity,
       effective_kinematic_viscosity,
       export_stenosis_geometry_figures,
       flow_view,
       initial_condition,
       initial_condition_name,
       initial_condition_values,
       initial_state_result,
       inlet_boundary_name,
       inlet_flow,
       generated_stokes_mesh,
       load_openbf_config,
       load_resolved3d_velocity,
       legendre_derivative,
       legendre_value,
       limiter_name,
       mean_to_max_velocity_ratio,
       minmod,
       momentum_alpha,
       observed_order,
       ode_problem,
       outlet_boundary_name,
       pack_state,
       parse_xdmf_velocity,
       parallel_case_map,
       parse_args,
       params_from_openbf_config,
       pressure,
       profile_exponent,
       profile_name,
       publish_resolved3d_report_assets,
       radial_profile_velocity,
       run_refinement_study,
       run_stationary_stokes_refinement,
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
       state_views,
       stenosis_throat_z,
       study_summary_path,
       time_stepper_name,
       unpack_state,
       velocity,
       write_comparison_csvs,
       write_csv,
       write_refinement_latex_tables,
       write_refinement_study_csv,
       write_section_comparison_svg,
       write_stationary_stokes_refinement_csv,
       write_study_csv,
       write_svg

include("CanicExtended1D/logging.jl")
include("CanicExtended1D/methods.jl")
include("CanicExtended1D/rheology.jl")
include("CanicExtended1D/initial_conditions.jl")
include("CanicExtended1D/profiles.jl")
include("CanicExtended1D/boundaries.jl")
include("CanicExtended1D/types.jl")
include("CanicExtended1D/parallel.jl")
include("CanicExtended1D/policies.jl")
include("CanicExtended1D/geometry.jl")
include("CanicExtended1D/state.jl")
include("CanicExtended1D/model.jl")
include("CanicExtended1D/stokes_ic.jl")
include("CanicExtended1D/solver.jl")
include("CanicExtended1D/dg.jl")
include("CanicExtended1D/sciml_problem.jl")
include("CanicExtended1D/backends.jl")
include("CanicExtended1D/outputs.jl")
include("CanicExtended1D/openbf_protocol.jl")
include("CanicExtended1D/studies.jl")
include("CanicExtended1D/refinement.jl")
include("CanicExtended1D/resolved3d_types.jl")
include("CanicExtended1D/resolved3d_io.jl")
include("CanicExtended1D/resolved3d_compare.jl")
include("CanicExtended1D/resolved3d_outputs.jl")
include("CanicExtended1D/stationary_stokes_refinement.jl")
include("CanicExtended1D/geometry_exports.jl")
include("CanicExtended1D/benchmarks.jl")
include("CanicExtended1D/cli.jl")

end
