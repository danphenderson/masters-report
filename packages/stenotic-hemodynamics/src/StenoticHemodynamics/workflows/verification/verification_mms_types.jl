"""
    ManufacturedVerificationSpec(; base_params, nxs, dt_values, backend, output_dir, ...)

Typed workflow spec for the manufactured-solution verification study. The base
parameters must stay on the MMS forcing and initial-condition contracts; this
surface only selects grids, timesteps, backend, and output paths.
"""
Base.@kwdef struct ManufacturedVerificationSpec{B<:AbstractTimeBackend} <: AbstractStudySpec
    base_params::Params = Params(;
        severity=0.0,
        nx=40,
        tfinal=2.0e-4,
        dt=5.0e-6,
        initial_condition=ManufacturedSolutionIC(),
        forcing=ManufacturedForcing(),
        space=FVMUSCLMethod(),
        time_stepper=SSPRK3Stepper(),
    )
    nxs::Vector{Int} = [20, 40, 80]
    dt_values::Vector{Float64} = [2.0e-5, 1.0e-5, 5.0e-6]
    backend::B = NativeRK3Backend()
    output_dir::String = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification")
    summary_csv::String = ""
    summary_tex::String = ""
    overwrite::Bool = false
    progress_every::Int = 0
end

"""One MMS verification summary row for either the spatial or temporal sweep."""
Base.@kwdef struct ManufacturedVerificationRow
    study_kind::String
    nx::Int
    dx::Float64
    dt::Float64
    tfinal::Float64
    area_l1_error::Float64
    area_l2_error::Float64
    area_linf_error::Float64
    area_observed_order::Float64 = NaN
    area_l1_observed_order::Float64 = NaN
    area_l2_observed_order::Float64 = area_observed_order
    area_linf_observed_order::Float64 = NaN
    flow_l1_error::Float64
    flow_l2_error::Float64
    flow_linf_error::Float64
    flow_observed_order::Float64 = NaN
    flow_l1_observed_order::Float64 = NaN
    flow_l2_observed_order::Float64 = flow_observed_order
    flow_linf_observed_order::Float64 = NaN
    accepted_dt_min::Float64
    accepted_dt_max::Float64
    realized_cfl_max::Float64
    independent_mass_forcing_max_abs_diff::Float64
    independent_momentum_forcing_max_abs_diff::Float64
    status::String
    error_message::String
end

"""Return value from `run_manufactured_verification`."""
struct ManufacturedVerificationResult{S<:ManufacturedVerificationSpec}
    spec::S
    rows::Vector{ManufacturedVerificationRow}
    summary_csv::String
    summary_tex::String
end

workflow_kind(::ManufacturedVerificationSpec) = "manufactured_verification"

function validate(spec::ManufacturedVerificationSpec)
    validate(spec.base_params)
    assert_backend_supported(spec.base_params.space, spec.backend)
    spec.base_params.forcing isa ManufacturedForcing ||
        throw(ArgumentError("manufactured verification requires base_params.forcing=ManufacturedForcing(...)"))
    spec.base_params.initial_condition isa ManufacturedSolutionIC ||
        throw(ArgumentError("manufactured verification requires base_params.initial_condition=ManufacturedSolutionIC()"))
    length(spec.nxs) >= 2 || throw(ArgumentError("manufactured verification requires at least two spatial grids"))
    length(spec.dt_values) >= 2 || throw(ArgumentError("manufactured verification requires at least two timesteps"))
    all(nx -> nx >= 3, spec.nxs) || throw(ArgumentError("all manufactured verification grids must be at least 3"))
    all(dt -> dt > 0.0, spec.dt_values) || throw(ArgumentError("all manufactured verification timesteps must be positive"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    return spec
end

function manufactured_verification_csv_path(spec::ManufacturedVerificationSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    return joinpath(spec.output_dir, "mms_verification.csv")
end

function manufactured_verification_tex_path(spec::ManufacturedVerificationSpec)
    !isempty(spec.summary_tex) && return spec.summary_tex
    return joinpath(spec.output_dir, "mms_verification.tex")
end

function manufactured_verification_spec_from_values(
    values::Dict{String,String},
    flags::Set{String};
    output_dir::String = get(values, "output-dir", joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification")),
    overwrite::Bool = "overwrite" in flags,
    progress_every::Int = parse(Int, get(values, "progress-every", "0")),
)
    base_params = Params(;
        nx=parse(Int, get(values, "nx", "40")),
        tfinal=parse(Float64, get(values, "tfinal", "2e-3")),
        dt=parse(Float64, get(values, "dt", "5e-6")),
        severity=parse(Float64, get(values, "severity", "0")),
        initial_condition=ManufacturedSolutionIC(),
        forcing=ManufacturedForcing(),
        space=spatial_method_from_cli(values),
        time_stepper=time_stepper_from_cli(values),
        velocity_profile=velocity_profile_from_cli(values),
        rheology=rheology_from_cli(values),
        model=model_from_cli(values),
    )
    return ManufacturedVerificationSpec(;
        base_params=base_params,
        nxs=parse_int_list(get(values, "nxs", "20,40,80")),
        dt_values=parse_float_list(get(values, "dt-values", "2e-5,1e-5,5e-6")),
        output_dir=output_dir,
        summary_csv=get(values, "summary-csv", ""),
        summary_tex=get(values, "summary-tex", ""),
        overwrite=overwrite,
        progress_every=progress_every,
    )
end

default_output_paths(spec::ManufacturedVerificationSpec) = (
    summary_csv=manufactured_verification_csv_path(spec),
    summary_tex=manufactured_verification_tex_path(spec),
)
