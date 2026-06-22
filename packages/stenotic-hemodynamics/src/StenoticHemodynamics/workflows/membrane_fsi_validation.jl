struct MembraneFSIValidationSpec{M<:AbstractMembraneWallMode,F} <: AbstractStudySpec
    base_params::Params
    severities::Vector{Float64}
    geometry_id::String
    reference_radius_at_z::F
    pressure_drop_pa::Float64
    meshes::Vector{NTuple{3,Int}}
    mode::M
    output_dir::String
    summary_csv::String
    summary_tex::String
    manifest_json::String
    overwrite::Bool
    max_coupling_iters::Int
    coupling_tolerance_cm::Float64
    damping::Float64
    reference_radius_cm::Float64
    history_stride::Int
    parallel_workers::Int
end

function MembraneFSIValidationSpec(;
    base_params::Params = Params(nx=80, tfinal=0.0, initial_condition=GeometryRestIC()),
    severities = [23.0, 40.0],
    geometry_id::AbstractString = "",
    reference_radius_at_z = nothing,
    pressure_drop_pa::Real = 40.0,
    meshes = [(8, 2, 8), (16, 4, 16)],
    mode::AbstractMembraneWallMode = QuasiStaticMembraneMode(),
    output_dir::AbstractString = "",
    summary_csv::AbstractString = "",
    summary_tex::AbstractString = "",
    manifest_json::AbstractString = "",
    overwrite::Bool = false,
    max_coupling_iters::Int = 12,
    coupling_tolerance_cm::Real = 1.0e-7,
    damping::Real = 0.5,
    reference_radius_cm::Real = wall_reference_radius(base_params),
    history_stride::Int = 1,
    parallel_workers::Int = default_case_workers(),
)
    severity_values = [Float64(severity) for severity in severities]
    mesh_values = [(Int(mesh[1]), Int(mesh[2]), Int(mesh[3])) for mesh in meshes]
    geometry_label = membrane_geometry_label(geometry_id, reference_radius_at_z)
    return MembraneFSIValidationSpec{typeof(mode),typeof(reference_radius_at_z)}(
        base_params,
        severity_values,
        geometry_label,
        reference_radius_at_z,
        Float64(pressure_drop_pa),
        mesh_values,
        mode,
        String(output_dir),
        String(summary_csv),
        String(summary_tex),
        String(manifest_json),
        overwrite,
        max_coupling_iters,
        Float64(coupling_tolerance_cm),
        Float64(damping),
        Float64(reference_radius_cm),
        history_stride,
        parallel_workers,
    )
end

Base.@kwdef struct MembraneFSIValidationRow
    case_id::String
    severity::Float64
    wall_mode::String
    geometry_id::String
    pressure_drop_pa::Float64
    pressure_drop_dyn_cm2::Float64
    mesh_nz::Int
    mesh_nr::Int
    mesh_ntheta::Int
    mesh_nodes::Int
    mesh_cells::Int
    velocity_dofs::Int
    pressure_dofs::Int
    iterations::Int
    converged::Bool
    residual_cm::Float64
    elapsed_s::Float64
    time_s::Float64
    time_step_count::Int
    reference_radius_cm::Float64
    displacement_min_cm::Float64
    displacement_max_cm::Float64
    current_radius_min_cm::Float64
    current_radius_max_cm::Float64
    max_radius_change_rel::Float64
    wall_velocity_min_cm_s::Float64
    wall_velocity_max_cm_s::Float64
    wall_force_mean_dyn_cm2::Float64
    wall_force_max_dyn_cm2::Float64
    pressure_min_dyn_cm2::Float64
    pressure_max_dyn_cm2::Float64
    mean_flow_cm3_s::Float64
    profile_csv::String
    history_csv::String
    status::String
    error_message::String
end

struct MembraneFSIValidationResult
    spec::MembraneFSIValidationSpec
    rows::Vector{MembraneFSIValidationRow}
    summary_csv::String
    summary_tex::String
    manifest_json::String
