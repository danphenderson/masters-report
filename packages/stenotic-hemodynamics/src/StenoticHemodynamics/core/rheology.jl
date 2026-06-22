abstract type AbstractRheology end

_float_input_type(::T) where {T<:AbstractFloat} = T
_float_input_type(::Real) = Float64
_promote_float_type(value::Real) = _float_input_type(value)
_promote_float_type(a::Real, b::Real...) = promote_type(_float_input_type(a), _promote_float_type(b...))

"""Constant-viscosity Newtonian closure. Uses `Params.nu` as the kinematic viscosity."""
struct NewtonianRheology <: AbstractRheology end

"""
    CarreauRheology(; eta0, eta_inf, lambda_s, n, shear_rate_floor, min_eta, max_eta)

Dynamic-viscosity Carreau closure in g/(cm*s):
`eta_inf + (eta0 - eta_inf) * (1 + (lambda_s * gamma_dot)^2)^((n - 1) / 2)`.
"""
struct CarreauRheology{T<:AbstractFloat} <: AbstractRheology
    eta0::T
    eta_inf::T
    lambda_s::T
    n::T
    shear_rate_floor::T
    min_eta::T
    max_eta::T
end

"""
    CarreauYasudaRheology(; eta0, eta_inf, lambda_s, a, n, shear_rate_floor, min_eta, max_eta)

Dynamic-viscosity Carreau-Yasuda closure in g/(cm*s):
`eta_inf + (eta0 - eta_inf) * (1 + (lambda_s * gamma_dot)^a)^((n - 1) / a)`.
"""
struct CarreauYasudaRheology{T<:AbstractFloat} <: AbstractRheology
    eta0::T
    eta_inf::T
    lambda_s::T
    a::T
    n::T
    shear_rate_floor::T
    min_eta::T
    max_eta::T
end

"""
    CassonRheology(; yield_stress, plastic_viscosity, shear_rate_floor, min_eta, max_eta)

Dynamic-viscosity Casson closure in g/(cm*s), evaluated as
`(sqrt(yield_stress / gamma_dot) + sqrt(plastic_viscosity))^2`.
"""
struct CassonRheology{T<:AbstractFloat} <: AbstractRheology
    yield_stress::T
    plastic_viscosity::T
    shear_rate_floor::T
    min_eta::T
    max_eta::T
end

"""
    PowerLawRheology(; consistency, n, shear_rate_floor, min_eta, max_eta)

Dynamic-viscosity power-law closure in g/(cm*s):
`consistency * gamma_dot^(n - 1)`.
"""
struct PowerLawRheology{T<:AbstractFloat} <: AbstractRheology
    consistency::T
    n::T
    shear_rate_floor::T
    min_eta::T
    max_eta::T
end

function CarreauRheology{T}(;
    eta0::Real = T(0.56),
    eta_inf::Real = T(0.0345),
    lambda_s::Real = T(3.313),
    n::Real = T(0.3568),
    shear_rate_floor::Real = T(1.0e-8),
    min_eta::Real = zero(T),
    max_eta::Real = T(Inf),
) where {T<:AbstractFloat}
    return CarreauRheology{T}(
        T(eta0),
        T(eta_inf),
        T(lambda_s),
        T(n),
        T(shear_rate_floor),
        T(min_eta),
        T(max_eta),
    )
end

function CarreauRheology(;
    eta0::Union{Nothing,Real} = nothing,
    eta_inf::Union{Nothing,Real} = nothing,
    lambda_s::Union{Nothing,Real} = nothing,
    n::Union{Nothing,Real} = nothing,
    shear_rate_floor::Union{Nothing,Real} = nothing,
    min_eta::Union{Nothing,Real} = nothing,
    max_eta::Union{Nothing,Real} = nothing,
)
    provided = [value for value in (eta0, eta_inf, lambda_s, n, shear_rate_floor, min_eta, max_eta) if value !== nothing]
    T = isempty(provided) ? Float64 : _promote_float_type(provided...)
    return CarreauRheology{T}(
        eta0=something(eta0, T(0.56)),
        eta_inf=something(eta_inf, T(0.0345)),
        lambda_s=something(lambda_s, T(3.313)),
        n=something(n, T(0.3568)),
        shear_rate_floor=something(shear_rate_floor, T(1.0e-8)),
        min_eta=something(min_eta, zero(T)),
        max_eta=something(max_eta, T(Inf)),
    )
