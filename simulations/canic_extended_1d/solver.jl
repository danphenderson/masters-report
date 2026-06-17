function initial_state(p::Params)
    dx = p.length_cm / p.nx
    z = [(i - 0.5) * dx for i in 1:p.nx]
    A = [stenosis(zi, p)[1]^2 for zi in z]
    Q = zeros(Float64, p.nx)
    return z, A, Q, dx
end

function solve_inlet_area(Qin::Float64, w2::Float64, guess::Float64, p::Params)
    c0 = sqrt(wall_stiffness(p) / (2.0 * p.rho * p.rmax^2))
    residual(A) = Qin / A - w2 - 4.0 * c0 * A^0.25

    lo = max(guess * 0.05, AREA_LIMITER_FLOOR)
    hi = max(guess * 5.0, lo * 2.0)
    flo = residual(lo)
    fhi = residual(hi)

    for _ in 1:80
        flo * fhi <= 0.0 && break
        lo *= 0.5
        hi *= 2.0
        flo = residual(lo)
        fhi = residual(hi)
    end

    flo * fhi > 0.0 && return max(guess, AREA_LIMITER_FLOOR)

    for _ in 1:80
        mid = 0.5 * (lo + hi)
        fm = residual(mid)
        if abs(fm) < 1.0e-10 || abs(hi - lo) < 1.0e-12
            return mid
        elseif flo * fm <= 0.0
            hi = mid
            fhi = fm
        else
            lo = mid
            flo = fm
        end
    end

    return 0.5 * (lo + hi)
end

function boundary_states(A::AbstractVector{Float64}, Q::AbstractVector{Float64}, p::Params)
    c0 = sqrt(wall_stiffness(p) / (2.0 * p.rho * p.rmax^2))

    r0_in, _, _ = stenosis(0.0, p)
    A0_in = r0_in^2
    Qin = A0_in * inlet_uavg(p)
    w2 = Q[begin] / positive_area(A[begin]) - 4.0 * c0 * positive_area(A[begin])^0.25
    Ain = solve_inlet_area(Qin, w2, max(A[begin], A0_in), p)

    r0_out, _, _ = stenosis(p.length_cm, p)
    Aout = r0_out^2
    w1 = Q[end] / positive_area(A[end]) + 4.0 * c0 * positive_area(A[end])^0.25
    Qout = Aout * w1 - 4.0 * c0 * Aout^1.25

    return Ain, Qin, Aout, Qout
end

function fill_rhs!(
    dA::AbstractVector{Float64},
    dQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    p::Params,
    cache::RHSCache,
)
    nx = length(A)
    length(Q) == nx || throw(DimensionMismatch("area and flow vectors must have the same length"))
    length(dA) == nx || throw(DimensionMismatch("area derivative length mismatch"))
    length(dQ) == nx || throw(DimensionMismatch("flow derivative length mismatch"))
    length(z) == nx || throw(DimensionMismatch("grid and state lengths must match"))

    FA = cache.area_flux
    FQ = cache.flow_flux
    source = cache.source
    length(FA) == nx + 1 || throw(DimensionMismatch("area flux cache length mismatch"))
    length(FQ) == nx + 1 || throw(DimensionMismatch("flow flux cache length mismatch"))
    length(source) == nx || throw(DimensionMismatch("source cache length mismatch"))

    Ain, Qin, Aout, Qout = boundary_states(A, Q, p)

    for iface in 1:(nx + 1)
        if iface == 1
            AL, QL = Ain, Qin
            AR, QR = A[begin], Q[begin]
            zi = 0.0
        elseif iface == nx + 1
            AL, QL = A[end], Q[end]
            AR, QR = Aout, Qout
            zi = p.length_cm
        else
            AL, QL = A[iface - 1], Q[iface - 1]
            AR, QR = A[iface], Q[iface]
            zi = 0.5 * (z[iface - 1] + z[iface])
        end

        FAL, FQL = flux(AL, QL, zi, p)
        FAR, FQR = flux(AR, QR, zi, p)
        smax = max(max_wave_speed(AL, QL, zi, p), max_wave_speed(AR, QR, zi, p))

        FA[iface] = 0.5 * (FAL + FAR) - 0.5 * smax * (AR - AL)
        FQ[iface] = 0.5 * (FQL + FQR) - 0.5 * smax * (QR - QL)
    end

    fill_source!(source, A, Q, z, dx, p)

    for i in 1:nx
        dA[i] = -(FA[i + 1] - FA[i]) / dx
        dQ[i] = -(FQ[i + 1] - FQ[i]) / dx + source[i]
    end

    return dA, dQ
end

function rhs(A::AbstractVector{Float64}, Q::AbstractVector{Float64}, z::AbstractVector{Float64}, dx::Float64, p::Params)
    dA = similar(A, Float64)
    dQ = similar(Q, Float64)
    cache = RHSCache(length(A))
    fill_rhs!(dA, dQ, A, Q, z, dx, p, cache)
    return dA, dQ
end

function rhs!(du::AbstractVector{Float64}, u::AbstractVector{Float64}, sim::SemiDiscreteSimulation, t)
    A, Q = state_views(u, sim.layout)
    dA, dQ = state_views(du, sim.layout)
    fill_rhs!(dA, dQ, A, Q, sim.z, sim.dx, sim.params, sim.cache)
    return nothing
end

function rk3_step(A::Vector{Float64}, Q::Vector{Float64}, z::Vector{Float64}, dx::Float64, dt::Float64, p::Params)
    dA1, dQ1 = rhs(A, Q, z, dx, p)
    A1 = max.(A .+ dt .* dA1, AREA_LIMITER_FLOOR)
    Q1 = Q .+ dt .* dQ1

    dA2, dQ2 = rhs(A1, Q1, z, dx, p)
    A2 = max.(0.75 .* A .+ 0.25 .* (A1 .+ dt .* dA2), AREA_LIMITER_FLOOR)
    Q2 = 0.75 .* Q .+ 0.25 .* (Q1 .+ dt .* dQ2)

    dA3, dQ3 = rhs(A2, Q2, z, dx, p)
    Anew = max.((A .+ 2.0 .* (A2 .+ dt .* dA3)) ./ 3.0, AREA_LIMITER_FLOOR)
    Qnew = (Q .+ 2.0 .* (Q2 .+ dt .* dQ3)) ./ 3.0

    return Anew, Qnew
end

function choose_dt(A::Vector{Float64}, Q::Vector{Float64}, z::Vector{Float64}, dx::Float64, p::Params)
    smax = 0.0
    for i in eachindex(A)
        smax = max(smax, max_wave_speed(A[i], Q[i], z[i], p))
    end
    return min(p.dt, p.cfl * dx / max(smax, eps()))
end