end

workflow_kind(::MembraneFSIValidationSpec) = "membrane_fsi_validation"

function validate(spec::MembraneFSIValidationSpec)
    validate(spec.base_params)
    !isempty(spec.severities) || throw(ArgumentError("membrane FSI validation requires at least one severity"))
    !isempty(spec.meshes) || throw(ArgumentError("membrane FSI validation requires at least one mesh"))
    spec.pressure_drop_pa > 0.0 || throw(ArgumentError("membrane FSI pressure drop must be positive"))
    spec.base_params.nu > 0.0 || throw(ArgumentError("membrane FSI requires positive Newtonian viscosity"))
    all(mesh -> all(>(0), mesh), spec.meshes) || throw(ArgumentError("all membrane FSI mesh entries must be positive"))
    spec.max_coupling_iters >= 1 || throw(ArgumentError("max_coupling_iters must be positive"))
    spec.coupling_tolerance_cm > 0.0 || throw(ArgumentError("coupling_tolerance_cm must be positive"))
    0.0 < spec.damping <= 1.0 || throw(ArgumentError("damping must lie in (0, 1]"))
    spec.reference_radius_cm > 0.0 || throw(ArgumentError("reference_radius_cm must be positive"))
    spec.history_stride >= 1 || throw(ArgumentError("history_stride must be positive"))
    spec.parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    validate_membrane_geometry_callback(spec)
    if spec.mode isa DynamicMembraneMode
        spec.mode.wall_density > 0.0 || throw(ArgumentError("dynamic membrane wall_density must be positive"))
        spec.mode.dt > 0.0 || throw(ArgumentError("dynamic membrane dt must be positive"))
        spec.mode.tfinal > 0.0 || throw(ArgumentError("dynamic membrane tfinal must be positive"))
    end
    return spec
end

function membrane_geometry_label(geometry_id::AbstractString, reference_radius_at_z)
    text = strip(String(geometry_id))
    !isempty(text) && return text
    return reference_radius_at_z === nothing ? "canic-stenosis" : "custom-smooth-radius"
end

function validate_membrane_geometry_callback(spec::MembraneFSIValidationSpec)
    spec.reference_radius_at_z === nothing && return spec
    samples = (0.0, Float64(spec.base_params.length_cm) / 2.0, Float64(spec.base_params.length_cm))
    for z in samples
        stokes_mesh_radius(spec.reference_radius_at_z, z)
    end
    return spec
end

function default_membrane_fsi_output_dir()
    return joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "membrane_fsi_validation")
end

function default_output_paths(spec::MembraneFSIValidationSpec)
    outdir = isempty(spec.output_dir) ? default_membrane_fsi_output_dir() : spec.output_dir
    summary_csv = isempty(spec.summary_csv) ? joinpath(outdir, "summary.csv") : spec.summary_csv
    summary_tex = isempty(spec.summary_tex) ? replace(summary_csv, r"\.csv$" => ".tex") : spec.summary_tex
    manifest_json = isempty(spec.manifest_json) ? joinpath(outdir, "manifest.json") : spec.manifest_json
    return (summary_csv=summary_csv, summary_tex=summary_tex, manifest_json=manifest_json)
end

function run_membrane_fsi_validation(spec::MembraneFSIValidationSpec = MembraneFSIValidationSpec())
    validate_workflow_spec(spec)
    cases = [(severity=severity, mesh=mesh) for severity in spec.severities for mesh in spec.meshes]
    chunks = parallel_case_map(cases; parallel_workers=spec.parallel_workers) do case
        membrane_fsi_row_for_case(spec, case.severity, case.mesh)
    end
    rows = MembraneFSIValidationRow[chunks...]
    paths = default_output_paths(spec)
    result = MembraneFSIValidationResult(spec, rows, paths.summary_csv, paths.summary_tex, paths.manifest_json)
    write_membrane_fsi_validation_outputs(result; overwrite=spec.overwrite)
    return result
