function print_usage(io::IO = stdout)
    println(
        io,
        """
        Usage:
          packages/stenotic-hemodynamics/bin/stenotic-hemodynamics <command> [options]

        Commands:
          simulate      Run one 1D forward simulation
          openbf-run    Run a strict OpenBF-style input.yml adapter
          study         Run severity, grid, or refinement studies
          stokes        Run stationary-Stokes workflows
          fsi           Run membrane-FSI validation and native resolved-FSI status workflows
          verify        Run MMS and rest-state verification workflows
          compare-3d    Compare available resolved-3D cases against 1D runs
          operator-validation Validate cross-section quadrature on synthetic cuts
          benchmark     Run package benchmark profiles
          export-assets Export stenosis geometry/report CSV assets

        Run 'packages/stenotic-hemodynamics/bin/stenotic-hemodynamics <command> --help' for command help.
        """,
    )
end

const CLI_COMMAND_HANDLERS = Dict{String,Function}(
    "simulate" => run_simulate_cli,
    "openbf-run" => run_openbf_cli,
    "study" => run_study_cli,
    "stokes" => run_stokes_cli,
    "fsi" => run_fsi_cli,
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
