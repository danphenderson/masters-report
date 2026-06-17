const AREA_FLOOR = 1.0e-12
const AREA_LIMITER_FLOOR = 1.0e-10

"""
    Params(; kwargs...)

Physical case and finite-volume grid parameters for one Canic extended 1D
stenosis run. Units follow the paper and upstream MATLAB code: cm, g, s, dyn.

Solver backend options belong in `SolveSpec`; output paths belong in
`OutputSpec`.
"""
Base.@kwdef struct Params
    nx::Int = 400
    length_cm::Float64 = 6.0
    tfinal::Float64 = 1.0
    dt::Float64 = 1.0e-5
    cfl::Float64 = 0.45
    severity::Float64 = 50.0
    rmax::Float64 = 0.18
    rho::Float64 = 1.055
    nu::Float64 = 0.04
    young::Float64 = 5.02e6
    wall_h::Float64 = 0.06
    sigma::Float64 = 0.5
    alpha::Float64 = 1.1
    inlet_umax::Float64 = 45.0
end

"""
    OutputSpec(; csv, svg, write_svg, progress_every)

CLI output and progress-log settings for a single run. This intentionally stays
separate from `Params` and `SolveSpec`.
"""
Base.@kwdef struct OutputSpec
    csv::String = ""
    svg::String = ""
    write_svg::Bool = true
    progress_every::Int = 5000
end

"""
    SimulationResult

Final state returned by all time backends. `area` and `flow` are sampled at
cell centers `z`, and diagnostics such as `velocity(result)` and
`pressure(result, params)` are derived from this structure.
"""
struct SimulationResult
    z::Vector{Float64}
    area::Vector{Float64}
    flow::Vector{Float64}
    completed_time::Float64
    steps::Int
end

velocity(result::SimulationResult) = result.flow ./ result.area

function default_output_stub(p::Params)
    severity_label = round(Int, p.severity)
    return "simulations/output/canic_extended_1d_severity$(severity_label)"
end

function validate(p::Params)
    p.nx >= 3 || throw(ArgumentError("nx must be at least 3"))
    p.length_cm > 0.0 || throw(ArgumentError("length_cm must be positive"))
    p.tfinal >= 0.0 || throw(ArgumentError("tfinal must be nonnegative"))
    p.dt > 0.0 || throw(ArgumentError("dt must be positive"))
    p.cfl > 0.0 || throw(ArgumentError("cfl must be positive"))
    0.0 <= p.severity < 100.0 || throw(ArgumentError("severity must be in [0, 100)"))
    p.rmax > 0.0 || throw(ArgumentError("rmax must be positive"))
    p.rho > 0.0 || throw(ArgumentError("rho must be positive"))
    p.nu >= 0.0 || throw(ArgumentError("nu must be nonnegative"))
    p.young > 0.0 || throw(ArgumentError("young must be positive"))
    p.wall_h > 0.0 || throw(ArgumentError("wall_h must be positive"))
    abs(p.sigma) < 1.0 || throw(ArgumentError("abs(sigma) must be less than 1"))
    p.alpha > 1.0 || throw(ArgumentError("alpha must be greater than 1"))
    p.inlet_umax >= 0.0 || throw(ArgumentError("inlet_umax must be nonnegative"))
    return p
end
