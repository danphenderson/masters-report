"""
    run_stationary_stokes_refinement(spec=StationaryStokesRefinementSpec())

Run the fixed-wall stationary-Stokes refinement study, then write the CSV and
LaTeX summaries declared by [`default_output_paths`](@ref).
"""
function run_stationary_stokes_refinement(
    spec::StationaryStokesRefinementSpec = StationaryStokesRefinementSpec(),
)
    validate_workflow_spec(spec)
    chunks = parallel_case_map(spec.severities; parallel_workers=spec.parallel_workers) do severity
        stationary_stokes_rows_for_severity(spec, severity)
    end
    rows = reduce(vcat, chunks; init=StationaryStokesRefinementRow[])
    paths = default_output_paths(spec)
    path = paths.summary_csv
    result = StationaryStokesRefinementResult(spec, rows, path)
    write_stationary_stokes_refinement_csv(path, rows; overwrite=spec.overwrite)
    write_stationary_stokes_refinement_tex(paths.summary_tex, rows; overwrite=spec.overwrite)
    return result
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
