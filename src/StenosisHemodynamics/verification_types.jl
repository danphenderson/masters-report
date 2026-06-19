abstract type AbstractForcingTerm end

struct NoForcing <: AbstractForcingTerm end

Base.@kwdef struct ManufacturedForcing <: AbstractForcingTerm
    area_amplitude::Float64 = 0.02
    velocity_amplitude_cm_s::Float64 = 2.0
    period_s::Float64 = 0.02
end

forcing_name(::NoForcing) = "none"
forcing_name(::ManufacturedForcing) = "manufactured-solution"

function validate(::NoForcing)
    return NoForcing()
end

function validate(forcing::ManufacturedForcing)
    isfinite(forcing.area_amplitude) || throw(ArgumentError("manufactured area amplitude must be finite"))
    abs(forcing.area_amplitude) < 0.5 || throw(ArgumentError("manufactured area amplitude must have magnitude below 0.5"))
    isfinite(forcing.velocity_amplitude_cm_s) ||
        throw(ArgumentError("manufactured velocity amplitude must be finite"))
    forcing.period_s > 0.0 || throw(ArgumentError("manufactured period must be positive"))
    return forcing
end

Base.@kwdef struct SimulationDiagnostics
    dt_min::Float64 = NaN
    dt_max::Float64 = NaN
    cfl_min::Float64 = NaN
    cfl_max::Float64 = NaN
    lambda_minus_min::Float64 = NaN
    lambda_minus_max::Float64 = NaN
    lambda_plus_min::Float64 = NaN
    lambda_plus_max::Float64 = NaN
    subcritical_margin_min::Float64 = NaN
    mass_initial::Float64 = NaN
    mass_final::Float64 = NaN
    mass_min::Float64 = NaN
    mass_max::Float64 = NaN
    mass_defect::Float64 = NaN
    positivity_projection_count::Int = 0
    positivity_correction_total::Float64 = 0.0
end

empty_simulation_diagnostics() = SimulationDiagnostics()
