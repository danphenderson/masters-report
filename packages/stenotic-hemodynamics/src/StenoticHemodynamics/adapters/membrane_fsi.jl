abstract type AbstractMembraneWallMode end

struct QuasiStaticMembraneMode <: AbstractMembraneWallMode end

struct DynamicMembraneMode <: AbstractMembraneWallMode
    wall_density::Float64
    dt::Float64
    tfinal::Float64
end

DynamicMembraneMode(; wall_density::Real = 1.0, dt::Real = 1.0e-5, tfinal::Real = 1.0e-4) =
    DynamicMembraneMode(Float64(wall_density), Float64(dt), Float64(tfinal))

wall_mode_name(::QuasiStaticMembraneMode) = "quasi-static-membrane"
wall_mode_name(::DynamicMembraneMode) = "dynamic-membrane"

struct MembraneFSICouplingOptions{F}
    max_iterations::Int
    tolerance_cm::Float64
    damping::Float64
    reference_radius::Float64
    reference_radius_at_z::F
    history_stride::Int
end

function MembraneFSICouplingOptions(
    p::Params;
    max_iterations::Int = 12,
    tolerance_cm::Real = 1.0e-7,
    damping::Real = 0.5,
    reference_radius::Real = wall_reference_radius(p),
    reference_radius_at_z = z -> stenosis(Float64(z), p)[1],
    history_stride::Int = 1,
)
    max_iterations >= 1 || throw(ArgumentError("max_iterations must be positive"))
    tolerance = Float64(tolerance_cm)
    tolerance > 0.0 || throw(ArgumentError("tolerance_cm must be positive"))
    damping_value = Float64(damping)
    0.0 < damping_value <= 1.0 || throw(ArgumentError("damping must lie in (0, 1]"))
    radius = Float64(reference_radius)
    radius > 0.0 || throw(ArgumentError("reference_radius must be positive"))
    history_stride >= 1 || throw(ArgumentError("history_stride must be positive"))
    return MembraneFSICouplingOptions(
        max_iterations,
        tolerance,
        damping_value,
        radius,
        reference_radius_at_z,
        history_stride,
    )
end

Base.@kwdef struct MembraneFSIHistoryRow
    step::Int
    time_s::Float64
    residual_cm::Float64
    displacement_min_cm::Float64
    displacement_max_cm::Float64
    current_radius_min_cm::Float64
    current_radius_max_cm::Float64
    wall_pressure_min_dyn_cm2::Float64
    wall_pressure_max_dyn_cm2::Float64
    wall_velocity_min_cm_s::Float64
    wall_velocity_max_cm_s::Float64
end

struct MembraneFSISolution
    mesh::GeneratedStokesMesh
    stokes_solution::StationaryStokesSolution
    z::Vector{Float64}
    reference_radius::Vector{Float64}
    displacement::Vector{Float64}
    current_radius::Vector{Float64}
    wall_velocity::Vector{Float64}
    wall_force::Vector{Float64}
    wall_pressure::Vector{Float64}
    iterations::Int
    time_s::Float64
    time_step_count::Int
    residual::Float64
    converged::Bool
    elapsed_s::Float64
    history::Vector{MembraneFSIHistoryRow}
end

function canic_membrane_c0(p::Params; reference_radius::Real = wall_reference_radius(p))::Float64
    radius = Float64(reference_radius)
    radius > 0.0 || throw(ArgumentError("membrane reference radius must be positive"))
    return wall_stiffness(p) / radius^2
end

function clamped_membrane_displacement(
    wall_force::AbstractVector{<:Real},
    p::Params;
    reference_radius::Real = wall_reference_radius(p),
)
    c0 = canic_membrane_c0(p; reference_radius=reference_radius)
    displacement = [Float64(force) / c0 for force in wall_force]
    !isempty(displacement) || return displacement
    displacement[begin] = 0.0
    displacement[end] = 0.0
    return displacement
end

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

function profile_interpolator(z_nodes::Vector{Float64}, values::Vector{Float64})
    length(z_nodes) == length(values) || throw(DimensionMismatch("profile interpolation arrays must match"))
    return z -> profile_value_at(z_nodes, values, clamp(Float64(z), z_nodes[begin], z_nodes[end]))
end

function profile_value_at(z_nodes::Vector{Float64}, values::Vector{Float64}, z::Float64)
    z <= z_nodes[begin] && return values[begin]
    z >= z_nodes[end] && return values[end]
    hi = searchsortedfirst(z_nodes, z)
    lo = hi - 1
    weight = (z - z_nodes[lo]) / (z_nodes[hi] - z_nodes[lo])
    return (1.0 - weight) * values[lo] + weight * values[hi]
end

