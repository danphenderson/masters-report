function print_simulate_usage(io::IO = stdout)
    println(
        io,
        """
        Usage:
          packages/stenotic-hemodynamics/bin/stenotic-hemodynamics simulate [options]

        Options:
          --model VALUE           canic-extended-1d or classical-parabolic-1d
                                  (legacy alias: classical-1d-no-slip)
          --severity VALUE        Stenosis severity percentage, default 50
          --nx VALUE              Number of finite-volume cells, default 400
          --tfinal VALUE          Final time in seconds, default 1.0
          --dt VALUE              Maximum time step, default 1e-5
          --cfl VALUE             CFL limit, default 0.45
          --space VALUE           fv-first-order, fv-muscl, fv-wb-geometry-rest, fv-weno3, fv-lax-wendroff, or dg
          --degree VALUE          DG polynomial degree 0 through 4
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
          --overwrite             Replace existing CSV/SVG outputs
          --progress-every VALUE  Log every N steps, default 5000; use 0 to disable
          --help                  Show this help
        """,
    )
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
    write_csv(output.csv, result, params; overwrite=output.overwrite)
    output.write_svg && write_svg(output.svg, result, params; overwrite=output.overwrite)

    for line in summary_lines(result, params, output)
        println(line)
    end

    return result
end

function run_simulate_cli(args::Vector{String})
    parsed = parse_simulate_args(args)
    return run_single_simulation(parsed)
end
