function print_usage(io::IO = stdout)
    println(
        io,
        """
        Usage:
          julia simulations/run_canic_extended_1d.jl [options]

        Options:
          --severity VALUE        Stenosis severity percentage, default 50
          --nx VALUE              Number of finite-volume cells, default 400
          --tfinal VALUE          Final time in seconds, default 1.0
          --dt VALUE              Maximum time step, default 1e-5
          --cfl VALUE             CFL limit, default 0.45
          --alpha VALUE           Coriolis coefficient, default 1.1
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
    "alpha",
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

function require_value(args::Vector{String}, i::Int, key::String)
    i < length(args) || error("missing value for --$key")
    return args[i + 1]
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
    alg_label = backend isa SciMLTimeBackend ? algorithm_name(backend.solve.algorithm) : "ssprk"
    @info "running Canic extended 1D stenosis simulation" nx=params.nx tfinal=params.tfinal dt_cap=params.dt severity=params.severity alpha=params.alpha young=params.young backend=backend_label alg=alg_label

    result = simulate(params, backend; progress_every=output.progress_every)
    write_csv(output.csv, result, params)
    output.write_svg && write_svg(output.svg, result, params)

    for line in summary_lines(result, params, output)
        println(line)
    end

    return result
end
