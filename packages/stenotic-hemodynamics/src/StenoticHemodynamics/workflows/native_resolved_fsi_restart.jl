"""
    native_resolved_fsi_read_restart_metadata(path)

Read and validate package-written restart-identification metadata for the
native resolved-FSI partitioned production snapshot harness. The metadata is
JSON written by the package's minimal writer, and is parsed through the existing
lazy YAML loader because JSON is valid YAML. Both legacy independent
smoke-backed metadata and current state-carrying-in-run partitioned metadata
are readable; persisted resume remains unsupported for both forms.
"""
function native_resolved_fsi_read_restart_metadata(path::AbstractString)
    path_string = String(path)
    isfile(path_string) ||
        throw(ArgumentError("native resolved-FSI restart metadata file does not exist: $(path_string)"))

    loaded = load_yaml_file(path_string)
    metadata = native_resolved_fsi_normalize_restart_metadata(loaded)
    metadata_dir = dirname(path_string)

    provenance = native_resolved_fsi_require_restart_metadata_string(metadata, "restart_provenance")
    provenance in ("independent_smoke_backed_snapshots", "state_carrying_partitioned") || throw(ArgumentError(
        "native resolved-FSI restart metadata restart_provenance must be " *
        "\"independent_smoke_backed_snapshots\" or \"state_carrying_partitioned\"; got $(repr(provenance))",
    ))
    native_resolved_fsi_require_restart_metadata_value(metadata, "resume_supported", false)
    native_resolved_fsi_require_restart_metadata_value(metadata, "resume_status", "deferred")
    if provenance == "state_carrying_partitioned"
        native_resolved_fsi_require_restart_metadata_value(metadata, "state_carrying_restart", true)
    end

    manifest_csv = native_resolved_fsi_require_restart_metadata_string(metadata, "snapshot_manifest_csv")
    diagnostics_csv = native_resolved_fsi_require_restart_metadata_string(metadata, "diagnostics_csv")
    native_resolved_fsi_require_restart_metadata_file(manifest_csv, metadata_dir, "snapshot_manifest_csv")
    native_resolved_fsi_require_restart_metadata_file(diagnostics_csv, metadata_dir, "diagnostics_csv")

    snapshot_outputs = native_resolved_fsi_require_restart_metadata_vector(metadata, "snapshot_outputs")
    isempty(snapshot_outputs) &&
        throw(ArgumentError("native resolved-FSI restart metadata requires at least one snapshot output"))
    for (index, snapshot_output) in enumerate(snapshot_outputs)
        snapshot_output isa Dict{String,Any} || throw(ArgumentError(
            "native resolved-FSI restart metadata snapshot_outputs[$(index)] must be a mapping",
        ))
        output_dir = native_resolved_fsi_require_restart_metadata_string(
            snapshot_output,
            "output_dir";
            context="native resolved-FSI restart metadata snapshot_outputs[$(index)]",
        )
        native_resolved_fsi_require_restart_metadata_dir(
            output_dir,
            metadata_dir,
            "snapshot_outputs[$(index)].output_dir",
        )
        for key in ("velocity_xdmf", "pressure_xdmf", "displacement_xdmf")
            bundle_path = native_resolved_fsi_require_restart_metadata_string(
                snapshot_output,
                key;
                context="native resolved-FSI restart metadata snapshot_outputs[$(index)]",
            )
            native_resolved_fsi_require_restart_metadata_file(
                bundle_path,
                metadata_dir,
                "snapshot_outputs[$(index)].$(key)",
            )
        end
        if provenance == "state_carrying_partitioned"
            native_resolved_fsi_require_restart_metadata_value(
                snapshot_output,
                "provenance",
                "state_carrying_partitioned";
                context="native resolved-FSI restart metadata snapshot_outputs[$(index)]",
            )
            native_resolved_fsi_require_restart_metadata_positive_integer(
                snapshot_output,
                "time_step_count";
                context="native resolved-FSI restart metadata snapshot_outputs[$(index)]",
            )
        end
    end

    return metadata
end

