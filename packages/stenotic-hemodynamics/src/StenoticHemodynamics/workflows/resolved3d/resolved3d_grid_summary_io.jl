function write_grid_sensitivity_outputs(result::GridSensitivityResult; overwrite::Bool = false)
    write_grid_sensitivity_summary_csv(result.summary_csv, result.summary_rows; overwrite=overwrite)
    write_grid_sensitivity_summary_tex(result.summary_tex, result.summary_rows; overwrite=overwrite)
    return result
end

function write_grid_sensitivity_summary_csv(
    path::String,
    rows::Vector{GridSensitivitySummaryRow};
    overwrite::Bool = false,
)
    return write_csv_table(
        path,
        grid_sensitivity_summary_header(),
        (grid_sensitivity_summary_values(row) for row in rows);
        overwrite=overwrite,
    )
end

function grid_sensitivity_summary_header()
    return [
        "case_label",
        "severity",
        "case",
        "operator",
        "model",
        "nx",
        "dt_s",
        "initial_condition",
        "backend",
        "run_status",
        "coordinate_mode",
        "target_time_s",
        "section_count",
        "valid_section_count",
        "mean_physical_flow_bias_1d_minus_3d_cm3_s",
        "mean_physical_flow_discrepancy_cm3_s",
        "rms_physical_flow_discrepancy_cm3_s",
        "mean_velocity_bias_1d_minus_3d_cm_s",
        "mean_velocity_discrepancy_cm_s",
        "rms_velocity_discrepancy_cm_s",
        "max_velocity_discrepancy_cm_s",
        "max_velocity_discrepancy_z_cm",
        "relative_rms_velocity_discrepancy",
        "adjacent_from_nx",
        "adjacent_mean_abs_velocity_difference_cm_s",
        "adjacent_rms_velocity_difference_cm_s",
        "adjacent_max_abs_velocity_difference_cm_s",
        "adjacent_relative_rms_velocity_difference",
        "one_d_completed_time_s",
        "cross_model_time_offset_s",
        "runtime_elapsed_s",
        "case_worker_count",
        "solver_thread_count",
        "julia_thread_count",
        "process_id",
        "comparison_summary_csv",
        "section_csv",
    ]
end

function grid_sensitivity_summary_values(row::GridSensitivitySummaryRow)
    return Any[
        row.case_label,
        round(Int, row.severity),
        report_case_token(row.severity),
        row.operator,
        row.model,
        row.nx,
        row.dt_s,
        row.initial_condition,
        row.backend,
        row.run_status,
        row.coordinate_mode,
        row.target_time_s,
        row.section_count,
        row.valid_section_count,
        row.mean_physical_flow_bias_cm3_s,
        row.mean_physical_flow_discrepancy_cm3_s,
        row.rms_physical_flow_discrepancy_cm3_s,
        row.mean_velocity_bias_cm_s,
        row.mean_velocity_discrepancy_cm_s,
        row.rms_velocity_discrepancy_cm_s,
        row.max_velocity_discrepancy_cm_s,
        row.max_velocity_discrepancy_z_cm,
        row.relative_rms_velocity_discrepancy,
        row.adjacent_from_nx,
        row.adjacent_mean_abs_velocity_difference_cm_s,
        row.adjacent_rms_velocity_difference_cm_s,
        row.adjacent_max_abs_velocity_difference_cm_s,
        row.adjacent_relative_rms_velocity_difference,
        row.one_d_completed_time_s,
        row.cross_model_time_offset_s,
        row.runtime_elapsed_s,
        row.case_worker_count,
        row.solver_thread_count,
        row.julia_thread_count,
        row.process_id,
        row.comparison_summary_csv,
        row.section_csv,
    ]
end

function read_grid_sensitivity_summary_csv(path::String)
    headers, raw_rows = read_workflow_csv_table(path)
    optional_columns = Set([
        "case",
        "coordinate_mode",
        "runtime_elapsed_s",
        "case_worker_count",
        "solver_thread_count",
        "julia_thread_count",
        "process_id",
    ])
    required_columns = filter(column -> !(column in optional_columns), grid_sensitivity_summary_header())
    missing_columns = setdiff(required_columns, headers)
    if !isempty(missing_columns)
        throw(ArgumentError("grid sensitivity summary '$path' is missing columns: $(join(missing_columns, ", "))"))
    end

    rows = GridSensitivitySummaryRow[]
    for (index, row) in enumerate(raw_rows)
        push!(rows, grid_sensitivity_summary_row_from_csv(row, path, index + 1))
    end
    isempty(rows) && throw(ArgumentError("grid sensitivity summary '$path' has no data rows"))
    return rows
end

