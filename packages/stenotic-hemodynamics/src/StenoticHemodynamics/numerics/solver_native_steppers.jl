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
