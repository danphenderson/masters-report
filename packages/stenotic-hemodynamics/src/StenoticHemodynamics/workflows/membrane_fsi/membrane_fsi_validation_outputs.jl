"""
    write_membrane_fsi_validation_outputs(result; overwrite=false)

Write the workflow-level summary CSV, summary TeX table, and manifest declared
by a `MembraneFSIValidationResult`.
"""
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

"""
    write_membrane_fsi_profile_csv(path, solution; overwrite=false)

Write one longitudinal wall-response profile CSV for a solved membrane-FSI case.
"""
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

"""
    write_membrane_fsi_history_csv(path, solution; overwrite=false)

Write the fixed-point or dynamic wall-coupling history recorded for one solved
membrane-FSI case.
"""
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

"""
    write_membrane_fsi_manifest(path, result; overwrite=false)

Write the workflow manifest that describes the membrane-FSI validation run and
counts the terminal row statuses present in `result`.
"""
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
