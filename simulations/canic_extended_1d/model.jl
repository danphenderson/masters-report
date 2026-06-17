positive_area(A::Float64) = max(A, AREA_FLOOR)

function flux(A::Float64, Q::Float64, z::Float64, p::Params)
    Apos = positive_area(A)
    _, r0z, _ = stenosis(z, p)
    elastic_flux = wall_stiffness(p) / (3.0 * p.rho * p.rmax^2) * Apos^1.5
    return Q, (p.alpha + alpha_c(r0z)) * Q^2 / Apos + elastic_flux
end

function max_wave_speed(A::Float64, Q::Float64, z::Float64, p::Params)
    Apos = positive_area(A)
    _, r0z, _ = stenosis(z, p)
    effective_alpha = p.alpha + alpha_c(r0z)
    u = Q / Apos
    elastic = wall_stiffness(p) / (2.0 * p.rho * p.rmax^2) * sqrt(Apos)
    radicand = (effective_alpha * u)^2 - effective_alpha * u^2 + elastic
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
    stiffness = wall_stiffness(p)

    for i in eachindex(A)
        im = max(i - 1, firstindex(A))
        ip = min(i + 1, lastindex(A))
        dA = (A[ip] - A[im]) / ((ip - im) * dx)
        dQ = (Q[ip] - Q[im]) / ((ip - im) * dx)

        Ai = positive_area(A[i])
        Qi = Q[i]
        r0, r0z, r0zz = stenosis(z[i], p)
        source[i] = source_point(Ai, Qi, z[i], dA, dQ, r0, r0z, r0zz, gp2, stiffness, p)
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
    stiffness::Float64,
    p::Params,
)
    _ = z
    Ai = positive_area(A)
    a0 = r0^2
    nu_eff = effective_kinematic_viscosity(Ai, Q, r0, p)

    partial_p2 = nu_eff * gp2 * (
        Q / Ai / r0 * r0zz -
        Q / Ai / a0 * r0z^2 +
        dQ_dz / Ai / r0 * r0z -
        Q * dA_dz / Ai^2 / r0 * r0z
    )

    return -2.0 * nu_eff * gp2 * (Q / Ai) +
           stiffness / (p.rho * p.rmax^2) * Ai * r0z -
           Ai * partial_p2 +
           Q^2 / Ai * alpha_c_z(r0z, r0zz)
end

function pressure(result::SimulationResult, p::Params)
    return pressure(result.area, result.flow, result.z, p)
end

function pressure(A::AbstractVector{Float64}, Q::AbstractVector{Float64}, z::AbstractVector{Float64}, p::Params)
    gp2 = gamma_plus_two(p)
    out = similar(A)

    for i in eachindex(A)
        r0, r0z, _ = stenosis(z[i], p)
        R = sqrt(positive_area(A[i]))
        nu_eff = effective_kinematic_viscosity(positive_area(A[i]), Q[i], r0, p)
        elastic = wall_stiffness(p) / r0^2 * (R - r0)
        viscous = gp2 * p.rho * nu_eff * Q[i] / positive_area(A[i]) * (r0z / r0)
        out[i] = elastic + viscous
    end

    return out
end
