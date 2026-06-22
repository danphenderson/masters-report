"""
    run_study(spec) -> StudyResult

Execute a severity or grid reduced 1D study. Independent cases run in parallel
when `parallel_workers` is greater than one.
"""
function run_study(spec::SeveritySweepSpec)
    validate_workflow_spec(spec)
    kind = workflow_kind(spec)
    rows = parallel_case_map(spec.severities; parallel_workers=spec.parallel_workers) do severity
        params = params_with(spec.base_params; severity=severity)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        summarize_study_run(kind, params, spec.backend, result)
    end

    path = default_output_paths(spec).summary_csv
    study = StudyResult(kind, rows, path)
    write_study_csv(path, study; overwrite=spec.overwrite)
    return study
end

function run_study(spec::GridConvergenceStudySpec)
    validate_workflow_spec(spec)
    kind = workflow_kind(spec)
    rows = parallel_case_map(spec.nxs; parallel_workers=spec.parallel_workers) do nx
        params = params_with(spec.base_params; nx=nx)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        summarize_study_run(kind, params, spec.backend, result)
    end

    path = default_output_paths(spec).summary_csv
    study = StudyResult(kind, rows, path)
    write_study_csv(path, study; overwrite=spec.overwrite)
    return study
end
