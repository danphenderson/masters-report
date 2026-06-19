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

function resolved3d_time_fields(field::Resolved3DVelocityField, result::SimulationResult)
    return resolved3d_time_fields(field.case_spec.target_time, field.metadata.time, result.completed_time)
end

function resolved3d_time_fields(target_time::Real, xdmf_time::Real, one_d_completed_time::Real)
    target_time_s = Float64(target_time)
    xdmf_time_s = Float64(xdmf_time)
    one_d_completed_time_s = Float64(one_d_completed_time)
    return (
        target_time_s=target_time_s,
        one_d_completed_time_s=one_d_completed_time_s,
        one_d_terminal_time_error_s=terminal_time_error(one_d_completed_time_s, target_time_s),
        xdmf_target_time_error_s=terminal_time_error(xdmf_time_s, target_time_s),
        cross_model_time_offset_s=terminal_time_error(xdmf_time_s, one_d_completed_time_s),
    )
end

function resolved3d_run_fields(case::Resolved3DCaseSpec, params::Params, backend::AbstractTimeBackend)
    return (
        model=model_name(params),
        nx=params.nx,
        dt_s=params.dt,
        initial_condition=initial_condition_name(params.initial_condition),
        backend=backend_name(backend),
        run_status="ok",
        time_atol_s=case.time_atol,
    )
end

