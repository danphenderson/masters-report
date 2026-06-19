function section_csv_paths(spec::ComparisonSpec)
    return [section_csv_path(spec, case) for case in spec.cases]
end

function profile_csv_paths(spec::ComparisonSpec)
    return [profile_csv_path(spec, case) for case in spec.cases]
end

function section_csv_path(spec::ComparisonSpec, case::Resolved3DCaseSpec)
    return joinpath(spec.output_dir, "section_mean_$(comparison_case_token(case)).csv")
end

function profile_csv_path(spec::ComparisonSpec, case::Resolved3DCaseSpec)
    return joinpath(spec.output_dir, "radial_profile_$(comparison_case_token(case)).csv")
end

function comparison_summary_path(spec::ComparisonSpec)
    return joinpath(spec.output_dir, "comparison_summary.csv")
end

function sensitivity_csv_path(spec::ComparisonSpec)
    return joinpath(spec.output_dir, "node_slab_sensitivity.csv")
end

function comparison_case_token(case::Resolved3DCaseSpec)
    return "case$(case.case_label)_sev$(round(Int, case.severity))"
end

function write_comparison_csvs(result::ComparisonResult; overwrite::Bool = false)
    mkpath(result.spec.output_dir)

    for (case, path) in zip(result.spec.cases, result.section_csvs)
        rows = [row for row in result.section_rows if row.case_label == case.case_label]
        write_section_comparison_csv(path, rows; overwrite=overwrite)
    end

    for (case, path) in zip(result.spec.cases, result.profile_csvs)
        rows = [row for row in result.profile_rows if row.case_label == case.case_label]
        write_radial_profile_csv(path, rows; overwrite=overwrite)
    end

    write_comparison_summary_csv(result.summary_csv, result.summary_rows; overwrite=overwrite)
    write_node_slab_sensitivity_csv(result.sensitivity_csv, result.sensitivity_rows; overwrite=overwrite)
    return result
end

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
        "run_status",
        "z_cm",
        "area_cm2",
        "flow_3d_cm3_s",
        "flow_1d_cm3_s",
        "mean_u3d_cm_s",
        "mean_u1d_cm_s",
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
        row.run_status,
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
        "z_slice_cm",
        "radial_bin",
        "r_over_radius_mid",
        "area_cm2",
        "flow_3d_cm3_s",
        "mean_u3d_cm_s",
        "mean_u1d_cm_s",
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

function write_comparison_summary_csv(
    path::String,
    rows::Vector{ComparisonSummaryRow};
    overwrite::Bool = false,
)
    write_csv_table(path, comparison_summary_header(), (comparison_summary_values(row) for row in rows); overwrite=overwrite)
end

function comparison_summary_header()
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
        "section_count",
        "profile_count",
        "mean_abs_discrepancy_cm_s",
        "l2_velocity_discrepancy_cm_s",
        "max_abs_discrepancy_cm_s",
        "mean_relative_discrepancy",
        "relative_l1_velocity_discrepancy",
        "max_relative_discrepancy",
        "relative_l2_velocity_discrepancy",
        "mean_flow_abs_discrepancy_cm3_s",
        "flow_l2_discrepancy_cm3_s",
        "max_flow_abs_discrepancy_cm3_s",
        "profile_mean_abs_discrepancy_cm_s",
        "profile_l2_discrepancy_cm_s",
        "profile_max_abs_discrepancy_cm_s",
        "min_intersection_count",
        "min_section_nodes",
        "area_valid_count",
        "alpha_eff_min",
        "alpha_eff_max",
        "characteristic_radicand_min",
        "lambda_minus_min",
        "lambda_minus_max",
        "lambda_plus_min",
        "lambda_plus_max",
        "subcritical_margin_min",
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

function comparison_summary_values(row::ComparisonSummaryRow)
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
        row.section_count,
        row.profile_count,
        row.mean_abs_error_cm_s,
        row.l2_velocity_error_cm_s,
        row.max_abs_error_cm_s,
        row.mean_rel_error,
        row.relative_l1_velocity_error,
        row.max_rel_error,
        row.rel_l2_velocity_error,
        row.mean_flow_abs_error_cm3_s,
        row.flow_l2_error_cm3_s,
        row.max_flow_abs_error_cm3_s,
        row.profile_mean_abs_error_cm_s,
        row.profile_l2_error_cm_s,
        row.profile_max_abs_error_cm_s,
        row.min_intersection_count,
        row.min_section_nodes,
        row.area_valid_count,
        row.alpha_eff_min,
        row.alpha_eff_max,
        row.characteristic_radicand_min,
        row.lambda_minus_min,
        row.lambda_minus_max,
        row.lambda_plus_min,
        row.lambda_plus_max,
        row.subcritical_margin_min,
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
        "run_status",
        "half_width_cm",
        "z_cm",
        "mean_u3d_cm_s",
        "mean_u1d_cm_s",
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
        row.run_status,
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

