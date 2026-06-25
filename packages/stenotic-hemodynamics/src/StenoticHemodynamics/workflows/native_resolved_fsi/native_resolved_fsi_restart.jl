const NATIVE_RESOLVED_FSI_RESTART_SCHEMA_AUDIT_METADATA_VERSION = 1
const NATIVE_RESOLVED_FSI_RESTART_SCHEMA_CHECKPOINT_MANIFEST_VERSION = 2
const NATIVE_RESOLVED_FSI_RESTART_SCHEMA_DURABLE_CHECKPOINT_VERSION = 3
const NATIVE_RESOLVED_FSI_RESTART_INTERNAL_RESUME_SCOPE = "qualified_internal_split_run_only"
const NATIVE_RESOLVED_FSI_RESTART_INTERNAL_RESUME_STATUS = "ready"
const NATIVE_RESOLVED_FSI_RESTART_PUBLIC_RESUME_STATUS = "unsupported_no_public_or_default_process_resume"
const NATIVE_RESOLVED_FSI_RESTART_DEFAULT_PROCESS_RESUME_STATUS =
    "unsupported_use_qualified_internal_split_run_only"
const NATIVE_RESOLVED_FSI_RESTART_SCHEMA_V2_REQUIRED_CHECKPOINT_ROLES = (
    "wall_state",
    "mesh_identity",
    "fluid_state",
    "coupling_state",
    "output_linkage",
)
const NATIVE_RESOLVED_FSI_RESTART_SCHEMA_V3_REQUIRED_CHECKPOINT_ROLES =
    NATIVE_RESOLVED_FSI_RESTART_SCHEMA_V2_REQUIRED_CHECKPOINT_ROLES

