function run_grid_sensitivity(spec::GridSensitivitySpec)
    validate_workflow_spec(spec)
    comparison_results = ComparisonResult[]
    summary_rows = GridSensitivitySummaryRow[]
    previous_runs_by_case = Dict{String,Any}()

    for nx in spec.nxs
        comparison_spec = ComparisonSpec(;
            cases=spec.cases,
            base_params=params_with(spec.base_params; nx=nx),
            backend=spec.backend,
            case_workers=spec.case_workers,
            solver_threads=spec.solver_threads,
            operator=spec.operator,
            output_dir=joinpath(spec.output_dir, "nx$(nx)"),
            section_count=spec.section_count,
            profile_slices=spec.profile_slices,
            radial_bins=spec.radial_bins,
            radial_bin_counts=spec.radial_bin_counts,
            radial_radius_modes=spec.radial_radius_modes,
            node_slab_half_widths=spec.node_slab_half_widths,
            coordinate_mode=spec.coordinate_mode,
            overwrite=spec.overwrite,
            progress_every=spec.progress_every,
            write_svg=spec.write_svg,
        )
        comparison_run = run_comparison_with_case_runs(comparison_spec)
        push!(comparison_results, comparison_run.result)

        for case_run in comparison_run.case_runs
            previous_run = get(previous_runs_by_case, case_run.case.case_label, nothing)
            push!(
                summary_rows,
                summarize_grid_sensitivity_case(
                    case_run,
                    comparison_run.result,
                    previous_run,
                ),
            )
            previous_runs_by_case[case_run.case.case_label] = case_run
        end
    end

    paths = default_output_paths(spec)
    result = GridSensitivityResult(spec, comparison_results, summary_rows, paths.summary_csv, paths.summary_tex)
    write_grid_sensitivity_outputs(result; overwrite=spec.overwrite)
    return result
end

function run_grid_sensitivity_from_summary_csv(
    source_summary_csv::String;
    base_params::Params = Params(tfinal=0.9995, initial_condition=GeometryRestIC()),
    output_dir::String = joinpath(DEFAULT_COMPARISON_OUTPUT_DIR, "grid_sensitivity"),
    nxs = DEFAULT_GRID_SENSITIVITY_NXS,
    summary_csv::String = "",
    summary_tex::String = "",
    overwrite::Bool = false,
)
    rows = read_grid_sensitivity_summary_csv(source_summary_csv)
    case_specs = grid_sensitivity_cases_from_summary_rows(rows)
    coordinate_mode = grid_sensitivity_coordinate_mode(rows, source_summary_csv)
    spec = GridSensitivitySpec(;
        cases=case_specs,
        base_params=base_params,
        output_dir=output_dir,
        nxs=nxs,
        coordinate_mode=coordinate_mode,
        summary_csv=summary_csv,
        summary_tex=summary_tex,
        overwrite=overwrite,
        write_svg=false,
    )
    selected_rows = validate_reused_grid_sensitivity_rows(rows, spec, source_summary_csv)
    result = GridSensitivityResult(spec, ComparisonResult[], selected_rows, spec.summary_csv, spec.summary_tex)
    write_grid_sensitivity_outputs(result; overwrite=spec.overwrite)
    return result
end

function grid_sensitivity_cases_from_summary_rows(rows::Vector{GridSensitivitySummaryRow})
    by_label = Dict{String,GridSensitivitySummaryRow}()
    for row in rows
        previous = get(by_label, row.case_label, nothing)
        if previous !== nothing && !isapprox(previous.severity, row.severity; atol=0.0, rtol=0.0)
            throw(ArgumentError("grid sensitivity summary has inconsistent severity for case '$(row.case_label)'"))
        end
        by_label[row.case_label] = row
    end
    return [
        Resolved3DCaseSpec(row.case_label, row.severity, ""; target_time=row.target_time_s)
        for row in sort(collect(values(by_label)); by=row -> (row.severity, row.case_label))
    ]
end

function grid_sensitivity_coordinate_mode(rows::Vector{GridSensitivitySummaryRow}, source_summary_csv::String)
    modes = sort(unique(row.coordinate_mode for row in rows))
    length(modes) == 1 ||
        throw(ArgumentError("grid sensitivity summary '$source_summary_csv' mixes coordinate modes: $(join(modes, ", "))"))
    mode = only(modes)
    mode in ("reference", "deformed") ||
        throw(ArgumentError("grid sensitivity summary '$source_summary_csv' has unsupported coordinate_mode '$mode'"))
    return mode
end

