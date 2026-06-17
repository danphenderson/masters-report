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
    return result
end

function guarded_open_write(writer, path::String, overwrite::Bool)
    ensure_parent(path)
    if isfile(path) && !overwrite
        throw(ArgumentError("refusing to overwrite existing file '$path'; pass overwrite=true to allow replacement"))
    end
    open(path, "w") do io
        writer(io)
    end
    return path
end

function write_section_comparison_csv(
    path::String,
    rows::Vector{SectionComparisonRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, section_comparison_header())
        for row in rows
            println(io, section_comparison_csv_row(row))
        end
    end
end

function section_comparison_header()
    return join((
        "case_label",
        "severity",
        "z_cm",
        "u1d_cm_s",
        "u3d_cm_s",
        "abs_error_cm_s",
        "rel_error",
        "node_count",
        "observed_radius_cm",
        "xdmf_time_s",
        "time_error_s",
    ), ",")
end

function section_comparison_csv_row(row::SectionComparisonRow)
    return join((
        row.case_label,
        row.severity,
        row.z_cm,
        row.u1d_cm_s,
        row.u3d_cm_s,
        row.abs_error_cm_s,
        row.rel_error,
        row.node_count,
        row.observed_radius_cm,
        row.xdmf_time_s,
        row.time_error_s,
    ), ",")
end

function write_radial_profile_csv(
    path::String,
    rows::Vector{RadialProfileRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, radial_profile_header())
        for row in rows
            println(io, radial_profile_csv_row(row))
        end
    end
end

function radial_profile_header()
    return join((
        "case_label",
        "severity",
        "z_slice_cm",
        "radial_bin",
        "r_over_r0_mid",
        "u1d_cm_s",
        "u3d_cm_s",
        "abs_error_cm_s",
        "rel_error",
        "node_count",
        "xdmf_time_s",
        "time_error_s",
    ), ",")
end

function radial_profile_csv_row(row::RadialProfileRow)
    return join((
        row.case_label,
        row.severity,
        row.z_slice_cm,
        row.radial_bin,
        row.r_over_r0_mid,
        row.u1d_cm_s,
        row.u3d_cm_s,
        row.abs_error_cm_s,
        row.rel_error,
        row.node_count,
        row.xdmf_time_s,
        row.time_error_s,
    ), ",")
end

function write_comparison_summary_csv(
    path::String,
    rows::Vector{ComparisonSummaryRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, comparison_summary_header())
        for row in rows
            println(io, comparison_summary_csv_row(row))
        end
    end
end

function comparison_summary_header()
    return join((
        "case_label",
        "severity",
        "section_count",
        "profile_count",
        "mean_abs_error_cm_s",
        "max_abs_error_cm_s",
        "mean_rel_error",
        "max_rel_error",
        "profile_mean_abs_error_cm_s",
        "profile_max_abs_error_cm_s",
        "min_section_nodes",
        "xdmf_time_s",
        "time_error_s",
    ), ",")
end

function comparison_summary_csv_row(row::ComparisonSummaryRow)
    return join((
        row.case_label,
        row.severity,
        row.section_count,
        row.profile_count,
        row.mean_abs_error_cm_s,
        row.max_abs_error_cm_s,
        row.mean_rel_error,
        row.max_rel_error,
        row.profile_mean_abs_error_cm_s,
        row.profile_max_abs_error_cm_s,
        row.min_section_nodes,
        row.xdmf_time_s,
        row.time_error_s,
    ), ",")
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
        finite_u = finite_values(Iterators.flatten((row.u1d_cm_s, row.u3d_cm_s) for row in rows))
        finite_e = finite_values(row.abs_error_cm_s for row in rows)
        z_values = finite_values(row.z_cm for row in rows)
        xmin = isempty(z_values) ? 0.0 : minimum(z_values)
        xmax = isempty(z_values) ? 1.0 : maximum(z_values)
        umin, umax = padded_limits(finite_u)
        emin, emax = padded_limits(finite_e; lower_zero=true)

        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">""")
        println(io, """<rect width="100%" height="100%" fill="white"/>""")
        println(io, """<text x="$margin" y="32" font-family="Arial" font-size="18" fill="#111">Resolved 3D vs 1D section mean velocity</text>""")
        svg_panel_axes(io, margin, 58, width - margin, mid - 28, "mean axial velocity (cm/s)", xmin, xmax, umin, umax)
        svg_panel_axes(io, margin, mid + 26, width - margin, height - margin, "absolute error (cm/s)", xmin, xmax, emin, emax)

        for (case_index, case_label) in enumerate(cases)
            color = colors[mod1(case_index, length(colors))]
            case_rows = [row for row in rows if row.case_label == case_label]
            svg_polyline(io, case_rows, xmin, xmax, umin, umax, margin, 58, width - margin, mid - 28, color, row -> row.u3d_cm_s)
            svg_polyline(io, case_rows, xmin, xmax, umin, umax, margin, 58, width - margin, mid - 28, color, row -> row.u1d_cm_s; dash=true)
            svg_polyline(io, case_rows, xmin, xmax, emin, emax, margin, mid + 26, width - margin, height - margin, color, row -> row.abs_error_cm_s)
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
