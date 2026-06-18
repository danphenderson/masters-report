import DelimitedFiles: readdlm

abstract type AbstractInletBoundary end
abstract type AbstractOutletBoundary end

"""Steady inlet specified by a maximum profile velocity in cm/s."""
struct SteadyVelocityInlet <: AbstractInletBoundary
    umax::Float64
end

SteadyVelocityInlet(umax::Real) = SteadyVelocityInlet(Float64(umax))
SteadyVelocityInlet(; umax::Real = 45.0) = SteadyVelocityInlet(Float64(umax))

"""
Periodic volumetric-flow inlet waveform.

Times are stored in seconds and flows in cm^3/s. OpenBF inlet files describe
one cardiac period, so interpolation wraps periodically.
"""
struct FlowWaveformInlet <: AbstractInletBoundary
    time_s::Vector{Float64}
    flow_cm3_s::Vector{Float64}
    period_s::Float64
    source_path::String
end

function FlowWaveformInlet(
    time_s::AbstractVector,
    flow_cm3_s::AbstractVector;
    period_s::Union{Nothing,Real} = nothing,
    source_path::AbstractString = "",
)
    times = Float64.(collect(time_s))
    flows = Float64.(collect(flow_cm3_s))
    length(times) == length(flows) ||
        throw(DimensionMismatch("inlet waveform times and flows must have the same length"))
    length(times) >= 2 || throw(ArgumentError("inlet waveform requires at least two samples"))
    all(isfinite, times) || throw(ArgumentError("inlet waveform times must be finite"))
    all(isfinite, flows) || throw(ArgumentError("inlet waveform flows must be finite"))
    isapprox(times[1], 0.0; rtol=0.0, atol=1.0e-12) ||
        throw(ArgumentError("inlet waveform must start at time 0"))
    all(times[i] < times[i + 1] for i in 1:(length(times) - 1)) ||
        throw(ArgumentError("inlet waveform times must be strictly increasing"))

    period = period_s === nothing ? times[end] : Float64(period_s)
    period > 0.0 || throw(ArgumentError("inlet waveform period must be positive"))
    period >= times[end] || throw(ArgumentError("inlet waveform period must be at least the last sample time"))

    return FlowWaveformInlet(times, flows, period, String(source_path))
end

function FlowWaveformInlet(path::AbstractString; flow_scale::Real = 1.0)
    data = readdlm(path)
    values = Float64.(data)

    if ndims(values) != 2 || isempty(values)
        throw(ArgumentError("inlet file '$path' must contain numeric time/flow samples"))
    elseif size(values, 2) == 2
        times = values[:, 1]
        flows = values[:, 2]
    else
        flat = vec(values)
        iseven(length(flat)) ||
            throw(ArgumentError("inlet file '$path' must contain pairs of time and flow values"))
        times = flat[1:2:end]
        flows = flat[2:2:end]
    end

    return FlowWaveformInlet(times, Float64(flow_scale) .* flows; source_path=path)
end

struct FixedAreaCharacteristicOutlet <: AbstractOutletBoundary end

"""Outlet reflection coefficient for the incoming characteristic invariant."""
struct ReflectionCoefficientOutlet <: AbstractOutletBoundary
    rt::Float64
    reference_flow::Float64
end

function ReflectionCoefficientOutlet(rt::Real; reference_flow::Real = 0.0)
    return ReflectionCoefficientOutlet(Float64(rt), Float64(reference_flow))
end

inlet_boundary_name(::SteadyVelocityInlet) = "steady-velocity"
inlet_boundary_name(::FlowWaveformInlet) = "flow-waveform"
outlet_boundary_name(::FixedAreaCharacteristicOutlet) = "fixed-area-characteristic"
outlet_boundary_name(::ReflectionCoefficientOutlet) = "reflection-coefficient"

function validate(boundary::SteadyVelocityInlet)
    boundary.umax >= 0.0 || throw(ArgumentError("steady inlet umax must be nonnegative"))
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
    -1.0 <= boundary.rt <= 1.0 || throw(ArgumentError("Rt must be in [-1, 1]"))
    isfinite(boundary.reference_flow) || throw(ArgumentError("reference outlet flow must be finite"))
    return boundary
end

function inlet_flow(boundary::SteadyVelocityInlet, p, t::Real)
    _ = t
    r0, _, _ = stenosis(0.0, p)
    return r0^2 * mean_to_max_velocity_ratio(p.velocity_profile) * boundary.umax
end

function inlet_flow(boundary::FlowWaveformInlet, p, t::Real)
    _ = p
    tau = mod(Float64(t), boundary.period_s)
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

function characteristic_speed_from_area(A::Float64, p)
    return invariant_speed_factor(p) * positive_area(A)^0.25
end

function invariant_minus(A::Float64, Q::Float64, p)
    Apos = positive_area(A)
    return Q / Apos - 4.0 * characteristic_speed_from_area(Apos, p)
end

function invariant_plus(A::Float64, Q::Float64, p)
    Apos = positive_area(A)
    return Q / Apos + 4.0 * characteristic_speed_from_area(Apos, p)
end

function state_from_invariants(wminus::Float64, wplus::Float64, p)
    c0 = invariant_speed_factor(p)
    speed_term = max((wplus - wminus) / (8.0 * c0), AREA_LIMITER_FLOOR^0.25)
    A = max(speed_term^4, AREA_LIMITER_FLOOR)
    u = 0.5 * (wminus + wplus)
    return A, A * u
end
