function native_resolved_fsi_sample_smoke_fields(
    mesh::NativeResolvedFSIMesh,
    velocity_h,
    pressure_h;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
)
    size(coordinates, 1) == size(mesh.coordinates, 1) ||
        throw(DimensionMismatch("native resolved-FSI sampling coordinates must match the mesh node count"))
    node_count = size(coordinates, 1)
    velocity = zeros(Float64, node_count, 3)
    pressure = zeros(Float64, node_count)
    sampling_fallback_count = 0
    for node in axes(mesh.coordinates, 1)
        sample_velocity, sample_pressure, used_fallback =
            native_resolved_fsi_sample_smoke_state_at_node(
                mesh,
                node,
                velocity_h,
                pressure_h;
                coordinates=coordinates,
                wall_radius_at_z=wall_radius_at_z,
            )
        velocity[node, 1] = sample_velocity[1]
        velocity[node, 2] = sample_velocity[2]
        velocity[node, 3] = sample_velocity[3]
        pressure[node] = sample_pressure
        sampling_fallback_count += used_fallback ? 1 : 0
    end
    return velocity, pressure, sampling_fallback_count
end

function native_resolved_fsi_sample_smoke_state_at_node(
    mesh::NativeResolvedFSIMesh,
    node::Int,
    velocity_h,
    pressure_h;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
)
    direct_point = Point(Float64(coordinates[node, 1]), Float64(coordinates[node, 2]), Float64(coordinates[node, 3]))
    direct = native_resolved_fsi_try_sample_smoke_state(velocity_h, pressure_h, direct_point)
    direct !== nothing && return direct[1], direct[2], false

    fallback_point = native_resolved_fsi_smoke_interior_sample_point(mesh, node; coordinates=coordinates, wall_radius_at_z=wall_radius_at_z)
    fallback = native_resolved_fsi_try_sample_smoke_state(velocity_h, pressure_h, fallback_point)
    fallback !== nothing && return fallback[1], fallback[2], true

    throw(ArgumentError("native resolved-FSI smoke field sampling failed at mesh node $node"))
end

function native_resolved_fsi_try_sample_smoke_state(velocity_h, pressure_h, point::Point)
    velocity_value, pressure_value = try
        velocity_h(point), pressure_h(point)
    catch
        return nothing
    end
    velocity_components = (
        velocity_value[1],
        velocity_value[2],
        velocity_value[3],
    )
    all(component -> component isa Real, velocity_components) || return nothing
    pressure_value isa Real || return nothing
    pressure_scalar = pressure_value
    all(isfinite, velocity_components) && isfinite(pressure_scalar) || return nothing
    return velocity_components, pressure_scalar
end

function native_resolved_fsi_smoke_interior_sample_point(
    mesh::NativeResolvedFSIMesh,
    node::Int;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
)
    x = Float64(coordinates[node, 1])
    y = Float64(coordinates[node, 2])
    z = Float64(coordinates[node, 3])
    radial_distance = hypot(x, y)
    reference_radius = Float64(wall_radius_at_z(z))
    axial_eps = native_resolved_fsi_smoke_axial_epsilon(mesh)

    sample_z = if isapprox(z, 0.0; atol=axial_eps)
        min(mesh.case_spec.length_cm, z + axial_eps)
    elseif isapprox(z, mesh.case_spec.length_cm; atol=axial_eps)
        max(0.0, z - axial_eps)
    else
        z
    end

    if radial_distance == 0.0
        return Point(0.0, 0.0, sample_z)
    end

    sample_radius = min(radial_distance, reference_radius) * (1.0 - 1.0e-8)
    sample_radius >= 0.0 || throw(ArgumentError("native resolved-FSI smoke fallback radius became negative at node $node"))
    scale = sample_radius / radial_distance
    return Point(scale * x, scale * y, sample_z)
end

function native_resolved_fsi_smoke_axial_epsilon(mesh::NativeResolvedFSIMesh)
    axial_coordinates = mesh.geometry.axial_coordinates_cm
    if length(axial_coordinates) <= 1
        return max(mesh.case_spec.length_cm * 1.0e-6, 1.0e-8)
    end
    axial_spacing = minimum(diff(axial_coordinates))
    return min(0.25 * axial_spacing, max(mesh.case_spec.length_cm * 1.0e-6, 1.0e-8))
end

function native_resolved_fsi_outlet_gauge_pressure(
    pressure::AbstractVector{<:Real},
    outlet_nodes::AbstractVector{<:Integer},
)
    isempty(outlet_nodes) && throw(ArgumentError("native resolved-FSI smoke outlet node set must not be empty"))
    gauge_offset = sum(pressure[node] for node in outlet_nodes) / length(outlet_nodes)
    isfinite(gauge_offset) || throw(ArgumentError("native resolved-FSI smoke outlet gauge offset must be finite"))
    return pressure .- gauge_offset, gauge_offset
end

function native_resolved_fsi_smoke_validate_finite_fields(
    stage_name::AbstractString,
    velocity::Matrix{Float64},
    pressure::Vector{Float64},
    displacement::Matrix{Float64},
)
    all(isfinite, velocity) || throw(ArgumentError("$stage_name produced non-finite velocity values"))
    all(isfinite, pressure) || throw(ArgumentError("$stage_name produced non-finite pressure values"))
    all(isfinite, displacement) || throw(ArgumentError("$stage_name produced non-finite displacement values"))
    return nothing
end
