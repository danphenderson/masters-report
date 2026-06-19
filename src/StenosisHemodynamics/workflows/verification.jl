using Printf

Base.@kwdef struct ManufacturedVerificationSpec <: AbstractStudySpec
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
    backend::AbstractTimeBackend = NativeRK3Backend()
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
    status::String
    error_message::String
end

struct ManufacturedVerificationResult
    spec::ManufacturedVerificationSpec
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

Base.@kwdef struct RestStateDriftSpec <: AbstractStudySpec
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
    backend::AbstractTimeBackend = NativeRK3Backend()
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
    max_abs_area_drift::Float64
    mass_defect::Float64
    realized_cfl_max::Float64
    lambda_minus_min::Float64
    lambda_plus_max::Float64
    subcritical_margin_min::Float64
    positivity_projection_count::Int
    positivity_correction_total::Float64
    status::String
    error_message::String
end

struct RestStateDriftResult
    spec::RestStateDriftSpec
    rows::Vector{RestStateDriftRow}
    summary_csv::String
    summary_tex::String
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
    for severity in spec.severities, nx in sort(spec.nxs), tfinal in sort(spec.elapsed_times)
        push!(rows, rest_state_drift_case(spec, Float64(severity), nx, Float64(tfinal)))
    end
    paths = default_output_paths(spec)
    csv_path = paths.summary_csv
    tex_path = paths.summary_tex
    write_rest_state_drift_csv(csv_path, rows; overwrite=spec.overwrite)
    write_rest_state_drift_tex(tex_path, rows; overwrite=spec.overwrite)
    write_rest_state_drift_full_tex(paths.full_tex, rows; overwrite=spec.overwrite)
    return RestStateDriftResult(spec, rows, csv_path, tex_path)
end

function rest_state_drift_case(spec::RestStateDriftSpec, severity::Float64, nx::Int, tfinal::Float64)
    params = params_with(spec.base_params; severity=severity, nx=nx, tfinal=tfinal)
    try
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        reference_A = [stenosis(zi, params)[1]^2 for zi in result.z]
        return RestStateDriftRow(
            severity=severity,
            nx=nx,
            dx=params.length_cm / nx,
            elapsed_time_s=result.completed_time,
            requested_time_s=tfinal,
            terminal_time_error_s=terminal_time_error(result.completed_time, tfinal),
            max_abs_q=maximum(abs.(result.flow)),
            max_abs_area_drift=maximum(abs.(result.area .- reference_A)),
            mass_defect=result.diagnostics.mass_defect,
            realized_cfl_max=result.diagnostics.cfl_max,
            lambda_minus_min=result.diagnostics.lambda_minus_min,
            lambda_plus_max=result.diagnostics.lambda_plus_max,
            subcritical_margin_min=result.diagnostics.subcritical_margin_min,
            positivity_projection_count=result.diagnostics.positivity_projection_count,
            positivity_correction_total=result.diagnostics.positivity_correction_total,
            status="ok",
            error_message="",
        )
    catch err
        return RestStateDriftRow(
            severity=severity,
            nx=nx,
            dx=params.length_cm / nx,
            elapsed_time_s=NaN,
            requested_time_s=tfinal,
            terminal_time_error_s=NaN,
            max_abs_q=NaN,
            max_abs_area_drift=NaN,
            mass_defect=NaN,
            realized_cfl_max=NaN,
            lambda_minus_min=NaN,
            lambda_plus_max=NaN,
            subcritical_margin_min=NaN,
            positivity_projection_count=0,
            positivity_correction_total=NaN,
            status="error",
            error_message=sprint(showerror, err),
        )
    end
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
    "max_abs_area_drift",
    "mass_defect",
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
        row.max_abs_area_drift,
        row.mass_defect,
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

