using Printf

Base.@kwdef struct RefinementStudySpec
    base_params::Params = Params(tfinal=1.0e-4, nx=50, initial_condition=GeometryRestIC())
    nxs::Vector{Int} = [50, 100, 200, 400]
    degrees::Vector{Int} = [0, 1, 2]
    h_methods::Vector{AbstractSpatialMethod} = AbstractSpatialMethod[
        FVMUSCLMethod(),
        FVWENO3Method(),
        FVLaxWendroffMethod(),
    ]
    backend::AbstractTimeBackend = NativeRK3Backend()
    output_dir::String = ""
    overwrite::Bool = false
    progress_every::Int = 0
    parallel_workers::Int = default_case_workers()
end

Base.@kwdef struct RefinementStudyRow
    table_kind::String
    method::String
    degree::Int
    stepper::String
    nx::Int
    dx::Float64
    dofs::Int
    expected_order::Float64
    error_A_l2::Float64
    order_A::Float64
    error_Q_l2::Float64
    order_Q::Float64
    error_u_l2::Float64
    order_u::Float64
    error_pressure_l2::Float64
    order_pressure::Float64
end

struct RefinementStudyResult
    spec::RefinementStudySpec
    h_rows::Vector{RefinementStudyRow}
    p_rows::Vector{RefinementStudyRow}
    csv_paths::Vector{String}
    tex_paths::Vector{String}
end