"""
    native_resolved_fsi_read_restart_metadata(path)

Read and validate package-written restart-identification metadata for the
native resolved-FSI partitioned production snapshot harness. The metadata is
JSON written by the package's minimal writer, and is parsed through the existing
lazy YAML loader because JSON is valid YAML. Both legacy independent
smoke-backed metadata and current state-carrying-in-run partitioned metadata
are readable. When a versioned `state_payload` block is present it is validated
as audit metadata only. Durable schema-v3 checkpoints are valid only for
qualified internal split-run resume; public/default process resume remains
unsupported.
"""
function native_resolved_fsi_read_restart_metadata(path::AbstractString)
    path_string = String(path)
    isfile(path_string) ||
        throw(ArgumentError("native resolved-FSI restart metadata file does not exist: $(path_string)"))

    loaded = load_yaml_file(path_string)
    metadata = native_resolved_fsi_normalize_restart_metadata(loaded)
    metadata_dir = dirname(path_string)
    restart_schema_version = native_resolved_fsi_restart_schema_version(metadata)
    native_resolved_fsi_validate_restart_schema_contract(metadata, restart_schema_version, metadata_dir)

    provenance = native_resolved_fsi_require_restart_metadata_string(metadata, "restart_provenance")
    provenance in ("independent_smoke_backed_snapshots", "state_carrying_partitioned") || throw(ArgumentError(
        "native resolved-FSI restart metadata restart_provenance must be " *
        "\"independent_smoke_backed_snapshots\" or \"state_carrying_partitioned\"; got $(repr(provenance))",
    ))
    if restart_schema_version == NATIVE_RESOLVED_FSI_RESTART_SCHEMA_DURABLE_CHECKPOINT_VERSION
        native_resolved_fsi_require_restart_metadata_value(metadata, "resume_supported", true)
        native_resolved_fsi_require_restart_metadata_value(metadata, "resume_status", "ready")
        native_resolved_fsi_validate_restart_schema_v3_resume_scope(metadata)
    else
        native_resolved_fsi_require_restart_metadata_value(metadata, "resume_supported", false)
        native_resolved_fsi_require_restart_metadata_value(metadata, "resume_status", "deferred")
    end
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
then fail closed for public callers. Durable schema-v3 checkpoints are
reserved for qualified internal split-run resume runners; default package APIs
and CLI paths do not expose production resume.
"""
function native_resolved_fsi_resume_partitioned_production(path::AbstractString; kwargs...)
    metadata = native_resolved_fsi_read_restart_metadata(path)
    provenance = String(metadata["restart_provenance"])
    restart_schema_version = get(
        metadata,
        "restart_schema_version",
        NATIVE_RESOLVED_FSI_RESTART_SCHEMA_AUDIT_METADATA_VERSION,
    )
    throw(ArgumentError(
        "native resolved-FSI public/default process resume from restart metadata is unsupported for provenance " *
        "$(repr(provenance)) and restart_schema_version $(restart_schema_version); durable schema-v3 checkpoints " *
        "are limited to qualified internal split-run resume runners and no default CLI resume command is exposed",
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

function native_resolved_fsi_require_restart_metadata_nonnegative_integer(
    metadata::Dict{String,Any},
    key::String;
    context::String = "native resolved-FSI restart metadata",
)
    haskey(metadata, key) || throw(ArgumentError("$(context) requires '$(key)'"))
    value = metadata[key]
    value isa Integer && !(value isa Bool) || throw(ArgumentError("$(context) '$(key)' must be an integer"))
    value >= 0 || throw(ArgumentError("$(context) '$(key)' must be nonnegative"))
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

function native_resolved_fsi_restart_schema_version(metadata::Dict{String,Any})
    haskey(metadata, "restart_schema_version") || return NATIVE_RESOLVED_FSI_RESTART_SCHEMA_AUDIT_METADATA_VERSION
    version = native_resolved_fsi_require_restart_metadata_positive_integer(metadata, "restart_schema_version")
    version in (
        NATIVE_RESOLVED_FSI_RESTART_SCHEMA_AUDIT_METADATA_VERSION,
        NATIVE_RESOLVED_FSI_RESTART_SCHEMA_CHECKPOINT_MANIFEST_VERSION,
        NATIVE_RESOLVED_FSI_RESTART_SCHEMA_DURABLE_CHECKPOINT_VERSION,
    ) || throw(ArgumentError(
        "native resolved-FSI restart metadata restart_schema_version must be 1, 2, or 3; got $(repr(version))",
    ))
    return version
end

function native_resolved_fsi_validate_restart_schema_v3_resume_scope(
    metadata::Dict{String,Any};
    context::String = "native resolved-FSI restart metadata",
)
    native_resolved_fsi_require_restart_metadata_value(
        metadata,
        "resume_scope",
        NATIVE_RESOLVED_FSI_RESTART_INTERNAL_RESUME_SCOPE;
        context=context,
    )
    native_resolved_fsi_require_restart_metadata_bool(
        metadata,
        "internal_split_run_resume_supported",
        true;
        context=context,
    )
    native_resolved_fsi_require_restart_metadata_value(
        metadata,
        "internal_split_run_resume_status",
        NATIVE_RESOLVED_FSI_RESTART_INTERNAL_RESUME_STATUS;
        context=context,
    )
    native_resolved_fsi_require_restart_metadata_bool(
        metadata,
        "public_resume_supported",
        false;
        context=context,
    )
    native_resolved_fsi_require_restart_metadata_value(
        metadata,
        "public_resume_status",
        NATIVE_RESOLVED_FSI_RESTART_PUBLIC_RESUME_STATUS;
        context=context,
    )
    native_resolved_fsi_require_restart_metadata_bool(
        metadata,
        "default_process_resume_supported",
        false;
        context=context,
    )
    native_resolved_fsi_require_restart_metadata_value(
        metadata,
        "default_process_resume_status",
        NATIVE_RESOLVED_FSI_RESTART_DEFAULT_PROCESS_RESUME_STATUS;
        context=context,
    )

    resume_run_role = native_resolved_fsi_require_restart_metadata_string(
        metadata,
        "resume_run_role";
        context=context,
    )
    resume_run_role in ("checkpoint_writer", "forked_internal_resume") || throw(ArgumentError(
        "$(context) resume_run_role must be \"checkpoint_writer\" or \"forked_internal_resume\"; got " *
        repr(resume_run_role),
    ))
    output_ownership_policy = native_resolved_fsi_require_restart_metadata_string(
        metadata,
        "output_ownership_policy";
        context=context,
    )
    output_ownership_policy in (
        "current_run_owns_all_listed_outputs",
        "forked_resume_references_parent_completed_outputs_and_owns_only_current_resume_output_root",
    ) || throw(ArgumentError(
        "$(context) output_ownership_policy is not a recognized internal split-run ownership policy",
    ))
    parent_restart_metadata_json = get(metadata, "parent_restart_metadata_json", nothing)
    if resume_run_role == "checkpoint_writer"
        parent_restart_metadata_json === nothing || throw(ArgumentError(
            "$(context) checkpoint_writer must not declare parent_restart_metadata_json",
        ))
        output_ownership_policy == "current_run_owns_all_listed_outputs" || throw(ArgumentError(
            "$(context) checkpoint_writer must own all listed outputs",
        ))
    else
        parent_restart_metadata_json isa AbstractString && !isempty(parent_restart_metadata_json) || throw(ArgumentError(
            "$(context) forked_internal_resume requires parent_restart_metadata_json",
        ))
        forked_output_ownership_policy =
            "forked_resume_references_parent_completed_outputs_and_owns_only_current_resume_output_root"
        if output_ownership_policy != forked_output_ownership_policy
            throw(ArgumentError(
                "$(context) forked_internal_resume must distinguish parent outputs from the current resume output root",
            ))
        end
    end
    return nothing
end

function native_resolved_fsi_validate_restart_schema_contract(
    metadata::Dict{String,Any},
    restart_schema_version::Int,
    metadata_dir::String,
)
    if restart_schema_version == NATIVE_RESOLVED_FSI_RESTART_SCHEMA_AUDIT_METADATA_VERSION
        if haskey(metadata, "restart_schema_status")
            native_resolved_fsi_require_restart_metadata_value(
                metadata,
                "restart_schema_status",
                "schema_v1_audit_metadata_only",
            )
        end
        if haskey(metadata, "checkpoint_schema_status")
            native_resolved_fsi_require_restart_metadata_value(
                metadata,
                "checkpoint_schema_status",
                "not_persisted_solver_checkpoint",
            )
        end
        if haskey(metadata, "checkpoint_manifest")
            checkpoint_manifest = native_resolved_fsi_require_restart_metadata_vector(metadata, "checkpoint_manifest")
            isempty(checkpoint_manifest) || throw(ArgumentError(
                "native resolved-FSI restart metadata schema v1 checkpoint_manifest must be empty",
            ))
        end
        return nothing
    end

    if restart_schema_version == NATIVE_RESOLVED_FSI_RESTART_SCHEMA_CHECKPOINT_MANIFEST_VERSION
        native_resolved_fsi_require_restart_metadata_value(
            metadata,
            "restart_schema_status",
            "schema_v2_checkpoint_manifest",
        )
        native_resolved_fsi_require_restart_metadata_value(
            metadata,
            "checkpoint_schema_status",
            "checkpoint_manifest_present_resume_not_implemented",
        )
    else
        native_resolved_fsi_require_restart_metadata_value(
            metadata,
            "restart_schema_status",
            "schema_v3_durable_checkpoint",
        )
        native_resolved_fsi_require_restart_metadata_value(
            metadata,
            "checkpoint_schema_status",
            "durable_checkpoint_ready",
        )
    end
    checkpoint_manifest = native_resolved_fsi_require_restart_metadata_vector(metadata, "checkpoint_manifest")
    isempty(checkpoint_manifest) && throw(ArgumentError(
        "native resolved-FSI restart metadata schema $(restart_schema_version) requires a non-empty checkpoint_manifest",
    ))
    required_checkpoint_roles =
        restart_schema_version == NATIVE_RESOLVED_FSI_RESTART_SCHEMA_DURABLE_CHECKPOINT_VERSION ?
        NATIVE_RESOLVED_FSI_RESTART_SCHEMA_V3_REQUIRED_CHECKPOINT_ROLES :
        NATIVE_RESOLVED_FSI_RESTART_SCHEMA_V2_REQUIRED_CHECKPOINT_ROLES
    required_roles = Set(required_checkpoint_roles)
    observed_roles = Set{String}()
    for (index, checkpoint_entry) in enumerate(checkpoint_manifest)
        context = "native resolved-FSI restart metadata checkpoint_manifest[$(index)]"
        checkpoint_entry isa Dict{String,Any} ||
            throw(ArgumentError("$(context) must be a mapping"))
        role = native_resolved_fsi_require_restart_metadata_string(checkpoint_entry, "role"; context=context)
        role in required_roles || throw(ArgumentError(
            "$(context) has unsupported checkpoint role $(repr(role)); expected one of " *
            "$(join(required_checkpoint_roles, ", "))",
        ))
        role in observed_roles && throw(ArgumentError(
            "$(context) duplicates checkpoint role $(repr(role))",
        ))
        push!(observed_roles, role)
        checkpoint_path = native_resolved_fsi_require_restart_metadata_string(checkpoint_entry, "path"; context=context)
        sha256 = native_resolved_fsi_require_restart_metadata_string(checkpoint_entry, "sha256"; context=context)
        length(sha256) == 64 || throw(ArgumentError("$(context) 'sha256' must be a 64-character hex digest"))
        all(character -> ('0' <= character <= '9') || ('a' <= character <= 'f'), sha256) ||
            throw(ArgumentError("$(context) 'sha256' must be lowercase hexadecimal"))
        byte_size = native_resolved_fsi_require_restart_metadata_positive_integer(
            checkpoint_entry,
            "byte_size";
            context=context,
        )
        resolved_path = native_resolved_fsi_restart_metadata_confined_checkpoint_path(
            checkpoint_path,
            metadata_dir,
            context,
        )
        isfile(resolved_path) || throw(ArgumentError(
            "$(context) references a missing checkpoint file: $(checkpoint_path)",
        ))
        filesize(resolved_path) == byte_size || throw(ArgumentError(
            "$(context) byte_size does not match checkpoint file size",
        ))
        sha256_file(resolved_path) == sha256 || throw(ArgumentError(
            "$(context) sha256 does not match checkpoint file digest",
        ))
    end
    missing_roles = sort!(collect(setdiff(required_roles, observed_roles)))
    isempty(missing_roles) || throw(ArgumentError(
        "native resolved-FSI restart metadata schema $(restart_schema_version) checkpoint_manifest is missing required role(s): " *
        join(missing_roles, ", "),
    ))
    if restart_schema_version == NATIVE_RESOLVED_FSI_RESTART_SCHEMA_DURABLE_CHECKPOINT_VERSION
        native_resolved_fsi_validate_restart_durable_checkpoint_sidecars(metadata, metadata_dir, checkpoint_manifest)
    end
    return nothing
end

function native_resolved_fsi_restart_checkpoint_entries_by_role(checkpoint_manifest, metadata_dir::String)
    entries = Dict{String,NamedTuple}()
    for checkpoint_entry in checkpoint_manifest
        role = String(checkpoint_entry["role"])
        relative_path = String(checkpoint_entry["path"])
        resolved_path = native_resolved_fsi_restart_metadata_confined_checkpoint_path(
            relative_path,
            metadata_dir,
            "native resolved-FSI restart metadata checkpoint_manifest role $(repr(role))",
        )
        entries[role] = (
            path=resolved_path,
            relative_path=relative_path,
            sha256=String(checkpoint_entry["sha256"]),
            byte_size=Int(checkpoint_entry["byte_size"]),
        )
    end
    return entries
end

function native_resolved_fsi_load_restart_checkpoint_sidecars(metadata_dir::String, checkpoint_manifest)
    entries = native_resolved_fsi_restart_checkpoint_entries_by_role(checkpoint_manifest, metadata_dir)
    sidecars = Dict{String,Dict{String,Any}}()
    for role in NATIVE_RESOLVED_FSI_RESTART_SCHEMA_V3_REQUIRED_CHECKPOINT_ROLES
        haskey(entries, role) || throw(ArgumentError(
            "native resolved-FSI durable checkpoint is missing sidecar role $(repr(role))",
        ))
        loaded = load_yaml_file(entries[role].path)
        sidecar = native_resolved_fsi_normalize_restart_metadata(loaded)
        sidecars[role] = sidecar
    end
    return sidecars
end

function native_resolved_fsi_restart_metadata_mesh_resolution(
    metadata::Dict{String,Any};
    context::String = "native resolved-FSI restart metadata",
)
    resolution = native_resolved_fsi_require_restart_metadata_mapping(metadata, "mesh_resolution"; context=context)
    return NativeResolvedFSIMeshResolution(
        axial=native_resolved_fsi_require_restart_metadata_positive_integer(
            resolution,
            "axial";
            context="$(context) mesh_resolution",
        ),
        radial=native_resolved_fsi_require_restart_metadata_positive_integer(
            resolution,
            "radial";
            context="$(context) mesh_resolution",
        ),
        angular=native_resolved_fsi_require_restart_metadata_positive_integer(
            resolution,
            "angular";
            context="$(context) mesh_resolution",
        ),
    )
end

function native_resolved_fsi_require_restart_sidecar_schema(
    sidecar::Dict{String,Any},
    representation::String,
    context::String,
)
    schema_version =
        native_resolved_fsi_require_restart_metadata_positive_integer(sidecar, "schema_version"; context=context)
    schema_version == 1 || throw(ArgumentError("$(context) requires schema_version == 1"))
    native_resolved_fsi_require_restart_metadata_value(sidecar, "representation", representation; context=context)
    return sidecar
end

function native_resolved_fsi_restart_resolved_existing_file(
    path::String,
    metadata_dir::String,
    context::String,
)
    resolved_path = native_resolved_fsi_restart_metadata_resolved_path(path, metadata_dir, isfile)
    isempty(resolved_path) && throw(ArgumentError("$(context) references a missing file: $(path)"))
    return resolved_path
end

function native_resolved_fsi_require_restart_sidecar_file_digest(
    sidecar::Dict{String,Any},
    path_key::String,
    digest_key::String,
    metadata_dir::String,
    context::String,
)
    path = native_resolved_fsi_require_restart_metadata_string(sidecar, path_key; context=context)
    digest = native_resolved_fsi_require_restart_metadata_string(sidecar, digest_key; context=context)
    resolved_path = native_resolved_fsi_restart_resolved_existing_file(path, metadata_dir, "$(context) '$(path_key)'")
    sha256_file(resolved_path) == digest || throw(ArgumentError(
        "$(context) '$(digest_key)' does not match file digest for $(path_key)",
    ))
    return resolved_path
end

function native_resolved_fsi_validate_restart_wall_sidecar(
    metadata::Dict{String,Any},
    wall_state::Dict{String,Any},
)
    context = "native resolved-FSI durable checkpoint wall_state"
    native_resolved_fsi_require_restart_sidecar_schema(wall_state, "durable_reduced_wall_state", context)
    wall_axial_coordinates_cm = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        wall_state,
        "wall_axial_coordinates_cm";
        context=context,
    )
    reference_radii_cm = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        wall_state,
        "reference_radii_cm";
        context=context,
    )
    wall_displacement_cm = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        wall_state,
        "wall_displacement_cm";
        context=context,
    )
    wall_velocity_cm_s = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        wall_state,
        "wall_velocity_cm_s";
        context=context,
    )
    current_radii_cm = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        wall_state,
        "current_radii_cm";
        context=context,
    )
    wall_pressure_dyn_cm2 = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        wall_state,
        "wall_pressure_dyn_cm2";
        context=context,
    )
    vector_lengths = (
        length(wall_axial_coordinates_cm),
        length(reference_radii_cm),
        length(wall_displacement_cm),
        length(wall_velocity_cm_s),
        length(current_radii_cm),
        length(wall_pressure_dyn_cm2),
    )
    all(==(first(vector_lengths)), vector_lengths) ||
        throw(ArgumentError("$(context) wall arrays must have matching lengths"))
    all(radius -> radius > 0.0, current_radii_cm) ||
        throw(ArgumentError("$(context) current_radii_cm entries must be positive"))
    maximum(abs, current_radii_cm .- (reference_radii_cm .+ wall_displacement_cm)) <= 1.0e-12 ||
        throw(ArgumentError("$(context) current_radii_cm must equal reference_radii_cm plus wall_displacement_cm"))
    !isempty(wall_displacement_cm) &&
        iszero(wall_displacement_cm[begin]) &&
        iszero(wall_displacement_cm[end]) &&
        iszero(wall_velocity_cm_s[begin]) &&
        iszero(wall_velocity_cm_s[end]) ||
        throw(ArgumentError("$(context) wall displacement and velocity endpoints must be clamped"))
    native_resolved_fsi_require_restart_metadata_value(
        wall_state,
        "pressure_gauge_convention",
        "outlet_gauge_normalization_export_only_not_membrane_forcing";
        context=context,
    )
    if haskey(metadata, "current_wall_displacement_cm")
        metadata_displacement = native_resolved_fsi_require_restart_metadata_finite_real_vector(
            metadata,
            "current_wall_displacement_cm",
        )
        metadata_displacement == wall_displacement_cm ||
            throw(ArgumentError("$(context) wall displacement does not match restart metadata"))
    end
    return nothing
end

function native_resolved_fsi_validate_restart_mesh_sidecar(
    metadata::Dict{String,Any},
    mesh_identity::Dict{String,Any},
)
    context = "native resolved-FSI durable checkpoint mesh_identity"
    native_resolved_fsi_require_restart_sidecar_schema(mesh_identity, "native_mesh_identity", context)
    case_id = native_resolved_fsi_require_restart_metadata_string(metadata, "case_id")
    resolution = native_resolved_fsi_restart_metadata_mesh_resolution(metadata)
    mesh = native_resolved_fsi_mesh(Symbol(case_id), resolution)
    expected_identity = native_resolved_fsi_checkpoint_mesh_identity(mesh)
    for key in (
        "case_id",
        "severity_percent",
        "node_count",
        "tetrahedron_count",
        "reference_coordinates_sha256",
        "topology_sha256",
        "boundary_tags_sha256",
        "axial_coordinates_sha256",
        "reference_radii_sha256",
    )
        haskey(mesh_identity, key) || throw(ArgumentError("$(context) requires '$(key)'"))
        mesh_identity[key] == expected_identity[key] || throw(ArgumentError(
            "$(context) '$(key)' does not match regenerated native mesh identity",
        ))
    end
    native_resolved_fsi_require_restart_metadata_finite_real(
        mesh_identity,
        "minimum_signed_tetra_volume6";
        context=context,
    ) > 0.0 || throw(ArgumentError("$(context) minimum_signed_tetra_volume6 must be positive"))
    return nothing
end

function native_resolved_fsi_validate_restart_fluid_sidecar(
    fluid_state::Dict{String,Any},
    metadata_dir::String,
)
    context = "native resolved-FSI durable checkpoint fluid_state"
    native_resolved_fsi_require_restart_sidecar_schema(fluid_state, "gridap_free_dof_checkpoint", context)
    native_resolved_fsi_require_restart_metadata_bool(fluid_state, "restartable_fe_state", true; context=context)
    velocity_dofs =
        native_resolved_fsi_require_restart_metadata_positive_integer(fluid_state, "velocity_dofs"; context=context)
    pressure_dofs =
        native_resolved_fsi_require_restart_metadata_positive_integer(fluid_state, "pressure_dofs"; context=context)
    velocity_free_dof_values = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        fluid_state,
        "velocity_free_dof_values";
        context=context,
    )
    pressure_free_dof_values = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        fluid_state,
        "pressure_free_dof_values";
        context=context,
    )
    previous_velocity_free_dof_values = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        fluid_state,
        "previous_velocity_free_dof_values";
        context=context,
    )
    length(velocity_free_dof_values) == velocity_dofs ||
        throw(ArgumentError("$(context) velocity_free_dof_values length must match velocity_dofs"))
    length(previous_velocity_free_dof_values) == velocity_dofs ||
        throw(ArgumentError("$(context) previous_velocity_free_dof_values length must match velocity_dofs"))
    length(pressure_free_dof_values) == pressure_dofs ||
        throw(ArgumentError("$(context) pressure_free_dof_values length must match pressure_dofs"))
    native_resolved_fsi_require_restart_metadata_value(
        fluid_state,
        "pressure_gauge_convention",
        "outlet_gauge_normalization_export_only_not_membrane_forcing";
        context=context,
    )
    for (path_key, digest_key) in (
        ("velocity_h5", "velocity_h5_sha256"),
        ("pressure_h5", "pressure_h5_sha256"),
        ("displacement_h5", "displacement_h5_sha256"),
    )
        native_resolved_fsi_require_restart_sidecar_file_digest(
            fluid_state,
            path_key,
            digest_key,
            metadata_dir,
            context,
        )
    end
    return nothing
end

function native_resolved_fsi_validate_restart_coupling_sidecar(
    metadata::Dict{String,Any},
    coupling_state::Dict{String,Any},
)
    context = "native resolved-FSI durable checkpoint coupling_state"
    native_resolved_fsi_require_restart_sidecar_schema(
        coupling_state,
        "partitioned_coupling_state_and_cursor",
        context,
    )
    current_snapshot_index = native_resolved_fsi_require_restart_metadata_positive_integer(
        coupling_state,
        "current_snapshot_index";
        context=context,
    )
    metadata_snapshot_index =
        native_resolved_fsi_require_restart_metadata_positive_integer(metadata, "current_snapshot_index")
    current_snapshot_index == metadata_snapshot_index ||
        throw(ArgumentError("$(context) current_snapshot_index must match restart metadata"))
    completed_snapshot_count = native_resolved_fsi_require_restart_metadata_positive_integer(
        coupling_state,
        "completed_snapshot_count";
        context=context,
    )
    completed_snapshot_count == current_snapshot_index ||
        throw(ArgumentError("$(context) completed_snapshot_count must match current_snapshot_index"))
    snapshot_times_s = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        coupling_state,
        "snapshot_times_s";
        context=context,
    )
    metadata_snapshot_times_s = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        metadata,
        "snapshot_times_s",
    )
    snapshot_times_s == metadata_snapshot_times_s ||
        throw(ArgumentError("$(context) snapshot_times_s must match restart metadata"))
    current_snapshot_index <= length(snapshot_times_s) ||
        throw(ArgumentError("$(context) current_snapshot_index exceeds snapshot schedule length"))
    expected_next = current_snapshot_index < length(snapshot_times_s) ? current_snapshot_index + 1 : nothing
    get(coupling_state, "next_pending_snapshot_index", nothing) == expected_next ||
        throw(ArgumentError("$(context) next_pending_snapshot_index is inconsistent with current_snapshot_index"))
    for key in ("dt_s", "tfinal_s", "time_atol", "coupling_tolerance", "coupling_under_relaxation")
        native_resolved_fsi_require_restart_metadata_finite_real(coupling_state, key; context=context)
    end
    for key in ("coupling_iteration_count", "max_coupling_iterations_used")
        native_resolved_fsi_require_restart_metadata_positive_integer(coupling_state, key; context=context)
    end
    native_resolved_fsi_require_restart_metadata_nonnegative_integer(
        coupling_state,
        "pressure_projection_fallback_count";
        context=context,
    )
    if haskey(coupling_state, "sampling_fallback_count")
        native_resolved_fsi_require_restart_metadata_nonnegative_integer(
            coupling_state,
            "sampling_fallback_count";
            context=context,
        )
    end
    native_resolved_fsi_require_restart_metadata_string(coupling_state, "fluid_wall_boundary_mode"; context=context)
    native_resolved_fsi_require_restart_metadata_vector(coupling_state, "coupling_residual_history")
    return nothing
end

function native_resolved_fsi_validate_restart_output_linkage_sidecar(
    metadata::Dict{String,Any},
    output_linkage::Dict{String,Any},
    metadata_dir::String,
)
    context = "native resolved-FSI durable checkpoint output_linkage"
    native_resolved_fsi_require_restart_sidecar_schema(output_linkage, "sidecar_and_output_linkage", context)
    native_resolved_fsi_require_restart_sidecar_file_digest(
        output_linkage,
        "snapshot_manifest_csv",
        "snapshot_manifest_sha256",
        metadata_dir,
        context,
    )
    native_resolved_fsi_require_restart_sidecar_file_digest(
        output_linkage,
        "diagnostics_csv",
        "diagnostics_sha256",
        metadata_dir,
        context,
    )
    snapshot_outputs = native_resolved_fsi_require_restart_metadata_vector(output_linkage, "snapshot_outputs")
    metadata_snapshot_outputs = native_resolved_fsi_require_restart_metadata_vector(metadata, "snapshot_outputs")
    length(snapshot_outputs) == length(metadata_snapshot_outputs) || throw(ArgumentError(
        "$(context) snapshot_outputs length must match restart metadata",
    ))
    for (index, snapshot_output) in enumerate(snapshot_outputs)
        snapshot_output isa Dict{String,Any} ||
            throw(ArgumentError("$(context) snapshot_outputs[$(index)] must be a mapping"))
        snapshot_context = "$(context) snapshot_outputs[$(index)]"
        native_resolved_fsi_require_restart_metadata_string(snapshot_output, "output_dir"; context=snapshot_context)
        for key in ("velocity_xdmf", "pressure_xdmf", "displacement_xdmf")
            path = native_resolved_fsi_require_restart_metadata_string(snapshot_output, key; context=snapshot_context)
            native_resolved_fsi_restart_resolved_existing_file(path, metadata_dir, "$(snapshot_context) '$(key)'")
        end
        for (path_key, digest_key) in (
            ("velocity_h5", "velocity_h5_sha256"),
            ("pressure_h5", "pressure_h5_sha256"),
            ("displacement_h5", "displacement_h5_sha256"),
        )
            if haskey(snapshot_output, path_key)
                native_resolved_fsi_require_restart_sidecar_file_digest(
                    snapshot_output,
                    path_key,
                    digest_key,
                    metadata_dir,
                    snapshot_context,
                )
            end
        end
    end
    return nothing
end

function native_resolved_fsi_validate_restart_durable_checkpoint_sidecars(
    metadata::Dict{String,Any},
    metadata_dir::String,
    checkpoint_manifest,
)
    sidecars = native_resolved_fsi_load_restart_checkpoint_sidecars(metadata_dir, checkpoint_manifest)
    native_resolved_fsi_validate_restart_wall_sidecar(metadata, sidecars["wall_state"])
    native_resolved_fsi_validate_restart_mesh_sidecar(metadata, sidecars["mesh_identity"])
    native_resolved_fsi_validate_restart_fluid_sidecar(sidecars["fluid_state"], metadata_dir)
    native_resolved_fsi_validate_restart_coupling_sidecar(metadata, sidecars["coupling_state"])
    native_resolved_fsi_validate_restart_output_linkage_sidecar(metadata, sidecars["output_linkage"], metadata_dir)
    return nothing
end

function native_resolved_fsi_restart_csv_data_lines(path::String, metadata_dir::String, label::String)
    resolved_path = native_resolved_fsi_restart_resolved_existing_file(path, metadata_dir, label)
    lines = readlines(resolved_path)
    length(lines) >= 2 || throw(ArgumentError("$(label) must include a header and at least one data row"))
    return lines[2:end]
end

function native_resolved_fsi_restart_metadata_required_snapshot_index(metadata::Dict{String,Any})
    current_snapshot_index =
        native_resolved_fsi_require_restart_metadata_positive_integer(metadata, "current_snapshot_index")
    snapshot_outputs = native_resolved_fsi_require_restart_metadata_vector(metadata, "snapshot_outputs")
    current_snapshot_index == length(snapshot_outputs) || throw(ArgumentError(
        "native resolved-FSI restart metadata current_snapshot_index must match snapshot_outputs length",
    ))
    snapshot_times_s = native_resolved_fsi_require_restart_metadata_finite_real_vector(metadata, "snapshot_times_s")
    current_snapshot_index < length(snapshot_times_s) || throw(ArgumentError(
        "native resolved-FSI restart metadata has no pending snapshots to resume",
    ))
    next_pending_snapshot_index = native_resolved_fsi_require_restart_metadata_positive_integer(
        metadata,
        "next_pending_snapshot_index",
    )
    next_pending_snapshot_index == current_snapshot_index + 1 || throw(ArgumentError(
        "native resolved-FSI restart metadata next_pending_snapshot_index must equal current_snapshot_index + 1",
    ))
    return current_snapshot_index, next_pending_snapshot_index
end

function native_resolved_fsi_restart_require_matching_spec(
    metadata::Dict{String,Any},
    spec;
    context::String = "native resolved-FSI internal resume",
)
    case_id = native_resolved_fsi_require_restart_metadata_string(metadata, "case_id"; context=context)
    string(spec.case_spec.case_id) == case_id || throw(ArgumentError(
        "$(context) case_id does not match restart metadata",
    ))
    metadata_resolution = native_resolved_fsi_restart_metadata_mesh_resolution(metadata; context=context)
    metadata_resolution == spec.resolution || throw(ArgumentError(
        "$(context) mesh_resolution does not match restart metadata",
    ))
    for key in ("dt_s", "tfinal_s", "time_atol", "coupling_tolerance", "coupling_under_relaxation")
        metadata_value = native_resolved_fsi_require_restart_metadata_finite_real(metadata, key; context=context)
        spec_value = Float64(getfield(spec, Symbol(key)))
        isapprox(metadata_value, spec_value; atol=0.0, rtol=1.0e-12) || throw(ArgumentError(
            "$(context) $(key) does not match restart metadata",
        ))
    end
    snapshot_times_s = native_resolved_fsi_require_restart_metadata_finite_real_vector(
        metadata,
        "snapshot_times_s";
        context=context,
    )
    snapshot_times_s == Float64[Float64(value) for value in spec.snapshot_times_s] || throw(ArgumentError(
        "$(context) snapshot_times_s does not match restart metadata",
    ))
    metadata_coupling_iteration_count = native_resolved_fsi_require_restart_metadata_positive_integer(
        metadata,
        "coupling_iteration_count";
        context=context,
    )
    metadata_coupling_iteration_count == spec.coupling_iteration_count || throw(ArgumentError(
        "$(context) coupling_iteration_count does not match restart metadata",
    ))
    boundary_mode =
        native_resolved_fsi_require_restart_metadata_string(metadata, "boundary_mode"; context=context)
    Symbol(boundary_mode) === spec.inlet_outlet_boundary_mode || throw(ArgumentError(
        "$(context) boundary_mode does not match restart metadata",
    ))
    if spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        inlet_umax_cm_s =
            native_resolved_fsi_require_restart_metadata_finite_real(metadata, "inlet_umax_cm_s"; context=context)
        isapprox(inlet_umax_cm_s, spec.inlet_umax_cm_s; atol=0.0, rtol=1.0e-12) || throw(ArgumentError(
            "$(context) inlet_umax_cm_s does not match restart metadata",
        ))
    end
    metadata_output_dir =
        native_resolved_fsi_require_restart_metadata_string(metadata, "production_output_dir"; context=context)
    resumed_output_dir = default_native_resolved_fsi_partitioned_production_output_dir(spec)
    production_canonical(path) = normpath(abspath(path))
    production_canonical(resumed_output_dir) != production_canonical(metadata_output_dir) || throw(ArgumentError(
        "$(context) requires a forked output_root; resumed production output_dir must not overwrite the parent checkpoint run",
    ))
    return nothing
end

function native_resolved_fsi_restart_bool(sidecar::Dict{String,Any}, key::String, context::String)
    haskey(sidecar, key) || throw(ArgumentError("$(context) requires '$(key)'"))
    value = sidecar[key]
    value isa Bool || throw(ArgumentError("$(context) '$(key)' must be a boolean"))
    return value
end

function native_resolved_fsi_restart_coupling_history(coupling_state::Dict{String,Any})
    context = "native resolved-FSI durable checkpoint coupling_state"
    rows = native_resolved_fsi_require_restart_metadata_vector(coupling_state, "coupling_residual_history")
    history = NamedTuple[]
    for (index, row) in enumerate(rows)
        row isa Dict{String,Any} || throw(ArgumentError(
            "$(context) coupling_residual_history[$(index)] must be a mapping",
        ))
        row_context = "$(context) coupling_residual_history[$(index)]"
        push!(history, (
            time_step_index=native_resolved_fsi_require_restart_metadata_positive_integer(
                row,
                "time_step_index";
                context=row_context,
            ),
            coupling_iteration=native_resolved_fsi_require_restart_metadata_positive_integer(
                row,
                "coupling_iteration";
                context=row_context,
            ),
            time_start_s=native_resolved_fsi_require_restart_metadata_finite_real(row, "time_start_s"; context=row_context),
            time_end_s=native_resolved_fsi_require_restart_metadata_finite_real(row, "time_end_s"; context=row_context),
            displacement_residual_cm=native_resolved_fsi_require_restart_metadata_finite_real(
                row,
                "displacement_residual_cm";
                context=row_context,
            ),
            coupling_tolerance_cm=native_resolved_fsi_require_restart_metadata_finite_real(
                row,
                "coupling_tolerance_cm";
                context=row_context,
            ),
            under_relaxation=native_resolved_fsi_require_restart_metadata_finite_real(
                row,
                "under_relaxation";
                context=row_context,
            ),
            converged=native_resolved_fsi_restart_bool(row, "converged", row_context),
            fluid_wall_boundary_mode=native_resolved_fsi_require_restart_metadata_string(
                row,
                "fluid_wall_boundary_mode";
                context=row_context,
            ),
            inlet_outlet_boundary_mode=get(row, "inlet_outlet_boundary_mode", ""),
        ))
    end
    return history
end

function native_resolved_fsi_restart_solver_state(
    metadata::Dict{String,Any},
    sidecars::Dict{String,Dict{String,Any}},
)
    wall_state = sidecars["wall_state"]
    fluid_state = sidecars["fluid_state"]
    coupling_state = sidecars["coupling_state"]
    return (
        current_saved_time_s=native_resolved_fsi_require_restart_metadata_finite_real(
            coupling_state,
            "current_saved_time_s";
            context="native resolved-FSI durable checkpoint coupling_state",
        ),
        current_time_step_count=native_resolved_fsi_require_restart_metadata_positive_integer(
            coupling_state,
            "current_time_step_count";
            context="native resolved-FSI durable checkpoint coupling_state",
        ),
        wall_axial_coordinates_cm=native_resolved_fsi_require_restart_metadata_finite_real_vector(
            wall_state,
            "wall_axial_coordinates_cm";
            context="native resolved-FSI durable checkpoint wall_state",
        ),
        wall_displacement_cm=native_resolved_fsi_require_restart_metadata_finite_real_vector(
            wall_state,
            "wall_displacement_cm";
            context="native resolved-FSI durable checkpoint wall_state",
        ),
        wall_velocity_cm_s=native_resolved_fsi_require_restart_metadata_finite_real_vector(
            wall_state,
            "wall_velocity_cm_s";
            context="native resolved-FSI durable checkpoint wall_state",
        ),
        current_radii_cm=native_resolved_fsi_require_restart_metadata_finite_real_vector(
            wall_state,
            "current_radii_cm";
            context="native resolved-FSI durable checkpoint wall_state",
        ),
        wall_pressure_dyn_cm2=native_resolved_fsi_require_restart_metadata_finite_real_vector(
            wall_state,
            "wall_pressure_dyn_cm2";
            context="native resolved-FSI durable checkpoint wall_state",
        ),
        velocity_free_dof_values=native_resolved_fsi_require_restart_metadata_finite_real_vector(
            fluid_state,
            "velocity_free_dof_values";
            context="native resolved-FSI durable checkpoint fluid_state",
        ),
        max_picard_iterations_used=native_resolved_fsi_require_restart_metadata_positive_integer(
            fluid_state,
            "max_picard_iterations_used";
            context="native resolved-FSI durable checkpoint fluid_state",
        ),
        final_picard_update_norm=native_resolved_fsi_require_restart_metadata_finite_real(
            fluid_state,
            "final_picard_update_norm";
            context="native resolved-FSI durable checkpoint fluid_state",
        ),
        picard_converged=native_resolved_fsi_restart_bool(
            fluid_state,
            "picard_converged",
            "native resolved-FSI durable checkpoint fluid_state",
        ),
        pressure_projection_fallback_count=native_resolved_fsi_require_restart_metadata_nonnegative_integer(
            coupling_state,
            "pressure_projection_fallback_count";
            context="native resolved-FSI durable checkpoint coupling_state",
        ),
        minimum_signed_tetra_volume6=native_resolved_fsi_require_restart_metadata_finite_real(
            coupling_state,
            "minimum_signed_tetra_volume6";
            context="native resolved-FSI durable checkpoint coupling_state",
        ),
        max_coupling_iterations_used=native_resolved_fsi_require_restart_metadata_positive_integer(
            coupling_state,
            "max_coupling_iterations_used";
            context="native resolved-FSI durable checkpoint coupling_state",
        ),
        final_coupling_displacement_residual_cm=native_resolved_fsi_require_restart_metadata_finite_real(
            coupling_state,
            "final_coupling_displacement_residual_cm";
            context="native resolved-FSI durable checkpoint coupling_state",
        ),
        coupling_converged=native_resolved_fsi_restart_bool(
            coupling_state,
            "coupling_converged",
            "native resolved-FSI durable checkpoint coupling_state",
        ),
        coupling_residual_history=native_resolved_fsi_restart_coupling_history(coupling_state),
        fluid_wall_boundary_mode=native_resolved_fsi_require_restart_metadata_string(
            coupling_state,
            "fluid_wall_boundary_mode";
            context="native resolved-FSI durable checkpoint coupling_state",
        ),
        production_spec_digest=native_resolved_fsi_require_restart_metadata_string(
            metadata,
            "production_spec_digest",
        ),
    )
end

function native_resolved_fsi_restart_resume_context(path::AbstractString, spec)
    metadata_path = String(path)
    metadata = native_resolved_fsi_read_restart_metadata(metadata_path)
    restart_schema_version = native_resolved_fsi_restart_schema_version(metadata)
    restart_schema_version == NATIVE_RESOLVED_FSI_RESTART_SCHEMA_DURABLE_CHECKPOINT_VERSION || throw(ArgumentError(
        "native resolved-FSI internal resume requires schema-v3 durable checkpoint metadata",
    ))
    native_resolved_fsi_restart_require_matching_spec(metadata, spec)
    completed_snapshot_count, next_snapshot_index =
        native_resolved_fsi_restart_metadata_required_snapshot_index(metadata)
    metadata_dir = dirname(metadata_path)
    checkpoint_manifest = native_resolved_fsi_require_restart_metadata_vector(metadata, "checkpoint_manifest")
    sidecars = native_resolved_fsi_load_restart_checkpoint_sidecars(metadata_dir, checkpoint_manifest)
    manifest_csv = native_resolved_fsi_require_restart_metadata_string(metadata, "snapshot_manifest_csv")
    diagnostics_csv = native_resolved_fsi_require_restart_metadata_string(metadata, "diagnostics_csv")
    snapshot_outputs = native_resolved_fsi_require_restart_metadata_vector(metadata, "snapshot_outputs")
    return (
        parent_restart_metadata_json=metadata_path,
        completed_snapshot_count=completed_snapshot_count,
        next_snapshot_index=next_snapshot_index,
        completed_snapshot_outputs=deepcopy(snapshot_outputs),
        completed_manifest_data_lines=native_resolved_fsi_restart_csv_data_lines(
            manifest_csv,
            metadata_dir,
            "native resolved-FSI restart metadata snapshot_manifest_csv",
        ),
        completed_diagnostics_data_lines=native_resolved_fsi_restart_csv_data_lines(
            diagnostics_csv,
            metadata_dir,
            "native resolved-FSI restart metadata diagnostics_csv",
        ),
        solver_state=native_resolved_fsi_restart_solver_state(metadata, sidecars),
        metadata=metadata,
    )
end

const NATIVE_RESOLVED_FSI_RESTART_BOUNDARY_STATUS_KEYS = (
    "inlet_umax_cm_s",
    "boundary_mode",
    "boundary_mode_class",
    "inlet_condition_status",
    "outlet_condition_status",
    "pressure_gauge_status",
    "wall_pressure_projection_status",
    "wall_pressure_forcing_status",
    "pressure_gauge_convention",
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
    if haskey(metadata, "wall_pressure_forcing_status")
        native_resolved_fsi_require_restart_metadata_value(
            metadata,
            "wall_pressure_forcing_status",
            native_resolved_fsi_wall_pressure_forcing_status(mode_symbol);
            context=context,
        )
    end
    if haskey(metadata, "pressure_gauge_convention")
        native_resolved_fsi_require_restart_metadata_value(
            metadata,
            "pressure_gauge_convention",
            "outlet_gauge_normalization_export_only_not_membrane_forcing";
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

function native_resolved_fsi_restart_metadata_candidates(path::String, metadata_dir::String)
    candidates = String[path]
    if !isabspath(path) && !isempty(metadata_dir)
        push!(candidates, joinpath(metadata_dir, path))
    end
    return candidates
end

function native_resolved_fsi_restart_metadata_resolved_path(path::String, metadata_dir::String, predicate)
    for candidate in native_resolved_fsi_restart_metadata_candidates(path, metadata_dir)
        predicate(candidate) && return candidate
    end
    return ""
end

function native_resolved_fsi_restart_metadata_confined_checkpoint_path(
    path::String,
    metadata_dir::String,
    context::String,
)
    isempty(path) && throw(ArgumentError("$(context) 'path' must not be empty"))
    isabspath(path) && throw(ArgumentError("$(context) checkpoint path must be metadata-relative"))
    normalized_path = normpath(path)
    normalized_path == "." && throw(ArgumentError("$(context) checkpoint path must name a file"))
    metadata_root = abspath(metadata_dir)
    resolved_path = abspath(joinpath(metadata_root, normalized_path))
    relative_to_root = relpath(resolved_path, metadata_root)
    if relative_to_root == ".." || startswith(relative_to_root, "../") || startswith(relative_to_root, "..\\")
        throw(ArgumentError("$(context) checkpoint path escapes the restart metadata directory"))
    end
    return resolved_path
end

function native_resolved_fsi_restart_metadata_path_exists(path::String, metadata_dir::String, predicate)
    candidates = native_resolved_fsi_restart_metadata_candidates(path, metadata_dir)
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
