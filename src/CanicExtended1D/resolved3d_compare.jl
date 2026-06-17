function default_profile_slices(p::Params)
    throat = stenosis_throat_z(p)
    return clamp.([throat - 0.5, throat, throat + 0.5], 0.0, p.length_cm)
end

function stenosis_throat_z(p::Params; samples::Int = 2001)
    samples >= 3 || throw(ArgumentError("samples must be at least 3"))
    best_z = 0.0
    best_r = Inf
    for z in range(0.0, p.length_cm; length=samples)
        r0, _, _ = stenosis(Float64(z), p)
        if r0 < best_r
            best_r = r0
            best_z = Float64(z)
        end
    end
    return best_z
end

function run_comparison(spec::ComparisonSpec)
    section_rows = SectionComparisonRow[]
    profile_rows = RadialProfileRow[]
    summary_rows = ComparisonSummaryRow[]

    for case in spec.cases
        field = load_resolved3d_velocity(case)
        params = params_with(spec.base_params; severity=case.severity, tfinal=case.target_time)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)

        case_sections = compare_section_means(field, result, params, spec)
        case_profiles = compare_radial_profiles(field, result, params, spec)
        append!(section_rows, case_sections)
        append!(profile_rows, case_profiles)
        push!(summary_rows, summarize_comparison(case, field.metadata, case_sections, case_profiles))
    end

    result = ComparisonResult(
        spec,
        section_rows,
        profile_rows,
        summary_rows,
        section_csv_paths(spec),
        profile_csv_paths(spec),
        comparison_summary_path(spec),
        String[],
    )
    write_comparison_csvs(result; overwrite=spec.overwrite)

    svg_paths = String[]
    if spec.write_svg
        path = joinpath(spec.output_dir, "section_mean_overlay.svg")
        write_section_comparison_svg(path, section_rows; overwrite=spec.overwrite)
        push!(svg_paths, path)
    end

    return ComparisonResult(
        spec,
        section_rows,
        profile_rows,
        summary_rows,
        result.section_csvs,
        result.profile_csvs,
        result.summary_csv,
        svg_paths,
    )
end

