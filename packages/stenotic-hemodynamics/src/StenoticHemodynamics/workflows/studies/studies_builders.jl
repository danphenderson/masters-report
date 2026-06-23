function severity_sweep_spec_from_values(values::Dict{String,String}, flags::Set{String})
    params, backend, progress_every = params_backend_progress(values, flags)
    return SeveritySweepSpec(;
        base_params=params,
        severities=parse_float_list(get(values, "severities", "23,50")),
        backend=backend,
        summary_csv=get(values, "summary-csv", ""),
        overwrite=("overwrite" in flags),
        progress_every=progress_every,
        parallel_workers=parse(Int, get(values, "parallel-workers", string(default_case_workers()))),
    )
end

function grid_convergence_study_spec_from_values(values::Dict{String,String}, flags::Set{String})
    params, backend, progress_every = params_backend_progress(values, flags)
    return GridConvergenceStudySpec(;
        base_params=params,
        nxs=parse_int_list(get(values, "nxs", "40,80")),
        backend=backend,
        summary_csv=get(values, "summary-csv", ""),
        overwrite=("overwrite" in flags),
        progress_every=progress_every,
        parallel_workers=parse(Int, get(values, "parallel-workers", string(default_case_workers()))),
    )
end