end

function membrane_fsi_row_for_case(
    spec::MembraneFSIValidationSpec,
    severity::Float64,
    mesh::NTuple{3,Int},
)
    nz, nr, ntheta = mesh
    case_id = membrane_fsi_case_id(severity, mesh, spec.mode, spec.geometry_id)
    profile_csv = membrane_fsi_profile_csv_path(spec, case_id)
    history_csv = membrane_fsi_history_csv_path(spec, case_id)

    try
        ic = StationaryStokesIC(
            pressure_drop_pa=spec.pressure_drop_pa,
            mesh_nz=nz,
            mesh_nr=nr,
            mesh_ntheta=ntheta,
            projection_nr=max(nr, 1),
            projection_ntheta=max(ntheta, 1),
        )
        params = params_with(spec.base_params; severity=severity, tfinal=0.0, initial_condition=GeometryRestIC())
        solution = solve_membrane_fsi(
            spec.mode,
            params,
            ic,
            MembraneFSICouplingOptions(
                params;
                max_iterations=spec.max_coupling_iters,
                tolerance_cm=spec.coupling_tolerance_cm,
                damping=spec.damping,
                reference_radius=spec.reference_radius_cm,
                reference_radius_at_z=membrane_reference_radius_at_z(spec, params),
                history_stride=spec.history_stride,
            ),
        )
        write_membrane_fsi_profile_csv(profile_csv, solution; overwrite=spec.overwrite)
        write_membrane_fsi_history_csv(history_csv, solution; overwrite=spec.overwrite)
        status = solution.converged ? "ok" : "not-converged"
        message = solution.converged ? "" : "coupling residual exceeded tolerance after $(solution.iterations) iterations"
        return membrane_fsi_row_from_solution(case_id, severity, spec, mesh, profile_csv, history_csv, solution, status, message)
    catch err
        return membrane_fsi_error_row(
            case_id,
            severity,
            spec,
            mesh,
            profile_csv,
            history_csv,
            "error",
            sprint(showerror, err),
        )
    end
end

function membrane_reference_radius_at_z(spec::MembraneFSIValidationSpec, params::Params)
    spec.reference_radius_at_z === nothing && return z -> stenosis(Float64(z), params)[1]
    return spec.reference_radius_at_z
end

function membrane_fsi_row_from_solution(
    case_id::String,
    severity::Float64,
    spec::MembraneFSIValidationSpec,
    mesh::NTuple{3,Int},
    profile_csv::String,
    history_csv::String,
    solution::MembraneFSISolution,
    status::String,
    error_message::String,
)
    nz, nr, ntheta = mesh
    radius_changes = abs.(solution.current_radius .- solution.reference_radius) ./ solution.reference_radius
    flow = membrane_physical_flow(solution, spec.base_params, spec.pressure_drop_pa)
    return MembraneFSIValidationRow(
        case_id=case_id,
        severity=severity,
        wall_mode=wall_mode_name(spec.mode),
        geometry_id=spec.geometry_id,
        pressure_drop_pa=spec.pressure_drop_pa,
        pressure_drop_dyn_cm2=10.0 * spec.pressure_drop_pa,
        mesh_nz=nz,
        mesh_nr=nr,
        mesh_ntheta=ntheta,
        mesh_nodes=length(solution.mesh.coordinates),
        mesh_cells=length(solution.mesh.cells),
        velocity_dofs=solution.stokes_solution.velocity_dofs,
        pressure_dofs=solution.stokes_solution.pressure_dofs,
        iterations=solution.iterations,
        converged=solution.converged,
        residual_cm=solution.residual,
        elapsed_s=solution.elapsed_s,
        time_s=solution.time_s,
        time_step_count=solution.time_step_count,
        reference_radius_cm=spec.reference_radius_cm,
        displacement_min_cm=minimum(solution.displacement),
        displacement_max_cm=maximum(solution.displacement),
        current_radius_min_cm=minimum(solution.current_radius),
        current_radius_max_cm=maximum(solution.current_radius),
        max_radius_change_rel=maximum(radius_changes),
        wall_velocity_min_cm_s=minimum(solution.wall_velocity),
        wall_velocity_max_cm_s=maximum(solution.wall_velocity),
        wall_force_mean_dyn_cm2=membrane_mean(solution.wall_force),
        wall_force_max_dyn_cm2=maximum(solution.wall_force),
        pressure_min_dyn_cm2=minimum(solution.wall_pressure),
        pressure_max_dyn_cm2=maximum(solution.wall_pressure),
        mean_flow_cm3_s=flow,
        profile_csv=profile_csv,
        history_csv=history_csv,
        status=status,
        error_message=error_message,
    )
