function initial_state(p::Params)
    state = initial_state_result(p)
    return state.z, state.area, state.flow, state.dx
end

function solve_inlet_area(Qin::Float64, w2::Float64, guess::Float64, p::Params)
    c0 = invariant_speed_factor(p)
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

    if flo * fhi > 0.0
        @warn "inlet area solver failed to bracket; returning limited guess" Qin w2 guess lo hi flo fhi
        return max(guess, AREA_LIMITER_FLOOR)
    end

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

function outlet_state(::FixedAreaCharacteristicOutlet, A::AbstractVector{Float64}, Q::AbstractVector{Float64}, p::Params, t::Float64)
    return outlet_state_from_values(FixedAreaCharacteristicOutlet(), A[end], Q[end], p, t)
end

function outlet_state_from_values(
    ::FixedAreaCharacteristicOutlet,
    A_end::Float64,
    Q_end::Float64,
    p::Params,
    t::Float64,
)
    _ = t
    r0_out, _, _ = stenosis(p.length_cm, p)
    Aout = r0_out^2
    w1 = invariant_plus(A_end, Q_end, p)
    Qout = Aout * w1 - 4.0 * invariant_speed_factor(p) * Aout^1.25
    return Aout, Qout
end

function outlet_state(boundary::ReflectionCoefficientOutlet, A::AbstractVector{Float64}, Q::AbstractVector{Float64}, p::Params, t::Float64)
    return outlet_state_from_values(boundary, A[end], Q[end], p, t)
end

function outlet_state_from_values(
    boundary::ReflectionCoefficientOutlet,
    A_end::Float64,
    Q_end::Float64,
    p::Params,
    t::Float64,
)
    _ = t
    r0_out, _, _ = stenosis(p.length_cm, p)
    Aref = max(r0_out^2, AREA_LIMITER_FLOOR)
    Qref = boundary.reference_flow
    wplus = invariant_plus(A_end, Q_end, p)
    wminus_ref = invariant_minus(Aref, Qref, p)
    wplus_ref = invariant_plus(Aref, Qref, p)
    wminus = wminus_ref - boundary.rt * (wplus - wplus_ref)
    return state_from_invariants(wminus, wplus, p)
end

function boundary_states(A::AbstractVector{Float64}, Q::AbstractVector{Float64}, p::Params, t::Float64 = 0.0)
    return boundary_states_from_values(A[begin], Q[begin], A[end], Q[end], p, t)
end

function boundary_states_from_values(
    A_begin::Float64,
    Q_begin::Float64,
    A_end::Float64,
    Q_end::Float64,
    p::Params,
    t::Float64 = 0.0,
)
    if p.forcing isa ManufacturedForcing
        Ain, Qin = exact_manufactured_state(p.forcing, 0.0, t, p)
        Aout, Qout = exact_manufactured_state(p.forcing, p.length_cm, t, p)
        return Ain, Qin, Aout, Qout
    end

    r0_in, _, _ = stenosis(0.0, p)
    A0_in = r0_in^2
    Qin = inlet_flow(p, t)
    w2 = invariant_minus(A_begin, Q_begin, p)
    Ain = solve_inlet_area(Qin, w2, max(A_begin, A0_in), p)

    Aout, Qout = outlet_state_from_values(p.outlet_boundary, A_end, Q_end, p, t)

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

function fill_method_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    method::AbstractSpatialMethod,
    p::Params,
)
    cache = RHSCache(length(A))
    return fill_method_fluxes!(FA, FQ, A, Q, z, dx, dt, t, method, p, cache)
end

function fill_method_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    method::FVFirstOrderMethod,
    p::Params,
    cache::RHSCache,
)
    _ = dx
    _ = dt
    _ = cache
    Ain, Qin, Aout, Qout = boundary_states(A, Q, p, t)

    for iface in 1:(length(A) + 1)
        if iface == 1
            AL, QL = Ain, Qin
            AR, QR = A[begin], Q[begin]
            zi = 0.0
        elseif iface == length(A) + 1
            AL, QL = A[end], Q[end]
            AR, QR = Aout, Qout
            zi = p.length_cm
        else
            AL, QL = A[iface - 1], Q[iface - 1]
            AR, QR = A[iface], Q[iface]
            zi = 0.5 * (z[iface - 1] + z[iface])
        end

        FA[iface], FQ[iface] = rusanov_flux(AL, QL, AR, QR, zi, p)
    end

    return FA, FQ
