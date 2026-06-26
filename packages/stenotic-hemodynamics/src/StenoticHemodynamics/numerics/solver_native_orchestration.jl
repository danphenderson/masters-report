function initial_state(p::Params)
    state = initial_state_result(p)
    return state.z, state.area, state.flow, state.dx
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

function thread_slot_range(values::AbstractVector, slot::Integer, slot_count::Integer)
    1 <= slot <= slot_count || throw(ArgumentError("slot must lie in 1:slot_count"))
    offset = firstindex(values) - 1
    lo = offset + fld((slot - 1) * length(values), slot_count) + 1
    hi = slot == slot_count ? lastindex(values) : offset + fld(slot * length(values), slot_count)
    return lo:hi
end

function choose_dt_record_timestep!(
    diagnostics::DiagnosticsAccumulator,
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    remaining_time::Float64,
    p::Params,
    ;
    threaded::Bool = false,
)
    max_speed = 0.0
    if threaded
        thread_count = Threads.nthreads()
        max_speeds = zeros(Float64, thread_count)
        lambda_minus_min = fill(Inf, thread_count)
        lambda_minus_max = fill(-Inf, thread_count)
        lambda_plus_min = fill(Inf, thread_count)
        lambda_plus_max = fill(-Inf, thread_count)
        subcritical_margin_min = fill(Inf, thread_count)

        Threads.@threads :static for slot in 1:thread_count
            for i in thread_slot_range(A, slot, thread_count)
                lambda_minus, lambda_plus, _, _ = characteristic_speeds(A[i], Q[i], z[i], p)
                max_speeds[slot] = max(max_speeds[slot], abs(lambda_minus), abs(lambda_plus))
                lambda_minus_min[slot] = min(lambda_minus_min[slot], lambda_minus)
                lambda_minus_max[slot] = max(lambda_minus_max[slot], lambda_minus)
                lambda_plus_min[slot] = min(lambda_plus_min[slot], lambda_plus)
                lambda_plus_max[slot] = max(lambda_plus_max[slot], lambda_plus)
                subcritical_margin_min[slot] = min(subcritical_margin_min[slot], min(-lambda_minus, lambda_plus))
            end
        end

        max_speed = maximum(max_speeds)
        diagnostics.lambda_minus_min = min(diagnostics.lambda_minus_min, minimum(lambda_minus_min))
        diagnostics.lambda_minus_max = max(diagnostics.lambda_minus_max, maximum(lambda_minus_max))
        diagnostics.lambda_plus_min = min(diagnostics.lambda_plus_min, minimum(lambda_plus_min))
        diagnostics.lambda_plus_max = max(diagnostics.lambda_plus_max, maximum(lambda_plus_max))
        diagnostics.subcritical_margin_min = min(diagnostics.subcritical_margin_min, minimum(subcritical_margin_min))
    else
        for i in eachindex(A)
            lambda_minus, lambda_plus, _, _ = characteristic_speeds(A[i], Q[i], z[i], p)
            max_speed = max(max_speed, abs(lambda_minus), abs(lambda_plus))
            diagnostics.lambda_minus_min = min(diagnostics.lambda_minus_min, lambda_minus)
            diagnostics.lambda_minus_max = max(diagnostics.lambda_minus_max, lambda_minus)
            diagnostics.lambda_plus_min = min(diagnostics.lambda_plus_min, lambda_plus)
            diagnostics.lambda_plus_max = max(diagnostics.lambda_plus_max, lambda_plus)
            diagnostics.subcritical_margin_min = min(diagnostics.subcritical_margin_min, min(-lambda_minus, lambda_plus))
        end
    end

    dt = min(p.dt, p.cfl * dx / max(max_speed, eps()), remaining_time)
    diagnostics.dt_min = min(diagnostics.dt_min, dt)
    diagnostics.dt_max = max(diagnostics.dt_max, dt)
    cfl = max_speed * dt / dx
    diagnostics.cfl_min = min(diagnostics.cfl_min, cfl)
    diagnostics.cfl_max = max(diagnostics.cfl_max, cfl)
    return dt
end
