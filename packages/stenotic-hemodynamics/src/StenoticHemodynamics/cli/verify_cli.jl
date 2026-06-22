function print_verify_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics verify mms [--nxs 20,40,80] [--dt-values 2e-5,1e-5,5e-6] [options]
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics verify ph-refinement [--h-nxs 20,40,80,160] [--degrees 0,1,2,3,4] [options]
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics verify rest [--severities 23,40] [--nxs 50,100,200] [--elapsed-times 0,0.001,0.005] [options]

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
    output_dir = get(values, "output-dir", joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "verification"))
    overwrite = "overwrite" in flags
    progress_every = parse(Int, get(values, "progress-every", "0"))

    if subcommand == "mms"
        spec = manufactured_verification_spec_from_values(
            values,
            flags;
            output_dir=output_dir,
            overwrite=overwrite,
            progress_every=progress_every,
        )
        result = run_manufactured_verification(spec)
        println("mms_verification_csv,$(result.summary_csv)")
        println("mms_verification_tex,$(result.summary_tex)")
        return result
    elseif subcommand == "ph-refinement"
        spec = ph_refinement_demo_spec_from_values(
            values,
            flags;
            output_dir=output_dir,
            overwrite=overwrite,
            progress_every=progress_every,
        )
        result = run_ph_refinement_demo(spec)
        println("ph_refinement_demo_csv,$(result.summary_csv)")
        println("ph_refinement_demo_tex,$(result.summary_tex)")
        return result
    elseif subcommand == "rest"
        spec = rest_state_drift_spec_from_values(
            values,
            flags;
            output_dir=output_dir,
            overwrite=overwrite,
            progress_every=progress_every,
        )
        result = run_rest_state_drift(spec)
        println("rest_state_drift_csv,$(result.summary_csv)")
        println("rest_state_drift_tex,$(result.summary_tex)")
        println("rest_state_residual_components_csv,$(result.residual_csv)")
        println("rest_state_residual_components_tex,$(result.residual_tex)")
        return result
    end

    throw(ArgumentError("unknown verify subcommand '$subcommand'; expected mms, ph-refinement, or rest"))
end
