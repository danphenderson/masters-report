#!/usr/bin/env julia

using CanicExtended1D

function usage()
    return """
    Usage:
      ./scripts/julia-release simulations/run_package_benchmark.jl \\
        --profile smoke|overnight \\
        --output-dir simulations/output/package_benchmark/<run_id> \\
        [--overwrite] [--include-python] [--include-resolved3d] [--publish-report-assets]

    Defaults:
      --profile smoke
      --output-dir simulations/output/package_benchmark/smoke
    """
end

function parse_benchmark_args(args)
    values = Dict{String,String}(
        "profile" => "smoke",
        "output-dir" => joinpath("simulations", "output", "package_benchmark", "smoke"),
    )
    flags = Set{String}()
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--help" || arg == "-h"
            println(usage())
            exit(0)
        elseif arg in ("--overwrite", "--include-python", "--include-resolved3d", "--publish-report-assets")
            push!(flags, arg[3:end])
            i += 1
        elseif arg in ("--profile", "--output-dir")
            i < length(args) || throw(ArgumentError("missing value for $arg"))
            values[arg[3:end]] = args[i + 1]
            i += 2
        elseif startswith(arg, "--")
            throw(ArgumentError("unknown option: $arg"))
        else
            throw(ArgumentError("unexpected positional argument: $arg"))
        end
    end

    return PackageBenchmarkSpec(;
        profile=values["profile"],
        output_dir=values["output-dir"],
        overwrite=("overwrite" in flags),
        include_python=("include-python" in flags),
        include_resolved3d=("include-resolved3d" in flags),
        publish_report_assets=("publish-report-assets" in flags),
    )
end

function main(args)
    spec = parse_benchmark_args(args)
    result = run_package_benchmark(spec)
    println("wrote package benchmark manifest: $(result.manifest_path)")
    for path in result.csv_paths
        println("wrote package benchmark csv: $path")
    end
    if spec.publish_report_assets
        println("published package benchmark data: $(CanicExtended1D.PACKAGE_BENCHMARK_DATA_DIR)")
    end
    return result
end

main(ARGS)
