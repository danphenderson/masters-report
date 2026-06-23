"""
    write_manufactured_verification_csv(path, rows; overwrite=false)

Write the MMS verification summary CSV for the combined spatial and timestep
rows produced by `run_manufactured_verification`.
"""
function write_manufactured_verification_csv(
    path::String,
    rows::Vector{ManufacturedVerificationRow};
    overwrite::Bool = false,
)
    return write_csv_table(
        path,
        manufactured_verification_header(),
        (manufactured_verification_values(row) for row in rows);
        overwrite=overwrite,
    )
end

manufactured_verification_header() = [
    "study_kind",
    "nx",
    "dx",
    "dt",
    "tfinal",
    "area_l1_error",
    "area_l2_error",
    "area_linf_error",
    "area_l2_observed_order",
    "flow_l1_error",
    "flow_l2_error",
    "flow_linf_error",
    "flow_l2_observed_order",
    "accepted_dt_min",
    "accepted_dt_max",
    "realized_cfl_max",
    "independent_mass_forcing_max_abs_diff",
    "independent_momentum_forcing_max_abs_diff",
    "status",
    "error_message",
]

function manufactured_verification_values(row::ManufacturedVerificationRow)
    return Any[
        row.study_kind,
        row.nx,
        row.dx,
        row.dt,
        row.tfinal,
        row.area_l1_error,
        row.area_l2_error,
        row.area_linf_error,
        row.area_observed_order,
        row.flow_l1_error,
        row.flow_l2_error,
        row.flow_linf_error,
        row.flow_observed_order,
        row.accepted_dt_min,
        row.accepted_dt_max,
        row.realized_cfl_max,
        row.independent_mass_forcing_max_abs_diff,
        row.independent_momentum_forcing_max_abs_diff,
        row.status,
        row.error_message,
    ]
end

"""
    write_manufactured_verification_tex(path, rows; overwrite=false)

Write the MMS verification LaTeX tables. The first table is the spatial
verification summary; the second reports timestep insensitivity on the finest
configured grid.
"""
function write_manufactured_verification_tex(
    path::String,
    rows::Vector{ManufacturedVerificationRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Manufactured-solution spatial verification errors. The order columns use adjacent-grid \$L_2\$ errors; the final column checks the inserted forcing against an independently assembled residual.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        \$N\$ & \$\\Delta t_{\\min}\$ & CFL\$_{\\max}\$ & \$\\|e_a\\|_1\$ & \$\\|e_a\\|_2\$ & \$\\|e_a\\|_\\infty\$ & \$p_a\$ & \$\\|e_q\\|_1\$ & \$\\|e_q\\|_2\$ & \$\\|e_q\\|_\\infty\$ & \$p_q\$ & forcing check \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" && row.study_kind == "spatial" || continue
            println(io, manufactured_verification_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
        println(io)
        println(io, "\\begin{table}[!htb]")
        println(io, "    \\centering")
        println(io, "    \\scriptsize")
        println(io, "    \\caption{Manufactured-solution timestep-insensitivity rows on the finest MMS grid. These rows report accepted timestep and realized CFL rather than temporal order.}")
        println(io, "    \\resizebox{\\textwidth}{!}{%")
        println(io, "    \\begin{tabular}{@{}rrrrrrrr@{}}")
        println(io, "        \\toprule")
        println(io, "        \$N\$ & requested \$\\Delta t\$ & accepted \$\\Delta t_{\\min}\$ & accepted \$\\Delta t_{\\max}\$ & CFL\$_{\\max}\$ & \$\\|e_a\\|_2\$ & \$\\|e_q\\|_2\$ & forcing check \\\\")
        println(io, "        \\midrule")
        for row in rows
            row.status == "ok" && row.study_kind == "temporal" || continue
            println(io, manufactured_timestep_latex_row(row))
        end
        println(io, "        \\bottomrule")
        println(io, "    \\end{tabular}%")
        println(io, "    }")
        println(io, "\\end{table}")
    end
    return path
end

function manufactured_verification_latex_row(row::ManufacturedVerificationRow)
    return join((
        string(row.nx),
        latex_number(row.accepted_dt_min),
        latex_number(row.realized_cfl_max),
        latex_number(row.area_l1_error),
        latex_number(row.area_l2_error),
        latex_number(row.area_linf_error),
        latex_number(row.area_observed_order),
        latex_number(row.flow_l1_error),
        latex_number(row.flow_l2_error),
        latex_number(row.flow_linf_error),
        latex_number(row.flow_observed_order),
        latex_number(max(row.independent_mass_forcing_max_abs_diff, row.independent_momentum_forcing_max_abs_diff)),
    ), " & ") * " \\\\"
end

function manufactured_timestep_latex_row(row::ManufacturedVerificationRow)
    return join((
        string(row.nx),
        latex_number(row.dt),
        latex_number(row.accepted_dt_min),
        latex_number(row.accepted_dt_max),
        latex_number(row.realized_cfl_max),
        latex_number(row.area_l2_error),
        latex_number(row.flow_l2_error),
        latex_number(max(row.independent_mass_forcing_max_abs_diff, row.independent_momentum_forcing_max_abs_diff)),
    ), " & ") * " \\\\"
end
