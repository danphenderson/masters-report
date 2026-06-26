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

function choose_dt_record_timestep!(
    diagnostics::DiagnosticsAccumulator,
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    remaining_time::Float64,
    p::Params,
)
    max_speed = 0.0
    for i in eachindex(A)
        lambda_minus, lambda_plus, _, _ = characteristic_speeds(A[i], Q[i], z[i], p)
        max_speed = max(max_speed, abs(lambda_minus), abs(lambda_plus))
        diagnostics.lambda_minus_min = min(diagnostics.lambda_minus_min, lambda_minus)
        diagnostics.lambda_minus_max = max(diagnostics.lambda_minus_max, lambda_minus)
        diagnostics.lambda_plus_min = min(diagnostics.lambda_plus_min, lambda_plus)
        diagnostics.lambda_plus_max = max(diagnostics.lambda_plus_max, lambda_plus)
        diagnostics.subcritical_margin_min = min(diagnostics.subcritical_margin_min, min(-lambda_minus, lambda_plus))
    end

    dt = min(p.dt, p.cfl * dx / max(max_speed, eps()), remaining_time)
    diagnostics.dt_min = min(diagnostics.dt_min, dt)
    diagnostics.dt_max = max(diagnostics.dt_max, dt)
    cfl = max_speed * dt / dx
    diagnostics.cfl_min = min(diagnostics.cfl_min, cfl)
    diagnostics.cfl_max = max(diagnostics.cfl_max, cfl)
    return dt
end
