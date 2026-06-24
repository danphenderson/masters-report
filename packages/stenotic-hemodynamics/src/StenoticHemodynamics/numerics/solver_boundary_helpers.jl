struct InletAreaSolveControls{T<:AbstractFloat}
    bracket_lower_scale::T
    bracket_upper_scale::T
    bracket_growth_factor::T
    residual_tolerance::T
    area_tolerance::T
    max_bracket_iterations::Int
    max_bisection_iterations::Int
end

function InletAreaSolveControls{T}(;
    bracket_lower_scale::Real=T(0.05),
    bracket_upper_scale::Real=T(5),
    bracket_growth_factor::Real=T(2),
    residual_tolerance::Real=T(1.0e-10),
    area_tolerance::Real=T(1.0e-12),
    max_bracket_iterations::Integer=80,
    max_bisection_iterations::Integer=80,
) where {T<:AbstractFloat}
    return InletAreaSolveControls{T}(
        T(bracket_lower_scale),
        T(bracket_upper_scale),
        T(bracket_growth_factor),
        T(residual_tolerance),
        T(area_tolerance),
        Int(max_bracket_iterations),
        Int(max_bisection_iterations),
    )
end

InletAreaSolveControls(; kwargs...) = InletAreaSolveControls{Float64}(; kwargs...)

const DEFAULT_INLET_AREA_SOLVE_CONTROLS = InletAreaSolveControls{Float64}()

function validate_inlet_area_solve_controls(controls::InletAreaSolveControls)
    controls.bracket_lower_scale > 0 || throw(ArgumentError("inlet area lower bracket scale must be positive"))
    controls.bracket_upper_scale > controls.bracket_lower_scale ||
        throw(ArgumentError("inlet area upper bracket scale must exceed lower bracket scale"))
    controls.bracket_growth_factor > 1 ||
        throw(ArgumentError("inlet area bracket growth factor must exceed one"))
    controls.residual_tolerance > 0 || throw(ArgumentError("inlet area residual tolerance must be positive"))
    controls.area_tolerance > 0 || throw(ArgumentError("inlet area tolerance must be positive"))
    controls.max_bracket_iterations >= 0 ||
        throw(ArgumentError("inlet area bracket iteration limit must be nonnegative"))
    controls.max_bisection_iterations > 0 ||
        throw(ArgumentError("inlet area bisection iteration limit must be positive"))
    return controls
end

function solve_inlet_area(
    Qin::Real,
    w2::Real,
    guess::Real,
    p::Params;
    controls::InletAreaSolveControls=DEFAULT_INLET_AREA_SOLVE_CONTROLS,
)
    validate_inlet_area_solve_controls(controls)
    T = _promote_float_type(Qin, w2, guess)
    Qin_t = T(Qin)
    w2_t = T(w2)
    guess_t = T(guess)
    c0 = invariant_speed_factor(p)
    c0_t = T(c0)
    floor_t = T(AREA_LIMITER_FLOOR)
    residual(A) = Qin_t / A - w2_t - T(4) * c0_t * sqrt(sqrt(A))

    lo = max(guess_t * T(controls.bracket_lower_scale), floor_t)
    hi = max(guess_t * T(controls.bracket_upper_scale), lo * T(controls.bracket_growth_factor))
    flo = residual(lo)
    fhi = residual(hi)

    for _ in 1:controls.max_bracket_iterations
        flo * fhi <= zero(T) && break
        lo = max(lo / T(controls.bracket_growth_factor), floor_t)
        hi *= T(controls.bracket_growth_factor)
        flo = residual(lo)
        fhi = residual(hi)
    end

    if flo * fhi > zero(T)
        @warn "inlet area solver failed to bracket; returning limited guess" Qin w2 guess lo hi flo fhi
        return max(guess_t, floor_t)
    end

    for _ in 1:controls.max_bisection_iterations
        mid = (lo + hi) / T(2)
        fm = residual(mid)
        if abs(fm) < T(controls.residual_tolerance) || abs(hi - lo) < T(controls.area_tolerance)
            return mid
        elseif flo * fm <= zero(T)
            hi = mid
            fhi = fm
        else
            lo = mid
            flo = fm
        end
    end

    return (lo + hi) / T(2)
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
