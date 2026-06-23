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
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
    pressure_drop_dyn_cm2::Real,
    allow_pressure_fallback::Bool = true,
)
    axial_coordinates_cm = mesh.geometry.axial_coordinates_cm
    length(current_radii_cm) == length(axial_coordinates_cm) || throw(DimensionMismatch(
        "native resolved-FSI partitioned current_radii_cm length must match the native axial station count",
    ))
    size(coordinates, 1) == size(mesh.coordinates, 1) ||
        throw(DimensionMismatch("native resolved-FSI partitioned pressure-sampling coordinates must match the mesh node count"))
    size(coordinates, 2) == 3 ||
        throw(DimensionMismatch("native resolved-FSI partitioned pressure-sampling coordinates must have 3 columns"))
    fallback_profile = allow_pressure_fallback ?
        native_resolved_fsi_partitioned_pressure_fallback_profile(
            mesh,
            axial_coordinates_cm,
            current_radii_cm;
            pressure_drop_dyn_cm2=pressure_drop_dyn_cm2,
        ) :
        fill(NaN, length(axial_coordinates_cm))
    pressure_values = similar(current_radii_cm)
    fallback_count = 0
    angular_samples = max(mesh.geometry.resolution.angular, 6)
    z_eps = max(mesh.case_spec.length_cm, 1.0) * 1.0e-8
    for index in eachindex(axial_coordinates_cm)
        z_sample = clamp(axial_coordinates_cm[index], z_eps, mesh.case_spec.length_cm - z_eps)
        plane_pressure = native_resolved_fsi_partitioned_wall_pressure_at_plane(
            mesh,
            pressure_h,
            index,
            coordinates,
            wall_radius_at_z,
        )
        if plane_pressure === nothing
            pressure_values[index], used_fallback = native_resolved_fsi_partitioned_wall_pressure_at_station(
                pressure_h,
                z_sample,
                current_radii_cm[index],
                fallback_profile[index],
                angular_samples;
                allow_pressure_fallback=allow_pressure_fallback,
            )
        else
            pressure_values[index] = plane_pressure
            used_fallback = false
        end
        fallback_count += used_fallback ? 1 : 0
    end
    return gauge_normalized_pressure_profile(pressure_values), fallback_count
end

function native_resolved_fsi_partitioned_wall_pressure_at_plane(
    mesh::NativeResolvedFSIMesh,
    pressure_h,
    plane_index::Int,
    coordinates::AbstractMatrix{<:Real},
    wall_radius_at_z,
)
    resolution = mesh.geometry.resolution
    plane_node_count = native_resolved_fsi_nodes_per_plane(resolution)
    offset = (plane_index - 1) * plane_node_count
    acc = 0.0
    count = 0
    for sector in 1:resolution.angular
        node = offset + native_resolved_fsi_plane_node_index(resolution, resolution.radial, sector)
        value = native_resolved_fsi_partitioned_try_pressure_at_node(
            mesh,
            node,
            pressure_h;
            coordinates=coordinates,
            wall_radius_at_z=wall_radius_at_z,
        )
        if value !== nothing
            acc += value
            count += 1
        end
    end
    return count > 0 ? acc / count : nothing
end

function native_resolved_fsi_partitioned_try_pressure_at_node(
    mesh::NativeResolvedFSIMesh,
    node::Int,
    pressure_h;
    coordinates::AbstractMatrix{<:Real},
    wall_radius_at_z,
)
    x = Float64(coordinates[node, 1])
    y = Float64(coordinates[node, 2])
    z = Float64(coordinates[node, 3])
    direct = native_resolved_fsi_partitioned_try_pressure(pressure_h, Point(x, y, z))
    direct !== nothing && return direct
    fallback_point = native_resolved_fsi_smoke_interior_sample_point(
        mesh,
        node;
        coordinates=coordinates,
        wall_radius_at_z=wall_radius_at_z,
    )
    return native_resolved_fsi_partitioned_try_pressure(pressure_h, fallback_point)
end