function membrane_stokes_state(
    p::Params,
    ic::StationaryStokesIC,
    z_nodes::Vector{Float64},
    current_radii::Vector{Float64},
)
    any(radius -> radius <= 0.0, current_radii) &&
        throw(ArgumentError("membrane FSI produced a non-positive lumen radius"))
    radius_at_z = profile_interpolator(z_nodes, current_radii)
    mesh = generated_stokes_mesh(p, ic; radius_at_z=radius_at_z)
    solution = solve_stationary_stokes_on_mesh(p, ic, mesh; wall_radius_at_z=radius_at_z)
    wall_pressure = membrane_wall_pressure_profile(solution, p, ic, z_nodes, current_radii)
    return solution, wall_pressure, copy(wall_pressure)
end

function membrane_wall_pressure_profile(
    solution::StationaryStokesSolution,
    p::Params,
    ic::StationaryStokesIC,
    z_nodes::Vector{Float64},
    current_radii::Vector{Float64},
)
    fallback = membrane_pressure_fallback_profile(p, ic, z_nodes, current_radii)
    pressure_values = similar(z_nodes)
    for (i, z) in pairs(z_nodes)
        pressure_values[i] = safe_membrane_wall_pressure(solution, ic, z, current_radii[i], fallback[i])
    end
    return gauge_normalized_pressure_profile(pressure_values)
end

function gauge_normalized_pressure_profile(pressure_values::Vector{Float64})
    isempty(pressure_values) && return pressure_values
    outlet_pressure = pressure_values[end]
    isfinite(outlet_pressure) || (outlet_pressure = 0.0)
    return pressure_values .- outlet_pressure
end

function safe_membrane_wall_pressure(
    solution::StationaryStokesSolution,
    ic::StationaryStokesIC,
    z::Float64,
    radius::Float64,
    fallback::Float64,
)
    acc = 0.0
    count = 0
    sample_radius = radius * (1.0 - 1.0e-8)
    for a in 1:ic.mesh_ntheta
        theta = 2.0 * pi * (a - 0.5) / ic.mesh_ntheta
        value = try
            Float64(solution.pressure(Point(sample_radius * cos(theta), sample_radius * sin(theta), z)))
        catch
            NaN
        end
        if isfinite(value)
            acc += value
            count += 1
        end
    end
    return count > 0 ? acc / count : fallback
end

function membrane_pressure_fallback_profile(
    p::Params,
    ic::StationaryStokesIC,
    z_nodes::Vector{Float64},
    current_radii::Vector{Float64},
)
    radius_at_z = profile_interpolator(z_nodes, current_radii)
    total = membrane_resistance_integral(p.length_cm, radius_at_z)
    total > 0.0 || return fill(NaN, length(z_nodes))
    return [
        ic.pressure_drop_dyn_cm2 * membrane_resistance_integral(p.length_cm - z, zeta -> radius_at_z(z + zeta)) / total
        for z in z_nodes
    ]
end

function membrane_resistance_integral(length_cm::Float64, radius_at_z; samples::Int = 400)
    length_cm <= 0.0 && return 0.0
    dz = length_cm / samples
    accum = 0.0
    for j in 0:samples
        z = j * dz
        radius = stokes_mesh_radius(radius_at_z, z)
        weight = (j == 0 || j == samples) ? 0.5 : 1.0
        accum += weight / radius^4
    end
    return accum * dz
end

function clamp_membrane_endpoints!(values::Vector{Float64})
    isempty(values) && return values
    values[begin] = 0.0
    values[end] = 0.0
    return values
end

function maybe_push_membrane_history!(
    history::Vector{MembraneFSIHistoryRow},
    step::Int,
    time_s::Float64,
    residual::Float64,
    displacement::Vector{Float64},
    current_radii::Vector{Float64},
    wall_pressure::Vector{Float64},
    wall_velocity::Vector{Float64},
)
    push!(
        history,
        MembraneFSIHistoryRow(
            step=step,
            time_s=time_s,
            residual_cm=residual,
            displacement_min_cm=minimum(displacement),
            displacement_max_cm=maximum(displacement),
            current_radius_min_cm=minimum(current_radii),
            current_radius_max_cm=maximum(current_radii),
            wall_pressure_min_dyn_cm2=minimum(wall_pressure),
            wall_pressure_max_dyn_cm2=maximum(wall_pressure),
            wall_velocity_min_cm_s=minimum(wall_velocity),
            wall_velocity_max_cm_s=maximum(wall_velocity),
        ),
    )
    return history
end

function should_capture_membrane_history(step::Int, stride::Int, force::Bool)
    return force || step == 1 || step % stride == 0
end

function maybe_push_membrane_history!(
    history::Vector{MembraneFSIHistoryRow},
    step::Int,
    time_s::Float64,
    residual::Float64,
    displacement::Vector{Float64},
    current_radii::Vector{Float64},
    wall_pressure::Vector{Float64},
    wall_velocity::Vector{Float64},
    stride::Int,
    force::Bool,
)
    should_capture_membrane_history(step, stride, force) || return history
    return maybe_push_membrane_history!(
        history,
        step,
        time_s,
        residual,
        displacement,
        current_radii,
        wall_pressure,
        wall_velocity,
    )
end
