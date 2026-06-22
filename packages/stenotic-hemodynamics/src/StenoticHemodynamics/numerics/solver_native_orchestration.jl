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
