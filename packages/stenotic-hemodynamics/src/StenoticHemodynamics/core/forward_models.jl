abstract type AbstractForwardModel end

struct CanicExtendedOneDModel <: AbstractForwardModel end

struct ClassicalParabolicOneDModel <: AbstractForwardModel end

Base.@deprecate_binding ClassicalNoSlip1DModel ClassicalParabolicOneDModel

const FORWARD_MODEL_NAMES = ("canic-extended-1d", "classical-parabolic-1d")
const DEPRECATED_FORWARD_MODEL_NAMES = ("classical-1d-no-slip",)
const ALL_FORWARD_MODEL_NAMES = (FORWARD_MODEL_NAMES..., DEPRECATED_FORWARD_MODEL_NAMES...)

forward_model_name(::CanicExtendedOneDModel) = "canic-extended-1d"
forward_model_name(::ClassicalParabolicOneDModel) = "classical-parabolic-1d"

variable_radius_terms_enabled(::CanicExtendedOneDModel) = true
variable_radius_terms_enabled(::ClassicalParabolicOneDModel) = false

wall_boundary_condition(::CanicExtendedOneDModel) = "reduced-wall-closure"
wall_boundary_condition(::ClassicalParabolicOneDModel) = "no-slip-wall"

function forward_model(name::AbstractString)
    normalized = replace(lowercase(strip(name)), "_" => "-")
    normalized == "canic-extended-1d" && return CanicExtendedOneDModel()
    normalized == "classical-parabolic-1d" && return ClassicalParabolicOneDModel()
    normalized == "classical-1d-no-slip" && return ClassicalParabolicOneDModel()
    throw(ArgumentError("unknown model '$name'; expected $(join(ALL_FORWARD_MODEL_NAMES, ", "))"))
end

function validate_model_profile(::CanicExtendedOneDModel, ::AbstractVelocityProfile)
    return nothing
end

function validate_model_profile(::ClassicalParabolicOneDModel, profile::AbstractVelocityProfile)
    profile isa ParabolicVelocityProfile ||
        throw(ArgumentError("classical-parabolic-1d requires --velocity-profile parabolic and does not accept --alpha"))
    return nothing
end

model_name(p) = forward_model_name(p.model)
variable_radius_terms_enabled(p) = variable_radius_terms_enabled(p.model)
wall_boundary_condition(p) = wall_boundary_condition(p.model)
function effective_alpha_c(p, r0z::Real)
    T = _float_input_type(r0z)
    return variable_radius_terms_enabled(p) ? alpha_c(r0z) : zero(T)
end

function effective_alpha_c_z(p, r0z::Real, r0zz::Real)
    T = _promote_float_type(r0z, r0zz)
    return variable_radius_terms_enabled(p) ? alpha_c_z(r0z, r0zz) : zero(T)
end
