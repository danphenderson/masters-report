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
       GridConvergenceStudySpec,
       NativeSSPRKPolicy,
       NativeRK3Backend,
       Params,
       OutputSpec,
       PackedStateLayout,
       Rodas5PPolicy,
       SciMLTimeBackend,
       SimulationResult,
       SemiDiscreteSimulation,
       SolveSpec,
       SeveritySweepSpec,
       StudyResult,
       StudyRunSummary,
       Tsit5Policy,
       area_view,
       algorithm_name,
       algorithm_policy,
       backend_algorithm_name,
       backend_name,
       default_output_stub,
       default_study_summary_path,
       flow_view,
       initial_condition,
       ode_problem,
       pack_state,
       parse_args,
       pressure,
       run_cli,
       rhs!,
       run_study,
       semidiscretize,
       simulate,
       state_views,
       study_summary_path,
       unpack_state,
       velocity,
       write_csv,
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
include("cli.jl")

end
