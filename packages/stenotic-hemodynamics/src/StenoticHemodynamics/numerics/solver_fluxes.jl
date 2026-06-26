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
    ;
    threaded::Bool = false,
)
    _ = dx
    _ = dt
    _ = cache
    Ain, Qin, Aout, Qout = boundary_states(A, Q, p, t)

    if threaded
        Threads.@threads :static for iface in 1:(length(A) + 1)
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
    method::FVGeometryRestWellBalancedMethod,
    p::Params,
    cache::RHSCache,
    ;
    threaded::Bool = false,
)
    _ = dx
    _ = dt
    fill_geometry_rest_well_balanced_fluxes!(FA, FQ, A, Q, z, t, method.limiter, p, cache; threaded=threaded)
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
    ;
    threaded::Bool = false,
)
    _ = dx
    _ = dt
    fill_muscl_rusanov_fluxes!(FA, FQ, A, Q, z, t, method.limiter, p, cache; threaded=threaded)
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
    ;
    threaded::Bool = false,
)
    _ = dx
    _ = dt
    fill_weno3_rusanov_fluxes!(FA, FQ, A, Q, z, t, method.epsilon, p, cache; threaded=threaded)
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
    ;
    threaded::Bool = false,
)
    dt > 0.0 || throw(ArgumentError("fv-lax-wendroff requires a positive native timestep"))
    fill_lax_wendroff_fluxes!(FA, FQ, A, Q, z, dx, dt, t, method.limiter, p, cache; threaded=threaded)
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
    ;
    threaded::Bool = false,
)
    method.degree == 0 || throw(ArgumentError("DG degree $(method.degree) uses the native modal DG solver, not cell-mean RHS"))
    return fill_method_fluxes!(FA, FQ, A, Q, z, dx, dt, t, FVFirstOrderMethod(), p, cache; threaded=threaded)
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

function geometry_rest_area(z::Float64, p::Params)
    r0, _, _ = stenosis(z, p)
    return r0^2
end

function geometry_rest_cell_areas(z::AbstractVector{Float64}, p::Params)
    return [geometry_rest_area(zi, p) for zi in z]
end

function geometry_rest_boundary_states(p::Params)
    return geometry_rest_area(0.0, p), 0.0, geometry_rest_area(p.length_cm, p), 0.0
end

function well_balanced_boundary_states(A::AbstractVector{Float64}, Q::AbstractVector{Float64}, p::Params, t::Float64)
    if p.forcing isa NoForcing && isapprox(inlet_flow(p, t), 0.0; rtol=0.0, atol=10 * eps(Float64))
        return geometry_rest_boundary_states(p)
    end
    return boundary_states(A, Q, p, t)
end

function geometry_rest_well_balanced_rusanov_flux(
    AL::Float64,
    QL::Float64,
    AR::Float64,
    QR::Float64,
    ALeq::Float64,
    AReq::Float64,
    z::Float64,
    p::Params,
)
    FAL, FQL = flux(AL, QL, z, p)
    FAR, FQR = flux(AR, QR, z, p)
    smax = max(max_wave_speed(AL, QL, z, p), max_wave_speed(AR, QR, z, p))
    return (
        0.5 * (FAL + FAR) - 0.5 * smax * ((AR - AReq) - (AL - ALeq)),
        0.5 * (FQL + FQR) - 0.5 * smax * (QR - QL),
    )
end

function cell_slopes(values::AbstractVector{Float64}, limiter::AbstractLimiter)
    slopes = zeros(Float64, length(values))
    return cell_slopes!(slopes, values, limiter)
end

function cell_slopes!(
    slopes::AbstractVector{Float64},
    values::AbstractVector{Float64},
    limiter::AbstractLimiter;
    threaded::Bool = false,
)
    length(slopes) == length(values) || throw(DimensionMismatch("slope cache length mismatch"))
    if threaded
        Threads.@threads :static for i in eachindex(values)
            slopes[i] = limited_slope(values, i, limiter)
        end
        return slopes
    end
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

function weno3_left_scalar(vm::T, v0::T, vp::T, epsilon::T) where {T<:AbstractFloat}
    one_v = one(v0)
    two_v = one_v + one_v
    three_v = two_v + one_v
    half_v = one_v / two_v
    beta0 = (v0 - vm)^2
    beta1 = (vp - v0)^2
    alpha0 = (one_v / three_v) / (epsilon + beta0)^2
    alpha1 = (two_v / three_v) / (epsilon + beta1)^2
    denom = alpha0 + alpha1
    omega0 = alpha0 / denom
    omega1 = alpha1 / denom
    p0 = -half_v * vm + (one_v + half_v) * v0
    p1 = half_v * v0 + half_v * vp
    return omega0 * p0 + omega1 * p1
end

function weno3_right_scalar(vm::T, v0::T, vp::T, epsilon::T) where {T<:AbstractFloat}
    one_v = one(v0)
    two_v = one_v + one_v
    three_v = two_v + one_v
    half_v = one_v / two_v
    beta0 = (vp - v0)^2
    beta1 = (v0 - vm)^2
    alpha0 = (one_v / three_v) / (epsilon + beta0)^2
    alpha1 = (two_v / three_v) / (epsilon + beta1)^2
    denom = alpha0 + alpha1
    omega0 = alpha0 / denom
    omega1 = alpha1 / denom
    p0 = (one_v + half_v) * v0 - half_v * vp
    p1 = half_v * vm + half_v * v0
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
    ;
    threaded::Bool = false,
)
    slope_A = cell_slopes!(cache.area_slope, A, limiter; threaded=threaded)
    slope_Q = cell_slopes!(cache.flow_slope, Q, limiter; threaded=threaded)
    Ain, Qin, Aout, Qout = boundary_states(A, Q, p, t)

    if threaded
        Threads.@threads :static for iface in 1:(length(A) + 1)
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