end

function membrane_fsi_error_row(
    case_id::String,
    severity::Float64,
    spec::MembraneFSIValidationSpec,
    mesh::NTuple{3,Int},
    profile_csv::String,
    history_csv::String,
    status::String,
    message::String,
)
    nz, nr, ntheta = mesh
    return MembraneFSIValidationRow(
        case_id=case_id,
        severity=severity,
        wall_mode=wall_mode_name(spec.mode),
        geometry_id=spec.geometry_id,
        pressure_drop_pa=spec.pressure_drop_pa,
        pressure_drop_dyn_cm2=10.0 * spec.pressure_drop_pa,
        mesh_nz=nz,
        mesh_nr=nr,
        mesh_ntheta=ntheta,
        mesh_nodes=0,
        mesh_cells=0,
        velocity_dofs=0,
        pressure_dofs=0,
        iterations=0,
        converged=false,
        residual_cm=NaN,
        elapsed_s=NaN,
        time_s=NaN,
        time_step_count=0,
        reference_radius_cm=spec.reference_radius_cm,
        displacement_min_cm=NaN,
        displacement_max_cm=NaN,
        current_radius_min_cm=NaN,
        current_radius_max_cm=NaN,
        max_radius_change_rel=NaN,
        wall_velocity_min_cm_s=NaN,
        wall_velocity_max_cm_s=NaN,
        wall_force_mean_dyn_cm2=NaN,
        wall_force_max_dyn_cm2=NaN,
        pressure_min_dyn_cm2=NaN,
        pressure_max_dyn_cm2=NaN,
        mean_flow_cm3_s=NaN,
        profile_csv=profile_csv,
        history_csv=history_csv,
        status=status,
        error_message=message,
    )
end

function membrane_physical_flow(solution::MembraneFSISolution, p::Params, pressure_drop_pa::Float64)
    radius_at_z = profile_interpolator(solution.z, solution.current_radius)
    resistance = membrane_resistance_integral(p.length_cm, radius_at_z)
    mu = p.rho * p.nu
    resistance > 0.0 || return NaN
    return pi * (10.0 * pressure_drop_pa) / (8.0 * mu * resistance)
end

function membrane_fsi_case_id(
    severity::Float64,
    mesh::NTuple{3,Int},
    mode::AbstractMembraneWallMode,
    geometry_id::AbstractString,
)
    nz, nr, ntheta = mesh
    return "fsi-$(replace(wall_mode_name(mode), "-" => "_"))-$(membrane_geometry_token(geometry_id))-s$(path_token(severity))-$(nz)x$(nr)x$(ntheta)"
end

function membrane_geometry_token(geometry_id::AbstractString)
    token = replace(lowercase(strip(String(geometry_id))), r"[^a-z0-9]+" => "_")
    token = replace(token, r"^_+|_+$" => "")
    return isempty(token) ? "geometry" : token
end

function membrane_fsi_profile_csv_path(spec::MembraneFSIValidationSpec, case_id::String)
    outdir = isempty(spec.output_dir) ? default_membrane_fsi_output_dir() : spec.output_dir
    return joinpath(outdir, "profiles", "$(case_id).csv")
end

