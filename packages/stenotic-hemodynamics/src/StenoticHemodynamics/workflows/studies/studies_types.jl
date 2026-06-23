"""
    AbstractStudySpec

Workflow specification protocol for reusable reduced 1D study runs.

Concrete study specs define `workflow_kind(spec)`, `validate(spec)`, and
`default_output_paths(spec)`. Public entrypoints should call
`validate_workflow_spec(spec)` before running cases and should return typed
result objects rather than raw file paths.
"""
abstract type AbstractStudySpec end

"""
    SeveritySweepSpec(; base_params, severities, backend, summary_csv, overwrite, parallel_workers)

Run the same reduced 1D case over multiple stenosis severities and write a
compact study summary CSV.
"""
struct SeveritySweepSpec <: AbstractStudySpec
    base_params::Params
    severities::Vector{Float64}
    backend::AbstractTimeBackend
    summary_csv::String
    overwrite::Bool
    progress_every::Int
    parallel_workers::Int
end

function SeveritySweepSpec(;
    base_params::Params = Params(initial_condition=GeometryRestIC()),
    severities,
    backend::AbstractTimeBackend = NativeRK3Backend(),
    summary_csv::String = "",
    overwrite::Bool = false,
    progress_every::Int = 0,
    parallel_workers::Int = default_case_workers(),
)
    severity_values = [Float64(value) for value in severities]
    isempty(severity_values) && throw(ArgumentError("severity sweep must include at least one severity"))
    progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    for severity in severity_values
        validate(params_with(base_params; severity=severity))
    end
    return SeveritySweepSpec(base_params, severity_values, backend, summary_csv, overwrite, progress_every, parallel_workers)
end

"""
    GridConvergenceStudySpec(; base_params, nxs, backend, summary_csv, overwrite, parallel_workers)

Run the same reduced 1D case over multiple finite-volume grid sizes and write a
compact study summary CSV.
"""
struct GridConvergenceStudySpec <: AbstractStudySpec
    base_params::Params
    nxs::Vector{Int}
    backend::AbstractTimeBackend
    summary_csv::String
    overwrite::Bool
    progress_every::Int
    parallel_workers::Int
end

function GridConvergenceStudySpec(;
    base_params::Params = Params(initial_condition=GeometryRestIC()),
    nxs,
    backend::AbstractTimeBackend = NativeRK3Backend(),
    summary_csv::String = "",
    overwrite::Bool = false,
    progress_every::Int = 0,
    parallel_workers::Int = default_case_workers(),
)
    nx_values = [Int(value) for value in nxs]
    isempty(nx_values) && throw(ArgumentError("grid convergence study must include at least one nx value"))
    progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    for nx in nx_values
        validate(params_with(base_params; nx=nx))
    end
    return GridConvergenceStudySpec(base_params, nx_values, backend, summary_csv, overwrite, progress_every, parallel_workers)
end

"""
    workflow_kind(spec) -> String

Internal stable identifier for a workflow result family.
"""
workflow_kind(::SeveritySweepSpec) = "severity_sweep"
workflow_kind(::GridConvergenceStudySpec) = "grid_convergence"

function validate(spec::SeveritySweepSpec)
    isempty(spec.severities) && throw(ArgumentError("severity sweep must include at least one severity"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    spec.parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    for severity in spec.severities
        params = params_with(spec.base_params; severity=severity)
        validate(params)
        assert_backend_supported(params.space, spec.backend)
    end
    return spec
end

function validate(spec::GridConvergenceStudySpec)
    isempty(spec.nxs) && throw(ArgumentError("grid convergence study must include at least one nx value"))
    all(nx -> nx >= 3, spec.nxs) || throw(ArgumentError("all grid convergence sizes must be at least 3"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    spec.parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    for nx in spec.nxs
        params = params_with(spec.base_params; nx=nx)
        validate(params)
        assert_backend_supported(params.space, spec.backend)
    end
    return spec
end

"""
    validate_workflow_spec(spec)

Validate a study spec through its local `validate` method. New workflow specs
can specialize this when validation requires adapter-specific setup.
"""
validate_workflow_spec(spec) = validate(spec)

"""
    default_output_paths(spec) -> NamedTuple

Return the output paths a study workflow would use after applying its default
path rules. The named tuple shape is local to each workflow family.
"""
default_output_paths(spec::SeveritySweepSpec) = (summary_csv=study_summary_path(spec),)
default_output_paths(spec::GridConvergenceStudySpec) = (summary_csv=study_summary_path(spec),)

"""One scalar diagnostic row summarizing a single reduced 1D study case."""
struct StudyRunSummary
    study_kind::String
    severity::Float64
    nx::Int
    dx::Float64
    backend::String
    algorithm::String
    model::String
    variable_radius_terms::Bool
    wall_law::String
    spatial_method::String
    time_stepper::String
    rheology::String
    velocity_profile::String
    alpha::Float64
    profile_exponent::Float64
    shear_rate_factor::Float64
    steps::Int
    final_time::Float64
    velocity_min::Float64
    velocity_max::Float64
    pressure_min::Float64
    pressure_max::Float64
    min_area::Float64
end

"""Return value from `run_study`, including reduced 1D summary rows and CSV path."""
struct StudyResult
    study_kind::String
    summaries::Vector{StudyRunSummary}
    summary_csv::String
end