function fill_geometry_rest_well_balanced_fluxes!(
    FA::AbstractVector{Float64},
    FQ::AbstractVector{Float64},
    A::AbstractVector{Float64},
    Q::AbstractVector{Float64},
    z::AbstractVector{Float64},
    t::Float64,
    limiter::AbstractLimiter,
    p::Params,
    cache::RHSCache,
    ;
    threaded::Bool = false,
)
    slope_A = cell_slopes!(cache.area_slope, A, limiter; threaded=threaded)
    slope_Q = cell_slopes!(cache.flow_slope, Q, limiter; threaded=threaded)
    Aeq = geometry_rest_cell_areas(z, p)
    slope_Aeq = cell_slopes(Aeq, limiter)
    Ain, Qin, Aout, Qout = well_balanced_boundary_states(A, Q, p, t)
    Aeq_in, Qeq_in, Aeq_out, Qeq_out = geometry_rest_boundary_states(p)
    _ = Qeq_in
    _ = Qeq_out

    if threaded
        Threads.@threads :static for iface in 1:(length(A) + 1)
            if iface == 1
                AL, QL = Ain, Qin
                AR = reconstructed_area(A[begin], slope_A[begin], -1.0)
                QR = reconstructed_flow(Q[begin], slope_Q[begin], -1.0)
                ALeq = Aeq_in
                AReq = reconstructed_area(Aeq[begin], slope_Aeq[begin], -1.0)
                zi = 0.0
            elseif iface == length(A) + 1
                AL = reconstructed_area(A[end], slope_A[end], 1.0)
                QL = reconstructed_flow(Q[end], slope_Q[end], 1.0)
                AR, QR = Aout, Qout
                ALeq = reconstructed_area(Aeq[end], slope_Aeq[end], 1.0)
                AReq = Aeq_out
                zi = p.length_cm
            else
                left = iface - 1
                right = iface
                AL = reconstructed_area(A[left], slope_A[left], 1.0)
                QL = reconstructed_flow(Q[left], slope_Q[left], 1.0)
                AR = reconstructed_area(A[right], slope_A[right], -1.0)
                QR = reconstructed_flow(Q[right], slope_Q[right], -1.0)
                ALeq = reconstructed_area(Aeq[left], slope_Aeq[left], 1.0)
                AReq = reconstructed_area(Aeq[right], slope_Aeq[right], -1.0)
                zi = 0.5 * (z[left] + z[right])
            end

            FA[iface], FQ[iface] = geometry_rest_well_balanced_rusanov_flux(AL, QL, AR, QR, ALeq, AReq, zi, p)
        end

        return FA, FQ
    end

    for iface in 1:(length(A) + 1)
        if iface == 1
            AL, QL = Ain, Qin
            AR = reconstructed_area(A[begin], slope_A[begin], -1.0)
            QR = reconstructed_flow(Q[begin], slope_Q[begin], -1.0)
            ALeq = Aeq_in
            AReq = reconstructed_area(Aeq[begin], slope_Aeq[begin], -1.0)
            zi = 0.0
        elseif iface == length(A) + 1
            AL = reconstructed_area(A[end], slope_A[end], 1.0)
            QL = reconstructed_flow(Q[end], slope_Q[end], 1.0)
            AR, QR = Aout, Qout
            ALeq = reconstructed_area(Aeq[end], slope_Aeq[end], 1.0)
            AReq = Aeq_out
            zi = p.length_cm
        else
            left = iface - 1
            right = iface
            AL = reconstructed_area(A[left], slope_A[left], 1.0)
            QL = reconstructed_flow(Q[left], slope_Q[left], 1.0)
            AR = reconstructed_area(A[right], slope_A[right], -1.0)
            QR = reconstructed_flow(Q[right], slope_Q[right], -1.0)
            ALeq = reconstructed_area(Aeq[left], slope_Aeq[left], 1.0)
            AReq = reconstructed_area(Aeq[right], slope_Aeq[right], -1.0)
            zi = 0.5 * (z[left] + z[right])
        end

        FA[iface], FQ[iface] = geometry_rest_well_balanced_rusanov_flux(AL, QL, AR, QR, ALeq, AReq, zi, p)
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
    ;
    threaded::Bool = false,
)
    slope_A = cell_slopes!(cache.area_slope, A, MinmodLimiter(); threaded=threaded)
    slope_Q = cell_slopes!(cache.flow_slope, Q, MinmodLimiter(); threaded=threaded)
    Ain, Qin, Aout, Qout = boundary_states(A, Q, p, t)
    nx = length(A)

    if threaded
        Threads.@threads :static for iface in 1:(nx + 1)
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
    ;
    threaded::Bool = false,
)
    slope_A = cell_slopes!(cache.area_slope, A, limiter; threaded=threaded)
    slope_Q = cell_slopes!(cache.flow_slope, Q, limiter; threaded=threaded)
    Ain, Qin, Aout, Qout = boundary_states(A, Q, p, t)

    if threaded
        Threads.@threads :static for iface in 1:(length(A) + 1)
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
