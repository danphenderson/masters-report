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
        a0 = r0^2

        partial_p2 = p.nu * gp2 * (
            Qi / Ai / r0 * r0zz -
            Qi / Ai / a0 * r0z^2 +
            dQ / Ai / r0 * r0z -
            Qi * dA / Ai^2 / r0 * r0z
        )

        source[i] =
            -2.0 * p.nu * gp2 * (Qi / Ai) +
            stiffness / (p.rho * p.rmax^2) * Ai * r0z -
            Ai * partial_p2 +
            Qi^2 / Ai * alpha_c_z(r0z, r0zz)
    end

    return source
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
        elastic = wall_stiffness(p) / r0^2 * (R - r0)
        viscous = gp2 * p.rho * p.nu * Q[i] / positive_area(A[i]) * (r0z / r0)
        out[i] = elastic + viscous
    end

    return out
end
