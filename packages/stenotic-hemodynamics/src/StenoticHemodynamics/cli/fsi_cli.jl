function print_fsi_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics fsi validate [--wall-mode quasi-static|dynamic] [--severities 23,40] [--meshes 8x2x8,16x4x16] [--publish-report-assets] [options]

    Dynamic mode is a reduced radial membrane model coupled to repeated quasi-steady Stokes solves.
    Dynamic options use cgs-compatible units: --wall-density G/CM3, --wall-dt SECONDS, --wall-tfinal SECONDS.
    Report assets are written under --report-assets-dir, default report/assets.
    """)
end

function run_fsi_cli(args::Vector{String})
    isempty(args) && (print_fsi_usage(); return nothing)
    subcommand = args[1]
    rest = args[2:end]
    subcommand in ("--help", "-h", "help") && (print_fsi_usage(); return nothing)
    subcommand == "validate" || throw(ArgumentError("unknown fsi subcommand '$subcommand'; expected validate"))
    values, flags = parse_cli_options(rest, FSI_VALUE_OPTIONS, FSI_FLAG_OPTIONS)
    if "help" in flags
        print_fsi_usage()
        return nothing
    end
    haskey(values, "tfinal") || (values["tfinal"] = "0.0")
    params, _, _ = params_backend_progress(values, flags)
    result = run_membrane_fsi_validation(membrane_fsi_validation_spec_from_values(params, values, flags))
    println("fsi_validation_summary_csv,$(result.summary_csv)")
    println("fsi_validation_summary_tex,$(result.summary_tex)")
    println("fsi_validation_manifest_json,$(result.manifest_json)")
    if "publish-report-assets" in flags
        paths = publish_membrane_fsi_report_assets(
            result;
            report_assets_dir=get(values, "report-assets-dir", joinpath("report", "assets")),
            overwrite=("overwrite" in flags),
        )
        for path in paths
            println("fsi_validation_report_asset,$path")
        end
    end
    return result
end
