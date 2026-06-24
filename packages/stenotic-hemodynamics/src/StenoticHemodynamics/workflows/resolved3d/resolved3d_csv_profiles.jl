"""
    write_radial_profile_csv(path, rows; overwrite=false)

Write one per-case radial-profile CSV assembled from imported resolved-3D
axial-velocity samples and their reconstructed 1D axial comparison rows.
"""
function write_radial_profile_csv(
    path::String,
    rows::Vector{RadialProfileRow};
    overwrite::Bool = false,
)
    write_csv_table(path, radial_profile_header(), (radial_profile_values(row) for row in rows); overwrite=overwrite)
end

function radial_profile_header()
    return [
        "case_label",
        "severity",
        "operator",
        "model",
        "nx",
        "dt_s",
        "initial_condition",
        "backend",
        "run_status",
        "coordinate_mode",
        "z_slice_cm",
        "radial_bin",
        "r_over_radius_mid",
        "area_cm2",
        "flow_3d_cm3_s",
        "mean_axial_u3d_cm_s",
        "reconstructed_axial_u1d_cm_s",
        "abs_velocity_discrepancy_cm_s",
        "relative_discrepancy",
        "intersection_count",
        "area_valid",
        "node_count",
        "xdmf_time_s",
        "time_offset_s",
        "target_time_s",
        "time_atol_s",
        "one_d_completed_time_s",
        "one_d_terminal_time_error_s",
        "xdmf_target_time_error_s",
        "cross_model_time_offset_s",
        "radial_bin_count",
        "radius_mode",
        "radius_scale_cm",
        "current_area_cm2",
        "reference_area_cm2",
        "current_area_mismatch_rel",
        "velocity_variance_cm2_s2",
    ]
end

function radial_profile_values(row::RadialProfileRow)
    return Any[
        row.case_label,
        row.severity,
        row.operator,
        row.model,
        row.nx,
        row.dt_s,
        row.initial_condition,
        row.backend,
        row.run_status,
        row.coordinate_mode,
        row.z_slice_cm,
        row.radial_bin,
        row.r_over_r0_mid,
        row.area_cm2,
        row.flow_3d_cm3_s,
        row.mean_u3d_cm_s,
        row.mean_u1d_cm_s,
        row.abs_velocity_error_cm_s,
        row.rel_error,
        row.intersection_count,
        row.area_valid,
        row.node_count,
        row.xdmf_time_s,
        row.time_error_s,
        row.target_time_s,
        row.time_atol_s,
        row.one_d_completed_time_s,
        row.one_d_terminal_time_error_s,
        row.xdmf_target_time_error_s,
        row.cross_model_time_offset_s,
        row.radial_bin_count,
        row.radius_mode,
        row.radius_scale_cm,
        row.current_area_cm2,
        row.reference_area_cm2,
        row.current_area_mismatch_rel,
        row.velocity_variance_cm2_s2,
    ]
end
