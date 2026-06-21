"""
    AbstractLimiter

Limiter protocol for slope-reconstructed finite-volume methods.

To add a limiter, subtype `AbstractLimiter` and define:

- `limiter_name(limiter) -> String`
- `validate(limiter) -> limiter`
- `limited_slope(values, i, limiter) -> Float64`

Limiter implementations are intentionally small and allocation-free so they can
be called inside reconstruction kernels.
"""
abstract type AbstractLimiter end

"""
    AbstractSpatialMethod

Spatial discretization protocol for 1D stenosis simulations.

To add a spatial method, subtype `AbstractSpatialMethod` and define
`spatial_method_name`, `validate`, `method_family`, `degrees_of_freedom`, and a
`fill_method_fluxes!` method when the method uses the cell-mean RHS path. Methods
that need a dedicated solver should specialize `requires_fixed_timestep`,
`requires_native_modal_solver`, and `supports_backend` rather than adding
method-specific conditionals to backend code.
"""
abstract type AbstractSpatialMethod end

"""
    AbstractNativeTimeStepper

Native fixed-step time-stepper protocol.

Subtypes must define `time_stepper_name`, `validate`, and a `native_step!`
method that advances `(A, Q)` in place using the existing cache objects.
Steppers are intentionally separate from spatial methods: a spatial method
describes flux/state layout, while a stepper owns only time integration over the
native RHS.
"""
abstract type AbstractNativeTimeStepper end

"""Total-variation-diminishing minmod slope limiter."""
struct MinmodLimiter <: AbstractLimiter end

"""Smooth TVD Van Leer slope limiter for finite-volume reconstructions."""
struct VanLeerLimiter <: AbstractLimiter end

"""Legacy first-order finite-volume Rusanov method."""
struct FVFirstOrderMethod <: AbstractSpatialMethod end

"""MUSCL finite-volume method with a TVD limiter."""
struct FVMUSCLMethod{L<:AbstractLimiter} <: AbstractSpatialMethod
    limiter::L
end

FVMUSCLMethod() = FVMUSCLMethod(MinmodLimiter())

"""Characteristic-wise third-order WENO finite-volume method with Rusanov flux."""
struct FVWENO3Method <: AbstractSpatialMethod
    epsilon::Float64

    function FVWENO3Method(epsilon::Real = 1.0e-6)
        epsilon > 0.0 || throw(ArgumentError("WENO epsilon must be positive"))
        return new(Float64(epsilon))
    end
end

"""Richtmyer/Lax-Wendroff finite-volume method with limited interface states."""
struct FVLaxWendroffMethod{L<:AbstractLimiter} <: AbstractSpatialMethod
    limiter::L
end

FVLaxWendroffMethod() = FVLaxWendroffMethod(MinmodLimiter())

const MAX_DG_DEGREE = 4

"""Modal Legendre DG method for polynomial degrees 0 through 4."""
struct DGMethod <: AbstractSpatialMethod
    degree::Int

    function DGMethod(degree::Int)
        0 <= degree <= MAX_DG_DEGREE || throw(ArgumentError("DG degree must be in 0:$MAX_DG_DEGREE"))
        return new(degree)
    end
end

DGMethod() = DGMethod(1)

struct ForwardEulerStepper <: AbstractNativeTimeStepper end
struct SSPRK2Stepper <: AbstractNativeTimeStepper end
struct SSPRK3Stepper <: AbstractNativeTimeStepper end
struct SSPRK54Stepper <: AbstractNativeTimeStepper end

limiter_name(::MinmodLimiter) = "minmod"
limiter_name(::VanLeerLimiter) = "van-leer"

spatial_method_name(::FVFirstOrderMethod) = "fv-first-order"
spatial_method_name(method::FVMUSCLMethod) = "fv-muscl-$(limiter_name(method.limiter))"
spatial_method_name(::FVWENO3Method) = "fv-weno3"
spatial_method_name(method::FVLaxWendroffMethod) = "fv-lax-wendroff-$(limiter_name(method.limiter))"
spatial_method_name(method::DGMethod) = "dg-p$(method.degree)"

time_stepper_name(::ForwardEulerStepper) = "euler"
time_stepper_name(::SSPRK2Stepper) = "ssprk2"
time_stepper_name(::SSPRK3Stepper) = "ssprk3"
time_stepper_name(::SSPRK54Stepper) = "ssprk54"

validate(::MinmodLimiter) = MinmodLimiter()
validate(::VanLeerLimiter) = VanLeerLimiter()
validate(::FVFirstOrderMethod) = FVFirstOrderMethod()
validate(method::FVMUSCLMethod) = (validate(method.limiter); method)
validate(method::FVWENO3Method) = (method.epsilon > 0.0 || throw(ArgumentError("WENO epsilon must be positive")); method)
validate(method::FVLaxWendroffMethod) = (validate(method.limiter); method)
validate(method::DGMethod) = (
    0 <= method.degree <= MAX_DG_DEGREE || throw(ArgumentError("DG degree must be in 0:$MAX_DG_DEGREE"));
    method
)
validate(::ForwardEulerStepper) = ForwardEulerStepper()
validate(::SSPRK2Stepper) = SSPRK2Stepper()
validate(::SSPRK3Stepper) = SSPRK3Stepper()
validate(::SSPRK54Stepper) = SSPRK54Stepper()

