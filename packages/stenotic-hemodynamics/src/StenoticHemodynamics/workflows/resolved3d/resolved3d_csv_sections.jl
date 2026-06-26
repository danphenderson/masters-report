"""
    write_section_comparison_csv(path, rows; overwrite=false)

Write one per-case axial cross-section CSV from imported resolved-3D versus 1D
comparison rows.
"""
function write_section_comparison_csv(
    path::String,
    rows::Vector{SectionComparisonRow};
    overwrite::Bool = false,
)
    write_csv_table(path, section_comparison_header(), (section_comparison_values(row) for row in rows); overwrite=overwrite)
end

function section_comparison_header()
    return [
        "case_label",
        "severity",
        "operator",
        "model",
        "nx",
        "dt_s",
        "initial_condition",
        "backend",
        "spatial_method",
        "run_status",
        "coordinate_mode",
        "z_cm",
        "area_cm2",
        "flow_3d_cm3_s",
        "flow_1d_cm3_s",
        "mean_axial_u3d_cm_s",
        "reconstructed_axial_u1d_cm_s",
        "abs_velocity_discrepancy_cm_s",
        "flow_abs_discrepancy_cm3_s",
        "relative_discrepancy",
        "rel_l2_velocity_component",
        "intersection_count",
        "area_valid",
        "cut_status",
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

function section_comparison_values(row::SectionComparisonRow)
    return Any[
        row.case_label,
        row.severity,
        row.operator,
        row.model,
        row.nx,
        row.dt_s,
        row.initial_condition,
        row.backend,
        row.spatial_method,
        row.run_status,
        row.coordinate_mode,
        row.z_cm,
        row.area_cm2,
        row.flow_3d_cm3_s,
        row.flow_1d_cm3_s,
        row.mean_u3d_cm_s,
        row.mean_u1d_cm_s,
        row.abs_velocity_error_cm_s,
        row.flow_abs_error_cm3_s,
        row.rel_error,
        row.rel_l2_velocity_component,
        row.intersection_count,
        row.area_valid,
        row.cut_status,
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
