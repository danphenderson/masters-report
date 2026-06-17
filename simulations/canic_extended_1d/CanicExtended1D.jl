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
       AbstractRheology,
       AbstractLimiter,
       AbstractInitialConditionSpec,
       AbstractNativeTimeStepper,
       AbstractSpatialMethod,
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
       PackedStateLayout,
       PowerLawRheology,
       RefinementStudyResult,
       RefinementStudySpec,
       RefinementStudyRow,
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
       generated_stokes_mesh,
       load_resolved3d_velocity,
       legendre_derivative,
       legendre_value,
       limiter_name,
       minmod,
       observed_order,
       ode_problem,
       pack_state,
       parse_xdmf_velocity,
       parse_args,
       pressure,
       run_refinement_study,
       run_available_resolved3d_comparison,
       run_cli,
       run_comparison,
       rhs!,
       rheology_name,
       run_study,
       semidiscretize,
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
include("types.jl")
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
include("studies.jl")
include("refinement.jl")
include("resolved3d.jl")
include("cli.jl")

end
