"""
    publish_resolved3d_report_assets(result; output_dir=..., overwrite=false)

Materialize the report-facing resolved-3D comparison assets for `result` and
return the written paths. Reference-coordinate runs additionally publish the
legacy compatibility filenames without the `-reference` suffix.
"""
function publish_resolved3d_report_assets(
    result::ComparisonResult;
    output_dir::String = joinpath("report", "assets", "data", "stenosis-comparison"),
    overwrite::Bool = false,
)
    mkpath(output_dir)
    mode = report_coordinate_mode(result)
    paths = String[]
    push!(
        paths,
        write_report_section_dat(
            joinpath(output_dir, "section-quadrature-$(mode).dat"),
            result.section_rows;
            overwrite=overwrite,
        ),
    )
    append!(
        paths,
        write_report_radial_profile_assets(
            output_dir,
            result.profile_rows;
            section_rows=result.section_rows,
            summary_rows=result.summary_rows,
            coordinate_mode=mode,
            overwrite=overwrite,
        ),
    )
    push!(
        paths,
        write_report_node_slab_sensitivity_csv(
            joinpath(output_dir, "node-slab-sensitivity-$(mode).csv"),
            result.sensitivity_rows;
            overwrite=overwrite,
        ),
    )
    push!(
        paths,
        write_report_area_audit_dat(
            joinpath(output_dir, "area-audit-$(mode).dat"),
            result.section_rows,
            result.spec.base_params;
            overwrite=overwrite,
        ),
    )
    push!(
        paths,
        write_report_production_diagnostics_dat(
            joinpath(output_dir, "production-diagnostics-$(mode).dat"),
            result.summary_rows;
            overwrite=overwrite,
        ),
    )
    if mode == "reference"
        push!(
            paths,
            write_report_section_dat(
                joinpath(output_dir, "section-quadrature.dat"),
                result.section_rows;
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
        push!(
            paths,
            write_report_production_diagnostics_dat(
                joinpath(output_dir, "production-diagnostics.dat"),
                result.summary_rows;
                overwrite=overwrite,
            ),
        )
    end
    return paths
end

"""
    publish_resolved3d_grid_sensitivity_assets(result; output_dir=..., overwrite=false)

Write the report-facing grid-sensitivity summary CSV and TeX table and return
their paths.
"""
function publish_resolved3d_grid_sensitivity_assets(
    result::GridSensitivityResult;
    output_dir::String = joinpath("report", "assets", "data", "stenosis-comparison"),
    overwrite::Bool = false,
)
    mkpath(output_dir)
    paths = String[]
    push!(
        paths,
        write_grid_sensitivity_summary_csv(
            joinpath(output_dir, "grid-sensitivity-summary.csv"),
            result.summary_rows;
            overwrite=overwrite,
        ),
    )
    push!(
        paths,
        write_grid_sensitivity_summary_tex(
            joinpath(output_dir, "grid-sensitivity-summary.tex"),
            result.summary_rows;
            overwrite=overwrite,
        ),
    )
    return paths
end
