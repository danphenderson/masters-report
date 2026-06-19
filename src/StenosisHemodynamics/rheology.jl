abstract type AbstractRheology end

"""Constant-viscosity Newtonian closure. Uses `Params.nu` as the kinematic viscosity."""
struct NewtonianRheology <: AbstractRheology end

"""
    CarreauRheology(; eta0, eta_inf, lambda_s, n, shear_rate_floor, min_eta, max_eta)

Dynamic-viscosity Carreau closure in g/(cm*s):
`eta_inf + (eta0 - eta_inf) * (1 + (lambda_s * gamma_dot)^2)^((n - 1) / 2)`.
"""
Base.@kwdef struct CarreauRheology <: AbstractRheology
    eta0::Float64 = 0.56
    eta_inf::Float64 = 0.0345
    lambda_s::Float64 = 3.313
    n::Float64 = 0.3568
    shear_rate_floor::Float64 = 1.0e-8
    min_eta::Float64 = 0.0
    max_eta::Float64 = Inf
end

"""
    CarreauYasudaRheology(; eta0, eta_inf, lambda_s, a, n, shear_rate_floor, min_eta, max_eta)

Dynamic-viscosity Carreau-Yasuda closure in g/(cm*s):
`eta_inf + (eta0 - eta_inf) * (1 + (lambda_s * gamma_dot)^a)^((n - 1) / a)`.
"""
Base.@kwdef struct CarreauYasudaRheology <: AbstractRheology
    eta0::Float64 = 0.56
    eta_inf::Float64 = 0.0345
    lambda_s::Float64 = 3.313
    a::Float64 = 2.0
    n::Float64 = 0.3568
    shear_rate_floor::Float64 = 1.0e-8
    min_eta::Float64 = 0.0
    max_eta::Float64 = Inf
end

"""
    CassonRheology(; yield_stress, plastic_viscosity, shear_rate_floor, min_eta, max_eta)

Dynamic-viscosity Casson closure in g/(cm*s), evaluated as
`(sqrt(yield_stress / gamma_dot) + sqrt(plastic_viscosity))^2`.
"""
Base.@kwdef struct CassonRheology <: AbstractRheology
    yield_stress::Float64 = 0.04
    plastic_viscosity::Float64 = 0.035
    shear_rate_floor::Float64 = 1.0e-8
    min_eta::Float64 = 0.0
    max_eta::Float64 = Inf
end

"""
    PowerLawRheology(; consistency, n, shear_rate_floor, min_eta, max_eta)

Dynamic-viscosity power-law closure in g/(cm*s):
`consistency * gamma_dot^(n - 1)`.
"""
Base.@kwdef struct PowerLawRheology <: AbstractRheology
    consistency::Float64 = 0.035
    n::Float64 = 1.0
    shear_rate_floor::Float64 = 1.0e-8
    min_eta::Float64 = 0.0
    max_eta::Float64 = Inf
end

rheology_name(::NewtonianRheology) = "newtonian"
rheology_name(::CarreauRheology) = "carreau"
rheology_name(::CarreauYasudaRheology) = "carreau-yasuda"
rheology_name(::CassonRheology) = "casson"
rheology_name(::PowerLawRheology) = "power-law"

function validate(r::NewtonianRheology)
    return r
end

function validate(r::CarreauRheology)
    validate_viscosity_window(r.min_eta, r.max_eta, "Carreau")
    r.eta0 > 0.0 || throw(ArgumentError("Carreau eta0 must be positive"))
    r.eta_inf >= 0.0 || throw(ArgumentError("Carreau eta_inf must be nonnegative"))
    r.eta0 >= r.eta_inf || throw(ArgumentError("Carreau eta0 must be at least eta_inf"))
    r.lambda_s >= 0.0 || throw(ArgumentError("Carreau lambda_s must be nonnegative"))
    r.n > 0.0 || throw(ArgumentError("Carreau n must be positive"))
    r.shear_rate_floor > 0.0 || throw(ArgumentError("Carreau shear_rate_floor must be positive"))
    return r
end

function validate(r::CarreauYasudaRheology)
    validate_viscosity_window(r.min_eta, r.max_eta, "Carreau-Yasuda")
    r.eta0 > 0.0 || throw(ArgumentError("Carreau-Yasuda eta0 must be positive"))
    r.eta_inf >= 0.0 || throw(ArgumentError("Carreau-Yasuda eta_inf must be nonnegative"))
    r.eta0 >= r.eta_inf || throw(ArgumentError("Carreau-Yasuda eta0 must be at least eta_inf"))
    r.lambda_s >= 0.0 || throw(ArgumentError("Carreau-Yasuda lambda_s must be nonnegative"))
    r.a > 0.0 || throw(ArgumentError("Carreau-Yasuda a must be positive"))
    r.n > 0.0 || throw(ArgumentError("Carreau-Yasuda n must be positive"))
    r.shear_rate_floor > 0.0 || throw(ArgumentError("Carreau-Yasuda shear_rate_floor must be positive"))
    return r