function write_section_comparison_svg(
    path::String,
    rows::Vector{SectionComparisonRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        width = 920
        height = 560
        margin = 58
        mid = 285
        colors = ("#a51f2d", "#1d5f8f", "#2d7a36", "#6f4a8e")
        cases = unique(row.case_label for row in rows)
        finite_u = finite_values(Iterators.flatten((row.mean_u1d_cm_s, row.mean_u3d_cm_s) for row in rows))
        finite_e = finite_values(row.abs_velocity_error_cm_s for row in rows)
        z_values = finite_values(row.z_cm for row in rows)
        xmin = isempty(z_values) ? 0.0 : minimum(z_values)
        xmax = isempty(z_values) ? 1.0 : maximum(z_values)
        umin, umax = padded_limits(finite_u)
        emin, emax = padded_limits(finite_e; lower_zero=true)

        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">""")
        println(io, """<rect width="100%" height="100%" fill="white"/>""")
        println(io, """<text x="$margin" y="32" font-family="Arial" font-size="18" fill="#111">Resolved 3D vs 1D quadrature mean velocity</text>""")
        svg_panel_axes(io, margin, 58, width - margin, mid - 28, "mean axial velocity (cm/s)", xmin, xmax, umin, umax)
        svg_panel_axes(io, margin, mid + 26, width - margin, height - margin, "absolute discrepancy (cm/s)", xmin, xmax, emin, emax)

        for (case_index, case_label) in enumerate(cases)
            color = colors[mod1(case_index, length(colors))]
            case_rows = [row for row in rows if row.case_label == case_label]
            svg_polyline(io, case_rows, xmin, xmax, umin, umax, margin, 58, width - margin, mid - 28, color, row -> row.mean_u3d_cm_s)
            svg_polyline(io, case_rows, xmin, xmax, umin, umax, margin, 58, width - margin, mid - 28, color, row -> row.mean_u1d_cm_s; dash=true)
            svg_polyline(io, case_rows, xmin, xmax, emin, emax, margin, mid + 26, width - margin, height - margin, color, row -> row.abs_velocity_error_cm_s)
            println(io, """<text x="$(margin + 12 + 110 * (case_index - 1))" y="54" font-family="Arial" font-size="12" fill="$color">case $case_label solid=3D dashed=1D</text>""")
        end

        println(io, "</svg>")
    end
end

function padded_limits(values::Vector{Float64}; lower_zero::Bool = false)
    isempty(values) && return (0.0, 1.0)
    ymin = lower_zero ? 0.0 : minimum(values)
    ymax = maximum(values)
    pad = 0.08 * max(ymax - ymin, 1.0e-9)
    return ymin - (lower_zero ? 0.0 : pad), ymax + pad
end

function svg_panel_axes(io, xleft, ytop, xright, ybot, title, xmin, xmax, ymin, ymax)
    println(io, """<line x1="$xleft" y1="$ybot" x2="$xright" y2="$ybot" stroke="#333" stroke-width="1"/>""")
    println(io, """<line x1="$xleft" y1="$ytop" x2="$xleft" y2="$ybot" stroke="#333" stroke-width="1"/>""")
    println(io, """<text x="$xleft" y="$(ytop - 12)" font-family="Arial" font-size="14" fill="#111">$title</text>""")
    println(io, """<text x="$(xright - 40)" y="$(ybot + 28)" font-family="Arial" font-size="12" fill="#333">z (cm)</text>""")
    println(io, """<text x="$(xleft + 4)" y="$(ytop + 14)" font-family="Arial" font-size="11" fill="#555">$(round(ymax, sigdigits=4))</text>""")
    println(io, """<text x="$(xleft + 4)" y="$(ybot - 4)" font-family="Arial" font-size="11" fill="#555">$(round(ymin, sigdigits=4))</text>""")
    println(io, """<text x="$xleft" y="$(ybot + 28)" font-family="Arial" font-size="11" fill="#555">$(round(xmin, sigdigits=4))</text>""")
    println(io, """<text x="$(xright - 88)" y="$(ybot + 28)" font-family="Arial" font-size="11" fill="#555">$(round(xmax, sigdigits=4))</text>""")
end

function svg_polyline(
    io,
    rows::Vector{SectionComparisonRow},
    xmin,
    xmax,
    ymin,
    ymax,
    xleft,
    ytop,
    xright,
    ybot,
    color,
    value_fn;
    dash::Bool = false,
)
    points = String[]
    for row in rows
        y = Float64(value_fn(row))
        if isfinite(row.z_cm) && isfinite(y)
            sx = xleft + (row.z_cm - xmin) / max(xmax - xmin, eps()) * (xright - xleft)
            sy = ybot - (y - ymin) / max(ymax - ymin, eps()) * (ybot - ytop)
            push!(points, string(round(sx, digits=2), ",", round(sy, digits=2)))
        end
    end

    isempty(points) && return nothing
    dash_attr = dash ? " stroke-dasharray=\"7 5\"" : ""
    println(io, """<polyline points="$(join(points, " "))" fill="none" stroke="$color" stroke-width="2"$dash_attr/>""")
    return nothing
end

function publish_resolved3d_report_assets(
    result::ComparisonResult;
    output_dir::String = joinpath("figures", "static", "static", "data", "stenosis-comparison"),
    overwrite::Bool = false,
)
    mkpath(output_dir)
    paths = String[]
    push!(
        paths,
        write_report_section_dat(
            joinpath(output_dir, "section-quadrature.dat"),
            result.section_rows;
            overwrite=overwrite,
        ),
    )
    append!(
        paths,
        write_report_radial_dat_files(
            output_dir,
            result.profile_rows;
            overwrite=overwrite,
        ),
    )
    push!(
        paths,
        write_report_node_slab_sensitivity_csv(
            joinpath(output_dir, "node-slab-sensitivity.csv"),
            result.sensitivity_rows;
            overwrite=overwrite,
        ),
    )
    push!(
        paths,
        write_report_area_audit_dat(
            joinpath(output_dir, "area-audit.dat"),
            result.section_rows,
            result.spec.base_params;
            overwrite=overwrite,
        ),
    )
    return paths
end

function report_case_token(severity::Real)
    return "C$(round(Int, severity))"
end

function report_slice_token(z::Real)
    return replace(string(round(Float64(z); digits=3)), "." => "p", "-" => "m")
end

function report_fmt(value)
    value isa Bool && return value ? "true" : "false"
    value isa Integer && return string(value)
    value isa Real || return string(value)
    number = Float64(value)
    isfinite(number) || return "nan"
    return string(round(number; sigdigits=12))
end

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
end

function write_report_radial_dat_files(output_dir::String, rows::Vector{RadialProfileRow}; overwrite::Bool = false)
    paths = String[]
    primary_rows = principal_radial_profile_rows(rows)
    cases = sort(collect(unique(row.severity for row in primary_rows)))
    for severity in cases
        case_rows = [row for row in primary_rows if row.severity == severity]
        path = joinpath(output_dir, "radial-quadrature-$(report_case_token(severity)).dat")
        slices = sort(collect(unique(row.z_slice_cm for row in case_rows)))
        bins = sort(collect(unique(row.radial_bin for row in case_rows)))
        rows_by_slice_bin = Dict((row.z_slice_cm, row.radial_bin) => row for row in case_rows)
        guarded_open_write(path, overwrite) do io
            headers = ["r"]
            for z in slices
                token = report_slice_token(z)
                append!(headers, ["u1d$(token)", "u3d$(token)", "area$(token)", "disc$(token)"])
            end
            println(io, join(headers, " "))
            for bin in bins
                first_row = rows_by_slice_bin[(slices[begin], bin)]
                values = Any[first_row.r_over_r0_mid]
                for z in slices
                    row = rows_by_slice_bin[(z, bin)]
                    append!(values, [row.mean_u1d_cm_s, row.mean_u3d_cm_s, row.area_cm2, row.abs_velocity_error_cm_s])
                end
                println(io, join(report_fmt.(values), " "))
            end
        end
        push!(paths, path)
    end
    return paths
end

function principal_radial_profile_rows(rows::Vector{RadialProfileRow})
    current_rows = [row for row in rows if row.radius_mode == "current"]
    isempty(current_rows) && return rows
    preferred_count = 20
    preferred = [row for row in current_rows if row.radial_bin_count == preferred_count]
    !isempty(preferred) && return preferred
    counts = sort(collect(unique(row.radial_bin_count for row in current_rows)))
    isempty(counts) && return current_rows
    fallback_count = counts[clamp(searchsortedfirst(counts, preferred_count), 1, length(counts))]
    return [row for row in current_rows if row.radial_bin_count == fallback_count]
end

function write_report_node_slab_sensitivity_csv(
    path::String,
    rows::Vector{NodeSlabSensitivityRow};
    overwrite::Bool = false,
)
    write_node_slab_sensitivity_csv(path, rows; overwrite=overwrite)
end

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
                report_case_token(severity),
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
end

minimum_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : minimum(values)
median_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : median(values)
