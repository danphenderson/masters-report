"""
    synthetic_operator_validation_field(coefficients)

Construct the in-memory single-tetra velocity field used by the operator
validation workflow. The axial velocity is affine in `(x, y, z)` and the field
metadata is synthetic rather than file-backed.
"""
function synthetic_operator_validation_field(coefficients::NTuple{4,Float64})
    coordinates = [
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        0.0 0.0 1.0
    ]
    velocity = zeros(Float64, size(coordinates, 1), 3)
    for i in axes(coordinates, 1)
        velocity[i, 3] = affine_axial_value(
            coefficients,
            (coordinates[i, 1], coordinates[i, 2], coordinates[i, 3]),
        )
    end
    case = Resolved3DCaseSpec("operator-validation", 0.0, "synthetic://operator-validation"; target_time=0.0)
    metadata = XDMFVelocityMetadata(
        0.0,
        "synthetic",
        "/geometry",
        size(coordinates),
        "synthetic",
        "/topology",
        (1, 4),
        "synthetic",
        "/velocity",
        size(velocity),
    )
    return Resolved3DVelocityField(case, metadata, [1 2 3 4], coordinates, velocity)
end

function triangle_centroid_xyz(center, p1, p2)
    return (
        (center[1] + p1[1] + p2[1]) / 3.0,
        (center[2] + p1[2] + p2[2]) / 3.0,
        (center[3] + p1[3] + p2[3]) / 3.0,
    )
end

function affine_axial_value(coefficients::NTuple{4,Float64}, point)
    return coefficients[1] + coefficients[2] * point[1] + coefficients[3] * point[2] + coefficients[4] * point[3]
end