function write_manufactured_verification_tex(
    path::String,
    rows::Vector{ManufacturedVerificationRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Manufactured-solution verification errors. The order columns use the \$L^2\$ errors.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}lrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Study & \$N\$ & \$\\Delta t\$ & \$\\|e_a\\|_1\$ & \$\\|e_a\\|_2\$ & \$\\|e_a\\|_\\infty\$ & \$p_a\$ & \$\\|e_q\\|_1\$ & \$\\|e_q\\|_2\$ & \$\\|e_q\\|_\\infty\$ & \$p_q\$ \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" || continue
            println(io, manufactured_verification_latex_row(row))
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
        row.study_kind,
        string(row.nx),
        latex_number(row.dt),
        latex_number(row.area_l1_error),
        latex_number(row.area_l2_error),
        latex_number(row.area_linf_error),
        latex_number(row.area_observed_order),
        latex_number(row.flow_l1_error),
        latex_number(row.flow_l2_error),
        latex_number(row.flow_linf_error),
        latex_number(row.flow_observed_order),
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
        println(io, "    \\caption{Zero-forcing, zero-inlet geometry-rest drift summary. Values are maxima over the reported positive elapsed times for the two finest grids. The normalization uses the comparison-run flow scale \$q_{\\mathrm{comp}}=2.288/\\pi=0.7283\\,\\mathrm{cm^3/s}\$.}")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Severity & \$N\$ & \$t_{\\max q}\$ & \$\\max |q_i|\$ & \$\\max |q_i|/q_{\\mathrm{comp}}\$ & \$\\max |a_i-R_{0,i}^2|\$ & \$\\max |\\Delta M|\$ & Subcrit. min & \$\\max |\\Delta t_{\\mathrm{term}}|\$ \\\\")
        println(io, "        \\midrule")
        for row in rest_state_drift_summary_rows(rows)
            println(io, rest_state_drift_summary_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}")
        println(io, "\\end{table}")
    end
    return path
end

function write_rest_state_drift_full_tex(path::String, rows::Vector{RestStateDriftRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Full zero-forcing, zero-inlet geometry-rest drift diagnostics.}")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Severity & \$N\$ & \$t\$ & \$|\\Delta t_{\\mathrm{term}}|\$ & \$\\max |q_i|\$ & \$\\max |a_i-R_{0,i}^2|\$ & Mass defect & CFL max & Subcrit. margin \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" || continue
            println(io, rest_state_drift_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}")
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
        terminal_errors = [row.terminal_time_error_s for row in group if isfinite(row.terminal_time_error_s)]
        push!(output, (
            severity=severity,
            nx=nx,
            elapsed_time_s=max_q_row.elapsed_time_s,
            max_abs_q=max_q_row.max_abs_q,
            normalized_q=max_q_row.max_abs_q / rest_state_comparison_flow_scale(),
            max_abs_area_drift=maximum(row.max_abs_area_drift for row in group),
            max_abs_mass_defect=maximum(abs(row.mass_defect) for row in group),
            subcritical_margin_min=minimum(row.subcritical_margin_min for row in group if isfinite(row.subcritical_margin_min)),
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
        latex_number(row.elapsed_time_s),
        latex_number(row.max_abs_q),
        latex_number(row.normalized_q),
        latex_number(row.max_abs_area_drift),
        latex_number(row.max_abs_mass_defect),
        latex_number(row.subcritical_margin_min),
        latex_number(row.max_terminal_time_error_s),
    ), " & ") * " \\\\"
end

function rest_state_drift_latex_row(row::RestStateDriftRow)
    return join((
        string(round(Int, row.severity)),
        string(row.nx),
        latex_number(row.elapsed_time_s),
        latex_number(row.terminal_time_error_s),
        latex_number(row.max_abs_q),
        latex_number(row.max_abs_area_drift),
        latex_number(row.mass_defect),
        latex_number(row.realized_cfl_max),
        latex_number(row.subcritical_margin_min),
    ), " & ") * " \\\\"
end
