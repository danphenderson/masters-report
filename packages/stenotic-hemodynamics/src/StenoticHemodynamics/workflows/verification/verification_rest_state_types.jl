# Types, defaults, and CLI value parsing for geometry-rest drift verification.

"""
    RestStateDriftSpec

Configure zero-forcing, zero-inlet geometry-rest drift verification cases.
"""
Base.@kwdef struct RestStateDriftSpec{B<:AbstractTimeBackend} <: AbstractStudySpec
    base_params::Params = Params(;
        severity=23.0,
        nx=80,
        tfinal=1.0e-3,
        dt=1.0e-5,
        initial_condition=GeometryRestIC(),
        forcing=NoForcing(),
        inlet_umax=0.0,
        space=FVMUSCLMethod(),
        time_stepper=SSPRK3Stepper(),
    )
    severities::Vector{Float64} = [23.0, 40.0]
    nxs::Vector{Int} = [50, 100, 200]
    elapsed_times::Vector{Float64} = [0.0, 1.0e-3, 5.0e-3]
    backend::B = NativeRK3Backend()
    output_dir::String = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification")
    summary_csv::String = ""
    summary_tex::String = ""
    overwrite::Bool = false
    progress_every::Int = 0
end

Base.@kwdef struct RestStateDriftRow
    severity::Float64
    nx::Int
    dx::Float64
    elapsed_time_s::Float64
    requested_time_s::Float64
    terminal_time_error_s::Float64
    max_abs_q::Float64
    max_abs_q_z::Float64
    max_abs_area_drift::Float64
    solver_volume_defect::Float64
    physical_volume_defect::Float64
    requested_q_in::Float64
    applied_q_in::Float64
    inlet_area_flux::Float64
    outlet_area_flux::Float64
    boundary_flux_integral::Float64
    conservation_residual::Float64
    inlet_cell_q::Float64
    outlet_cell_q::Float64
    mean_q::Float64
    rms_q::Float64
    lh_area_interior_max_abs::Float64
    lh_area_boundary_max_abs::Float64
    lh_flow_interior_max_abs::Float64
    lh_flow_boundary_max_abs::Float64
    realized_cfl_max::Float64
    lambda_minus_min::Float64
    lambda_plus_max::Float64
    subcritical_margin_min::Float64
    positivity_projection_count::Int
    positivity_correction_total::Float64
    status::String
    error_message::String
end

Base.@kwdef struct RestStateResidualComponentRow
    severity::Float64
    nx::Int
    dx::Float64
    mass_flux_rusanov_max_abs::Float64
    mass_flux_rusanov_z_cm::Float64
    elastic_flux_difference_max_abs::Float64
    elastic_flux_difference_z_cm::Float64
    wall_geometry_source_max_abs::Float64
    wall_geometry_source_z_cm::Float64
    total_flow_residual_max_abs::Float64
    total_flow_residual_z_cm::Float64
    total_area_residual_max_abs::Float64
    status::String
    error_message::String
end

"""
    RestStateDriftResult

Bundle the drift rows, residual rows, and emitted report paths for one run.
"""
struct RestStateDriftResult{S<:RestStateDriftSpec}
    spec::S
    rows::Vector{RestStateDriftRow}
    residual_rows::Vector{RestStateResidualComponentRow}
    summary_csv::String
    summary_tex::String
    profile_csv::String
    residual_csv::String
    residual_tex::String
end

workflow_kind(::RestStateDriftSpec) = "rest_state_drift"

function validate(spec::RestStateDriftSpec)
    validate(spec.base_params)
    spec.base_params.initial_condition isa GeometryRestIC ||
        throw(ArgumentError("rest-state drift requires base_params.initial_condition=GeometryRestIC()"))
    spec.base_params.forcing isa NoForcing ||
        throw(ArgumentError("rest-state drift requires base_params.forcing=NoForcing()"))
    !isempty(spec.severities) || throw(ArgumentError("rest-state drift requires at least one severity"))
    !isempty(spec.nxs) || throw(ArgumentError("rest-state drift requires at least one grid"))
    !isempty(spec.elapsed_times) || throw(ArgumentError("rest-state drift requires at least one elapsed time"))
    all(nx -> nx >= 3, spec.nxs) || throw(ArgumentError("all rest-state drift grids must be at least 3"))
    all(t -> t >= 0.0, spec.elapsed_times) || throw(ArgumentError("all rest-state drift times must be nonnegative"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    return spec
end

function rest_state_drift_csv_path(spec::RestStateDriftSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    return joinpath(spec.output_dir, "rest_state_drift.csv")
end

function rest_state_drift_tex_path(spec::RestStateDriftSpec)
    !isempty(spec.summary_tex) && return spec.summary_tex
    return joinpath(spec.output_dir, "rest_state_drift.tex")
end

function rest_state_drift_profile_csv_path(spec::RestStateDriftSpec)
    return joinpath(spec.output_dir, "rest_state_drift_profiles.csv")
end

function rest_state_residual_components_csv_path(spec::RestStateDriftSpec)
    return joinpath(spec.output_dir, "rest_state_residual_components.csv")
end

function rest_state_residual_components_tex_path(spec::RestStateDriftSpec)
    return joinpath(spec.output_dir, "rest_state_residual_components.tex")
end

function rest_state_drift_full_tex_path(path::String)
    return endswith(path, ".tex") ? replace(path, r"\.tex$" => "_full.tex") : path * "_full.tex"
end

function rest_state_drift_spec_from_values(
    values::Dict{String,String},
    flags::Set{String};
    output_dir::String = get(values, "output-dir", joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification")),
    overwrite::Bool = "overwrite" in flags,
    progress_every::Int = parse(Int, get(values, "progress-every", "0")),
)
    base_params = Params(;
        nx=parse(Int, get(values, "nx", "80")),
        tfinal=parse(Float64, get(values, "tfinal", "1e-3")),
        dt=parse(Float64, get(values, "dt", "1e-5")),
        severity=parse(Float64, get(values, "severity", "23")),
        initial_condition=GeometryRestIC(),
        forcing=NoForcing(),
        inlet_umax=parse(Float64, get(values, "inlet-umax", "0.0")),
        space=spatial_method_from_cli(values),
        time_stepper=time_stepper_from_cli(values),
        velocity_profile=velocity_profile_from_cli(values),
        rheology=rheology_from_cli(values),
        model=model_from_cli(values),
    )
    return RestStateDriftSpec(;
        base_params=base_params,
        severities=parse_float_list(get(values, "severities", "23,40")),
        nxs=parse_int_list(get(values, "nxs", "50,100,200")),
        elapsed_times=parse_float_list(get(values, "elapsed-times", "0,0.001,0.005")),
        output_dir=output_dir,
        summary_csv=get(values, "summary-csv", ""),
        summary_tex=get(values, "summary-tex", ""),
        overwrite=overwrite,
        progress_every=progress_every,
    )
end

default_output_paths(spec::RestStateDriftSpec) = (
    summary_csv=rest_state_drift_csv_path(spec),
    summary_tex=rest_state_drift_tex_path(spec),
    full_tex=rest_state_drift_full_tex_path(rest_state_drift_tex_path(spec)),
    profile_csv=rest_state_drift_profile_csv_path(spec),
    residual_csv=rest_state_residual_components_csv_path(spec),
    residual_tex=rest_state_residual_components_tex_path(spec),
)
