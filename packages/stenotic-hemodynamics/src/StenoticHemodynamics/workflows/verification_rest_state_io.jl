# CSV and report writers for rest-state drift diagnostics.

function write_rest_state_drift_csv(path::String, rows::Vector{RestStateDriftRow}; overwrite::Bool = false)
    return write_csv_table(path, rest_state_drift_header(), (rest_state_drift_values(row) for row in rows); overwrite=overwrite)
end

rest_state_drift_header() = [
    "severity",
    "nx",
    "dx",
    "elapsed_time_s",
    "requested_time_s",
    "terminal_time_error_s",
    "max_abs_q",
    "max_abs_q_z",
    "max_abs_area_drift",
    "solver_volume_defect",
    "physical_volume_defect",
    "requested_q_in",
    "applied_q_in",
    "inlet_area_flux",
    "outlet_area_flux",
    "boundary_flux_integral",
    "conservation_residual",
    "inlet_cell_q",
    "outlet_cell_q",
    "mean_q",
    "rms_q",
    "lh_area_interior_max_abs",
    "lh_area_boundary_max_abs",
    "lh_flow_interior_max_abs",
    "lh_flow_boundary_max_abs",
    "realized_cfl_max",
    "lambda_minus_min",
    "lambda_plus_max",
    "subcritical_margin_min",
    "positivity_projection_count",
    "positivity_correction_total",
    "status",
    "error_message",
]

function rest_state_drift_values(row::RestStateDriftRow)
    return Any[
        row.severity,
        row.nx,
        row.dx,
        row.elapsed_time_s,
        row.requested_time_s,
        row.terminal_time_error_s,
        row.max_abs_q,
        row.max_abs_q_z,
        row.max_abs_area_drift,
        row.solver_volume_defect,
        row.physical_volume_defect,
        row.requested_q_in,
        row.applied_q_in,
        row.inlet_area_flux,
        row.outlet_area_flux,
        row.boundary_flux_integral,
        row.conservation_residual,
        row.inlet_cell_q,
        row.outlet_cell_q,
        row.mean_q,
        row.rms_q,
        row.lh_area_interior_max_abs,
        row.lh_area_boundary_max_abs,
        row.lh_flow_interior_max_abs,
        row.lh_flow_boundary_max_abs,
        row.realized_cfl_max,
        row.lambda_minus_min,
        row.lambda_plus_max,
        row.subcritical_margin_min,
        row.positivity_projection_count,
        row.positivity_correction_total,
        row.status,
        row.error_message,
    ]
end

function write_rest_state_residual_components_csv(
    path::String,
    rows::Vector{RestStateResidualComponentRow};
    overwrite::Bool = false,
)
    return write_csv_table(
        path,
        rest_state_residual_components_header(),
        (rest_state_residual_components_values(row) for row in rows);
        overwrite=overwrite,
    )
end

rest_state_residual_components_header() = [
    "severity",
    "nx",
    "dx",
    "mass_flux_rusanov_max_abs",
    "mass_flux_rusanov_z_cm",
    "elastic_flux_difference_max_abs",
    "elastic_flux_difference_z_cm",
    "wall_geometry_source_max_abs",
    "wall_geometry_source_z_cm",
    "total_flow_residual_max_abs",
    "total_flow_residual_z_cm",
    "total_area_residual_max_abs",
    "status",
    "error_message",
]

function rest_state_residual_components_values(row::RestStateResidualComponentRow)
    return Any[
        row.severity,
        row.nx,
        row.dx,
        row.mass_flux_rusanov_max_abs,
        row.mass_flux_rusanov_z_cm,
        row.elastic_flux_difference_max_abs,
        row.elastic_flux_difference_z_cm,
        row.wall_geometry_source_max_abs,
        row.wall_geometry_source_z_cm,
        row.total_flow_residual_max_abs,
        row.total_flow_residual_z_cm,
        row.total_area_residual_max_abs,
        row.status,
        row.error_message,
    ]
end

rest_state_profile_header() = [
    "severity",
    "nx",
    "requested_time_s",
    "elapsed_time_s",
    "z_cm",
    "a_cm2",
    "q_cm3_s",
    "u_cm_s",
]

function write_rest_state_drift_profile_csv(path::String, rows; overwrite::Bool = false)
    return write_csv_table(path, rest_state_profile_header(), rows; overwrite=overwrite)
end

