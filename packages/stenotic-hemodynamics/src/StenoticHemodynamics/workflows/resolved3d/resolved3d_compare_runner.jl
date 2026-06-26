function run_comparison(spec::ComparisonSpec)
    return run_comparison_with_case_runs(spec).result
end

function run_comparison_with_case_runs(spec::ComparisonSpec)
    validate_workflow_spec(spec)
    paths = default_output_paths(spec)
    section_rows = SectionComparisonRow[]
    profile_rows = RadialProfileRow[]
    sensitivity_rows = NodeSlabSensitivityRow[]
    summary_rows = ComparisonSummaryRow[]
    loaded_cases = [load_comparison_case_inputs(case, spec) for case in spec.cases]
    case_runs = if spec.solver_threads > 1 || spec.case_workers != 1
        parallel_case_map(
            loaded -> run_loaded_comparison_case(loaded.case, loaded.bundle, loaded.field, spec),
            loaded_cases;
            parallel_workers=spec.case_workers,
            threads_per_worker=spec.solver_threads,
            force_process=spec.solver_threads > 1,
        )
    else
        runs = Vector{Any}(undef, length(loaded_cases))
        Threads.@threads for index in eachindex(loaded_cases)
            loaded = loaded_cases[index]
            runs[index] = run_loaded_comparison_case(loaded.case, loaded.bundle, loaded.field, spec)
        end
        runs
    end

    for case_run in case_runs
        append!(section_rows, case_run.section_rows)
        append!(profile_rows, case_run.profile_rows)
        append!(sensitivity_rows, case_run.sensitivity_rows)
        push!(summary_rows, case_run.summary_row)
    end

    result = ComparisonResult(
        spec,
        section_rows,
        profile_rows,
        sensitivity_rows,
        summary_rows,
        paths.section_csvs,
        paths.profile_csvs,
        paths.sensitivity_csv,
        paths.summary_csv,
        String[],
    )
    write_comparison_csvs(result; overwrite=spec.overwrite)

    svg_paths = String[]
    if spec.write_svg
        path = paths.overlay_svg
        write_section_comparison_svg(path, section_rows; overwrite=spec.overwrite)
        push!(svg_paths, path)
    end

    final_result = ComparisonResult(
        spec,
        section_rows,
        profile_rows,
        sensitivity_rows,
        summary_rows,
        result.section_csvs,
        result.profile_csvs,
        result.sensitivity_csv,
        result.summary_csv,
        svg_paths,
    )
    return (result=final_result, case_runs=case_runs)
end

function run_comparison_case(case::Resolved3DCaseSpec, spec::ComparisonSpec)
    loaded = load_comparison_case_inputs(case, spec)
    return run_loaded_comparison_case(loaded.case, loaded.bundle, loaded.field, spec)
end

function load_comparison_case_inputs(case::Resolved3DCaseSpec, spec::ComparisonSpec)
    bundle = load_resolved3d_field_bundle(case; require_displacement=(spec.coordinate_mode == "deformed"))
    field = resolved3d_velocity_field_from_bundle(bundle, spec.coordinate_mode)
    return (case=case, bundle=bundle, field=field)
end

function run_loaded_comparison_case(case::Resolved3DCaseSpec, bundle, field, spec::ComparisonSpec)
    params = params_with(spec.base_params; severity=case.severity, tfinal=case.target_time)
    start_ns = time_ns()
    result = simulate(params, spec.backend; progress_every=spec.progress_every)
    elapsed_s = (time_ns() - start_ns) / 1.0e9

    section_rows = compare_section_means(field, result, params, spec)
    profile_rows = compare_radial_profiles(field, result, params, spec)
    sensitivity_rows = compare_node_slab_sensitivity(field, result, params, spec)
    diagnostics = characteristic_diagnostics(result, params)
    production_diagnostics = comparison_production_diagnostics(result, params)
    summary_row = summarize_comparison(
        case,
        field.metadata,
        params,
        spec.backend,
        section_rows,
        profile_rows,
        diagnostics,
        production_diagnostics,
        result.completed_time,
        (
            elapsed_s=elapsed_s,
            case_workers=spec.case_workers,
            solver_threads=spec.solver_threads,
            julia_threads=Threads.nthreads(),
            process_id=Distributed.myid(),
        ),
    )
    return (
        case=case,
        field=field,
        field_bundle=bundle,
        params=params,
        simulation_result=result,
        section_rows=section_rows,
        profile_rows=profile_rows,
        sensitivity_rows=sensitivity_rows,
        summary_row=summary_row,
    )
end