function compare_section_means(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    z_targets = collect(range(0.0, params.length_cm; length=spec.section_count))
    half_width = section_half_width(z_targets)
    u1d = velocity(result)
    rows = SectionComparisonRow[]
    time_error = abs(field.metadata.time - field.case_spec.target_time)

    for z in z_targets
        node_ids = slab_node_indices(field.coordinates, Float64(z), half_width)
        u3d = mean_velocity_or_nan(field.velocity, node_ids)
        u1d_at_z = interpolate_linear(result.z, u1d, Float64(z))
        abs_error = abs_or_nan(u1d_at_z, u3d)
        rel_error = relative_error(abs_error, u3d)
        observed_radius = observed_radius_or_nan(field.coordinates, node_ids)

        push!(
            rows,
            SectionComparisonRow(
                field.case_spec.case_label,
                field.case_spec.severity,
                Float64(z),
                u1d_at_z,
                u3d,
                abs_error,
                rel_error,
                length(node_ids),
                observed_radius,
                field.metadata.time,
                time_error,
            ),
        )
    end

    return rows
end

function compare_radial_profiles(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    z_targets = collect(range(0.0, params.length_cm; length=spec.section_count))
    half_width = section_half_width(z_targets)
    u1d = velocity(result)
    rows = RadialProfileRow[]
    time_error = abs(field.metadata.time - field.case_spec.target_time)

    for z_slice in spec.profile_slices
        r0, _, _ = stenosis(z_slice, params)
        area_at_z = interpolate_linear(result.z, result.area, z_slice)
        radius_at_z = sqrt(positive_area(area_at_z))
        uavg_at_z = interpolate_linear(result.z, u1d, z_slice)
        node_ids = slab_node_indices(field.coordinates, z_slice, half_width)
        bins = radial_bins(field.coordinates, node_ids, r0, spec.radial_bins)

        for bin in 1:spec.radial_bins
            ids = bins[bin]
            r_over_r0_mid = (bin - 0.5) / spec.radial_bins
            u3d = mean_velocity_or_nan(field.velocity, ids)
            u1d_profile = one_dimensional_profile_velocity(uavg_at_z, r_over_r0_mid * r0, radius_at_z, params)
            abs_error = abs_or_nan(u1d_profile, u3d)
            rel_error = relative_error(abs_error, u3d)

            push!(
                rows,
                RadialProfileRow(
                    field.case_spec.case_label,
                    field.case_spec.severity,
                    z_slice,
                    bin,
                    r_over_r0_mid,
                    u1d_profile,
                    u3d,
                    abs_error,
                    rel_error,
                    length(ids),
                    field.metadata.time,
                    time_error,
                ),
            )
        end
    end

    return rows
end

function section_half_width(z_targets::Vector{Float64})
    dz = length(z_targets) <= 1 ? 0.0 : minimum(diff(z_targets))
    return max(0.5 * dz, 0.015)
end

function slab_node_indices(coordinates::Matrix{Float64}, z::Float64, half_width::Float64)
    ids = Int[]
    for i in axes(coordinates, 1)
        if abs(coordinates[i, 3] - z) <= half_width
            push!(ids, i)
        end
    end
    return ids
end

function mean_velocity_or_nan(velocity::Matrix{Float64}, ids::Vector{Int})
    isempty(ids) && return NaN
    return mean(view(velocity, ids, 3))
end

function observed_radius_or_nan(coordinates::Matrix{Float64}, ids::Vector{Int})
    isempty(ids) && return NaN
    radius = 0.0
    for i in ids
        radius = max(radius, hypot(coordinates[i, 1], coordinates[i, 2]))
    end
    return radius
end

function radial_bins(coordinates::Matrix{Float64}, ids::Vector{Int}, r0::Float64, bin_count::Int)
    bins = [Int[] for _ in 1:bin_count]
    r0 > 0.0 || throw(ArgumentError("reference radius must be positive"))

    for i in ids
        rho = hypot(coordinates[i, 1], coordinates[i, 2]) / r0
        if 0.0 <= rho <= 1.05
            bin = clamp(floor(Int, min(rho, 1.0) * bin_count) + 1, 1, bin_count)
            push!(bins[bin], i)
        end
    end

    return bins
end

function one_dimensional_profile_velocity(uavg::Float64, radius::Float64, section_radius::Float64, p::Params)
    return radial_profile_velocity(uavg, radius, section_radius, p.velocity_profile)
end

function interpolate_linear(x::Vector{Float64}, y::Vector{Float64}, x0::Float64)
    length(x) == length(y) || throw(DimensionMismatch("interpolation vectors must have matching lengths"))
    isempty(x) && throw(ArgumentError("cannot interpolate empty vectors"))
    x0 <= x[begin] && return y[begin]
    x0 >= x[end] && return y[end]

    hi = searchsortedfirst(x, x0)
    lo = hi - 1
    weight = (x0 - x[lo]) / (x[hi] - x[lo])
    return (1.0 - weight) * y[lo] + weight * y[hi]
end

function abs_or_nan(a::Float64, b::Float64)
    return isfinite(a) && isfinite(b) ? abs(a - b) : NaN
end

function relative_error(abs_error::Float64, reference::Float64)
    return isfinite(abs_error) && isfinite(reference) ? abs_error / max(abs(reference), eps()) : NaN
end

function summarize_comparison(
    case::Resolved3DCaseSpec,
    metadata::XDMFVelocityMetadata,
    section_rows::Vector{SectionComparisonRow},
    profile_rows::Vector{RadialProfileRow},
)
    section_abs = finite_values(row.abs_error_cm_s for row in section_rows)
    section_rel = finite_values(row.rel_error for row in section_rows)
    profile_abs = finite_values(row.abs_error_cm_s for row in profile_rows)
    node_counts = [row.node_count for row in section_rows]
    time_error = abs(metadata.time - case.target_time)

    return ComparisonSummaryRow(
        case.case_label,
        case.severity,
        length(section_rows),
        length(profile_rows),
        mean_or_nan(section_abs),
        maximum_or_nan(section_abs),
        mean_or_nan(section_rel),
        maximum_or_nan(section_rel),
        mean_or_nan(profile_abs),
        maximum_or_nan(profile_abs),
        isempty(node_counts) ? 0 : minimum(node_counts),
        metadata.time,
        time_error,
    )
end

function finite_values(values)
    return [Float64(value) for value in values if isfinite(Float64(value))]
end

mean_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : mean(values)
maximum_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : maximum(values)
