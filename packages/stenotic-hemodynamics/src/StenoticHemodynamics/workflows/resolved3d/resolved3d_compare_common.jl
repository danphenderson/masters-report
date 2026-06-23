function default_profile_slices(p::Params)
    throat = stenosis_throat_z(p)
    return clamp.([throat - 0.5, throat, throat + 0.5], 0.0, p.length_cm)
end

function stenosis_throat_z(p::Params; samples::Int = 2001)
    samples >= 3 || throw(ArgumentError("samples must be at least 3"))
    best_z = 0.0
    best_r = Inf
    for z in range(0.0, p.length_cm; length=samples)
        r0, _, _ = stenosis(Float64(z), p)
        if r0 < best_r
            best_r = r0
            best_z = Float64(z)
        end
    end
    return best_z
end

function resolved3d_time_fields(field::Resolved3DVelocityField, result::SimulationResult)
    return resolved3d_time_fields(field.case_spec.target_time, field.metadata.time, result.completed_time)
end

function resolved3d_time_fields(target_time::Real, xdmf_time::Real, one_d_completed_time::Real)
    target_time_s = Float64(target_time)
    xdmf_time_s = Float64(xdmf_time)
    one_d_completed_time_s = Float64(one_d_completed_time)
    return (
        target_time_s=target_time_s,
        one_d_completed_time_s=one_d_completed_time_s,
        one_d_terminal_time_error_s=terminal_time_error(one_d_completed_time_s, target_time_s),
        xdmf_target_time_error_s=terminal_time_error(xdmf_time_s, target_time_s),
        cross_model_time_offset_s=terminal_time_error(xdmf_time_s, one_d_completed_time_s),
    )
end

function resolved3d_run_fields(case::Resolved3DCaseSpec, params::Params, backend::AbstractTimeBackend)
    return (
        model=model_name(params),
        nx=params.nx,
        dt_s=params.dt,
        initial_condition=initial_condition_name(params.initial_condition),
        backend=backend_name(backend),
        run_status="ok",
        time_atol_s=case.time_atol,
    )
end

function one_dimensional_profile_velocity(uavg::Float64, radius::Float64, section_radius::Float64, p::Params)
    return radial_profile_velocity(uavg, radius, section_radius, p.velocity_profile)
end

function interpolate_linear(x::Vector{Float64}, y::Vector{Float64}, x0::Float64)
    length(x) == length(y) || throw(DimensionMismatch("interpolation vectors must have matching lengths"))
    isempty(x) && throw(ArgumentError("cannot interpolate empty vectors"))
    x0 <= x[begin] && return y[begin]
    x0 >= x[end] && return y[end]

    hi = searchsortedfirst(x, x0)
    lo = hi - 1
    weight = (x0 - x[lo]) / (x[hi] - x[lo])
    return (1.0 - weight) * y[lo] + weight * y[hi]
end

function abs_or_nan(a::Float64, b::Float64)
    return isfinite(a) && isfinite(b) ? abs(a - b) : NaN
end

function relative_error(abs_error::Float64, reference::Float64)
    return isfinite(abs_error) && isfinite(reference) ? abs_error / max(abs(reference), eps()) : NaN
end
