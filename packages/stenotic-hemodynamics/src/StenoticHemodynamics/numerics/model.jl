positive_area(A::Float64) = max(A, AREA_FLOOR)

function diagnostic_wall_elastic_pressure(::CanicKoiterWallLaw, A::Float64, z::Float64, p::Params)
    r0, _, _ = stenosis(z, p)
    r0_safe = max(r0, sqrt(AREA_LIMITER_FLOOR))
    return wall_elastic_coefficient(p, r0_safe) * (sqrt(positive_area(A)) - r0_safe)
end

diagnostic_wall_elastic_pressure(A::Float64, z::Float64, p::Params) =
    diagnostic_wall_elastic_pressure(p.wall_law, A, z, p)

wall_elastic_pressure(wall_law::CanicKoiterWallLaw, A::Float64, z::Float64, p::Params) =
    diagnostic_wall_elastic_pressure(wall_law, A, z, p)
wall_elastic_pressure(A::Float64, z::Float64, p::Params) = diagnostic_wall_elastic_pressure(A, z, p)

function evolution_wall_elastic_pressure(::CanicKoiterWallLaw, A::Float64, z::Float64, p::Params)
    r0, _, _ = stenosis(z, p)
    r0_safe = max(r0, sqrt(AREA_LIMITER_FLOOR))
    reference_radius = max(wall_reference_radius(p), sqrt(AREA_LIMITER_FLOOR))
    return wall_elastic_coefficient(p, reference_radius) * (sqrt(positive_area(A)) - r0_safe)
end

evolution_wall_elastic_pressure(A::Float64, z::Float64, p::Params) =
    evolution_wall_elastic_pressure(p.wall_law, A, z, p)

function variable_radius_pressure_correction(
    A::Float64,
    Q::Float64,
    r0::Float64,
    r0z::Float64,
    nu_eff::Float64,
    gp2::Float64,
    p::Params,
)
    r0_safe = max(r0, sqrt(AREA_LIMITER_FLOOR))
    return gp2 * p.rho * nu_eff * Q / positive_area(A) * (r0z / r0_safe)
end

function wall_elastic_potential(::CanicKoiterWallLaw, A::Float64, _z::Float64, p::Params)
    return wall_stiffness(p) / (3.0 * p.rho * wall_reference_radius(p)^2) * positive_area(A)^1.5
end

wall_elastic_potential(A::Float64, z::Float64, p::Params) = wall_elastic_potential(p.wall_law, A, z, p)

function wall_wave_speed_squared(::CanicKoiterWallLaw, A::Float64, _z::Float64, p::Params)
    return wall_stiffness(p) / (2.0 * p.rho * wall_reference_radius(p)^2) * sqrt(positive_area(A))
end

wall_wave_speed_squared(A::Float64, z::Float64, p::Params) = wall_wave_speed_squared(p.wall_law, A, z, p)

function wall_geometry_source(::CanicKoiterWallLaw, A::Float64, _z::Float64, _r0::Float64, r0z::Float64, p::Params)
    return wall_stiffness(p) / (p.rho * wall_reference_radius(p)^2) * positive_area(A) * r0z
end

wall_geometry_source(A::Float64, z::Float64, r0::Float64, r0z::Float64, p::Params) =
    wall_geometry_source(p.wall_law, A, z, r0, r0z, p)

function flux(A::Float64, Q::Float64, z::Float64, p::Params)
    Apos = positive_area(A)
    _, r0z, _ = stenosis(z, p)
    return Q, (momentum_alpha(p) + effective_alpha_c(p, r0z)) * Q^2 / Apos + wall_elastic_potential(Apos, z, p)
end

function max_wave_speed(A::Float64, Q::Float64, z::Float64, p::Params)
    Apos = positive_area(A)
    _, r0z, _ = stenosis(z, p)
    effective_alpha = momentum_alpha(p) + effective_alpha_c(p, r0z)
    u = Q / Apos
    radicand = (effective_alpha * u)^2 - effective_alpha * u^2 + wall_wave_speed_squared(Apos, z, p)
    c = sqrt(max(radicand, 0.0))
    return max(abs(effective_alpha * u - c), abs(effective_alpha * u + c))
end

function fill_source!(
    source::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    p::Params,
)
    gp2 = gamma_plus_two(p)

    for i in eachindex(A)
        im = max(i - 1, firstindex(A))
        ip = min(i + 1, lastindex(A))
        dA = (A[ip] - A[im]) / ((ip - im) * dx)
        dQ = (Q[ip] - Q[im]) / ((ip - im) * dx)

        Ai = positive_area(A[i])
        Qi = Q[i]
        r0, r0z, r0zz = stenosis(z[i], p)
        source[i] = source_point(Ai, Qi, z[i], dA, dQ, r0, r0z, r0zz, gp2, p)
    end

    return source
end

function source_point(
    A::Float64,
    Q::Float64,
    z::Float64,
    dA_dz::Float64,
    dQ_dz::Float64,
    r0::Float64,
    r0z::Float64,
    r0zz::Float64,
    gp2::Float64,
    p::Params,
)
    Ai = positive_area(A)
    r0_safe = max(r0, sqrt(AREA_LIMITER_FLOOR))
    a0 = r0_safe^2
    nu_eff = effective_kinematic_viscosity(Ai, Q, r0_safe, p)

    partial_p2 = variable_radius_terms_enabled(p) ? nu_eff * gp2 * (
        Q / Ai / r0_safe * r0zz -
        Q / Ai / a0 * r0z^2 +
        dQ_dz / Ai / r0_safe * r0z -
        Q * dA_dz / Ai^2 / r0_safe * r0z
    ) : 0.0

    return -2.0 * nu_eff * gp2 * (Q / Ai) +
           wall_geometry_source(Ai, z, r0, r0z, p) -
           Ai * partial_p2 +
           Q^2 / Ai * effective_alpha_c_z(p, r0z, r0zz)
end

function evolution_pressure(result::SimulationResult, p::Params)
    return evolution_pressure(result.area, result.flow, result.z, p)
end

function evolution_pressure(A::AbstractVector{Float64}, _Q::AbstractVector{Float64}, z::AbstractVector{Float64}, p::Params)
    out = similar(A)

    for i in eachindex(A)
        Ai = positive_area(A[i])
        out[i] = evolution_wall_elastic_pressure(Ai, z[i], p)
    end

    return out
end

function diagnostic_pressure(result::SimulationResult, p::Params)
    return diagnostic_pressure(result.area, result.flow, result.z, p)
end

function diagnostic_pressure(A::AbstractVector{Float64}, Q::AbstractVector{Float64}, z::AbstractVector{Float64}, p::Params)
    gp2 = gamma_plus_two(p)
    out = similar(A)

    for i in eachindex(A)
        Ai = positive_area(A[i])
        r0, r0z, _ = stenosis(z[i], p)
        r0_safe = max(r0, sqrt(AREA_LIMITER_FLOOR))
        nu_eff = effective_kinematic_viscosity(Ai, Q[i], r0_safe, p)
        correction = variable_radius_terms_enabled(p) ?
                     variable_radius_pressure_correction(Ai, Q[i], r0, r0z, nu_eff, gp2, p) :
                     0.0
        out[i] = diagnostic_wall_elastic_pressure(Ai, z[i], p) + correction
    end

    return out
end

function pressure(args...)
    Base.depwarn("pressure is deprecated; use diagnostic_pressure or evolution_pressure", :pressure)
    return diagnostic_pressure(args...)
end