end

function validate(r::CassonRheology)
    validate_viscosity_window(r.min_eta, r.max_eta, "Casson")
    r.yield_stress >= 0.0 || throw(ArgumentError("Casson yield_stress must be nonnegative"))
    r.plastic_viscosity > 0.0 || throw(ArgumentError("Casson plastic_viscosity must be positive"))
    r.shear_rate_floor > 0.0 || throw(ArgumentError("Casson shear_rate_floor must be positive"))
    return r
end

function validate(r::PowerLawRheology)
    validate_viscosity_window(r.min_eta, r.max_eta, "power-law")
    r.consistency > 0.0 || throw(ArgumentError("power-law consistency must be positive"))
    r.n > 0.0 || throw(ArgumentError("power-law n must be positive"))
    r.shear_rate_floor > 0.0 || throw(ArgumentError("power-law shear_rate_floor must be positive"))
    return r
end

function validate_viscosity_window(min_eta::Float64, max_eta::Float64, label::String)
    min_eta >= 0.0 || throw(ArgumentError("$label min_eta must be nonnegative"))
    max_eta > 0.0 || throw(ArgumentError("$label max_eta must be positive"))
    min_eta <= max_eta || throw(ArgumentError("$label min_eta must be <= max_eta"))
    return nothing
end

safe_shear_rate(shear_rate::Real, floor::Float64) = max(abs(Float64(shear_rate)), floor)

function clamp_dynamic_viscosity(eta::Float64, min_eta::Float64, max_eta::Float64)
    return min(max(eta, min_eta), max_eta)
end

function effective_dynamic_viscosity(
    ::NewtonianRheology,
    shear_rate::Real,
    rho::Real,
    nu::Real,
)
    _ = shear_rate
    return Float64(rho) * Float64(nu)
end

function effective_dynamic_viscosity(r::CarreauRheology, shear_rate::Real, rho::Real, nu::Real)
    _ = rho
    _ = nu
    gamma_dot = safe_shear_rate(shear_rate, r.shear_rate_floor)
    eta = r.eta_inf + (r.eta0 - r.eta_inf) * (1.0 + (r.lambda_s * gamma_dot)^2)^((r.n - 1.0) / 2.0)
    return clamp_dynamic_viscosity(eta, r.min_eta, r.max_eta)
end

function effective_dynamic_viscosity(r::CarreauYasudaRheology, shear_rate::Real, rho::Real, nu::Real)
    _ = rho
    _ = nu
    gamma_dot = safe_shear_rate(shear_rate, r.shear_rate_floor)
    eta = r.eta_inf + (r.eta0 - r.eta_inf) * (1.0 + (r.lambda_s * gamma_dot)^r.a)^((r.n - 1.0) / r.a)
    return clamp_dynamic_viscosity(eta, r.min_eta, r.max_eta)
end

function effective_dynamic_viscosity(r::CassonRheology, shear_rate::Real, rho::Real, nu::Real)
    _ = rho
    _ = nu
    gamma_dot = safe_shear_rate(shear_rate, r.shear_rate_floor)
    eta = (sqrt(r.yield_stress / gamma_dot) + sqrt(r.plastic_viscosity))^2
    return clamp_dynamic_viscosity(eta, r.min_eta, r.max_eta)
end

function effective_dynamic_viscosity(r::PowerLawRheology, shear_rate::Real, rho::Real, nu::Real)
    _ = rho
    _ = nu
    gamma_dot = safe_shear_rate(shear_rate, r.shear_rate_floor)
    eta = r.consistency * gamma_dot^(r.n - 1.0)
    return clamp_dynamic_viscosity(eta, r.min_eta, r.max_eta)
end

function effective_kinematic_viscosity(
    rheology::AbstractRheology,
    shear_rate::Real,
    rho::Real,
    nu::Real,
)
    rho_value = Float64(rho)
    rho_value > 0.0 || throw(ArgumentError("rho must be positive"))
    eta = effective_dynamic_viscosity(rheology, shear_rate, rho_value, nu)
    return eta / rho_value
end

function characteristic_shear_rate(A::Float64, Q::Float64, r0::Float64, p)
    _ = r0
    Apos = positive_area(A)
    radius = max(sqrt(Apos), eps())
    uavg = abs(Q) / Apos
    return gamma_plus_two(p) * uavg / radius
end

function effective_kinematic_viscosity(A::Float64, Q::Float64, r0::Float64, p)
    shear_rate = characteristic_shear_rate(A, Q, r0, p)
    return effective_kinematic_viscosity(p.rheology, shear_rate, p.rho, p.nu)
end
