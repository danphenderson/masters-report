abstract type AbstractStudySpec end

"""
    SeveritySweepSpec(; base_params, severities, backend, summary_csv, overwrite, parallel_workers)

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

"""One scalar diagnostic row from a study run."""
struct StudyRunSummary
    study_kind::String
    severity::Float64
    nx::Int
    dx::Float64
    backend::String
    algorithm::String
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
    rheology::AbstractRheology = p.rheology,
    space::AbstractSpatialMethod = p.space,
    time_stepper::AbstractNativeTimeStepper = p.time_stepper,
    initial_condition::AbstractInitialConditionSpec = p.initial_condition,
    velocity_profile::AbstractVelocityProfile = p.velocity_profile,
    inlet_boundary::AbstractInletBoundary = p.inlet_boundary,
    outlet_boundary::AbstractOutletBoundary = p.outlet_boundary,
    young::Float64 = p.young,
    wall_h::Float64 = p.wall_h,
    sigma::Float64 = p.sigma,
    alpha::Union{Nothing,Float64} = nothing,
    inlet_umax::Float64 = p.inlet_umax,
)
    if alpha !== nothing && velocity_profile != p.velocity_profile
        throw(ArgumentError("provide velocity_profile or alpha, not both"))
    end
    resolved_profile = alpha === nothing ? velocity_profile : PowerVelocityProfile(alpha=alpha)
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
        rheology=rheology,
        space=space,
        time_stepper=time_stepper,
        initial_condition=initial_condition,
        velocity_profile=resolved_profile,
        inlet_boundary=inlet_boundary,
        outlet_boundary=outlet_boundary,
        young=young,
        wall_h=wall_h,
        sigma=sigma,
        inlet_umax=inlet_umax,
    )
end

"""
    run_study(spec) -> StudyResult

Execute a severity or grid study. Independent cases run in parallel when
`parallel_workers` is greater than one.
"""
function run_study(spec::SeveritySweepSpec)
    rows = parallel_case_map(spec.severities; parallel_workers=spec.parallel_workers) do severity
        params = params_with(spec.base_params; severity=severity)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        summarize_study_run("severity_sweep", params, spec.backend, result)
    end

    path = study_summary_path(spec)
    study = StudyResult("severity_sweep", rows, path)
    write_study_csv(path, study; overwrite=spec.overwrite)
    return study
end

function run_study(spec::GridConvergenceStudySpec)
    rows = parallel_case_map(spec.nxs; parallel_workers=spec.parallel_workers) do nx
        params = params_with(spec.base_params; nx=nx)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        summarize_study_run("grid_convergence", params, spec.backend, result)
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
        backend isa NativeRK3Backend ? time_stepper_name(params.time_stepper) : backend_algorithm_name(backend),
        spatial_method_name(params.space),
        time_stepper_name(params.time_stepper),
        rheology_name(params.rheology),
        profile_name(params.velocity_profile),
        params.alpha,
        profile_exponent(params.velocity_profile),
        shear_rate_factor(params.velocity_profile),
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
    profile_token = velocity_profile_path_token(spec.base_params.velocity_profile)
    return joinpath(
        "simulations",
        "output",
        "canic_extended_1d_severity_sweep_vp_$(profile_token)_s$(severity_token)_nx$(spec.base_params.nx)_t$(path_token(spec.base_params.tfinal)).csv",
    )
end

function default_study_summary_path(spec::GridConvergenceStudySpec)
    nx_token = join(spec.nxs, "-")
    profile_token = velocity_profile_path_token(spec.base_params.velocity_profile)
    return joinpath(
        "simulations",
        "output",
        "canic_extended_1d_grid_convergence_vp_$(profile_token)_nx$(nx_token)_s$(path_token(spec.base_params.severity))_t$(path_token(spec.base_params.tfinal)).csv",
    )
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
        "spatial_method",
        "time_stepper",
        "rheology",
        "velocity_profile",
        "alpha",
        "profile_exponent",
        "shear_rate_factor",
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
        row.spatial_method,
        row.time_stepper,
        row.rheology,
        row.velocity_profile,
        row.alpha,
        row.profile_exponent,
        row.shear_rate_factor,
        row.steps,
        row.final_time,
        row.velocity_min,
        row.velocity_max,
        row.pressure_min,
        row.pressure_max,
        row.min_area,
    ), ",")
end
