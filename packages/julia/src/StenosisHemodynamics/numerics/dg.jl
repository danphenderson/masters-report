struct DGSimulationCoefficients
    z::Vector{Float64}
    area_coefficients::Matrix{Float64}
    flow_coefficients::Matrix{Float64}
    dx::Float64
    completed_time::Float64
    steps::Int
    initial_condition::Union{Nothing,InitialConditionSummary}
    diagnostics::SimulationDiagnostics
end

struct DGRHSCache
    dA::Matrix{Float64}
    dQ::Matrix{Float64}
    area_flux::Vector{Float64}
    flow_flux::Vector{Float64}
end

function DGRHSCache(nx::Int, degree::Int)
    nx > 0 || throw(ArgumentError("nx must be positive"))
    0 <= degree <= MAX_DG_DEGREE || throw(ArgumentError("DG degree must be in 0:$MAX_DG_DEGREE"))
    modes = degree + 1
    return DGRHSCache(
        zeros(Float64, nx, modes),
        zeros(Float64, nx, modes),
        zeros(Float64, nx + 1),
        zeros(Float64, nx + 1),
    )
end

struct DGStepCache
    rhs::DGRHSCache
    A1::Matrix{Float64}
    Q1::Matrix{Float64}
    A2::Matrix{Float64}
    Q2::Matrix{Float64}
    A3::Matrix{Float64}
    Q3::Matrix{Float64}
end

function DGStepCache(nx::Int, degree::Int)
    nx > 0 || throw(ArgumentError("nx must be positive"))
    0 <= degree <= MAX_DG_DEGREE || throw(ArgumentError("DG degree must be in 0:$MAX_DG_DEGREE"))
    modes = degree + 1
    return DGStepCache(
        DGRHSCache(nx, degree),
        zeros(Float64, nx, modes),
        zeros(Float64, nx, modes),
        zeros(Float64, nx, modes),
        zeros(Float64, nx, modes),
        zeros(Float64, nx, modes),
        zeros(Float64, nx, modes),
    )
end

function dg_initial_coefficients(p::Params, method::DGMethod)
    z, Acoef, Qcoef, dx, _ = dg_initial_coefficients_with_summary(p, method)
    return z, Acoef, Qcoef, dx
end

function dg_initial_coefficients_with_summary(p::Params, method::DGMethod)
    degree = method.degree
    dx = p.length_cm / p.nx
    z = [(i - 0.5) * dx for i in 1:p.nx]
    Acoef = zeros(Float64, p.nx, degree + 1)
    Qcoef = zeros(Float64, p.nx, degree + 1)
    xis, weights = dg_quadrature(degree)
    zq = Float64[]

    for i in 1:p.nx
        for xi in xis
            push!(zq, z[i] + 0.5 * dx * xi)
        end
    end

    Aq_values, Qq_values, summary = initial_condition_values(p, zq)
    sample = 1

    for i in 1:p.nx
        for m in 0:degree
            acc_A = 0.0
            acc_Q = 0.0
            local_sample = sample
            for (xi, w) in zip(xis, weights)
                acc_A += w * Aq_values[local_sample] * legendre_value(m, xi)
                acc_Q += w * Qq_values[local_sample] * legendre_value(m, xi)
                local_sample += 1
            end
            Acoef[i, m + 1] = 0.5 * (2m + 1) * acc_A
            Qcoef[i, m + 1] = 0.5 * (2m + 1) * acc_Q
        end
        sample += length(xis)
    end

    return z, Acoef, Qcoef, dx, summary
end

function dg_value(coeffs::AbstractMatrix{Float64}, i::Int, xi::Float64, degree::Int)
    value = 0.0
    @inbounds for m in 0:degree
        value += coeffs[i, m + 1] * legendre_value(m, xi)
    end
    return value
end

function dg_derivative(coeffs::AbstractMatrix{Float64}, i::Int, xi::Float64, degree::Int, dx::Float64)
    value = 0.0
    @inbounds for m in 0:degree
        value += coeffs[i, m + 1] * legendre_derivative(m, xi)
    end
    return 2.0 * value / dx
end

