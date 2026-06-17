abstract type AbstractVelocityProfile end

"""Uniform section velocity with explicit finite shear/friction scaling."""
struct FlatVelocityProfile <: AbstractVelocityProfile
    shear_rate_factor::Float64
end

FlatVelocityProfile(; shear_rate_factor::Real = 4.0) = FlatVelocityProfile(Float64(shear_rate_factor))

"""Poiseuille/parabolic profile normalized by the section-mean velocity."""
struct ParabolicVelocityProfile <: AbstractVelocityProfile end

"""Power-family profile normalized by the section-mean velocity."""
struct PowerVelocityProfile <: AbstractVelocityProfile
    exponent::Float64
end

function PowerVelocityProfile(exponent::Real)
    return PowerVelocityProfile(Float64(exponent))
end

function PowerVelocityProfile(; exponent::Union{Nothing,Real} = nothing, alpha::Union{Nothing,Real} = nothing)
    if exponent !== nothing && alpha !== nothing
        throw(ArgumentError("provide exactly one of exponent or alpha for PowerVelocityProfile"))
    elseif exponent === nothing && alpha === nothing
        throw(ArgumentError("PowerVelocityProfile requires exponent or alpha"))
    elseif exponent !== nothing
        return PowerVelocityProfile(exponent)
    end

    alpha_value = Float64(alpha)
    1.0 < alpha_value < 2.0 ||
        throw(ArgumentError("power velocity profile alpha must satisfy 1 < alpha < 2"))
    return PowerVelocityProfile(normalized_profile_parameter((2.0 - alpha_value) / (alpha_value - 1.0)))
end

profile_name(::FlatVelocityProfile) = "flat"
profile_name(::ParabolicVelocityProfile) = "parabolic"
profile_name(::PowerVelocityProfile) = "power"

momentum_alpha(::FlatVelocityProfile) = 1.0
momentum_alpha(::ParabolicVelocityProfile) = 4.0 / 3.0
momentum_alpha(profile::PowerVelocityProfile) = (profile.exponent + 2.0) / (profile.exponent + 1.0)

shear_rate_factor(profile::FlatVelocityProfile) = profile.shear_rate_factor
shear_rate_factor(::ParabolicVelocityProfile) = 4.0
shear_rate_factor(profile::PowerVelocityProfile) = profile.exponent + 2.0

mean_to_max_velocity_ratio(::FlatVelocityProfile) = 1.0
mean_to_max_velocity_ratio(::ParabolicVelocityProfile) = 0.5
mean_to_max_velocity_ratio(profile::PowerVelocityProfile) = profile.exponent / (profile.exponent + 2.0)

profile_exponent(::AbstractVelocityProfile) = NaN
profile_exponent(::ParabolicVelocityProfile) = 2.0
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

function normalized_profile_parameter(value::Real)
    value64 = Float64(value)
    !isfinite(value64) && return value64
    rounded_integer = round(value64)
    if isapprox(value64, rounded_integer; rtol=1.0e-12, atol=1.0e-12)
        return rounded_integer
    end
    return round(value64; digits=12)
end

function trim_trailing_decimal_zeros(text::AbstractString)
    occursin(".", text) || return text
    stripped = replace(text, r"0+$" => "")
    return replace(stripped, r"\.$" => "")
end

velocity_profile_path_token(::ParabolicVelocityProfile) = "parabolic"
velocity_profile_path_token(profile::FlatVelocityProfile) = "flat_sf_" * path_token(profile.shear_rate_factor)
velocity_profile_path_token(profile::PowerVelocityProfile) = "power_g_" * path_token(profile.exponent)

function radial_profile_velocity(
    uavg::Float64,
    radius::Float64,
    section_radius::Float64,
    ::FlatVelocityProfile,
)
    _ = radius
    _ = section_radius
    return uavg
end

function radial_profile_velocity(
    uavg::Float64,
    radius::Float64,
    section_radius::Float64,
    ::ParabolicVelocityProfile,
)
    ratio = clamp(radius / max(section_radius, eps()), 0.0, 1.0)
    return 2.0 * uavg * (1.0 - ratio^2)
end

function radial_profile_velocity(
    uavg::Float64,
    radius::Float64,
    section_radius::Float64,
    profile::PowerVelocityProfile,
)
    ratio = clamp(radius / max(section_radius, eps()), 0.0, 1.0)
    gamma = profile.exponent
    return ((gamma + 2.0) / gamma) * uavg * (1.0 - ratio^gamma)
end

function validate(profile::FlatVelocityProfile)
    isfinite(profile.shear_rate_factor) || throw(ArgumentError("flat velocity profile shear factor must be finite"))
    profile.shear_rate_factor > 0.0 || throw(ArgumentError("flat velocity profile shear factor must be positive"))
    return profile
end

function validate(profile::ParabolicVelocityProfile)
    return profile
end

function validate(profile::PowerVelocityProfile)
    isfinite(profile.exponent) || throw(ArgumentError("power velocity profile exponent must be finite"))
    profile.exponent > 0.0 || throw(ArgumentError("power velocity profile exponent must be positive"))
    return profile
end
