"""
    write_stationary_stokes_refinement_csv(path, rows; overwrite=false)

Write the stationary-Stokes refinement summary CSV with the stable workflow
column order.
"""
function write_stationary_stokes_refinement_csv(
    path::String,
    rows::Vector{StationaryStokesRefinementRow};
    overwrite::Bool = false,
)
    return write_csv_table(
        path,
        stationary_stokes_refinement_header(),
        (stationary_stokes_refinement_values(row) for row in rows);
        overwrite=overwrite,
    )
end

"""
    write_stationary_stokes_refinement_tex(path, rows; overwrite=false)

Write a compact LaTeX summary table for successful rows only. Failed rows stay
in the CSV but are omitted from the rendered table.
"""
function write_stationary_stokes_refinement_tex(
    path::String,
    rows::Vector{StationaryStokesRefinementRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Stationary-Stokes projection and mesh-refinement diagnostics. The finest-mesh relative discrepancy is zero on the finest row by construction; it is included to show the refinement reference used.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}lrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        Case & Nodes & Cells & \$\\langle Q\\rangle_{\\mathrm{FE}}\$ & \$\\mathrm{rel.\\ diff.}(u_{\\mathrm{FE}},u_{\\mathrm{proj}})\$ & \$\\mathrm{rel.\\ diff.}(u_{\\mathrm{FE}},u_{\\mathrm{finest}})\$ & \$\\max |\\tau_w|\$ \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" || continue
            println(io, stationary_stokes_refinement_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
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
    return [
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
    ]
end

function stationary_stokes_refinement_values(row::StationaryStokesRefinementRow)
    return Any[
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
    ]
end