function dg_rhs(
    Acoef::AbstractMatrix{Float64},
    Qcoef::AbstractMatrix{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    p::Params,
    method::DGMethod,
    t::Float64 = 0.0,
)
    degree = method.degree
    nx = size(Acoef, 1)
    cache = DGRHSCache(nx, degree)
    fill_dg_rhs!(cache.dA, cache.dQ, Acoef, Qcoef, z, dx, p, method, t, cache)
    return cache.dA, cache.dQ
end

function fill_dg_rhs!(
    dA::AbstractMatrix{Float64},
    dQ::AbstractMatrix{Float64},
    Acoef::AbstractMatrix{Float64},
    Qcoef::AbstractMatrix{Float64},
    z::AbstractVector{Float64},
    dx::Float64,
    p::Params,
    method::DGMethod,
    t::Float64,
    cache::DGRHSCache,
)
    degree = method.degree
    nx = size(Acoef, 1)
    modes = degree + 1
    size(Acoef) == size(Qcoef) || throw(DimensionMismatch("DG area and flow coefficient sizes must match"))
    size(Acoef, 2) == modes || throw(DimensionMismatch("DG coefficient mode count does not match method degree"))
    size(dA) == size(Acoef) || throw(DimensionMismatch("DG area derivative size mismatch"))
    size(dQ) == size(Qcoef) || throw(DimensionMismatch("DG flow derivative size mismatch"))
    length(z) == nx || throw(DimensionMismatch("DG grid and coefficient lengths must match"))

    FA = cache.area_flux
    FQ = cache.flow_flux
    length(FA) == nx + 1 || throw(DimensionMismatch("DG area flux cache length mismatch"))
    length(FQ) == nx + 1 || throw(DimensionMismatch("DG flow flux cache length mismatch"))
    @inbounds begin
        Ain, Qin, Aout, Qout =
            boundary_states_from_values(Acoef[begin, 1], Qcoef[begin, 1], Acoef[end, 1], Qcoef[end, 1], p, t)
    end

    @inbounds for iface in 1:(nx + 1)
        if iface == 1
            AL, QL = Ain, Qin
            AR = max(dg_value(Acoef, 1, -1.0, degree), AREA_LIMITER_FLOOR)
            QR = dg_value(Qcoef, 1, -1.0, degree)
            zi = 0.0
        elseif iface == nx + 1
            AL = max(dg_value(Acoef, nx, 1.0, degree), AREA_LIMITER_FLOOR)
            QL = dg_value(Qcoef, nx, 1.0, degree)
            AR, QR = Aout, Qout
            zi = p.length_cm
        else
            left = iface - 1
            right = iface
            AL = max(dg_value(Acoef, left, 1.0, degree), AREA_LIMITER_FLOOR)
            QL = dg_value(Qcoef, left, 1.0, degree)
            AR = max(dg_value(Acoef, right, -1.0, degree), AREA_LIMITER_FLOOR)
            QR = dg_value(Qcoef, right, -1.0, degree)
            zi = 0.5 * (z[left] + z[right])
        end

        FA[iface], FQ[iface] = rusanov_flux(AL, QL, AR, QR, zi, p)
    end

    xis, weights = dg_quadrature(degree)
    gp2 = gamma_plus_two(p)

    @inbounds for i in 1:nx
        for m in 0:degree
            left_test = isodd(m) ? -1.0 : 1.0
            boundary_A = FA[i + 1] - FA[i] * left_test
            boundary_Q = FQ[i + 1] - FQ[i] * left_test
            volume_A = 0.0
            volume_Q = 0.0
            source_A = 0.0
            source_Q = 0.0

            for q in eachindex(xis)
                xi = xis[q]
                w = weights[q]
                zq = z[i] + 0.5 * dx * xi
                Aq = max(dg_value(Acoef, i, xi, degree), AREA_LIMITER_FLOOR)
                Qq = dg_value(Qcoef, i, xi, degree)
                dA_dz = dg_derivative(Acoef, i, xi, degree, dx)
                dQ_dz = dg_derivative(Qcoef, i, xi, degree, dx)
                r0, r0z, r0zz = stenosis(zq, p)
                fA, fQ = flux(Aq, Qq, zq, p)
                volume_A += w * fA * legendre_derivative(m, xi)
                volume_Q += w * fQ * legendre_derivative(m, xi)
                test_value = legendre_value(m, xi)
                source_A += w * mass_forcing(p.forcing, zq, t, p) * test_value
                source_Q += w * (
                    source_point(Aq, Qq, zq, dA_dz, dQ_dz, r0, r0z, r0zz, gp2, p) +
                    momentum_forcing(p.forcing, zq, t, p)
                ) * test_value
            end

            scale = 2m + 1
            dA[i, m + 1] = -scale / dx * (boundary_A - volume_A) + 0.5 * scale * source_A
            dQ[i, m + 1] = -scale / dx * (boundary_Q - volume_Q) + 0.5 * scale * source_Q
        end
    end

    return dA, dQ
end

function limit_dg_coefficients!(Acoef::Matrix{Float64}, Qcoef::Matrix{Float64}, method::DGMethod)
    degree = method.degree
    degree == 0 && return Acoef, Qcoef
    nx = size(Acoef, 1)
    quadrature_xis, _ = dg_quadrature(degree)

    @inbounds for i in 1:nx
        mean_A = max(Acoef[i, 1], AREA_LIMITER_FLOOR)
        Acoef[i, 1] = mean_A
        min_A = min(dg_value(Acoef, i, -1.0, degree), dg_value(Acoef, i, 1.0, degree))
        for q in eachindex(quadrature_xis)
            min_A = min(min_A, dg_value(Acoef, i, quadrature_xis[q], degree))
        end
        if min_A < AREA_LIMITER_FLOOR
            theta = min(1.0, (mean_A - AREA_LIMITER_FLOOR) / max(mean_A - min_A, eps()))
            for m in 1:degree
                Acoef[i, m + 1] *= theta
            end
        end

        if 1 < i < nx
            limited_A1 = minmod(Acoef[i, 2], Acoef[i, 1] - Acoef[i - 1, 1], Acoef[i + 1, 1] - Acoef[i, 1])
            limited_Q1 = minmod(Qcoef[i, 2], Qcoef[i, 1] - Qcoef[i - 1, 1], Qcoef[i + 1, 1] - Qcoef[i, 1])
            if limited_A1 != Acoef[i, 2] || limited_Q1 != Qcoef[i, 2]
                Acoef[i, 2] = limited_A1
                Qcoef[i, 2] = limited_Q1
                for m in 2:degree
                    Acoef[i, m + 1] = 0.0
                    Qcoef[i, m + 1] = 0.0
                end
            end
        else
            for m in 1:degree
                Acoef[i, m + 1] = 0.0
                Qcoef[i, m + 1] = 0.0
            end
        end
    end

    return Acoef, Qcoef
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    p::Params,
    method::DGMethod,
)
    return dg_step(Acoef, Qcoef, z, dx, dt, 0.0, p.time_stepper, p, method)
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    p::Params,
    method::DGMethod,
)
    return dg_step(Acoef, Qcoef, z, dx, dt, t, p.time_stepper, p, method)
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::ForwardEulerStepper,
    p::Params,
    method::DGMethod,
)
    Anew = copy(Acoef)
    Qnew = copy(Qcoef)
    cache = DGStepCache(size(Acoef, 1), method.degree)
    return dg_step!(Anew, Qnew, z, dx, dt, t, ForwardEulerStepper(), p, method, cache)
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK2Stepper,
    p::Params,
    method::DGMethod,
)
    Anew = copy(Acoef)
    Qnew = copy(Qcoef)
    cache = DGStepCache(size(Acoef, 1), method.degree)
    return dg_step!(Anew, Qnew, z, dx, dt, t, SSPRK2Stepper(), p, method, cache)
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK3Stepper,
    p::Params,
    method::DGMethod,
)
    Anew = copy(Acoef)
    Qnew = copy(Qcoef)
    cache = DGStepCache(size(Acoef, 1), method.degree)
    return dg_step!(Anew, Qnew, z, dx, dt, t, SSPRK3Stepper(), p, method, cache)
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK54Stepper,
    p::Params,
    method::DGMethod,
)
    Anew = copy(Acoef)
    Qnew = copy(Qcoef)
    cache = DGStepCache(size(Acoef, 1), method.degree)
    return dg_step!(Anew, Qnew, z, dx, dt, t, SSPRK54Stepper(), p, method, cache)
