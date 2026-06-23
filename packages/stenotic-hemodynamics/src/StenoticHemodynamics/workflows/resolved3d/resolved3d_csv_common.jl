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

"""
    write_comparison_csvs(result; overwrite=false)

Write the CSV tables referenced by one resolved-3D comparison result. The
inputs are already package-native comparison rows derived from imported
resolved-3D cases.
"""
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
