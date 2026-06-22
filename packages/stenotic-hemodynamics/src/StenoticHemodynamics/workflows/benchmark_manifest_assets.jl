function publish_package_benchmark_assets(output_dir::String, csv_outputs::Vector{String}, manifest_path::String)
    mkpath(PACKAGE_BENCHMARK_DATA_DIR)
    for path in csv_outputs
        cp(path, joinpath(PACKAGE_BENCHMARK_DATA_DIR, basename(path)); force=true)
    end
    cp(manifest_path, joinpath(PACKAGE_BENCHMARK_DATA_DIR, "manifest.json"); force=true)
    return PACKAGE_BENCHMARK_DATA_DIR
end

function write_manifest(path::String, spec::PackageBenchmarkSpec, profile::String, csv_outputs::Vector{String})
    hash_paths = manifest_output_paths(spec.output_dir, csv_outputs, path)
    manifest = Dict{String,Any}(
        "package" => "StenoticHemodynamics",
        "default_model" => "canic-extended-1d",
        "default_wall_law" => wall_law_name(CanicKoiterWallLaw()),
        "default_variable_radius_terms" => variable_radius_terms_enabled(CanicExtendedOneDModel()),
        "profile" => profile,
        "output_dir" => spec.output_dir,
        "timestamp_utc" => chomp(read(`date -u +%Y-%m-%dT%H:%M:%SZ`, String)),
        "git_sha" => safe_readchomp(`git rev-parse HEAD`),
        "julia_version" => string(VERSION),
        "include_resolved3d" => spec.include_resolved3d,
        "publish_report_assets" => spec.publish_report_assets,
        "command" => join(vcat(isempty(PROGRAM_FILE) ? "julia" : PROGRAM_FILE, ARGS), " "),
        "output_hashes" => Dict(basename(p) => sha256_file(p) for p in hash_paths if isfile(p)),
    )
    write_json(path, manifest)
    return path
end

function manifest_output_paths(output_dir::String, csv_outputs::Vector{String}, manifest_path::String)
    output_files = isdir(output_dir) ? filter(isfile, readdir(output_dir; join=true)) : String[]
    manifest_abs = abspath(manifest_path)
    candidates = vcat(csv_outputs, output_files)
    unique_paths = Dict{String,String}()
    for path in candidates
        isfile(path) || continue
        abspath(path) == manifest_abs && continue
        unique_paths[abspath(path)] = path
    end
    return sort!(collect(values(unique_paths)); by=basename)
end

function safe_readchomp(cmd::Cmd)
    try
        return chomp(read(cmd, String))
    catch err
        return "unavailable: " * sprint(showerror, err)
    end
end