function run_comparison(spec::ComparisonSpec)
    validate_workflow_spec(spec)
    paths = default_output_paths(spec)
    section_rows = SectionComparisonRow[]
    profile_rows = RadialProfileRow[]
    sensitivity_rows = NodeSlabSensitivityRow[]
    summary_rows = ComparisonSummaryRow[]

    for case in spec.cases
        field = load_resolved3d_velocity(case)
        params = params_with(spec.base_params; severity=case.severity, tfinal=case.target_time)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)

        case_sections = compare_section_means(field, result, params, spec)
        case_profiles = compare_radial_profiles(field, result, params, spec)
        case_sensitivity = compare_node_slab_sensitivity(field, result, params, spec)
        diagnostics = characteristic_diagnostics(result, params)
        append!(section_rows, case_sections)
        append!(profile_rows, case_profiles)
        append!(sensitivity_rows, case_sensitivity)
        push!(
            summary_rows,
            summarize_comparison(
                case,
                field.metadata,
                params,
                spec.backend,
                case_sections,
                case_profiles,
                diagnostics,
                result.completed_time,
            ),
        )
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

    return ComparisonResult(
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
end

function compare_section_means(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    z_targets = collect(range(0.0, params.length_cm; length=spec.section_count))
    u1d = velocity(result)
    rows = SectionComparisonRow[]
    time_fields = resolved3d_time_fields(field, result)
    run_fields = resolved3d_run_fields(field.case_spec, params, spec.backend)

    for z in z_targets
        z_value = Float64(z)
        observation = section_observation(field, z_value, spec.operator)
        u1d_at_z = interpolate_linear(result.z, u1d, z_value)
        q1d_at_z = interpolate_linear(result.z, result.flow, z_value)
        flow_1d = pi * q1d_at_z
        abs_error = abs_or_nan(u1d_at_z, observation.mean_velocity_cm_s)
        flow_abs_error = abs_or_nan(flow_1d, observation.flow_cm3_s)
        rel_error = relative_error(abs_error, observation.mean_velocity_cm_s)

        push!(
            rows,
            SectionComparisonRow(
                field.case_spec.case_label,
                field.case_spec.severity,
                operator_name(spec.operator),
                run_fields.model,
                run_fields.nx,
                run_fields.dt_s,
                run_fields.initial_condition,
                run_fields.backend,
                run_fields.run_status,
                z_value,
                observation.area_cm2,
                observation.flow_cm3_s,
                flow_1d,
                observation.mean_velocity_cm_s,
                u1d_at_z,
                abs_error,
                flow_abs_error,
                rel_error,
                rel_error,
                observation.intersection_count,
                observation.area_valid,
                observation.cut_status,
                observation.node_count,
                observation.observed_radius_cm,
                field.metadata.time,
                time_fields.xdmf_target_time_error_s,
                time_fields.target_time_s,
                run_fields.time_atol_s,
                time_fields.one_d_completed_time_s,
                time_fields.one_d_terminal_time_error_s,
                time_fields.xdmf_target_time_error_s,
                time_fields.cross_model_time_offset_s,
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
    u1d = velocity(result)
    rows = RadialProfileRow[]
    time_fields = resolved3d_time_fields(field, result)
    run_fields = resolved3d_run_fields(field.case_spec, params, spec.backend)

    for z_slice in spec.profile_slices
        r0, _, _ = stenosis(z_slice, params)
        area_at_z = interpolate_linear(result.z, result.area, z_slice)
        radius_at_z = sqrt(positive_area(area_at_z))
        uavg_at_z = interpolate_linear(result.z, u1d, z_slice)
        current_area = pi * radius_at_z^2
        reference_area = pi * r0^2
        area_mismatch = abs(current_area - reference_area) / max(reference_area, eps())

        for radius_mode in spec.radial_radius_modes, bin_count in spec.radial_bin_counts
            radius_scale = radius_mode == "current" ? radius_at_z : r0
            observations = radial_profile_observations(field, z_slice, radius_scale, bin_count, spec.operator)

            for bin in 1:bin_count
                observation = observations[bin]
                r_over_radius_mid = (bin - 0.5) / bin_count
                u1d_profile = one_dimensional_profile_velocity(uavg_at_z, r_over_radius_mid * radius_scale, radius_at_z, params)
                abs_error = abs_or_nan(u1d_profile, observation.mean_velocity_cm_s)
                rel_error = relative_error(abs_error, observation.mean_velocity_cm_s)

                push!(
                    rows,
                    RadialProfileRow(
                        field.case_spec.case_label,
                        field.case_spec.severity,
                        operator_name(spec.operator),
                        run_fields.model,
                        run_fields.nx,
                        run_fields.dt_s,
                        run_fields.initial_condition,
                        run_fields.backend,
                        run_fields.run_status,
                        z_slice,
                        bin,
                        r_over_radius_mid,
                        observation.area_cm2,
                        observation.flow_cm3_s,
                        observation.mean_velocity_cm_s,
                        u1d_profile,
                        abs_error,
                        rel_error,
                        observation.intersection_count,
                        observation.area_valid,
                        observation.node_count,
                        field.metadata.time,
                        time_fields.xdmf_target_time_error_s,
                        time_fields.target_time_s,
                        run_fields.time_atol_s,
                        time_fields.one_d_completed_time_s,
                        time_fields.one_d_terminal_time_error_s,
                        time_fields.xdmf_target_time_error_s,
                        time_fields.cross_model_time_offset_s,
                        bin_count,
                        radius_mode,
                        radius_scale,
                        current_area,
                        reference_area,
                        area_mismatch,
                        observation.velocity_variance_cm2_s2,
                    ),
                )
            end
        end
    end

    return rows
end

function compare_node_slab_sensitivity(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    z_targets = collect(range(0.0, params.length_cm; length=spec.section_count))
    u1d = velocity(result)
    rows = NodeSlabSensitivityRow[]
    time_fields = resolved3d_time_fields(field, result)
    run_fields = resolved3d_run_fields(field.case_spec, params, spec.backend)

    for half_width in spec.node_slab_half_widths
        operator = NodeSlabOperator(half_width_cm=half_width)
        for z in z_targets
            z_value = Float64(z)
            observation = section_observation(field, z_value, operator)
            u1d_at_z = interpolate_linear(result.z, u1d, z_value)
            abs_error = abs_or_nan(u1d_at_z, observation.mean_velocity_cm_s)
            push!(
                rows,
                NodeSlabSensitivityRow(
                    field.case_spec.case_label,
                    field.case_spec.severity,
                    run_fields.model,
                    run_fields.nx,
                    run_fields.dt_s,
                    run_fields.initial_condition,
                    run_fields.backend,
                    run_fields.run_status,
                    half_width,
                    z_value,
                    observation.mean_velocity_cm_s,
                    u1d_at_z,
                    abs_error,
                    relative_error(abs_error, observation.mean_velocity_cm_s),
                    observation.node_count,
                    observation.observed_radius_cm,
                    field.metadata.time,
                    time_fields.xdmf_target_time_error_s,
                    time_fields.target_time_s,
                    run_fields.time_atol_s,
                    time_fields.one_d_completed_time_s,
                    time_fields.one_d_terminal_time_error_s,
                    time_fields.xdmf_target_time_error_s,
                    time_fields.cross_model_time_offset_s,
                ),
            )
        end
    end

    return rows
end

function section_half_width(z_targets::Vector{Float64})
    dz = length(z_targets) <= 1 ? 0.0 : minimum(diff(z_targets))
    return max(0.5 * dz, DEFAULT_NODE_SLAB_HALF_WIDTH_CM)
end

function section_observation(field::Resolved3DVelocityField, z::Float64, ::CrossSectionQuadratureOperator)
    return quadrature_section_observation(field, z)
end

function section_observation(field::Resolved3DVelocityField, z::Float64, operator::NodeSlabOperator)
    node_ids = slab_node_indices(field.coordinates, z, operator.half_width_cm)
    u3d = mean_velocity_or_nan(field.velocity, node_ids)
    return (
        area_cm2=NaN,
        flow_cm3_s=NaN,
        mean_velocity_cm_s=u3d,
        intersection_count=0,
        area_valid=false,
        cut_status=isempty(node_ids) ? "empty-slab" : "valid-slab",
        node_count=length(node_ids),
        observed_radius_cm=observed_radius_or_nan(field.coordinates, node_ids),
    )
end

function quadrature_section_observation(field::Resolved3DVelocityField, z::Float64)
    area = 0.0
    flow = 0.0
    count = 0
    observed_radius = 0.0
    degenerate_count = 0

    for tet in eachrow(field.topology)
        polygon = tetra_plane_polygon(field, tet, z)
        if 0 < length(polygon) < 3
            degenerate_count += 1
            continue
        end
        length(polygon) >= 3 || continue
        center = polygon_center(polygon)
        tet_triangles = 0
        for i in eachindex(polygon)
            p1 = polygon[i]
            p2 = polygon[mod1(i + 1, length(polygon))]
            tri_area = triangle_area_xy(center, p1, p2)
            tri_area > 1.0e-14 || continue
            tri_velocity = (center[4] + p1[4] + p2[4]) / 3.0
            area += tri_area
            flow += tri_area * tri_velocity
            count += 1
            tet_triangles += 1
            observed_radius = max(observed_radius, hypot(p1[1], p1[2]), hypot(p2[1], p2[2]))
        end
        tet_triangles > 0 || (degenerate_count += 1)
    end

    area_valid = area > 0.0 && isfinite(area)
    cut_status = area_valid ? "valid" : (degenerate_count > 0 ? "degenerate-cut" : "empty-plane")
    return (
        area_cm2=area_valid ? area : NaN,
        flow_cm3_s=area_valid ? flow : NaN,
        mean_velocity_cm_s=area_valid ? flow / area : NaN,
        intersection_count=count,
        area_valid=area_valid,
        cut_status=cut_status,
        node_count=0,
        observed_radius_cm=area_valid ? observed_radius : NaN,
    )
end

function radial_profile_observations(
    field::Resolved3DVelocityField,
    z::Float64,
    radius_scale::Float64,
    bin_count::Int,
    ::CrossSectionQuadratureOperator,
)
    areas = zeros(Float64, bin_count)
    flows = zeros(Float64, bin_count)
    velocity_sumsq = zeros(Float64, bin_count)
    counts = zeros(Int, bin_count)
    radius_scale > 0.0 || throw(ArgumentError("radial profile radius scale must be positive"))

    for tet in eachrow(field.topology)
        polygon = tetra_plane_polygon(field, tet, z)
        length(polygon) >= 3 || continue
        center = polygon_center(polygon)
        for i in eachindex(polygon)
            p1 = polygon[i]
            p2 = polygon[mod1(i + 1, length(polygon))]
            tri_area = triangle_area_xy(center, p1, p2)
            tri_area > 1.0e-14 || continue
            for point in triangle_quadrature_points(center, p1, p2)
                rho = hypot(point[1], point[2]) / radius_scale
                0.0 <= rho <= 1.05 || continue
                bin = clamp(floor(Int, min(rho, 1.0) * bin_count) + 1, 1, bin_count)
                area_weight = tri_area / 3.0
                velocity_value = point[4]
                areas[bin] += area_weight
                flows[bin] += area_weight * velocity_value
                velocity_sumsq[bin] += area_weight * velocity_value^2
                counts[bin] += 1
            end
        end
    end

    return [
        (
            area_cm2=areas[bin] > 0.0 ? areas[bin] : NaN,
            flow_cm3_s=areas[bin] > 0.0 ? flows[bin] : NaN,
            mean_velocity_cm_s=areas[bin] > 0.0 ? flows[bin] / areas[bin] : NaN,
            intersection_count=counts[bin],
            area_valid=areas[bin] > 0.0,
            node_count=0,
            observed_radius_cm=NaN,
            velocity_variance_cm2_s2=areas[bin] > 0.0 ? max(velocity_sumsq[bin] / areas[bin] - (flows[bin] / areas[bin])^2, 0.0) : NaN,
        )
        for bin in 1:bin_count
    ]
end

function triangle_quadrature_points(center, p1, p2)
    return (
        triangle_barycentric_point(center, p1, p2, 2.0 / 3.0, 1.0 / 6.0, 1.0 / 6.0),
        triangle_barycentric_point(center, p1, p2, 1.0 / 6.0, 2.0 / 3.0, 1.0 / 6.0),
        triangle_barycentric_point(center, p1, p2, 1.0 / 6.0, 1.0 / 6.0, 2.0 / 3.0),
    )
end

function triangle_barycentric_point(center, p1, p2, w0::Float64, w1::Float64, w2::Float64)
    return (
        w0 * center[1] + w1 * p1[1] + w2 * p2[1],
        w0 * center[2] + w1 * p1[2] + w2 * p2[2],
        w0 * center[3] + w1 * p1[3] + w2 * p2[3],
        w0 * center[4] + w1 * p1[4] + w2 * p2[4],
    )
end

function radial_profile_observations(
    field::Resolved3DVelocityField,
    z::Float64,
    radius_scale::Float64,
    bin_count::Int,
    operator::NodeSlabOperator,
)
    node_ids = slab_node_indices(field.coordinates, z, operator.half_width_cm)
    bins = radial_bins(field.coordinates, node_ids, radius_scale, bin_count)
    return [
        (
            area_cm2=NaN,
            flow_cm3_s=NaN,
            mean_velocity_cm_s=mean_velocity_or_nan(field.velocity, bins[bin]),
            intersection_count=0,
            area_valid=false,
            node_count=length(bins[bin]),
            observed_radius_cm=NaN,
            velocity_variance_cm2_s2=velocity_variance_or_nan(field.velocity, bins[bin]),
        )
        for bin in 1:bin_count
    ]
end

const TETRA_EDGES = ((1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4))
const PLANE_INTERSECTION_TOL = 1.0e-10

function tetra_plane_polygon(field::Resolved3DVelocityField, tet, z::Float64)
    points = NTuple{4,Float64}[]
    for local_index in 1:4
        node = tet[local_index]
        dz = field.coordinates[node, 3] - z
        if abs(dz) <= PLANE_INTERSECTION_TOL
            push_unique_intersection!(points, field, node)
        end
    end

    for (a, b) in TETRA_EDGES
        ia = tet[a]
        ib = tet[b]
        za = field.coordinates[ia, 3]
        zb = field.coordinates[ib, 3]
        da = za - z
        db = zb - z
        if (da < -PLANE_INTERSECTION_TOL && db > PLANE_INTERSECTION_TOL) ||
           (da > PLANE_INTERSECTION_TOL && db < -PLANE_INTERSECTION_TOL)
            weight = (z - za) / (zb - za)
            push_unique_intersection!(points, field, ia, ib, weight, z)
        end
    end

    length(points) >= 3 || return points
    center = polygon_center(points)
    sort!(points; by=point -> atan(point[2] - center[2], point[1] - center[1]))
    return points
end

function push_unique_intersection!(points::Vector{NTuple{4,Float64}}, field::Resolved3DVelocityField, node::Int)
    point = (
        field.coordinates[node, 1],
        field.coordinates[node, 2],
        field.coordinates[node, 3],
        field.velocity[node, 3],
    )
    return push_unique_intersection!(points, point)
end

function push_unique_intersection!(
    points::Vector{NTuple{4,Float64}},
    field::Resolved3DVelocityField,
    left::Int,
    right::Int,
    weight::Float64,
    z::Float64,
)
    point = (
        (1.0 - weight) * field.coordinates[left, 1] + weight * field.coordinates[right, 1],
        (1.0 - weight) * field.coordinates[left, 2] + weight * field.coordinates[right, 2],
        z,
        (1.0 - weight) * field.velocity[left, 3] + weight * field.velocity[right, 3],
    )
    return push_unique_intersection!(points, point)
end

function push_unique_intersection!(points::Vector{NTuple{4,Float64}}, point::NTuple{4,Float64})
    for existing in points
        if hypot(existing[1] - point[1], existing[2] - point[2]) <= 1.0e-9 &&
           abs(existing[3] - point[3]) <= 1.0e-9
            return points
        end
    end
    push!(points, point)
    return points
end

function polygon_center(points::Vector{NTuple{4,Float64}})
    inv_n = 1.0 / length(points)
    return (
        sum(point[1] for point in points) * inv_n,
        sum(point[2] for point in points) * inv_n,
        sum(point[3] for point in points) * inv_n,
        sum(point[4] for point in points) * inv_n,
    )
end

function triangle_area_xy(center, p1, p2)
    return 0.5 * abs((p1[1] - center[1]) * (p2[2] - center[2]) - (p2[1] - center[1]) * (p1[2] - center[2]))
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

function velocity_variance_or_nan(velocity::Matrix{Float64}, ids::Vector{Int})
    length(ids) <= 1 && return NaN
    return var(view(velocity, ids, 3); corrected=false)
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
    params::Params,
    backend::AbstractTimeBackend,
    section_rows::Vector{SectionComparisonRow},
    profile_rows::Vector{RadialProfileRow},
    diagnostics,
    one_d_completed_time::Real,
)
    section_abs = finite_values(row.abs_velocity_error_cm_s for row in section_rows)
    section_rel = finite_values(row.rel_error for row in section_rows)
    flow_abs = finite_values(row.flow_abs_error_cm3_s for row in section_rows)
    profile_abs = finite_values(row.abs_velocity_error_cm_s for row in profile_rows)
    node_counts = [row.node_count for row in section_rows]
    intersection_counts = [row.intersection_count for row in section_rows if row.intersection_count > 0]
    time_fields = resolved3d_time_fields(case.target_time, metadata.time, one_d_completed_time)
    run_fields = resolved3d_run_fields(case, params, backend)
    velocity_errors = finite_values(row.abs_velocity_error_cm_s for row in section_rows)
    velocity_refs = finite_values(row.mean_u3d_cm_s for row in section_rows)

    return ComparisonSummaryRow(
        case.case_label,
        case.severity,
        isempty(section_rows) ? "" : first(section_rows).operator,
        run_fields.model,
        run_fields.nx,
        run_fields.dt_s,
        run_fields.initial_condition,
        run_fields.backend,
        run_fields.run_status,
        length(section_rows),
        length(profile_rows),
        mean_or_nan(section_abs),
        l2_mean_or_nan(section_abs),
        maximum_or_nan(section_abs),
        mean_or_nan(section_rel),
        relative_l1(velocity_errors, velocity_refs),
        maximum_or_nan(section_rel),
        relative_l2(velocity_errors, velocity_refs),
        mean_or_nan(flow_abs),
        l2_mean_or_nan(flow_abs),
        maximum_or_nan(flow_abs),
        mean_or_nan(profile_abs),
        l2_mean_or_nan(profile_abs),
        maximum_or_nan(profile_abs),
        isempty(intersection_counts) ? 0 : minimum(intersection_counts),
        isempty(node_counts) ? 0 : minimum(node_counts),
        count(row -> row.area_valid, section_rows),
        diagnostics.alpha_eff_min,
        diagnostics.alpha_eff_max,
        diagnostics.characteristic_radicand_min,
        diagnostics.lambda_minus_min,
        diagnostics.lambda_minus_max,
        diagnostics.lambda_plus_min,
        diagnostics.lambda_plus_max,
        diagnostics.subcritical_margin_min,
        metadata.time,
        time_fields.xdmf_target_time_error_s,
        time_fields.target_time_s,
        run_fields.time_atol_s,
        time_fields.one_d_completed_time_s,
        time_fields.one_d_terminal_time_error_s,
        time_fields.xdmf_target_time_error_s,
        time_fields.cross_model_time_offset_s,
    )
end

function finite_values(values)
    return [Float64(value) for value in values if isfinite(Float64(value))]
end

mean_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : mean(values)
maximum_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : maximum(values)
l2_mean_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : sqrt(mean(value^2 for value in values))

function relative_l1(errors::Vector{Float64}, references::Vector{Float64})
    isempty(errors) && return NaN
    length(errors) == length(references) || return NaN
    denominator = sum(abs(reference) for reference in references)
    return denominator > 0.0 ? sum(abs(error) for error in errors) / denominator : NaN
end

function relative_l2(errors::Vector{Float64}, references::Vector{Float64})
    isempty(errors) && return NaN
    length(errors) == length(references) || return NaN
    numerator = sqrt(sum(error^2 for error in errors))
    denominator = sqrt(sum(reference^2 for reference in references))
    return denominator > 0.0 ? numerator / denominator : NaN
end

function characteristic_diagnostics(result::SimulationResult, params::Params)
    alpha_min = Inf
    alpha_max = -Inf
    radicand_min = Inf
    lambda_minus_min = Inf
    lambda_minus_max = -Inf
    lambda_plus_min = Inf
    lambda_plus_max = -Inf
    subcritical_margin_min = Inf

    for (A, Q, z) in zip(result.area, result.flow, result.z)
        lambda_minus, lambda_plus, radicand, alpha_eff = characteristic_speeds(A, Q, z, params)
        alpha_min = min(alpha_min, alpha_eff)
        alpha_max = max(alpha_max, alpha_eff)
        radicand_min = min(radicand_min, radicand)
        lambda_minus_min = min(lambda_minus_min, lambda_minus)
        lambda_minus_max = max(lambda_minus_max, lambda_minus)
        lambda_plus_min = min(lambda_plus_min, lambda_plus)
        lambda_plus_max = max(lambda_plus_max, lambda_plus)
        subcritical_margin_min = min(subcritical_margin_min, min(-lambda_minus, lambda_plus))
    end

    return (
        alpha_eff_min=alpha_min,
        alpha_eff_max=alpha_max,
        characteristic_radicand_min=radicand_min,
        lambda_minus_min=lambda_minus_min,
        lambda_minus_max=lambda_minus_max,
        lambda_plus_min=lambda_plus_min,
        lambda_plus_max=lambda_plus_max,
        subcritical_margin_min=subcritical_margin_min,
    )
end
