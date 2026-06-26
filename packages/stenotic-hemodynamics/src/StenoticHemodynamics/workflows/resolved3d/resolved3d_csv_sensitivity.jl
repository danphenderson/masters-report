"""
    write_node_slab_sensitivity_csv(path, rows; overwrite=false)

Write the supplemental node-slab sensitivity CSV derived from imported
resolved-3D comparison samples.
"""
function write_node_slab_sensitivity_csv(
    path::String,
    rows::Vector{NodeSlabSensitivityRow};
    overwrite::Bool = false,
)
    write_csv_table(path, node_slab_sensitivity_header(), (node_slab_sensitivity_values(row) for row in rows); overwrite=overwrite)
end

function node_slab_sensitivity_header()
    return [
        "case_label",
        "severity",
        "model",
        "nx",
        "dt_s",
        "initial_condition",
        "backend",
        "spatial_method",
        "run_status",
        "coordinate_mode",
        "half_width_cm",
        "z_cm",
        "mean_axial_u3d_cm_s",
        "reconstructed_axial_u1d_cm_s",
        "abs_velocity_discrepancy_cm_s",
        "relative_discrepancy",
        "node_count",
        "observed_radius_cm",
        "xdmf_time_s",
        "time_offset_s",
        "target_time_s",
        "time_atol_s",
        "one_d_completed_time_s",
        "one_d_terminal_time_error_s",
        "xdmf_target_time_error_s",
        "cross_model_time_offset_s",
    ]
end

function node_slab_sensitivity_values(row::NodeSlabSensitivityRow)
    return Any[
        row.case_label,
        row.severity,
        row.model,
        row.nx,
        row.dt_s,
        row.initial_condition,
        row.backend,
        row.spatial_method,
        row.run_status,
        row.coordinate_mode,
        row.half_width_cm,
        row.z_cm,
        row.mean_u3d_cm_s,
        row.mean_u1d_cm_s,
        row.abs_velocity_error_cm_s,
        row.rel_error,
        row.node_count,
        row.observed_radius_cm,
        row.xdmf_time_s,
        row.time_error_s,
        row.target_time_s,
        row.time_atol_s,
        row.one_d_completed_time_s,
        row.one_d_terminal_time_error_s,
        row.xdmf_target_time_error_s,
        row.cross_model_time_offset_s,
    ]
end
