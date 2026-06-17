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
       GridConvergenceStudySpec,
       InitialConditionSummary,
       MinmodLimiter,
       NativeSSPRKPolicy,
       NativeRK3Backend,
       NewtonianRheology,
       Params,
       OutputSpec,
       OpenBFRunSpec,
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
       radial_profile_velocity,
       run_refinement_study,
       run_available_resolved3d_comparison,
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
       write_study_csv,
       write_svg

include("methods.jl")
include("rheology.jl")
include("initial_conditions.jl")
include("profiles.jl")
include("boundaries.jl")
include("types.jl")
include("parallel.jl")
include("policies.jl")
include("geometry.jl")
include("state.jl")
include("model.jl")
include("stokes_ic.jl")
include("solver.jl")
include("dg.jl")
include("sciml_problem.jl")
include("backends.jl")
include("outputs.jl")
include("openbf_protocol.jl")
include("studies.jl")
include("refinement.jl")
include("resolved3d.jl")
include("cli.jl")

end
