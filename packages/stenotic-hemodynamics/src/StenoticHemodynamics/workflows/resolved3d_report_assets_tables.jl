"""
    write_report_section_dat(path, rows; overwrite=false)

Write the report-facing section comparison `.dat` table for one coordinate mode.
Rows are grouped by severity and aligned on the unique section `z_cm` values
already present in `rows`.
"""
function write_report_section_dat(path::String, rows::Vector{SectionComparisonRow}; overwrite::Bool = false)
    cases = sort(collect(unique(row.severity for row in rows)))
    z_values = sort(collect(unique(row.z_cm for row in rows)))
    rows_by_case_z = Dict((row.severity, row.z_cm) => row for row in rows)
    guarded_open_write(path, overwrite) do io
        headers = ["z"]
        for severity in cases
            token = report_case_token(severity)
            append!(
                headers,
                [
                    "u1d$(token)",
                    "u3d$(token)",
                    "disc$(token)",
                    "flow1d$(token)",
                    "flow3d$(token)",
                    "flowdisc$(token)",
                    "area$(token)",
                    "intersections$(token)",
                ],
            )
        end
        println(io, join(headers, " "))
        for z in z_values
            values = Any[z]
            for severity in cases
                row = rows_by_case_z[(severity, z)]
                append!(
                    values,
                    [
                        row.mean_u1d_cm_s,
                        row.mean_u3d_cm_s,
                        row.abs_velocity_error_cm_s,
                        row.flow_1d_cm3_s,
                        row.flow_3d_cm3_s,
                        row.flow_abs_error_cm3_s,
                        row.area_cm2,
                        row.intersection_count,
                    ],
                )
            end
            println(io, join(report_fmt.(values), " "))
        end
    end
    return path
end

"""
    write_report_production_diagnostics_dat(path, rows; overwrite=false)

Write the report-facing production-diagnostics `.dat` table from comparison
summary rows without changing the existing column order or filenames.
"""
function write_report_production_diagnostics_dat(
    path::String,
    rows::Vector{ComparisonSummaryRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(
            io,
            join(
                [
                    "case",
                    "dt_min",
                    "dt_max",
                    "cfl_max",
                    "min_a",
                    "min_Aphys",
                    "volume_defect",
                    "positivity_count",
                    "positivity_correction",
                    "area_flux_balance",
                    "rhs_area_max",
                    "rhs_flow_max",
                    "completed_time",
                    "target_time",
                    "cross_model_time_offset",
                ],
                " ",
            ),
        )
        for row in rows
            println(
                io,
                join(
                    report_fmt.([
                        report_case_percent_tex(row.severity),
                        row.accepted_dt_min,
                        row.accepted_dt_max,
                        row.realized_cfl_max,
                        row.min_solver_area,
                        row.min_physical_area_cm2,
                        row.solver_volume_defect,
                        row.positivity_projection_count,
                        row.positivity_correction_total,
                        row.final_area_flux_balance,
                        row.final_rhs_area_max_abs,
                        row.final_rhs_flow_max_abs,
                        row.one_d_completed_time_s,
                        row.target_time_s,
                        row.cross_model_time_offset_s,
                    ]),
                    " ",
                ),
            )
        end
    end
    return path
end

function write_report_node_slab_sensitivity_csv(
    path::String,
    rows::Vector{NodeSlabSensitivityRow};
    overwrite::Bool = false,
)
    write_node_slab_sensitivity_csv(path, rows; overwrite=overwrite)
end

"""
    write_report_area_audit_dat(path, rows, base_params; overwrite=false)

Summarize section-area closure against the analytic reference stenosis profile
for each severity already represented in `rows`.
"""
function write_report_area_audit_dat(
    path::String,
    rows::Vector{SectionComparisonRow},
    base_params::Params;
    overwrite::Bool = false,
)
    cases = sort(collect(unique(row.severity for row in rows)))
    guarded_open_write(path, overwrite) do io
        headers = [
            "case",
            "sections",
            "eps_min_percent",
            "eps_median_percent",
            "eps_mean_percent",
            "eps_max_percent",
            "area3d_min_cm2",
            "area3d_max_cm2",
            "aref_min_cm2",
            "aref_max_cm2",
        ]
        println(io, join(headers, " "))
        for severity in cases
            case_rows = [
                row for row in rows if row.severity == severity && row.area_valid && isfinite(row.area_cm2)
            ]
            params = params_with(base_params; severity=severity)
            epsilons = Float64[]
            area_values = Float64[]
            reference_values = Float64[]
            for row in case_rows
                r0, _, _ = stenosis(row.z_cm, params)
                area_ref = pi * r0^2
                if isfinite(area_ref) && area_ref > 0.0
                    push!(epsilons, abs(row.area_cm2 - area_ref) / area_ref)
                    push!(area_values, row.area_cm2)
                    push!(reference_values, area_ref)
                end
            end
            values = Any[
                report_case_percent_tex(severity),
                length(epsilons),
                100.0 * minimum_or_nan(epsilons),
                100.0 * median_or_nan(epsilons),
                100.0 * mean_or_nan(epsilons),
                100.0 * maximum_or_nan(epsilons),
                minimum_or_nan(area_values),
                maximum_or_nan(area_values),
                minimum_or_nan(reference_values),
                maximum_or_nan(reference_values),
            ]
            println(io, join(report_fmt.(values), " "))
        end
    end
    return path
end
