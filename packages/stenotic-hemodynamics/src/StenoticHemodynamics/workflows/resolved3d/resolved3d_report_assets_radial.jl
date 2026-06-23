"""
    write_report_radial_dat_files(output_dir, rows; overwrite=false)

Write legacy radial `.dat` files for the promoted radial-profile rows, grouped
only by severity. This helper preserves the historical filename contract used by
older report consumers.
"""
function write_report_radial_dat_files(output_dir::String, rows::Vector{RadialProfileRow}; overwrite::Bool = false)
    paths = String[]
    primary_rows = principal_radial_profile_rows(rows)
    cases = sort(collect(unique(row.severity for row in primary_rows)))
    for severity in cases
        case_rows = [row for row in primary_rows if row.severity == severity]
        path = joinpath(output_dir, "radial-quadrature-$(report_case_token(severity)).dat")
        push!(paths, write_report_radial_dat_file(path, case_rows; overwrite=overwrite))
    end
    return paths
end

"""
    write_report_radial_profile_assets(output_dir, rows; section_rows, summary_rows, coordinate_mode, overwrite=false)

Write the radial-profile audit CSV plus per-case radial `.dat` assets for the
requested coordinate mode. Per-case `.dat` files are emitted only for severities
whose audit status is `ok`.
"""
function write_report_radial_profile_assets(
    output_dir::String,
    rows::Vector{RadialProfileRow};
    section_rows::Vector{SectionComparisonRow},
    summary_rows::Vector{ComparisonSummaryRow},
    coordinate_mode::String,
    overwrite::Bool = false,
)
    paths = String[]
    primary_rows = principal_radial_profile_rows(rows)
    audit_rows = radial_profile_audit_rows(primary_rows, rows, section_rows, summary_rows; coordinate_mode=coordinate_mode)
    audit_path = joinpath(output_dir, "radial-profile-audit-$(coordinate_mode).csv")
    push!(paths, write_radial_profile_audit_csv(audit_path, audit_rows; overwrite=overwrite))
    passed_severities = Set(row.severity for row in audit_rows if row.status == "ok")
    for severity in sort(collect(passed_severities))
        case_rows = [row for row in primary_rows if row.severity == severity && row.coordinate_mode == coordinate_mode]
        isempty(case_rows) && continue
        path = joinpath(output_dir, "radial-quadrature-$(coordinate_mode)-$(report_case_token(severity)).dat")
        push!(paths, write_report_radial_dat_file(path, case_rows; overwrite=overwrite))
    end
    return paths
end

function write_report_radial_dat_file(path::String, case_rows::Vector{RadialProfileRow}; overwrite::Bool = false)
    isempty(case_rows) && throw(ArgumentError("cannot write radial profile data with no rows"))
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
    return path
end

"""
    principal_radial_profile_rows(rows)

Choose the radial-profile rows that feed the report assets. The preferred surface
is the current-radius profile at 20 bins; when that exact bin count is absent,
the helper falls back to the nearest available current-radius resolution.
"""
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