function minmod(a::Float64, b::Float64)
    sign(a) == sign(b) || return 0.0
    return sign(a) * min(abs(a), abs(b))
end

function minmod(a::Float64, b::Float64, c::Float64)
    return minmod(a, minmod(b, c))
end

function vanleer(a::Float64, b::Float64)
    a * b > 0.0 || return 0.0
    return 2.0 * a * b / (a + b)
end

function limited_slope(values::AbstractVector{Float64}, i::Int, ::MinmodLimiter)
    firstindex(values) < i < lastindex(values) || return 0.0
    return minmod(values[i] - values[i - 1], values[i + 1] - values[i])
end

function limited_slope(values::AbstractVector{Float64}, i::Int, ::VanLeerLimiter)
    firstindex(values) < i < lastindex(values) || return 0.0
    return vanleer(values[i] - values[i - 1], values[i + 1] - values[i])
end

"""
    method_family(method) -> Symbol

Internal trait identifying the broad spatial-method family. New spatial methods
should return either an existing family symbol or a new symbol documented with
their solver path.
"""
method_family(::FVFirstOrderMethod) = :finite_volume
method_family(::FVMUSCLMethod) = :finite_volume
method_family(::FVWENO3Method) = :finite_volume
method_family(::FVLaxWendroffMethod) = :finite_volume
method_family(::DGMethod) = :discontinuous_galerkin

"""
    requires_fixed_timestep(method) -> Bool

Return `true` when a spatial method needs the native fixed-step time increment
inside its flux construction and therefore cannot use generic SciML RHS solves.
"""
requires_fixed_timestep(::AbstractSpatialMethod) = false
requires_fixed_timestep(::FVLaxWendroffMethod) = true

"""
    requires_native_modal_solver(method) -> Bool

Return `true` when a method needs the package-native modal solver rather than the
cell-mean RHS path used by SciML.
"""
requires_native_modal_solver(::AbstractSpatialMethod) = false
requires_native_modal_solver(method::DGMethod) = method.degree > 0

"""
    degrees_of_freedom(nx, method) -> Int

Return the number of scalar conserved-variable degrees of freedom for `nx`
cells and a spatial method.
"""
degrees_of_freedom(nx::Int, ::AbstractSpatialMethod) = 2 * nx
degrees_of_freedom(nx::Int, method::DGMethod) = 2 * nx * (method.degree + 1)

function legendre_value(degree::Int, xi::Float64)
    0 <= degree <= MAX_DG_DEGREE || throw(ArgumentError("Legendre degree must be in 0:$MAX_DG_DEGREE"))
    degree == 0 && return 1.0
    p_nm2 = 1.0
    p_nm1 = xi
    degree == 1 && return p_nm1
    p_n = p_nm1
    for n in 2:degree
        p_n = ((2n - 1) * xi * p_nm1 - (n - 1) * p_nm2) / n
        p_nm2 = p_nm1
        p_nm1 = p_n
    end
    return p_n
end

function legendre_derivative(degree::Int, xi::Float64)
    0 <= degree <= MAX_DG_DEGREE || throw(ArgumentError("Legendre degree must be in 0:$MAX_DG_DEGREE"))
    degree == 0 && return 0.0
    p_nm2 = 1.0
    p_nm1 = xi
    dp_nm2 = 0.0
    dp_nm1 = 1.0
    degree == 1 && return dp_nm1
    dp_n = dp_nm1
    for n in 2:degree
        p_n = ((2n - 1) * xi * p_nm1 - (n - 1) * p_nm2) / n
        dp_n = ((2n - 1) * (p_nm1 + xi * dp_nm1) - (n - 1) * dp_nm2) / n
        p_nm2 = p_nm1
        p_nm1 = p_n
        dp_nm2 = dp_nm1
        dp_nm1 = dp_n
    end
    return dp_n
end

function dg_quadrature()
    r = sqrt(3.0 / 5.0)
    return (-r, 0.0, r), (5.0 / 9.0, 8.0 / 9.0, 5.0 / 9.0)
end

function dg_quadrature(degree::Int)
    0 <= degree <= MAX_DG_DEGREE || throw(ArgumentError("DG quadrature degree must be in 0:$MAX_DG_DEGREE"))
    degree <= 2 && return dg_quadrature()
    r1 = sqrt(5.0 - 2.0 * sqrt(10.0 / 7.0)) / 3.0
    r2 = sqrt(5.0 + 2.0 * sqrt(10.0 / 7.0)) / 3.0
    w1 = (322.0 + 13.0 * sqrt(70.0)) / 900.0
    w2 = (322.0 - 13.0 * sqrt(70.0)) / 900.0
    return (-r2, -r1, 0.0, r1, r2), (w2, w1, 128.0 / 225.0, w1, w2)
end

dg_degrees_of_freedom(nx::Int, method::AbstractSpatialMethod) = degrees_of_freedom(nx, method)
