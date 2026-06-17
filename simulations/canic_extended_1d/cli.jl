function print_usage(io::IO = stdout)
    println(
        io,
        """
        Usage:
          ./scripts/julia-release simulations/run_canic_extended_1d.jl [options]

        Options:
          --severity VALUE        Stenosis severity percentage, default 50
          --nx VALUE              Number of finite-volume cells, default 400
          --tfinal VALUE          Final time in seconds, default 1.0
          --dt VALUE              Maximum time step, default 1e-5
          --cfl VALUE             CFL limit, default 0.45
          --space VALUE           fv-first-order, fv-muscl, fv-lax-wendroff, or dg
          --degree VALUE          DG polynomial degree 0, 1, or 2
          --limiter VALUE         TVD limiter, default minmod
          --time-stepper VALUE    euler, ssprk2, or ssprk3
          --ic VALUE              stationary-stokes or geometry-rest, default stationary-stokes
          --ic-pressure-drop-pa VALUE Pressure drop for stationary Stokes IC in Pa
          --ic-pressure-drop-dyn-cm2 VALUE Pressure drop for stationary Stokes IC in dyn/cm^2
          --ic-mesh-nz VALUE      Stationary Stokes axial mesh segments, default 64
          --ic-mesh-nr VALUE      Stationary Stokes radial mesh rings, default 6
          --ic-mesh-ntheta VALUE  Stationary Stokes angular mesh sectors, default 32
          --ic-diagnostics PATH   Optional stationary Stokes IC diagnostics CSV
          --alpha VALUE           Coriolis coefficient, default 1.1
          --nu VALUE              Newtonian kinematic viscosity, default 0.04 cm^2/s
          --rheology VALUE        newtonian, carreau, carreau-yasuda, casson, or power-law
          --eta0 VALUE            Low-shear dynamic viscosity for Carreau variants, g/(cm*s)
          --eta-inf VALUE         High-shear dynamic viscosity for Carreau variants, g/(cm*s)
          --lambda-s VALUE        Carreau time constant in seconds
          --yasuda-a VALUE        Carreau-Yasuda transition exponent
          --flow-index VALUE      Carreau/power-law exponent n
          --yield-stress VALUE    Casson yield stress in dyn/cm^2
          --plastic-viscosity VALUE Casson plastic viscosity in g/(cm*s)
          --consistency VALUE     Power-law consistency coefficient
          --min-eta VALUE         Lower clamp for dynamic viscosity, g/(cm*s)
          --max-eta VALUE         Upper clamp for dynamic viscosity, g/(cm*s)
          --shear-floor VALUE     Minimum shear rate used by rheology closures, 1/s
          --young VALUE           Young modulus in dyn/cm^2, default 5.02e6
          --inlet-umax VALUE      Inlet Poiseuille maximum velocity, default 45 cm/s
          --backend VALUE         Time backend: native or sciml, default native
          --alg VALUE             Solver policy: auto, tsit5, rodas5p, or ssprk
          --abstol VALUE          SciML absolute tolerance, default 1e-6
          --reltol VALUE          SciML relative tolerance, default 1e-6
          --save-everystep        Save each SciML internal time step
          --maxiters VALUE        SciML maximum internal iterations, default 1000000
          --output PATH           CSV output path
          --svg PATH              SVG plot output path
          --no-svg                Skip SVG output
          --progress-every VALUE  Log every N steps, default 5000; use 0 to disable
          --help                  Show this help
        """,
    )
end

const VALUE_OPTIONS = Set([
    "severity",
    "nx",
    "tfinal",
    "dt",
    "cfl",
    "space",
    "degree",
    "limiter",
    "time-stepper",
    "ic",
    "ic-pressure-drop-pa",
    "ic-pressure-drop-dyn-cm2",
    "ic-mesh-nz",
    "ic-mesh-nr",
    "ic-mesh-ntheta",
    "ic-diagnostics",
    "alpha",
    "nu",
    "rheology",
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
    "young",
    "inlet-umax",
    "backend",
    "alg",
    "abstol",
    "reltol",
    "maxiters",
    "output",
    "svg",
    "progress-every",
])

const FLAG_OPTIONS = Set([
    "help",
    "no-svg",
    "save-everystep",
])

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

function require_value(args::Vector{String}, i::Int, key::String)
    i < length(args) || error("missing value for --$key")
    return args[i + 1]
end

function parse_float_value(values::Dict{String,String}, key::String, default::Float64)
    return parse(Float64, get(values, key, string(default)))
end