function membrane_fsi_history_csv_path(spec::MembraneFSIValidationSpec, case_id::String)
    outdir = isempty(spec.output_dir) ? default_membrane_fsi_output_dir() : spec.output_dir
    return joinpath(outdir, "histories", "$(case_id).csv")
end

function write_membrane_fsi_validation_outputs(result::MembraneFSIValidationResult; overwrite::Bool = false)
    write_membrane_fsi_summary_csv(result.summary_csv, result.rows; overwrite=overwrite)
    write_membrane_fsi_summary_tex(result.summary_tex, result.rows; overwrite=overwrite)
    write_membrane_fsi_manifest(result.manifest_json, result; overwrite=overwrite)
    return result
end

function write_membrane_fsi_summary_csv(
    path::String,
    rows::Vector{MembraneFSIValidationRow};
    overwrite::Bool = false,
)
    return write_csv_table(path, membrane_fsi_summary_header(), (membrane_fsi_summary_values(row) for row in rows); overwrite=overwrite)
end

function membrane_fsi_summary_header()
    return [
        "case_id",
        "severity",
        "wall_mode",
        "geometry_id",
        "pressure_drop_pa",
        "pressure_drop_dyn_cm2",
        "mesh_nz",
        "mesh_nr",
        "mesh_ntheta",
        "mesh_nodes",
        "mesh_cells",
        "velocity_dofs",
        "pressure_dofs",
        "iterations",
        "converged",
        "residual_cm",
        "elapsed_s",
        "time_s",
        "time_step_count",
        "reference_radius_cm",
        "displacement_min_cm",
        "displacement_max_cm",
        "current_radius_min_cm",
        "current_radius_max_cm",
        "max_radius_change_rel",
        "wall_velocity_min_cm_s",
        "wall_velocity_max_cm_s",
        "wall_force_mean_dyn_cm2",
        "wall_force_max_dyn_cm2",
        "pressure_min_dyn_cm2",
        "pressure_max_dyn_cm2",
        "mean_flow_cm3_s",
        "profile_csv",
        "history_csv",
        "status",
        "error_message",
    ]
end

function membrane_fsi_summary_values(row::MembraneFSIValidationRow)
    return Any[
        row.case_id,
        row.severity,
        row.wall_mode,
        row.geometry_id,
        row.pressure_drop_pa,
        row.pressure_drop_dyn_cm2,
        row.mesh_nz,
        row.mesh_nr,
        row.mesh_ntheta,
        row.mesh_nodes,
        row.mesh_cells,
        row.velocity_dofs,
        row.pressure_dofs,
        row.iterations,
        row.converged,
        row.residual_cm,
        row.elapsed_s,
        row.time_s,
        row.time_step_count,
        row.reference_radius_cm,
        row.displacement_min_cm,
        row.displacement_max_cm,
        row.current_radius_min_cm,
        row.current_radius_max_cm,
        row.max_radius_change_rel,
        row.wall_velocity_min_cm_s,
        row.wall_velocity_max_cm_s,
        row.wall_force_mean_dyn_cm2,
        row.wall_force_max_dyn_cm2,
        row.pressure_min_dyn_cm2,
        row.pressure_max_dyn_cm2,
        row.mean_flow_cm3_s,
        row.profile_csv,
        row.history_csv,
        row.status,
        row.error_message,
    ]
end

function write_membrane_fsi_profile_csv(
    path::String,
    solution::MembraneFSISolution;
    overwrite::Bool = false,
)
    header = [
        "z_cm",
        "reference_radius_cm",
        "displacement_cm",
        "current_radius_cm",
        "wall_velocity_cm_s",
        "wall_force_dyn_cm2",
        "pressure_dyn_cm2",
    ]
    rows = (
        Any[
            solution.z[i],
            solution.reference_radius[i],
            solution.displacement[i],
            solution.current_radius[i],
            solution.wall_velocity[i],
            solution.wall_force[i],
            solution.wall_pressure[i],
        ] for i in eachindex(solution.z)
    )
    return write_csv_table(path, header, rows; overwrite=overwrite)
