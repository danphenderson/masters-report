function native_resolved_fsi_partitioned_radius_profile(
    axial_coordinates_cm::Vector{Float64},
    radii_cm::Vector{Float64},
)
    length(axial_coordinates_cm) == length(radii_cm) || throw(DimensionMismatch(
        "native resolved-FSI partitioned radii must match the axial station count",
    ))
    return z -> native_resolved_fsi_interpolate_wall_lift(axial_coordinates_cm, radii_cm, z)
end

function native_resolved_fsi_partitioned_physical_wall_pressure_profile(
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
    angular_samples = max(mesh.geometry.resolution.angular, 6)
    z_eps = max(mesh.case_spec.length_cm, 1.0) * 1.0e-8
    fallback_count = 0
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
    return native_resolved_fsi_partitioned_validate_physical_wall_pressure_profile(pressure_values), fallback_count
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
    return native_resolved_fsi_partitioned_physical_wall_pressure_profile(
        mesh,
        pressure_h,
        current_radii_cm;
        coordinates=coordinates,
        wall_radius_at_z=wall_radius_at_z,
        pressure_drop_dyn_cm2=pressure_drop_dyn_cm2,
        allow_pressure_fallback=allow_pressure_fallback,
    )
end

function native_resolved_fsi_partitioned_diagnostic_outlet_gauge_pressure_profile(
    physical_wall_forcing_pressure_dyn_cm2::Vector{Float64},
)
    return gauge_normalized_pressure_profile(physical_wall_forcing_pressure_dyn_cm2)
end

function native_resolved_fsi_partitioned_validate_physical_wall_pressure_profile(
    physical_wall_forcing_pressure_dyn_cm2::Vector{Float64},
)
    all(isfinite, physical_wall_forcing_pressure_dyn_cm2) || throw(ArgumentError(
        "native resolved-FSI partitioned physical wall forcing pressure must be finite; " *
        "outlet-gauge-normalized pressure is diagnostic/export only and is not valid membrane forcing",
    ))
    return physical_wall_forcing_pressure_dyn_cm2
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
    acc = nothing
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
            acc = acc === nothing ? value : acc + value
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
        pressure_h(point)
    catch
        return nothing
    end
    return value isa Real && isfinite(value) ? value : nothing
end

function native_resolved_fsi_partitioned_wall_pressure_at_station(
    pressure_h,
    z_cm::AbstractFloat,
    radius_cm::AbstractFloat,
    fallback::Real,
    angular_samples::Int;
    allow_pressure_fallback::Bool = true,
)
    radius_cm > 0.0 || throw(ArgumentError("native resolved-FSI partitioned wall pressure sampling requires positive radius"))
    T = promote_type(typeof(z_cm), typeof(radius_cm))
    z = convert(T, z_cm)
    radius = convert(T, radius_cm)
    radial_scales = (
        one(T) - convert(T, 1.0e-6),
        convert(T, 0.95),
        convert(T, 0.75),
        convert(T, 0.5),
        convert(T, 0.25),
        zero(T),
    )
    for radial_scale in radial_scales
        acc = nothing
        count = 0
        sample_radius = radius * radial_scale
        for sample in 1:angular_samples
            theta = convert(T, 2) * convert(T, pi) * (convert(T, sample) - convert(T, 0.5)) /
                    convert(T, angular_samples)
            value = native_resolved_fsi_partitioned_try_pressure(
                pressure_h,
                Point(sample_radius * cos(theta), sample_radius * sin(theta), z),
            )
            if value !== nothing
                acc = acc === nothing ? value : acc + value
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
    fallback_profile = Vector{Float64}(undef, length(axial_coordinates_cm))
    function fallback_value(index)
        return drop * membrane_resistance_integral(
            mesh.case_spec.length_cm - axial_coordinates_cm[index],
            zeta -> radius_at_z(axial_coordinates_cm[index] + zeta),
        ) / total_resistance
    end
    if native_resolved_fsi_use_threads(length(axial_coordinates_cm))
        Threads.@threads :static for index in eachindex(axial_coordinates_cm)
            fallback_profile[index] = fallback_value(index)
        end
    else
        for index in eachindex(axial_coordinates_cm)
            fallback_profile[index] = fallback_value(index)
        end
    end
    return fallback_profile
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
    function signed_volume6_at_row(row)
        return tetrahedron_signed_volume6(
            mesh.topology[row, 1],
            mesh.topology[row, 2],
            mesh.topology[row, 3],
            mesh.topology[row, 4],
            deformed_coordinates,
        )
    end
    function throw_bad_tetrahedron(row, signed_volume6)
        throw(ArgumentError(
            "native resolved-FSI partitioned smoke produced an inverted or degenerate tetrahedron at cell $(row); " *
            "signed_volume6=$(signed_volume6), minimum_current_radius_cm=$(minimum(current_radii_cm)), " *
            "maximum_wall_displacement_cm=$(maximum(current_radii_cm .- mesh.geometry.reference_radii_cm)), " *
            "minimum_wall_displacement_cm=$(minimum(current_radii_cm .- mesh.geometry.reference_radii_cm))",
        ))
    end
    if native_resolved_fsi_use_threads(size(mesh.topology, 1))
        thread_slot_count = Threads.maxthreadid()
        minimum_by_thread = fill(Inf, thread_slot_count)
        bad_row_by_thread = fill(0, thread_slot_count)
        Threads.@threads :static for row in axes(mesh.topology, 1)
            signed_volume6 = signed_volume6_at_row(row)
            thread_index = Threads.threadid()
            minimum_by_thread[thread_index] = min(minimum_by_thread[thread_index], signed_volume6)
            if signed_volume6 <= 1.0e-14 &&
               (bad_row_by_thread[thread_index] == 0 || row < bad_row_by_thread[thread_index])
                bad_row_by_thread[thread_index] = row
            end
        end
        bad_row = 0
        for row in bad_row_by_thread
            if row != 0 && (bad_row == 0 || row < bad_row)
                bad_row = row
            end
        end
        bad_row == 0 || throw_bad_tetrahedron(bad_row, signed_volume6_at_row(bad_row))
        return minimum(minimum_by_thread)
    else
        minimum_signed_volume6 = Inf
        for row in axes(mesh.topology, 1)
            signed_volume6 = signed_volume6_at_row(row)
            signed_volume6 > 1.0e-14 || throw_bad_tetrahedron(row, signed_volume6)
            minimum_signed_volume6 = min(minimum_signed_volume6, signed_volume6)
        end
        return minimum_signed_volume6
    end
end

function native_resolved_fsi_partitioned_wall_state!(
    wall_displacement_cm::Vector{Float64},
    wall_velocity_cm_s::Vector{Float64},
    current_radii_cm::Vector{Float64},
    reference_radii_cm::Vector{Float64},
    physical_wall_forcing_pressure_dyn_cm2::Vector{Float64},
    wall_mass_g_cm2::Float64,
    wall_stiffness_c0_dyn_cm3::Float64,
    wall_damping_g_cm2_s::Float64,
    dt_step_s::Float64,
)
    native_resolved_fsi_partitioned_validate_physical_wall_pressure_profile(
        physical_wall_forcing_pressure_dyn_cm2,
    )
    denominator = wall_mass_g_cm2 + dt_step_s * wall_damping_g_cm2_s + dt_step_s^2 * wall_stiffness_c0_dyn_cm3
    denominator > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke semi-implicit wall denominator must be positive"))
    predicted_velocity_cm_s =
        (wall_mass_g_cm2 .* wall_velocity_cm_s .+
         dt_step_s .* (physical_wall_forcing_pressure_dyn_cm2 .- wall_stiffness_c0_dyn_cm3 .* wall_displacement_cm)) ./ denominator
    clamp_membrane_endpoints!(predicted_velocity_cm_s)
    predicted_displacement_cm = wall_displacement_cm .+ dt_step_s .* predicted_velocity_cm_s
    clamp_membrane_endpoints!(predicted_displacement_cm)
    predicted_radii_cm = reference_radii_cm .+ predicted_displacement_cm
    if !all(isfinite, predicted_displacement_cm) ||
       !all(isfinite, predicted_velocity_cm_s) ||
       !all(isfinite, predicted_radii_cm)
        throw(ArgumentError("native resolved-FSI partitioned smoke pressure-load plausibility gate produced non-finite predicted wall state"))
    end
    if minimum(predicted_radii_cm) <= 0.0
        min_radius_cm, min_radius_index = findmin(predicted_radii_cm)
        max_abs_wall_pressure_dyn_cm2 = maximum(abs, physical_wall_forcing_pressure_dyn_cm2)
        static_pressure_displacement_cm = wall_stiffness_c0_dyn_cm3 > 0.0 ?
                                          physical_wall_forcing_pressure_dyn_cm2[min_radius_index] /
                                          wall_stiffness_c0_dyn_cm3 : NaN
        semi_implicit_displacement_increment_cm =
            predicted_displacement_cm[min_radius_index] - wall_displacement_cm[min_radius_index]
        throw(ArgumentError(
            "native resolved-FSI partitioned smoke pressure-load plausibility gate predicted a non-positive radius before applying the wall update; " *
            "min_station_index=$(min_radius_index), predicted_radius_cm=$(min_radius_cm), " *
            "reference_radius_cm=$(reference_radii_cm[min_radius_index]), " *
            "wall_pressure_dyn_cm2=$(physical_wall_forcing_pressure_dyn_cm2[min_radius_index]), " *
            "physical_wall_forcing_pressure_dyn_cm2=$(physical_wall_forcing_pressure_dyn_cm2[min_radius_index]), " *
            "max_abs_wall_pressure_dyn_cm2=$(max_abs_wall_pressure_dyn_cm2), " *
            "static_pressure_displacement_cm=$(static_pressure_displacement_cm), " *
            "semi_implicit_displacement_increment_cm=$(semi_implicit_displacement_increment_cm), " *
            "wall_mass_g_cm2=$(wall_mass_g_cm2), wall_stiffness_c0_dyn_cm3=$(wall_stiffness_c0_dyn_cm3), " *
            "dt_step_s=$(dt_step_s)",
        ))
    end
    wall_displacement_cm .= predicted_displacement_cm
    wall_velocity_cm_s .= predicted_velocity_cm_s
    current_radii_cm .= predicted_radii_cm
    all(isfinite, wall_displacement_cm) || throw(ArgumentError("native resolved-FSI partitioned smoke wall displacement must remain finite"))
    all(isfinite, wall_velocity_cm_s) || throw(ArgumentError("native resolved-FSI partitioned smoke wall velocity must remain finite"))
    minimum(current_radii_cm) > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke produced a non-positive current radius"))
    return nothing
end

function native_resolved_fsi_partitioned_wall_update_diagnostics(
    wall_axial_coordinates_cm::Vector{Float64},
    reference_radii_cm::Vector{Float64},
    physical_wall_forcing_pressure_dyn_cm2::Vector{Float64},
    wall_displacement_cm::Vector{Float64},
    wall_velocity_cm_s::Vector{Float64},
    current_radii_cm::Vector{Float64},
    wall_mass_g_cm2::Float64,
    wall_stiffness_c0_dyn_cm3::Float64,
    wall_damping_g_cm2_s::Float64,
    dt_step_s::Float64;
    radius_label::String = "candidate_radius_cm",
)
    length(wall_axial_coordinates_cm) == length(reference_radii_cm) == length(physical_wall_forcing_pressure_dyn_cm2) ==
        length(wall_displacement_cm) == length(wall_velocity_cm_s) == length(current_radii_cm) ||
        return "wall-update diagnostics unavailable because wall-state vector lengths differ"
    isempty(current_radii_cm) && return "wall-update diagnostics unavailable because wall state is empty"
    min_radius_cm, min_radius_index = findmin(current_radii_cm)
    abs_wall_pressure = abs.(physical_wall_forcing_pressure_dyn_cm2)
    max_abs_wall_pressure_dyn_cm2, max_abs_pressure_index = findmax(abs_wall_pressure)
    stability_dt_limit_s = wall_mass_g_cm2 > 0.0 && wall_stiffness_c0_dyn_cm3 > 0.0 ?
                           1.9 * sqrt(wall_mass_g_cm2 / wall_stiffness_c0_dyn_cm3) : NaN
    static_pressure_displacement_cm = wall_stiffness_c0_dyn_cm3 > 0.0 ?
                                      physical_wall_forcing_pressure_dyn_cm2[min_radius_index] /
                                      wall_stiffness_c0_dyn_cm3 : NaN
    return "wall-update diagnostics: min_station_index=$(min_radius_index), " *
           "z_cm=$(wall_axial_coordinates_cm[min_radius_index]), " *
           "reference_radius_cm=$(reference_radii_cm[min_radius_index]), " *
           "$(radius_label)=$(min_radius_cm), " *
           "wall_displacement_cm=$(wall_displacement_cm[min_radius_index]), " *
           "wall_velocity_cm_s=$(wall_velocity_cm_s[min_radius_index]), " *
           "wall_pressure_dyn_cm2=$(physical_wall_forcing_pressure_dyn_cm2[min_radius_index]), " *
           "physical_wall_forcing_pressure_dyn_cm2=$(physical_wall_forcing_pressure_dyn_cm2[min_radius_index]), " *
           "static_pressure_displacement_cm=$(static_pressure_displacement_cm), " *
           "max_abs_wall_pressure_dyn_cm2=$(max_abs_wall_pressure_dyn_cm2), " *
           "max_abs_pressure_station_index=$(max_abs_pressure_index), " *
           "wall_mass_g_cm2=$(wall_mass_g_cm2), " *
           "wall_stiffness_c0_dyn_cm3=$(wall_stiffness_c0_dyn_cm3), " *
           "wall_damping_g_cm2_s=$(wall_damping_g_cm2_s), " *
           "dt_step_s=$(dt_step_s), " *
           "explicit_stability_dt_limit_s=$(stability_dt_limit_s)"
end

function native_resolved_fsi_copy_free_dof_values(field)
    return Float64[Float64(value) for value in get_free_dof_values(field)]
end

function native_resolved_fsi_partitioned_fluid_wall_boundary_mode(inlet_outlet_boundary_mode::Symbol)
    if inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        return NATIVE_RESOLVED_FSI_PARTITIONED_EXACT_FLUID_WALL_BOUNDARY_MODE
    end
    return NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_FLUID_WALL_BOUNDARY_MODE
end

function native_resolved_fsi_partitioned_wall_velocity_at(
    fluid_wall_boundary_mode::Symbol,
    wall_axial_coordinates_cm::Vector{Float64},
    wall_velocity_cm_s::Vector{Float64},
)
    fluid_wall_boundary_mode === NATIVE_RESOLVED_FSI_PARTITIONED_EXACT_FLUID_WALL_BOUNDARY_MODE &&
        return nothing
    return z -> native_resolved_fsi_interpolate_wall_lift(wall_axial_coordinates_cm, wall_velocity_cm_s, z)
end

struct NativeResolvedFSISolveWorkspace
    step_start_displacement_cm::Vector{Float64}
    step_start_velocity_cm_s::Vector{Float64}
    iteration_displacement_cm::Vector{Float64}
    iteration_velocity_cm_s::Vector{Float64}
    iteration_radii_cm::Vector{Float64}
    candidate_displacement_cm::Vector{Float64}
    candidate_velocity_cm_s::Vector{Float64}
    candidate_radii_cm::Vector{Float64}
    relaxed_displacement_cm::Vector{Float64}
    relaxed_velocity_cm_s::Vector{Float64}
    relaxed_radii_cm::Vector{Float64}
end

function NativeResolvedFSISolveWorkspace(axial_station_count::Integer)
    count = Int(axial_station_count)
    count > 0 || throw(ArgumentError("native resolved-FSI solve workspace requires at least one axial station"))
    return NativeResolvedFSISolveWorkspace(ntuple(_ -> zeros(Float64, count), 11)...)
end

function native_resolved_fsi_solve_workspace_for(mesh::NativeResolvedFSIMesh, workspace)
    axial_station_count = length(mesh.geometry.axial_coordinates_cm)
    workspace_value =
        workspace === nothing ? NativeResolvedFSISolveWorkspace(axial_station_count) : workspace
    workspace_value isa NativeResolvedFSISolveWorkspace || throw(ArgumentError(
        "native resolved-FSI solve workspace must be a NativeResolvedFSISolveWorkspace",
    ))
    arrays = (
        workspace_value.step_start_displacement_cm,
        workspace_value.step_start_velocity_cm_s,
        workspace_value.iteration_displacement_cm,
        workspace_value.iteration_velocity_cm_s,
        workspace_value.iteration_radii_cm,
        workspace_value.candidate_displacement_cm,
        workspace_value.candidate_velocity_cm_s,
        workspace_value.candidate_radii_cm,
        workspace_value.relaxed_displacement_cm,
        workspace_value.relaxed_velocity_cm_s,
        workspace_value.relaxed_radii_cm,
    )
    all(length(array) == axial_station_count for array in arrays) || throw(DimensionMismatch(
        "native resolved-FSI solve workspace axial-vector lengths must match the mesh axial station count",
    ))
    return workspace_value
end

function native_resolved_fsi_max_abs_difference(left::AbstractVector{<:Real}, right::AbstractVector{<:Real})
    length(left) == length(right) || throw(DimensionMismatch("native resolved-FSI vector lengths must match"))
    isempty(left) && return 0.0
    residual = 0.0
    @inbounds for index in eachindex(left, right)
        residual = max(residual, abs(Float64(left[index]) - Float64(right[index])))
    end
    return residual
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
    snapshot_times_s;
    progress_callback = nothing,
    restart_state = nothing,
    gridap_context = nothing,
    workspace = nothing,
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
    gridap_context_value = native_resolved_fsi_gridap_context_for(
        mesh,
        gridap_context;
        inlet_outlet_boundary_mode=controls.inlet_outlet_boundary_mode,
        quadrature_degree=4,
    )
    solve_workspace = native_resolved_fsi_solve_workspace_for(mesh, workspace)
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
    physical_wall_forcing_pressure_dyn_cm2 = zeros(Float64, length(wall_axial_coordinates_cm))
    minimum_signed_tetra_volume6 = native_resolved_fsi_partitioned_smoke_validate_deformed_mesh(mesh, mesh.coordinates, current_radii_cm)
    max_coupling_iterations_used = 0
    final_coupling_displacement_residual_cm = 0.0
    coupling_converged = true
    coupling_residual_history = NamedTuple[]
    fluid_wall_boundary_mode = native_resolved_fsi_partitioned_fluid_wall_boundary_mode(
        controls.inlet_outlet_boundary_mode,
    )
    phase_timing = native_resolved_fsi_phase_timing_accumulator()
    snapshots = NativeResolvedFSIPartitionedSmokeSolve[]
    expected_time_step_count = ceil(Int, last(requested_snapshot_times_s) / spec.dt_s)

    if restart_state !== nothing
        time_s = Float64(restart_state.current_saved_time_s)
        isfinite(time_s) && time_s > 0.0 || throw(ArgumentError(
            "native resolved-FSI partitioned restart state current_saved_time_s must be finite and positive",
        ))
        first(requested_snapshot_times_s) > time_s || throw(ArgumentError(
            "native resolved-FSI partitioned restart requires the first requested snapshot time " *
            "$(first(requested_snapshot_times_s)) to be after saved time $(time_s)",
        ))
        time_step_count = Int(restart_state.current_time_step_count)
        time_step_count > 0 || throw(ArgumentError(
            "native resolved-FSI partitioned restart state current_time_step_count must be positive",
        ))
        restart_wall_axial_coordinates_cm = Float64[Float64(value) for value in restart_state.wall_axial_coordinates_cm]
        restart_wall_axial_coordinates_cm == wall_axial_coordinates_cm || throw(ArgumentError(
            "native resolved-FSI partitioned restart wall axial coordinates do not match regenerated mesh",
        ))
        wall_displacement_cm = Float64[Float64(value) for value in restart_state.wall_displacement_cm]
        wall_velocity_cm_s = Float64[Float64(value) for value in restart_state.wall_velocity_cm_s]
        current_radii_cm = Float64[Float64(value) for value in restart_state.current_radii_cm]
        physical_wall_forcing_pressure_dyn_cm2 =
            Float64[Float64(value) for value in restart_state.wall_pressure_dyn_cm2]
        vector_lengths = (
            length(wall_axial_coordinates_cm),
            length(wall_displacement_cm),
            length(wall_velocity_cm_s),
            length(current_radii_cm),
            length(physical_wall_forcing_pressure_dyn_cm2),
        )
        all(==(first(vector_lengths)), vector_lengths) || throw(ArgumentError(
            "native resolved-FSI partitioned restart wall-state arrays must match the mesh axial station count",
        ))
        all(isfinite, wall_displacement_cm) || throw(ArgumentError(
            "native resolved-FSI partitioned restart wall displacement must be finite",
        ))
        all(isfinite, wall_velocity_cm_s) || throw(ArgumentError(
            "native resolved-FSI partitioned restart wall velocity must be finite",
        ))
        all(isfinite, current_radii_cm) || throw(ArgumentError(
            "native resolved-FSI partitioned restart current radii must be finite",
        ))
        all(radius -> radius > 0.0, current_radii_cm) || throw(ArgumentError(
            "native resolved-FSI partitioned restart current radii must be positive",
        ))
        maximum(abs, current_radii_cm .- (reference_radii_cm .+ wall_displacement_cm)) <= 1.0e-12 ||
            throw(ArgumentError(
                "native resolved-FSI partitioned restart current radii must equal reference radii plus wall displacement",
            ))
        !isempty(wall_displacement_cm) &&
            iszero(wall_displacement_cm[begin]) &&
            iszero(wall_displacement_cm[end]) &&
            iszero(wall_velocity_cm_s[begin]) &&
            iszero(wall_velocity_cm_s[end]) || throw(ArgumentError(
                "native resolved-FSI partitioned restart wall endpoints must be clamped",
            ))
        velocity_dofs_previous = Float64[Float64(value) for value in restart_state.velocity_free_dof_values]
        isempty(velocity_dofs_previous) && throw(ArgumentError(
            "native resolved-FSI partitioned restart velocity_free_dof_values must not be empty",
        ))
        max_picard_iterations_used = Int(restart_state.max_picard_iterations_used)
        final_picard_update_norm = Float64(restart_state.final_picard_update_norm)
        picard_converged = Bool(restart_state.picard_converged)
        pressure_projection_fallback_count = Int(restart_state.pressure_projection_fallback_count)
        minimum_signed_tetra_volume6 = Float64(restart_state.minimum_signed_tetra_volume6)
        max_coupling_iterations_used = Int(restart_state.max_coupling_iterations_used)
        final_coupling_displacement_residual_cm =
            Float64(restart_state.final_coupling_displacement_residual_cm)
        coupling_converged = Bool(restart_state.coupling_converged)
        coupling_residual_history = copy(restart_state.coupling_residual_history)
        restart_fluid_wall_boundary_mode = Symbol(restart_state.fluid_wall_boundary_mode)
        restart_fluid_wall_boundary_mode === fluid_wall_boundary_mode || throw(ArgumentError(
            "native resolved-FSI partitioned restart fluid wall boundary mode does not match resumed controls",
        ))
        minimum_signed_tetra_volume6 = native_resolved_fsi_partitioned_smoke_validate_deformed_mesh(
            mesh,
            mesh.coordinates .+ native_resolved_fsi_lifted_displacement(mesh, wall_displacement_cm),
            current_radii_cm,
        )
    end

    for snapshot_time_s in requested_snapshot_times_s
        while time_s < snapshot_time_s
            step_phase_timing = native_resolved_fsi_phase_timing_accumulator()
            step_start_ns = time_ns()
            dt_step = min(spec.dt_s, snapshot_time_s - time_s)
            step_index = time_step_count + 1
            step_start_displacement_cm = solve_workspace.step_start_displacement_cm
            step_start_velocity_cm_s = solve_workspace.step_start_velocity_cm_s
            iteration_displacement_cm = solve_workspace.iteration_displacement_cm
            iteration_velocity_cm_s = solve_workspace.iteration_velocity_cm_s
            iteration_radii_cm = solve_workspace.iteration_radii_cm
            copyto!(step_start_displacement_cm, wall_displacement_cm)
            copyto!(step_start_velocity_cm_s, wall_velocity_cm_s)
            copyto!(iteration_displacement_cm, wall_displacement_cm)
            copyto!(iteration_velocity_cm_s, wall_velocity_cm_s)
            copyto!(iteration_radii_cm, current_radii_cm)
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
                wall_velocity_at_z = native_resolved_fsi_partitioned_wall_velocity_at(
                    fluid_wall_boundary_mode,
                    wall_axial_coordinates_cm,
                    iteration_velocity_cm_s,
                )
                fluid_start_ns = time_ns()
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
                    gridap_context=gridap_context_value,
                )
                native_resolved_fsi_record_fluid_solve_phase_timing!(
                    fluid_state.phase_timing_s,
                    fluid_start_ns,
                    phase_timing,
                    step_phase_timing,
                )
                coupling_velocity_dofs = native_resolved_fsi_copy_free_dof_values(fluid_state.velocity)
                pressure_start_ns = time_ns()
                physical_wall_forcing_pressure_dyn_cm2, step_pressure_fallback_count =
                    native_resolved_fsi_partitioned_physical_wall_pressure_profile(
                        mesh,
                        fluid_state.pressure,
                        iteration_radii_cm;
                        coordinates=deformed_coordinates,
                        wall_radius_at_z=wall_radius_at_z,
                        pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
                        allow_pressure_fallback=
                            controls.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke,
                    )
                native_resolved_fsi_record_phase_elapsed!(
                    :wall_pressure_sampling_s,
                    pressure_start_ns,
                    phase_timing,
                    step_phase_timing,
                )
                pressure_projection_fallback_count += step_pressure_fallback_count

                candidate_displacement_cm = solve_workspace.candidate_displacement_cm
                candidate_velocity_cm_s = solve_workspace.candidate_velocity_cm_s
                candidate_radii_cm = solve_workspace.candidate_radii_cm
                copyto!(candidate_displacement_cm, step_start_displacement_cm)
                copyto!(candidate_velocity_cm_s, step_start_velocity_cm_s)
                copyto!(candidate_radii_cm, reference_radii_cm)
                wall_update_start_ns = time_ns()
                try
                    native_resolved_fsi_partitioned_wall_state!(
                        candidate_displacement_cm,
                        candidate_velocity_cm_s,
                        candidate_radii_cm,
                        reference_radii_cm,
                        physical_wall_forcing_pressure_dyn_cm2,
                        wall_mass_g_cm2,
                        wall_stiffness_c0_dyn_cm3,
                        spec.wall_damping_g_cm2_s,
                        dt_step,
                    )
                catch error
                    diagnostics = native_resolved_fsi_partitioned_wall_update_diagnostics(
                        wall_axial_coordinates_cm,
                        reference_radii_cm,
                        physical_wall_forcing_pressure_dyn_cm2,
                        candidate_displacement_cm,
                        candidate_velocity_cm_s,
                        candidate_radii_cm,
                        wall_mass_g_cm2,
                        wall_stiffness_c0_dyn_cm3,
                        spec.wall_damping_g_cm2_s,
                        dt_step;
                        radius_label="candidate_radius_cm",
                    )
                    throw(ArgumentError(
                        "native resolved-FSI partitioned smoke wall-update guard failed at time step $(step_index), coupling iteration $(coupling_iteration): $(sprint(showerror, error)); $(diagnostics)",
                    ))
                end
                native_resolved_fsi_record_phase_elapsed!(
                    :wall_update_s,
                    wall_update_start_ns,
                    phase_timing,
                    step_phase_timing,
                )

                relaxed_displacement_cm = solve_workspace.relaxed_displacement_cm
                relaxed_velocity_cm_s = solve_workspace.relaxed_velocity_cm_s
                relaxed_radii_cm = solve_workspace.relaxed_radii_cm
                @. relaxed_displacement_cm =
                    iteration_displacement_cm +
                    spec.coupling_under_relaxation * (candidate_displacement_cm - iteration_displacement_cm)
                @. relaxed_velocity_cm_s =
                    iteration_velocity_cm_s +
                    spec.coupling_under_relaxation * (candidate_velocity_cm_s - iteration_velocity_cm_s)
                clamp_membrane_endpoints!(relaxed_displacement_cm)
                clamp_membrane_endpoints!(relaxed_velocity_cm_s)
                @. relaxed_radii_cm = reference_radii_cm + relaxed_displacement_cm
                all(isfinite, relaxed_displacement_cm) || throw(ArgumentError(
                    "native resolved-FSI partitioned smoke produced non-finite relaxed displacement at time step $(step_index), coupling iteration $(coupling_iteration)",
                ))
                all(isfinite, relaxed_velocity_cm_s) || throw(ArgumentError(
                    "native resolved-FSI partitioned smoke produced non-finite relaxed wall velocity at time step $(step_index), coupling iteration $(coupling_iteration)",
                ))
                if minimum(relaxed_radii_cm) <= 0.0
                    diagnostics = native_resolved_fsi_partitioned_wall_update_diagnostics(
                        wall_axial_coordinates_cm,
                        reference_radii_cm,
                        physical_wall_forcing_pressure_dyn_cm2,
                        relaxed_displacement_cm,
                        relaxed_velocity_cm_s,
                        relaxed_radii_cm,
                        wall_mass_g_cm2,
                        wall_stiffness_c0_dyn_cm3,
                        spec.wall_damping_g_cm2_s,
                        dt_step;
                        radius_label="relaxed_radius_cm",
                    )
                    throw(ArgumentError(
                        "native resolved-FSI partitioned smoke produced a non-positive relaxed radius at time step $(step_index), coupling iteration $(coupling_iteration); $(diagnostics)",
                    ))
                end

                step_coupling_residual_cm =
                    native_resolved_fsi_max_abs_difference(relaxed_displacement_cm, iteration_displacement_cm)
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
            coupling_converged = coupling_converged && step_coupling_converged
            time_s += dt_step
            time_step_count += 1
            max_picard_iterations_used = max(max_picard_iterations_used, fluid_state.max_picard_iterations_used)
            final_picard_update_norm = fluid_state.final_picard_update_norm
            picard_converged = picard_converged && fluid_state.picard_converged
            native_resolved_fsi_record_phase_elapsed!(
                :step_total_s,
                step_start_ns,
                phase_timing,
                step_phase_timing,
            )
            if progress_callback !== nothing
                wall_state_finite =
                    all(isfinite, wall_displacement_cm) &&
                    all(isfinite, wall_velocity_cm_s) &&
                    all(isfinite, physical_wall_forcing_pressure_dyn_cm2) &&
                    all(isfinite, current_radii_cm)
                progress_callback((
                    event="time_step_completed",
                    time_step_index=time_step_count,
                    expected_time_step_count=expected_time_step_count,
                    snapshot_time_s=snapshot_time_s,
                    time_s=time_s,
                    dt_s=dt_step,
                    minimum_current_radius_cm=minimum(current_radii_cm),
                    minimum_signed_tetra_volume6=minimum_signed_tetra_volume6,
                    wall_displacement_min_cm=minimum(wall_displacement_cm),
                    wall_displacement_max_cm=maximum(wall_displacement_cm),
                    wall_pressure_min_dyn_cm2=minimum(physical_wall_forcing_pressure_dyn_cm2),
                    wall_pressure_max_dyn_cm2=maximum(physical_wall_forcing_pressure_dyn_cm2),
                    physical_wall_forcing_pressure_min_dyn_cm2=minimum(physical_wall_forcing_pressure_dyn_cm2),
                    physical_wall_forcing_pressure_max_dyn_cm2=maximum(physical_wall_forcing_pressure_dyn_cm2),
                    pressure_gauge_convention="outlet_gauge_normalization_export_only_not_membrane_forcing",
                    field_finite_status=wall_state_finite ?
                                        "wall_state_finite_fluid_refresh_pending" :
                                        "nonfinite_wall_state",
                    final_coupling_displacement_residual_cm=final_coupling_displacement_residual_cm,
                    step_coupling_converged=step_coupling_converged,
                    coupling_converged=coupling_converged,
                    max_coupling_iterations_used=max_coupling_iterations_used,
                    pressure_projection_fallback_count=pressure_projection_fallback_count,
                    fluid_wall_boundary_mode=string(fluid_wall_boundary_mode),
                    inlet_outlet_boundary_mode=string(controls.inlet_outlet_boundary_mode),
                    solver_diagnostics=fluid_state.solver_diagnostics,
                    phase_timing_s=native_resolved_fsi_phase_timing_named_tuple(step_phase_timing),
                ))
            end
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
        wall_velocity_at_z = native_resolved_fsi_partitioned_wall_velocity_at(
            fluid_wall_boundary_mode,
            wall_axial_coordinates_cm,
            wall_velocity_cm_s,
        )
        refresh_dt = min(spec.dt_s, snapshot_time_s)
        refresh_start_ns = time_ns()
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
            gridap_context=gridap_context_value,
        )
        native_resolved_fsi_record_fluid_solve_phase_timing!(
            fluid_state.phase_timing_s,
            refresh_start_ns,
            phase_timing,
        )
        velocity_dofs_previous = native_resolved_fsi_copy_free_dof_values(fluid_state.velocity)
        max_picard_iterations_used = max(max_picard_iterations_used, fluid_state.max_picard_iterations_used)
        final_picard_update_norm = fluid_state.final_picard_update_norm
        picard_converged = picard_converged && fluid_state.picard_converged
        refresh_pressure_start_ns = time_ns()
        physical_wall_forcing_pressure_dyn_cm2, refresh_pressure_fallback_count =
            native_resolved_fsi_partitioned_physical_wall_pressure_profile(
                mesh,
                fluid_state.pressure,
                current_radii_cm;
                coordinates=final_deformed_coordinates,
                wall_radius_at_z=wall_radius_at_z,
                pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
                allow_pressure_fallback=
                    controls.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke,
            )
        native_resolved_fsi_record_phase_elapsed!(:wall_pressure_sampling_s, refresh_pressure_start_ns, phase_timing)
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
            copy(physical_wall_forcing_pressure_dyn_cm2),
            copy(current_radii_cm),
            wall_mass_g_cm2,
            wall_stiffness_c0_dyn_cm3,
            stability_dt_limit_s,
            minimum_signed_tetra_volume6,
            pressure_projection_fallback_count,
            fluid_state.solver_diagnostics,
            native_resolved_fsi_phase_timing_named_tuple(phase_timing),
        ))
        if progress_callback !== nothing
            progress_callback((
                event="snapshot_completed",
                time_step_index=time_step_count,
                expected_time_step_count=expected_time_step_count,
                snapshot_time_s=snapshot_time_s,
                time_s=snapshot_time_s,
                dt_s=refresh_dt,
                minimum_current_radius_cm=minimum(current_radii_cm),
                minimum_signed_tetra_volume6=minimum_signed_tetra_volume6,
                wall_displacement_min_cm=minimum(wall_displacement_cm),
                wall_displacement_max_cm=maximum(wall_displacement_cm),
                wall_pressure_min_dyn_cm2=minimum(physical_wall_forcing_pressure_dyn_cm2),
                wall_pressure_max_dyn_cm2=maximum(physical_wall_forcing_pressure_dyn_cm2),
                physical_wall_forcing_pressure_min_dyn_cm2=minimum(physical_wall_forcing_pressure_dyn_cm2),
                physical_wall_forcing_pressure_max_dyn_cm2=maximum(physical_wall_forcing_pressure_dyn_cm2),
                pressure_gauge_convention="outlet_gauge_normalization_export_only_not_membrane_forcing",
                field_finite_status="snapshot_fluid_refresh_completed",
                final_coupling_displacement_residual_cm=final_coupling_displacement_residual_cm,
                step_coupling_converged=coupling_converged,
                coupling_converged=coupling_converged,
                max_coupling_iterations_used=max_coupling_iterations_used,
                pressure_projection_fallback_count=pressure_projection_fallback_count,
                fluid_wall_boundary_mode=string(fluid_wall_boundary_mode),
                inlet_outlet_boundary_mode=string(controls.inlet_outlet_boundary_mode),
                solver_diagnostics=fluid_state.solver_diagnostics,
                phase_timing_s=native_resolved_fsi_phase_timing_named_tuple(phase_timing),
            ))
        end
    end

    return snapshots
end
