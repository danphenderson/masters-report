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
    output_dir::String = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification")
    summary_csv::String = ""
    summary_tex::String = ""
    overwrite::Bool = false
    progress_every::Int = 0
    apply_limiter::Bool = true
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
    area_p_sweep_status::String = "not_evaluated"
    flow_l1_error::Float64
    flow_l2_error::Float64
    flow_linf_error::Float64
    flow_l2_observed_order::Float64
    flow_log10_l2_error::Float64
    flow_l2_reduction::Float64
    flow_p_sweep_status::String = "not_evaluated"
    p_sweep_status::String = "not_evaluated"
    dg_limiter_policy::String = "modal_limiter"
    status::String
    error_message::String
end

struct PHRefinementDemoResult
    spec::PHRefinementDemoSpec
    rows::Vector{PHRefinementDemoRow}
    summary_csv::String
    summary_tex::String
end

workflow_kind(::PHRefinementDemoSpec) = "p_h_refinement_demo"

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

function ph_refinement_demo_csv_path(spec::PHRefinementDemoSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    return joinpath(spec.output_dir, "p_h_refinement_demo.csv")
end

function ph_refinement_demo_tex_path(spec::PHRefinementDemoSpec)
    !isempty(spec.summary_tex) && return spec.summary_tex
    return joinpath(spec.output_dir, "p_h_refinement_demo.tex")
end

function ph_refinement_demo_spec_from_values(
    values::Dict{String,String},
    flags::Set{String};
    output_dir::String = get(values, "output-dir", joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification")),
    overwrite::Bool = "overwrite" in flags,
    progress_every::Int = parse(Int, get(values, "progress-every", "0")),
)
    h_degree = parse(Int, get(values, "h-degree", "2"))
    base_params = Params(;
        nx=parse(Int, get(values, "p-nx", "40")),
        tfinal=parse(Float64, get(values, "tfinal", "2e-4")),
        dt=parse(Float64, get(values, "dt", "5e-7")),
        severity=parse(Float64, get(values, "severity", "0")),
        initial_condition=ManufacturedSolutionIC(),
        forcing=ManufacturedForcing(),
        space=DGMethod(h_degree),
        time_stepper=time_stepper_from_cli(values),
        velocity_profile=velocity_profile_from_cli(values),
        rheology=rheology_from_cli(values),
        model=model_from_cli(values),
    )
    return PHRefinementDemoSpec(;
        base_params=base_params,
        h_nxs=parse_int_list(get(values, "h-nxs", get(values, "nxs", "20,40,80,160"))),
        h_degree=h_degree,
        degrees=parse_int_list(get(values, "degrees", "0,1,2,3,4")),
        p_nx=parse(Int, get(values, "p-nx", "40")),
        output_dir=output_dir,
        summary_csv=get(values, "summary-csv", ""),
        summary_tex=get(values, "summary-tex", ""),
        overwrite=overwrite,
        progress_every=progress_every,
    )
end

default_output_paths(spec::PHRefinementDemoSpec) = (
    summary_csv=ph_refinement_demo_csv_path(spec),
    summary_tex=ph_refinement_demo_tex_path(spec),
)

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
    limiter_policy = dg_limiter_policy_label(spec.apply_limiter)
    try
        coefficients = simulate_dg_coefficients(
            params,
            DGMethod(degree);
            progress_every=spec.progress_every,
            apply_limiter=spec.apply_limiter,
        )
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
            area_p_sweep_status="not_evaluated",
            flow_l1_error=metrics.flow_l1_error,
            flow_l2_error=metrics.flow_l2_error,
            flow_linf_error=metrics.flow_linf_error,
            flow_l2_observed_order=NaN,
            flow_log10_l2_error=safe_log10(metrics.flow_l2_error),
            flow_l2_reduction=NaN,
            flow_p_sweep_status="not_evaluated",
            p_sweep_status="not_evaluated",
            dg_limiter_policy=limiter_policy,
            status="ok",
            error_message="",
        )
    catch err
        return failed_ph_refinement_demo_row(sweep, params, degree, limiter_policy, sprint(showerror, err))
    end
end

function failed_ph_refinement_demo_row(
    sweep::String,
    params::Params,
    degree::Int,
    dg_limiter_policy::String,
    message::String,
)
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
        area_p_sweep_status="not_evaluated",
        flow_l1_error=NaN,
        flow_l2_error=NaN,
        flow_linf_error=NaN,
        flow_l2_observed_order=NaN,
        flow_log10_l2_error=NaN,
        flow_l2_reduction=NaN,
        flow_p_sweep_status="not_evaluated",
        p_sweep_status="not_evaluated",
        dg_limiter_policy=dg_limiter_policy,
        status="error",
        error_message=message,
    )
