const SCIML_SOLVE_OPTIONS = Set([
    "abstol",
    "reltol",
    "maxiters",
    "save-everystep",
])

const RHEOLOGY_PARAMETER_OPTIONS = Set([
    "eta0",
    "eta-inf",
    "lambda-s",
    "yasuda-a",
    "flow-index",
    "yield-stress",
    "plastic-viscosity",
    "consistency",
    "min-eta",
    "max-eta",
    "shear-floor",
])

function parse_float_value(values::Dict{String,String}, key::String, default::Float64)
    return parse(Float64, get(values, key, string(default)))
end

function parse_float_list(raw::AbstractString)
    values = [parse(Float64, strip(item)) for item in split(raw, ",") if !isempty(strip(item))]
    isempty(values) && throw(ArgumentError("expected at least one numeric value"))
    return values
end

function parse_int_list(raw::AbstractString)
    values = [parse(Int, strip(item)) for item in split(raw, ",") if !isempty(strip(item))]
    isempty(values) && throw(ArgumentError("expected at least one integer value"))
    return values
end

function parse_mesh_list(raw::AbstractString)
    meshes = NTuple{3,Int}[]
    for item in split(raw, ",")
        token = strip(item)
        isempty(token) && continue
        parts = split(replace(token, "X" => "x"), "x")
        length(parts) == 3 || throw(ArgumentError("mesh '$token' must have the form nzxnrxntheta"))
        push!(meshes, (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3])))
    end
    isempty(meshes) && throw(ArgumentError("expected at least one mesh triple"))
    return meshes
end

function limiter_from_cli(values::Dict{String,String})
    name = replace(lowercase(strip(get(values, "limiter", "minmod"))), "_" => "-")
    name == "minmod" && return MinmodLimiter()
    name in ("van-leer", "vanleer") && return VanLeerLimiter()
    throw(ArgumentError("unknown limiter '$name'; expected minmod or van-leer"))
end

function spatial_method_from_cli(values::Dict{String,String})
    name = replace(lowercase(strip(get(values, "space", "fv-muscl"))), "_" => "-")
    limiter = limiter_from_cli(values)
    degree_was_set = haskey(values, "degree")
    degree = parse(Int, get(values, "degree", "1"))

    if name in ("fv-first-order", "first-order", "firstorder")
        degree_was_set && throw(ArgumentError("--degree is only valid with --space dg"))
        return FVFirstOrderMethod()
    elseif name in ("fv-muscl", "muscl")
        degree_was_set && throw(ArgumentError("--degree is only valid with --space dg"))
        return FVMUSCLMethod(limiter)
    elseif name in ("fv-weno3", "weno3")
        degree_was_set && throw(ArgumentError("--degree is only valid with --space dg"))
        return FVWENO3Method()
    elseif name in ("fv-lax-wendroff", "lax-wendroff", "laxwendroff")
        degree_was_set && throw(ArgumentError("--degree is only valid with --space dg"))
        return FVLaxWendroffMethod(limiter)
    elseif name == "dg"
        return DGMethod(degree)
    end

    throw(ArgumentError("unknown spatial method '$name'; expected fv-first-order, fv-muscl, fv-weno3, fv-lax-wendroff, or dg"))
end

function time_stepper_from_cli(values::Dict{String,String})
    name = replace(lowercase(strip(get(values, "time-stepper", "ssprk3"))), "_" => "-")
    name in ("euler", "forward-euler", "forwardeuler") && return ForwardEulerStepper()
    name in ("ssprk2", "rk2") && return SSPRK2Stepper()
    name in ("ssprk3", "rk3") && return SSPRK3Stepper()
    name in ("ssprk54", "ssprk5-4", "ssprk-5-4", "rk54") && return SSPRK54Stepper()
    throw(ArgumentError("unknown native time stepper '$name'; expected euler, ssprk2, ssprk3, or ssprk54"))
end

function initial_condition_from_cli(values::Dict{String,String})
    name = replace(lowercase(strip(get(values, "ic", "stationary-stokes"))), "_" => "-")
    pressure_pa_set = haskey(values, "ic-pressure-drop-pa")
    pressure_dyn_set = haskey(values, "ic-pressure-drop-dyn-cm2")

    if name in ("geometry-rest", "rest")
        if pressure_pa_set || pressure_dyn_set
            throw(ArgumentError("--ic-pressure-drop-pa and --ic-pressure-drop-dyn-cm2 are only valid with --ic stationary-stokes"))
        end
        for key in ("ic-mesh-nz", "ic-mesh-nr", "ic-mesh-ntheta", "ic-diagnostics")
            haskey(values, key) && throw(ArgumentError("--$key is only valid with --ic stationary-stokes"))
        end
        return GeometryRestIC()
    elseif name in ("stationary-stokes", "stokes")
        pressure_pa_set == pressure_dyn_set &&
            throw(ArgumentError("stationary-stokes IC requires exactly one of --ic-pressure-drop-pa or --ic-pressure-drop-dyn-cm2"))
        return StationaryStokesIC(
            pressure_drop_pa=pressure_pa_set ? parse(Float64, values["ic-pressure-drop-pa"]) : nothing,
            pressure_drop_dyn_cm2=pressure_dyn_set ? parse(Float64, values["ic-pressure-drop-dyn-cm2"]) : nothing,
            mesh_nz=parse(Int, get(values, "ic-mesh-nz", "64")),
            mesh_nr=parse(Int, get(values, "ic-mesh-nr", "6")),
            mesh_ntheta=parse(Int, get(values, "ic-mesh-ntheta", "32")),
            diagnostics_path=get(values, "ic-diagnostics", ""),
        )
    end

    throw(ArgumentError("unknown initial condition '$name'; expected stationary-stokes or geometry-rest"))