end

function fill_method_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    method::FVMUSCLMethod,
    p::Params,
    cache::RHSCache,
)
    _ = dx
    _ = dt
    fill_muscl_rusanov_fluxes!(FA, FQ, A, Q, z, t, method.limiter, p, cache)
    return FA, FQ
end

function fill_method_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    method::FVWENO3Method,
    p::Params,
    cache::RHSCache,
)
    _ = dx
    _ = dt
    fill_weno3_rusanov_fluxes!(FA, FQ, A, Q, z, t, method.epsilon, p, cache)
    return FA, FQ
end

function fill_method_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    method::FVLaxWendroffMethod,
    p::Params,
    cache::RHSCache,
)
    dt > 0.0 || throw(ArgumentError("fv-lax-wendroff requires a positive native timestep"))
    fill_lax_wendroff_fluxes!(FA, FQ, A, Q, z, dx, dt, t, method.limiter, p, cache)
    return FA, FQ
end

function fill_method_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    method::DGMethod,
    p::Params,
    cache::RHSCache,
)
    method.degree == 0 || throw(ArgumentError("DG degree $(method.degree) uses the native modal DG solver, not cell-mean RHS"))
    return fill_method_fluxes!(FA, FQ, A, Q, z, dx, dt, t, FVFirstOrderMethod(), p, cache)
end

function rusanov_flux(AL::Float64, QL::Float64, AR::Float64, QR::Float64, z::Float64, p::Params)
    FAL, FQL = flux(AL, QL, z, p)
    FAR, FQR = flux(AR, QR, z, p)
    smax = max(max_wave_speed(AL, QL, z, p), max_wave_speed(AR, QR, z, p))
    return (
        0.5 * (FAL + FAR) - 0.5 * smax * (AR - AL),
        0.5 * (FQL + FQR) - 0.5 * smax * (QR - QL),
    )
end

function cell_slopes(values::AbstractVector{Float64}, limiter::AbstractLimiter)
    slopes = zeros(Float64, length(values))
    return cell_slopes!(slopes, values, limiter)
end

function cell_slopes!(slopes::AbstractVector{Float64}, values::AbstractVector{Float64}, limiter::AbstractLimiter)
    length(slopes) == length(values) || throw(DimensionMismatch("slope cache length mismatch"))
    for i in eachindex(values)
        slopes[i] = limited_slope(values, i, limiter)
    end
    return slopes
end

function reconstructed_area(value::Float64, slope::Float64, side::Float64)
    candidate = value + side * 0.5 * slope
    return candidate > AREA_LIMITER_FLOOR ? candidate : max(value, AREA_LIMITER_FLOOR)
end

reconstructed_flow(value::Float64, slope::Float64, side::Float64) = value + side * 0.5 * slope

function weno3_left_scalar(vm::Float64, v0::Float64, vp::Float64, epsilon::Float64)
    beta0 = (v0 - vm)^2
    beta1 = (vp - v0)^2
    alpha0 = (1.0 / 3.0) / (epsilon + beta0)^2
    alpha1 = (2.0 / 3.0) / (epsilon + beta1)^2
    denom = alpha0 + alpha1
    omega0 = alpha0 / denom
    omega1 = alpha1 / denom
    p0 = -0.5 * vm + 1.5 * v0
    p1 = 0.5 * v0 + 0.5 * vp
    return omega0 * p0 + omega1 * p1
end

function weno3_right_scalar(vm::Float64, v0::Float64, vp::Float64, epsilon::Float64)
    beta0 = (vp - v0)^2
    beta1 = (v0 - vm)^2
    alpha0 = (1.0 / 3.0) / (epsilon + beta0)^2
    alpha1 = (2.0 / 3.0) / (epsilon + beta1)^2
    denom = alpha0 + alpha1
    omega0 = alpha0 / denom
    omega1 = alpha1 / denom
    p0 = 1.5 * v0 - 0.5 * vp
    p1 = 0.5 * vm + 0.5 * v0
    return omega0 * p0 + omega1 * p1
end

function characteristic_basis(A::Float64, Q::Float64, z::Float64, p::Params)
    Apos = positive_area(A)
    _, r0z, _ = stenosis(z, p)
    alpha_eff = momentum_alpha(p) + effective_alpha_c(p, r0z)
    u = Q / Apos
    radicand = (alpha_eff * u)^2 - alpha_eff * u^2 + wall_wave_speed_squared(Apos, z, p)
    c = sqrt(max(radicand, 0.0))
    return alpha_eff * u - c, alpha_eff * u + c