function grid_sensitivity_summary_row_from_csv(row::Dict{String,String}, path::String, line_number::Int)
    return GridSensitivitySummaryRow(
        required_csv_string(row, "case_label", path, line_number),
        required_csv_float(row, "severity", path, line_number),
        required_csv_string(row, "operator", path, line_number),
        required_csv_string(row, "model", path, line_number),
        required_csv_int(row, "nx", path, line_number),
        required_csv_float(row, "dt_s", path, line_number),
        required_csv_string(row, "initial_condition", path, line_number),
        required_csv_string(row, "backend", path, line_number),
        required_csv_string(row, "run_status", path, line_number),
        get(row, "coordinate_mode", "reference"),
        required_csv_float(row, "target_time_s", path, line_number),
        required_csv_int(row, "section_count", path, line_number),
        required_csv_int(row, "valid_section_count", path, line_number),
        required_csv_float(row, "mean_physical_flow_bias_1d_minus_3d_cm3_s", path, line_number),
        required_csv_float(row, "mean_physical_flow_discrepancy_cm3_s", path, line_number),
        required_csv_float(row, "rms_physical_flow_discrepancy_cm3_s", path, line_number),
        required_csv_float(row, "mean_velocity_bias_1d_minus_3d_cm_s", path, line_number),
        required_csv_float(row, "mean_velocity_discrepancy_cm_s", path, line_number),
        required_csv_float(row, "rms_velocity_discrepancy_cm_s", path, line_number),
        required_csv_float(row, "max_velocity_discrepancy_cm_s", path, line_number),
        required_csv_float(row, "max_velocity_discrepancy_z_cm", path, line_number),
        required_csv_float(row, "relative_rms_velocity_discrepancy", path, line_number),
        required_csv_int(row, "adjacent_from_nx", path, line_number),
        required_csv_float(row, "adjacent_mean_abs_velocity_difference_cm_s", path, line_number),
        required_csv_float(row, "adjacent_rms_velocity_difference_cm_s", path, line_number),
        required_csv_float(row, "adjacent_max_abs_velocity_difference_cm_s", path, line_number),
        required_csv_float(row, "adjacent_relative_rms_velocity_difference", path, line_number),
        required_csv_float(row, "one_d_completed_time_s", path, line_number),
        required_csv_float(row, "cross_model_time_offset_s", path, line_number),
        optional_csv_float(row, "runtime_elapsed_s", NaN),
        optional_csv_int(row, "case_worker_count", 0),
        optional_csv_int(row, "solver_thread_count", 0),
        optional_csv_int(row, "julia_thread_count", 0),
        optional_csv_int(row, "process_id", 0),
        required_csv_string(row, "comparison_summary_csv", path, line_number),
        required_csv_string(row, "section_csv", path, line_number),
    )
end

function read_workflow_csv_table(path::String)
    isfile(path) || throw(ArgumentError("CSV input '$path' does not exist"))
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("CSV input '$path' is empty"))
    headers = split(lines[1], ",")
    isempty(headers) && throw(ArgumentError("CSV input '$path' has no header"))
    rows = Dict{String,String}[]
    for (line_number, line) in enumerate(lines[2:end])
        isempty(strip(line)) && continue
        startswith(line, "#") && continue
        values = split(line, ",")
        length(values) == length(headers) ||
            throw(ArgumentError("CSV input '$path' line $(line_number + 1) has $(length(values)) fields; expected $(length(headers))"))
        push!(rows, Dict(header => value for (header, value) in zip(headers, values)))
    end
    return headers, rows
end

function required_csv_string(row::Dict{String,String}, column::String, path::String, line_number::Int)
    haskey(row, column) || throw(ArgumentError("CSV input '$path' line $line_number is missing '$column'"))
    return row[column]
end

function required_csv_float(row::Dict{String,String}, column::String, path::String, line_number::Int)
    value = required_csv_string(row, column, path, line_number)
    try
        return parse(Float64, value)
    catch err
        err isa ArgumentError || rethrow()
        throw(ArgumentError("CSV input '$path' line $line_number column '$column' is not a float: '$value'"))
    end
end

function optional_csv_float(row::Dict{String,String}, column::String, default::Float64)
    return haskey(row, column) ? parse(Float64, row[column]) : default
end

function optional_csv_int(row::Dict{String,String}, column::String, default::Int)
    return haskey(row, column) ? parse(Int, row[column]) : default
end

function required_csv_int(row::Dict{String,String}, column::String, path::String, line_number::Int)
    value = required_csv_string(row, column, path, line_number)
    try
        return parse(Int, value)
    catch err
        err isa ArgumentError || rethrow()
        throw(ArgumentError("CSV input '$path' line $line_number column '$column' is not an integer: '$value'"))
    end
end

function write_grid_sensitivity_summary_tex(
    path::String,
    rows::Vector{GridSensitivitySummaryRow};
    overwrite::Bool = false,
)
    ordered_rows = sort(collect(rows); by=row -> (row.severity, row.nx))
    guarded_open_write(path, overwrite) do io
        println(io, raw"\begin{tabular}{llrrrrrrr}")
        println(io, raw"\toprule")
        println(
            io,
            "Case & \$N\$ & \$D_{Q,1}\$ & \$D_{Q,2}\$ & \$D_{u,1}\$ & \$D_{u,2}\$ & rel. \$D_{u,2}\$ & max \$|d_u|\$ & adj. \$D_{u,2}\$ \\\\",
        )
        println(io, raw"\midrule")
        for row in ordered_rows
            values = [
                report_case_label_tex(row.severity),
                string(row.nx),
                tex_number(row.mean_physical_flow_discrepancy_cm3_s),
                tex_number(row.rms_physical_flow_discrepancy_cm3_s),
                tex_number(row.mean_velocity_discrepancy_cm_s),
                tex_number(row.rms_velocity_discrepancy_cm_s),
                tex_number(row.relative_rms_velocity_discrepancy),
                tex_number(row.max_velocity_discrepancy_cm_s),
                tex_number(row.adjacent_rms_velocity_difference_cm_s),
            ]
            println(io, join(values, " & "), " \\\\")
        end
        println(io, raw"\bottomrule")
        println(io, raw"\end{tabular}")
    end
    return path
end

function tex_number(value)
    value isa Real || return string(value)
    number = Float64(value)
    isfinite(number) || return "--"
    return string(round(number; sigdigits=4))
end
