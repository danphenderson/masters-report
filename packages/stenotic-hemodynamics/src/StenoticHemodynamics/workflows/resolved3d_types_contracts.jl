default_resolved3d_data_root() = DEFAULT_RESOLVED3D_DATA_ROOT

function default_resolved3d_cases(
    data_root::String = default_resolved3d_data_root();
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
)
    return Resolved3DCaseSpec[
        Resolved3DCaseSpec("77", 23.0, joinpath(data_root, "77", "velocity.xdmf"); target_time, time_atol),
        Resolved3DCaseSpec("60", 40.0, joinpath(data_root, "60", "velocity.xdmf"); target_time, time_atol),
    ]
end

"""
    available_resolved3d_cases(...)

Return the subset of default resolved-3D cases whose velocity XDMF metadata is
present locally. This is intentionally a filesystem contract only; it does not
load XDMF or HDF5 content.
"""
function available_resolved3d_cases(
    data_root::String = default_resolved3d_data_root();
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
)
    cases = [
        case for case in default_resolved3d_cases(data_root; target_time, time_atol) if isfile(case.velocity_xdmf)
    ]
    if isempty(cases)
        @telemetry_info "skipping resolved 3D comparison because no case XDMF files were found" event="resolved3d_skipped" stage="resolved3d" backend="resolved3d" method="" nx="" tfinal="" status="skipped" rows=0 reason="missing_xdmf" data_root expected_layout=[
            joinpath(data_root, "77", "velocity.xdmf"),
            joinpath(data_root, "60", "velocity.xdmf"),
        ]
    end
    return cases
end

function resolved3d_common_cli_values(values::Dict{String,String}, flags::Set{String})
    params, backend, progress_every = params_backend_progress(values, flags)
    return (
        data_root=get(values, "data-root", default_resolved3d_data_root()),
        target_time=parse(Float64, get(values, "target-time", "0.9995")),
        time_atol=parse(Float64, get(values, "time-atol", "1.0e-3")),
        base_params=params,
        backend=backend,
        section_count=parse(Int, get(values, "section-count", "200")),
        profile_slices=haskey(values, "profile-slices") ? parse_float_list(values["profile-slices"]) : nothing,
        radial_bins=parse(Int, get(values, "radial-bins", "20")),
        radial_bin_counts=haskey(values, "radial-bin-counts") ? parse_int_list(values["radial-bin-counts"]) : nothing,
        radial_radius_modes=haskey(values, "radial-radius-modes") ? split(values["radial-radius-modes"], ",") : nothing,
        node_slab_half_widths=haskey(values, "node-slab-half-widths") ? parse_float_list(values["node-slab-half-widths"]) : nothing,
        coordinate_mode=get(values, "coordinate-mode", "reference"),
        overwrite=("overwrite" in flags),
        progress_every=progress_every,
        write_svg=!("no-svg" in flags),
    )
end

"""
    compare3d_command_plan_from_values(values, flags)

Translate CLI-style value dictionaries into a comparison or grid-sensitivity
execution plan without touching any resolved-3D input files.
"""
function compare3d_command_plan_from_values(values::Dict{String,String}, flags::Set{String})
    common = resolved3d_common_cli_values(values, flags)
    publish_report_assets = "publish-report-assets" in flags
    report_assets_dir = get(values, "report-assets-dir", joinpath("report", "assets", "data", "stenosis-comparison"))

    if haskey(values, "nxs")
        output_dir = get(values, "output-dir", joinpath(DEFAULT_COMPARISON_OUTPUT_DIR, "grid_sensitivity"))
        nxs = parse_int_list(values["nxs"])
        summary_csv = get(values, "grid-summary-csv", "")
        summary_tex = get(values, "grid-summary-tex", "")
        if haskey(values, "reuse-grid-summary")
            return (
                mode=:reuse_grid_sensitivity,
                source_summary_csv=values["reuse-grid-summary"],
                run_kwargs=(
                    ;
                    base_params=common.base_params,
                    output_dir=output_dir,
                    nxs=nxs,
                    summary_csv=summary_csv,
                    summary_tex=summary_tex,
                    overwrite=common.overwrite,
                ),
                publish_report_assets=publish_report_assets,
                report_assets_dir=report_assets_dir,
            )
        end

        return (
            mode=:grid_sensitivity,
            run_kwargs=(
                ;
                data_root=common.data_root,
                target_time=common.target_time,
                time_atol=common.time_atol,
                base_params=common.base_params,
                backend=common.backend,
                output_dir=output_dir,
                nxs=nxs,
                section_count=common.section_count,
                profile_slices=common.profile_slices,
                radial_bins=common.radial_bins,
                radial_bin_counts=common.radial_bin_counts,
                radial_radius_modes=common.radial_radius_modes,
                node_slab_half_widths=common.node_slab_half_widths,
                coordinate_mode=common.coordinate_mode,
                overwrite=common.overwrite,
                progress_every=common.progress_every,
                write_svg=common.write_svg,
                summary_csv=summary_csv,
                summary_tex=summary_tex,
            ),
            publish_report_assets=publish_report_assets,
            report_assets_dir=report_assets_dir,
        )
    end

    return (
        mode=:comparison,
        run_kwargs=(
            ;
            data_root=common.data_root,
            target_time=common.target_time,
            time_atol=common.time_atol,
            base_params=common.base_params,
            backend=common.backend,
            output_dir=get(values, "output-dir", DEFAULT_COMPARISON_OUTPUT_DIR),
            section_count=common.section_count,
            profile_slices=common.profile_slices,
            radial_bins=common.radial_bins,
            radial_bin_counts=common.radial_bin_counts,
            radial_radius_modes=common.radial_radius_modes,
            node_slab_half_widths=common.node_slab_half_widths,
            coordinate_mode=common.coordinate_mode,
            overwrite=common.overwrite,
            progress_every=common.progress_every,
            write_svg=common.write_svg,
        ),
        publish_report_assets=publish_report_assets,
        report_assets_dir=report_assets_dir,
    )
end

function run_available_resolved3d_comparison(;
    data_root::String = default_resolved3d_data_root(),
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
    kwargs...,
)
    cases = available_resolved3d_cases(data_root; target_time, time_atol)
    isempty(cases) && return nothing
    return run_comparison(ComparisonSpec(; cases=cases, kwargs...))
end

function run_available_resolved3d_grid_sensitivity(;
    data_root::String = default_resolved3d_data_root(),
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
    kwargs...,
)
    cases = available_resolved3d_cases(data_root; target_time, time_atol)
    isempty(cases) && return nothing
    return run_grid_sensitivity(GridSensitivitySpec(; cases=cases, kwargs...))
end