end

function conservative_to_characteristic(A::Float64, Q::Float64, lambda_minus::Float64, lambda_plus::Float64)
    denom = lambda_plus - lambda_minus
    abs(denom) > sqrt(eps(Float64)) || throw(ArgumentError("characteristic basis is degenerate"))
    wminus = (lambda_plus * A - Q) / denom
    wplus = (-lambda_minus * A + Q) / denom
    return wminus, wplus
end

function characteristic_to_conservative(wminus::Float64, wplus::Float64, lambda_minus::Float64, lambda_plus::Float64)
    return wminus + wplus, lambda_minus * wminus + lambda_plus * wplus
end

function componentwise_weno3_states(
    A0::Float64,
    Q0::Float64,
    A1::Float64,
    Q1::Float64,
    A2::Float64,
    Q2::Float64,
    A3::Float64,
    Q3::Float64,
    epsilon::Float64,
)
    AL = weno3_left_scalar(A0, A1, A2, epsilon)
    QL = weno3_left_scalar(Q0, Q1, Q2, epsilon)
    AR = weno3_right_scalar(A1, A2, A3, epsilon)
    QR = weno3_right_scalar(Q1, Q2, Q3, epsilon)
    return AL, QL, AR, QR
end

function characteristic_weno3_states(
    A0::Float64,
    Q0::Float64,
    A1::Float64,
    Q1::Float64,
    A2::Float64,
    Q2::Float64,
    A3::Float64,
    Q3::Float64,
    z::Float64,
    epsilon::Float64,
    p::Params,
)
    Aref = positive_area(0.5 * (A1 + A2))
    Qref = 0.5 * (Q1 + Q2)
    lambda_minus, lambda_plus = characteristic_basis(Aref, Qref, z, p)
    if abs(lambda_plus - lambda_minus) <= sqrt(eps(Float64))
        return componentwise_weno3_states(A0, Q0, A1, Q1, A2, Q2, A3, Q3, epsilon)
    end

    w0m, w0p = conservative_to_characteristic(A0, Q0, lambda_minus, lambda_plus)
    w1m, w1p = conservative_to_characteristic(A1, Q1, lambda_minus, lambda_plus)
    w2m, w2p = conservative_to_characteristic(A2, Q2, lambda_minus, lambda_plus)
    w3m, w3p = conservative_to_characteristic(A3, Q3, lambda_minus, lambda_plus)

    wLm = weno3_left_scalar(w0m, w1m, w2m, epsilon)
    wLp = weno3_left_scalar(w0p, w1p, w2p, epsilon)
    wRm = weno3_right_scalar(w1m, w2m, w3m, epsilon)
    wRp = weno3_right_scalar(w1p, w2p, w3p, epsilon)

    AL, QL = characteristic_to_conservative(wLm, wLp, lambda_minus, lambda_plus)
    AR, QR = characteristic_to_conservative(wRm, wRp, lambda_minus, lambda_plus)
    return AL, QL, AR, QR
end

function weno3_interface_states(
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    iface::Int,
    epsilon::Float64,
    p::Params,
)
    nx = length(A)
    3 <= iface <= nx - 1 || throw(ArgumentError("WENO3 interface $iface does not have a four-cell stencil"))
    zi = 0.5 * (z[iface - 1] + z[iface])
    AL, QL, AR, QR = characteristic_weno3_states(
        A[iface - 2],
        Q[iface - 2],
        A[iface - 1],
        Q[iface - 1],
        A[iface],
        Q[iface],
        A[iface + 1],
        Q[iface + 1],
        zi,
        epsilon,
        p,
    )
    return reconstructed_area(AL, 0.0, 0.0), QL, reconstructed_area(AR, 0.0, 0.0), QR
end

function fill_muscl_rusanov_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    t::Float64,
    limiter::AbstractLimiter,
    p::Params,
)
    cache = RHSCache(length(A))
    return fill_muscl_rusanov_fluxes!(FA, FQ, A, Q, z, t, limiter, p, cache)
end

