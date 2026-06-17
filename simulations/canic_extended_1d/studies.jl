abstract type AbstractStudySpec end

"""
    SeveritySweepSpec(; base_params, severities, backend, summary_csv, overwrite)

Run the same case over multiple stenosis severities and write a compact study
summary CSV.
"""
struct SeveritySweepSpec <: AbstractStudySpec
    base_params::Params
    severities::Vector{Float64}
    backend::AbstractTimeBackend
    summary_csv::String
    overwrite::Bool
    progress_every::Int
end

function SeveritySweepSpec(;
    base_params::Params = Params(),
    severities,
    backend::AbstractTimeBackend = NativeRK3Backend(),
    summary_csv::String = "",
    overwrite::Bool = false,
    progress_every::Int = 0,
)
    severity_values = [Float64(value) for value in severities]
    isempty(severity_values) && throw(ArgumentError("severity sweep must include at least one severity"))
    progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    for severity in severity_values
        validate(params_with(base_params; severity=severity))
    end
    return SeveritySweepSpec(base_params, severity_values, backend, summary_csv, overwrite, progress_every)
end

"""
    GridConvergenceStudySpec(; base_params, nxs, backend, summary_csv, overwrite)

Run the same case over multiple finite-volume grid sizes and write a compact
study summary CSV.
"""
struct GridConvergenceStudySpec <: AbstractStudySpec
    base_params::Params
    nxs::Vector{Int}
    backend::AbstractTimeBackend
    summary_csv::String
    overwrite::Bool
    progress_every::Int
end

function GridConvergenceStudySpec(;
    base_params::Params = Params(),
    nxs,
    backend::AbstractTimeBackend = NativeRK3Backend(),
    summary_csv::String = "",
    overwrite::Bool = false,
    progress_every::Int = 0,
)
    nx_values = [Int(value) for value in nxs]
    isempty(nx_values) && throw(ArgumentError("grid convergence study must include at least one nx value"))
    progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    for nx in nx_values
        validate(params_with(base_params; nx=nx))
    end
    return GridConvergenceStudySpec(base_params, nx_values, backend, summary_csv, overwrite, progress_every)
end

"""One scalar diagnostic row from a study run."""
struct StudyRunSummary
    study_kind::String
    severity::Float64
    nx::Int
    dx::Float64
    backend::String
    algorithm::String
    steps::Int
    final_time::Float64
    velocity_min::Float64
    velocity_max::Float64
    pressure_min::Float64
    pressure_max::Float64
    min_area::Float64
end

"""Return value from `run_study`, including summary rows and CSV path."""
struct StudyResult
    study_kind::String
    summaries::Vector{StudyRunSummary}
    summary_csv::String
end

function params_with(
    p::Params;
    nx::Int = p.nx,
    length_cm::Float64 = p.length_cm,
    tfinal::Float64 = p.tfinal,
    dt::Float64 = p.dt,
    cfl::Float64 = p.cfl,
    severity::Float64 = p.severity,
    rmax::Float64 = p.rmax,
    rho::Float64 = p.rho,
    nu::Float64 = p.nu,
    young::Float64 = p.young,
    wall_h::Float64 = p.wall_h,
    sigma::Float64 = p.sigma,
    alpha::Float64 = p.alpha,
    inlet_umax::Float64 = p.inlet_umax,
)
    return Params(
        nx=nx,
        length_cm=length_cm,
        tfinal=tfinal,
        dt=dt,
        cfl=cfl,
        severity=severity,
        rmax=rmax,
        rho=rho,
        nu=nu,
        young=young,
        wall_h=wall_h,
        sigma=sigma,
        alpha=alpha,
        inlet_umax=inlet_umax,
    )
end

"""
    run_study(spec) -> StudyResult

Execute a severity or grid study sequentially. Each row calls
`simulate(params, backend)`, so studies share the single-run protocol.
"""
function run_study(spec::SeveritySweepSpec)
    rows = StudyRunSummary[]
    for severity in spec.severities
        params = params_with(spec.base_params; severity=severity)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        push!(rows, summarize_study_run("severity_sweep", params, spec.backend, result))
    end

    path = study_summary_path(spec)
    study = StudyResult("severity_sweep", rows, path)
    write_study_csv(path, study; overwrite=spec.overwrite)
    return study
end

function run_study(spec::GridConvergenceStudySpec)
    rows = StudyRunSummary[]
    for nx in spec.nxs
        params = params_with(spec.base_params; nx=nx)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        push!(rows, summarize_study_run("grid_convergence", params, spec.backend, result))
    end

    path = study_summary_path(spec)
    study = StudyResult("grid_convergence", rows, path)
    write_study_csv(path, study; overwrite=spec.overwrite)
    return study
end

function summarize_study_run(
    study_kind::String,
    params::Params,
    backend::AbstractTimeBackend,
    result::SimulationResult,
)
    u = velocity(result)
    P = pressure(result, params)
    return StudyRunSummary(
        study_kind,
        params.severity,
        params.nx,
        params.length_cm / params.nx,
        backend_name(backend),
        backend_algorithm_name(backend),
        result.steps,
        result.completed_time,
        minimum(u),
        maximum(u),
        minimum(P),
        maximum(P),
        minimum(result.area),
    )
end

function study_summary_path(spec::AbstractStudySpec)
    return isempty(spec.summary_csv) ? default_study_summary_path(spec) : spec.summary_csv
end

function default_study_summary_path(spec::SeveritySweepSpec)
    severity_token = join(map(path_token, spec.severities), "-")
    return joinpath(
        "simulations",
        "output",
        "canic_extended_1d_severity_sweep_s$(severity_token)_nx$(spec.base_params.nx)_t$(path_token(spec.base_params.tfinal)).csv",
    )
end

function default_study_summary_path(spec::GridConvergenceStudySpec)
    nx_token = join(spec.nxs, "-")
    return joinpath(
        "simulations",
        "output",
        "canic_extended_1d_grid_convergence_nx$(nx_token)_s$(path_token(spec.base_params.severity))_t$(path_token(spec.base_params.tfinal)).csv",
    )
end

function path_token(value)
    return replace(string(value), "." => "p", "-" => "m", "+" => "")
end

"""
    write_study_csv(path, study; overwrite=false)

Write compact study diagnostics without changing the single-run profile CSV
format.
"""
function write_study_csv(path::String, study::StudyResult; overwrite::Bool = false)
    ensure_parent(path)
    if isfile(path) && !overwrite
        throw(ArgumentError("refusing to overwrite existing study summary '$path'; pass overwrite=true to allow replacement"))
    end

    open(path, "w") do io
        println(io, study_summary_header())
        for row in study.summaries
            println(io, study_summary_row(row))
        end
    end
    return path
end

function write_study_csv(path::String, rows::Vector{StudyRunSummary}; overwrite::Bool = false)
    return write_study_csv(path, StudyResult("study", rows, path); overwrite=overwrite)
end

function study_summary_header()
    return join((
        "study_kind",
        "severity",
        "nx",
        "dx",
        "backend",
        "algorithm",
        "steps",
        "final_time",
        "velocity_min",
        "velocity_max",
        "pressure_min",
        "pressure_max",
        "min_area",
    ), ",")
end

function study_summary_row(row::StudyRunSummary)
    return join((
        row.study_kind,
        row.severity,
        row.nx,
        row.dx,
        row.backend,
        row.algorithm,
        row.steps,
        row.final_time,
        row.velocity_min,
        row.velocity_max,
        row.pressure_min,
        row.pressure_max,
        row.min_area,
    ), ",")
end
