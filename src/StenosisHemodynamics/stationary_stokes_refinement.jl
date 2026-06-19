struct StationaryStokesRefinementSpec <: AbstractStudySpec
    base_params::Params
    severities::Vector{Float64}
    pressure_drop_pa::Float64
    meshes::Vector{NTuple{3,Int}}
    output_dir::String
    summary_csv::String
    overwrite::Bool
    parallel_workers::Int
end

function StationaryStokesRefinementSpec(;
    base_params::Params = Params(nx=80, tfinal=0.0, initial_condition=GeometryRestIC()),
    severities = [0.0, 23.0, 40.0, 50.0],
    pressure_drop_pa::Real = 40.0,
    meshes = [(8, 2, 8), (16, 4, 16), (32, 6, 32), (64, 6, 32)],
    output_dir::AbstractString = "",
    summary_csv::AbstractString = "",
    overwrite::Bool = false,
    parallel_workers::Int = default_case_workers(),
)
    severity_values = [Float64(severity) for severity in severities]
    mesh_values = [(Int(mesh[1]), Int(mesh[2]), Int(mesh[3])) for mesh in meshes]
    return StationaryStokesRefinementSpec(
        base_params,
        severity_values,
        Float64(pressure_drop_pa),
        mesh_values,
        String(output_dir),
        String(summary_csv),
        overwrite,
        parallel_workers,
    )
end

Base.@kwdef struct StationaryStokesRefinementRow
    case_id::String
    severity::Float64
    pressure_drop_pa::Float64
    mesh_nz::Int
    mesh_nr::Int
    mesh_ntheta::Int
    projection_nr::Int
    projection_ntheta::Int
    mesh_nodes::Int
    mesh_cells::Int
    velocity_dofs::Int
    pressure_dofs::Int
    elapsed_s::Float64
    mean_flow::Float64
    fe_uavg_min::Float64
    fe_uavg_max::Float64
    projection_uavg_min::Float64
    projection_uavg_max::Float64
    fe_pressure_min::Float64
    fe_pressure_max::Float64
    projection_pressure_min::Float64
    projection_pressure_max::Float64
    fe_projection_u_l2_relative_error::Float64
    fe_projection_pressure_l2_relative_error::Float64
    finest_u_l2_relative_error::Float64
    finest_pressure_l2_relative_error::Float64
    traction_samples::Int
    wall_traction_mean::Float64
    wall_traction_max::Float64
    wss_mean::Float64
    wss_max::Float64
    status::String
    error_message::String
end

struct StationaryStokesRefinementResult
    spec::StationaryStokesRefinementSpec
    rows::Vector{StationaryStokesRefinementRow}
    summary_csv::String
end

function validate(spec::StationaryStokesRefinementSpec)
    !isempty(spec.severities) || throw(ArgumentError("stationary Stokes refinement requires at least one severity"))
    !isempty(spec.meshes) || throw(ArgumentError("stationary Stokes refinement requires at least one mesh"))
    isfinite(spec.pressure_drop_pa) || throw(ArgumentError("stationary Stokes pressure drop must be finite"))
    spec.pressure_drop_pa > 0.0 || throw(ArgumentError("stationary Stokes pressure drop must be positive"))
    spec.base_params.nx >= 3 || throw(ArgumentError("base_params.nx must be at least 3 for section sampling"))
    spec.base_params.length_cm > 0.0 || throw(ArgumentError("base_params.length_cm must be positive"))
    spec.base_params.rmax > 0.0 || throw(ArgumentError("base_params.rmax must be positive"))
    spec.base_params.rho > 0.0 || throw(ArgumentError("base_params.rho must be positive"))
    spec.base_params.nu > 0.0 || throw(ArgumentError("base_params.nu must be positive for stationary Stokes"))
    spec.parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    return spec
end

function run_stationary_stokes_refinement(
    spec::StationaryStokesRefinementSpec = StationaryStokesRefinementSpec(),
)
    validate(spec)
    chunks = parallel_case_map(spec.severities; parallel_workers=spec.parallel_workers) do severity
        stationary_stokes_rows_for_severity(spec, severity)
    end
    rows = reduce(vcat, chunks; init=StationaryStokesRefinementRow[])
    path = stationary_stokes_refinement_summary_path(spec)
    result = StationaryStokesRefinementResult(spec, rows, path)
    write_stationary_stokes_refinement_csv(path, rows; overwrite=spec.overwrite)
    write_stationary_stokes_refinement_tex(stationary_stokes_refinement_tex_path(path), rows; overwrite=spec.overwrite)
    return result