function fill_muscl_rusanov_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    t::Float64,
    limiter::AbstractLimiter,
    p::Params,
    cache::RHSCache,
)
    slope_A = cell_slopes!(cache.area_slope, A, limiter)
    slope_Q = cell_slopes!(cache.flow_slope, Q, limiter)
    Ain, Qin, Aout, Qout = boundary_states(A, Q, p, t)

    for iface in 1:(length(A) + 1)
        if iface == 1
            AL, QL = Ain, Qin
            AR = reconstructed_area(A[begin], slope_A[begin], -1.0)
            QR = reconstructed_flow(Q[begin], slope_Q[begin], -1.0)
            zi = 0.0
        elseif iface == length(A) + 1
            AL = reconstructed_area(A[end], slope_A[end], 1.0)
            QL = reconstructed_flow(Q[end], slope_Q[end], 1.0)
            AR, QR = Aout, Qout
            zi = p.length_cm
        else
            left = iface - 1
            right = iface
            AL = reconstructed_area(A[left], slope_A[left], 1.0)
            QL = reconstructed_flow(Q[left], slope_Q[left], 1.0)
            AR = reconstructed_area(A[right], slope_A[right], -1.0)
            QR = reconstructed_flow(Q[right], slope_Q[right], -1.0)
            zi = 0.5 * (z[left] + z[right])
        end

        FA[iface], FQ[iface] = rusanov_flux(AL, QL, AR, QR, zi, p)
    end

    return FA, FQ
end

function fill_weno3_rusanov_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    t::Float64,
    epsilon::Float64,
    p::Params,
    cache::RHSCache,
)
    slope_A = cell_slopes!(cache.area_slope, A, MinmodLimiter())
    slope_Q = cell_slopes!(cache.flow_slope, Q, MinmodLimiter())
    Ain, Qin, Aout, Qout = boundary_states(A, Q, p, t)
    nx = length(A)

    for iface in 1:(nx + 1)
        if iface == 1
            AL, QL = Ain, Qin
            AR = reconstructed_area(A[begin], slope_A[begin], -1.0)
            QR = reconstructed_flow(Q[begin], slope_Q[begin], -1.0)
            zi = 0.0
        elseif iface == nx + 1
            AL = reconstructed_area(A[end], slope_A[end], 1.0)
            QL = reconstructed_flow(Q[end], slope_Q[end], 1.0)
            AR, QR = Aout, Qout
            zi = p.length_cm
        elseif 3 <= iface <= nx - 1
            AL, QL, AR, QR = weno3_interface_states(A, Q, z, iface, epsilon, p)
            zi = 0.5 * (z[iface - 1] + z[iface])
        else
            left = iface - 1
            right = iface
            AL = reconstructed_area(A[left], slope_A[left], 1.0)
            QL = reconstructed_flow(Q[left], slope_Q[left], 1.0)
            AR = reconstructed_area(A[right], slope_A[right], -1.0)
            QR = reconstructed_flow(Q[right], slope_Q[right], -1.0)
            zi = 0.5 * (z[left] + z[right])
        end

        FA[iface], FQ[iface] = rusanov_flux(AL, QL, AR, QR, zi, p)
    end

    return FA, FQ
end

function fill_lax_wendroff_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    limiter::AbstractLimiter,
    p::Params,
)
    cache = RHSCache(length(A))
    return fill_lax_wendroff_fluxes!(FA, FQ, A, Q, z, dx, dt, t, limiter, p, cache)
end

function fill_lax_wendroff_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    limiter::AbstractLimiter,
    p::Params,
    cache::RHSCache,
)
    slope_A = cell_slopes!(cache.area_slope, A, limiter)
    slope_Q = cell_slopes!(cache.flow_slope, Q, limiter)
    Ain, Qin, Aout, Qout = boundary_states(A, Q, p, t)

    for iface in 1:(length(A) + 1)
        if iface == 1
            AL, QL = Ain, Qin
            AR = reconstructed_area(A[begin], slope_A[begin], -1.0)
            QR = reconstructed_flow(Q[begin], slope_Q[begin], -1.0)
            zi = 0.0
        elseif iface == length(A) + 1
            AL = reconstructed_area(A[end], slope_A[end], 1.0)
            QL = reconstructed_flow(Q[end], slope_Q[end], 1.0)
            AR, QR = Aout, Qout
            zi = p.length_cm
        else
            left = iface - 1
            right = iface
            AL = reconstructed_area(A[left], slope_A[left], 1.0)
            QL = reconstructed_flow(Q[left], slope_Q[left], 1.0)
            AR = reconstructed_area(A[right], slope_A[right], -1.0)
            QR = reconstructed_flow(Q[right], slope_Q[right], -1.0)
            zi = 0.5 * (z[left] + z[right])
        end

        FAL, FQL = flux(AL, QL, zi, p)
        FAR, FQR = flux(AR, QR, zi, p)
        Ah = max(0.5 * (AL + AR) - 0.5 * dt / dx * (FAR - FAL), AREA_LIMITER_FLOOR)
        Qh = 0.5 * (QL + QR) - 0.5 * dt / dx * (FQR - FQL)
        FA[iface], FQ[iface] = flux(Ah, Qh, zi, p)
    end

    return FA, FQ
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