end

function CarreauYasudaRheology{T}(;
    eta0::Real = T(0.56),
    eta_inf::Real = T(0.0345),
    lambda_s::Real = T(3.313),
    a::Real = T(2.0),
    n::Real = T(0.3568),
    shear_rate_floor::Real = T(1.0e-8),
    min_eta::Real = zero(T),
    max_eta::Real = T(Inf),
) where {T<:AbstractFloat}
    return CarreauYasudaRheology{T}(
        T(eta0),
        T(eta_inf),
        T(lambda_s),
        T(a),
        T(n),
        T(shear_rate_floor),
        T(min_eta),
        T(max_eta),
    )
end

function CarreauYasudaRheology(;
    eta0::Union{Nothing,Real} = nothing,
    eta_inf::Union{Nothing,Real} = nothing,
    lambda_s::Union{Nothing,Real} = nothing,
    a::Union{Nothing,Real} = nothing,
    n::Union{Nothing,Real} = nothing,
    shear_rate_floor::Union{Nothing,Real} = nothing,
    min_eta::Union{Nothing,Real} = nothing,
    max_eta::Union{Nothing,Real} = nothing,
)
    provided = [value for value in (eta0, eta_inf, lambda_s, a, n, shear_rate_floor, min_eta, max_eta) if value !== nothing]
    T = isempty(provided) ? Float64 : _promote_float_type(provided...)
    return CarreauYasudaRheology{T}(
        eta0=something(eta0, T(0.56)),
        eta_inf=something(eta_inf, T(0.0345)),
        lambda_s=something(lambda_s, T(3.313)),
        a=something(a, T(2.0)),
        n=something(n, T(0.3568)),
        shear_rate_floor=something(shear_rate_floor, T(1.0e-8)),
        min_eta=something(min_eta, zero(T)),
        max_eta=something(max_eta, T(Inf)),
    )
end

function CassonRheology{T}(;
    yield_stress::Real = T(0.04),
    plastic_viscosity::Real = T(0.035),
    shear_rate_floor::Real = T(1.0e-8),
    min_eta::Real = zero(T),
    max_eta::Real = T(Inf),
) where {T<:AbstractFloat}
    return CassonRheology{T}(
        T(yield_stress),
        T(plastic_viscosity),
        T(shear_rate_floor),
        T(min_eta),
        T(max_eta),
    )
end

function CassonRheology(;
    yield_stress::Union{Nothing,Real} = nothing,
    plastic_viscosity::Union{Nothing,Real} = nothing,
    shear_rate_floor::Union{Nothing,Real} = nothing,
    min_eta::Union{Nothing,Real} = nothing,
    max_eta::Union{Nothing,Real} = nothing,
)
    provided = [value for value in (yield_stress, plastic_viscosity, shear_rate_floor, min_eta, max_eta) if value !== nothing]
    T = isempty(provided) ? Float64 : _promote_float_type(provided...)
    return CassonRheology{T}(
        yield_stress=something(yield_stress, T(0.04)),
        plastic_viscosity=something(plastic_viscosity, T(0.035)),
        shear_rate_floor=something(shear_rate_floor, T(1.0e-8)),
        min_eta=something(min_eta, zero(T)),
        max_eta=something(max_eta, T(Inf)),
    )
end

