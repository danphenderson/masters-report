"""
    solve_quasistatic_membrane_fsi(p, ic; kwargs...)

Convenience entrypoint for the current fixed-point membrane-FSI adapter. This
reuses the generic membrane options constructor and the quasi-static wall mode.
"""
function solve_quasistatic_membrane_fsi(
    p::Params,
    ic::StationaryStokesIC;
    max_iterations::Int = 12,
    tolerance_cm::Real = 1.0e-7,
    damping::Real = 0.5,
    reference_radius::Real = wall_reference_radius(p),
    reference_radius_at_z = z -> stenosis(Float64(z), p)[1],
    history_stride::Int = 1,
)
    options = MembraneFSICouplingOptions(
        p;
        max_iterations,
        tolerance_cm,
        damping,
        reference_radius,
        reference_radius_at_z,
        history_stride,
    )
    return solve_membrane_fsi(QuasiStaticMembraneMode(), p, ic, options)
end

function solve_membrane_fsi(mode::AbstractMembraneWallMode, p::Params, ic::StationaryStokesIC; kwargs...)
    return solve_membrane_fsi(mode, p, ic, MembraneFSICouplingOptions(p; kwargs...))
end

"""
    solve_membrane_fsi(::QuasiStaticMembraneMode, p, ic, options)

Run the current quasi-static membrane-FSI adapter by alternating stationary
Stokes solves and under-relaxed membrane displacement updates.
"""
function solve_membrane_fsi(
    ::QuasiStaticMembraneMode,
    p::Params,
    ic::StationaryStokesIC,
    options::MembraneFSICouplingOptions,
)
    validate(p)
    validate(ic)

    z_nodes = [p.length_cm * j / ic.mesh_nz for j in 0:ic.mesh_nz]
    reference_radii = [stokes_mesh_radius(options.reference_radius_at_z, z) for z in z_nodes]
    displacement = zeros(Float64, length(z_nodes))
    wall_velocity = zeros(Float64, length(z_nodes))
    current_radii = copy(reference_radii)
    final_solution, wall_pressure, wall_force = membrane_stokes_state(p, ic, z_nodes, current_radii)
    residual = Inf
    converged = false
    iteration_count = 0
    history = MembraneFSIHistoryRow[]
    state_matches_current_radii = true

    elapsed = @elapsed begin
        for iteration in 1:options.max_iterations
            iteration_count = iteration
            if !state_matches_current_radii
                final_solution, wall_pressure, wall_force = membrane_stokes_state(p, ic, z_nodes, current_radii)
                state_matches_current_radii = true
            end
            target_displacement = clamped_membrane_displacement(wall_force, p; reference_radius=options.reference_radius)
            updated = similar(displacement)
            for i in eachindex(displacement)
                updated[i] = (1.0 - options.damping) * displacement[i] + options.damping * target_displacement[i]
            end
            residual = maximum(abs.(updated .- displacement))
            displacement = updated
            current_radii = reference_radii .+ displacement
            any(radius -> radius <= 0.0, current_radii) &&
                throw(ArgumentError("quasi-static membrane FSI produced a non-positive lumen radius"))
            state_matches_current_radii = false
            record_history = should_capture_membrane_history(
                iteration,
                options.history_stride,
                iteration == options.max_iterations,
            )
            if residual <= options.tolerance_cm || record_history
                final_solution, wall_pressure, wall_force = membrane_stokes_state(p, ic, z_nodes, current_radii)
                state_matches_current_radii = true
            end
            if record_history
                maybe_push_membrane_history!(
                    history,
                    iteration,
                    NaN,
                    residual,
                    displacement,
                    current_radii,
                    wall_pressure,
                    wall_velocity,
                )
            end
            if residual <= options.tolerance_cm
                converged = true
                break
            end
        end
    end

    if !state_matches_current_radii
        final_solution, wall_pressure, wall_force = membrane_stokes_state(p, ic, z_nodes, current_radii)
    end
    return MembraneFSISolution(
        final_solution.mesh,
        final_solution,
        z_nodes,
        reference_radii,
        displacement,
        current_radii,
        wall_velocity,
        wall_force,
        wall_pressure,
        iteration_count,
        0.0,
        0,
        residual,
        converged,
        elapsed,
        history,
    )
