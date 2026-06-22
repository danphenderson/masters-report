function print_benchmark_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics benchmark --profile smoke|overnight --output-dir PATH [--overwrite]
    """)
end

function benchmark_spec_from_cli(args::Vector{String})
    values, flags = parse_cli_options(args, BENCHMARK_VALUE_OPTIONS, BENCHMARK_FLAG_OPTIONS)
    if "help" in flags
        return nothing
    end
    return package_benchmark_spec_from_values(values, flags)
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