function validate_reused_grid_sensitivity_rows(
    rows::Vector{GridSensitivitySummaryRow},
    spec::GridSensitivitySpec,
    source_summary_csv::String,
)
    expected_nxs = spec.nxs
    observed_nxs = sort(unique(row.nx for row in rows))
    observed_nxs == expected_nxs ||
        throw(ArgumentError("grid sensitivity summary '$source_summary_csv' has nx values $(observed_nxs), expected $(expected_nxs)"))

    expected_cases = sort([case.case_label for case in spec.cases])
    observed_cases = sort(unique(row.case_label for row in rows))
    observed_cases == expected_cases ||
        throw(ArgumentError("grid sensitivity summary '$source_summary_csv' has cases $(observed_cases), expected $(expected_cases)"))

    observed_modes = sort(unique(row.coordinate_mode for row in rows))
    observed_modes == [spec.coordinate_mode] ||
        throw(ArgumentError("grid sensitivity summary '$source_summary_csv' has coordinate modes $(observed_modes), expected $(spec.coordinate_mode)"))

    selected_rows = GridSensitivitySummaryRow[]
    for nx in expected_nxs
        for case_label in expected_cases
            matches = [row for row in rows if row.nx == nx && row.case_label == case_label]
            length(matches) == 1 ||
                throw(ArgumentError("grid sensitivity summary '$source_summary_csv' must have exactly one row for case $case_label at nx=$nx"))
            push!(selected_rows, only(matches))
        end
    end
    return sort(selected_rows; by=row -> (row.severity, row.nx))
end

function summarize_grid_sensitivity_case(case_run, comparison_result::ComparisonResult, previous_run)
    section_rows = [
        row for row in case_run.section_rows if row.area_valid &&
        isfinite(row.flow_1d_cm3_s) &&
        isfinite(row.flow_3d_cm3_s) &&
        isfinite(row.mean_u1d_cm_s) &&
        isfinite(row.mean_u3d_cm_s)
    ]
    flow_diffs = [row.flow_1d_cm3_s - row.flow_3d_cm3_s for row in section_rows]
    velocity_diffs = [row.mean_u1d_cm_s - row.mean_u3d_cm_s for row in section_rows]
    velocity_refs = [row.mean_u3d_cm_s for row in section_rows]
    velocity_abs = abs.(velocity_diffs)
    max_index = isempty(velocity_abs) ? 0 : argmax(velocity_abs)
    adjacent = adjacent_velocity_difference_metrics(previous_run, case_run)
    summary_row = case_run.summary_row

    return GridSensitivitySummaryRow(
        case_run.case.case_label,
        case_run.case.severity,
        operator_name(comparison_result.spec.operator),
        summary_row.model,
        case_run.params.nx,
        case_run.params.dt,
        summary_row.initial_condition,
        summary_row.backend,
        summary_row.run_status,
        summary_row.coordinate_mode,
        case_run.case.target_time,
        length(case_run.section_rows),
        length(section_rows),
        mean_or_nan(flow_diffs),
        mean_or_nan(abs.(flow_diffs)),
        l2_mean_or_nan(flow_diffs),
        mean_or_nan(velocity_diffs),
        mean_or_nan(velocity_abs),
        l2_mean_or_nan(velocity_diffs),
        maximum_or_nan(velocity_abs),
        max_index == 0 ? NaN : section_rows[max_index].z_cm,
        relative_l2(velocity_diffs, velocity_refs),
        adjacent.from_nx,
        adjacent.mean_abs_velocity_difference_cm_s,
        adjacent.rms_velocity_difference_cm_s,
        adjacent.max_abs_velocity_difference_cm_s,
        adjacent.relative_rms_velocity_difference,
        summary_row.one_d_completed_time_s,
        summary_row.cross_model_time_offset_s,
        summary_row.runtime_elapsed_s,
        summary_row.case_worker_count,
        summary_row.solver_thread_count,
        summary_row.julia_thread_count,
        summary_row.process_id,
        comparison_result.summary_csv,
        section_csv_for_case(comparison_result, case_run.case),
    )
end

function adjacent_velocity_difference_metrics(previous_run, current_run)
    if previous_run === nothing
        return (
            from_nx=0,
            mean_abs_velocity_difference_cm_s=NaN,
            rms_velocity_difference_cm_s=NaN,
            max_abs_velocity_difference_cm_s=NaN,
            relative_rms_velocity_difference=NaN,
        )
    end

    previous_result = previous_run.simulation_result
    current_result = current_run.simulation_result
    previous_velocity = velocity(previous_result)
    current_velocity = velocity(current_result)
    diffs = Float64[]
    refs = Float64[]
    for (z, u_current) in zip(current_result.z, current_velocity)
        u_previous = interpolate_linear(previous_result.z, previous_velocity, z)
        push!(diffs, u_current - u_previous)
        push!(refs, u_current)
    end
    abs_diffs = abs.(diffs)
    return (
        from_nx=previous_run.params.nx,
        mean_abs_velocity_difference_cm_s=mean_or_nan(abs_diffs),
        rms_velocity_difference_cm_s=l2_mean_or_nan(diffs),
        max_abs_velocity_difference_cm_s=maximum_or_nan(abs_diffs),
        relative_rms_velocity_difference=relative_l2(diffs, refs),
    )
end

function section_csv_for_case(result::ComparisonResult, case::Resolved3DCaseSpec)
    for (candidate, path) in zip(result.spec.cases, result.section_csvs)
        candidate.case_label == case.case_label && return path
    end
    return ""
end
