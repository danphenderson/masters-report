function print_stokes_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics stokes refine [--severities 0,23,40,50] [--meshes 8x2x8,16x4x16] [options]
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
    result = run_stationary_stokes_refinement(stationary_stokes_refinement_spec_from_values(values, flags))
    println("stokes_refinement_summary_csv,$(result.summary_csv)")
    println("stokes_refinement_summary_tex,$(stationary_stokes_refinement_tex_path(result.summary_csv))")
    return result
end