end

function velocity_profile_from_cli(values::Dict{String,String})
    profile_was_set = haskey(values, "velocity-profile")
    exponent_was_set = haskey(values, "profile-exponent")
    shear_was_set = haskey(values, "profile-shear-factor")
    alpha_was_set = haskey(values, "alpha")

    if alpha_was_set
        (profile_was_set || exponent_was_set || shear_was_set) &&
            throw(ArgumentError("--alpha cannot be combined with --velocity-profile, --profile-exponent, or --profile-shear-factor"))
        return PowerVelocityProfile(alpha=parse(Float64, values["alpha"]))
    end

    name = replace(lowercase(strip(get(values, "velocity-profile", "parabolic"))), "_" => "-")
    if name in ("parabolic", "poiseuille")
        (exponent_was_set || shear_was_set) &&
            throw(ArgumentError("--profile-exponent and --profile-shear-factor are not valid with --velocity-profile parabolic"))
        return ParabolicVelocityProfile()
    elseif name in ("flat", "plug")
        exponent_was_set &&
            throw(ArgumentError("--profile-exponent is only valid with --velocity-profile power"))
        return FlatVelocityProfile(shear_rate_factor=parse_float_value(values, "profile-shear-factor", 4.0))
    elseif name == "power"
        shear_was_set &&
            throw(ArgumentError("--profile-shear-factor is only valid with --velocity-profile flat"))
        exponent_was_set || throw(ArgumentError("--velocity-profile power requires --profile-exponent"))
        return PowerVelocityProfile(exponent=parse(Float64, values["profile-exponent"]))
    end

    throw(ArgumentError("unknown velocity profile '$name'; expected flat, parabolic, or power"))
end

function model_from_cli(values::Dict{String,String})
    return forward_model(get(values, "model", "canic-extended-1d"))
end

function assert_no_unused_rheology_options(values::Dict{String,String}, allowed::Set{String}, model::String)
    unused = sort([key for key in RHEOLOGY_PARAMETER_OPTIONS if haskey(values, key) && !(key in allowed)])
    isempty(unused) ||
        throw(ArgumentError("rheology '$model' does not use option(s): $(join(map(key -> "--" * key, unused), ", "))"))
    return nothing
end

function rheology_from_cli(values::Dict{String,String})
    raw_model = lowercase(strip(get(values, "rheology", "newtonian")))
    model = replace(raw_model, "_" => "-")

    if model in ("newtonian", "constant")
        assert_no_unused_rheology_options(values, Set{String}(), model)
        return NewtonianRheology()
    elseif model == "carreau"
        allowed = Set(["eta0", "eta-inf", "lambda-s", "flow-index", "shear-floor", "min-eta", "max-eta"])
        assert_no_unused_rheology_options(values, allowed, model)
        return CarreauRheology(
            eta0=parse_float_value(values, "eta0", 0.56),
            eta_inf=parse_float_value(values, "eta-inf", 0.0345),
            lambda_s=parse_float_value(values, "lambda-s", 3.313),
            n=parse_float_value(values, "flow-index", 0.3568),
            shear_rate_floor=parse_float_value(values, "shear-floor", 1.0e-8),
            min_eta=parse_float_value(values, "min-eta", 0.0),
            max_eta=parse_float_value(values, "max-eta", Inf),
        )
    elseif model == "carreau-yasuda"
        allowed = Set(["eta0", "eta-inf", "lambda-s", "yasuda-a", "flow-index", "shear-floor", "min-eta", "max-eta"])
        assert_no_unused_rheology_options(values, allowed, model)
        return CarreauYasudaRheology(
            eta0=parse_float_value(values, "eta0", 0.56),
            eta_inf=parse_float_value(values, "eta-inf", 0.0345),
            lambda_s=parse_float_value(values, "lambda-s", 3.313),
            a=parse_float_value(values, "yasuda-a", 2.0),
            n=parse_float_value(values, "flow-index", 0.3568),
            shear_rate_floor=parse_float_value(values, "shear-floor", 1.0e-8),
            min_eta=parse_float_value(values, "min-eta", 0.0),
            max_eta=parse_float_value(values, "max-eta", Inf),
        )
    elseif model == "casson"
        allowed = Set(["yield-stress", "plastic-viscosity", "shear-floor", "min-eta", "max-eta"])
        assert_no_unused_rheology_options(values, allowed, model)
        return CassonRheology(
            yield_stress=parse_float_value(values, "yield-stress", 0.04),
            plastic_viscosity=parse_float_value(values, "plastic-viscosity", 0.035),
            shear_rate_floor=parse_float_value(values, "shear-floor", 1.0e-8),
            min_eta=parse_float_value(values, "min-eta", 0.0),
            max_eta=parse_float_value(values, "max-eta", Inf),
        )
    elseif model in ("power-law", "powerlaw")
        allowed = Set(["consistency", "flow-index", "shear-floor", "min-eta", "max-eta"])
        assert_no_unused_rheology_options(values, allowed, model)
        return PowerLawRheology(
            consistency=parse_float_value(values, "consistency", 0.035),
            n=parse_float_value(values, "flow-index", 1.0),
            shear_rate_floor=parse_float_value(values, "shear-floor", 1.0e-8),
            min_eta=parse_float_value(values, "min-eta", 0.0),
            max_eta=parse_float_value(values, "max-eta", Inf),
        )
    end

    throw(ArgumentError("unknown rheology '$raw_model'; expected newtonian, carreau, carreau-yasuda, casson, or power-law"))
