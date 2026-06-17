abstract type AbstractLimiter end
abstract type AbstractSpatialMethod end
abstract type AbstractNativeTimeStepper end

"""Total-variation-diminishing minmod slope limiter."""
struct MinmodLimiter <: AbstractLimiter end

"""Legacy first-order finite-volume Rusanov method."""
struct FVFirstOrderMethod <: AbstractSpatialMethod end

"""MUSCL finite-volume method with a TVD limiter."""
struct FVMUSCLMethod{L<:AbstractLimiter} <: AbstractSpatialMethod
    limiter::L
end

FVMUSCLMethod() = FVMUSCLMethod(MinmodLimiter())

"""Richtmyer/Lax-Wendroff finite-volume method with limited interface states."""
struct FVLaxWendroffMethod{L<:AbstractLimiter} <: AbstractSpatialMethod
    limiter::L
end

FVLaxWendroffMethod() = FVLaxWendroffMethod(MinmodLimiter())

"""Modal Legendre DG method for polynomial degrees 0, 1, and 2."""
struct DGMethod <: AbstractSpatialMethod
    degree::Int

    function DGMethod(degree::Int)
        0 <= degree <= 2 || throw(ArgumentError("DG degree must be 0, 1, or 2"))
        return new(degree)
    end
end

DGMethod() = DGMethod(1)

struct ForwardEulerStepper <: AbstractNativeTimeStepper end
struct SSPRK2Stepper <: AbstractNativeTimeStepper end
struct SSPRK3Stepper <: AbstractNativeTimeStepper end

limiter_name(::MinmodLimiter) = "minmod"

spatial_method_name(::FVFirstOrderMethod) = "fv-first-order"
spatial_method_name(method::FVMUSCLMethod) = "fv-muscl-$(limiter_name(method.limiter))"
spatial_method_name(method::FVLaxWendroffMethod) = "fv-lax-wendroff-$(limiter_name(method.limiter))"
spatial_method_name(method::DGMethod) = "dg-p$(method.degree)"

time_stepper_name(::ForwardEulerStepper) = "euler"
time_stepper_name(::SSPRK2Stepper) = "ssprk2"
time_stepper_name(::SSPRK3Stepper) = "ssprk3"

validate(::MinmodLimiter) = MinmodLimiter()
validate(::FVFirstOrderMethod) = FVFirstOrderMethod()
validate(method::FVMUSCLMethod) = (validate(method.limiter); method)
validate(method::FVLaxWendroffMethod) = (validate(method.limiter); method)
validate(method::DGMethod) = (0 <= method.degree <= 2 || throw(ArgumentError("DG degree must be 0, 1, or 2")); method)
validate(::ForwardEulerStepper) = ForwardEulerStepper()
validate(::SSPRK2Stepper) = SSPRK2Stepper()
validate(::SSPRK3Stepper) = SSPRK3Stepper()

function minmod(a::Float64, b::Float64)
    sign(a) == sign(b) || return 0.0
    return sign(a) * min(abs(a), abs(b))
end

function minmod(a::Float64, b::Float64, c::Float64)
    return minmod(a, minmod(b, c))
end

function limited_slope(values::AbstractVector{Float64}, i::Int, ::MinmodLimiter)
    firstindex(values) < i < lastindex(values) || return 0.0
    return minmod(values[i] - values[i - 1], values[i + 1] - values[i])
end

function legendre_value(degree::Int, xi::Float64)
    degree == 0 && return 1.0
    degree == 1 && return xi
    degree == 2 && return 0.5 * (3.0 * xi^2 - 1.0)
    throw(ArgumentError("Legendre degree must be 0, 1, or 2"))
end

function legendre_derivative(degree::Int, xi::Float64)
    degree == 0 && return 0.0
    degree == 1 && return 1.0
    degree == 2 && return 3.0 * xi
    throw(ArgumentError("Legendre degree must be 0, 1, or 2"))
end

function dg_quadrature()
    r = sqrt(3.0 / 5.0)
    return (-r, 0.0, r), (5.0 / 9.0, 8.0 / 9.0, 5.0 / 9.0)
end

function dg_degrees_of_freedom(nx::Int, method::DGMethod)
    return 2 * nx * (method.degree + 1)
end

dg_degrees_of_freedom(nx::Int, ::AbstractSpatialMethod) = 2 * nx
