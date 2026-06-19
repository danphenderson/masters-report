function manufactured_frequency(forcing::ManufacturedForcing)
    return 2.0 * pi / forcing.period_s
end

function manufactured_shape(z::Float64, p::Params)
    return sin(pi * z / p.length_cm)
end

function manufactured_base_area(z::Float64, p::Params)
    r0, _, _ = stenosis(z, p)
    return r0^2
end

function manufactured_area(forcing::ManufacturedForcing, z::Float64, t::Float64, p::Params)
    base = manufactured_base_area(z, p)
    return base * (1.0 + forcing.area_amplitude * manufactured_shape(z, p) * cos(manufactured_frequency(forcing) * t))
end

function manufactured_flow(forcing::ManufacturedForcing, z::Float64, t::Float64, p::Params)
    s = manufactured_shape(z, p)
    return manufactured_base_area(z, p) * forcing.velocity_amplitude_cm_s * s^2 * sin(manufactured_frequency(forcing) * t)
end

function manufactured_area_t(forcing::ManufacturedForcing, z::Float64, t::Float64, p::Params)
    base = manufactured_base_area(z, p)
    omega = manufactured_frequency(forcing)
    return -base * forcing.area_amplitude * manufactured_shape(z, p) * omega * sin(omega * t)
end

function manufactured_flow_t(forcing::ManufacturedForcing, z::Float64, t::Float64, p::Params)
    s = manufactured_shape(z, p)
    omega = manufactured_frequency(forcing)
    return manufactured_base_area(z, p) * forcing.velocity_amplitude_cm_s * s^2 * omega * cos(omega * t)
end

function exact_manufactured_state(forcing::ManufacturedForcing, z::Float64, t::Float64, p::Params)
    return manufactured_area(forcing, z, t, p), manufactured_flow(forcing, z, t, p)
end

mass_forcing(::NoForcing, _z::Float64, _t::Float64, _p::Params) = 0.0
momentum_forcing(::NoForcing, _z::Float64, _t::Float64, _p::Params) = 0.0

function finite_difference_z(fn, p::Params, z::Float64)
    h = min(1.0e-5 * max(p.length_cm, 1.0), max(p.length_cm, 1.0) / 10000.0)
    left = max(0.0, z - h)
    right = min(p.length_cm, z + h)
    right > left || return 0.0
    return (fn(right) - fn(left)) / (right - left)
end

function mass_forcing(forcing::ManufacturedForcing, z::Float64, t::Float64, p::Params)
    flux_z = finite_difference_z(p, z) do zz
        A, Q = exact_manufactured_state(forcing, zz, t, p)
        return flux(A, Q, zz, p)[1]
    end
    return manufactured_area_t(forcing, z, t, p) + flux_z
end

function momentum_forcing(forcing::ManufacturedForcing, z::Float64, t::Float64, p::Params)
    A, Q = exact_manufactured_state(forcing, z, t, p)
    dA_dz = finite_difference_z(p, z) do zz
        return manufactured_area(forcing, zz, t, p)
    end
    dQ_dz = finite_difference_z(p, z) do zz
        return manufactured_flow(forcing, zz, t, p)
    end
    flux_z = finite_difference_z(p, z) do zz
        Az, Qz = exact_manufactured_state(forcing, zz, t, p)
        return flux(Az, Qz, zz, p)[2]
    end
    r0, r0z, r0zz = stenosis(z, p)
    source = source_point(A, Q, z, dA_dz, dQ_dz, r0, r0z, r0zz, gamma_plus_two(p), p)
    return manufactured_flow_t(forcing, z, t, p) + flux_z - source
end

function characteristic_speeds(A::Float64, Q::Float64, z::Float64, p::Params)
    Apos = positive_area(A)
    _, r0z, _ = stenosis(z, p)
    alpha_eff = momentum_alpha(p) + effective_alpha_c(p, r0z)
    u = Q / Apos
    radicand = (alpha_eff * u)^2 - alpha_eff * u^2 + wall_wave_speed_squared(Apos, z, p)
    c = sqrt(max(radicand, 0.0))
    return alpha_eff * u - c, alpha_eff * u + c, radicand, alpha_eff
