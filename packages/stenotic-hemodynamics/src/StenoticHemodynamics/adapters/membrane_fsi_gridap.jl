"""
Gridap-backed helpers for the current membrane-FSI adapter. These functions own
the deformed mesh construction, stationary-Stokes solve, and wall-pressure
sampling/fallback logic.
"""

"""Create a piecewise-linear profile interpolator clamped to the node range."""
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

"""
    membrane_stokes_state(p, ic, z_nodes, current_radii)

Build the deformed lumen geometry, solve the stationary-Stokes problem on that
mesh, and return the current wall-pressure profile plus the adapter's current
wall-load surrogate. At present the wall-load surrogate is the sampled pressure
profile itself.
"""
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

"""
    membrane_wall_pressure_profile(solution, p, ic, z_nodes, current_radii)

Sample the Stokes pressure field slightly inside the wall. If Gridap point
evaluation fails or returns non-finite values, fall back to a resistance-based
pressure profile normalized to zero outlet gauge pressure.
"""
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
    # Gridap point evaluation can fail exactly on coarse-wall boundaries, so
    # sample just inside the lumen and fall back to a resistance profile if no
    # finite samples are available.
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

"""
    membrane_resistance_integral(length_cm, radius_at_z; samples=400)

Evaluate the one-dimensional Poiseuille resistance integral used by the current
pressure fallback and mean-flow reduction.
"""
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