end

"""
    solve_membrane_fsi(mode::DynamicMembraneMode, p, ic, options)

Run the current explicit wall-update adapter. The membrane state is advanced
with a lumped wall mass and stiffness, while each recorded wall state reuses a
stationary Stokes solve for the fluid load.
"""
function solve_membrane_fsi(
    mode::DynamicMembraneMode,
    p::Params,
    ic::StationaryStokesIC,
    options::MembraneFSICouplingOptions,
)
    validate(p)
    validate(ic)
    mode.wall_density > 0.0 || throw(ArgumentError("dynamic membrane wall_density must be positive"))
    mode.dt > 0.0 || throw(ArgumentError("dynamic membrane dt must be positive"))
    mode.tfinal > 0.0 || throw(ArgumentError("dynamic membrane tfinal must be positive"))

    z_nodes = [p.length_cm * j / ic.mesh_nz for j in 0:ic.mesh_nz]
    reference_radii = [stokes_mesh_radius(options.reference_radius_at_z, z) for z in z_nodes]
    displacement = zeros(Float64, length(z_nodes))
    wall_velocity = zeros(Float64, length(z_nodes))
    current_radii = copy(reference_radii)
    final_solution, wall_pressure, wall_force = membrane_stokes_state(p, ic, z_nodes, current_radii)
    history = MembraneFSIHistoryRow[]
    c0 = canic_membrane_c0(p; reference_radius=options.reference_radius)
    wall_mass = mode.wall_density * p.wall_h
    wall_mass > 0.0 || throw(ArgumentError("dynamic membrane wall mass must be positive"))
    stability_dt = 1.9 * sqrt(wall_mass / c0)
    mode.dt <= stability_dt ||
        throw(ArgumentError("dynamic membrane dt=$(mode.dt) exceeds explicit stability limit $(stability_dt)"))

    time_s = 0.0
    step_count = 0
    residual = Inf
    converged = false
    state_matches_current_radii = true
    elapsed = @elapsed begin
        while time_s < mode.tfinal - eps(mode.tfinal)
            dt_step = min(mode.dt, mode.tfinal - time_s)
            step_count += 1
            if !state_matches_current_radii
                final_solution, wall_pressure, wall_force = membrane_stokes_state(p, ic, z_nodes, current_radii)
                state_matches_current_radii = true
            end
            previous = copy(displacement)
            acceleration = (wall_force .- c0 .* displacement) ./ wall_mass
            clamp_membrane_endpoints!(acceleration)
            displacement .= displacement .+ dt_step .* wall_velocity .+ 0.5 * dt_step^2 .* acceleration
            clamp_membrane_endpoints!(displacement)
            wall_velocity .= wall_velocity .+ dt_step .* acceleration
            clamp_membrane_endpoints!(wall_velocity)
            residual = maximum(abs.(displacement .- previous))
            current_radii = reference_radii .+ displacement
            any(radius -> radius <= 0.0, current_radii) &&
                throw(ArgumentError("dynamic membrane FSI produced a non-positive lumen radius"))
            time_s += dt_step
            record_history = should_capture_membrane_history(
                step_count,
                options.history_stride,
                time_s >= mode.tfinal - eps(mode.tfinal),
            )
            state_matches_current_radii = false
            if record_history
                final_solution, wall_pressure, wall_force = membrane_stokes_state(p, ic, z_nodes, current_radii)
                state_matches_current_radii = true
                maybe_push_membrane_history!(
                    history,
                    step_count,
                    time_s,
                    residual,
                    displacement,
                    current_radii,
                    wall_pressure,
                    wall_velocity,
                )
            end
        end
        converged = true
    end

    if !state_matches_current_radii
        final_solution, wall_pressure, wall_force = membrane_stokes_state(p, ic, z_nodes, current_radii)
    end
    return MembraneFSISolution(
        final_solution.mesh,
        final_solution,
        z_nodes,
        reference_radii,
        displacement,
        current_radii,
        wall_velocity,
        wall_force,
        wall_pressure,
        step_count,
        time_s,
        step_count,
        residual,
        converged,
        elapsed,
        history,
    )
end
