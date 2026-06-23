function native_resolved_fsi_partitioned_radius_profile(
    axial_coordinates_cm::Vector{Float64},
    radii_cm::Vector{Float64},
)
    length(axial_coordinates_cm) == length(radii_cm) || throw(DimensionMismatch(
        "native resolved-FSI partitioned radii must match the axial station count",
    ))
    return z -> native_resolved_fsi_interpolate_wall_lift(axial_coordinates_cm, radii_cm, z)
end

function native_resolved_fsi_partitioned_wall_pressure_profile(
    mesh::NativeResolvedFSIMesh,
    pressure_h,
    current_radii_cm::Vector{Float64};
    pressure_drop_dyn_cm2::Real,
)
    axial_coordinates_cm = mesh.geometry.axial_coordinates_cm
    length(current_radii_cm) == length(axial_coordinates_cm) || throw(DimensionMismatch(
        "native resolved-FSI partitioned current_radii_cm length must match the native axial station count",
    ))
    fallback_profile = native_resolved_fsi_partitioned_pressure_fallback_profile(
        mesh,
        axial_coordinates_cm,
        current_radii_cm;
        pressure_drop_dyn_cm2=pressure_drop_dyn_cm2,
    )
    pressure_values = similar(current_radii_cm)
    fallback_count = 0
    angular_samples = max(mesh.geometry.resolution.angular, 6)
    for index in eachindex(axial_coordinates_cm)
        pressure_values[index], used_fallback = native_resolved_fsi_partitioned_wall_pressure_at_station(
            pressure_h,
            axial_coordinates_cm[index],
            current_radii_cm[index],
            fallback_profile[index],
            angular_samples,
        )
        fallback_count += used_fallback ? 1 : 0
    end
    return gauge_normalized_pressure_profile(pressure_values), fallback_count
end

function native_resolved_fsi_partitioned_wall_pressure_at_station(
    pressure_h,
    z_cm::Float64,
    radius_cm::Float64,
    fallback::Float64,
    angular_samples::Int,
)
    radius_cm > 0.0 || throw(ArgumentError("native resolved-FSI partitioned wall pressure sampling requires positive radius"))
    acc = 0.0
    count = 0
    sample_radius = radius_cm * (1.0 - 1.0e-8)
    for sample in 1:angular_samples
        theta = 2.0 * pi * (sample - 0.5) / angular_samples
        value = try
            Float64(pressure_h(Point(sample_radius * cos(theta), sample_radius * sin(theta), z_cm)))
        catch
            NaN
        end
        if isfinite(value)
            acc += value
            count += 1
        end
    end
    if count > 0
        return acc / count, false
    end
    isfinite(fallback) || throw(ArgumentError("native resolved-FSI partitioned wall-pressure fallback must be finite"))
    return fallback, true
end

function native_resolved_fsi_partitioned_pressure_fallback_profile(
    mesh::NativeResolvedFSIMesh,
    axial_coordinates_cm::Vector{Float64},
    current_radii_cm::Vector{Float64};
    pressure_drop_dyn_cm2::Real,
)
    radius_at_z = native_resolved_fsi_partitioned_radius_profile(axial_coordinates_cm, current_radii_cm)
    total_resistance = membrane_resistance_integral(mesh.case_spec.length_cm, radius_at_z)
    total_resistance > 0.0 || throw(ArgumentError("native resolved-FSI partitioned resistance fallback integral must be positive"))
    drop = Float64(pressure_drop_dyn_cm2)
    return [
        drop * membrane_resistance_integral(
            mesh.case_spec.length_cm - axial_coordinates_cm[index],
            zeta -> radius_at_z(axial_coordinates_cm[index] + zeta),
        ) / total_resistance for index in eachindex(axial_coordinates_cm)
    ]
end

function native_resolved_fsi_partitioned_smoke_validate_deformed_mesh(
    mesh::NativeResolvedFSIMesh,
    deformed_coordinates::Matrix{Float64},
    current_radii_cm::Vector{Float64},
)
    all(isfinite, deformed_coordinates) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke deformed coordinates must be finite"))
    minimum(current_radii_cm) > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke produced a non-positive lumen radius"))
    minimum_signed_volume6 = Inf
    for row in axes(mesh.topology, 1)
        signed_volume6 = tetrahedron_signed_volume6(
            mesh.topology[row, 1],
            mesh.topology[row, 2],
            mesh.topology[row, 3],
            mesh.topology[row, 4],
            deformed_coordinates,
        )
        signed_volume6 > 1.0e-14 || throw(ArgumentError(
            "native resolved-FSI partitioned smoke produced an inverted or degenerate tetrahedron at cell $row",
        ))
        minimum_signed_volume6 = min(minimum_signed_volume6, signed_volume6)
    end
    return minimum_signed_volume6