end

mutable struct DiagnosticsAccumulator
    dt_min::Float64
    dt_max::Float64
    cfl_min::Float64
    cfl_max::Float64
    lambda_minus_min::Float64
    lambda_minus_max::Float64
    lambda_plus_min::Float64
    lambda_plus_max::Float64
    subcritical_margin_min::Float64
    mass_initial::Float64
    mass_final::Float64
    mass_min::Float64
    mass_max::Float64
    positivity_projection_count::Int
    positivity_correction_total::Float64
end

function DiagnosticsAccumulator(A::Vector{Float64}, dx::Float64)
    mass = section_mass(A, dx)
    return DiagnosticsAccumulator(
        Inf,
        -Inf,
        Inf,
        -Inf,
        Inf,
        -Inf,
        Inf,
        -Inf,
        Inf,
        mass,
        mass,
        mass,
        mass,
        0,
        0.0,
    )
end

section_mass(A::AbstractVector{Float64}, dx::Float64) = sum(A) * dx

function record_timestep_diagnostics!(
    diagnostics::DiagnosticsAccumulator,
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    dt::Float64,
    p::Params,
)
    diagnostics.dt_min = min(diagnostics.dt_min, dt)
    diagnostics.dt_max = max(diagnostics.dt_max, dt)
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
    cfl = max_speed * dt / dx
    diagnostics.cfl_min = min(diagnostics.cfl_min, cfl)
    diagnostics.cfl_max = max(diagnostics.cfl_max, cfl)
    return diagnostics
end

function record_mass_diagnostics!(diagnostics::DiagnosticsAccumulator, A::Vector{Float64}, dx::Float64)
    mass = section_mass(A, dx)
    diagnostics.mass_final = mass
    diagnostics.mass_min = min(diagnostics.mass_min, mass)
    diagnostics.mass_max = max(diagnostics.mass_max, mass)
    return diagnostics
end

function record_projection!(diagnostics::Nothing, _candidate::Float64)
    return nothing
end

function record_projection!(diagnostics::DiagnosticsAccumulator, candidate::Float64)
    if candidate < AREA_LIMITER_FLOOR
        diagnostics.positivity_projection_count += 1
        diagnostics.positivity_correction_total += AREA_LIMITER_FLOOR - candidate
    end
    return diagnostics
end

function limited_area(candidate::Float64, diagnostics)
    record_projection!(diagnostics, candidate)
    return max(candidate, AREA_LIMITER_FLOOR)
end

function finite_or_nan(value::Float64)
    return isfinite(value) ? value : NaN
end

function finalize_diagnostics(diagnostics::DiagnosticsAccumulator)
    return SimulationDiagnostics(
        dt_min=finite_or_nan(diagnostics.dt_min),
        dt_max=finite_or_nan(diagnostics.dt_max),
        cfl_min=finite_or_nan(diagnostics.cfl_min),
        cfl_max=finite_or_nan(diagnostics.cfl_max),
        lambda_minus_min=finite_or_nan(diagnostics.lambda_minus_min),
        lambda_minus_max=finite_or_nan(diagnostics.lambda_minus_max),
        lambda_plus_min=finite_or_nan(diagnostics.lambda_plus_min),
        lambda_plus_max=finite_or_nan(diagnostics.lambda_plus_max),
        subcritical_margin_min=finite_or_nan(diagnostics.subcritical_margin_min),
        mass_initial=diagnostics.mass_initial,
        mass_final=diagnostics.mass_final,
        mass_min=diagnostics.mass_min,
        mass_max=diagnostics.mass_max,
        mass_defect=diagnostics.mass_final - diagnostics.mass_initial,
        positivity_projection_count=diagnostics.positivity_projection_count,
        positivity_correction_total=diagnostics.positivity_correction_total,
    )
end
