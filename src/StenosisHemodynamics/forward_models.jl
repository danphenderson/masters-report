abstract type AbstractForwardModel end

struct CanicExtendedOneDModel <: AbstractForwardModel end

struct ClassicalNoSlip1DModel <: AbstractForwardModel end

const FORWARD_MODEL_NAMES = ("canic-extended-1d", "classical-1d-no-slip")

forward_model_name(::CanicExtendedOneDModel) = "canic-extended-1d"
forward_model_name(::ClassicalNoSlip1DModel) = "classical-1d-no-slip"

variable_radius_terms_enabled(::CanicExtendedOneDModel) = true
variable_radius_terms_enabled(::ClassicalNoSlip1DModel) = false

wall_boundary_condition(::CanicExtendedOneDModel) = "reduced-wall-closure"
wall_boundary_condition(::ClassicalNoSlip1DModel) = "no-slip-wall"

function forward_model(name::AbstractString)
    normalized = replace(lowercase(strip(name)), "_" => "-")
    normalized == "canic-extended-1d" && return CanicExtendedOneDModel()
    normalized == "classical-1d-no-slip" && return ClassicalNoSlip1DModel()
    throw(ArgumentError("unknown model '$name'; expected $(join(FORWARD_MODEL_NAMES, ", "))"))
end

function validate_model_profile(::CanicExtendedOneDModel, ::AbstractVelocityProfile)
    return nothing
end

function validate_model_profile(::ClassicalNoSlip1DModel, profile::AbstractVelocityProfile)
    profile isa ParabolicVelocityProfile ||
        throw(ArgumentError("classical-1d-no-slip requires --velocity-profile parabolic and does not accept --alpha"))
    return nothing
end

model_name(p) = forward_model_name(p.model)
variable_radius_terms_enabled(p) = variable_radius_terms_enabled(p.model)
wall_boundary_condition(p) = wall_boundary_condition(p.model)
effective_alpha_c(p, r0z::Float64) = variable_radius_terms_enabled(p) ? alpha_c(r0z) : 0.0
effective_alpha_c_z(p, r0z::Float64, r0zz::Float64) = variable_radius_terms_enabled(p) ? alpha_c_z(r0z, r0zz) : 0.0