end

function native_resolved_fsi_partitioned_wall_state!(
    wall_displacement_cm::Vector{Float64},
    wall_velocity_cm_s::Vector{Float64},
    current_radii_cm::Vector{Float64},
    reference_radii_cm::Vector{Float64},
    wall_pressure_dyn_cm2::Vector{Float64},
    wall_mass_g_cm2::Float64,
    wall_stiffness_c0_dyn_cm3::Float64,
    wall_damping_g_cm2_s::Float64,
    dt_step_s::Float64,
)
    all(isfinite, wall_pressure_dyn_cm2) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke wall pressure must be finite"))
    acceleration_cm_s2 =
        (wall_pressure_dyn_cm2 .- wall_damping_g_cm2_s .* wall_velocity_cm_s .- wall_stiffness_c0_dyn_cm3 .* wall_displacement_cm) ./
        wall_mass_g_cm2
    clamp_membrane_endpoints!(acceleration_cm_s2)
    wall_displacement_cm .= wall_displacement_cm .+ dt_step_s .* wall_velocity_cm_s .+ 0.5 * dt_step_s^2 .* acceleration_cm_s2
    clamp_membrane_endpoints!(wall_displacement_cm)
    wall_velocity_cm_s .= wall_velocity_cm_s .+ dt_step_s .* acceleration_cm_s2
    clamp_membrane_endpoints!(wall_velocity_cm_s)
    current_radii_cm .= reference_radii_cm .+ wall_displacement_cm
    all(isfinite, wall_displacement_cm) || throw(ArgumentError("native resolved-FSI partitioned smoke wall displacement must remain finite"))
    all(isfinite, wall_velocity_cm_s) || throw(ArgumentError("native resolved-FSI partitioned smoke wall velocity must remain finite"))
    minimum(current_radii_cm) > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke produced a non-positive current radius"))
    return nothing
end

function native_resolved_fsi_copy_free_dof_values(field)
    return Float64[Float64(value) for value in get_free_dof_values(field)]
end

