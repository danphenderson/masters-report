function operator_validation_row(
    validation_case::String,
    field::Resolved3DVelocityField,
    coefficients::NTuple{4,Float64},
    z::Float64,
    shift::Float64,
    baseline,
    tolerance::Float64,
)
    observation = quadrature_section_observation(field, z)
    reference = operator_validation_reference(field, coefficients, z)
    area_error = abs_or_nan(observation.area_cm2, reference.area_cm2)
    flow_error = abs_or_nan(observation.flow_cm3_s, reference.flow_cm3_s)
    mean_error = abs_or_nan(observation.mean_velocity_cm_s, reference.mean_velocity_cm_s)
    area_delta = baseline === nothing ? NaN : observation.area_cm2 - baseline.area_cm2
    flow_delta = baseline === nothing ? NaN : observation.flow_cm3_s - baseline.flow_cm3_s
    mean_delta = baseline === nothing ? NaN : observation.mean_velocity_cm_s - baseline.mean_velocity_cm_s
    status = operator_validation_status(
        observation,
        (area_error, flow_error, mean_error, reference.max_triangle_mean_error_cm_s),
        tolerance,
    )
    return OperatorValidationRow(
        validation_case,
        z,
        shift,
        observation.area_cm2,
        reference.area_cm2,
        area_error,
        observation.flow_cm3_s,
        reference.flow_cm3_s,
        flow_error,
        observation.mean_velocity_cm_s,
        reference.mean_velocity_cm_s,
        mean_error,
        area_delta,
        flow_delta,
        mean_delta,
        observation.intersection_count,
        reference.max_triangle_mean_error_cm_s,
        observation.cut_status,
        status,
    )
end

"""
    operator_validation_reference(field, coefficients, z)

Evaluate the exact cross-section reference for the synthetic affine field at a
single plane location. The result is derived from the same polygonization used
by the quadrature operator so the comparison stays bounded to operator behavior.
"""
function operator_validation_reference(
    field::Resolved3DVelocityField,
    coefficients::NTuple{4,Float64},
    z::Float64,
)
    area = 0.0
    flow = 0.0
    triangle_count = 0
    max_triangle_error = 0.0

    for tet in eachrow(field.topology)
        polygon = tetra_plane_polygon(field, tet, z)
        length(polygon) >= 3 || continue
        center = polygon_center(polygon)
        for i in eachindex(polygon)
            p1 = polygon[i]
            p2 = polygon[mod1(i + 1, length(polygon))]
            tri_area = triangle_area_xy(center, p1, p2)
            tri_area > 1.0e-14 || continue
            centroid = triangle_centroid_xyz(center, p1, p2)
            exact_mean = affine_axial_value(coefficients, centroid)
            observed_triangle_mean = (center[4] + p1[4] + p2[4]) / 3.0
            max_triangle_error = max(max_triangle_error, abs(observed_triangle_mean - exact_mean))
            area += tri_area
            flow += tri_area * exact_mean
            triangle_count += 1
        end
    end

    area_valid = area > 0.0 && isfinite(area)
    return (
        area_cm2=area_valid ? area : NaN,
        flow_cm3_s=area_valid ? flow : NaN,
        mean_velocity_cm_s=area_valid ? flow / area : NaN,
        intersection_count=triangle_count,
        max_triangle_mean_error_cm_s=triangle_count > 0 ? max_triangle_error : NaN,
    )
end

function operator_validation_status(observation, errors, tolerance::Float64)
    observation.area_valid || return "fail"
    all(error -> isfinite(error) && error <= tolerance, errors) && return "pass"
    return "fail"
end
