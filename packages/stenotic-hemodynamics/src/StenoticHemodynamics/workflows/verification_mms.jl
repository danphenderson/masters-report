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
    output_dir::String = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification")
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

workflow_kind(::ManufacturedVerificationSpec) = "manufactured_verification"

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

function manufactured_verification_csv_path(spec::ManufacturedVerificationSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    return joinpath(spec.output_dir, "mms_verification.csv")
end

function manufactured_verification_tex_path(spec::ManufacturedVerificationSpec)
    !isempty(spec.summary_tex) && return spec.summary_tex
    return joinpath(spec.output_dir, "mms_verification.tex")
end

function manufactured_verification_spec_from_values(
    values::Dict{String,String},
    flags::Set{String};
    output_dir::String = get(values, "output-dir", joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification")),
    overwrite::Bool = "overwrite" in flags,
    progress_every::Int = parse(Int, get(values, "progress-every", "0")),
)
    base_params = Params(;
        nx=parse(Int, get(values, "nx", "40")),
        tfinal=parse(Float64, get(values, "tfinal", "2e-3")),
        dt=parse(Float64, get(values, "dt", "5e-6")),
        severity=parse(Float64, get(values, "severity", "0")),
        initial_condition=ManufacturedSolutionIC(),
        forcing=ManufacturedForcing(),
        space=spatial_method_from_cli(values),
        time_stepper=time_stepper_from_cli(values),
        velocity_profile=velocity_profile_from_cli(values),
        rheology=rheology_from_cli(values),
        model=model_from_cli(values),
    )
    return ManufacturedVerificationSpec(;
        base_params=base_params,
        nxs=parse_int_list(get(values, "nxs", "20,40,80")),
        dt_values=parse_float_list(get(values, "dt-values", "2e-5,1e-5,5e-6")),
        output_dir=output_dir,
        summary_csv=get(values, "summary-csv", ""),
        summary_tex=get(values, "summary-tex", ""),
        overwrite=overwrite,
        progress_every=progress_every,
    )
end

default_output_paths(spec::ManufacturedVerificationSpec) = (
    summary_csv=manufactured_verification_csv_path(spec),
    summary_tex=manufactured_verification_tex_path(spec),
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

function write_manufactured_verification_csv(
    path::String,
    rows::Vector{ManufacturedVerificationRow};
    overwrite::Bool = false,
)
    return write_csv_table(
        path,
        manufactured_verification_header(),
        (manufactured_verification_values(row) for row in rows);
        overwrite=overwrite,
    )
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

function write_manufactured_verification_tex(
    path::String,
    rows::Vector{ManufacturedVerificationRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Manufactured-solution spatial verification errors. The order columns use adjacent-grid \$L_2\$ errors; the final column checks the inserted forcing against an independently assembled residual.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        \$N\$ & \$\\Delta t_{\\min}\$ & CFL\$_{\\max}\$ & \$\\|e_a\\|_1\$ & \$\\|e_a\\|_2\$ & \$\\|e_a\\|_\\infty\$ & \$p_a\$ & \$\\|e_q\\|_1\$ & \$\\|e_q\\|_2\$ & \$\\|e_q\\|_\\infty\$ & \$p_q\$ & forcing check \\\\")
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
        println(io, "        \$N\$ & requested \$\\Delta t\$ & accepted \$\\Delta t_{\\min}\$ & accepted \$\\Delta t_{\\max}\$ & CFL\$_{\\max}\$ & \$\\|e_a\\|_2\$ & \$\\|e_q\\|_2\$ & forcing check \\\\")
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
