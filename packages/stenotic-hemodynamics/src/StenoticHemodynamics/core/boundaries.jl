abstract type AbstractInletBoundary end
abstract type AbstractOutletBoundary end

"""Steady inlet specified by a maximum profile velocity in cm/s."""
struct SteadyVelocityInlet{T<:AbstractFloat} <: AbstractInletBoundary
    umax::T
end

function SteadyVelocityInlet(umax::Real)
    T = _promote_float_type(umax)
    return SteadyVelocityInlet{T}(T(umax))
end

SteadyVelocityInlet(; umax::Real = 45.0) = SteadyVelocityInlet(umax)

"""
Periodic volumetric-flow inlet waveform.

Times are stored in seconds and flows in cm^3/s. OpenBF inlet files describe
one cardiac period, so interpolation wraps periodically.
"""
struct FlowWaveformInlet{T<:AbstractFloat} <: AbstractInletBoundary
    time_s::Vector{T}
    flow_cm3_s::Vector{T}
    period_s::T
    source_path::String
end

function FlowWaveformInlet{T}(
    time_s::AbstractVector,
    flow_cm3_s::AbstractVector;
    period_s::Union{Nothing,Real} = nothing,
    source_path::AbstractString = "",
) where {T<:AbstractFloat}
    times = T.(collect(time_s))
    flows = T.(collect(flow_cm3_s))
    length(times) == length(flows) ||
        throw(DimensionMismatch("inlet waveform times and flows must have the same length"))
    length(times) >= 2 || throw(ArgumentError("inlet waveform requires at least two samples"))
    all(isfinite, times) || throw(ArgumentError("inlet waveform times must be finite"))
    all(isfinite, flows) || throw(ArgumentError("inlet waveform flows must be finite"))
    isapprox(times[1], zero(T); rtol=zero(T), atol=T(1.0e-12)) ||
        throw(ArgumentError("inlet waveform must start at time 0"))
    all(times[i] < times[i + 1] for i in 1:(length(times) - 1)) ||
        throw(ArgumentError("inlet waveform times must be strictly increasing"))

    period = period_s === nothing ? times[end] : T(period_s)
    period > zero(T) || throw(ArgumentError("inlet waveform period must be positive"))
    period >= times[end] || throw(ArgumentError("inlet waveform period must be at least the last sample time"))

    return FlowWaveformInlet{T}(times, flows, period, String(source_path))
end

function FlowWaveformInlet(
    time_s::AbstractVector,
    flow_cm3_s::AbstractVector;
    period_s::Union{Nothing,Real} = nothing,
    source_path::AbstractString = "",
)
    times = collect(time_s)
    flows = collect(flow_cm3_s)
    length(times) == length(flows) ||
        throw(DimensionMismatch("inlet waveform times and flows must have the same length"))
    length(times) >= 2 || throw(ArgumentError("inlet waveform requires at least two samples"))
    T = period_s === nothing ? _promote_float_type(times[1], flows[1]) : _promote_float_type(times[1], flows[1], period_s)
    return FlowWaveformInlet{T}(times, flows; period_s=period_s, source_path=source_path)
end

struct FixedAreaCharacteristicOutlet <: AbstractOutletBoundary end

"""Outlet reflection coefficient for the incoming characteristic invariant."""
struct ReflectionCoefficientOutlet{T<:AbstractFloat} <: AbstractOutletBoundary
    rt::T
    reference_flow::T
end

function ReflectionCoefficientOutlet(rt::Real; reference_flow::Real = 0.0)
    T = _promote_float_type(rt, reference_flow)
    return ReflectionCoefficientOutlet{T}(T(rt), T(reference_flow))
end

inlet_boundary_name(::SteadyVelocityInlet) = "steady-velocity"
inlet_boundary_name(::FlowWaveformInlet) = "flow-waveform"
outlet_boundary_name(::FixedAreaCharacteristicOutlet) = "fixed-area-characteristic"
outlet_boundary_name(::ReflectionCoefficientOutlet) = "reflection-coefficient"

function validate(boundary::SteadyVelocityInlet)
    boundary.umax >= zero(boundary.umax) || throw(ArgumentError("steady inlet umax must be nonnegative"))
    return boundary
end

function validate(boundary::FlowWaveformInlet)
    FlowWaveformInlet(
        boundary.time_s,
        boundary.flow_cm3_s;
        period_s=boundary.period_s,
        source_path=boundary.source_path,
    )
    return boundary
end

validate(::FixedAreaCharacteristicOutlet) = FixedAreaCharacteristicOutlet()

function validate(boundary::ReflectionCoefficientOutlet)
    -one(boundary.rt) <= boundary.rt <= one(boundary.rt) || throw(ArgumentError("Rt must be in [-1, 1]"))
    isfinite(boundary.reference_flow) || throw(ArgumentError("reference outlet flow must be finite"))
    return boundary
end

function inlet_flow(boundary::SteadyVelocityInlet, p, t::Real)
    _ = t
    r0, _, _ = stenosis(0.0, p)
    return r0^2 * mean_to_max_velocity_ratio(p.velocity_profile) * boundary.umax
end

function inlet_flow(boundary::FlowWaveformInlet{T}, p, t::Real) where {T<:AbstractFloat}
    _ = p
    tau = mod(T(t), boundary.period_s)
    i = searchsortedlast(boundary.time_s, tau)
    i = clamp(i, 1, length(boundary.time_s) - 1)
    t0 = boundary.time_s[i]
    t1 = boundary.time_s[i + 1]
    q0 = boundary.flow_cm3_s[i]
    q1 = boundary.flow_cm3_s[i + 1]
    return q0 + (tau - t0) * (q1 - q0) / (t1 - t0)
end

inlet_flow(p, t::Real) = inlet_flow(p.inlet_boundary, p, t)

function invariant_speed_factor(p)
    return wall_invariant_speed_factor(p)
end

function characteristic_speed_from_area(A::Real, p)
    c0 = invariant_speed_factor(p)
    T = _float_input_type(A)
    Apos = max(T(A), T(AREA_FLOOR))
    return T(c0) * sqrt(sqrt(Apos))
end

function invariant_minus(A::Real, Q::Real, p)
    c = characteristic_speed_from_area(A, p)
    T = _promote_float_type(A, Q)
    Apos = max(T(A), T(AREA_FLOOR))
    return T(Q) / Apos - T(4) * T(c)
end

function invariant_plus(A::Real, Q::Real, p)
    c = characteristic_speed_from_area(A, p)
    T = _promote_float_type(A, Q)
    Apos = max(T(A), T(AREA_FLOOR))
    return T(Q) / Apos + T(4) * T(c)
end

function state_from_invariants(wminus::Real, wplus::Real, p)
    c0 = invariant_speed_factor(p)
    T = _promote_float_type(wminus, wplus)
    c0_t = T(c0)
    speed_term = max((T(wplus) - T(wminus)) / (T(8) * c0_t), sqrt(sqrt(T(AREA_LIMITER_FLOOR))))
    A = max(speed_term^4, T(AREA_LIMITER_FLOOR))
    u = (T(wminus) + T(wplus)) / T(2)
    return A, A * u
end