function native_resolved_fsi_solve_partitioned_smoke(
    mesh::NativeResolvedFSIMesh,
    spec::NativeResolvedFSIPartitionedSmokeSpec,
)
    controls = native_resolved_fsi_navier_stokes_controls(spec)
    params = Params(severity=mesh.case_spec.severity_percent, tfinal=spec.tfinal_s, initial_condition=GeometryRestIC())
    wall_stiffness_c0_dyn_cm3 = canic_membrane_c0(params; reference_radius=params.rmax)
    wall_mass_g_cm2 = spec.wall_density_g_cm3 * params.wall_h
    wall_mass_g_cm2 > 0.0 || throw(ArgumentError("native resolved-FSI partitioned smoke wall mass must be positive"))
    stability_dt_limit_s = 1.9 * sqrt(wall_mass_g_cm2 / wall_stiffness_c0_dyn_cm3)
    spec.dt_s <= stability_dt_limit_s || throw(ArgumentError(
        "native resolved-FSI partitioned smoke dt_s=$(spec.dt_s) exceeds the explicit membrane stability limit $(stability_dt_limit_s)",
    ))

    wall_axial_coordinates_cm = copy(mesh.geometry.axial_coordinates_cm)
    reference_radii_cm = copy(mesh.geometry.reference_radii_cm)
    wall_displacement_cm = zeros(Float64, length(wall_axial_coordinates_cm))
    wall_velocity_cm_s = zeros(Float64, length(wall_axial_coordinates_cm))
    current_radii_cm = copy(reference_radii_cm)

    time_s = 0.0
    time_step_count = 0
    max_picard_iterations_used = 0
    final_picard_update_norm = 0.0
    picard_converged = true
    pressure_projection_fallback_count = 0
    velocity_dofs_previous = nothing
    fluid_state = nothing
    wall_pressure_dyn_cm2 = zeros(Float64, length(wall_axial_coordinates_cm))
    minimum_signed_tetra_volume6 = native_resolved_fsi_partitioned_smoke_validate_deformed_mesh(mesh, mesh.coordinates, current_radii_cm)

    while time_s < spec.tfinal_s
        displacement = native_resolved_fsi_lifted_displacement(mesh, wall_displacement_cm)
        deformed_coordinates = mesh.coordinates .+ displacement
        minimum_signed_tetra_volume6 = native_resolved_fsi_partitioned_smoke_validate_deformed_mesh(
            mesh,
            deformed_coordinates,
            current_radii_cm,
        )
        dt_step = min(spec.dt_s, spec.tfinal_s - time_s)
        wall_radius_at_z = native_resolved_fsi_partitioned_radius_profile(wall_axial_coordinates_cm, current_radii_cm)
        fluid_state = native_resolved_fsi_solve_navier_stokes(
            mesh;
            coordinates=deformed_coordinates,
            wall_radius_at_z=wall_radius_at_z,
            dt_s=dt_step,
            tfinal_s=dt_step,
            pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
            picard_iteration_count=controls.picard_iteration_count,
            picard_tolerance=controls.picard_tolerance,
            initial_velocity_dofs=velocity_dofs_previous,
        )
        velocity_dofs_previous = native_resolved_fsi_copy_free_dof_values(fluid_state.velocity)
        wall_pressure_dyn_cm2, step_pressure_fallback_count = native_resolved_fsi_partitioned_wall_pressure_profile(
            mesh,
            fluid_state.pressure,
            current_radii_cm;
            pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
        )
        pressure_projection_fallback_count += step_pressure_fallback_count
        native_resolved_fsi_partitioned_wall_state!(
            wall_displacement_cm,
            wall_velocity_cm_s,
            current_radii_cm,
            reference_radii_cm,
            wall_pressure_dyn_cm2,
            wall_mass_g_cm2,
            wall_stiffness_c0_dyn_cm3,
            spec.wall_damping_g_cm2_s,
            dt_step,
        )
        time_s += dt_step
        time_step_count += 1
        max_picard_iterations_used = max(max_picard_iterations_used, fluid_state.max_picard_iterations_used)
        final_picard_update_norm = fluid_state.final_picard_update_norm
        picard_converged &= fluid_state.picard_converged
    end

    time_step_count > 0 || throw(ArgumentError("native resolved-FSI partitioned smoke produced zero coupling steps"))

    final_displacement = native_resolved_fsi_lifted_displacement(mesh, wall_displacement_cm)
    final_deformed_coordinates = mesh.coordinates .+ final_displacement
    minimum_signed_tetra_volume6 = native_resolved_fsi_partitioned_smoke_validate_deformed_mesh(
        mesh,
        final_deformed_coordinates,
        current_radii_cm,
    )
    wall_radius_at_z = native_resolved_fsi_partitioned_radius_profile(wall_axial_coordinates_cm, current_radii_cm)
    refresh_dt = min(spec.dt_s, spec.tfinal_s)
    fluid_state = native_resolved_fsi_solve_navier_stokes(
        mesh;
        coordinates=final_deformed_coordinates,
        wall_radius_at_z=wall_radius_at_z,
        dt_s=refresh_dt,
        tfinal_s=refresh_dt,
        pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
        picard_iteration_count=controls.picard_iteration_count,
        picard_tolerance=controls.picard_tolerance,
        initial_velocity_dofs=velocity_dofs_previous,
    )
    max_picard_iterations_used = max(max_picard_iterations_used, fluid_state.max_picard_iterations_used)
    final_picard_update_norm = fluid_state.final_picard_update_norm
    picard_converged &= fluid_state.picard_converged
    wall_pressure_dyn_cm2, refresh_pressure_fallback_count = native_resolved_fsi_partitioned_wall_pressure_profile(
        mesh,
        fluid_state.pressure,
        current_radii_cm;
        pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
    )
    pressure_projection_fallback_count += refresh_pressure_fallback_count

    return NativeResolvedFSIPartitionedSmokeSolve(
        fluid_state.velocity,
        fluid_state.pressure,
        fluid_state.velocity_dofs,
        fluid_state.pressure_dofs,
        time_step_count,
        max_picard_iterations_used,
        final_picard_update_norm,
        picard_converged,
        true,
        wall_axial_coordinates_cm,
        wall_displacement_cm,
        wall_velocity_cm_s,
        wall_pressure_dyn_cm2,
        current_radii_cm,
        wall_mass_g_cm2,
        wall_stiffness_c0_dyn_cm3,
        stability_dt_limit_s,
        minimum_signed_tetra_volume6,
        pressure_projection_fallback_count,
    )
end