function validate(spec::RefinementStudySpec)
    validate(spec.base_params)
    length(spec.nxs) >= 2 || throw(ArgumentError("refinement study requires at least two grid sizes"))
    all(nx -> nx >= 3, spec.nxs) || throw(ArgumentError("all refinement grid sizes must be at least 3"))
    sort(spec.nxs) == spec.nxs || throw(ArgumentError("refinement grid sizes must be sorted ascending"))
    length(unique(spec.nxs)) == length(spec.nxs) || throw(ArgumentError("refinement grid sizes must be unique"))
    all(degree -> 0 <= degree <= 2, spec.degrees) || throw(ArgumentError("DG degrees must be in 0:2"))
    !isempty(spec.h_methods) || throw(ArgumentError("h refinement requires at least one spatial method"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    spec.parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    return spec
end

function default_refinement_output_dir(spec::RefinementStudySpec)
    return joinpath(
        "simulations",
        "output",
        "refinement",
        "s$(path_token(spec.base_params.severity))_t$(path_token(spec.base_params.tfinal))",
    )
end

function refinement_output_dir(spec::RefinementStudySpec)
    return isempty(spec.output_dir) ? default_refinement_output_dir(spec) : spec.output_dir
end

function run_refinement_study(spec::RefinementStudySpec = RefinementStudySpec())
    validate(spec)
    h_chunks = parallel_case_map(spec.h_methods; parallel_workers=spec.parallel_workers) do method
        refinement_rows_for_method("h_refinement", spec, method)
    end
    h_rows = reduce(vcat, h_chunks; init=RefinementStudyRow[])

    p_methods = [DGMethod(degree) for degree in spec.degrees]
    p_chunks = parallel_case_map(p_methods; parallel_workers=spec.parallel_workers) do method
        refinement_rows_for_method("p_refinement", spec, method)
    end
    p_rows = reduce(vcat, p_chunks; init=RefinementStudyRow[])

    outdir = refinement_output_dir(spec)
    csv_paths = [
        joinpath(outdir, "h_refinement.csv"),
        joinpath(outdir, "p_refinement.csv"),
    ]
    tex_paths = [
        joinpath(outdir, "h_refinement.tex"),
        joinpath(outdir, "p_refinement.tex"),
    ]
    result = RefinementStudyResult(spec, h_rows, p_rows, csv_paths, tex_paths)
    write_refinement_study_csv(csv_paths[1], h_rows; overwrite=spec.overwrite)
    write_refinement_study_csv(csv_paths[2], p_rows; overwrite=spec.overwrite)
    write_refinement_latex_tables(result; overwrite=spec.overwrite)
    return result
end

function refinement_rows_for_method(table_kind::String, spec::RefinementStudySpec, method::AbstractSpatialMethod)
    reference_nx = 2 * maximum(spec.nxs)
    reference_params = params_with(spec.base_params; nx=reference_nx, space=method)
    reference = simulate(reference_params, spec.backend; progress_every=spec.progress_every)
    reference_pressure = pressure(reference, reference_params)
    reference_u = velocity(reference)

    scratch = NamedTuple[]
    for nx in spec.nxs
        params = params_with(spec.base_params; nx=nx, space=method)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        pressure_values = pressure(result, params)
        u_values = velocity(result)
        degree = method isa DGMethod ? method.degree : -1
        push!(
            scratch,
            (
                table_kind=table_kind,
                method=spatial_method_name(method),
                degree=degree,
                stepper=time_stepper_name(params.time_stepper),
                nx=nx,
                dx=params.length_cm / nx,
                dofs=dg_degrees_of_freedom(nx, method),
                expected_order=expected_refinement_order(method),
                error_A_l2=l2_error_against_reference(result.z, result.area, reference.z, reference.area),
                error_Q_l2=l2_error_against_reference(result.z, result.flow, reference.z, reference.flow),
                error_u_l2=l2_error_against_reference(result.z, u_values, reference.z, reference_u),
                error_pressure_l2=l2_error_against_reference(result.z, pressure_values, reference.z, reference_pressure),
            ),
        )
    end

    by_nx = Dict(row.nx => row for row in scratch)
    rows = RefinementStudyRow[]
    for row in scratch
        next_row = get(by_nx, 2 * row.nx, nothing)
        push!(
            rows,
            RefinementStudyRow(
                table_kind=row.table_kind,
                method=row.method,
                degree=row.degree,
                stepper=row.stepper,
                nx=row.nx,
                dx=row.dx,
                dofs=row.dofs,
                expected_order=row.expected_order,
                error_A_l2=row.error_A_l2,
                order_A=observed_order(row.error_A_l2, next_row === nothing ? NaN : next_row.error_A_l2),
                error_Q_l2=row.error_Q_l2,
                order_Q=observed_order(row.error_Q_l2, next_row === nothing ? NaN : next_row.error_Q_l2),
                error_u_l2=row.error_u_l2,
                order_u=observed_order(row.error_u_l2, next_row === nothing ? NaN : next_row.error_u_l2),
                error_pressure_l2=row.error_pressure_l2,
                order_pressure=observed_order(row.error_pressure_l2, next_row === nothing ? NaN : next_row.error_pressure_l2),
            ),
        )
    end

    return rows
end

function expected_refinement_order(method::AbstractSpatialMethod)
    method isa FVFirstOrderMethod && return 1.0
    method isa FVMUSCLMethod && return 2.0
    method isa FVWENO3Method && return 3.0
    method isa FVLaxWendroffMethod && return 2.0
    method isa DGMethod && return Float64(method.degree + 1)
    return NaN
end

function l2_error_against_reference(z::Vector{Float64}, values::Vector{Float64}, z_ref::Vector{Float64}, values_ref::Vector{Float64})
    length(z) == length(values) || throw(DimensionMismatch("sample coordinates and values must have the same length"))
    accum = 0.0
    for (zi, value) in zip(z, values)
        diff = value - interpolate_linear(z_ref, values_ref, zi)
        accum += diff^2
    end
    return sqrt(accum / length(z))
end

function observed_order(error_coarse::Float64, error_fine::Float64)
    isfinite(error_coarse) && isfinite(error_fine) || return NaN
    error_coarse > 0.0 && error_fine > 0.0 || return NaN
    return log2(error_coarse / error_fine)
end

function write_refinement_study_csv(path::String, rows::Vector{RefinementStudyRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, refinement_csv_header())
        for row in rows
            println(io, refinement_csv_row(row))
        end
    end
    return path
end

function refinement_csv_header()
    return join((
        "table_kind",
        "method",
        "degree",
        "stepper",
        "nx",
        "dx",
        "dofs",
        "expected_order",
        "error_A_l2",
        "order_A",
        "error_Q_l2",
        "order_Q",
        "error_u_l2",
        "order_u",
        "error_pressure_l2",
        "order_pressure",
    ), ",")
end

function refinement_csv_row(row::RefinementStudyRow)
    return join((
        row.table_kind,
        row.method,
        row.degree,
        row.stepper,
        row.nx,
        row.dx,
        row.dofs,
        row.expected_order,
        row.error_A_l2,
        row.order_A,
        row.error_Q_l2,
        row.order_Q,
        row.error_u_l2,
        row.order_u,
        row.error_pressure_l2,
        row.order_pressure,
    ), ",")
end

function write_refinement_latex_tables(result::RefinementStudyResult; overwrite::Bool = false)
    write_refinement_latex_table(result.tex_paths[1], result.h_rows, "Self-convergence h-refinement summary"; overwrite=overwrite)
    write_refinement_latex_table(result.tex_paths[2], result.p_rows, "Self-convergence p-refinement summary"; overwrite=overwrite)
    return result.tex_paths
end

function write_refinement_latex_table(path::String, rows::Vector{RefinementStudyRow}, caption::String; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{$caption}")
        println(io, "    \\begin{tabular}{@{}llrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Method & Stepper & \$p\$ & \$N\$ & Expected & \$\\|e_A\\|_2\$ & Order & \$\\|e_Q\\|_2\$ & Order \\\\")
        println(io, "        \\midrule")
        for row in rows
            println(io, refinement_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}")
        println(io, "\\end{table}")
    end
    return path
end

function refinement_latex_row(row::RefinementStudyRow)
    degree = row.degree < 0 ? "--" : string(row.degree)
    return join((
        row.method,
        row.stepper,
        degree,
        string(row.nx),
        latex_number(row.expected_order),
        latex_number(row.error_A_l2),
        latex_number(row.order_A),
        latex_number(row.error_Q_l2),
        latex_number(row.order_Q),
    ), " & ") * " \\\\"
end

function latex_number(value::Float64)
    isfinite(value) || return "--"
    abs(value) >= 1.0e-3 && abs(value) < 1.0e4 && return string(round(value, sigdigits=4))
    return @sprintf("%.3e", value)
end