end

function dg_step!(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    p::Params,
    method::DGMethod,
    cache::DGStepCache,
)
    return dg_step!(Acoef, Qcoef, z, dx, dt, t, p.time_stepper, p, method, cache)
end

function dg_step!(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::ForwardEulerStepper,
    p::Params,
    method::DGMethod,
    cache::DGStepCache,
)
    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, Acoef, Qcoef, z, dx, p, method, t, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        Acoef[i] += dt * cache.rhs.dA[i]
        Qcoef[i] += dt * cache.rhs.dQ[i]
    end
    return limit_dg_coefficients!(Acoef, Qcoef, method)
end

function dg_step!(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK2Stepper,
    p::Params,
    method::DGMethod,
    cache::DGStepCache,
)
    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, Acoef, Qcoef, z, dx, p, method, t, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        cache.A1[i] = Acoef[i] + dt * cache.rhs.dA[i]
        cache.Q1[i] = Qcoef[i] + dt * cache.rhs.dQ[i]
    end
    limit_dg_coefficients!(cache.A1, cache.Q1, method)

    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, cache.A1, cache.Q1, z, dx, p, method, t + dt, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        Acoef[i] = 0.5 * Acoef[i] + 0.5 * (cache.A1[i] + dt * cache.rhs.dA[i])
        Qcoef[i] = 0.5 * Qcoef[i] + 0.5 * (cache.Q1[i] + dt * cache.rhs.dQ[i])
    end
    return limit_dg_coefficients!(Acoef, Qcoef, method)