end

function write_membrane_fsi_history_csv(
    path::String,
    solution::MembraneFSISolution;
    overwrite::Bool = false,
)
    header = [
        "step",
        "time_s",
        "residual_cm",
        "displacement_min_cm",
        "displacement_max_cm",
        "current_radius_min_cm",
        "current_radius_max_cm",
        "wall_pressure_min_dyn_cm2",
        "wall_pressure_max_dyn_cm2",
        "wall_velocity_min_cm_s",
        "wall_velocity_max_cm_s",
    ]
    rows = (
        Any[
            row.step,
            row.time_s,
            row.residual_cm,
            row.displacement_min_cm,
            row.displacement_max_cm,
            row.current_radius_min_cm,
            row.current_radius_max_cm,
            row.wall_pressure_min_dyn_cm2,
            row.wall_pressure_max_dyn_cm2,
            row.wall_velocity_min_cm_s,
            row.wall_velocity_max_cm_s,
        ] for row in solution.history
    )
    return write_csv_table(path, header, rows; overwrite=overwrite)
end

function write_membrane_fsi_summary_tex(
    path::String,
    rows::Vector{MembraneFSIValidationRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{tabular}{@{}lrrrrrll@{}}")
        println(io, "\\toprule")
        println(io, "Case & Nodes & Iter. & \$\\max \\eta\$ & \$\\min R\$ & \$\\langle Q\\rangle\$ & Conv. & Status \\\\")
        println(io, "\\midrule")
        for row in rows
            println(io, join((
                row.case_id,
                string(row.mesh_nodes),
                string(row.iterations),
                membrane_tex_number(row.displacement_max_cm),
                membrane_tex_number(row.current_radius_min_cm),
                membrane_tex_number(row.mean_flow_cm3_s),
                string(row.converged),
                row.status,
            ), " & "), " \\\\")
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    return path
end

function write_membrane_fsi_manifest(
    path::String,
    result::MembraneFSIValidationResult;
    overwrite::Bool = false,
)
    spec = result.spec
    return write_json(
        path,
        Dict(
            "workflow_kind" => workflow_kind(spec),
            "wall_mode" => wall_mode_name(spec.mode),
            "geometry_id" => spec.geometry_id,
            "reference_radius_profile" =>
                spec.reference_radius_at_z === nothing ? "canic-stenosis-from-severity" : "custom-callback",
            "severities" => spec.severities,
            "meshes" => [collect(mesh) for mesh in spec.meshes],
            "pressure_drop_pa" => spec.pressure_drop_pa,
            "reference_radius_cm" => spec.reference_radius_cm,
            "history_stride" => spec.history_stride,
            "max_coupling_iters" => spec.max_coupling_iters,
            "coupling_tolerance_cm" => spec.coupling_tolerance_cm,
            "damping" => spec.damping,
            "dynamic_wall_density" => spec.mode isa DynamicMembraneMode ? spec.mode.wall_density : nothing,
            "dynamic_dt_s" => spec.mode isa DynamicMembraneMode ? spec.mode.dt : nothing,
            "dynamic_tfinal_s" => spec.mode isa DynamicMembraneMode ? spec.mode.tfinal : nothing,
            "summary_csv" => result.summary_csv,
            "summary_tex" => result.summary_tex,
            "row_count" => length(result.rows),
            "ok_count" => count(row -> row.status == "ok", result.rows),
            "not_converged_count" => count(row -> row.status == "not-converged", result.rows),
            "error_count" => count(row -> row.status == "error", result.rows),
        );
        overwrite=overwrite,
    )
end

membrane_mean(values::Vector{Float64}) = isempty(values) ? NaN : sum(values) / length(values)

function membrane_tex_number(value)
    value isa Real || return string(value)
    number = Float64(value)
    isfinite(number) || return "--"
    return string(round(number; sigdigits=4))
end
