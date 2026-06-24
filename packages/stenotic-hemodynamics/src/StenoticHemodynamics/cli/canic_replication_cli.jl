function print_canic_replication_usage(io::IO = stdout)
    println(
        io,
        """
        Usage:
          packages/stenotic-hemodynamics/bin/stenotic-hemodynamics canic-replication section41 [options]

        Options:
          --data-root PATH          Optional upstream case3_all_3d_results root or parent, default public/var/data/simulations/canic_case3
          --output-dir PATH         Output directory, default tmp/simulations/output/canic-replication/section41
          --coordinate-mode VALUE   reference or deformed, default deformed
          --nx VALUE                1D cells, default 100
          --dt VALUE                1D time step, default 1e-5
          --tfinal VALUE            Optional global 1D final-time override; default uses each imported case time
          --section-count VALUE     Axial observation count, default 200
          --radial-sample-count VALUE Radial velocity sample count, default 41
          --time-atol VALUE         XDMF time tolerance, default 1e-6
          --models LIST             Comma-separated 1D models, default canic-extended-1d,classical-parabolic-1d
          --publish-report-assets   Copy CSV/TeX outputs into report/assets/data|tables/canic-replication
          --report-assets-dir PATH  Report asset root, default report/assets
          --overwrite               Replace existing outputs
        """,
    )
end

function canic_section41_spec_from_values(values::Dict{String,String}, flags::Set{String})
    models = split(get(values, "models", join(CANIC_SECTION41_DEFAULT_MODELS, ",")), ",")
    return CanicSection41ReplicationSpec(
        data_root=get(values, "data-root", DEFAULT_RESOLVED3D_DATA_ROOT),
        output_dir=get(values, "output-dir", CANIC_SECTION41_DEFAULT_OUTPUT_DIR),
        report_assets_dir=get(values, "report-assets-dir", joinpath("report", "assets")),
        coordinate_mode=get(values, "coordinate-mode", "deformed"),
        nx=parse(Int, get(values, "nx", "100")),
        dt_s=parse(Float64, get(values, "dt", "1.0e-5")),
        tfinal_s=haskey(values, "tfinal") ? parse(Float64, values["tfinal"]) : nothing,
        section_count=parse(Int, get(values, "section-count", "200")),
        radial_sample_count=parse(Int, get(values, "radial-sample-count", "41")),
        time_atol_s=parse(Float64, get(values, "time-atol", "1.0e-6")),
        models=[strip(model) for model in models if !isempty(strip(model))],
        publish_report_assets=("publish-report-assets" in flags),
        overwrite=("overwrite" in flags),
    )
end

function run_canic_replication_cli(args::Vector{String})
    if isempty(args) || args[1] in ("--help", "-h", "help")
        print_canic_replication_usage()
        return nothing
    end
    subcommand = args[1]
    subcommand == "section41" ||
        throw(ArgumentError("unknown canic-replication subcommand '$subcommand'; expected section41"))
    values, flags = parse_cli_options(args[2:end], CANIC_REPLICATION_VALUE_OPTIONS, CANIC_REPLICATION_FLAG_OPTIONS)
    if "help" in flags
        print_canic_replication_usage()
        return nothing
    end
    spec = canic_section41_spec_from_values(values, flags)
    missing = canic_section41_missing_files(spec.data_root)
    if !isempty(missing)
        println("canic_replication_status,skipped_missing_data")
        println("canic_replication_missing_count,$(length(missing))")
        println("canic_replication_first_missing,$(first(missing))")
        return nothing
    end
    result = run_canic_section41_replication(spec)
    println("canic_replication_status,$(result.status)")
    println("canic_replication_provenance_json,$(result.provenance_json)")
    println("canic_replication_parameter_audit_csv,$(result.parameter_audit_csv)")
    println("canic_replication_comparison_csv,$(result.comparison_csv)")
    println("canic_replication_summary_csv,$(result.summary_csv)")
    println("canic_replication_radial_velocity_csv,$(result.radial_velocity_csv)")
    println("canic_replication_figure6_diagnostics_csv,$(result.figure6_diagnostics_csv)")
    println("canic_replication_parameter_audit_tex,$(result.parameter_audit_tex)")
    println("canic_replication_summary_tex,$(result.summary_tex)")
    return result
end
