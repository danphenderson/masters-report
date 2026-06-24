abstract type AbstractVelocityProfile end

"""Uniform section velocity with explicit finite shear/friction scaling."""
struct FlatVelocityProfile{T<:AbstractFloat} <: AbstractVelocityProfile
    shear_rate_factor::T
end

function FlatVelocityProfile(shear_rate_factor::Real)
    T = _float_input_type(shear_rate_factor)
    return FlatVelocityProfile{T}(T(shear_rate_factor))
end
FlatVelocityProfile(; shear_rate_factor::Real = 4.0) = FlatVelocityProfile(shear_rate_factor)

"""Poiseuille/parabolic profile normalized by the section-mean velocity."""
struct ParabolicVelocityProfile{T<:AbstractFloat} <: AbstractVelocityProfile end

ParabolicVelocityProfile() = ParabolicVelocityProfile{Float64}()
ParabolicVelocityProfile(::Type{T}) where {T<:AbstractFloat} = ParabolicVelocityProfile{T}()

"""Power-family profile normalized by the section-mean velocity."""
struct PowerVelocityProfile{T<:AbstractFloat} <: AbstractVelocityProfile
    exponent::T
end

function PowerVelocityProfile(exponent::Real)
    T = _float_input_type(exponent)
    return PowerVelocityProfile{T}(T(exponent))
end

function PowerVelocityProfile(; exponent::Union{Nothing,Real} = nothing, alpha::Union{Nothing,Real} = nothing)
    if exponent !== nothing && alpha !== nothing
        throw(ArgumentError("provide exactly one of exponent or alpha for PowerVelocityProfile"))
    elseif exponent === nothing && alpha === nothing
        throw(ArgumentError("PowerVelocityProfile requires exponent or alpha"))
    elseif exponent !== nothing
        return PowerVelocityProfile(exponent)
    end

    T = _float_input_type(alpha)
    alpha_value = T(alpha)
    one_t = one(T)
    two_t = one_t + one_t
    one_t < alpha_value < two_t ||
        throw(ArgumentError("power velocity profile alpha must satisfy 1 < alpha < 2"))
    return PowerVelocityProfile(normalized_profile_parameter((two_t - alpha_value) / (alpha_value - one_t)))
end

profile_name(::FlatVelocityProfile) = "flat"
profile_name(::ParabolicVelocityProfile) = "parabolic"
profile_name(::PowerVelocityProfile) = "power"

momentum_alpha(profile::FlatVelocityProfile{T}) where {T<:AbstractFloat} = one(T)
momentum_alpha(::ParabolicVelocityProfile{T}) where {T<:AbstractFloat} = T(4) / T(3)
function momentum_alpha(profile::PowerVelocityProfile{T}) where {T<:AbstractFloat}
    return (profile.exponent + T(2)) / (profile.exponent + one(T))
end

shear_rate_factor(profile::FlatVelocityProfile) = profile.shear_rate_factor
shear_rate_factor(::ParabolicVelocityProfile{T}) where {T<:AbstractFloat} = T(4)
shear_rate_factor(profile::PowerVelocityProfile{T}) where {T<:AbstractFloat} = profile.exponent + T(2)

mean_to_max_velocity_ratio(profile::FlatVelocityProfile{T}) where {T<:AbstractFloat} = one(T)
mean_to_max_velocity_ratio(::ParabolicVelocityProfile{T}) where {T<:AbstractFloat} = one(T) / T(2)
function mean_to_max_velocity_ratio(profile::PowerVelocityProfile{T}) where {T<:AbstractFloat}
    return profile.exponent / (profile.exponent + T(2))
end

profile_exponent(::AbstractVelocityProfile) = NaN
profile_exponent(::FlatVelocityProfile{T}) where {T<:AbstractFloat} = T(NaN)
profile_exponent(::ParabolicVelocityProfile{T}) where {T<:AbstractFloat} = T(2)
profile_exponent(profile::PowerVelocityProfile) = profile.exponent

function path_token(value::Real)
    text = string(normalized_profile_parameter(value))
    lowered = lowercase(text)
    if occursin('e', lowered)
        mantissa, exponent = split(lowered, 'e'; limit=2)
        return replace(trim_trailing_decimal_zeros(mantissa), "." => "p", "-" => "m", "+" => "") *
               "e" *
               replace(trim_trailing_decimal_zeros(exponent), "." => "p", "-" => "m", "+" => "")
    end
    return replace(trim_trailing_decimal_zeros(text), "." => "p", "-" => "m", "+" => "")
end

path_token(value) = replace(trim_trailing_decimal_zeros(string(value)), "." => "p", "-" => "m", "+" => "")

function normalized_profile_parameter(value::T) where {T<:AbstractFloat}
    !isfinite(value) && return value
    rounded_integer = round(value)
    if isapprox(value, rounded_integer; rtol=T(1.0e-12), atol=T(1.0e-12))
        return rounded_integer
    end
    return round(value; digits=12)
end

normalized_profile_parameter(value::Real) = normalized_profile_parameter(_float_input_type(value)(value))

function trim_trailing_decimal_zeros(text::AbstractString)
    occursin(".", text) || return text
    stripped = replace(text, r"0+$" => "")
    return replace(stripped, r"\.$" => "")
end

velocity_profile_path_token(::ParabolicVelocityProfile) = "parabolic"
velocity_profile_path_token(profile::FlatVelocityProfile) = "flat_sf_" * path_token(profile.shear_rate_factor)
velocity_profile_path_token(profile::PowerVelocityProfile) = "power_g_" * path_token(profile.exponent)

function radial_profile_velocity(
    uavg::Real,
    radius::Real,
    section_radius::Real,
    ::FlatVelocityProfile,
)
    T = _promote_float_type(uavg, radius, section_radius)
    return T(uavg)
end

function radial_profile_velocity(
    uavg::Real,
    radius::Real,
    section_radius::Real,
    ::ParabolicVelocityProfile,
)
    T = _promote_float_type(uavg, radius, section_radius)
    uavg_t = T(uavg)
    radius_t = T(radius)
    section_radius_t = T(section_radius)
    ratio = clamp(radius_t / max(section_radius_t, eps(T)), zero(T), one(T))
    return T(2) * uavg_t * (one(T) - ratio^2)
end

function radial_profile_velocity(
    uavg::Real,
    radius::Real,
    section_radius::Real,
    profile::PowerVelocityProfile,
)
    T = _promote_float_type(uavg, radius, section_radius, profile.exponent)
    uavg_t = T(uavg)
    radius_t = T(radius)
    section_radius_t = T(section_radius)
    gamma = T(profile.exponent)
    ratio = clamp(radius_t / max(section_radius_t, eps(T)), zero(T), one(T))
    return ((gamma + T(2)) / gamma) * uavg_t * (one(T) - ratio^gamma)
end

function validate(profile::FlatVelocityProfile{T}) where {T<:AbstractFloat}
    isfinite(profile.shear_rate_factor) || throw(ArgumentError("flat velocity profile shear factor must be finite"))
    profile.shear_rate_factor > zero(T) || throw(ArgumentError("flat velocity profile shear factor must be positive"))
    return profile
end

function validate(profile::ParabolicVelocityProfile{T}) where {T<:AbstractFloat}
    return profile
end

function validate(profile::PowerVelocityProfile{T}) where {T<:AbstractFloat}
    isfinite(profile.exponent) || throw(ArgumentError("power velocity profile exponent must be finite"))
    profile.exponent > zero(T) || throw(ArgumentError("power velocity profile exponent must be positive"))
    return profile
end