"""
    radial_profile_audit_rows(primary_rows, all_rows, section_rows, summary_rows; coordinate_mode)

Build the report-facing audit rows that decide whether per-case radial `.dat`
assets should be published for the selected coordinate mode.
"""
function radial_profile_audit_rows(
    primary_rows::Vector{RadialProfileRow},
    all_rows::Vector{RadialProfileRow},
    section_rows::Vector{SectionComparisonRow},
    summary_rows::Vector{ComparisonSummaryRow};
    coordinate_mode::String,
)
    rows = NamedTuple[]
    cases = sort(collect(unique(row.severity for row in primary_rows if row.coordinate_mode == coordinate_mode)))
    for severity in cases
        case_primary = [row for row in primary_rows if row.severity == severity && row.coordinate_mode == coordinate_mode]
        case_all = [row for row in all_rows if row.severity == severity && row.coordinate_mode == coordinate_mode]
        summary_index = findfirst(row -> row.severity == severity && row.coordinate_mode == coordinate_mode, summary_rows)
        summary_delta = if summary_index === nothing
            NaN
        else
            abs(mean_or_nan(finite_values(row.abs_velocity_error_cm_s for row in case_all)) -
                summary_rows[summary_index].profile_mean_abs_error_cm_s)
        end
        case_message = ""
        if isempty(case_primary)
            case_message = "no promoted current-radius radial rows"
        elseif !(isfinite(summary_delta) && summary_delta <= 1.0e-6)
            case_message = "radial summary mismatch"
        end
        for z in sort(collect(unique(row.z_slice_cm for row in case_primary)))
            slice_rows = sort([row for row in case_primary if row.z_slice_cm == z]; by=row -> row.radial_bin)
            status, message, area_mismatch, reconstructed_error = radial_profile_slice_audit(
                slice_rows,
                section_rows;
                severity=severity,
                coordinate_mode=coordinate_mode,
            )
            if !isempty(case_message)
                status = "failed"
                message = isempty(message) ? case_message : string(message, "; ", case_message)
            end
            push!(rows, (
                severity=severity,
                case=report_case_token(severity),
                coordinate_mode=coordinate_mode,
                z_slice_cm=z,
                radial_bin_count=length(unique(row.radial_bin for row in slice_rows)),
                area_mismatch_rel=area_mismatch,
                reconstructed_mean_abs_error_cm_s=reconstructed_error,
                summary_mean_abs_delta_cm_s=summary_delta,
                status=status,
                message=message,
            ))
        end
        if isempty(case_primary)
            push!(rows, (
                severity=severity,
                case=report_case_token(severity),
                coordinate_mode=coordinate_mode,
                z_slice_cm=NaN,
                radial_bin_count=0,
                area_mismatch_rel=NaN,
                reconstructed_mean_abs_error_cm_s=NaN,
                summary_mean_abs_delta_cm_s=summary_delta,
                status="failed",
                message=case_message,
            ))
        end
    end
    return rows
end

function radial_profile_slice_audit(
    rows::Vector{RadialProfileRow},
    section_rows::Vector{SectionComparisonRow};
    severity::Float64,
    coordinate_mode::String,
)
    isempty(rows) && return ("failed", "no rows", NaN, NaN)
    finite_required = all(row ->
            isfinite(row.r_over_r0_mid) &&
            isfinite(row.area_cm2) &&
            isfinite(row.mean_u3d_cm_s) &&
            isfinite(row.mean_u1d_cm_s) &&
            isfinite(row.abs_velocity_error_cm_s),
        rows,
    )
    positive_bins = all(row -> row.area_valid && row.area_cm2 > 0.0, rows)
    bin_count = length(unique(row.radial_bin for row in rows))
    radii = [row.r_over_r0_mid for row in rows]
    monotone_radius = all(diff(radii) .> 0.0)
    z_slice = first(rows).z_slice_cm
    section_index = findfirst(
        row -> row.severity == severity &&
            row.coordinate_mode == coordinate_mode &&
            isapprox(row.z_cm, z_slice; atol=1.0e-9) &&
            row.area_valid,
        section_rows,
    )
    section_area = section_index === nothing ? NaN : section_rows[section_index].area_cm2
    radial_area = sum(row.area_cm2 for row in rows)
    area_mismatch = isfinite(section_area) && section_area > 0.0 ? abs(radial_area - section_area) / section_area : NaN
    reconstructed_error = radial_area > 0.0 ?
        sum(row.area_cm2 * row.abs_velocity_error_cm_s for row in rows) / radial_area :
        NaN
    failures = String[]
    finite_required || push!(failures, "nonfinite row values")
    positive_bins || push!(failures, "nonpositive or invalid bin area")
    bin_count >= 20 || push!(failures, "fewer than 20 radial bins")
    monotone_radius || push!(failures, "nonmonotone normalized radius")
    isfinite(area_mismatch) && area_mismatch <= 0.01 || push!(failures, "radial area closure exceeds 1%")
    status = isempty(failures) ? "ok" : "failed"
    return (status, join(failures, "; "), area_mismatch, reconstructed_error)
end

function write_radial_profile_audit_csv(path::String, rows; overwrite::Bool = false)
    header = [
        "severity",
        "case",
        "coordinate_mode",
        "z_slice_cm",
        "radial_bin_count",
        "area_mismatch_rel",
        "reconstructed_mean_abs_error_cm_s",
        "summary_mean_abs_delta_cm_s",
        "status",
        "message",
    ]
    values = (
        Any[
            row.severity,
            row.case,
            row.coordinate_mode,
            row.z_slice_cm,
            row.radial_bin_count,
            row.area_mismatch_rel,
            row.reconstructed_mean_abs_error_cm_s,
            row.summary_mean_abs_delta_cm_s,
            row.status,
            row.message,
        ] for row in rows
    )
    return write_csv_table(path, header, values; overwrite=overwrite)
end
