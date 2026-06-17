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
       AutoPolicy,
       AbstractStudySpec,
       ComparisonResult,
       ComparisonSpec,
       ComparisonSummaryRow,
       GridConvergenceStudySpec,
       NativeSSPRKPolicy,
       NativeRK3Backend,
       Params,
       OutputSpec,
       PackedStateLayout,
       Rodas5PPolicy,
       SciMLTimeBackend,
       RadialProfileRow,
       Resolved3DCaseSpec,
       Resolved3DVelocityField,
       SectionComparisonRow,
       SimulationResult,
       SemiDiscreteSimulation,
       SolveSpec,
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
       default_output_stub,
       default_resolved3d_cases,
       default_resolved3d_data_root,
       default_study_summary_path,
       flow_view,
       initial_condition,
       load_resolved3d_velocity,
       ode_problem,
       pack_state,
       parse_xdmf_velocity,
       parse_args,
       pressure,
       run_available_resolved3d_comparison,
       run_cli,
       run_comparison,
       rhs!,
       run_study,
       semidiscretize,
       simulate,
       state_views,
       stenosis_throat_z,
       study_summary_path,
       unpack_state,
       velocity,
       write_comparison_csvs,
       write_csv,
       write_section_comparison_svg,
       write_study_csv,
       write_svg

include("types.jl")
include("policies.jl")
include("geometry.jl")
include("state.jl")
include("model.jl")
include("solver.jl")
include("sciml_problem.jl")
include("backends.jl")
include("outputs.jl")
include("studies.jl")
include("resolved3d.jl")
include("cli.jl")

end
