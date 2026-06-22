function print_study_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics study severity --severities 23,50 [options]
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics study grid --nxs 40,80 [options]
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics study refinement --nxs 50,100,200,400 [options]
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

    if subcommand == "severity"
        result = run_study(severity_sweep_spec_from_values(values, flags))
        println("study_summary_csv,$(result.summary_csv)")
        return result
    elseif subcommand == "grid"
        result = run_study(grid_convergence_study_spec_from_values(values, flags))
        println("study_summary_csv,$(result.summary_csv)")
        return result
    elseif subcommand == "refinement"
        result = run_refinement_study(refinement_study_spec_from_values(values, flags))
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