# CSV writers keep the full diagnostic surface; LaTeX writers collapse it to
# the report-facing summary tables.
function write_rest_state_drift_tex(path::String, rows::Vector{RestStateDriftRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Zero-forcing, zero-inlet geometry-rest drift summary. The table reports the requested/applied inlet flow, the largest cell flow over positive elapsed times, and the signed finite-volume balance at the final reported time.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Severity & \$N\$ & time of peak \$\\max_i |q_i|\$ & requested \$q_{\\mathrm{in}}\$ & applied \$q_{\\mathrm{in}}\$ & peak \$\\max |q_i|\$ & \$z_{\\max |q|}\$ & final \$\\max |q_i|\$ & final \$\\Delta\\!\\int a\\,dz\$ & final flux integral & final balance residual \\\\")
        println(io, "        \\midrule")
        for row in rest_state_drift_summary_rows(rows)
            println(io, rest_state_drift_summary_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
    end
    return path
end

function write_rest_state_residual_components_tex(
    path::String,
    rows::Vector{RestStateResidualComponentRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Initial geometry-rest residual component magnitudes at \$t=0\$. The area row is the Rusanov mass-flux residual. The momentum rows split the elastic-flux difference and wall/geometry source before summing them into the total flow residual. Values are maxima over cells in solver coordinates.}")
        println(io, "    \\label{tab:rest-state-residual-components}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}lrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Case & \$N\$ & \$\\max |R_a^{\\mathrm{Rus}}|\$ & \$z_a\$ & \$\\max |R_q^{\\mathrm{el}}|\$ & \$\\max |S_q^{\\mathrm{wall}}|\$ & \$\\max |R_q^{\\mathrm{tot}}|\$ & \$z_{q,\\mathrm{tot}}\$ \\\\")
        println(io, "        \\midrule")
        for row in rest_state_residual_component_summary_rows(rows)
            row.status == "ok" || continue
            println(io, rest_state_residual_components_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
    end
    return path
end

function write_rest_state_drift_full_tex(path::String, rows::Vector{RestStateDriftRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Full zero-forcing, zero-inlet geometry-rest drift diagnostics. The volume-defect column is the signed solver-coordinate integral \$\\Delta\\!\\int a\\,dz\$; the balance residual is \$\\Delta\\!\\int a\\,dz+\\int(\\widehat F^a_{\\mathrm{out}}-\\widehat F^a_{\\mathrm{in}})\\,dt\$.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Severity & \$N\$ & \$t\$ & requested \$q_{\\mathrm{in}}\$ & applied \$q_{\\mathrm{in}}\$ & \$\\widehat F^a_{\\mathrm{in}}\$ & \$\\widehat F^a_{\\mathrm{out}}\$ & \$\\max |q_i|\$ & \$z_{\\max |q|}\$ & \$\\Delta\\!\\int a\\,dz\$ & balance residual \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" || continue
            println(io, rest_state_drift_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
    end
    return path
end

function rest_state_drift_summary_rows(rows::Vector{RestStateDriftRow})
    ok_rows = [row for row in rows if row.status == "ok" && row.elapsed_time_s > 0.0]
    nxs = sort(unique(row.nx for row in ok_rows))
    selected_nxs = Set(nxs[max(1, length(nxs) - 1):end])
    output = NamedTuple[]
    for severity in sort(unique(row.severity for row in ok_rows)), nx in sort(collect(selected_nxs))
        group = [row for row in ok_rows if row.severity == severity && row.nx == nx]
        isempty(group) && continue
        max_q_row = group[argmax([row.max_abs_q for row in group])]
        final_row = group[argmax([row.elapsed_time_s for row in group])]
        terminal_errors = [row.terminal_time_error_s for row in group if isfinite(row.terminal_time_error_s)]
        push!(output, (
            severity=severity,
            nx=nx,
            peak_time_s=max_q_row.elapsed_time_s,
            peak_requested_q_in=max_q_row.requested_q_in,
            peak_applied_q_in=max_q_row.applied_q_in,
            peak_max_abs_q=max_q_row.max_abs_q,
            peak_max_abs_q_z=max_q_row.max_abs_q_z,
            final_max_abs_q=final_row.max_abs_q,
            final_solver_volume_defect=final_row.solver_volume_defect,
            final_boundary_flux_integral=final_row.boundary_flux_integral,
            final_conservation_residual=final_row.conservation_residual,
            max_terminal_time_error_s=isempty(terminal_errors) ? NaN : maximum(terminal_errors),
        ))
    end
    return output
end

function rest_state_residual_component_summary_rows(rows::Vector{RestStateResidualComponentRow})
    ok_rows = [row for row in rows if row.status == "ok"]
    isempty(ok_rows) && return RestStateResidualComponentRow[]
    nxs = sort(unique(row.nx for row in ok_rows))
    selected_nxs = Set(nxs[max(1, length(nxs) - 1):end])
    return [
        row for row in sort(ok_rows; by=row -> (row.severity, row.nx))
        if row.nx in selected_nxs
    ]
end

rest_state_comparison_flow_scale() = 2.288 / pi

function rest_state_drift_summary_latex_row(row)
    return join((
        string(round(Int, row.severity)),
        string(row.nx),
        latex_number(row.peak_time_s),
        latex_number(row.peak_requested_q_in),
        latex_number(row.peak_applied_q_in),
        latex_number(row.peak_max_abs_q),
        latex_number(row.peak_max_abs_q_z),
        latex_number(row.final_max_abs_q),
        latex_number(row.final_solver_volume_defect),
        latex_number(row.final_boundary_flux_integral),
        latex_number(row.final_conservation_residual),
    ), " & ") * " \\\\"
end

function rest_state_residual_components_latex_row(row::RestStateResidualComponentRow)
    return join((
        "C$(round(Int, row.severity))",
        string(row.nx),
        latex_number(row.mass_flux_rusanov_max_abs),
        latex_number(row.mass_flux_rusanov_z_cm),
        latex_number(row.elastic_flux_difference_max_abs),
        latex_number(row.wall_geometry_source_max_abs),
        latex_number(row.total_flow_residual_max_abs),
        latex_number(row.total_flow_residual_z_cm),
    ), " & ") * " \\\\"
end

function rest_state_drift_latex_row(row::RestStateDriftRow)
    return join((
        string(round(Int, row.severity)),
        string(row.nx),
        latex_number(row.elapsed_time_s),
        latex_number(row.requested_q_in),
        latex_number(row.applied_q_in),
        latex_number(row.inlet_area_flux),
        latex_number(row.outlet_area_flux),
        latex_number(row.max_abs_q),
        latex_number(row.max_abs_q_z),
        latex_number(row.solver_volume_defect),
        latex_number(row.conservation_residual),
    ), " & ") * " \\\\"
end
