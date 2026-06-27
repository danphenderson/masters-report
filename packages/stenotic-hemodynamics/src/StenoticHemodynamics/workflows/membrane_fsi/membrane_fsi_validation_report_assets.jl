"""
    publish_membrane_fsi_report_assets(result; report_assets_dir="report/assets", overwrite=false)

Copy retained membrane-FSI workflow outputs into the report asset layout and
emit the compact `.tex` and `.dat` files consumed by report figures and tables.
"""
function publish_membrane_fsi_report_assets(
    result::MembraneFSIValidationResult;
    report_assets_dir::String = joinpath("report", "assets"),
    overwrite::Bool = false,
)
    data_dir, table_dir = membrane_fsi_report_asset_dirs(report_assets_dir)
    mkpath(data_dir)
    mkpath(table_dir)
    retained_rows = retained_membrane_fsi_rows(result.rows)
    paths = String[]
    push!(
        paths,
        write_membrane_fsi_summary_csv(
            joinpath(data_dir, "summary.csv"),
            result.rows;
            overwrite=overwrite,
        ),
    )
    push!(
        paths,
        write_membrane_fsi_report_summary_tex(
            joinpath(table_dir, "summary.tex"),
            retained_rows;
            overwrite=overwrite,
        ),
    )
    append!(
        paths,
        write_membrane_fsi_report_profile_dat_files(data_dir, retained_rows; overwrite=overwrite),
    )
    append!(
        paths,
        write_membrane_fsi_report_history_dat_files(data_dir, retained_rows; overwrite=overwrite),
    )
    return paths
end

function membrane_fsi_report_asset_dirs(report_assets_dir::String)
    root = normpath(report_assets_dir)
    if basename(root) == "membrane-fsi" && basename(dirname(root)) == "data"
        return root, joinpath(dirname(dirname(root)), "tables", "membrane-fsi")
    end
    return joinpath(root, "data", "membrane-fsi"), joinpath(root, "tables", "membrane-fsi")
end

function retained_membrane_fsi_rows(rows::Vector{MembraneFSIValidationRow})
    ok_rows = [row for row in rows if row.status == "ok" && row.converged]
    isempty(ok_rows) && return MembraneFSIValidationRow[]
    severities = sort(collect(unique(row.severity for row in ok_rows)))
    retained = MembraneFSIValidationRow[]
    for severity in severities
        case_rows = [row for row in ok_rows if row.severity == severity]
        sort!(case_rows; by=row -> (row.mesh_nz, row.mesh_nr, row.mesh_ntheta))
        push!(retained, case_rows[end])
    end
    return retained
end

function write_membrane_fsi_summary_tex(
    path::String,
    rows::Vector{MembraneFSIValidationRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{tabular}{@{}llrrrrrll@{}}")
        println(io, "\\toprule")
        println(io, "Case & Mesh & Nodes & Iter. & \$\\max \\eta\$ & \$\\min R\$ & \$\\langle Q\\rangle\$ & Conv. & Status \\\\")
        println(io, "\\midrule")
        for row in rows
            println(io, join((
                membrane_report_case_label_tex(row),
                membrane_mesh_label(row),
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

function write_membrane_fsi_report_summary_tex(
    path::String,
    rows::Vector{MembraneFSIValidationRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{tabular}{@{}lrrrrrr@{}}")
        println(io, "\\toprule")
        println(
            io,
            "Case & Mesh & Iter. & Residual (cm) & \$\\max\\eta\$ (cm) & \$\\min R\$ (cm) & \$\\langle Q\\rangle\$ (cm\$^3\$/s) \\\\",
        )
        println(io, "\\midrule")
        for row in rows
            println(io, join((
                membrane_report_case_label_tex(row),
                membrane_mesh_label(row),
                string(row.iterations),
                membrane_tex_number(row.residual_cm),
                membrane_tex_number(row.displacement_max_cm),
                membrane_tex_number(row.current_radius_min_cm),
                membrane_tex_number(row.mean_flow_cm3_s),
            ), " & "), " \\\\")
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    return path
end

function write_membrane_fsi_report_profile_dat_files(
    data_dir::String,
    rows::Vector{MembraneFSIValidationRow};
    overwrite::Bool = false,
)
    paths = String[]
    for row in rows
        isfile(row.profile_csv) || continue
        headers, raw_rows = read_workflow_csv_table(row.profile_csv)
        required = [
            "z_cm",
            "reference_radius_cm",
            "displacement_cm",
            "current_radius_cm",
            "wall_force_dyn_cm2",
            "pressure_dyn_cm2",
        ]
        missing = setdiff(required, headers)
        isempty(missing) || throw(ArgumentError("membrane FSI profile '$(row.profile_csv)' is missing columns: $(join(missing, ", "))"))
        path = joinpath(data_dir, "wall-profile-$(report_case_token(row.severity)).dat")
        guarded_open_write(path, overwrite) do io
            println(io, "z reference_radius displacement current_radius wall_force pressure")
            for (index, raw) in enumerate(raw_rows)
                values = Any[
                    required_csv_float(raw, "z_cm", row.profile_csv, index + 1),
                    required_csv_float(raw, "reference_radius_cm", row.profile_csv, index + 1),
                    required_csv_float(raw, "displacement_cm", row.profile_csv, index + 1),
                    required_csv_float(raw, "current_radius_cm", row.profile_csv, index + 1),
                    required_csv_float(raw, "wall_force_dyn_cm2", row.profile_csv, index + 1),
                    required_csv_float(raw, "pressure_dyn_cm2", row.profile_csv, index + 1),
                ]
                println(io, join(report_fmt.(values), " "))
            end
        end
        push!(paths, path)
    end
    return paths
end

function write_membrane_fsi_report_history_dat_files(
    data_dir::String,
    rows::Vector{MembraneFSIValidationRow};
    overwrite::Bool = false,
)
    paths = String[]
    for row in rows
        isfile(row.history_csv) || continue
        headers, raw_rows = read_workflow_csv_table(row.history_csv)
        required = ["step", "residual_cm", "current_radius_min_cm", "current_radius_max_cm"]
        missing = setdiff(required, headers)
        isempty(missing) || throw(ArgumentError("membrane FSI history '$(row.history_csv)' is missing columns: $(join(missing, ", "))"))
        path = joinpath(data_dir, "fixed-point-history-$(report_case_token(row.severity)).dat")
        guarded_open_write(path, overwrite) do io
            println(io, "step residual current_radius_min current_radius_max")
            for (index, raw) in enumerate(raw_rows)
                values = Any[
                    required_csv_int(raw, "step", row.history_csv, index + 1),
                    required_csv_float(raw, "residual_cm", row.history_csv, index + 1),
                    required_csv_float(raw, "current_radius_min_cm", row.history_csv, index + 1),
                    required_csv_float(raw, "current_radius_max_cm", row.history_csv, index + 1),
                ]
                println(io, join(report_fmt.(values), " "))
            end
        end
        push!(paths, path)
    end
    return paths
end

membrane_mesh_label(row::MembraneFSIValidationRow) = "\$$(row.mesh_nz)\\times$(row.mesh_nr)\\times$(row.mesh_ntheta)\$"

function membrane_report_case_label_tex(row::MembraneFSIValidationRow)
    if isapprox(Float64(row.severity), 23.0; rtol=0.0, atol=1.0e-9)
        return "C23 (22.56\\%)"
    end
    return report_case_label_tex(row.severity)
end

function membrane_tex_number(value)
    value isa Real || return string(value)
    number = Float64(value)
    isfinite(number) || return "--"
    return string(round(number; sigdigits=4))
end