end

function stationary_stokes_refinement_summary_path(spec::StationaryStokesRefinementSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    outdir = isempty(spec.output_dir) ? default_stationary_stokes_refinement_output_dir() : spec.output_dir
    return joinpath(outdir, "summary.csv")
end

default_stationary_stokes_refinement_output_dir() =
    joinpath("simulations", "output", "stationary_stokes_refinement")

function stationary_stokes_refinement_tex_path(summary_csv::String)
    endswith(summary_csv, ".csv") && return summary_csv[begin:end-4] * ".tex"
    return summary_csv * ".tex"
end

function stationary_stokes_rows_for_severity(spec::StationaryStokesRefinementSpec, severity::Float64)
    scratch = [stationary_stokes_case_scratch(spec, severity, mesh) for mesh in spec.meshes]
    successful = [item for item in scratch if item.status == "ok"]
    reference = isempty(successful) ? nothing : largest_stationary_stokes_mesh(successful)
    return [stationary_stokes_row_from_scratch(item, reference) for item in scratch]
end

function largest_stationary_stokes_mesh(items)
    return reduce((left, right) -> left.mesh_nodes >= right.mesh_nodes ? left : right, items)
end

function stationary_stokes_case_scratch(
    spec::StationaryStokesRefinementSpec,
    severity::Float64,
    mesh::NTuple{3,Int},
)
    nz, nr, ntheta = mesh
    case_id = stationary_stokes_case_id(severity, mesh)
    projection_nr = nr
    projection_ntheta = ntheta
    try
        ic = StationaryStokesIC(
            pressure_drop_pa=spec.pressure_drop_pa,
            mesh_nz=nz,
            mesh_nr=nr,
            mesh_ntheta=ntheta,
            projection_nr=projection_nr,
            projection_ntheta=projection_ntheta,
        )
        params = params_with(spec.base_params; severity=severity, tfinal=0.0, initial_condition=ic)
        validate(params)
        solution = nothing
        z = Float64[]
        projected_A = Float64[]
        projected_Q = Float64[]
        projected_u = Float64[]
        projected_pressure = Float64[]
        fe_u = Float64[]
        fe_pressure = Float64[]
        traction = nothing
        elapsed = @elapsed begin
            solution = solve_stationary_stokes(params, ic)
            dx = params.length_cm / params.nx
            z = [(i - 0.5) * dx for i in 1:params.nx]
            projected_A, projected_Q, projected_u, projected_pressure =
                project_stationary_stokes(solution, params, ic, z)
            fe_u = [safe_section_average_velocity(solution.velocity, zi, params, ic) for zi in z]
            fe_pressure = [safe_section_average_pressure(solution.pressure, zi, params, ic) for zi in z]
            traction = stationary_stokes_wall_traction_summary(solution, params)
        end
        return (
            status="ok",
            error_message="",
            case_id=case_id,
            severity=severity,
            pressure_drop_pa=spec.pressure_drop_pa,
            mesh_nz=nz,
            mesh_nr=nr,
            mesh_ntheta=ntheta,
            projection_nr=projection_nr,
            projection_ntheta=projection_ntheta,
            mesh_nodes=length(solution.mesh.coordinates),
            mesh_cells=length(solution.mesh.cells),
            velocity_dofs=solution.velocity_dofs,
            pressure_dofs=solution.pressure_dofs,
            elapsed_s=elapsed,
            mean_flow=finite_mean(projected_Q),
            fe_u=fe_u,
            fe_pressure=fe_pressure,
            projected_u=projected_u,
            projected_pressure=projected_pressure,
            fe_projection_u_l2_relative_error=relative_l2_error(fe_u, projected_u),
            fe_projection_pressure_l2_relative_error=relative_l2_error(fe_pressure, projected_pressure),
            traction=traction,
        )
    catch err
        return stationary_stokes_error_scratch(spec, severity, mesh, projection_nr, projection_ntheta, sprint(showerror, err))
    end
end

function stationary_stokes_error_scratch(
    spec::StationaryStokesRefinementSpec,
    severity::Float64,
    mesh::NTuple{3,Int},
    projection_nr::Int,
    projection_ntheta::Int,
    message::String,
)
    nz, nr, ntheta = mesh
    return (
        status="error",
        error_message=message,
        case_id=stationary_stokes_case_id(severity, mesh),
        severity=severity,
        pressure_drop_pa=spec.pressure_drop_pa,
        mesh_nz=nz,
        mesh_nr=nr,
        mesh_ntheta=ntheta,
        projection_nr=projection_nr,
        projection_ntheta=projection_ntheta,
        mesh_nodes=0,
        mesh_cells=0,
        velocity_dofs=0,
        pressure_dofs=0,
        elapsed_s=NaN,
        mean_flow=NaN,
        fe_u=Float64[],
        fe_pressure=Float64[],
        projected_u=Float64[],
        projected_pressure=Float64[],
        fe_projection_u_l2_relative_error=NaN,
        fe_projection_pressure_l2_relative_error=NaN,
        traction=(samples=0, traction_mean=NaN, traction_max=NaN, wss_mean=NaN, wss_max=NaN),
    )
end

function stationary_stokes_row_from_scratch(item, reference)
    finest_u_error = item.status == "ok" && reference !== nothing ? relative_l2_error(item.fe_u, reference.fe_u) : NaN
    finest_pressure_error =
        item.status == "ok" && reference !== nothing ? relative_l2_error(item.fe_pressure, reference.fe_pressure) : NaN
    return StationaryStokesRefinementRow(
        case_id=item.case_id,
        severity=item.severity,
        pressure_drop_pa=item.pressure_drop_pa,
        mesh_nz=item.mesh_nz,
        mesh_nr=item.mesh_nr,
        mesh_ntheta=item.mesh_ntheta,
        projection_nr=item.projection_nr,
        projection_ntheta=item.projection_ntheta,
        mesh_nodes=item.mesh_nodes,
        mesh_cells=item.mesh_cells,
        velocity_dofs=item.velocity_dofs,
        pressure_dofs=item.pressure_dofs,
        elapsed_s=item.elapsed_s,
        mean_flow=item.mean_flow,
        fe_uavg_min=finite_min(item.fe_u),
        fe_uavg_max=finite_max(item.fe_u),
        projection_uavg_min=finite_min(item.projected_u),
        projection_uavg_max=finite_max(item.projected_u),
        fe_pressure_min=finite_min(item.fe_pressure),
        fe_pressure_max=finite_max(item.fe_pressure),
        projection_pressure_min=finite_min(item.projected_pressure),
        projection_pressure_max=finite_max(item.projected_pressure),
        fe_projection_u_l2_relative_error=item.fe_projection_u_l2_relative_error,
        fe_projection_pressure_l2_relative_error=item.fe_projection_pressure_l2_relative_error,
        finest_u_l2_relative_error=finest_u_error,
        finest_pressure_l2_relative_error=finest_pressure_error,
        traction_samples=item.traction.samples,
        wall_traction_mean=item.traction.traction_mean,
        wall_traction_max=item.traction.traction_max,
        wss_mean=item.traction.wss_mean,
        wss_max=item.traction.wss_max,
        status=item.status,
        error_message=item.error_message,
    )
end

function stationary_stokes_case_id(severity::Float64, mesh::NTuple{3,Int})
    nz, nr, ntheta = mesh
    return "stokes-s$(path_token(severity))-$(nz)x$(nr)x$(ntheta)"
end

function stationary_stokes_wall_traction_summary(solution::StationaryStokesSolution, params::Params)
    traction_values = Float64[]
    wss_values = Float64[]
    for j in 0:solution.mesh.nz
        z = params.length_cm * j / solution.mesh.nz
        for a in 1:solution.mesh.ntheta
            theta = 2.0 * pi * (a - 1) / solution.mesh.ntheta
            traction_magnitude, wss_magnitude = try
                stationary_stokes_wall_traction_sample(solution, params, z, theta)
            catch
                continue
            end
            push!(traction_values, traction_magnitude)
            push!(wss_values, wss_magnitude)
        end
    end
    isempty(traction_values) && throw(ArgumentError("could not evaluate any stationary Stokes wall-traction samples"))
    return (
        samples=length(traction_values),
        traction_mean=finite_mean(traction_values),
        traction_max=finite_max(traction_values),
        wss_mean=finite_mean(wss_values),
        wss_max=finite_max(wss_values),
    )
end

function stationary_stokes_wall_traction_sample(
    solution::StationaryStokesSolution,
    params::Params,
    z::Float64,
    theta::Float64,
)
    r0, r0z, _ = stenosis(z, params)
    sample_radius = r0 * (1.0 - 1.0e-8)
    x = sample_radius * cos(theta)
    y = sample_radius * sin(theta)
    point = Point(x, y, z)
    grad_u = (∇(solution.velocity))(point)
    pressure_value = Float64(solution.pressure(point))
    nx, ny, nz = stationary_stokes_wall_normal(theta, r0z)
    sx, sy, sz = symmetric_gradient_times_normal(grad_u, nx, ny, nz)
    mu = params.rho * params.nu
    tx = -pressure_value * nx + mu * sx
    ty = -pressure_value * ny + mu * sy
    tz = -pressure_value * nz + mu * sz
    normal_component = tx * nx + ty * ny + tz * nz
    taux = tx - normal_component * nx
    tauy = ty - normal_component * ny
    tauz = tz - normal_component * nz
    return vector_norm3(tx, ty, tz), vector_norm3(taux, tauy, tauz)
end

function stationary_stokes_wall_normal(theta::Float64, r0z::Float64)
    scale = inv(sqrt(1.0 + r0z^2))
    return cos(theta) * scale, sin(theta) * scale, -r0z * scale
end

function symmetric_gradient_times_normal(grad_u, nx::Float64, ny::Float64, nz::Float64)
    sx = 2.0 * grad_u[1, 1] * nx + (grad_u[1, 2] + grad_u[2, 1]) * ny + (grad_u[1, 3] + grad_u[3, 1]) * nz
    sy = (grad_u[2, 1] + grad_u[1, 2]) * nx + 2.0 * grad_u[2, 2] * ny + (grad_u[2, 3] + grad_u[3, 2]) * nz
    sz = (grad_u[3, 1] + grad_u[1, 3]) * nx + (grad_u[3, 2] + grad_u[2, 3]) * ny + 2.0 * grad_u[3, 3] * nz
    return sx, sy, sz
end

vector_norm3(x::Real, y::Real, z::Real) = sqrt(Float64(x)^2 + Float64(y)^2 + Float64(z)^2)

function safe_section_average_velocity(velocity_h, z::Float64, p::Params, ic::StationaryStokesIC)
    r0, _, _ = stenosis(clamp(z, 0.0, p.length_cm), p)
    acc = 0.0
    count = 0
    polygon_scale = cos(pi / ic.mesh_ntheta) * (1.0 - 1.0e-8)
    for ir in 1:ic.projection_nr
        radius = r0 * polygon_scale * sqrt((ir - 0.5) / ic.projection_nr)
        for itheta in 1:ic.projection_ntheta
            theta = 2.0 * pi * (itheta - 0.5) / ic.projection_ntheta
            value = try
                velocity_h(Point(radius * cos(theta), radius * sin(theta), z))[3]
            catch
                continue
            end
            acc += value
            count += 1
        end
    end
    count > 0 || throw(ArgumentError("could not evaluate any FE velocity section samples at z=$z"))
    return acc / count
end

function safe_section_average_pressure(pressure_h, z::Float64, p::Params, ic::StationaryStokesIC)
    r0, _, _ = stenosis(clamp(z, 0.0, p.length_cm), p)
    acc = 0.0
    count = 0
    polygon_scale = cos(pi / ic.mesh_ntheta) * (1.0 - 1.0e-8)
    for ir in 1:ic.projection_nr
        radius = r0 * polygon_scale * sqrt((ir - 0.5) / ic.projection_nr)
        for itheta in 1:ic.projection_ntheta
            theta = 2.0 * pi * (itheta - 0.5) / ic.projection_ntheta
            value = try
                pressure_h(Point(radius * cos(theta), radius * sin(theta), z))
            catch
                continue
            end
            acc += value
            count += 1
        end
    end
    count > 0 || throw(ArgumentError("could not evaluate any FE pressure section samples at z=$z"))
    return acc / count
end

function relative_l2_error(values::Vector{Float64}, reference::Vector{Float64})
    length(values) == length(reference) || return NaN
    isempty(values) && return NaN
    error_accum = 0.0
    reference_accum = 0.0
    for (value, ref) in zip(values, reference)
        error_accum += (value - ref)^2
        reference_accum += ref^2
    end
    error_norm = sqrt(error_accum / length(values))
    reference_norm = sqrt(reference_accum / length(values))
    reference_norm > 0.0 || return error_norm
    return error_norm / reference_norm
end

finite_mean(values::Vector{Float64}) = isempty(values) ? NaN : sum(values) / length(values)
finite_min(values::Vector{Float64}) = isempty(values) ? NaN : minimum(values)
finite_max(values::Vector{Float64}) = isempty(values) ? NaN : maximum(values)

function write_stationary_stokes_refinement_csv(
    path::String,
    rows::Vector{StationaryStokesRefinementRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, stationary_stokes_refinement_header())
        for row in rows
            println(io, stationary_stokes_refinement_csv_row(row))
        end
    end
    return path
end

function write_stationary_stokes_refinement_tex(
    path::String,
    rows::Vector{StationaryStokesRefinementRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Stationary-Stokes projection and mesh-refinement diagnostics.}")
        println(io, "    \\begin{tabular}{@{}lrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Case & Nodes & Cells & \$\\langle Q\\rangle\$ & FE--proj. \$u\$ & Finest \$u\$ & WSS max \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" || continue
            println(io, stationary_stokes_refinement_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}")
        println(io, "\\end{table}")
    end
    return path
end

function stationary_stokes_refinement_latex_row(row::StationaryStokesRefinementRow)
    return join((
        row.case_id,
        string(row.mesh_nodes),
        string(row.mesh_cells),
        latex_number(row.mean_flow),
        latex_number(row.fe_projection_u_l2_relative_error),
        latex_number(row.finest_u_l2_relative_error),
        latex_number(row.wss_max),
    ), " & ") * " \\\\"
end

function stationary_stokes_refinement_header()
    return join((
        "case_id",
        "severity",
        "pressure_drop_pa",
        "mesh_nz",
        "mesh_nr",
        "mesh_ntheta",
        "projection_nr",
        "projection_ntheta",
        "mesh_nodes",
        "mesh_cells",
        "velocity_dofs",
        "pressure_dofs",
        "elapsed_s",
        "mean_flow",
        "fe_uavg_min",
        "fe_uavg_max",
        "projection_uavg_min",
        "projection_uavg_max",
        "fe_pressure_min",
        "fe_pressure_max",
        "projection_pressure_min",
        "projection_pressure_max",
        "fe_projection_u_l2_relative_error",
        "fe_projection_pressure_l2_relative_error",
        "finest_u_l2_relative_error",
        "finest_pressure_l2_relative_error",
        "traction_samples",
        "wall_traction_mean",
        "wall_traction_max",
        "wss_mean",
        "wss_max",
        "status",
        "error_message",
    ), ",")
end

function stationary_stokes_refinement_csv_row(row::StationaryStokesRefinementRow)
    return join(stationary_stokes_csv_cell.([
        row.case_id,
        row.severity,
        row.pressure_drop_pa,
        row.mesh_nz,
        row.mesh_nr,
        row.mesh_ntheta,
        row.projection_nr,
        row.projection_ntheta,
        row.mesh_nodes,
        row.mesh_cells,
        row.velocity_dofs,
        row.pressure_dofs,
        row.elapsed_s,
        row.mean_flow,
        row.fe_uavg_min,
        row.fe_uavg_max,
        row.projection_uavg_min,
        row.projection_uavg_max,
        row.fe_pressure_min,
        row.fe_pressure_max,
        row.projection_pressure_min,
        row.projection_pressure_max,
        row.fe_projection_u_l2_relative_error,
        row.fe_projection_pressure_l2_relative_error,
        row.finest_u_l2_relative_error,
        row.finest_pressure_l2_relative_error,
        row.traction_samples,
        row.wall_traction_mean,
        row.wall_traction_max,
        row.wss_mean,
        row.wss_max,
        row.status,
        row.error_message,
    ]), ",")
end

function stationary_stokes_csv_cell(value)
    value === nothing && return ""
    text = string(value)
    if any(occursin.(["\"", ",", "\n", "\r"], Ref(text)))
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end
