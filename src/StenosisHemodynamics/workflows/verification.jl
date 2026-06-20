using Printf

Base.@kwdef struct ManufacturedVerificationSpec{B<:AbstractTimeBackend} <: AbstractStudySpec
    base_params::Params = Params(;
        severity=0.0,
        nx=40,
        tfinal=2.0e-4,
        dt=5.0e-6,
        initial_condition=ManufacturedSolutionIC(),
        forcing=ManufacturedForcing(),
        space=FVMUSCLMethod(),
        time_stepper=SSPRK3Stepper(),
    )
    nxs::Vector{Int} = [20, 40, 80]
    dt_values::Vector{Float64} = [2.0e-5, 1.0e-5, 5.0e-6]
    backend::B = NativeRK3Backend()
    output_dir::String = joinpath("simulations", "output", "verification")
    summary_csv::String = ""
    summary_tex::String = ""
    overwrite::Bool = false
    progress_every::Int = 0
end

Base.@kwdef struct ManufacturedVerificationRow
    study_kind::String
    nx::Int
    dx::Float64
    dt::Float64
    tfinal::Float64
    area_l1_error::Float64
    area_l2_error::Float64
    area_linf_error::Float64
    area_observed_order::Float64
    flow_l1_error::Float64
    flow_l2_error::Float64
    flow_linf_error::Float64
    flow_observed_order::Float64
    accepted_dt_min::Float64
    accepted_dt_max::Float64
    realized_cfl_max::Float64
    independent_mass_forcing_max_abs_diff::Float64
    independent_momentum_forcing_max_abs_diff::Float64
    status::String
    error_message::String
end

struct ManufacturedVerificationResult{S<:ManufacturedVerificationSpec}
    spec::S
    rows::Vector{ManufacturedVerificationRow}
    summary_csv::String
    summary_tex::String
end

Base.@kwdef struct PHRefinementDemoSpec <: AbstractStudySpec
    base_params::Params = Params(;
        severity=0.0,
        nx=40,
        tfinal=2.0e-4,
        dt=5.0e-7,
        initial_condition=ManufacturedSolutionIC(),
        forcing=ManufacturedForcing(),
        space=DGMethod(2),
        time_stepper=SSPRK3Stepper(),
    )
    h_nxs::Vector{Int} = [20, 40, 80, 160]
    h_degree::Int = 2
    degrees::Vector{Int} = [0, 1, 2, 3, 4]
    p_nx::Int = 40
    output_dir::String = joinpath("simulations", "output", "verification")
    summary_csv::String = ""
    summary_tex::String = ""
    overwrite::Bool = false
    progress_every::Int = 0
end

Base.@kwdef struct PHRefinementDemoRow
    sweep::String
    degree::Int
    nx::Int
    dx::Float64
    dofs::Int
    dt::Float64
    tfinal::Float64
    completed_time::Float64
    steps::Int
    area_l1_error::Float64
    area_l2_error::Float64
    area_linf_error::Float64
    area_l2_observed_order::Float64
    area_log10_l2_error::Float64
    area_l2_reduction::Float64
    flow_l1_error::Float64
    flow_l2_error::Float64
    flow_linf_error::Float64
    flow_l2_observed_order::Float64
    flow_log10_l2_error::Float64
    flow_l2_reduction::Float64
    status::String
    error_message::String
end

struct PHRefinementDemoResult
    spec::PHRefinementDemoSpec
    rows::Vector{PHRefinementDemoRow}
    summary_csv::String
    summary_tex::String
end

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
    output_dir::String = joinpath("simulations", "output", "verification")
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

struct RestStateDriftResult{S<:RestStateDriftSpec}
    spec::S
    rows::Vector{RestStateDriftRow}
    summary_csv::String
    summary_tex::String
    profile_csv::String
end

workflow_kind(::ManufacturedVerificationSpec) = "manufactured_verification"
workflow_kind(::PHRefinementDemoSpec) = "p_h_refinement_demo"
workflow_kind(::RestStateDriftSpec) = "rest_state_drift"

