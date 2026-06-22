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