end

function simulate_specs_from_values(values::Dict{String,String}, flags::Set{String}; default_ic::String = "stationary-stokes")
    param_values = copy(values)
    haskey(param_values, "ic") || (param_values["ic"] = default_ic)
    severity = parse(Float64, get(param_values, "severity", "50"))
    params = Params(
        nx=parse(Int, get(param_values, "nx", "400")),
        tfinal=parse(Float64, get(param_values, "tfinal", "1.0")),
        dt=parse(Float64, get(param_values, "dt", "1e-5")),
        cfl=parse(Float64, get(param_values, "cfl", "0.45")),
        severity=severity,
        nu=parse(Float64, get(param_values, "nu", "0.04")),
        rheology=rheology_from_cli(param_values),
        space=spatial_method_from_cli(param_values),
        time_stepper=time_stepper_from_cli(param_values),
        initial_condition=initial_condition_from_cli(param_values),
        velocity_profile=velocity_profile_from_cli(param_values),
        model=model_from_cli(param_values),
        young=parse(Float64, get(param_values, "young", "5.02e6")),
        inlet_umax=parse(Float64, get(param_values, "inlet-umax", "45.0")),
    )
    validate(params)

    solve = SolveSpec(
        algorithm=algorithm_policy(get(param_values, "alg", "auto")),
        abstol=parse(Float64, get(param_values, "abstol", "1e-6")),
        reltol=parse(Float64, get(param_values, "reltol", "1e-6")),
        save_everystep=("save-everystep" in flags),
        maxiters=parse(Int, get(param_values, "maxiters", "1000000")),
    )
    validate(solve)

    backend = backend_from_cli(
        get(param_values, "backend", "native"),
        solve;
        algorithm_was_set=haskey(param_values, "alg"),
        solve_options_were_set=any(k -> haskey(param_values, k) || k in flags, SCIML_SOLVE_OPTIONS),
    )

    default_stub = default_output_stub(params)
    output = OutputSpec(
        csv=get(param_values, "output", default_stub * ".csv"),
        svg=get(param_values, "svg", default_stub * ".svg"),
        write_svg=!("no-svg" in flags),
        progress_every=parse(Int, get(param_values, "progress-every", "5000")),
        overwrite=("overwrite" in flags),
    )

    output.progress_every >= 0 || throw(ArgumentError("progress-every must be nonnegative"))
    return params, output, backend
end

function backend_from_cli(
    name::AbstractString,
    solve::SolveSpec;
    algorithm_was_set::Bool,
    solve_options_were_set::Bool,
)
    backend_name = lowercase(strip(name))

    if backend_name == "native"
        if algorithm_was_set && !(solve.algorithm isa NativeSSPRKPolicy)
            throw(ArgumentError("algorithm '$(algorithm_name(solve.algorithm))' requires --backend sciml"))
        end
        if solve_options_were_set
            throw(ArgumentError("--abstol, --reltol, --save-everystep, and --maxiters require --backend sciml"))
        end

        return NativeRK3Backend()
    elseif backend_name == "sciml"
        if solve.algorithm isa NativeSSPRKPolicy
            throw(ArgumentError("algorithm '$(algorithm_name(solve.algorithm))' is only available with --backend native"))
        end

        return SciMLTimeBackend(solve=solve)
    end

    throw(ArgumentError("unknown backend '$name'; expected native or sciml"))
end

function params_backend_progress(values::Dict{String,String}, flags::Set{String}; default_ic::String = "geometry-rest")
    params, output, backend = simulate_specs_from_values(values, flags; default_ic=default_ic)
    return params, backend, output.progress_every
end
