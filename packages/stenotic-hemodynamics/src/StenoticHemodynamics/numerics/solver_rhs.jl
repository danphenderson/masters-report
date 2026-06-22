function fill_rhs!(
    dA::AbstractVector{Float64},
    dQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    p::Params,
    cache::RHSCache,
    t::Float64 = 0.0,
)
    return fill_rhs_dt!(dA, dQ, A, Q, z, dx, 0.0, t, p, cache)
end

function fill_rhs_dt!(
    dA::AbstractVector{Float64},
    dQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
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
    slope_A = cache.area_slope
    slope_Q = cache.flow_slope
    length(FA) == nx + 1 || throw(DimensionMismatch("area flux cache length mismatch"))
    length(FQ) == nx + 1 || throw(DimensionMismatch("flow flux cache length mismatch"))
    length(source) == nx || throw(DimensionMismatch("source cache length mismatch"))
    length(slope_A) == nx || throw(DimensionMismatch("area slope cache length mismatch"))
    length(slope_Q) == nx || throw(DimensionMismatch("flow slope cache length mismatch"))

    fill_method_fluxes!(FA, FQ, A, Q, z, dx, dt, t, p.space, p, cache)
    fill_source!(source, A, Q, z, dx, p)

    for i in 1:nx
        dA[i] = -(FA[i + 1] - FA[i]) / dx
        dQ[i] = -(FQ[i + 1] - FQ[i]) / dx + source[i]
        if !(p.forcing isa NoForcing)
            dA[i] += mass_forcing(p.forcing, z[i], t, p)
            dQ[i] += momentum_forcing(p.forcing, z[i], t, p)
        end
    end

    return dA, dQ
end

function rhs(A::AbstractVector{Float64}, Q::AbstractVector{Float64}, z::AbstractVector{Float64}, dx::Float64, p::Params)
    return rhs_dt(A, Q, z, dx, 0.0, p)
end

function rhs_dt(
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    p::Params,
)
    return rhs_dt(A, Q, z, dx, dt, 0.0, p)
end

function rhs_dt(
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    p::Params,
    ;
    cache::Union{Nothing,RHSCache} = nothing,
)
    dA = similar(A, Float64)
    dQ = similar(Q, Float64)
    rhs_cache = cache === nothing ? RHSCache(length(A)) : cache
    fill_rhs_dt!(dA, dQ, A, Q, z, dx, dt, t, p, rhs_cache)
    return dA, dQ
end

function rhs!(du::AbstractVector{Float64}, u::AbstractVector{Float64}, sim::SemiDiscreteSimulation, t)
    A, Q = state_views(u, sim.layout)
    dA, dQ = state_views(du, sim.layout)
    fill_rhs!(dA, dQ, A, Q, sim.z, sim.dx, sim.params, sim.cache, Float64(t))
    return nothing
end
