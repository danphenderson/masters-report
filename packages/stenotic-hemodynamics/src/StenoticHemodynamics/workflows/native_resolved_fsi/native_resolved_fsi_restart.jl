"""
    native_resolved_fsi_read_restart_metadata(path)

Read and validate package-written restart-identification metadata for the
native resolved-FSI partitioned production snapshot harness. The metadata is
JSON written by the package's minimal writer, and is parsed through the existing
lazy YAML loader because JSON is valid YAML. Both legacy independent
smoke-backed metadata and current state-carrying-in-run partitioned metadata
are readable. When a versioned `state_payload` block is present it is validated
as audit metadata only; persisted resume remains unsupported for all forms.
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
    native_resolved_fsi_validate_restart_boundary_status_if_present(metadata)

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
        native_resolved_fsi_validate_restart_boundary_status_if_present(
            snapshot_output;
            context="native resolved-FSI restart metadata snapshot_outputs[$(index)]",
        )
    end
    if haskey(metadata, "state_payload")
        native_resolved_fsi_validate_restart_state_payload(metadata)
    end

    return metadata
end

"""
    native_resolved_fsi_resume_partitioned_production(path; kwargs...)

Validate restart-identification metadata, including any optional state payload,
then fail closed because persisted resume from restart metadata is not
implemented. Current production metadata may carry state within a single run,
but saved payloads are audit metadata until an actual resumed run is
implemented and tested.
"""
function native_resolved_fsi_resume_partitioned_production(path::AbstractString; kwargs...)
    metadata = native_resolved_fsi_read_restart_metadata(path)
    provenance = String(metadata["restart_provenance"])
    throw(ArgumentError(
        "native resolved-FSI persisted resume from restart metadata is unsupported for provenance " *
        "$(repr(provenance)); state_payload may record state carried within a production run, but " *
        "resume_supported is false and resume_status is deferred",
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
    value isa Integer && !(value isa Bool) || throw(ArgumentError("$(context) '$(key)' must be an integer"))
    value > 0 || throw(ArgumentError("$(context) '$(key)' must be positive"))
    return value
end

function native_resolved_fsi_require_restart_metadata_mapping(
    metadata::Dict{String,Any},
    key::String;
    context::String = "native resolved-FSI restart metadata",
)
    haskey(metadata, key) || throw(ArgumentError("$(context) requires '$(key)'"))
    value = metadata[key]
    value isa Dict{String,Any} || throw(ArgumentError("$(context) '$(key)' must be a mapping"))
    return value
end

function native_resolved_fsi_require_restart_metadata_finite_real(
    metadata::Dict{String,Any},
    key::String;
    context::String = "native resolved-FSI restart metadata",
)
    haskey(metadata, key) || throw(ArgumentError("$(context) requires '$(key)'"))
    value = metadata[key]
    value isa Real && !(value isa Bool) || throw(ArgumentError("$(context) '$(key)' must be numeric"))
    value_float = Float64(value)
    isfinite(value_float) || throw(ArgumentError("$(context) '$(key)' must be finite"))
    return value_float
end

function native_resolved_fsi_require_restart_metadata_bool(
    metadata::Dict{String,Any},
    key::String,
    expected::Bool;
    context::String = "native resolved-FSI restart metadata",
)
    haskey(metadata, key) || throw(ArgumentError("$(context) requires '$(key)'"))
    value = metadata[key]
    value isa Bool || throw(ArgumentError("$(context) '$(key)' must be a boolean"))
    value == expected || throw(ArgumentError("$(context) requires $(key) == $(repr(expected)); got $(repr(value))"))
    return value
end

function native_resolved_fsi_require_restart_metadata_finite_real_vector(
    metadata::Dict{String,Any},
    key::String;
    context::String = "native resolved-FSI restart metadata",
)
    haskey(metadata, key) || throw(ArgumentError("$(context) requires '$(key)'"))
    value = metadata[key]
    value isa AbstractVector || throw(ArgumentError("$(context) '$(key)' must be an array"))
    isempty(value) && throw(ArgumentError("$(context) '$(key)' must not be empty"))
    vector = Float64[]
    for (index, item) in enumerate(value)
        item isa Real && !(item isa Bool) || throw(ArgumentError("$(context) '$(key)'[$(index)] must be numeric"))
        item_float = Float64(item)
        isfinite(item_float) || throw(ArgumentError("$(context) '$(key)'[$(index)] must be finite"))
        push!(vector, item_float)
    end
    return vector
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

const NATIVE_RESOLVED_FSI_RESTART_BOUNDARY_STATUS_KEYS = (
    "inlet_umax_cm_s",
    "boundary_mode",
    "boundary_mode_class",
    "inlet_condition_status",
    "outlet_condition_status",
    "pressure_gauge_status",
    "wall_pressure_projection_status",
    "section41_boundary_status",
    "boundary_status",
    "boundary_equivalence_status",
)

function native_resolved_fsi_restart_boundary_inlet_umax_cm_s(
    metadata::Dict{String,Any},
    mode::Symbol;
    context::String,
)
    if haskey(metadata, "inlet_umax_cm_s")
        value = native_resolved_fsi_require_restart_metadata_finite_real(
            metadata,
            "inlet_umax_cm_s";
            context=context,
        )
        value > 0.0 || throw(ArgumentError("$(context) 'inlet_umax_cm_s' must be positive"))
        return value
    end
    mode === :poiseuille_inlet_zero_outlet_stress_section41 && throw(ArgumentError(
        "$(context) exact Section 4.1 boundary metadata requires 'inlet_umax_cm_s'",
    ))
    return NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S
end

function native_resolved_fsi_validate_restart_boundary_status_if_present(
    metadata::Dict{String,Any};
    context::String = "native resolved-FSI restart metadata",
)
    any(key -> haskey(metadata, key), NATIVE_RESOLVED_FSI_RESTART_BOUNDARY_STATUS_KEYS) || return nothing
    mode = native_resolved_fsi_require_restart_metadata_string(metadata, "boundary_mode"; context=context)
    mode_symbol = Symbol(mode)
    inlet_umax_cm_s = native_resolved_fsi_restart_boundary_inlet_umax_cm_s(
        metadata,
        mode_symbol;
        context=context,
    )
    boundary_status = native_resolved_fsi_boundary_status_fields(mode_symbol; inlet_umax_cm_s=inlet_umax_cm_s)
    expected_values = Dict{String,String}(
        "boundary_mode" => boundary_status.boundary_mode,
        "boundary_mode_class" => boundary_status.boundary_mode_class,
        "inlet_condition_status" => boundary_status.inlet_condition_status,
        "outlet_condition_status" => boundary_status.outlet_condition_status,
        "pressure_gauge_status" => boundary_status.pressure_gauge_status,
        "section41_boundary_status" => boundary_status.section41_boundary_status,
        "boundary_status" => boundary_status.boundary_status,
        "boundary_equivalence_status" => native_resolved_fsi_boundary_equivalence_status(boundary_status),
    )
    for (key, expected) in expected_values
        native_resolved_fsi_require_restart_metadata_value(metadata, key, expected; context=context)
    end
    if haskey(metadata, "wall_pressure_projection_status")
        native_resolved_fsi_require_restart_metadata_value(
            metadata,
            "wall_pressure_projection_status",
            native_resolved_fsi_wall_pressure_projection_status(mode_symbol);
            context=context,
        )
    end
    if haskey(metadata, "pressure_nullspace_status")
        native_resolved_fsi_require_restart_metadata_value(
            metadata,
            "pressure_nullspace_status",
            native_resolved_fsi_pressure_nullspace_status(mode_symbol);
            context=context,
        )
    end
    return nothing
end

function native_resolved_fsi_validate_restart_state_payload(metadata::Dict{String,Any})
    context = "native resolved-FSI restart metadata state_payload"
    payload = native_resolved_fsi_require_restart_metadata_mapping(metadata, "state_payload")
    schema_version =
        native_resolved_fsi_require_restart_metadata_positive_integer(payload, "schema_version"; context=context)
    schema_version == 1 ||
        throw(ArgumentError("$(context) requires schema_version == 1; got $(repr(schema_version))"))
    saved_time_s = native_resolved_fsi_require_restart_metadata_finite_real(payload, "saved_time_s"; context=context)
    saved_time_s > 0.0 || throw(ArgumentError("$(context) 'saved_time_s' must be positive"))
    last_snapshot_index =
        native_resolved_fsi_require_restart_metadata_positive_integer(payload, "last_snapshot_index"; context=context)
    final_wall_displacement_cm = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        payload,
        "final_wall_displacement_cm";
        context=context,
    )
    final_wall_velocity_cm_s = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        payload,
        "final_wall_velocity_cm_s";
        context=context,
    )
    current_radii_cm = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        payload,
        "current_radii_cm";
        context=context,
    )
    final_wall_pressure_dyn_cm2 = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        payload,
        "final_wall_pressure_dyn_cm2";
        context=context,
    )
    vector_lengths = (
        length(final_wall_displacement_cm),
        length(final_wall_velocity_cm_s),
        length(current_radii_cm),
        length(final_wall_pressure_dyn_cm2),
    )
    all(==(first(vector_lengths)), vector_lengths) ||
        throw(ArgumentError("$(context) wall state arrays must have matching lengths"))
    all(radius -> radius > 0.0, current_radii_cm) ||
        throw(ArgumentError("$(context) 'current_radii_cm' entries must be positive"))
    native_resolved_fsi_require_restart_metadata_value(
        payload,
        "solver_provenance",
        "state_carrying_partitioned";
        context=context,
    )
    native_resolved_fsi_require_restart_metadata_bool(payload, "state_carrying_in_run", true; context=context)
    native_resolved_fsi_require_restart_metadata_bool(payload, "resume_supported", false; context=context)
    native_resolved_fsi_require_restart_metadata_value(payload, "resume_status", "deferred"; context=context)
    if haskey(metadata, "current_snapshot_index") && metadata["current_snapshot_index"] != last_snapshot_index
        throw(ArgumentError("$(context) last_snapshot_index must match current_snapshot_index"))
    end
    if haskey(metadata, "snapshot_outputs")
        snapshot_outputs = native_resolved_fsi_require_restart_metadata_vector(metadata, "snapshot_outputs")
        last_snapshot_index <= length(snapshot_outputs) ||
            throw(ArgumentError("$(context) last_snapshot_index exceeds snapshot_outputs length"))
    end
    return payload
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