function PowerLawRheology{T}(;
    consistency::Real = T(0.035),
    n::Real = one(T),
    shear_rate_floor::Real = T(1.0e-8),
    min_eta::Real = zero(T),
    max_eta::Real = T(Inf),
) where {T<:AbstractFloat}
    return PowerLawRheology{T}(
        T(consistency),
        T(n),
        T(shear_rate_floor),
        T(min_eta),
        T(max_eta),
    )
end

function PowerLawRheology(;
    consistency::Union{Nothing,Real} = nothing,
    n::Union{Nothing,Real} = nothing,
    shear_rate_floor::Union{Nothing,Real} = nothing,
    min_eta::Union{Nothing,Real} = nothing,
    max_eta::Union{Nothing,Real} = nothing,
)
    provided = [value for value in (consistency, n, shear_rate_floor, min_eta, max_eta) if value !== nothing]
    T = isempty(provided) ? Float64 : _promote_float_type(provided...)
    return PowerLawRheology{T}(
        consistency=something(consistency, T(0.035)),
        n=something(n, one(T)),
        shear_rate_floor=something(shear_rate_floor, T(1.0e-8)),
        min_eta=something(min_eta, zero(T)),
        max_eta=something(max_eta, T(Inf)),
    )
end

rheology_name(::NewtonianRheology) = "newtonian"
rheology_name(::CarreauRheology) = "carreau"
rheology_name(::CarreauYasudaRheology) = "carreau-yasuda"
rheology_name(::CassonRheology) = "casson"
rheology_name(::PowerLawRheology) = "power-law"

function validate(r::NewtonianRheology)
    return r
end

function validate(r::CarreauRheology{T}) where {T<:AbstractFloat}
    validate_viscosity_window(r.min_eta, r.max_eta, "Carreau")
    r.eta0 > zero(T) || throw(ArgumentError("Carreau eta0 must be positive"))
    r.eta_inf >= zero(T) || throw(ArgumentError("Carreau eta_inf must be nonnegative"))
    r.eta0 >= r.eta_inf || throw(ArgumentError("Carreau eta0 must be at least eta_inf"))
    r.lambda_s >= zero(T) || throw(ArgumentError("Carreau lambda_s must be nonnegative"))
    r.n > zero(T) || throw(ArgumentError("Carreau n must be positive"))
    r.shear_rate_floor > zero(T) || throw(ArgumentError("Carreau shear_rate_floor must be positive"))
    return r
end

function validate(r::CarreauYasudaRheology{T}) where {T<:AbstractFloat}
    validate_viscosity_window(r.min_eta, r.max_eta, "Carreau-Yasuda")
    r.eta0 > zero(T) || throw(ArgumentError("Carreau-Yasuda eta0 must be positive"))
    r.eta_inf >= zero(T) || throw(ArgumentError("Carreau-Yasuda eta_inf must be nonnegative"))
    r.eta0 >= r.eta_inf || throw(ArgumentError("Carreau-Yasuda eta0 must be at least eta_inf"))
    r.lambda_s >= zero(T) || throw(ArgumentError("Carreau-Yasuda lambda_s must be nonnegative"))
    r.a > zero(T) || throw(ArgumentError("Carreau-Yasuda a must be positive"))
    r.n > zero(T) || throw(ArgumentError("Carreau-Yasuda n must be positive"))
    r.shear_rate_floor > zero(T) || throw(ArgumentError("Carreau-Yasuda shear_rate_floor must be positive"))
    return r
end

function validate(r::CassonRheology{T}) where {T<:AbstractFloat}
    validate_viscosity_window(r.min_eta, r.max_eta, "Casson")
    r.yield_stress >= zero(T) || throw(ArgumentError("Casson yield_stress must be nonnegative"))
    r.plastic_viscosity > zero(T) || throw(ArgumentError("Casson plastic_viscosity must be positive"))
    r.shear_rate_floor > zero(T) || throw(ArgumentError("Casson shear_rate_floor must be positive"))
    return r
end

