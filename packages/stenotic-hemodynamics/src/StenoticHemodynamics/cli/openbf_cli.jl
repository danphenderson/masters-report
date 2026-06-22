function print_openbf_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics openbf-run --config PATH [--verbose] [--save-stats]
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
