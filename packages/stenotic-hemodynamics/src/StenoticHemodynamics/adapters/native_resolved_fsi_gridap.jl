function native_resolved_fsi_gridap_model(
    mesh::NativeResolvedFSIMesh;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
)
    size(coordinates, 1) == size(mesh.coordinates, 1) ||
        throw(DimensionMismatch("native resolved-FSI Gridap coordinates must match the mesh node count"))
    size(coordinates, 2) == 3 || throw(DimensionMismatch("native resolved-FSI Gridap coordinates must have 3 columns"))
    points = [Point(Float64(coordinates[row, 1]), Float64(coordinates[row, 2]), Float64(coordinates[row, 3])) for row in axes(coordinates, 1)]
    cell_node_ids = Table([Int32[mesh.topology[row, 1], mesh.topology[row, 2], mesh.topology[row, 3], mesh.topology[row, 4]] for row in axes(mesh.topology, 1)])
    reffes = [LagrangianRefFE(Float64, TET, 1)]
    cell_types = fill(Int8(1), size(mesh.topology, 1))
    grid = UnstructuredGrid(points, cell_node_ids, reffes, cell_types, Oriented())
    model = UnstructuredDiscreteModel(grid)
    labels = get_face_labeling(model)
    topo = get_grid_topology(model)

    length_cm = mesh.case_spec.length_cm
    ztol = max(length_cm, 1.0) * 1.0e-10
    rtol = max(mesh.case_spec.rmax_cm, 1.0) * 1.0e-8
    merge!(labels, face_labeling_from_vertex_filter(topo, "inlet", x -> abs(Float64(x[3])) <= ztol))
    merge!(labels, face_labeling_from_vertex_filter(topo, "outlet", x -> abs(Float64(x[3]) - length_cm) <= ztol))
    merge!(
        labels,
        face_labeling_from_vertex_filter(topo, "wall", x -> begin
            z = clamp(Float64(x[3]), 0.0, length_cm)
            radius = Float64(wall_radius_at_z(z))
            abs(hypot(Float64(x[1]), Float64(x[2])) - radius) <= rtol
        end),
    )
    return model, labels
end

function native_resolved_fsi_radial_wall_velocity_function(mesh::NativeResolvedFSIMesh, wall_velocity_at)
    length_cm = mesh.case_spec.length_cm
    radial_eps = max(mesh.case_spec.rmax_cm, 1.0) * 1.0e-12
    return function prescribed_radial_wall_velocity(x)
        x1 = Float64(x[1])
        x2 = Float64(x[2])
        z = clamp(Float64(x[3]), 0.0, length_cm)
        radial_distance = hypot(x1, x2)
        radial_distance > radial_eps || return VectorValue(0.0, 0.0, 0.0)
        radial_speed = Float64(wall_velocity_at(z))
        isfinite(radial_speed) || throw(ArgumentError(
            "native resolved-FSI Navier-Stokes wall velocity profile must return finite values",
        ))
        return VectorValue(
            radial_speed * x1 / radial_distance,
            radial_speed * x2 / radial_distance,
            0.0,
        )
    end
end

function native_resolved_fsi_inlet_outlet_boundary_mode(value::Union{Symbol,AbstractString})
    mode = Symbol(value)
    mode in NATIVE_RESOLVED_FSI_INLET_OUTLET_BOUNDARY_MODES ||
        throw(ArgumentError(
            "unsupported native resolved-FSI inlet/outlet boundary mode $(repr(mode)); " *
            "supported modes are $(NATIVE_RESOLVED_FSI_INLET_OUTLET_BOUNDARY_MODES)",
        ))
    return mode
end

function native_resolved_fsi_section41_poiseuille_inlet_velocity_function(
    mesh::NativeResolvedFSIMesh,
    wall_radius_at_z,
    inlet_umax_cm_s::Real,
)
    umax = Float64(inlet_umax_cm_s)
    isfinite(umax) ||
        throw(ArgumentError("native resolved-FSI Section 4.1 inlet_umax_cm_s must be finite"))
    umax > 0.0 ||
        throw(ArgumentError("native resolved-FSI Section 4.1 inlet_umax_cm_s must be positive"))
    length_cm = mesh.case_spec.length_cm
    return function poiseuille_inlet_velocity(x)
        z = clamp(Float64(x[3]), 0.0, length_cm)
        radius = Float64(wall_radius_at_z(z))
        isfinite(radius) ||
            throw(ArgumentError("native resolved-FSI Section 4.1 inlet radius must be finite"))
        radius > 0.0 ||
            throw(ArgumentError("native resolved-FSI Section 4.1 inlet radius must be positive"))
        radial_fraction = clamp(hypot(Float64(x[1]), Float64(x[2])) / radius, 0.0, 1.0)
        return VectorValue(0.0, 0.0, umax * max(0.0, 1.0 - radial_fraction^2))
    end