function validate(r::PowerLawRheology{T}) where {T<:AbstractFloat}
    validate_viscosity_window(r.min_eta, r.max_eta, "power-law")
    r.consistency > zero(T) || throw(ArgumentError("power-law consistency must be positive"))
    r.n > zero(T) || throw(ArgumentError("power-law n must be positive"))
    r.shear_rate_floor > zero(T) || throw(ArgumentError("power-law shear_rate_floor must be positive"))
    return r
end

function validate_viscosity_window(min_eta::T, max_eta::T, label::String) where {T<:AbstractFloat}
    min_eta >= zero(T) || throw(ArgumentError("$label min_eta must be nonnegative"))
    max_eta > zero(T) || throw(ArgumentError("$label max_eta must be positive"))
    min_eta <= max_eta || throw(ArgumentError("$label min_eta must be <= max_eta"))
    return nothing
end

safe_shear_rate(shear_rate::Real, floor::T) where {T<:AbstractFloat} = max(abs(T(shear_rate)), floor)

function clamp_dynamic_viscosity(eta::T, min_eta::T, max_eta::T) where {T<:AbstractFloat}
    return min(max(eta, min_eta), max_eta)
end

function effective_dynamic_viscosity(
    ::NewtonianRheology,
    shear_rate::Real,
    rho::Real,
    nu::Real,
)
    _ = shear_rate
    T = _promote_float_type(rho, nu)
    return T(rho) * T(nu)
end

function effective_dynamic_viscosity(r::CarreauRheology{T}, shear_rate::Real, rho::Real, nu::Real) where {T<:AbstractFloat}
    _ = rho
    _ = nu
    gamma_dot = safe_shear_rate(shear_rate, r.shear_rate_floor)
    one_t = one(T)
    eta = r.eta_inf + (r.eta0 - r.eta_inf) * (one_t + (r.lambda_s * gamma_dot)^2)^((r.n - one_t) / T(2))
    return clamp_dynamic_viscosity(eta, r.min_eta, r.max_eta)
end

function effective_dynamic_viscosity(r::CarreauYasudaRheology{T}, shear_rate::Real, rho::Real, nu::Real) where {T<:AbstractFloat}
    _ = rho
    _ = nu
    gamma_dot = safe_shear_rate(shear_rate, r.shear_rate_floor)
    one_t = one(T)
    eta = r.eta_inf + (r.eta0 - r.eta_inf) * (one_t + (r.lambda_s * gamma_dot)^r.a)^((r.n - one_t) / r.a)
    return clamp_dynamic_viscosity(eta, r.min_eta, r.max_eta)
end

function effective_dynamic_viscosity(r::CassonRheology{T}, shear_rate::Real, rho::Real, nu::Real) where {T<:AbstractFloat}
    _ = rho
    _ = nu
    gamma_dot = safe_shear_rate(shear_rate, r.shear_rate_floor)
    eta = (sqrt(r.yield_stress / gamma_dot) + sqrt(r.plastic_viscosity))^2
    return clamp_dynamic_viscosity(eta, r.min_eta, r.max_eta)
end

function effective_dynamic_viscosity(r::PowerLawRheology{T}, shear_rate::Real, rho::Real, nu::Real) where {T<:AbstractFloat}
    _ = rho
    _ = nu
    gamma_dot = safe_shear_rate(shear_rate, r.shear_rate_floor)
    eta = r.consistency * gamma_dot^(r.n - one(T))
    return clamp_dynamic_viscosity(eta, r.min_eta, r.max_eta)
end

function effective_kinematic_viscosity(
    rheology::AbstractRheology,
    shear_rate::Real,
    rho::Real,
    nu::Real,
)
    rho_type = _float_input_type(rho)
    rho_value = rho_type(rho)
    rho_value > zero(rho_type) || throw(ArgumentError("rho must be positive"))
    eta = effective_dynamic_viscosity(rheology, shear_rate, rho_value, nu)
    T = promote_type(typeof(eta), rho_type)
    return T(eta) / T(rho_value)
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