"""
    native_resolved_fsi_resume_partitioned_production(path; kwargs...)

Validate restart-identification metadata, then fail closed because persisted
resume from restart metadata is not implemented. Current production metadata
may be state-carrying within a single run, but it is still identification-only
for future process resume.
"""
function native_resolved_fsi_resume_partitioned_production(path::AbstractString; kwargs...)
    metadata = native_resolved_fsi_read_restart_metadata(path)
    provenance = String(metadata["restart_provenance"])
    throw(ArgumentError(
        "native resolved-FSI persisted resume from restart metadata is unsupported for provenance " *
        "$(repr(provenance)); state may be carried within a production run, but resume_supported is false " *
        "and resume_status is deferred",
    ))
end

function native_resolved_fsi_normalize_restart_metadata(value)
    normalized = native_resolved_fsi_normalize_restart_metadata_value(value)
    normalized isa Dict{String,Any} ||
        throw(ArgumentError("native resolved-FSI restart metadata must be a mapping"))
    return normalized
end

function native_resolved_fsi_normalize_restart_metadata_value(value)
    if value isa AbstractDict
        return Dict{String,Any}(
            string(key) => native_resolved_fsi_normalize_restart_metadata_value(nested_value)
            for (key, nested_value) in value
        )
    elseif value isa AbstractVector
        return Any[native_resolved_fsi_normalize_restart_metadata_value(item) for item in value]
    else
        return value
    end
end

function native_resolved_fsi_require_restart_metadata_value(
    metadata::Dict{String,Any},
    key::String,
    expected;
    context::String = "native resolved-FSI restart metadata",
)
    haskey(metadata, key) ||
        throw(ArgumentError("$(context) requires '$(key)'"))
    value = metadata[key]
    value == expected || throw(ArgumentError(
        "$(context) requires $(key) == $(repr(expected)); got $(repr(value))",
    ))
    return value
end

function native_resolved_fsi_require_restart_metadata_positive_integer(
    metadata::Dict{String,Any},
    key::String;
    context::String = "native resolved-FSI restart metadata",
)
    haskey(metadata, key) || throw(ArgumentError("$(context) requires '$(key)'"))
    value = metadata[key]
    value isa Integer || throw(ArgumentError("$(context) '$(key)' must be an integer"))
    value > 0 || throw(ArgumentError("$(context) '$(key)' must be positive"))
    return value
end

function native_resolved_fsi_require_restart_metadata_string(
    metadata::Dict{String,Any},
    key::String;
    context::String = "native resolved-FSI restart metadata",
)
    haskey(metadata, key) || throw(ArgumentError("$(context) requires '$(key)'"))
    value = metadata[key]
    value isa AbstractString || throw(ArgumentError("$(context) '$(key)' must be a string"))
    return String(value)
end

function native_resolved_fsi_require_restart_metadata_vector(metadata::Dict{String,Any}, key::String)
    haskey(metadata, key) ||
        throw(ArgumentError("native resolved-FSI restart metadata requires '$(key)'"))
    value = metadata[key]
    value isa AbstractVector ||
        throw(ArgumentError("native resolved-FSI restart metadata '$(key)' must be an array"))
    return value
end

function native_resolved_fsi_restart_metadata_path_exists(path::String, metadata_dir::String, predicate)
    candidates = String[path]
    if !isabspath(path) && !isempty(metadata_dir)
        push!(candidates, joinpath(metadata_dir, path))
    end
    return any(predicate, candidates)
end

function native_resolved_fsi_require_restart_metadata_file(path::String, metadata_dir::String, label::String)
    native_resolved_fsi_restart_metadata_path_exists(path, metadata_dir, isfile) || throw(ArgumentError(
        "native resolved-FSI restart metadata $(label) references a missing file: $(path)",
    ))
    return path
end

function native_resolved_fsi_require_restart_metadata_dir(path::String, metadata_dir::String, label::String)
    native_resolved_fsi_restart_metadata_path_exists(path, metadata_dir, isdir) || throw(ArgumentError(
        "native resolved-FSI restart metadata $(label) references a missing directory: $(path)",
    ))
    return path
end