end

function dg_step!(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK3Stepper,
    p::Params,
    method::DGMethod,
    cache::DGStepCache,
)
    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, Acoef, Qcoef, z, dx, p, method, t, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        cache.A1[i] = Acoef[i] + dt * cache.rhs.dA[i]
        cache.Q1[i] = Qcoef[i] + dt * cache.rhs.dQ[i]
    end
    limit_dg_coefficients!(cache.A1, cache.Q1, method)

    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, cache.A1, cache.Q1, z, dx, p, method, t + dt, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        cache.A2[i] = 0.75 * Acoef[i] + 0.25 * (cache.A1[i] + dt * cache.rhs.dA[i])
        cache.Q2[i] = 0.75 * Qcoef[i] + 0.25 * (cache.Q1[i] + dt * cache.rhs.dQ[i])
    end
    limit_dg_coefficients!(cache.A2, cache.Q2, method)

    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, cache.A2, cache.Q2, z, dx, p, method, t + 0.5 * dt, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        Acoef[i] = (Acoef[i] + 2.0 * (cache.A2[i] + dt * cache.rhs.dA[i])) / 3.0
        Qcoef[i] = (Qcoef[i] + 2.0 * (cache.Q2[i] + dt * cache.rhs.dQ[i])) / 3.0
    end
    return limit_dg_coefficients!(Acoef, Qcoef, method)
end

function dg_step!(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    t::Float64,
    ::SSPRK54Stepper,
    p::Params,
    method::DGMethod,
    cache::DGStepCache,
)
    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, Acoef, Qcoef, z, dx, p, method, t, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        cache.A1[i] = Acoef[i] + 0.391752226571890 * dt * cache.rhs.dA[i]
        cache.Q1[i] = Qcoef[i] + 0.391752226571890 * dt * cache.rhs.dQ[i]
    end
    limit_dg_coefficients!(cache.A1, cache.Q1, method)

    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, cache.A1, cache.Q1, z, dx, p, method, t + 0.391752226571890 * dt, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        cache.A1[i] =
            0.444370493651235 * Acoef[i] +
            0.555629506348765 * cache.A1[i] +
            0.368410593050371 * dt * cache.rhs.dA[i]
        cache.Q1[i] =
            0.444370493651235 * Qcoef[i] +
            0.555629506348765 * cache.Q1[i] +
            0.368410593050371 * dt * cache.rhs.dQ[i]
    end
    limit_dg_coefficients!(cache.A1, cache.Q1, method)

    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, cache.A1, cache.Q1, z, dx, p, method, t + 0.586079688967798 * dt, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        cache.A2[i] =
            0.620101851488403 * Acoef[i] +
            0.379898148511597 * cache.A1[i] +
            0.251891774271694 * dt * cache.rhs.dA[i]
        cache.Q2[i] =
            0.620101851488403 * Qcoef[i] +
            0.379898148511597 * cache.Q1[i] +
            0.251891774271694 * dt * cache.rhs.dQ[i]
    end
    limit_dg_coefficients!(cache.A2, cache.Q2, method)

    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, cache.A2, cache.Q2, z, dx, p, method, t + 0.474542363026872 * dt, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        cache.A3[i] =
            0.178079954393132 * Acoef[i] +
            0.821920045606868 * cache.A2[i] +
            0.544974750228521 * dt * cache.rhs.dA[i]
        cache.Q3[i] =
            0.178079954393132 * Qcoef[i] +
            0.821920045606868 * cache.Q2[i] +
            0.544974750228521 * dt * cache.rhs.dQ[i]
    end
    limit_dg_coefficients!(cache.A3, cache.Q3, method)

    fill_dg_rhs!(cache.rhs.dA, cache.rhs.dQ, cache.A3, cache.Q3, z, dx, p, method, t + 0.935010630967653 * dt, cache.rhs)
    @inbounds for i in eachindex(Acoef)
        Acoef[i] =
            0.517231671970585 * cache.A1[i] +
            0.096059710526147 * cache.A2[i] +
            0.386708617503269 * cache.A3[i] +
            0.063692468666290 * dt * cache.rhs.dA[i]
        Qcoef[i] =
            0.517231671970585 * cache.Q1[i] +
            0.096059710526147 * cache.Q2[i] +
            0.386708617503269 * cache.Q3[i] +
            0.063692468666290 * dt * cache.rhs.dQ[i]
    end
    return limit_dg_coefficients!(Acoef, Qcoef, method)
