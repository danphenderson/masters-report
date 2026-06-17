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
    xis, weights = dg_quadrature()
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
    for m in 0:degree
        value += coeffs[i, m + 1] * legendre_value(m, xi)
    end
    return value
end

function dg_derivative(coeffs::AbstractMatrix{Float64}, i::Int, xi::Float64, degree::Int, dx::Float64)
    value = 0.0
    for m in 0:degree
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
)
    degree = method.degree
    nx = size(Acoef, 1)
    dA = zeros(Float64, nx, degree + 1)
    dQ = zeros(Float64, nx, degree + 1)
    FA = zeros(Float64, nx + 1)
    FQ = zeros(Float64, nx + 1)
    means_A = vec(Acoef[:, 1])
    means_Q = vec(Qcoef[:, 1])
    Ain, Qin, Aout, Qout = boundary_states(means_A, means_Q, p)

    for iface in 1:(nx + 1)
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

    xis, weights = dg_quadrature()
    gp2 = gamma_plus_two(p)
    stiffness = wall_stiffness(p)

    for i in 1:nx
        for m in 0:degree
            boundary_A = FA[i + 1] * legendre_value(m, 1.0) - FA[i] * legendre_value(m, -1.0)
            boundary_Q = FQ[i + 1] * legendre_value(m, 1.0) - FQ[i] * legendre_value(m, -1.0)
            volume_A = 0.0
            volume_Q = 0.0
            source_Q = 0.0

            for (xi, w) in zip(xis, weights)
                zq = z[i] + 0.5 * dx * xi
                Aq = max(dg_value(Acoef, i, xi, degree), AREA_LIMITER_FLOOR)
                Qq = dg_value(Qcoef, i, xi, degree)
                dA_dz = dg_derivative(Acoef, i, xi, degree, dx)
                dQ_dz = dg_derivative(Qcoef, i, xi, degree, dx)
                r0, r0z, r0zz = stenosis(zq, p)
                fA, fQ = flux(Aq, Qq, zq, p)
                volume_A += w * fA * legendre_derivative(m, xi)
                volume_Q += w * fQ * legendre_derivative(m, xi)
                source_Q += w * source_point(Aq, Qq, zq, dA_dz, dQ_dz, r0, r0z, r0zz, gp2, stiffness, p) *
                            legendre_value(m, xi)
            end

            scale = 2m + 1
            dA[i, m + 1] = -scale / dx * (boundary_A - volume_A)
            dQ[i, m + 1] = -scale / dx * (boundary_Q - volume_Q) + 0.5 * scale * source_Q
        end
    end

    return dA, dQ
end

function limit_dg_coefficients!(Acoef::Matrix{Float64}, Qcoef::Matrix{Float64}, method::DGMethod)
    degree = method.degree
    degree == 0 && return Acoef, Qcoef
    nx = size(Acoef, 1)
    xis = (-1.0, dg_quadrature()[1]..., 1.0)

    for i in 1:nx
        mean_A = max(Acoef[i, 1], AREA_LIMITER_FLOOR)
        Acoef[i, 1] = mean_A
        min_A = minimum(dg_value(Acoef, i, xi, degree) for xi in xis)
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
                degree >= 2 && (Acoef[i, 3] = 0.0)
                degree >= 2 && (Qcoef[i, 3] = 0.0)
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
    return dg_step(Acoef, Qcoef, z, dx, dt, p.time_stepper, p, method)
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    ::ForwardEulerStepper,
    p::Params,
    method::DGMethod,
)
    dA, dQ = dg_rhs(Acoef, Qcoef, z, dx, p, method)
    Anew = Acoef .+ dt .* dA
    Qnew = Qcoef .+ dt .* dQ
    return limit_dg_coefficients!(Anew, Qnew, method)
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    ::SSPRK2Stepper,
    p::Params,
    method::DGMethod,
)
    dA1, dQ1 = dg_rhs(Acoef, Qcoef, z, dx, p, method)
    A1 = Acoef .+ dt .* dA1
    Q1 = Qcoef .+ dt .* dQ1
    limit_dg_coefficients!(A1, Q1, method)

    dA2, dQ2 = dg_rhs(A1, Q1, z, dx, p, method)
    Anew = 0.5 .* Acoef .+ 0.5 .* (A1 .+ dt .* dA2)
    Qnew = 0.5 .* Qcoef .+ 0.5 .* (Q1 .+ dt .* dQ2)
    return limit_dg_coefficients!(Anew, Qnew, method)
end

function dg_step(
    Acoef::Matrix{Float64},
    Qcoef::Matrix{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    ::SSPRK3Stepper,
    p::Params,
    method::DGMethod,
)
    dA1, dQ1 = dg_rhs(Acoef, Qcoef, z, dx, p, method)
    A1 = Acoef .+ dt .* dA1
    Q1 = Qcoef .+ dt .* dQ1
    limit_dg_coefficients!(A1, Q1, method)

    dA2, dQ2 = dg_rhs(A1, Q1, z, dx, p, method)
    A2 = 0.75 .* Acoef .+ 0.25 .* (A1 .+ dt .* dA2)
    Q2 = 0.75 .* Qcoef .+ 0.25 .* (Q1 .+ dt .* dQ2)
    limit_dg_coefficients!(A2, Q2, method)

    dA3, dQ3 = dg_rhs(A2, Q2, z, dx, p, method)
    Anew = (Acoef .+ 2.0 .* (A2 .+ dt .* dA3)) ./ 3.0
    Qnew = (Qcoef .+ 2.0 .* (Q2 .+ dt .* dQ3)) ./ 3.0
    return limit_dg_coefficients!(Anew, Qnew, method)
end

function choose_dt_dg(Acoef::Matrix{Float64}, Qcoef::Matrix{Float64}, z::Vector{Float64}, dx::Float64, p::Params, method::DGMethod)
    smax = 0.0
    for i in axes(Acoef, 1)
        smax = max(smax, max_wave_speed(max(Acoef[i, 1], AREA_LIMITER_FLOOR), Qcoef[i, 1], z[i], p))
    end
    return min(p.dt, p.cfl * dx / max((2 * method.degree + 1) * smax, eps()))
end

function simulate_dg(p::Params, method::DGMethod; progress_every::Int = 0)
    validate(p)
    method.degree == 0 && return simulate(params_with(p; space=FVFirstOrderMethod()), NativeRK3Backend(); progress_every=progress_every)

    z, Acoef, Qcoef, dx, initial_summary = dg_initial_coefficients_with_summary(p, method)
    limit_dg_coefficients!(Acoef, Qcoef, method)
    t = 0.0
    step = 0

    while t < p.tfinal - 1.0e-14
        dt = min(choose_dt_dg(Acoef, Qcoef, z, dx, p, method), p.tfinal - t)
        Acoef, Qcoef = dg_step(Acoef, Qcoef, z, dx, dt, p, method)
        t += dt
        step += 1

        if progress_every > 0 && step % progress_every == 0
            @info "DG simulation progress" degree=method.degree step t dt minA=minimum(Acoef[:, 1]) maxU=maximum(abs.(Qcoef[:, 1] ./ Acoef[:, 1]))
        end

        if !all(isfinite, Acoef) || !all(isfinite, Qcoef)
            error("non-finite DG solution at t=$(t)")
        end
    end

    A = max.(vec(Acoef[:, 1]), AREA_LIMITER_FLOOR)
    Q = vec(Qcoef[:, 1])
    return SimulationResult(z, A, Q, t, step, initial_summary)
end