end

function native_resolved_fsi_inlet_outlet_boundary_status(
    mode::Symbol;
    inlet_umax_cm_s::Real,
)
    if mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
        return "pressure_drop_weak_inlet_outlet_gauge_smoke active: weak pressure-drop inlet loading " *
               "with Gridap zero-mean pressure constraint and post-sampling outlet-gauge pressure normalization; " *
               "local smoke boundary evidence only, " *
               "not exact Section 4.1 Poiseuille inlet / zero-outlet-stress reproduction"
    end
    if mode === :poiseuille_inlet_zero_outlet_stress_section41
        return "poiseuille_inlet_zero_outlet_stress_section41 active: strong inlet Dirichlet " *
               "Poiseuille profile with u_max=$(Float64(inlet_umax_cm_s)) cm/s, zero outlet stress " *
               "as the natural traction boundary, Gridap zero-mean pressure constraint, " *
               "post-sampling outlet pressure gauge normalization, and no pressure-drop weak inlet/outlet loading"
    end
    throw(ArgumentError("unsupported native resolved-FSI inlet/outlet boundary mode $(repr(mode))"))
end

function native_resolved_fsi_solve_fixed_wall_stokes(mesh::NativeResolvedFSIMesh, spec::NativeResolvedFSISmokeSpec)
    params = Params(severity=mesh.case_spec.severity_percent, tfinal=spec.saved_time_s, initial_condition=GeometryRestIC())
    mu = params.rho * params.nu
    mu > 0.0 || throw(ArgumentError("native resolved-FSI smoke requires positive dynamic viscosity rho*nu"))

    model, labels = native_resolved_fsi_gridap_model(mesh)
    order = 2
    reffe_u = ReferenceFE(lagrangian, VectorValue{3,Float64}, order)
    reffe_p = ReferenceFE(lagrangian, Float64, order - 1)
    zero_velocity(x) = VectorValue(0.0, 0.0, 0.0)
    V = TestFESpace(model, reffe_u, labels=labels, dirichlet_tags="wall", conformity=:H1)
    Q = TestFESpace(model, reffe_p, labels=labels, conformity=:H1)
    U = TrialFESpace(V, zero_velocity)
    P = TrialFESpace(Q)
    X = MultiFieldFESpace([U, P])
    Y = MultiFieldFESpace([V, Q])

    Ω = Triangulation(model)
    Γin = BoundaryTriangulation(model, labels, tags="inlet")
    Γout = BoundaryTriangulation(model, labels, tags="outlet")
    n_in = get_normal_vector(Γin)
    n_out = get_normal_vector(Γout)
    degree = 2 * order
    dΩ = Measure(Ω, degree)
    dΓin = Measure(Γin, degree)
    dΓout = Measure(Γout, degree)

    a((u, pfield), (v, q)) = ∫(mu * (∇(v) ⊙ ∇(u)) - (∇ ⋅ v) * pfield + q * (∇ ⋅ u)) * dΩ
    l((v, q)) = ∫(-spec.pressure_drop_dyn_cm2 * (v ⋅ n_in)) * dΓin + ∫(-0.0 * (v ⋅ n_out)) * dΓout

    velocity_h, pressure_h = solve(AffineFEOperator(a, l, X, Y))
    return NativeResolvedFSIStokesSmokeSolve(
        velocity_h,
        pressure_h,
        length(get_free_dof_values(velocity_h)),
        length(get_free_dof_values(pressure_h)),
    )
end

function native_resolved_fsi_solve_fixed_wall_navier_stokes(
    mesh::NativeResolvedFSIMesh,
    spec::NativeResolvedFSINavierStokesSmokeSpec,
)
    controls = native_resolved_fsi_navier_stokes_controls(spec)
    return native_resolved_fsi_solve_navier_stokes(
        mesh;
        dt_s=controls.dt_s,
        tfinal_s=controls.tfinal_s,
        pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
        picard_iteration_count=controls.picard_iteration_count,
        picard_tolerance=controls.picard_tolerance,
    )
end

function native_resolved_fsi_navier_stokes_controls(spec::NativeResolvedFSINavierStokesSmokeSpec)
    return (
        dt_s=spec.dt_s,
        tfinal_s=spec.tfinal_s,
        pressure_drop_dyn_cm2=spec.pressure_drop_dyn_cm2,
        picard_iteration_count=spec.picard_iteration_count,
        picard_tolerance=spec.picard_tolerance,
    )
end

function native_resolved_fsi_navier_stokes_controls(spec::NativeResolvedFSIPartitionedSmokeSpec)
    return (
        dt_s=spec.dt_s,
        tfinal_s=spec.tfinal_s,
        inlet_outlet_boundary_mode=spec.inlet_outlet_boundary_mode,
        inlet_umax_cm_s=spec.inlet_umax_cm_s,
        pressure_drop_dyn_cm2=spec.pressure_drop_dyn_cm2,
        picard_iteration_count=spec.picard_iteration_count,
        picard_tolerance=spec.picard_tolerance,
    )
