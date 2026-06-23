function print_visualization_usage(io::IO = stdout)
    println(
        io,
        """
        Usage:
          packages/stenotic-hemodynamics/bin/stenotic-hemodynamics visualization export-web [options]

        Required:
          --output-dir PATH

        Input modes:
          --velocity-xdmf PATH
          --input-production-dir DIR

        Three-field native resolved-FSI exports also require pressure and displacement:
          --pressure-xdmf PATH
          --displacement-xdmf PATH

        Options:
          --schema-version 1|2
          --case-id sev23|sev40|sev50
          --target-time FLOAT
          --time-atol FLOAT
          --coordinate-mode reference|deformed
          --geometry-mode surface
          --snapshot-include IDS
          --snapshot-exclude IDS
          --snapshot-stride N
          --max-snapshots N
          --include-tetra-debug
          --allow-velocity-only
          --overwrite
        """,
    )
end

function run_visualization_cli(args::Vector{String})
    if isempty(args) || args[1] in ("--help", "-h", "help")
        print_visualization_usage()
        return nothing
    end
    subcommand = args[1]
    subcommand == "export-web" || throw(ArgumentError("unknown visualization subcommand '$subcommand'; expected export-web"))
    return run_visualization_export_web_cli(args[2:end])
end

function run_visualization_export_web_cli(args::Vector{String})
    values, flags = parse_cli_options(args, VISUALIZATION_VALUE_OPTIONS, VISUALIZATION_FLAG_OPTIONS)
    if "help" in flags
        print_visualization_usage()
        return nothing
    end
    velocity_xdmf = get(values, "velocity-xdmf", "")
    output_dir = get(values, "output-dir", "")
    spec = NativeResolvedFSIWebExportSpec(
        schema_version=haskey(values, "schema-version") ? values["schema-version"] : nothing,
        velocity_xdmf=velocity_xdmf,
        pressure_xdmf=get(values, "pressure-xdmf", default_companion_xdmf_path(velocity_xdmf, "pressure.xdmf")),
        displacement_xdmf=get(values, "displacement-xdmf", default_companion_xdmf_path(velocity_xdmf, "displace.xdmf")),
        input_production_dir=get(values, "input-production-dir", ""),
        output_dir=output_dir,
        case_id=get(values, "case-id", "sev23"),
        target_time=parse(Float64, get(values, "target-time", string(RESOLVED3D_DEFAULT_BENCHMARK_TIME_S))),
        time_atol=parse(Float64, get(values, "time-atol", "0.001")),
        coordinate_mode=get(values, "coordinate-mode", "reference"),
        geometry_mode=get(values, "geometry-mode", "surface"),
        include_tetra_debug="include-tetra-debug" in flags,
        include_observations=!("no-observations" in flags),
        include_derived=!("no-derived" in flags),
        allow_velocity_only="allow-velocity-only" in flags,
        diagnostics_csv=get(values, "diagnostics-csv", ""),
        restart_metadata_json=get(values, "restart-metadata-json", ""),
        observations_csv=get(values, "observations-csv", ""),
        observation_summary_csv=get(values, "observation-summary-csv", ""),
        batch_benchmark_json=get(values, "batch-benchmark-json", ""),
        snapshot_include=get(values, "snapshot-include", ""),
        snapshot_exclude=get(values, "snapshot-exclude", ""),
        snapshot_stride=parse(Int, get(values, "snapshot-stride", "1")),
        max_snapshots=haskey(values, "max-snapshots") ? values["max-snapshots"] : nothing,
        overwrite="overwrite" in flags,
    )
    result = run_native_resolved_fsi_web_export(spec)
    println("manifest_json,$(result.manifest_json)")
    println("asset_count,$(length(result.asset_paths))")
    println("frame_count,$(result.frame_count)")
    println("skipped_snapshots,$(join(result.skipped_snapshots, ";"))")
    println("estimated_playback_fps,$(result.estimated_playback_fps)")
    return result
end
