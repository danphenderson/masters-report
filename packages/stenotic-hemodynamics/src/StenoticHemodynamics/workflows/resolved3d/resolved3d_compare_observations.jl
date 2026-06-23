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