end

dg_limiter_policy_label(apply_limiter::Bool) = apply_limiter ? "modal_limiter" : "disabled"

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
        push!(
            output,
            ph_row_with_diagnostics(
                current,
                area_order,
                NaN,
                "not_applicable",
                flow_order,
                NaN,
                "not_applicable",
                "not_applicable",
            ),
        )
    end
    return output
end

function assign_ph_p_reductions(rows::Vector{PHRefinementDemoRow})
    output = PHRefinementDemoRow[]
    previous = nothing
    for row in rows
        area_reduction = previous === nothing ? NaN : safe_reduction(previous.area_l2_error, row.area_l2_error)
        flow_reduction = previous === nothing ? NaN : safe_reduction(previous.flow_l2_error, row.flow_l2_error)
        area_status = previous === nothing ? "baseline" : p_sweep_reduction_status(area_reduction)
        flow_status = previous === nothing ? "baseline" : p_sweep_reduction_status(flow_reduction)
        combined_status = combine_p_sweep_status(area_status, flow_status)
        push!(
            output,
            ph_row_with_diagnostics(
                row,
                NaN,
                area_reduction,
                area_status,
                NaN,
                flow_reduction,
                flow_status,
                combined_status,
            ),
        )
        previous = row
    end
    return output
end

function ph_row_with_diagnostics(
    row::PHRefinementDemoRow,
    area_order::Float64,
    area_reduction::Float64,
    area_p_sweep_status::String,
    flow_order::Float64,
    flow_reduction::Float64,
    flow_p_sweep_status::String,
    p_sweep_status::String,
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
        area_p_sweep_status=area_p_sweep_status,
        flow_l1_error=row.flow_l1_error,
        flow_l2_error=row.flow_l2_error,
        flow_linf_error=row.flow_linf_error,
        flow_l2_observed_order=flow_order,
        flow_log10_l2_error=row.flow_log10_l2_error,
        flow_l2_reduction=flow_reduction,
        flow_p_sweep_status=flow_p_sweep_status,
        p_sweep_status=p_sweep_status,
        dg_limiter_policy=row.dg_limiter_policy,
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

function p_sweep_reduction_status(reduction::Float64; tolerance::Float64 = 0.05)
    isfinite(reduction) || return "not_evaluated"
    reduction > 1.0 + tolerance && return "improved"
    reduction < 1.0 - tolerance && return "regressed"
    return "plateau"
end

function combine_p_sweep_status(area_status::String, flow_status::String)
    statuses = (area_status, flow_status)
    all(status -> status == "not_applicable", statuses) && return "not_applicable"
    all(status -> status == "baseline", statuses) && return "baseline"
    any(status -> status == "regressed", statuses) && return "regressed"
    any(status -> status == "not_evaluated", statuses) && return "not_evaluated"
    any(status -> status == "plateau", statuses) && return "plateau"
    all(status -> status == "improved", statuses) && return "improved"
    return "not_evaluated"
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
    "area_p_sweep_status",
    "flow_l1_error",
    "flow_l2_error",
    "flow_linf_error",
    "flow_l2_observed_order",
    "flow_log10_l2_error",
    "flow_l2_reduction",
    "flow_p_sweep_status",
    "p_sweep_status",
    "dg_limiter_policy",
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
        row.area_p_sweep_status,
        row.flow_l1_error,
        row.flow_l2_error,
        row.flow_linf_error,
        row.flow_l2_observed_order,
        row.flow_log10_l2_error,
        row.flow_l2_reduction,
        row.flow_p_sweep_status,
        row.p_sweep_status,
        row.dg_limiter_policy,
        row.status,
        row.error_message,
    ]
end

function write_ph_refinement_demo_tex(path::String, rows::Vector{PHRefinementDemoRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Manufactured-solution p- and h-refinement diagnostic. The h-refinement rows report \$L_2\$ observed order from adjacent grid spacings; the p-refinement rows report fixed-mesh \$L_2\$ error reduction and conservative diagnostic status, not accepted p-convergence evidence.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}lrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Sweep & \$p\$ & \$N\$ & DOFs & \$\\|e_a\\|_2\$ & h-order & p-reduction & \$\\|e_q\\|_2\$ & h-order & p-reduction & p-status \\\\")
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
        latex_status(row.p_sweep_status),
    ), " & ") * " \\\\"
end

latex_status(value::String) = replace(value, "_" => "\\_")