end

function choose_dt_dg(Acoef::Matrix{Float64}, Qcoef::Matrix{Float64}, z::Vector{Float64}, dx::Float64, p::Params, method::DGMethod)
    smax = 0.0
    for i in axes(Acoef, 1)
        smax = max(smax, max_wave_speed(max(Acoef[i, 1], AREA_LIMITER_FLOOR), Qcoef[i, 1], z[i], p))
    end
    return min(p.dt, p.cfl * dx / max((2 * method.degree + 1) * smax, eps()))
end

function simulate_dg_coefficients(p::Params, method::DGMethod; progress_every::Int = 0)
    method.degree == 0 && return simulate_dg0_coefficients(p; progress_every=progress_every)

    validate(p)
    z, Acoef, Qcoef, dx, initial_summary = dg_initial_coefficients_with_summary(p, method)
    limit_dg_coefficients!(Acoef, Qcoef, method)
    step_cache = DGStepCache(size(Acoef, 1), method.degree)
    diagnostics = DiagnosticsAccumulator(vec(Acoef[:, 1]), dx)
    t = 0.0
    step = 0

    while t < p.tfinal - 1.0e-14
        dt = min(choose_dt_dg(Acoef, Qcoef, z, dx, p, method), p.tfinal - t)
        record_timestep_diagnostics!(diagnostics, vec(Acoef[:, 1]), vec(Qcoef[:, 1]), z, dx, dt, p)
        dg_step!(Acoef, Qcoef, z, dx, dt, t, p, method, step_cache)
        t += dt
        step += 1
        record_mass_diagnostics!(diagnostics, max.(vec(Acoef[:, 1]), AREA_LIMITER_FLOOR), dx)

        if progress_every > 0 && step % progress_every == 0
            @telemetry_info "DG simulation progress" event="simulation_progress" stage="simulate" backend="native" method=spatial_method_name(method) nx=p.nx tfinal=p.tfinal status="running" degree=method.degree step t dt minA=minimum(Acoef[:, 1]) maxU=maximum(abs.(Qcoef[:, 1] ./ Acoef[:, 1]))
        end

        if !all(isfinite, Acoef) || !all(isfinite, Qcoef)
            error("non-finite DG solution at t=$(t)")
        end
    end

    return DGSimulationCoefficients(z, Acoef, Qcoef, dx, t, step, initial_summary, finalize_diagnostics(diagnostics))
end

function simulate_dg0_coefficients(p::Params; progress_every::Int = 0)
    result = simulate(params_with(p; space=FVFirstOrderMethod()), NativeRK3Backend(); progress_every=progress_every)
    return DGSimulationCoefficients(
        result.z,
        reshape(copy(result.area), :, 1),
        reshape(copy(result.flow), :, 1),
        p.length_cm / p.nx,
        result.completed_time,
        result.steps,
        result.initial_condition,
        result.diagnostics,
    )
end

function simulate_dg(p::Params, method::DGMethod; progress_every::Int = 0)
    start_ns = telemetry_start_ns()
    @telemetry_info "simulation started" event="simulation_started" stage="simulate" backend="native" method=spatial_method_name(method) nx=p.nx tfinal=p.tfinal status="started"
    try
        validate(p)
        method.degree == 0 && return simulate(params_with(p; space=FVFirstOrderMethod()), NativeRK3Backend(); progress_every=progress_every)

        coefficients = simulate_dg_coefficients(p, method; progress_every=progress_every)
        A = max.(vec(coefficients.area_coefficients[:, 1]), AREA_LIMITER_FLOOR)
        Q = vec(coefficients.flow_coefficients[:, 1])
        result = SimulationResult(
            coefficients.z,
            A,
            Q,
            coefficients.completed_time,
            coefficients.steps,
            coefficients.initial_condition,
            coefficients.diagnostics,
        )
        @telemetry_info "simulation completed" event="simulation_completed" stage="simulate" backend="native" method=spatial_method_name(method) nx=p.nx tfinal=p.tfinal status="ok" elapsed_s=telemetry_elapsed_s(start_ns) rows=length(A)
        return result
    catch err
        @telemetry_error "simulation failed" event="simulation_failed" stage="simulate" backend="native" method=spatial_method_name(method) nx=p.nx tfinal=p.tfinal status="error" elapsed_s=telemetry_elapsed_s(start_ns) reason=sprint(showerror, err)
        rethrow()
    end
end