end

function native_resolved_fsi_solve_navier_stokes(
    mesh::NativeResolvedFSIMesh;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString} = :pressure_drop_weak_inlet_outlet_gauge_smoke,
    inlet_umax_cm_s::Real = NATIVE_RESOLVED_FSI_SECTION41_INLET_UMAX_CM_S,
    dt_s::Real,
    tfinal_s::Real,
    pressure_drop_dyn_cm2::Real,
    picard_iteration_count::Integer,
    picard_tolerance::Real,
    initial_velocity_dofs = nothing,
    wall_velocity_at = nothing,
)
    dt_value = Float64(dt_s)
    tfinal_value = Float64(tfinal_s)
    pressure_drop_value = Float64(pressure_drop_dyn_cm2)
    picard_iteration_count_value = Int(picard_iteration_count)
    picard_tolerance_value = Float64(picard_tolerance)
    inlet_outlet_boundary_mode_value = native_resolved_fsi_inlet_outlet_boundary_mode(inlet_outlet_boundary_mode)
    inlet_umax_value = Float64(inlet_umax_cm_s)
    dt_value > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes dt_s must be positive"))
    tfinal_value > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes tfinal_s must be positive"))
    isfinite(pressure_drop_value) || throw(ArgumentError("native resolved-FSI Navier-Stokes pressure_drop_dyn_cm2 must be finite"))
    if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        pressure_drop_value > 0.0 ||
            throw(ArgumentError("native resolved-FSI Navier-Stokes pressure_drop_dyn_cm2 must be positive"))
    end
    isfinite(inlet_umax_value) || throw(ArgumentError("native resolved-FSI Navier-Stokes inlet_umax_cm_s must be finite"))
    if inlet_outlet_boundary_mode_value === :poiseuille_inlet_zero_outlet_stress_section41
        inlet_umax_value > 0.0 ||
            throw(ArgumentError("native resolved-FSI Section 4.1 inlet_umax_cm_s must be positive"))
    end
    picard_iteration_count_value > 0 || throw(ArgumentError("native resolved-FSI Navier-Stokes picard_iteration_count must be positive"))
    isfinite(picard_tolerance_value) || throw(ArgumentError("native resolved-FSI Navier-Stokes picard_tolerance must be finite"))
    picard_tolerance_value > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes picard_tolerance must be positive"))

    params = Params(severity=mesh.case_spec.severity_percent, tfinal=tfinal_value, initial_condition=GeometryRestIC())
    rho = params.rho
    mu = rho * params.nu
    rho > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke requires positive density"))
    mu > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke requires positive dynamic viscosity rho*nu"))

    model, labels = native_resolved_fsi_gridap_model(mesh; coordinates=coordinates, wall_radius_at_z=wall_radius_at_z)
    order = 2
    reffe_u = ReferenceFE(lagrangian, VectorValue{3,Float64}, order)
    reffe_p = ReferenceFE(lagrangian, Float64, order - 1)
    zero_velocity(x) = VectorValue(0.0, 0.0, 0.0)
    wall_velocity_function = if wall_velocity_at === nothing
        zero_velocity
    else
        native_resolved_fsi_radial_wall_velocity_function(mesh, wall_velocity_at)
    end
    inlet_velocity_function = if inlet_outlet_boundary_mode_value === :poiseuille_inlet_zero_outlet_stress_section41
        native_resolved_fsi_section41_poiseuille_inlet_velocity_function(
            mesh,
            wall_radius_at_z,
            inlet_umax_value,
        )
    else
        zero_velocity
    end
    zero_pressure(x) = 0.0
    initial_velocity_function = native_resolved_fsi_navier_stokes_initial_velocity_function(
        mesh,
        inlet_outlet_boundary_mode_value,
        wall_velocity_function,
        inlet_velocity_function,
    )
    V = if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        TestFESpace(model, reffe_u, labels=labels, dirichlet_tags="wall", conformity=:H1)
    else
        TestFESpace(model, reffe_u, labels=labels, dirichlet_tags=["wall", "inlet"], conformity=:H1)
    end
    Q = TestFESpace(model, reffe_p, labels=labels, conformity=:H1, constraint=:zeromean)
    U = if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        TrialFESpace(V, wall_velocity_function)
    else
        TrialFESpace(V, [wall_velocity_function, inlet_velocity_function])
    end
    P = TrialFESpace(Q)
    X = MultiFieldFESpace([U, P])
    Y = MultiFieldFESpace([V, Q])

    Ω = Triangulation(model)
    Γin = BoundaryTriangulation(model, labels, tags="inlet")
    Γout = BoundaryTriangulation(model, labels, tags="outlet")
    n_in = get_normal_vector(Γin)
    n_out = get_normal_vector(Γout)
    degree = 2 * order
    dΩ = Measure(Ω, degree)
    dΓin = Measure(Γin, degree)
    dΓout = Measure(Γout, degree)

    velocity_state = native_resolved_fsi_navier_stokes_initial_velocity_state(U, initial_velocity_function, initial_velocity_dofs)
    pressure_state = interpolate_everywhere(zero_pressure, P)
    time_s = 0.0
    time_step_count = 0
    max_picard_iterations_used = 0
    final_picard_update_norm = 0.0
    picard_converged = true

    while time_s < tfinal_value
        dt_step = min(dt_value, tfinal_value - time_s)
        dt_step > 0.0 || break

        velocity_previous_step = velocity_state
        velocity_iterate = velocity_state
        step_converged = false
        step_iterations_used = 0
        step_update_norm = Inf

        for iteration in 1:picard_iteration_count_value
            velocity_advector = velocity_iterate
            a((u, pfield), (v, q)) =
                ∫(
                    (rho / dt_step) * (v ⋅ u) +
                    mu * (∇(v) ⊙ ∇(u)) +
                    v ⋅ ((∇(u)) ⋅ velocity_advector) -
                    (∇ ⋅ v) * pfield +
                    q * (∇ ⋅ u)
                ) * dΩ
            l((v, q)) =
                if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
                    ∫((rho / dt_step) * (v ⋅ velocity_previous_step)) * dΩ +
                    ∫(-pressure_drop_value * (v ⋅ n_in)) * dΓin +
                    ∫(-0.0 * (v ⋅ n_out)) * dΓout
                else
                    ∫((rho / dt_step) * (v ⋅ velocity_previous_step)) * dΩ +
                    ∫(0.0 * (v ⋅ n_out)) * dΓout
                end

            velocity_next, pressure_next = solve(AffineFEOperator(a, l, X, Y))
            step_update_norm = native_resolved_fsi_smoke_velocity_update_norm(velocity_next, velocity_iterate)
            velocity_scale = max(native_resolved_fsi_smoke_velocity_dof_norm(velocity_next), 1.0)
            velocity_state = velocity_next
            pressure_state = pressure_next
            velocity_iterate = velocity_next
            step_iterations_used = iteration

            if step_update_norm <= picard_tolerance_value * velocity_scale
                step_converged = true
                break
            end
        end

        max_picard_iterations_used = max(max_picard_iterations_used, step_iterations_used)
        final_picard_update_norm = step_update_norm
        picard_converged &= step_converged
        time_s += dt_step
        time_step_count += 1
    end

    time_step_count > 0 ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke produced zero time steps despite positive tfinal_s"))
    isfinite(final_picard_update_norm) ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke Picard update norm must be finite"))

    return NativeResolvedFSINavierStokesSmokeSolve(
        velocity_state,
        pressure_state,
        length(get_free_dof_values(velocity_state)),
        length(get_free_dof_values(pressure_state)),
        time_step_count,
        max_picard_iterations_used,
        final_picard_update_norm,
        picard_converged,
        inlet_outlet_boundary_mode_value,
        inlet_outlet_boundary_mode_value === :poiseuille_inlet_zero_outlet_stress_section41 ? inlet_umax_value : 0.0,
        native_resolved_fsi_inlet_outlet_boundary_status(
            inlet_outlet_boundary_mode_value;
            inlet_umax_cm_s=inlet_umax_value,
        ),
    )
end

function native_resolved_fsi_navier_stokes_initial_velocity_function(
    mesh::NativeResolvedFSIMesh,
    inlet_outlet_boundary_mode::Symbol,
    wall_velocity_function,
    inlet_velocity_function,
)
    inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41 || return wall_velocity_function
    ztol = max(mesh.case_spec.length_cm, 1.0) * 1.0e-10
    return x -> abs(Float64(x[3])) <= ztol ? inlet_velocity_function(x) : wall_velocity_function(x)
end

function native_resolved_fsi_navier_stokes_initial_velocity_state(U, wall_velocity_function, initial_velocity_dofs)
    if initial_velocity_dofs === nothing
        return interpolate_everywhere(wall_velocity_function, U)
    end
    values = Float64[Float64(value) for value in initial_velocity_dofs]
    return FEFunction(U, values)
end

function native_resolved_fsi_smoke_velocity_dof_norm(velocity_h)
    return sqrt(sum(abs2, get_free_dof_values(velocity_h)))
end

function native_resolved_fsi_smoke_velocity_update_norm(velocity_next, velocity_previous)
    return sqrt(sum(abs2, get_free_dof_values(velocity_next) .- get_free_dof_values(velocity_previous)))
end