function native_resolved_fsi_partitioned_try_pressure(pressure_h, point::Point)
    value = try
        Float64(pressure_h(point))
    catch
        return nothing
    end
    return isfinite(value) ? value : nothing
end

function native_resolved_fsi_partitioned_wall_pressure_at_station(
    pressure_h,
    z_cm::Float64,
    radius_cm::Float64,
    fallback::Float64,
    angular_samples::Int;
    allow_pressure_fallback::Bool = true,
)
    radius_cm > 0.0 || throw(ArgumentError("native resolved-FSI partitioned wall pressure sampling requires positive radius"))
    for radial_scale in (1.0 - 1.0e-6, 0.95, 0.75, 0.5, 0.25, 0.0)
        acc = 0.0
        count = 0
        sample_radius = radius_cm * radial_scale
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
    end
    allow_pressure_fallback || throw(ArgumentError(
        "native resolved-FSI exact inlet/outlet boundary mode requires direct finite wall-pressure sampling; pressure-drop fallback is disabled",
    ))
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
    return only(native_resolved_fsi_solve_partitioned_snapshot_series(mesh, spec, [spec.tfinal_s]))
end

function native_resolved_fsi_solve_partitioned_snapshot_series(
    mesh::NativeResolvedFSIMesh,
    spec::NativeResolvedFSIPartitionedSmokeSpec,
    snapshot_times_s,
)
    requested_snapshot_times_s = Float64[Float64(time_s) for time_s in snapshot_times_s]
    isempty(requested_snapshot_times_s) &&
        throw(ArgumentError("native resolved-FSI partitioned snapshot series requires at least one snapshot time"))
    all(isfinite, requested_snapshot_times_s) ||
        throw(ArgumentError("native resolved-FSI partitioned snapshot times must be finite"))
    for snapshot_time_s in requested_snapshot_times_s
        snapshot_time_s > 0.0 ||
            throw(ArgumentError("native resolved-FSI partitioned snapshot times must be positive"))
        snapshot_time_s <= spec.tfinal_s || throw(ArgumentError(
            "native resolved-FSI partitioned snapshot time $(snapshot_time_s) exceeds tfinal_s=$(spec.tfinal_s)",
        ))
    end
    for index in 2:length(requested_snapshot_times_s)
        requested_snapshot_times_s[index] > requested_snapshot_times_s[index - 1] || throw(ArgumentError(
            "native resolved-FSI partitioned snapshot times must be strictly increasing",
        ))
    end

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
    max_coupling_iterations_used = 0
    final_coupling_displacement_residual_cm = 0.0
    coupling_converged = true
    coupling_residual_history = NamedTuple[]
    fluid_wall_boundary_mode = NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_FLUID_WALL_BOUNDARY_MODE
    snapshots = NativeResolvedFSIPartitionedSmokeSolve[]

    for snapshot_time_s in requested_snapshot_times_s
        while time_s < snapshot_time_s
            dt_step = min(spec.dt_s, snapshot_time_s - time_s)
            step_index = time_step_count + 1
            step_start_displacement_cm = copy(wall_displacement_cm)
            step_start_velocity_cm_s = copy(wall_velocity_cm_s)
            iteration_displacement_cm = copy(wall_displacement_cm)
            iteration_velocity_cm_s = copy(wall_velocity_cm_s)
            iteration_radii_cm = copy(current_radii_cm)
            coupling_velocity_dofs = velocity_dofs_previous
            step_coupling_converged = false
            step_coupling_residual_cm = Inf

            for coupling_iteration in 1:spec.coupling_iteration_count
                displacement = native_resolved_fsi_lifted_displacement(mesh, iteration_displacement_cm)
                deformed_coordinates = mesh.coordinates .+ displacement
                try
                    minimum_signed_tetra_volume6 = native_resolved_fsi_partitioned_smoke_validate_deformed_mesh(
                        mesh,
                        deformed_coordinates,
                        iteration_radii_cm,
                    )
                catch error
                    throw(ArgumentError(
                        "native resolved-FSI partitioned smoke deformed-mesh guard failed at time step $(step_index), coupling iteration $(coupling_iteration): $(sprint(showerror, error))",
                    ))
                end
                wall_radius_at_z = native_resolved_fsi_partitioned_radius_profile(
                    wall_axial_coordinates_cm,
                    iteration_radii_cm,
                )
                wall_velocity_at_z =
                    z -> native_resolved_fsi_interpolate_wall_lift(wall_axial_coordinates_cm, iteration_velocity_cm_s, z)
                fluid_state = native_resolved_fsi_solve_navier_stokes(
                    mesh;
                    coordinates=deformed_coordinates,
                    wall_radius_at_z=wall_radius_at_z,
                    wall_velocity_at=wall_velocity_at_z,
                    inlet_outlet_boundary_mode=controls.inlet_outlet_boundary_mode,
                    inlet_umax_cm_s=controls.inlet_umax_cm_s,
                    dt_s=dt_step,
                    tfinal_s=dt_step,
                    pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
                    picard_iteration_count=controls.picard_iteration_count,
                    picard_tolerance=controls.picard_tolerance,
                    initial_velocity_dofs=coupling_velocity_dofs,
                )
                coupling_velocity_dofs = native_resolved_fsi_copy_free_dof_values(fluid_state.velocity)
                wall_pressure_dyn_cm2, step_pressure_fallback_count = native_resolved_fsi_partitioned_wall_pressure_profile(
                    mesh,
                    fluid_state.pressure,
                    iteration_radii_cm;
                    coordinates=deformed_coordinates,
                    wall_radius_at_z=wall_radius_at_z,
                    pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
                    allow_pressure_fallback=
                        controls.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke,
                )
                pressure_projection_fallback_count += step_pressure_fallback_count

                candidate_displacement_cm = copy(step_start_displacement_cm)
                candidate_velocity_cm_s = copy(step_start_velocity_cm_s)
                candidate_radii_cm = copy(reference_radii_cm)
                try
                    native_resolved_fsi_partitioned_wall_state!(
                        candidate_displacement_cm,
                        candidate_velocity_cm_s,
                        candidate_radii_cm,
                        reference_radii_cm,
                        wall_pressure_dyn_cm2,
                        wall_mass_g_cm2,
                        wall_stiffness_c0_dyn_cm3,
                        spec.wall_damping_g_cm2_s,
                        dt_step,
                    )
                catch error
                    throw(ArgumentError(
                        "native resolved-FSI partitioned smoke wall-update guard failed at time step $(step_index), coupling iteration $(coupling_iteration): $(sprint(showerror, error))",
                    ))
                end

                relaxed_displacement_cm =
                    iteration_displacement_cm .+
                    spec.coupling_under_relaxation .* (candidate_displacement_cm .- iteration_displacement_cm)
                relaxed_velocity_cm_s =
                    iteration_velocity_cm_s .+
                    spec.coupling_under_relaxation .* (candidate_velocity_cm_s .- iteration_velocity_cm_s)
                clamp_membrane_endpoints!(relaxed_displacement_cm)
                clamp_membrane_endpoints!(relaxed_velocity_cm_s)
                relaxed_radii_cm = reference_radii_cm .+ relaxed_displacement_cm
                all(isfinite, relaxed_displacement_cm) || throw(ArgumentError(
                    "native resolved-FSI partitioned smoke produced non-finite relaxed displacement at time step $(step_index), coupling iteration $(coupling_iteration)",
                ))
                all(isfinite, relaxed_velocity_cm_s) || throw(ArgumentError(
                    "native resolved-FSI partitioned smoke produced non-finite relaxed wall velocity at time step $(step_index), coupling iteration $(coupling_iteration)",
                ))
                minimum(relaxed_radii_cm) > 0.0 || throw(ArgumentError(
                    "native resolved-FSI partitioned smoke produced a non-positive relaxed radius at time step $(step_index), coupling iteration $(coupling_iteration)",
                ))

                step_coupling_residual_cm = maximum(abs, relaxed_displacement_cm .- iteration_displacement_cm)
                iteration_displacement_cm .= relaxed_displacement_cm
                iteration_velocity_cm_s .= relaxed_velocity_cm_s
                iteration_radii_cm .= relaxed_radii_cm
                step_coupling_converged = step_coupling_residual_cm <= spec.coupling_tolerance
                push!(coupling_residual_history, (
                    time_step_index=step_index,
                    coupling_iteration=coupling_iteration,
                    time_start_s=time_s,
                    time_end_s=time_s + dt_step,
                    displacement_residual_cm=step_coupling_residual_cm,
                    coupling_tolerance_cm=spec.coupling_tolerance,
                    under_relaxation=spec.coupling_under_relaxation,
                    converged=step_coupling_converged,
                    fluid_wall_boundary_mode=string(fluid_wall_boundary_mode),
                    inlet_outlet_boundary_mode=string(controls.inlet_outlet_boundary_mode),
                ))
                max_coupling_iterations_used = max(max_coupling_iterations_used, coupling_iteration)
                final_coupling_displacement_residual_cm = step_coupling_residual_cm
                step_coupling_converged && break
            end

            wall_displacement_cm .= iteration_displacement_cm
            wall_velocity_cm_s .= iteration_velocity_cm_s
            current_radii_cm .= iteration_radii_cm
            velocity_dofs_previous = coupling_velocity_dofs
            coupling_converged &= step_coupling_converged
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
        wall_velocity_at_z =
            z -> native_resolved_fsi_interpolate_wall_lift(wall_axial_coordinates_cm, wall_velocity_cm_s, z)
        refresh_dt = min(spec.dt_s, snapshot_time_s)
        fluid_state = native_resolved_fsi_solve_navier_stokes(
            mesh;
            coordinates=final_deformed_coordinates,
            wall_radius_at_z=wall_radius_at_z,
            wall_velocity_at=wall_velocity_at_z,
            inlet_outlet_boundary_mode=controls.inlet_outlet_boundary_mode,
            inlet_umax_cm_s=controls.inlet_umax_cm_s,
            dt_s=refresh_dt,
            tfinal_s=refresh_dt,
            pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
            picard_iteration_count=controls.picard_iteration_count,
            picard_tolerance=controls.picard_tolerance,
            initial_velocity_dofs=velocity_dofs_previous,
        )
        velocity_dofs_previous = native_resolved_fsi_copy_free_dof_values(fluid_state.velocity)
        max_picard_iterations_used = max(max_picard_iterations_used, fluid_state.max_picard_iterations_used)
        final_picard_update_norm = fluid_state.final_picard_update_norm
        picard_converged &= fluid_state.picard_converged
        wall_pressure_dyn_cm2, refresh_pressure_fallback_count = native_resolved_fsi_partitioned_wall_pressure_profile(
            mesh,
            fluid_state.pressure,
            current_radii_cm;
            coordinates=final_deformed_coordinates,
            wall_radius_at_z=wall_radius_at_z,
            pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
            allow_pressure_fallback=
                controls.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke,
        )
        pressure_projection_fallback_count += refresh_pressure_fallback_count

        push!(snapshots, NativeResolvedFSIPartitionedSmokeSolve(
            fluid_state.velocity,
            fluid_state.pressure,
            fluid_state.velocity_dofs,
            fluid_state.pressure_dofs,
            fluid_state.inlet_outlet_boundary_mode,
            fluid_state.inlet_umax_cm_s,
            fluid_state.inlet_outlet_boundary_status,
            time_step_count,
            max_picard_iterations_used,
            final_picard_update_norm,
            picard_converged,
            max_coupling_iterations_used,
            final_coupling_displacement_residual_cm,
            coupling_converged,
            fluid_wall_boundary_mode,
            copy(coupling_residual_history),
            true,
            copy(wall_axial_coordinates_cm),
            copy(wall_displacement_cm),
            copy(wall_velocity_cm_s),
            copy(wall_pressure_dyn_cm2),
            copy(current_radii_cm),
            wall_mass_g_cm2,
            wall_stiffness_c0_dyn_cm3,
            stability_dt_limit_s,
            minimum_signed_tetra_volume6,
            pressure_projection_fallback_count,
        ))
    end

    return snapshots
end
