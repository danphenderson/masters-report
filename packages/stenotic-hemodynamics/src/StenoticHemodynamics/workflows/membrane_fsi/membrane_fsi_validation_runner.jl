"""
    run_membrane_fsi_validation(spec=MembraneFSIValidationSpec())

Run the membrane-FSI validation workflow for every `(severity, mesh)` case in
`spec`, then write the workflow summaries declared by `default_output_paths`.
"""
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

membrane_mean(values::Vector{Float64}) = isempty(values) ? NaN : sum(values) / length(values)