function native_step(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    p::Params,
)
    return native_step(A, Q, z, dx, dt, 0.0, p.time_stepper, p)
end

function native_step(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    p::Params,
)
    return native_step(A, Q, z, dx, dt, t, p.time_stepper, p)
end

function native_step(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::ForwardEulerStepper,
    p::Params,
)
    Anew = copy(A)
    Qnew = copy(Q)
    cache = NativeStepCache(length(A))
    return native_step!(Anew, Qnew, z, dx, dt, t, ForwardEulerStepper(), p, cache)
end

function native_step(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK2Stepper,
    p::Params,
)
    Anew = copy(A)
    Qnew = copy(Q)
    cache = NativeStepCache(length(A))
    return native_step!(Anew, Qnew, z, dx, dt, t, SSPRK2Stepper(), p, cache)
end

function native_step(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK3Stepper,
    p::Params,
)
    Anew = copy(A)
    Qnew = copy(Q)
    cache = NativeStepCache(length(A))
    return native_step!(Anew, Qnew, z, dx, dt, t, SSPRK3Stepper(), p, cache)
end

function native_step(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK54Stepper,
    p::Params,
)
    Anew = copy(A)
    Qnew = copy(Q)
    cache = NativeStepCache(length(A))
    return native_step!(Anew, Qnew, z, dx, dt, t, SSPRK54Stepper(), p, cache)
end

function native_step!(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    p::Params,
    cache::NativeStepCache,
    diagnostics = nothing,
)
    return native_step!(A, Q, z, dx, dt, t, p.time_stepper, p, cache, diagnostics)
end

function native_step!(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::ForwardEulerStepper,
    p::Params,
    cache::NativeStepCache,
    diagnostics = nothing,
)
    fill_rhs_dt!(cache.dA1, cache.dQ1, A, Q, z, dx, dt, t, p, cache.rhs)

    for i in eachindex(A)
        A[i] = limited_area(A[i] + dt * cache.dA1[i], diagnostics)
        Q[i] = Q[i] + dt * cache.dQ1[i]
    end

    return A, Q
end

function native_step!(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK2Stepper,
    p::Params,
    cache::NativeStepCache,
    diagnostics = nothing,
)
    fill_rhs_dt!(cache.dA1, cache.dQ1, A, Q, z, dx, dt, t, p, cache.rhs)
    for i in eachindex(A)
        cache.A1[i] = limited_area(A[i] + dt * cache.dA1[i], diagnostics)
        cache.Q1[i] = Q[i] + dt * cache.dQ1[i]
    end

    fill_rhs_dt!(cache.dA2, cache.dQ2, cache.A1, cache.Q1, z, dx, dt, t + dt, p, cache.rhs)
    for i in eachindex(A)
        A[i] = limited_area(0.5 * A[i] + 0.5 * (cache.A1[i] + dt * cache.dA2[i]), diagnostics)
        Q[i] = 0.5 * Q[i] + 0.5 * (cache.Q1[i] + dt * cache.dQ2[i])
    end

    return A, Q
end

function native_step!(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK3Stepper,
    p::Params,
    cache::NativeStepCache,
    diagnostics = nothing,
)
    fill_rhs_dt!(cache.dA1, cache.dQ1, A, Q, z, dx, dt, t, p, cache.rhs)
    for i in eachindex(A)
        cache.A1[i] = limited_area(A[i] + dt * cache.dA1[i], diagnostics)
        cache.Q1[i] = Q[i] + dt * cache.dQ1[i]
    end

    fill_rhs_dt!(cache.dA2, cache.dQ2, cache.A1, cache.Q1, z, dx, dt, t + dt, p, cache.rhs)
    for i in eachindex(A)
        cache.A2[i] = limited_area(0.75 * A[i] + 0.25 * (cache.A1[i] + dt * cache.dA2[i]), diagnostics)
        cache.Q2[i] = 0.75 * Q[i] + 0.25 * (cache.Q1[i] + dt * cache.dQ2[i])
    end

    fill_rhs_dt!(cache.dA3, cache.dQ3, cache.A2, cache.Q2, z, dx, dt, t + 0.5 * dt, p, cache.rhs)
    for i in eachindex(A)
        A[i] = limited_area((A[i] + 2.0 * (cache.A2[i] + dt * cache.dA3[i])) / 3.0, diagnostics)
        Q[i] = (Q[i] + 2.0 * (cache.Q2[i] + dt * cache.dQ3[i])) / 3.0
    end

    return A, Q