function limiter_from_cli(values::Dict{String,String})
    name = lowercase(strip(get(values, "limiter", "minmod")))
    name == "minmod" && return MinmodLimiter()
    throw(ArgumentError("unknown limiter '$name'; expected minmod"))
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
    elseif name in ("fv-lax-wendroff", "lax-wendroff", "laxwendroff")
        degree_was_set && throw(ArgumentError("--degree is only valid with --space dg"))
        return FVLaxWendroffMethod(limiter)
    elseif name == "dg"
        return DGMethod(degree)
    end

    throw(ArgumentError("unknown spatial method '$name'; expected fv-first-order, fv-muscl, fv-lax-wendroff, or dg"))
end

function time_stepper_from_cli(values::Dict{String,String})
    name = replace(lowercase(strip(get(values, "time-stepper", "ssprk3"))), "_" => "-")
    name in ("euler", "forward-euler", "forwardeuler") && return ForwardEulerStepper()
    name in ("ssprk2", "rk2") && return SSPRK2Stepper()
    name in ("ssprk3", "rk3") && return SSPRK3Stepper()
    throw(ArgumentError("unknown native time stepper '$name'; expected euler, ssprk2, or ssprk3"))
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

function parse_args(args::Vector{String})
    values = Dict{String,String}()
    flags = Set{String}()
    i = 1

    while i <= length(args)
        arg = args[i]
        if arg == "--help" || arg == "-h"
            push!(flags, "help")
            i += 1
        elseif startswith(arg, "--")
            raw_key = arg[3:end]
            if occursin("=", raw_key)
                key, value = split(raw_key, "=", limit=2)
                if key in FLAG_OPTIONS
                    error("--$key does not accept a value")
                elseif key in VALUE_OPTIONS
                    values[key] = value
                    i += 1
                else
                    error("unknown option --$key")
                end
            else
                key = raw_key
                if key in FLAG_OPTIONS
                    push!(flags, key)
                    i += 1
                elseif key in VALUE_OPTIONS
                    values[key] = require_value(args, i, key)
                    i += 2
                else
                    error("unknown option --$key")
                end
            end
        else
            error("unexpected argument: $arg")
        end
    end

    if "help" in flags
        return nothing
    end

    severity = parse(Float64, get(values, "severity", "50"))
    params = Params(
        nx=parse(Int, get(values, "nx", "400")),
        tfinal=parse(Float64, get(values, "tfinal", "1.0")),
        dt=parse(Float64, get(values, "dt", "1e-5")),
        cfl=parse(Float64, get(values, "cfl", "0.45")),
        severity=severity,
        nu=parse(Float64, get(values, "nu", "0.04")),
        rheology=rheology_from_cli(values),
        space=spatial_method_from_cli(values),
        time_stepper=time_stepper_from_cli(values),
        initial_condition=initial_condition_from_cli(values),
        young=parse(Float64, get(values, "young", "5.02e6")),
        alpha=parse(Float64, get(values, "alpha", "1.1")),
        inlet_umax=parse(Float64, get(values, "inlet-umax", "45.0")),
    )
    validate(params)

    solve = SolveSpec(
        algorithm=algorithm_policy(get(values, "alg", "auto")),
        abstol=parse(Float64, get(values, "abstol", "1e-6")),
        reltol=parse(Float64, get(values, "reltol", "1e-6")),
        save_everystep=("save-everystep" in flags),
        maxiters=parse(Int, get(values, "maxiters", "1000000")),
    )
    validate(solve)

    backend = backend_from_cli(
        get(values, "backend", "native"),
        solve;
        algorithm_was_set=haskey(values, "alg"),
        solve_options_were_set=any(k -> haskey(values, k) || k in flags, SCIML_SOLVE_OPTIONS),
    )

    default_stub = default_output_stub(params)
    output = OutputSpec(
        csv=get(values, "output", default_stub * ".csv"),
        svg=get(values, "svg", default_stub * ".svg"),
        write_svg=!("no-svg" in flags),
        progress_every=parse(Int, get(values, "progress-every", "5000")),
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

function run_cli(args::Vector{String} = ARGS)
    parsed = parse_args(args)
    if parsed === nothing
        print_usage()
        return nothing
    end

    params, output, backend = parsed
    backend_label = backend isa NativeRK3Backend ? "native" : "sciml"
    alg_label = backend isa SciMLTimeBackend ? algorithm_name(backend.solve.algorithm) : time_stepper_name(params.time_stepper)
    @info "running Canic extended 1D stenosis simulation" nx=params.nx tfinal=params.tfinal dt_cap=params.dt severity=params.severity alpha=params.alpha young=params.young space=spatial_method_name(params.space) time_stepper=time_stepper_name(params.time_stepper) rheology=rheology_name(params.rheology) initial_condition=initial_condition_name(params.initial_condition) backend=backend_label alg=alg_label

    result = simulate(params, backend; progress_every=output.progress_every)
    write_csv(output.csv, result, params)
    output.write_svg && write_svg(output.svg, result, params)

    for line in summary_lines(result, params, output)
        println(line)
    end

    return result
end
