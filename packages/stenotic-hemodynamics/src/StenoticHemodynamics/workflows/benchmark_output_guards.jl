"""
    prepare_package_benchmark_output_dir(output_dir; overwrite=false)

Validate and prepare a package-benchmark output directory.

When `overwrite=false`, an existing directory is rejected. When
`overwrite=true`, only files and subdirectories owned by the package benchmark
workflow are removed; unrelated files in `output_dir` are preserved. Repository
source, report, reference, and raw-data paths are rejected even with overwrite
enabled.
"""
function prepare_package_benchmark_output_dir(output_dir::String; overwrite::Bool = false)
    isempty(strip(output_dir)) && throw(ArgumentError("benchmark output_dir must not be empty"))
    assert_package_benchmark_output_path(output_dir)

    if isdir(output_dir)
        overwrite ||
            throw(ArgumentError("output directory exists; pass overwrite=true to replace benchmark-owned files: $output_dir"))
        clear_package_benchmark_outputs(output_dir)
    elseif isfile(output_dir)
        throw(ArgumentError("output path exists and is not a directory: $output_dir"))
    else
        mkpath(output_dir)
    end
    return output_dir
end

function clear_package_benchmark_outputs(output_dir::String)
    for name in PACKAGE_BENCHMARK_OWNED_FILES
        path = joinpath(output_dir, name)
        isfile(path) && rm(path; force=true)
    end
    for name in PACKAGE_BENCHMARK_OWNED_DIRS
        path = joinpath(output_dir, name)
        isdir(path) && rm(path; recursive=true, force=true)
    end
    return output_dir
end

function assert_package_benchmark_output_path(output_dir::String)
    output_abs = canonical_package_benchmark_path(output_dir)
    repo_root = package_benchmark_repo_root()
    output_abs == repo_root && throw(ArgumentError(
        "refusing to use protected repository root as package benchmark output_dir: $output_dir",
    ))

    for protected in package_benchmark_protected_roots(repo_root)
        if same_or_descendant(output_abs, protected)
            throw(ArgumentError(
                "refusing to use protected repository path as package benchmark output_dir: $output_dir",
            ))
        end
    end
    return output_dir
end

function canonical_package_benchmark_path(path::String)
    normalized = normpath(abspath(path))
    while length(normalized) > 1 && (endswith(normalized, "/") || endswith(normalized, "\\"))
        normalized = normalized[begin:prevind(normalized, lastindex(normalized))]
    end
    return normalized
end

package_benchmark_repo_root() = canonical_package_benchmark_path(joinpath(@__DIR__, "..", "..", "..", "..", ".."))

function package_benchmark_protected_roots(repo_root::String = package_benchmark_repo_root())
    return [
        joinpath(repo_root, "packages", "stenotic-hemodynamics", "src"),
        joinpath(repo_root, "packages", "stenotic-hemodynamics", "test"),
        joinpath(repo_root, "public", "var", "data", "simulations"),
        joinpath(repo_root, "packages", "ops", "src"),
        joinpath(repo_root, "packages", "ops", "tests"),
        joinpath(repo_root, "public", "docs"),
        joinpath(repo_root, "public", "references"),
        joinpath(repo_root, "public", "reproducibility"),
        joinpath(repo_root, "report"),
    ]
end

function same_or_descendant(path::String, parent::String)
    rel = relpath(canonical_package_benchmark_path(path), canonical_package_benchmark_path(parent))
    return rel == "." || !(rel == ".." || startswith(rel, "../") || startswith(rel, "..\\") || isabspath(rel))
end