end

function native_step!(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK54Stepper,
    p::Params,
    cache::NativeStepCache,
    diagnostics = nothing,
)
    c1 = 0.391752226571890
    c2 = 0.586079688967798
    c3 = 0.474542363026872
    c4 = 0.935010630967653

    fill_rhs_dt!(cache.dA1, cache.dQ1, A, Q, z, dx, dt, t, p, cache.rhs)
    for i in eachindex(A)
        cache.A1[i] = limited_area(A[i] + 0.391752226571890 * dt * cache.dA1[i], diagnostics)
        cache.Q1[i] = Q[i] + 0.391752226571890 * dt * cache.dQ1[i]
    end

    fill_rhs_dt!(cache.dA1, cache.dQ1, cache.A1, cache.Q1, z, dx, dt, t + c1 * dt, p, cache.rhs)
    for i in eachindex(A)
        cache.A1[i] = limited_area(
            0.444370493651235 * A[i] +
            0.555629506348765 * cache.A1[i] +
            0.368410593050371 * dt * cache.dA1[i],
            diagnostics,
        )
        cache.Q1[i] =
            0.444370493651235 * Q[i] +
            0.555629506348765 * cache.Q1[i] +
            0.368410593050371 * dt * cache.dQ1[i]
    end

    fill_rhs_dt!(cache.dA1, cache.dQ1, cache.A1, cache.Q1, z, dx, dt, t + c2 * dt, p, cache.rhs)
    for i in eachindex(A)
        cache.A2[i] = limited_area(
            0.620101851488403 * A[i] +
            0.379898148511597 * cache.A1[i] +
            0.251891774271694 * dt * cache.dA1[i],
            diagnostics,
        )
        cache.Q2[i] =
            0.620101851488403 * Q[i] +
            0.379898148511597 * cache.Q1[i] +
            0.251891774271694 * dt * cache.dQ1[i]
    end

    fill_rhs_dt!(cache.dA1, cache.dQ1, cache.A2, cache.Q2, z, dx, dt, t + c3 * dt, p, cache.rhs)
    for i in eachindex(A)
        cache.A3[i] = limited_area(
            0.178079954393132 * A[i] +
            0.821920045606868 * cache.A2[i] +
            0.544974750228521 * dt * cache.dA1[i],
            diagnostics,
        )
        cache.Q3[i] =
            0.178079954393132 * Q[i] +
            0.821920045606868 * cache.Q2[i] +
            0.544974750228521 * dt * cache.dQ1[i]
    end

    fill_rhs_dt!(cache.dA1, cache.dQ1, cache.A3, cache.Q3, z, dx, dt, t + c4 * dt, p, cache.rhs)
    for i in eachindex(A)
        A[i] = limited_area(
            0.517231671970585 * cache.A1[i] +
            0.096059710526147 * cache.A2[i] +
            0.386708617503269 * cache.A3[i] +
            0.063692468666290 * dt * cache.dA1[i],
            diagnostics,
        )
        Q[i] =
            0.517231671970585 * cache.Q1[i] +
            0.096059710526147 * cache.Q2[i] +
            0.386708617503269 * cache.Q3[i] +
            0.063692468666290 * dt * cache.dQ1[i]
    end

    return A, Q
end

function rk3_step(A::Vector{Float64}, Q::Vector{Float64}, z::Vector{Float64}, dx::Float64, dt::Float64, p::Params)
    return native_step(A, Q, z, dx, dt, 0.0, SSPRK3Stepper(), p)
end

function choose_dt(A::Vector{Float64}, Q::Vector{Float64}, z::Vector{Float64}, dx::Float64, p::Params)
    smax = 0.0
    for i in eachindex(A)
        smax = max(smax, max_wave_speed(A[i], Q[i], z[i], p))
    end
    return min(p.dt, p.cfl * dx / max(smax, eps()))
end