function validate(spec::ManufacturedVerificationSpec)
    validate(spec.base_params)
    assert_backend_supported(spec.base_params.space, spec.backend)
    spec.base_params.forcing isa ManufacturedForcing ||
        throw(ArgumentError("manufactured verification requires base_params.forcing=ManufacturedForcing(...)"))
    spec.base_params.initial_condition isa ManufacturedSolutionIC ||
        throw(ArgumentError("manufactured verification requires base_params.initial_condition=ManufacturedSolutionIC()"))
    length(spec.nxs) >= 2 || throw(ArgumentError("manufactured verification requires at least two spatial grids"))
    length(spec.dt_values) >= 2 || throw(ArgumentError("manufactured verification requires at least two timesteps"))
    all(nx -> nx >= 3, spec.nxs) || throw(ArgumentError("all manufactured verification grids must be at least 3"))
    all(dt -> dt > 0.0, spec.dt_values) || throw(ArgumentError("all manufactured verification timesteps must be positive"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    return spec
end

function validate(spec::PHRefinementDemoSpec)
    validate(spec.base_params)
    spec.base_params.forcing isa ManufacturedForcing ||
        throw(ArgumentError("p/h refinement demo requires base_params.forcing=ManufacturedForcing(...)"))
    spec.base_params.initial_condition isa ManufacturedSolutionIC ||
        throw(ArgumentError("p/h refinement demo requires base_params.initial_condition=ManufacturedSolutionIC()"))
    length(spec.h_nxs) >= 2 || throw(ArgumentError("p/h refinement demo requires at least two h-refinement grids"))
    all(nx -> nx >= 3, spec.h_nxs) || throw(ArgumentError("all h-refinement grids must be at least 3"))
    sort(spec.h_nxs) == spec.h_nxs || throw(ArgumentError("h-refinement grids must be sorted ascending"))
    length(unique(spec.h_nxs)) == length(spec.h_nxs) || throw(ArgumentError("h-refinement grids must be unique"))
    spec.p_nx >= 3 || throw(ArgumentError("p-refinement grid must be at least 3"))
    !isempty(spec.degrees) || throw(ArgumentError("p/h refinement demo requires at least one p-refinement degree"))
    sort(spec.degrees) == spec.degrees || throw(ArgumentError("p-refinement degrees must be sorted ascending"))
    length(unique(spec.degrees)) == length(spec.degrees) || throw(ArgumentError("p-refinement degrees must be unique"))
    all(degree -> 0 <= degree <= MAX_DG_DEGREE, spec.degrees) ||
        throw(ArgumentError("p-refinement degrees must be in 0:$MAX_DG_DEGREE"))
    0 <= spec.h_degree <= MAX_DG_DEGREE || throw(ArgumentError("h-refinement degree must be in 0:$MAX_DG_DEGREE"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    return spec
end

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

function manufactured_verification_csv_path(spec::ManufacturedVerificationSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    return joinpath(spec.output_dir, "mms_verification.csv")
end

function manufactured_verification_tex_path(spec::ManufacturedVerificationSpec)
    !isempty(spec.summary_tex) && return spec.summary_tex
    return joinpath(spec.output_dir, "mms_verification.tex")
end

function ph_refinement_demo_csv_path(spec::PHRefinementDemoSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    return joinpath(spec.output_dir, "p_h_refinement_demo.csv")
end

function ph_refinement_demo_tex_path(spec::PHRefinementDemoSpec)
    !isempty(spec.summary_tex) && return spec.summary_tex
    return joinpath(spec.output_dir, "p_h_refinement_demo.tex")
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

default_output_paths(spec::ManufacturedVerificationSpec) = (
    summary_csv=manufactured_verification_csv_path(spec),
    summary_tex=manufactured_verification_tex_path(spec),
)

default_output_paths(spec::PHRefinementDemoSpec) = (
    summary_csv=ph_refinement_demo_csv_path(spec),
    summary_tex=ph_refinement_demo_tex_path(spec),
)

default_output_paths(spec::RestStateDriftSpec) = (
    summary_csv=rest_state_drift_csv_path(spec),
    summary_tex=rest_state_drift_tex_path(spec),
    full_tex=rest_state_drift_full_tex_path(rest_state_drift_tex_path(spec)),
    profile_csv=rest_state_drift_profile_csv_path(spec),
)

function run_manufactured_verification(spec::ManufacturedVerificationSpec = ManufacturedVerificationSpec())
    validate_workflow_spec(spec)
    spatial_rows = manufactured_group_rows(
        "spatial",
        spec,
        [(nx=nx, dt=minimum(spec.dt_values)) for nx in sort(spec.nxs)],
    )
    temporal_rows = manufactured_group_rows(
        "temporal",
        spec,
        [(nx=maximum(spec.nxs), dt=dt) for dt in sort(spec.dt_values; rev=true)],
    )
    rows = vcat(spatial_rows, temporal_rows)
    paths = default_output_paths(spec)
    csv_path = paths.summary_csv
    tex_path = paths.summary_tex
    write_manufactured_verification_csv(csv_path, rows; overwrite=spec.overwrite)
    write_manufactured_verification_tex(tex_path, rows; overwrite=spec.overwrite)
    return ManufacturedVerificationResult(spec, rows, csv_path, tex_path)
end

function run_ph_refinement_demo(spec::PHRefinementDemoSpec = PHRefinementDemoSpec())
    validate_workflow_spec(spec)
    h_rows = [
        ph_refinement_demo_case("h_refinement", spec, nx, spec.h_degree)
        for nx in spec.h_nxs
    ]
    p_rows = [
        ph_refinement_demo_case("p_refinement", spec, spec.p_nx, degree)
        for degree in spec.degrees
    ]
    rows = vcat(assign_ph_h_orders(h_rows), assign_ph_p_reductions(p_rows))
    paths = default_output_paths(spec)
    csv_path = paths.summary_csv
    tex_path = paths.summary_tex
    write_ph_refinement_demo_csv(csv_path, rows; overwrite=spec.overwrite)
    write_ph_refinement_demo_tex(tex_path, rows; overwrite=spec.overwrite)
    return PHRefinementDemoResult(spec, rows, csv_path, tex_path)
end

function ph_refinement_demo_case(sweep::String, spec::PHRefinementDemoSpec, nx::Int, degree::Int)
    params = params_with(spec.base_params; nx=nx, space=DGMethod(degree))
    try
        coefficients = simulate_dg_coefficients(params, DGMethod(degree); progress_every=spec.progress_every)
        metrics = dg_manufactured_error_metrics(coefficients, params, degree)
        return PHRefinementDemoRow(
            sweep=sweep,
            degree=degree,
            nx=nx,
            dx=params.length_cm / nx,
            dofs=degrees_of_freedom(nx, DGMethod(degree)),
            dt=params.dt,
            tfinal=params.tfinal,
            completed_time=coefficients.completed_time,
            steps=coefficients.steps,
            area_l1_error=metrics.area_l1_error,
            area_l2_error=metrics.area_l2_error,
            area_linf_error=metrics.area_linf_error,
            area_l2_observed_order=NaN,
            area_log10_l2_error=safe_log10(metrics.area_l2_error),
            area_l2_reduction=NaN,
            flow_l1_error=metrics.flow_l1_error,
            flow_l2_error=metrics.flow_l2_error,
            flow_linf_error=metrics.flow_linf_error,
            flow_l2_observed_order=NaN,
            flow_log10_l2_error=safe_log10(metrics.flow_l2_error),
            flow_l2_reduction=NaN,
            status="ok",
            error_message="",
        )
    catch err
        return failed_ph_refinement_demo_row(sweep, params, degree, sprint(showerror, err))
    end
end

function failed_ph_refinement_demo_row(sweep::String, params::Params, degree::Int, message::String)
    return PHRefinementDemoRow(
        sweep=sweep,
        degree=degree,
        nx=params.nx,
        dx=params.length_cm / params.nx,
        dofs=degrees_of_freedom(params.nx, DGMethod(degree)),
        dt=params.dt,
        tfinal=params.tfinal,
        completed_time=NaN,
        steps=0,
        area_l1_error=NaN,
        area_l2_error=NaN,
        area_linf_error=NaN,
        area_l2_observed_order=NaN,
        area_log10_l2_error=NaN,
        area_l2_reduction=NaN,
        flow_l1_error=NaN,
        flow_l2_error=NaN,
        flow_linf_error=NaN,
        flow_l2_observed_order=NaN,
        flow_log10_l2_error=NaN,
        flow_l2_reduction=NaN,
        status="error",
        error_message=message,
    )
end

function dg_manufactured_error_metrics(coefficients::DGSimulationCoefficients, params::Params, degree::Int)
    xis, weights = dg_quadrature(MAX_DG_DEGREE)
    area_l1 = 0.0
    area_l2 = 0.0
    area_linf = 0.0
    flow_l1 = 0.0
    flow_l2 = 0.0
    flow_linf = 0.0

    for i in axes(coefficients.area_coefficients, 1)
        for (xi, weight) in zip(xis, weights)
            zq = coefficients.z[i] + 0.5 * coefficients.dx * xi
            physical_weight = 0.5 * coefficients.dx * weight
            area_error = dg_value(coefficients.area_coefficients, i, xi, degree) -
                         manufactured_area(params.forcing, zq, coefficients.completed_time, params)
            flow_error = dg_value(coefficients.flow_coefficients, i, xi, degree) -
                         manufactured_flow(params.forcing, zq, coefficients.completed_time, params)
            area_l1 += abs(area_error) * physical_weight
            area_l2 += area_error^2 * physical_weight
            area_linf = max(area_linf, abs(area_error))
            flow_l1 += abs(flow_error) * physical_weight
            flow_l2 += flow_error^2 * physical_weight
            flow_linf = max(flow_linf, abs(flow_error))
        end
    end

    length_scale = params.length_cm
    return (
        area_l1_error=area_l1 / length_scale,
        area_l2_error=sqrt(area_l2 / length_scale),
        area_linf_error=area_linf,
        flow_l1_error=flow_l1 / length_scale,
        flow_l2_error=sqrt(flow_l2 / length_scale),
        flow_linf_error=flow_linf,
    )
end

function assign_ph_h_orders(rows::Vector{PHRefinementDemoRow})
    output = PHRefinementDemoRow[]
    for i in eachindex(rows)
        current = rows[i]
        next_row = i < lastindex(rows) ? rows[i + 1] : nothing
        ratio = next_row === nothing ? NaN : current.dx / next_row.dx
        area_order = next_row === nothing ? NaN :
                     observed_order_ratio(current.area_l2_error, next_row.area_l2_error, ratio)
        flow_order = next_row === nothing ? NaN :
                     observed_order_ratio(current.flow_l2_error, next_row.flow_l2_error, ratio)
        push!(output, ph_row_with_diagnostics(current, area_order, NaN, flow_order, NaN))
    end
    return output
end

function assign_ph_p_reductions(rows::Vector{PHRefinementDemoRow})
    output = PHRefinementDemoRow[]
    previous = nothing
    for row in rows
        area_reduction = previous === nothing ? NaN : safe_reduction(previous.area_l2_error, row.area_l2_error)
        flow_reduction = previous === nothing ? NaN : safe_reduction(previous.flow_l2_error, row.flow_l2_error)
        push!(output, ph_row_with_diagnostics(row, NaN, area_reduction, NaN, flow_reduction))
        previous = row
    end
    return output
end

function ph_row_with_diagnostics(
    row::PHRefinementDemoRow,
    area_order::Float64,
    area_reduction::Float64,
    flow_order::Float64,
    flow_reduction::Float64,
)
    return PHRefinementDemoRow(
        sweep=row.sweep,
        degree=row.degree,
        nx=row.nx,
        dx=row.dx,
        dofs=row.dofs,
        dt=row.dt,
        tfinal=row.tfinal,
        completed_time=row.completed_time,
        steps=row.steps,
        area_l1_error=row.area_l1_error,
        area_l2_error=row.area_l2_error,
        area_linf_error=row.area_linf_error,
        area_l2_observed_order=area_order,
        area_log10_l2_error=row.area_log10_l2_error,
        area_l2_reduction=area_reduction,
        flow_l1_error=row.flow_l1_error,
        flow_l2_error=row.flow_l2_error,
        flow_linf_error=row.flow_linf_error,
        flow_l2_observed_order=flow_order,
        flow_log10_l2_error=row.flow_log10_l2_error,
        flow_l2_reduction=flow_reduction,
        status=row.status,
        error_message=row.error_message,
    )
end

function safe_log10(value::Float64)
    isfinite(value) && value > 0.0 || return NaN
    return log10(value)
end

function safe_reduction(previous_error::Float64, current_error::Float64)
    isfinite(previous_error) && isfinite(current_error) || return NaN
    previous_error > 0.0 && current_error > 0.0 || return NaN
    return previous_error / current_error
end

function manufactured_group_rows(study_kind::String, spec::ManufacturedVerificationSpec, cases)
    scratch = ManufacturedVerificationRow[]
    for case in cases
        push!(scratch, manufactured_verification_case(study_kind, spec, case.nx, case.dt))
    end
    return assign_manufactured_orders(scratch)
end

function manufactured_verification_case(study_kind::String, spec::ManufacturedVerificationSpec, nx::Int, dt::Float64)
    params = params_with(spec.base_params; nx=nx, dt=dt)
    try
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        exact_A = [manufactured_area(params.forcing, zi, result.completed_time, params) for zi in result.z]
        exact_Q = [manufactured_flow(params.forcing, zi, result.completed_time, params) for zi in result.z]
        forcing_audit = manufactured_forcing_residual_audit(params)
        return ManufacturedVerificationRow(
            study_kind=study_kind,
            nx=nx,
            dx=params.length_cm / nx,
            dt=dt,
            tfinal=params.tfinal,
            area_l1_error=l1_error(result.area, exact_A),
            area_l2_error=l2_error(result.area, exact_A),
            area_linf_error=linf_error(result.area, exact_A),
            area_observed_order=NaN,
            flow_l1_error=l1_error(result.flow, exact_Q),
            flow_l2_error=l2_error(result.flow, exact_Q),
            flow_linf_error=linf_error(result.flow, exact_Q),
            flow_observed_order=NaN,
            accepted_dt_min=result.diagnostics.dt_min,
            accepted_dt_max=result.diagnostics.dt_max,
            realized_cfl_max=result.diagnostics.cfl_max,
            independent_mass_forcing_max_abs_diff=forcing_audit.mass_max_abs_diff,
            independent_momentum_forcing_max_abs_diff=forcing_audit.momentum_max_abs_diff,
            status="ok",
            error_message="",
        )
    catch err
        return ManufacturedVerificationRow(
            study_kind=study_kind,
            nx=nx,
            dx=params.length_cm / nx,
            dt=dt,
            tfinal=params.tfinal,
            area_l1_error=NaN,
            area_l2_error=NaN,
            area_linf_error=NaN,
            area_observed_order=NaN,
            flow_l1_error=NaN,
            flow_l2_error=NaN,
            flow_linf_error=NaN,
            flow_observed_order=NaN,
            accepted_dt_min=NaN,
            accepted_dt_max=NaN,
            realized_cfl_max=NaN,
            independent_mass_forcing_max_abs_diff=NaN,
            independent_momentum_forcing_max_abs_diff=NaN,
            status="error",
            error_message=sprint(showerror, err),
        )
    end
end

function assign_manufactured_orders(rows::Vector{ManufacturedVerificationRow})
    output = ManufacturedVerificationRow[]
    for i in eachindex(rows)
        current = rows[i]
        next_row = i < lastindex(rows) ? rows[i + 1] : nothing
        ratio = if next_row === nothing
            NaN
        elseif current.study_kind == "spatial"
            current.dx / next_row.dx
        else
            current.dt / next_row.dt
        end
        area_order = next_row === nothing ? NaN : observed_order_ratio(current.area_l2_error, next_row.area_l2_error, ratio)
        flow_order = next_row === nothing ? NaN : observed_order_ratio(current.flow_l2_error, next_row.flow_l2_error, ratio)
        if current.study_kind != "spatial"
            area_order = NaN
            flow_order = NaN
        end
        push!(
            output,
            ManufacturedVerificationRow(
                study_kind=current.study_kind,
                nx=current.nx,
                dx=current.dx,
                dt=current.dt,
                tfinal=current.tfinal,
                area_l1_error=current.area_l1_error,
                area_l2_error=current.area_l2_error,
                area_linf_error=current.area_linf_error,
                area_observed_order=area_order,
                flow_l1_error=current.flow_l1_error,
                flow_l2_error=current.flow_l2_error,
                flow_linf_error=current.flow_linf_error,
                flow_observed_order=flow_order,
                accepted_dt_min=current.accepted_dt_min,
                accepted_dt_max=current.accepted_dt_max,
                realized_cfl_max=current.realized_cfl_max,
                independent_mass_forcing_max_abs_diff=current.independent_mass_forcing_max_abs_diff,
                independent_momentum_forcing_max_abs_diff=current.independent_momentum_forcing_max_abs_diff,
                status=current.status,
                error_message=current.error_message,
            ),
        )
    end
    return output
end

function observed_order_ratio(error_coarse::Float64, error_fine::Float64, ratio::Float64)
    isfinite(error_coarse) && isfinite(error_fine) && isfinite(ratio) || return NaN
    error_coarse > 0.0 && error_fine > 0.0 && ratio > 1.0 || return NaN
    return log(error_coarse / error_fine) / log(ratio)
end

function l1_error(values::AbstractVector{Float64}, references::AbstractVector{Float64})
    check_error_vectors(values, references)
    return mean(abs(values[i] - references[i]) for i in eachindex(values))
end

function l2_error(values::AbstractVector{Float64}, references::AbstractVector{Float64})
    check_error_vectors(values, references)
    return sqrt(mean((values[i] - references[i])^2 for i in eachindex(values)))
end

function linf_error(values::AbstractVector{Float64}, references::AbstractVector{Float64})
    check_error_vectors(values, references)
    return maximum(abs(values[i] - references[i]) for i in eachindex(values))
end

function check_error_vectors(values::AbstractVector{Float64}, references::AbstractVector{Float64})
    length(values) == length(references) || throw(DimensionMismatch("error vectors must have matching length"))
    !isempty(values) || throw(ArgumentError("error vectors must be nonempty"))
    return nothing
end

function run_rest_state_drift(spec::RestStateDriftSpec = RestStateDriftSpec())
    validate_workflow_spec(spec)
    rows = RestStateDriftRow[]
    profile_rows = NamedTuple[]
    for severity in spec.severities, nx in sort(spec.nxs), tfinal in sort(spec.elapsed_times)
        row, profiles = rest_state_drift_case(spec, Float64(severity), nx, Float64(tfinal))
        push!(rows, row)
        append!(profile_rows, profiles)
    end
    paths = default_output_paths(spec)
    csv_path = paths.summary_csv
    tex_path = paths.summary_tex
    write_rest_state_drift_csv(csv_path, rows; overwrite=spec.overwrite)
    write_rest_state_drift_tex(tex_path, rows; overwrite=spec.overwrite)
    write_rest_state_drift_full_tex(paths.full_tex, rows; overwrite=spec.overwrite)
    write_rest_state_drift_profile_csv(paths.profile_csv, profile_rows; overwrite=spec.overwrite)
    return RestStateDriftResult(spec, rows, csv_path, tex_path, paths.profile_csv)
end

function rest_state_drift_case(spec::RestStateDriftSpec, severity::Float64, nx::Int, tfinal::Float64)
    params = params_with(spec.base_params; severity=severity, nx=nx, tfinal=tfinal)
    try
        case = simulate_rest_state_drift_case(params, spec.backend; progress_every=spec.progress_every)
        result = case.result
        reference_A = [stenosis(zi, params)[1]^2 for zi in result.z]
        max_abs_q_index = argmax(abs.(result.flow))
        solver_volume_defect = section_mass(result.area, params.length_cm / nx) - section_mass(reference_A, params.length_cm / nx)
        physical_volume_defect = pi * solver_volume_defect
        conservation_residual = solver_volume_defect + case.boundary_flux_integral
        return RestStateDriftRow(
            severity=severity,
            nx=nx,
            dx=params.length_cm / nx,
            elapsed_time_s=result.completed_time,
            requested_time_s=tfinal,
            terminal_time_error_s=terminal_time_error(result.completed_time, tfinal),
            max_abs_q=maximum(abs.(result.flow)),
            max_abs_q_z=result.z[max_abs_q_index],
            max_abs_area_drift=maximum(abs.(result.area .- reference_A)),
            solver_volume_defect=solver_volume_defect,
            physical_volume_defect=physical_volume_defect,
            requested_q_in=case.final_flux.requested_q_in,
            applied_q_in=case.final_flux.applied_q_in,
            inlet_area_flux=case.final_flux.inlet_area_flux,
            outlet_area_flux=case.final_flux.outlet_area_flux,
            boundary_flux_integral=case.boundary_flux_integral,
            conservation_residual=conservation_residual,
            inlet_cell_q=result.flow[begin],
            outlet_cell_q=result.flow[end],
            mean_q=mean(result.flow),
            rms_q=sqrt(mean(abs2, result.flow)),
            lh_area_interior_max_abs=case.initial_lh.area_interior_max_abs,
            lh_area_boundary_max_abs=case.initial_lh.area_boundary_max_abs,
            lh_flow_interior_max_abs=case.initial_lh.flow_interior_max_abs,
            lh_flow_boundary_max_abs=case.initial_lh.flow_boundary_max_abs,
            realized_cfl_max=result.diagnostics.cfl_max,
            lambda_minus_min=result.diagnostics.lambda_minus_min,
            lambda_plus_max=result.diagnostics.lambda_plus_max,
            subcritical_margin_min=result.diagnostics.subcritical_margin_min,
            positivity_projection_count=result.diagnostics.positivity_projection_count,
            positivity_correction_total=result.diagnostics.positivity_correction_total,
            status="ok",
            error_message="",
        ), rest_state_profile_rows(params, result)
    catch err
        return RestStateDriftRow(
            severity=severity,
            nx=nx,
            dx=params.length_cm / nx,
            elapsed_time_s=NaN,
            requested_time_s=tfinal,
            terminal_time_error_s=NaN,
            max_abs_q=NaN,
            max_abs_q_z=NaN,
            max_abs_area_drift=NaN,
            solver_volume_defect=NaN,
            physical_volume_defect=NaN,
            requested_q_in=NaN,
            applied_q_in=NaN,
            inlet_area_flux=NaN,
            outlet_area_flux=NaN,
            boundary_flux_integral=NaN,
            conservation_residual=NaN,
            inlet_cell_q=NaN,
            outlet_cell_q=NaN,
            mean_q=NaN,
            rms_q=NaN,
            lh_area_interior_max_abs=NaN,
            lh_area_boundary_max_abs=NaN,
            lh_flow_interior_max_abs=NaN,
            lh_flow_boundary_max_abs=NaN,
            realized_cfl_max=NaN,
            lambda_minus_min=NaN,
            lambda_plus_max=NaN,
            subcritical_margin_min=NaN,
            positivity_projection_count=0,
            positivity_correction_total=NaN,
            status="error",
            error_message=sprint(showerror, err),
        ), NamedTuple[]
    end
end

function simulate_rest_state_drift_case(params::Params, backend::AbstractTimeBackend; progress_every::Int = 0)
    if backend isa NativeRK3Backend && method_family(params.space) != :discontinuous_galerkin
        return simulate_rest_state_drift_native(params; progress_every=progress_every)
    end

    result = simulate(params, backend; progress_every=progress_every)
    initial = initial_state_result(params)
    return (
        result=result,
        boundary_flux_integral=NaN,
        initial_lh=rest_state_lh_metrics(initial.area, initial.flow, initial.z, initial.dx, params),
        final_flux=rest_state_boundary_flux_metrics(result.area, result.flow, result.z, params.length_cm / params.nx, params, result.completed_time),
    )
end

function simulate_rest_state_drift_native(params::Params; progress_every::Int = 0)
    validate(params)
    initial = initial_state_result(params)
    z = copy(initial.z)
    A = copy(initial.area)
    Q = copy(initial.flow)
    dx = initial.dx
    step_cache = NativeStepCache(length(A))
    flux_cache = RHSCache(length(A))
    diagnostics = DiagnosticsAccumulator(A, dx)
    initial_lh = rest_state_lh_metrics(A, Q, z, dx, params)
    boundary_flux_integral = 0.0
    t = 0.0
    step = 0

    while t < params.tfinal - 1.0e-14
        dt = min(choose_dt(A, Q, z, dx, params), params.tfinal - t)
        start_flux = rest_state_boundary_flux_metrics(A, Q, z, dx, params, t, flux_cache)
        start_flux_difference = start_flux.outlet_area_flux - start_flux.inlet_area_flux
        record_timestep_diagnostics!(diagnostics, A, Q, z, dx, dt, params)
        native_step!(A, Q, z, dx, dt, t, params, step_cache, diagnostics)
        t += dt
        step += 1
        record_mass_diagnostics!(diagnostics, A, dx)
        end_flux = rest_state_boundary_flux_metrics(A, Q, z, dx, params, t, flux_cache)
        end_flux_difference = end_flux.outlet_area_flux - end_flux.inlet_area_flux
        boundary_flux_integral += 0.5 * (start_flux_difference + end_flux_difference) * dt

        if progress_every > 0 && step % progress_every == 0
            @telemetry_info "rest-state progress" event="rest_state_progress" stage="verification" nx=params.nx tfinal=params.tfinal status="running" step t dt
        end

        if !all(isfinite, A) || !all(isfinite, Q)
            error("non-finite solution at t=$(t)")
        end
    end

    result = SimulationResult(z, A, Q, t, step, initial.summary, finalize_diagnostics(diagnostics))
    final_flux = rest_state_boundary_flux_metrics(A, Q, z, dx, params, t, flux_cache)
    return (
        result=result,
        boundary_flux_integral=boundary_flux_integral,
        initial_lh=initial_lh,
        final_flux=final_flux,
    )
end

function rest_state_boundary_flux_metrics(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    params::Params,
    t::Float64,
)
    return rest_state_boundary_flux_metrics(A, Q, z, dx, params, t, RHSCache(length(A)))
end

function rest_state_boundary_flux_metrics(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    params::Params,
    t::Float64,
    cache::RHSCache,
)
    fill_method_fluxes!(cache.area_flux, cache.flow_flux, A, Q, z, dx, 0.0, t, params.space, params, cache)
    _, applied_q_in, _, _ = boundary_states(A, Q, params, t)
    return (
        requested_q_in=inlet_flow(params, t),
        applied_q_in=applied_q_in,
        inlet_area_flux=cache.area_flux[begin],
        outlet_area_flux=cache.area_flux[end],
    )
end

function rest_state_lh_metrics(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    params::Params,
)
    cache = RHSCache(length(A))
    dA = similar(A)
    dQ = similar(Q)
    fill_rhs_dt!(dA, dQ, A, Q, z, dx, 0.0, 0.0, params, cache)
    return (
        area_interior_max_abs=maximum_abs_index_range(dA, 2:(length(dA) - 1)),
        area_boundary_max_abs=max(abs(dA[begin]), abs(dA[end])),
        flow_interior_max_abs=maximum_abs_index_range(dQ, 2:(length(dQ) - 1)),
        flow_boundary_max_abs=max(abs(dQ[begin]), abs(dQ[end])),
    )
end

function maximum_abs_index_range(values::AbstractVector{Float64}, indices)
    max_value = 0.0
    for i in indices
        max_value = max(max_value, abs(values[i]))
    end
    return max_value
end

function rest_state_profile_rows(params::Params, result::SimulationResult)
    return [
        (
            severity=params.severity,
            nx=params.nx,
            requested_time_s=params.tfinal,
            elapsed_time_s=result.completed_time,
            z_cm=result.z[i],
            a_cm2=result.area[i],
            q_cm3_s=result.flow[i],
            u_cm_s=result.flow[i] / result.area[i],
        )
        for i in eachindex(result.z)
    ]
end

function write_manufactured_verification_csv(
    path::String,
    rows::Vector{ManufacturedVerificationRow};
    overwrite::Bool = false,
)
    return write_csv_table(path, manufactured_verification_header(), (manufactured_verification_values(row) for row in rows); overwrite=overwrite)
end

manufactured_verification_header() = [
    "study_kind",
    "nx",
    "dx",
    "dt",
    "tfinal",
    "area_l1_error",
    "area_l2_error",
    "area_linf_error",
    "area_l2_observed_order",
    "flow_l1_error",
    "flow_l2_error",
    "flow_linf_error",
    "flow_l2_observed_order",
    "accepted_dt_min",
    "accepted_dt_max",
    "realized_cfl_max",
    "independent_mass_forcing_max_abs_diff",
    "independent_momentum_forcing_max_abs_diff",
    "status",
    "error_message",
]

function manufactured_verification_values(row::ManufacturedVerificationRow)
    return Any[
        row.study_kind,
        row.nx,
        row.dx,
        row.dt,
        row.tfinal,
        row.area_l1_error,
        row.area_l2_error,
        row.area_linf_error,
        row.area_observed_order,
        row.flow_l1_error,
        row.flow_l2_error,
        row.flow_linf_error,
        row.flow_observed_order,
        row.accepted_dt_min,
        row.accepted_dt_max,
        row.realized_cfl_max,
        row.independent_mass_forcing_max_abs_diff,
        row.independent_momentum_forcing_max_abs_diff,
        row.status,
        row.error_message,
    ]
end

function write_ph_refinement_demo_csv(path::String, rows::Vector{PHRefinementDemoRow}; overwrite::Bool = false)
    return write_csv_table(path, ph_refinement_demo_header(), (ph_refinement_demo_values(row) for row in rows); overwrite=overwrite)
end

ph_refinement_demo_header() = [
    "sweep",
    "degree",
    "nx",
    "dx",
    "dofs",
    "dt",
    "tfinal",
    "completed_time",
    "steps",
    "area_l1_error",
    "area_l2_error",
    "area_linf_error",
    "area_l2_observed_order",
    "area_log10_l2_error",
    "area_l2_reduction",
    "flow_l1_error",
    "flow_l2_error",
    "flow_linf_error",
    "flow_l2_observed_order",
    "flow_log10_l2_error",
    "flow_l2_reduction",
    "status",
    "error_message",
]

function ph_refinement_demo_values(row::PHRefinementDemoRow)
    return Any[
        row.sweep,
        row.degree,
        row.nx,
        row.dx,
        row.dofs,
        row.dt,
        row.tfinal,
        row.completed_time,
        row.steps,
        row.area_l1_error,
        row.area_l2_error,
        row.area_linf_error,
        row.area_l2_observed_order,
        row.area_log10_l2_error,
        row.area_l2_reduction,
        row.flow_l1_error,
        row.flow_l2_error,
        row.flow_linf_error,
        row.flow_l2_observed_order,
        row.flow_log10_l2_error,
        row.flow_l2_reduction,
        row.status,
        row.error_message,
    ]
end

function write_rest_state_drift_csv(path::String, rows::Vector{RestStateDriftRow}; overwrite::Bool = false)
    return write_csv_table(path, rest_state_drift_header(), (rest_state_drift_values(row) for row in rows); overwrite=overwrite)
end

rest_state_drift_header() = [
    "severity",
    "nx",
    "dx",
    "elapsed_time_s",
    "requested_time_s",
    "terminal_time_error_s",
    "max_abs_q",
    "max_abs_q_z",
    "max_abs_area_drift",
    "solver_volume_defect",
    "physical_volume_defect",
    "requested_q_in",
    "applied_q_in",
    "inlet_area_flux",
    "outlet_area_flux",
    "boundary_flux_integral",
    "conservation_residual",
    "inlet_cell_q",
    "outlet_cell_q",
    "mean_q",
    "rms_q",
    "lh_area_interior_max_abs",
    "lh_area_boundary_max_abs",
    "lh_flow_interior_max_abs",
    "lh_flow_boundary_max_abs",
    "realized_cfl_max",
    "lambda_minus_min",
    "lambda_plus_max",
    "subcritical_margin_min",
    "positivity_projection_count",
    "positivity_correction_total",
    "status",
    "error_message",
]

function rest_state_drift_values(row::RestStateDriftRow)
    return Any[
        row.severity,
        row.nx,
        row.dx,
        row.elapsed_time_s,
        row.requested_time_s,
        row.terminal_time_error_s,
        row.max_abs_q,
        row.max_abs_q_z,
        row.max_abs_area_drift,
        row.solver_volume_defect,
        row.physical_volume_defect,
        row.requested_q_in,
        row.applied_q_in,
        row.inlet_area_flux,
        row.outlet_area_flux,
        row.boundary_flux_integral,
        row.conservation_residual,
        row.inlet_cell_q,
        row.outlet_cell_q,
        row.mean_q,
        row.rms_q,
        row.lh_area_interior_max_abs,
        row.lh_area_boundary_max_abs,
        row.lh_flow_interior_max_abs,
        row.lh_flow_boundary_max_abs,
        row.realized_cfl_max,
        row.lambda_minus_min,
        row.lambda_plus_max,
        row.subcritical_margin_min,
        row.positivity_projection_count,
        row.positivity_correction_total,
        row.status,
        row.error_message,
    ]
end

rest_state_profile_header() = [
    "severity",
    "nx",
    "requested_time_s",
    "elapsed_time_s",
    "z_cm",
    "a_cm2",
    "q_cm3_s",
    "u_cm_s",
]

function write_rest_state_drift_profile_csv(path::String, rows; overwrite::Bool = false)
    return write_csv_table(path, rest_state_profile_header(), rows; overwrite=overwrite)
end

function write_manufactured_verification_tex(
    path::String,
    rows::Vector{ManufacturedVerificationRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Manufactured-solution spatial verification errors. The order columns use adjacent-grid \$L^2\$ errors; the final two columns audit the inserted forcing against an independently assembled residual.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        \$N\$ & \$\\Delta t_{\\min}\$ & CFL\$_{\\max}\$ & \$\\|e_a\\|_1\$ & \$\\|e_a\\|_2\$ & \$\\|e_a\\|_\\infty\$ & \$p_a\$ & \$\\|e_q\\|_1\$ & \$\\|e_q\\|_2\$ & \$\\|e_q\\|_\\infty\$ & \$p_q\$ & forcing audit \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" && row.study_kind == "spatial" || continue
            println(io, manufactured_verification_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
        println(io)
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Manufactured-solution timestep-insensitivity rows on the finest MMS grid. These rows report accepted timestep and realized CFL rather than temporal order.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        \$N\$ & requested \$\\Delta t\$ & accepted \$\\Delta t_{\\min}\$ & accepted \$\\Delta t_{\\max}\$ & CFL\$_{\\max}\$ & \$\\|e_a\\|_2\$ & \$\\|e_q\\|_2\$ & forcing audit \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" && row.study_kind == "temporal" || continue
            println(io, manufactured_timestep_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
    end
    return path
end

function manufactured_verification_latex_row(row::ManufacturedVerificationRow)
    return join((
        string(row.nx),
        latex_number(row.accepted_dt_min),
        latex_number(row.realized_cfl_max),
        latex_number(row.area_l1_error),
        latex_number(row.area_l2_error),
        latex_number(row.area_linf_error),
        latex_number(row.area_observed_order),
        latex_number(row.flow_l1_error),
        latex_number(row.flow_l2_error),
        latex_number(row.flow_linf_error),
        latex_number(row.flow_observed_order),
        latex_number(max(row.independent_mass_forcing_max_abs_diff, row.independent_momentum_forcing_max_abs_diff)),
    ), " & ") * " \\\\"
end

function manufactured_timestep_latex_row(row::ManufacturedVerificationRow)
    return join((
        string(row.nx),
        latex_number(row.dt),
        latex_number(row.accepted_dt_min),
        latex_number(row.accepted_dt_max),
        latex_number(row.realized_cfl_max),
        latex_number(row.area_l2_error),
        latex_number(row.flow_l2_error),
        latex_number(max(row.independent_mass_forcing_max_abs_diff, row.independent_momentum_forcing_max_abs_diff)),
    ), " & ") * " \\\\"
end

function write_ph_refinement_demo_tex(path::String, rows::Vector{PHRefinementDemoRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Manufactured-solution p- and h-refinement demonstration. The h-refinement rows report observed order from adjacent grid spacings; the p-refinement rows report the error reduction relative to the previous polynomial degree on the fixed mesh.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}lrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Sweep & \$p\$ & \$N\$ & DOFs & \$\\|e_a\\|_2\$ & h-order & p-reduction & \$\\|e_q\\|_2\$ & h-order & p-reduction \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" || continue
            println(io, ph_refinement_demo_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
    end
    return path
end

function ph_refinement_demo_latex_row(row::PHRefinementDemoRow)
    sweep = row.sweep == "h_refinement" ? "h-refinement" : "p-refinement"
    return join((
        sweep,
        string(row.degree),
        string(row.nx),
        string(row.dofs),
        latex_number(row.area_l2_error),
        latex_number(row.area_l2_observed_order),
        latex_number(row.area_l2_reduction),
        latex_number(row.flow_l2_error),
        latex_number(row.flow_l2_observed_order),
        latex_number(row.flow_l2_reduction),
    ), " & ") * " \\\\"
end

function write_rest_state_drift_tex(path::String, rows::Vector{RestStateDriftRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Zero-forcing, zero-inlet geometry-rest drift summary. The table reports the requested/applied inlet flow, the largest cell flow over positive elapsed times, and the signed finite-volume balance at the final reported time.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Severity & \$N\$ & time of peak \$\\max_i |q_i|\$ & requested \$q_{\\mathrm{in}}\$ & applied \$q_{\\mathrm{in}}\$ & peak \$\\max |q_i|\$ & \$z_{\\max |q|}\$ & final \$\\max |q_i|\$ & final \$\\Delta\\!\\int a\\,dz\$ & final flux integral & final balance residual \\\\")
        println(io, "        \\midrule")
        for row in rest_state_drift_summary_rows(rows)
            println(io, rest_state_drift_summary_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
    end
    return path
end

function write_rest_state_drift_full_tex(path::String, rows::Vector{RestStateDriftRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Full zero-forcing, zero-inlet geometry-rest drift diagnostics. The volume-defect column is the signed solver-coordinate integral \$\\Delta\\!\\int a\\,dz\$; the balance residual is \$\\Delta\\!\\int a\\,dz+\\int(\\widehat F^a_{\\mathrm{out}}-\\widehat F^a_{\\mathrm{in}})\\,dt\$.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Severity & \$N\$ & \$t\$ & requested \$q_{\\mathrm{in}}\$ & applied \$q_{\\mathrm{in}}\$ & \$\\widehat F^a_{\\mathrm{in}}\$ & \$\\widehat F^a_{\\mathrm{out}}\$ & \$\\max |q_i|\$ & \$z_{\\max |q|}\$ & \$\\Delta\\!\\int a\\,dz\$ & balance residual \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" || continue
            println(io, rest_state_drift_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
    end
    return path
end

function rest_state_drift_full_tex_path(path::String)
    return endswith(path, ".tex") ? replace(path, r"\.tex$" => "_full.tex") : path * "_full.tex"
end

function rest_state_drift_summary_rows(rows::Vector{RestStateDriftRow})
    ok_rows = [row for row in rows if row.status == "ok" && row.elapsed_time_s > 0.0]
    nxs = sort(unique(row.nx for row in ok_rows))
    selected_nxs = Set(nxs[max(1, length(nxs) - 1):end])
    output = NamedTuple[]
    for severity in sort(unique(row.severity for row in ok_rows)), nx in sort(collect(selected_nxs))
        group = [row for row in ok_rows if row.severity == severity && row.nx == nx]
        isempty(group) && continue
        max_q_row = group[argmax([row.max_abs_q for row in group])]
        final_row = group[argmax([row.elapsed_time_s for row in group])]
        terminal_errors = [row.terminal_time_error_s for row in group if isfinite(row.terminal_time_error_s)]
        push!(output, (
            severity=severity,
            nx=nx,
            peak_time_s=max_q_row.elapsed_time_s,
            peak_requested_q_in=max_q_row.requested_q_in,
            peak_applied_q_in=max_q_row.applied_q_in,
            peak_max_abs_q=max_q_row.max_abs_q,
            peak_max_abs_q_z=max_q_row.max_abs_q_z,
            final_max_abs_q=final_row.max_abs_q,
            final_solver_volume_defect=final_row.solver_volume_defect,
            final_boundary_flux_integral=final_row.boundary_flux_integral,
            final_conservation_residual=final_row.conservation_residual,
            max_terminal_time_error_s=isempty(terminal_errors) ? NaN : maximum(terminal_errors),
        ))
    end
    return output
end

rest_state_comparison_flow_scale() = 2.288 / pi

function rest_state_drift_summary_latex_row(row)
    return join((
        string(round(Int, row.severity)),
        string(row.nx),
        latex_number(row.peak_time_s),
        latex_number(row.peak_requested_q_in),
        latex_number(row.peak_applied_q_in),
        latex_number(row.peak_max_abs_q),
        latex_number(row.peak_max_abs_q_z),
        latex_number(row.final_max_abs_q),
        latex_number(row.final_solver_volume_defect),
        latex_number(row.final_boundary_flux_integral),
        latex_number(row.final_conservation_residual),
    ), " & ") * " \\\\"
end

function rest_state_drift_latex_row(row::RestStateDriftRow)
    return join((
        string(round(Int, row.severity)),
        string(row.nx),
        latex_number(row.elapsed_time_s),
        latex_number(row.requested_q_in),
        latex_number(row.applied_q_in),
        latex_number(row.inlet_area_flux),
        latex_number(row.outlet_area_flux),
        latex_number(row.max_abs_q),
        latex_number(row.max_abs_q_z),
        latex_number(row.solver_volume_defect),
        latex_number(row.conservation_residual),
    ), " & ") * " \\\\"
end
