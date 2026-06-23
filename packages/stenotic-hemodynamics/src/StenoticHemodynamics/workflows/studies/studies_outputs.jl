function study_summary_path(spec::AbstractStudySpec)
    return isempty(spec.summary_csv) ? default_study_summary_path(spec) : spec.summary_csv
end

function default_study_summary_path(spec::SeveritySweepSpec)
    severity_token = join(map(path_token, spec.severities), "-")
    profile_token = velocity_profile_path_token(spec.base_params.velocity_profile)
    return joinpath(
        DEFAULT_SIMULATION_OUTPUT_ROOT,
        "studies",
        "stenotic_hemodynamics_severity_sweep_vp_$(profile_token)_s$(severity_token)_nx$(spec.base_params.nx)_t$(path_token(spec.base_params.tfinal)).csv",
    )
end

function default_study_summary_path(spec::GridConvergenceStudySpec)
    nx_token = join(spec.nxs, "-")
    profile_token = velocity_profile_path_token(spec.base_params.velocity_profile)
    return joinpath(
        DEFAULT_SIMULATION_OUTPUT_ROOT,
        "studies",
        "stenotic_hemodynamics_grid_convergence_vp_$(profile_token)_nx$(nx_token)_s$(path_token(spec.base_params.severity))_t$(path_token(spec.base_params.tfinal)).csv",
    )
end

"""
    write_study_csv(path, study; overwrite=false)

Write the compact reduced 1D study diagnostics CSV without changing the
single-run profile CSV format.
"""
function write_study_csv(path::String, study::StudyResult; overwrite::Bool = false)
    return write_csv_table(path, study_summary_header(), (study_summary_values(row) for row in study.summaries); overwrite=overwrite)
end

function write_study_csv(path::String, rows::Vector{StudyRunSummary}; overwrite::Bool = false)
    return write_study_csv(path, StudyResult("study", rows, path); overwrite=overwrite)
end

function study_summary_header()
    return [
        "study_kind",
        "severity",
        "nx",
        "dx",
        "backend",
        "algorithm",
        "model",
        "variable_radius_terms",
        "wall_law",
        "spatial_method",
        "time_stepper",
        "rheology",
        "velocity_profile",
        "alpha",
        "profile_exponent",
        "shear_rate_factor",
        "steps",
        "final_time",
        "velocity_min",
        "velocity_max",
        "pressure_min",
        "pressure_max",
        "min_area",
    ]
end

function study_summary_values(row::StudyRunSummary)
    return Any[
        row.study_kind,
        row.severity,
        row.nx,
        row.dx,
        row.backend,
        row.algorithm,
        row.model,
        row.variable_radius_terms,
        row.wall_law,
        row.spatial_method,
        row.time_stepper,
        row.rheology,
        row.velocity_profile,
        row.alpha,
        row.profile_exponent,
        row.shear_rate_factor,
        row.steps,
        row.final_time,
        row.velocity_min,
        row.velocity_max,
        row.pressure_min,
        row.pressure_max,
        row.min_area,
    ]
end
