function print_usage(io::IO = stdout)
    println(
        io,
        """
        Usage:
          ./scripts/stenosis-hemodynamics <command> [options]

        Commands:
          simulate      Run one 1D forward simulation
          openbf-run    Run a strict OpenBF-style input.yml adapter
          study         Run severity, grid, or refinement studies
          stokes        Run stationary-Stokes workflows
          verify        Run MMS and rest-state verification workflows
          compare-3d    Compare available resolved-3D cases against 1D runs
          operator-validation Validate cross-section quadrature on synthetic cuts
          benchmark     Run package benchmark profiles
          export-assets Export stenosis geometry/report CSV assets

        Run './scripts/stenosis-hemodynamics <command> --help' for command help.
        """,
    )
end

function print_simulate_usage(io::IO = stdout)
    println(
        io,
        """
        Usage:
          ./scripts/stenosis-hemodynamics simulate [options]

        Options:
          --model VALUE           canic-extended-1d or classical-1d-no-slip
          --severity VALUE        Stenosis severity percentage, default 50
          --nx VALUE              Number of finite-volume cells, default 400
          --tfinal VALUE          Final time in seconds, default 1.0
          --dt VALUE              Maximum time step, default 1e-5
          --cfl VALUE             CFL limit, default 0.45
          --space VALUE           fv-first-order, fv-muscl, fv-weno3, fv-lax-wendroff, or dg
          --degree VALUE          DG polynomial degree 0, 1, or 2
          --limiter VALUE         TVD limiter: minmod or van-leer, default minmod
          --time-stepper VALUE    euler, ssprk2, ssprk3, or ssprk54
          --ic VALUE              stationary-stokes or geometry-rest, default stationary-stokes
          --ic-pressure-drop-pa VALUE Pressure drop for stationary Stokes IC in Pa
          --ic-pressure-drop-dyn-cm2 VALUE Pressure drop for stationary Stokes IC in dyn/cm^2
          --ic-mesh-nz VALUE      Stationary Stokes axial mesh segments, default 64
          --ic-mesh-nr VALUE      Stationary Stokes radial mesh rings, default 6
          --ic-mesh-ntheta VALUE  Stationary Stokes angular mesh sectors, default 32
          --ic-diagnostics PATH   Optional stationary Stokes IC diagnostics CSV
          --velocity-profile VALUE flat, parabolic, or power; default parabolic
          --profile-exponent VALUE Power-profile exponent gamma
          --profile-shear-factor VALUE Flat-profile shear factor, default 4
          --alpha VALUE           Legacy alias for power-profile alpha
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
    "model",
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
    "velocity-profile",
    "profile-exponent",
    "profile-shear-factor",
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

function parse_cli_options(args::Vector{String}, value_options::Set{String}, flag_options::Set{String})
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
                if key in flag_options
                    error("--$key does not accept a value")
                elseif key in value_options
                    values[key] = value
                    i += 1
                else
                    error("unknown option --$key")
                end
            else
                key = raw_key
                if key in flag_options
                    push!(flags, key)
                    i += 1
                elseif key in value_options
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

    return values, flags
end

function parse_args(args::Vector{String})
    return parse_simulate_args(args)
end

function parse_simulate_args(args::Vector{String})
    values, flags = parse_cli_options(args, VALUE_OPTIONS, FLAG_OPTIONS)

    if "help" in flags
        return nothing
    end

    return simulate_specs_from_values(values, flags)
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

const BENCHMARK_VALUE_OPTIONS = Set(["profile", "output-dir", "progress-every"])
const BENCHMARK_FLAG_OPTIONS = Set(["help", "overwrite", "include-resolved3d", "publish-report-assets"])

const OPENBF_VALUE_OPTIONS = Set(["config"])
const OPENBF_FLAG_OPTIONS = Set(["help", "verbose", "out-files", "save-stats"])

const STUDY_VALUE_OPTIONS = union(VALUE_OPTIONS, Set([
    "severities",
    "nxs",
    "degrees",
    "meshes",
    "output-dir",
    "summary-csv",
    "parallel-workers",
    "pressure-drop-pa",
]))
const STUDY_FLAG_OPTIONS = union(FLAG_OPTIONS, Set(["overwrite"]))

const VERIFY_VALUE_OPTIONS = union(VALUE_OPTIONS, Set([
    "degrees",
    "h-degree",
    "h-nxs",
    "nxs",
    "p-nx",
    "dt-values",
    "elapsed-times",
    "severities",
    "output-dir",
    "summary-csv",
    "summary-tex",
]))
const VERIFY_FLAG_OPTIONS = union(FLAG_OPTIONS, Set(["overwrite"]))

const COMPARISON_VALUE_OPTIONS = union(VALUE_OPTIONS, Set([
    "data-root",
    "output-dir",
    "target-time",
    "time-atol",
    "nxs",
    "reuse-grid-summary",
    "section-count",
    "radial-bins",
    "radial-bin-counts",
    "radial-radius-modes",
    "profile-slices",
    "node-slab-half-widths",
    "grid-summary-csv",
    "grid-summary-tex",
    "report-assets-dir",
]))
const COMPARISON_FLAG_OPTIONS = union(FLAG_OPTIONS, Set(["overwrite", "publish-report-assets"]))

const OPERATOR_VALIDATION_VALUE_OPTIONS = Set([
    "output-dir",
    "summary-csv",
    "summary-tex",
    "sample-z",
    "plane-center",
    "plane-shifts",
    "constant-value",
    "affine-coefficients",
    "tolerance",
])
const OPERATOR_VALIDATION_FLAG_OPTIONS = Set(["help", "overwrite"])

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

function params_backend_progress(values::Dict{String,String}, flags::Set{String}; default_ic::String = "geometry-rest")
    params, output, backend = simulate_specs_from_values(values, flags; default_ic=default_ic)
    return params, backend, output.progress_every
end

function run_single_simulation(parsed)
    if parsed === nothing
        print_simulate_usage()
        return nothing
    end

    params, output, backend = parsed
    backend_label = backend_name(backend)
    alg_label = run_algorithm_name(params, backend)
    @info "running stenosis hemodynamics simulation" model=model_name(params) variable_radius_terms=variable_radius_terms_enabled(params) nx=params.nx tfinal=params.tfinal dt_cap=params.dt severity=params.severity velocity_profile=profile_name(params.velocity_profile) alpha=params.alpha shear_rate_factor=shear_rate_factor(params.velocity_profile) young=params.young space=spatial_method_name(params.space) time_stepper=time_stepper_name(params.time_stepper) rheology=rheology_name(params.rheology) initial_condition=initial_condition_name(params.initial_condition) backend=backend_label alg=alg_label

    result = simulate(params, backend; progress_every=output.progress_every)
    write_csv(output.csv, result, params)
    output.write_svg && write_svg(output.svg, result, params)

    for line in summary_lines(result, params, output)
        println(line)
    end

    return result
end

function run_simulate_cli(args::Vector{String})
    parsed = parse_simulate_args(args)
    return run_single_simulation(parsed)
end

function print_openbf_usage()
    println("""
    Usage:
      ./scripts/stenosis-hemodynamics openbf-run --config PATH [--verbose] [--save-stats]
    """)
end

function run_openbf_cli(args::Vector{String})
    values, flags = parse_cli_options(args, OPENBF_VALUE_OPTIONS, OPENBF_FLAG_OPTIONS)
    if "help" in flags
        print_openbf_usage()
        return nothing
    end
    haskey(values, "config") || throw(ArgumentError("openbf-run requires --config PATH"))
    result = run_simulation(
        values["config"];
        verbose=("verbose" in flags),
        out_files=("out-files" in flags),
        save_stats=("save-stats" in flags),
    )
    println("openbf_output_completed_time_s,$(result.completed_time)")
    println("openbf_output_steps,$(result.steps)")
    return result
end

function print_benchmark_usage()
    println("""
    Usage:
      ./scripts/stenosis-hemodynamics benchmark --profile smoke|overnight --output-dir PATH [--overwrite]
    """)
end

function benchmark_spec_from_cli(args::Vector{String})
    values, flags = parse_cli_options(args, BENCHMARK_VALUE_OPTIONS, BENCHMARK_FLAG_OPTIONS)
    if "help" in flags
        return nothing
    end
    return PackageBenchmarkSpec(;
        profile=get(values, "profile", "smoke"),
        output_dir=get(values, "output-dir", joinpath("simulations", "output", "package_benchmark", "smoke")),
        overwrite=("overwrite" in flags),
        include_resolved3d=("include-resolved3d" in flags),
        publish_report_assets=("publish-report-assets" in flags),
        progress_every=parse(Int, get(values, "progress-every", "0")),
    )
end

function run_benchmark_cli(args::Vector{String})
    spec = benchmark_spec_from_cli(args)
    if spec === nothing
        print_benchmark_usage()
        return nothing
    end
    result = run_package_benchmark(spec)
    println("benchmark_manifest,$(result.manifest_path)")
    for path in result.csv_paths
        println("benchmark_csv,$path")
    end
    spec.publish_report_assets && println("benchmark_report_assets,$PACKAGE_BENCHMARK_DATA_DIR")
    return result
end

function print_study_usage()
    println("""
    Usage:
      ./scripts/stenosis-hemodynamics study severity --severities 23,50 [options]
      ./scripts/stenosis-hemodynamics study grid --nxs 40,80 [options]
      ./scripts/stenosis-hemodynamics study refinement --nxs 50,100,200,400 [options]
    """)
end

function run_study_cli(args::Vector{String})
    isempty(args) && (print_study_usage(); return nothing)
    subcommand = args[1]
    rest = args[2:end]
    subcommand in ("--help", "-h", "help") && (print_study_usage(); return nothing)
    values, flags = parse_cli_options(rest, STUDY_VALUE_OPTIONS, STUDY_FLAG_OPTIONS)
    if "help" in flags
        print_study_usage()
        return nothing
    end
    params, backend, progress_every = params_backend_progress(values, flags)
    overwrite = "overwrite" in flags
    parallel_workers = parse(Int, get(values, "parallel-workers", string(default_case_workers())))

    if subcommand == "severity"
        severities = parse_float_list(get(values, "severities", "23,50"))
        result = run_study(SeveritySweepSpec(;
            base_params=params,
            severities=severities,
            backend=backend,
            summary_csv=get(values, "summary-csv", ""),
            overwrite=overwrite,
            progress_every=progress_every,
            parallel_workers=parallel_workers,
        ))
        println("study_summary_csv,$(result.summary_csv)")
        return result
    elseif subcommand == "grid"
        nxs = parse_int_list(get(values, "nxs", "40,80"))
        result = run_study(GridConvergenceStudySpec(;
            base_params=params,
            nxs=nxs,
            backend=backend,
            summary_csv=get(values, "summary-csv", ""),
            overwrite=overwrite,
            progress_every=progress_every,
            parallel_workers=parallel_workers,
        ))
        println("study_summary_csv,$(result.summary_csv)")
        return result
    elseif subcommand == "refinement"
        nxs = parse_int_list(get(values, "nxs", "50,100,200,400"))
        degrees = parse_int_list(get(values, "degrees", "0,1,2"))
        result = run_refinement_study(RefinementStudySpec(;
            base_params=params,
            nxs=nxs,
            degrees=degrees,
            backend=backend,
            output_dir=get(values, "output-dir", ""),
            overwrite=overwrite,
            progress_every=progress_every,
            parallel_workers=parallel_workers,
        ))
        for path in result.csv_paths
            println("refinement_csv,$path")
        end
        for path in result.tex_paths
            println("refinement_tex,$path")
        end
        return result
    end

    throw(ArgumentError("unknown study subcommand '$subcommand'; expected severity, grid, or refinement"))
end

function print_stokes_usage()
    println("""
    Usage:
      ./scripts/stenosis-hemodynamics stokes refine [--severities 0,23,40,50] [--meshes 8x2x8,16x4x16] [options]
    """)
end

function run_stokes_cli(args::Vector{String})
    isempty(args) && (print_stokes_usage(); return nothing)
    subcommand = args[1]
    rest = args[2:end]
    subcommand in ("--help", "-h", "help") && (print_stokes_usage(); return nothing)
    subcommand == "refine" || throw(ArgumentError("unknown stokes subcommand '$subcommand'; expected refine"))
    values, flags = parse_cli_options(rest, STUDY_VALUE_OPTIONS, STUDY_FLAG_OPTIONS)
    if "help" in flags
        print_stokes_usage()
        return nothing
    end
    haskey(values, "tfinal") || (values["tfinal"] = "0.0")
    params, _, _ = params_backend_progress(values, flags)
    result = run_stationary_stokes_refinement(StationaryStokesRefinementSpec(;
        base_params=params,
        severities=parse_float_list(get(values, "severities", "0,23,40,50")),
        pressure_drop_pa=parse(Float64, get(values, "pressure-drop-pa", "40")),
        meshes=parse_mesh_list(get(values, "meshes", "8x2x8,16x4x16,32x6x32,64x6x32")),
        output_dir=get(values, "output-dir", ""),
        summary_csv=get(values, "summary-csv", ""),
        overwrite=("overwrite" in flags),
        parallel_workers=parse(Int, get(values, "parallel-workers", string(default_case_workers()))),
    ))
    println("stokes_refinement_summary_csv,$(result.summary_csv)")
    println("stokes_refinement_summary_tex,$(stationary_stokes_refinement_tex_path(result.summary_csv))")
    return result
end

function print_verify_usage()
    println("""
    Usage:
      ./scripts/stenosis-hemodynamics verify mms [--nxs 20,40,80] [--dt-values 2e-5,1e-5,5e-6] [options]
      ./scripts/stenosis-hemodynamics verify ph-refinement [--h-nxs 20,40,80,160] [--degrees 0,1,2,3,4] [options]
      ./scripts/stenosis-hemodynamics verify rest [--severities 23,40] [--nxs 50,100,200] [--elapsed-times 0,0.001,0.005] [options]

    Rest verification defaults to --inlet-umax 0.0; simulate and compare-3d default to 45.0.
    """)
end

function run_verify_cli(args::Vector{String})
    isempty(args) && (print_verify_usage(); return nothing)
    subcommand = args[1]
    rest = args[2:end]
    subcommand in ("--help", "-h", "help") && (print_verify_usage(); return nothing)
    values, flags = parse_cli_options(rest, VERIFY_VALUE_OPTIONS, VERIFY_FLAG_OPTIONS)
    if "help" in flags
        print_verify_usage()
        return nothing
    end
    output_dir = get(values, "output-dir", joinpath("simulations", "output", "verification"))
    overwrite = "overwrite" in flags
    progress_every = parse(Int, get(values, "progress-every", "0"))

    if subcommand == "mms"
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
        result = run_manufactured_verification(ManufacturedVerificationSpec(;
            base_params=base_params,
            nxs=parse_int_list(get(values, "nxs", "20,40,80")),
            dt_values=parse_float_list(get(values, "dt-values", "2e-5,1e-5,5e-6")),
            output_dir=output_dir,
            summary_csv=get(values, "summary-csv", ""),
            summary_tex=get(values, "summary-tex", ""),
            overwrite=overwrite,
            progress_every=progress_every,
        ))
        println("mms_verification_csv,$(result.summary_csv)")
        println("mms_verification_tex,$(result.summary_tex)")
        return result
    elseif subcommand == "ph-refinement"
        h_degree = parse(Int, get(values, "h-degree", "2"))
        base_params = Params(;
            nx=parse(Int, get(values, "p-nx", "40")),
            tfinal=parse(Float64, get(values, "tfinal", "2e-4")),
            dt=parse(Float64, get(values, "dt", "5e-7")),
            severity=parse(Float64, get(values, "severity", "0")),
            initial_condition=ManufacturedSolutionIC(),
            forcing=ManufacturedForcing(),
            space=DGMethod(h_degree),
            time_stepper=time_stepper_from_cli(values),
            velocity_profile=velocity_profile_from_cli(values),
            rheology=rheology_from_cli(values),
            model=model_from_cli(values),
        )
        result = run_ph_refinement_demo(PHRefinementDemoSpec(;
            base_params=base_params,
            h_nxs=parse_int_list(get(values, "h-nxs", get(values, "nxs", "20,40,80,160"))),
            h_degree=h_degree,
            degrees=parse_int_list(get(values, "degrees", "0,1,2,3,4")),
            p_nx=parse(Int, get(values, "p-nx", "40")),
            output_dir=output_dir,
            summary_csv=get(values, "summary-csv", ""),
            summary_tex=get(values, "summary-tex", ""),
            overwrite=overwrite,
            progress_every=progress_every,
        ))
        println("ph_refinement_demo_csv,$(result.summary_csv)")
        println("ph_refinement_demo_tex,$(result.summary_tex)")
        return result
    elseif subcommand == "rest"
        base_params = Params(;
            nx=parse(Int, get(values, "nx", "80")),
            tfinal=parse(Float64, get(values, "tfinal", "1e-3")),
            dt=parse(Float64, get(values, "dt", "1e-5")),
            severity=parse(Float64, get(values, "severity", "23")),
            initial_condition=GeometryRestIC(),
            forcing=NoForcing(),
            inlet_umax=parse(Float64, get(values, "inlet-umax", "0.0")),
            space=spatial_method_from_cli(values),
            time_stepper=time_stepper_from_cli(values),
            velocity_profile=velocity_profile_from_cli(values),
            rheology=rheology_from_cli(values),
            model=model_from_cli(values),
        )
        result = run_rest_state_drift(RestStateDriftSpec(;
            base_params=base_params,
            severities=parse_float_list(get(values, "severities", "23,40")),
            nxs=parse_int_list(get(values, "nxs", "50,100,200")),
            elapsed_times=parse_float_list(get(values, "elapsed-times", "0,0.001,0.005")),
            output_dir=output_dir,
            summary_csv=get(values, "summary-csv", ""),
            summary_tex=get(values, "summary-tex", ""),
            overwrite=overwrite,
            progress_every=progress_every,
        ))
        println("rest_state_drift_csv,$(result.summary_csv)")
        println("rest_state_drift_tex,$(result.summary_tex)")
        return result
    end

    throw(ArgumentError("unknown verify subcommand '$subcommand'; expected mms, ph-refinement, or rest"))
end

function print_compare3d_usage()
    println("""
    Usage:
      ./scripts/stenosis-hemodynamics compare-3d [--data-root PATH] [--output-dir PATH] [--target-time SECONDS] [--time-atol SECONDS] [--overwrite] [--publish-report-assets]
      ./scripts/stenosis-hemodynamics compare-3d --nxs 200,400,800 [--data-root PATH] [--output-dir PATH] [--target-time SECONDS] [--time-atol SECONDS] [--overwrite] [--publish-report-assets]
      ./scripts/stenosis-hemodynamics compare-3d --nxs 200,400,800 --reuse-grid-summary PATH [--grid-summary-csv PATH] [--grid-summary-tex PATH] [--overwrite]
    """)
end

function run_compare3d_cli(args::Vector{String})
    values, flags = parse_cli_options(args, COMPARISON_VALUE_OPTIONS, COMPARISON_FLAG_OPTIONS)
    if "help" in flags
        print_compare3d_usage()
        return nothing
    end
    params, backend, progress_every = params_backend_progress(values, flags)
    profile_slices = haskey(values, "profile-slices") ? parse_float_list(values["profile-slices"]) : nothing
    node_slab_half_widths = haskey(values, "node-slab-half-widths") ? parse_float_list(values["node-slab-half-widths"]) : nothing
    radial_bin_counts = haskey(values, "radial-bin-counts") ? parse_int_list(values["radial-bin-counts"]) : nothing
    radial_radius_modes = haskey(values, "radial-radius-modes") ? split(values["radial-radius-modes"], ",") : nothing
    if haskey(values, "nxs")
        if haskey(values, "reuse-grid-summary")
            result = run_grid_sensitivity_from_summary_csv(
                values["reuse-grid-summary"];
                base_params=params,
                output_dir=get(values, "output-dir", joinpath(DEFAULT_COMPARISON_OUTPUT_DIR, "grid_sensitivity")),
                nxs=parse_int_list(values["nxs"]),
                summary_csv=get(values, "grid-summary-csv", ""),
                summary_tex=get(values, "grid-summary-tex", ""),
                overwrite=("overwrite" in flags),
            )
            println("compare_3d_grid_summary_csv,$(result.summary_csv)")
            println("compare_3d_grid_summary_tex,$(result.summary_tex)")
            if "publish-report-assets" in flags
                paths = publish_resolved3d_grid_sensitivity_assets(
                    result;
                    output_dir=get(values, "report-assets-dir", joinpath("figures", "static", "static", "data", "stenosis-comparison")),
                    overwrite=("overwrite" in flags),
                )
                for path in paths
                    println("compare_3d_report_asset,$path")
                end
            end
            return result
        end

        result = run_available_resolved3d_grid_sensitivity(;
            data_root=get(values, "data-root", default_resolved3d_data_root()),
            target_time=parse(Float64, get(values, "target-time", "0.9995")),
            time_atol=parse(Float64, get(values, "time-atol", "1.0e-3")),
            base_params=params,
            backend=backend,
            output_dir=get(values, "output-dir", joinpath(DEFAULT_COMPARISON_OUTPUT_DIR, "grid_sensitivity")),
            nxs=parse_int_list(values["nxs"]),
            section_count=parse(Int, get(values, "section-count", "200")),
            profile_slices=profile_slices,
            radial_bins=parse(Int, get(values, "radial-bins", "20")),
            radial_bin_counts=radial_bin_counts,
            radial_radius_modes=radial_radius_modes,
            node_slab_half_widths=node_slab_half_widths,
            overwrite=("overwrite" in flags),
            progress_every=progress_every,
            write_svg=!("no-svg" in flags),
            summary_csv=get(values, "grid-summary-csv", ""),
            summary_tex=get(values, "grid-summary-tex", ""),
        )
        if result === nothing
            println("compare_3d_status,skipped_missing_data")
            return nothing
        end
        println("compare_3d_grid_summary_csv,$(result.summary_csv)")
        println("compare_3d_grid_summary_tex,$(result.summary_tex)")
        if "publish-report-assets" in flags
            paths = publish_resolved3d_grid_sensitivity_assets(
                result;
                output_dir=get(values, "report-assets-dir", joinpath("figures", "static", "static", "data", "stenosis-comparison")),
                overwrite=("overwrite" in flags),
            )
            for path in paths
                println("compare_3d_report_asset,$path")
            end
        end
        return result
    end

    result = run_available_resolved3d_comparison(;
        data_root=get(values, "data-root", default_resolved3d_data_root()),
        target_time=parse(Float64, get(values, "target-time", "0.9995")),
        time_atol=parse(Float64, get(values, "time-atol", "1.0e-3")),
        base_params=params,
        backend=backend,
        output_dir=get(values, "output-dir", DEFAULT_COMPARISON_OUTPUT_DIR),
        section_count=parse(Int, get(values, "section-count", "200")),
        profile_slices=profile_slices,
        radial_bins=parse(Int, get(values, "radial-bins", "20")),
        radial_bin_counts=radial_bin_counts,
        radial_radius_modes=radial_radius_modes,
        node_slab_half_widths=node_slab_half_widths,
        overwrite=("overwrite" in flags),
        progress_every=progress_every,
        write_svg=!("no-svg" in flags),
    )
    if result === nothing
        println("compare_3d_status,skipped_missing_data")
        return nothing
    end
    println("compare_3d_summary_csv,$(result.summary_csv)")
    println("compare_3d_sensitivity_csv,$(result.sensitivity_csv)")
    if "publish-report-assets" in flags
        paths = publish_resolved3d_report_assets(
            result;
            output_dir=get(values, "report-assets-dir", joinpath("figures", "static", "static", "data", "stenosis-comparison")),
            overwrite=("overwrite" in flags),
        )
        for path in paths
            println("compare_3d_report_asset,$path")
        end
    end
    return result
end

function print_operator_validation_usage()
    println("""
    Usage:
      ./scripts/stenosis-hemodynamics operator-validation [--output-dir PATH] [--summary-csv PATH] [--summary-tex PATH] [--sample-z LIST] [--plane-center CM] [--plane-shifts LIST] [--constant-value CM_PER_S] [--affine-coefficients C0,CX,CY,CZ] [--tolerance VALUE] [--overwrite]
    """)
end

function run_operator_validation_cli(args::Vector{String})
    values, flags = parse_cli_options(args, OPERATOR_VALIDATION_VALUE_OPTIONS, OPERATOR_VALIDATION_FLAG_OPTIONS)
    if "help" in flags
        print_operator_validation_usage()
        return nothing
    end
    spec = OperatorValidationSpec(;
        output_dir=get(values, "output-dir", DEFAULT_OPERATOR_VALIDATION_OUTPUT_DIR),
        summary_csv=get(values, "summary-csv", ""),
        summary_tex=get(values, "summary-tex", ""),
        sample_z_cm=parse_float_list(get(values, "sample-z", join(DEFAULT_OPERATOR_VALIDATION_Z_SAMPLES, ","))),
        plane_shift_center_cm=parse(Float64, get(values, "plane-center", "0.5")),
        plane_shifts_cm=parse_float_list(get(values, "plane-shifts", join(DEFAULT_OPERATOR_VALIDATION_PLANE_SHIFTS, ","))),
        constant_value_cm_s=parse(Float64, get(values, "constant-value", "12.25")),
        affine_coefficients=parse_float_list(
            get(values, "affine-coefficients", join(DEFAULT_OPERATOR_VALIDATION_AFFINE_COEFFICIENTS, ",")),
        ),
        tolerance=parse(Float64, get(values, "tolerance", "1.0e-11")),
        overwrite=("overwrite" in flags),
    )
    result = run_operator_validation(spec)
    println("operator_validation_csv,$(result.summary_csv)")
    println("operator_validation_tex,$(result.summary_tex)")
    return result
end

function run_export_assets_cli(args::Vector{String})
    opts = parse_export_args(args)
    opts === nothing && return nothing
    return export_stenosis_geometry_figures(opts)
end

const CLI_COMMAND_HANDLERS = Dict{String,Function}(
    "simulate" => run_simulate_cli,
    "openbf-run" => run_openbf_cli,
    "study" => run_study_cli,
    "stokes" => run_stokes_cli,
    "verify" => run_verify_cli,
    "compare-3d" => run_compare3d_cli,
    "operator-validation" => run_operator_validation_cli,
    "benchmark" => run_benchmark_cli,
    "export-assets" => run_export_assets_cli,
)

const CLI_COMMAND_NAMES = join(sort!(collect(keys(CLI_COMMAND_HANDLERS))), ", ")

function run_cli(args::Vector{String} = ARGS)
    if isempty(args) || args[1] in ("--help", "-h", "help")
        print_usage()
        return nothing
    end

    command = args[1]
    rest = args[2:end]
    handler = get(CLI_COMMAND_HANDLERS, command, nothing)
    handler !== nothing && return handler(rest)
    startswith(command, "--") && throw(ArgumentError("missing command; use 'simulate' before simulation options"))
    throw(ArgumentError("unknown command '$command'; expected one of: $CLI_COMMAND_NAMES"))
end
