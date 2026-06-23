function run_native_resolved_fsi_web_export(spec::NativeResolvedFSIWebExportSpec)
    validate(spec)
    if isempty(spec.input_production_dir)
        source = NativeResolvedFSIWebExportSnapshotSource(
            "direct",
            spec.target_time,
            spec.velocity_xdmf,
            spec.pressure_xdmf,
            spec.displacement_xdmf,
        )
        bundle = native_resolved_fsi_web_export_load_bundle(spec, source)
        if spec.schema_version == NATIVE_RESOLVED_FSI_WEB_EXPORT_STATIC_SCHEMA_VERSION
            return run_native_resolved_fsi_web_export_v1(spec, bundle)
        end
        return run_native_resolved_fsi_web_export_v2(spec, [(source=source, bundle=bundle)], String[])
    end

    sources, discovery_skips = native_resolved_fsi_web_export_discover_sources(spec)
    selected_sources, selection_skips = native_resolved_fsi_web_export_select_sources(spec, sources)
    isempty(selected_sources) &&
        throw(ArgumentError("native resolved-FSI web export found no snapshots after include/exclude/stride filters"))
    frames = [(source=source, bundle=native_resolved_fsi_web_export_load_bundle(spec, source)) for source in selected_sources]
    return run_native_resolved_fsi_web_export_v2(spec, frames, vcat(discovery_skips, selection_skips))
end

function run_native_resolved_fsi_web_export(
    spec::NativeResolvedFSIWebExportSpec,
    bundle::Resolved3DFieldBundle,
)
    validate(spec)
    if spec.schema_version == NATIVE_RESOLVED_FSI_WEB_EXPORT_STATIC_SCHEMA_VERSION
        return run_native_resolved_fsi_web_export_v1(spec, bundle)
    end
    source = NativeResolvedFSIWebExportSnapshotSource(
        "direct",
        bundle.velocity.metadata.time,
        spec.velocity_xdmf,
        spec.pressure_xdmf,
        spec.displacement_xdmf,
    )
    return run_native_resolved_fsi_web_export_v2(spec, [(source=source, bundle=bundle)], String[])
end

function native_resolved_fsi_web_export_load_bundle(
    spec::NativeResolvedFSIWebExportSpec,
    source::NativeResolvedFSIWebExportSnapshotSource,
)
    case_spec = native_resolved_fsi_case_spec(spec.case_id)
    resolved_case = Resolved3DCaseSpec(
        string(case_spec.case_id),
        case_spec.severity_percent,
        source.velocity_xdmf;
        pressure_xdmf=source.pressure_xdmf,
        displacement_xdmf=source.displacement_xdmf,
        target_time=source.time_s,
        time_atol=spec.time_atol,
    )
    return load_resolved3d_field_bundle(
        resolved_case;
        require_pressure=!spec.allow_velocity_only,
        require_displacement=!spec.allow_velocity_only,
    )
end

function run_native_resolved_fsi_web_export_v1(
    spec::NativeResolvedFSIWebExportSpec,
    bundle::Resolved3DFieldBundle,
)
    mkpath(spec.output_dir)

    geometry_dir = joinpath(spec.output_dir, "geometry")
    snapshot_dir = joinpath(spec.output_dir, "snapshots", "t000")
    sidecar_dir = joinpath(spec.output_dir, "sidecars")
    observation_dir = joinpath(spec.output_dir, "observations")
    mkpath(geometry_dir)
    mkpath(snapshot_dir)
    mkpath(sidecar_dir)
    mkpath(observation_dir)

    velocity_field = bundle.velocity
    coordinates = velocity_field.coordinates
    topology = velocity_field.topology
    velocity = velocity_field.velocity
    pressure = bundle.pressure
    displacement = bundle.displacement

    node_count = size(coordinates, 1)
    native_resolved_fsi_web_export_assert_field_shapes(spec, coordinates, topology, velocity, pressure, displacement)
    surface_triangles = native_resolved_fsi_surface_triangles(topology)

    reference_positions_path = joinpath(geometry_dir, "reference_positions.f32")
    surface_indices_path = joinpath(geometry_dir, "surface_indices.u32")
    velocity_path = joinpath(snapshot_dir, "velocity.f32")
    pressure_path = joinpath(snapshot_dir, "pressure.f32")
    displacement_path = joinpath(snapshot_dir, "displacement.f32")
    derived_path = joinpath(snapshot_dir, "derived.json")

    asset_paths = String[
        write_web_export_binary(
            reference_positions_path,
            web_export_row_major_f32(coordinates);
            overwrite=spec.overwrite,
        ),
        write_web_export_binary(
            surface_indices_path,
            web_export_row_major_zero_based_u32(surface_triangles);
            overwrite=spec.overwrite,
        ),
        write_web_export_binary(
            velocity_path,
            web_export_row_major_f32(velocity);
            overwrite=spec.overwrite,
        ),
    ]

    pressure_asset = nothing
    if pressure !== nothing
        push!(asset_paths, write_web_export_binary(
            pressure_path,
            web_export_vector_f32(pressure);
            overwrite=spec.overwrite,
        ))
        pressure_asset = web_export_asset_descriptor(pressure_path, spec.output_dir)
    end

    displacement_asset = nothing
    if displacement !== nothing
        push!(asset_paths, write_web_export_binary(
            displacement_path,
            web_export_row_major_f32(displacement);
            overwrite=spec.overwrite,
        ))
        displacement_asset = web_export_asset_descriptor(displacement_path, spec.output_dir)
    end

    derived = native_resolved_fsi_web_export_ranges(velocity, pressure, displacement)
    if spec.include_derived
        write_json(derived_path, derived; overwrite=spec.overwrite)
        push!(asset_paths, derived_path)
    end

    tetra_asset = nothing
    if spec.include_tetra_debug
        tetra_path = joinpath(geometry_dir, "tetra_indices.u32")
        push!(asset_paths, write_web_export_binary(
            tetra_path,
            web_export_row_major_zero_based_u32(topology);
            overwrite=spec.overwrite,
        ))
        tetra_asset = web_export_asset_descriptor(tetra_path, spec.output_dir)
    end

    sidecars = native_resolved_fsi_web_export_sidecars(spec, sidecar_dir)
    observations = native_resolved_fsi_web_export_observations(spec, observation_dir)

    manifest = Dict{String,Any}(
        "schema_version" => NATIVE_RESOLVED_FSI_WEB_EXPORT_STATIC_SCHEMA_VERSION,
        "case_id" => string(spec.case_id),
        "case_label" => bundle.case_spec.case_label,
        "severity_percent" => bundle.case_spec.severity,
        "result_class" => "native_resolved_fsi_static_web_export",
        "claim_boundary" => NATIVE_RESOLVED_FSI_WEB_EXPORT_CLAIM_BOUNDARY,
        "coordinate_mode" => string(spec.coordinate_mode),
        "geometry_mode" => string(spec.geometry_mode),
        "units" => native_resolved_fsi_web_export_units(),
        "source" => Dict{String,Any}(
            "velocity_xdmf" => spec.velocity_xdmf,
            "pressure_xdmf" => spec.pressure_xdmf,
            "displacement_xdmf" => spec.displacement_xdmf,
            "target_time_s" => spec.target_time,
            "time_atol_s" => spec.time_atol,
        ),
        "geometry" => Dict{String,Any}(
            "node_count" => node_count,
            "tetrahedron_count" => size(topology, 1),
            "surface_triangle_count" => size(surface_triangles, 1),
            "reference_positions" => web_export_asset_descriptor(reference_positions_path, spec.output_dir),
            "surface_indices" => web_export_asset_descriptor(surface_indices_path, spec.output_dir),
            "tetra_indices_debug" => tetra_asset,
        ),
        "fields" => Dict{String,Any}(
            "velocity" => native_resolved_fsi_web_export_field_descriptor("velocity", 3, "cm/s", velocity_path, spec),
            "pressure" => pressure_asset === nothing ? nothing :
                          native_resolved_fsi_web_export_field_descriptor("pressure", 1, "dyn/cm^2", pressure_path, spec),
            "displacement" => displacement_asset === nothing ? nothing :
                              native_resolved_fsi_web_export_field_descriptor("displacement", 3, "cm", displacement_path, spec),
        ),
        "snapshots" => Any[
            Dict{String,Any}(
                "id" => "t000",
                "time_s" => bundle.velocity.metadata.time,
                "derived" => spec.include_derived ? web_export_asset_descriptor(derived_path, spec.output_dir) : nothing,
                "ranges" => derived,
            ),
        ],
        "sidecars" => sidecars,
        "observations" => observations,
    )

    manifest_path = native_resolved_fsi_web_export_manifest_path(spec)
    write_json(manifest_path, manifest; overwrite=spec.overwrite)
    push!(asset_paths, manifest_path)

    return NativeResolvedFSIWebExportResult(
        spec,
        spec.output_dir,
        manifest_path,
        asset_paths,
        manifest,
        1,
        String[],
        0.0,
    )
end

function run_native_resolved_fsi_web_export_v2(
    spec::NativeResolvedFSIWebExportSpec,
    frames::Vector,
    skipped_snapshots::Vector{String},
)
    mkpath(spec.output_dir)
    geometry_dir = joinpath(spec.output_dir, "geometry")
    snapshot_root = joinpath(spec.output_dir, "snapshots")
    sidecar_dir = joinpath(spec.output_dir, "sidecars")
    observation_dir = joinpath(spec.output_dir, "observations")
    mkpath(geometry_dir)
    mkpath(snapshot_root)
    mkpath(sidecar_dir)
    mkpath(observation_dir)

    first_bundle = frames[1].bundle
    coordinates = first_bundle.velocity.coordinates
    topology = first_bundle.velocity.topology
    surface_triangles = native_resolved_fsi_surface_triangles(topology)
    node_count = size(coordinates, 1)
    reference_positions_path = joinpath(geometry_dir, "reference_positions.f32")
    surface_indices_path = joinpath(geometry_dir, "surface_indices.u32")
    asset_paths = String[
        write_web_export_binary(
            reference_positions_path,
            web_export_row_major_f32(coordinates);
            overwrite=spec.overwrite,
        ),
        write_web_export_binary(
            surface_indices_path,
            web_export_row_major_zero_based_u32(surface_triangles);
            overwrite=spec.overwrite,
        ),
    ]

    snapshot_entries = Any[]
    time_axis = Any[]
    speed_ranges = Any[]
    pressure_ranges = Any[]
    displacement_ranges = Any[]
    has_pressure = false
    has_displacement = false

    for (index, frame) in enumerate(frames)
        frame_id = web_export_frame_id(index)
        bundle = frame.bundle
        native_resolved_fsi_web_export_assert_compatible_geometry(coordinates, topology, bundle)
        velocity = bundle.velocity.velocity
        pressure = bundle.pressure
        displacement = bundle.displacement
        native_resolved_fsi_web_export_assert_field_shapes(spec, coordinates, topology, velocity, pressure, displacement)

        frame_dir = joinpath(snapshot_root, frame_id)
        mkpath(frame_dir)
        velocity_path = joinpath(frame_dir, "velocity.f32")
        pressure_path = joinpath(frame_dir, "pressure.f32")
        displacement_path = joinpath(frame_dir, "displacement.f32")
        derived_path = joinpath(frame_dir, "derived.json")

        frame_assets = Dict{String,Any}(
            "velocity" => native_resolved_fsi_web_export_write_field_asset(
                asset_paths,
                velocity_path,
                web_export_row_major_f32(velocity),
                spec,
                3,
                "cm/s",
            ),
        )
        if pressure !== nothing
            has_pressure = true
            frame_assets["pressure"] = native_resolved_fsi_web_export_write_field_asset(
                asset_paths,
                pressure_path,
                web_export_vector_f32(pressure),
                spec,
                1,
                "dyn/cm^2",
            )
        end
        if displacement !== nothing
            has_displacement = true
            frame_assets["displacement"] = native_resolved_fsi_web_export_write_field_asset(
                asset_paths,
                displacement_path,
                web_export_row_major_f32(displacement),
                spec,
                3,
                "cm",
            )
        end

        ranges = native_resolved_fsi_web_export_ranges(velocity, pressure, displacement)
        push!(speed_ranges, ranges["speed_cm_s"])
        haskey(ranges, "pressure_dyn_cm2") && push!(pressure_ranges, ranges["pressure_dyn_cm2"])
        haskey(ranges, "displacement_magnitude_cm") &&
            push!(displacement_ranges, ranges["displacement_magnitude_cm"])
        if spec.include_derived
            write_json(derived_path, ranges; overwrite=spec.overwrite)
            push!(asset_paths, derived_path)
        end

        time_s = bundle.velocity.metadata.time
        previous_time = index == 1 ? nothing : frames[index - 1].bundle.velocity.metadata.time
        push!(time_axis, Dict{String,Any}(
            "frame_id" => frame_id,
            "time_s" => time_s,
            "delta_t_s" => previous_time === nothing ? nothing : time_s - previous_time,
        ))
        push!(snapshot_entries, Dict{String,Any}(
            "id" => frame_id,
            "source_id" => frame.source.source_id,
            "time_s" => time_s,
            "fields" => frame_assets,
            "derived" => spec.include_derived ? web_export_asset_descriptor(derived_path, spec.output_dir) : nothing,
            "ranges" => ranges,
        ))
    end

    global_ranges = Dict{String,Any}(
        "speed_cm_s" => web_export_merge_ranges(speed_ranges),
    )
    has_pressure && (global_ranges["pressure_dyn_cm2"] = web_export_merge_ranges(pressure_ranges))
    has_displacement &&
        (global_ranges["displacement_magnitude_cm"] = web_export_merge_ranges(displacement_ranges))
    available_fields = Any[
        Dict{String,Any}(
            "name" => "velocity",
            "components" => 3,
            "centering" => "node",
            "units" => "cm/s",
            "range" => global_ranges["speed_cm_s"],
        ),
        Dict{String,Any}(
            "name" => "speed",
            "components" => 1,
            "centering" => "node",
            "units" => "cm/s",
            "range" => global_ranges["speed_cm_s"],
        ),
    ]
    has_pressure && push!(available_fields, Dict{String,Any}(
        "name" => "pressure",
        "components" => 1,
        "centering" => "node",
        "units" => "dyn/cm^2",
        "range" => global_ranges["pressure_dyn_cm2"],
    ))
    has_displacement && push!(available_fields, Dict{String,Any}(
        "name" => "displacement",
        "components" => 3,
        "centering" => "node",
        "units" => "cm",
        "range" => global_ranges["displacement_magnitude_cm"],
    ))

    sidecars = native_resolved_fsi_web_export_sidecars(spec, sidecar_dir)
    observations = native_resolved_fsi_web_export_observations(spec, observation_dir)
    estimated_fps = native_resolved_fsi_web_export_estimated_fps(time_axis)
    manifest = Dict{String,Any}(
        "schema_version" => NATIVE_RESOLVED_FSI_WEB_EXPORT_TEMPORAL_SCHEMA_VERSION,
        "case_id" => string(spec.case_id),
        "case_label" => first_bundle.case_spec.case_label,
        "severity_percent" => first_bundle.case_spec.severity,
        "result_class" => "native_resolved_fsi_temporal_web_export",
        "claim_boundary" => NATIVE_RESOLVED_FSI_WEB_EXPORT_CLAIM_BOUNDARY,
        "coordinate_mode" => string(spec.coordinate_mode),
        "geometry_mode" => string(spec.geometry_mode),
        "units" => native_resolved_fsi_web_export_units(),
        "snapshot_count" => length(frames),
        "estimated_playback_fps" => estimated_fps,
        "time_axis" => time_axis,
        "available_fields" => available_fields,
        "global_ranges" => global_ranges,
        "mesh" => Dict{String,Any}(
            "node_indexing" => "zero_based",
            "index_dtype" => "uint32",
            "field_dtype" => "float32",
        ),
        "source" => Dict{String,Any}(
            "input_production_dir" => spec.input_production_dir,
            "target_time_s" => spec.target_time,
            "time_atol_s" => spec.time_atol,
            "snapshot_stride" => spec.snapshot_stride,
            "max_snapshots" => spec.max_snapshots,
        ),
        "geometry" => Dict{String,Any}(
            "node_count" => node_count,
            "tetrahedron_count" => size(topology, 1),
            "surface_triangle_count" => size(surface_triangles, 1),
            "reference_positions" => web_export_asset_descriptor(reference_positions_path, spec.output_dir),
            "surface_indices" => web_export_asset_descriptor(surface_indices_path, spec.output_dir),
            "tetra_indices_debug" => nothing,
        ),
        "snapshots" => snapshot_entries,
        "skipped_snapshots" => skipped_snapshots,
        "sidecars" => sidecars,
        "observations" => observations,
    )

    manifest_path = native_resolved_fsi_web_export_manifest_path(spec)
    write_json(manifest_path, manifest; overwrite=spec.overwrite)
    push!(asset_paths, manifest_path)

    return NativeResolvedFSIWebExportResult(
        spec,
        spec.output_dir,
        manifest_path,
        asset_paths,
        manifest,
        length(frames),
        skipped_snapshots,
        estimated_fps,
    )
end

function native_resolved_fsi_web_export_units()
    return Dict{String,Any}(
        "length" => "cm",
        "velocity" => "cm/s",
        "pressure" => "dyn/cm^2",
        "displacement" => "cm",
        "time" => "s",
    )
end

function native_resolved_fsi_web_export_ranges(velocity, pressure, displacement)
    speed = web_export_speed(velocity)
    displacement_magnitude = web_export_displacement_magnitude(displacement)
    ranges = Dict{String,Any}(
        "speed_cm_s" => web_export_range(speed),
        "velocity_components_cm_s" => Dict{String,Any}(
            "ux" => web_export_range(view(velocity, :, 1)),
            "uy" => web_export_range(view(velocity, :, 2)),
            "uz" => web_export_range(view(velocity, :, 3)),
        ),
    )
    pressure !== nothing && (ranges["pressure_dyn_cm2"] = web_export_range(pressure))
    !isempty(displacement_magnitude) &&
        (ranges["displacement_magnitude_cm"] = web_export_range(displacement_magnitude))
    return ranges
end

function native_resolved_fsi_web_export_field_descriptor(
    name::String,
    components::Int,
    units::String,
    path::String,
    spec::NativeResolvedFSIWebExportSpec,
)
    return Dict{String,Any}(
        "name" => name,
        "components" => components,
        "centering" => "node",
        "units" => units,
        "asset" => web_export_asset_descriptor(path, spec.output_dir),
    )
end

function native_resolved_fsi_web_export_write_field_asset(
    asset_paths::Vector{String},
    path::String,
    values,
    spec::NativeResolvedFSIWebExportSpec,
    components::Int,
    units::String,
)
    push!(asset_paths, write_web_export_binary(path, values; overwrite=spec.overwrite))
    return Dict{String,Any}(
        "components" => components,
        "centering" => "node",
        "units" => units,
        "asset" => web_export_asset_descriptor(path, spec.output_dir),
    )
end

function native_resolved_fsi_web_export_assert_field_shapes(
    spec::NativeResolvedFSIWebExportSpec,
    coordinates,
    topology,
    velocity,
    pressure,
    displacement,
)
    node_count = size(coordinates, 1)
    size(coordinates, 2) == 3 || throw(DimensionMismatch("coordinates must have three columns"))
    size(topology, 2) == 4 || throw(DimensionMismatch("topology must have four columns"))
    for index in topology
        1 <= index <= node_count ||
            throw(DimensionMismatch("topology index $index is outside the coordinate row range 1:$node_count"))
    end
    size(velocity, 1) == node_count || throw(DimensionMismatch("velocity row count does not match coordinates"))
    size(velocity, 2) == 3 || throw(DimensionMismatch("velocity must have three columns"))
    if pressure === nothing
        spec.allow_velocity_only ||
            throw(DimensionMismatch("pressure is required unless allow_velocity_only=true"))
    else
        length(pressure) == node_count ||
            throw(DimensionMismatch("pressure length does not match coordinates"))
    end
    if displacement === nothing
        spec.allow_velocity_only ||
            throw(DimensionMismatch("displacement is required unless allow_velocity_only=true"))
    else
        size(displacement, 1) == node_count ||
            throw(DimensionMismatch("displacement row count does not match coordinates"))
        size(displacement, 2) == 3 ||
            throw(DimensionMismatch("displacement must have three columns"))
    end
    return nothing
end

function native_resolved_fsi_web_export_assert_compatible_geometry(coordinates, topology, bundle::Resolved3DFieldBundle)
    bundle.velocity.coordinates == coordinates ||
        throw(ArgumentError("native resolved-FSI web export requires identical coordinates across temporal snapshots"))
    bundle.velocity.topology == topology ||
        throw(ArgumentError("native resolved-FSI web export requires identical topology across temporal snapshots"))
    return nothing
end

function native_resolved_fsi_web_export_sidecars(spec::NativeResolvedFSIWebExportSpec, sidecar_dir::String)
    sidecars = Dict{String,Any}()
    restart_sidecar = copy_web_export_json_sidecar(
        joinpath(sidecar_dir, "restart_metadata.json"),
        spec.restart_metadata_json,
        "restart_metadata";
        overwrite=spec.overwrite,
    )
    restart_sidecar !== nothing && (sidecars["restart_metadata"] = restart_sidecar)
    benchmark_sidecar = copy_web_export_json_sidecar(
        joinpath(sidecar_dir, "batch_benchmark.json"),
        spec.batch_benchmark_json,
        "batch_benchmark";
        overwrite=spec.overwrite,
    )
    benchmark_sidecar !== nothing && (sidecars["batch_benchmark"] = benchmark_sidecar)
    diagnostics_sidecar = copy_web_export_text_table_as_json(
        joinpath(sidecar_dir, "snapshot_diagnostics.json"),
        spec.diagnostics_csv,
        "snapshot_diagnostics";
        overwrite=spec.overwrite,
    )
    diagnostics_sidecar !== nothing && (sidecars["snapshot_diagnostics"] = diagnostics_sidecar)
    return sidecars
end

function native_resolved_fsi_web_export_observations(spec::NativeResolvedFSIWebExportSpec, observation_dir::String)
    observations = Dict{String,Any}()
    spec.include_observations || return observations
    observation_rows = copy_web_export_text_table_as_json(
        joinpath(observation_dir, "section41_observations.json"),
        spec.observations_csv,
        "section41_observations";
        overwrite=spec.overwrite,
    )
    observation_rows !== nothing && (observations["section41_observations"] = observation_rows)
    observation_summary = copy_web_export_text_table_as_json(
        joinpath(observation_dir, "section41_observation_summary.json"),
        spec.observation_summary_csv,
        "section41_observation_summary";
        overwrite=spec.overwrite,
    )
    observation_summary !== nothing && (observations["section41_observation_summary"] = observation_summary)
    return observations
end

function native_resolved_fsi_web_export_estimated_fps(time_axis)
    deltas = Float64[]
    for entry in time_axis
        delta = get(entry, "delta_t_s", nothing)
        delta === nothing && continue
        isfinite(delta) && delta > 0.0 && push!(deltas, Float64(delta))
    end
    isempty(deltas) && return 0.0
    return min(30.0, 1.0 / median(deltas))
end

function native_resolved_fsi_web_export_discover_sources(spec::NativeResolvedFSIWebExportSpec)
    root = spec.input_production_dir
    skipped = String[]
    restart_path = isempty(spec.restart_metadata_json) ? joinpath(root, "restart_metadata.json") : spec.restart_metadata_json
    if isfile(restart_path)
        metadata = load_yaml_file(restart_path)
        outputs = web_export_mapping_value(metadata, "snapshot_outputs", Any[])
        sources = NativeResolvedFSIWebExportSnapshotSource[]
        for (index, output) in enumerate(outputs)
            source = native_resolved_fsi_web_export_source_from_mapping(root, output, index, spec)
            source === nothing ? push!(skipped, "restart_metadata[$index]") : push!(sources, source)
        end
        !isempty(sources) && return sources, skipped
    end

    manifest_csv = joinpath(root, "snapshot_manifest.csv")
    if isfile(manifest_csv)
        rows = web_export_simple_csv_rows(manifest_csv)
        sources = NativeResolvedFSIWebExportSnapshotSource[]
        for (index, row) in enumerate(rows)
            source = native_resolved_fsi_web_export_source_from_mapping(root, row, index, spec)
            source === nothing ? push!(skipped, "snapshot_manifest[$index]") : push!(sources, source)
        end
        !isempty(sources) && return sources, skipped
    end

    snapshot_dirs = sort!(filter(path -> isdir(path) && startswith(basename(path), "snapshot-t"), readdir(root; join=true)))
    if !isempty(snapshot_dirs)
        sources = NativeResolvedFSIWebExportSnapshotSource[]
        for dir in snapshot_dirs
            source = native_resolved_fsi_web_export_source_from_directory(root, dir, spec)
            source === nothing ? push!(skipped, basename(dir)) : push!(sources, source)
        end
        !isempty(sources) && return sources, skipped
    end

    source = native_resolved_fsi_web_export_source_from_directory(root, root, spec)
    source === nothing && throw(ArgumentError("native resolved-FSI web export found no production snapshots in $root"))
    return NativeResolvedFSIWebExportSnapshotSource[source], skipped
end

function native_resolved_fsi_web_export_source_from_mapping(
    root::String,
    mapping,
    index::Int,
    spec::NativeResolvedFSIWebExportSpec,
)
    output_dir = web_export_resolve_source_path(String(web_export_mapping_value(mapping, "output_dir", root)), root)
    velocity = String(web_export_mapping_value(mapping, "velocity_xdmf", ""))
    pressure = String(web_export_mapping_value(mapping, "pressure_xdmf", ""))
    displacement = String(web_export_mapping_value(mapping, "displacement_xdmf", ""))
    isempty(velocity) && return nothing
    velocity_path = web_export_resolve_source_path(velocity, output_dir)
    pressure_path = web_export_resolve_source_path(pressure, output_dir)
    displacement_path = web_export_resolve_source_path(displacement, output_dir)
    if !isfile(velocity_path) ||
       (!spec.allow_velocity_only && (!isfile(pressure_path) || !isfile(displacement_path)))
        return nothing
    end
    source_id = basename(output_dir)
    isempty(source_id) && (source_id = "snapshot-$index")
    raw_time = web_export_mapping_value(mapping, "snapshot_time_s", spec.target_time)
    return NativeResolvedFSIWebExportSnapshotSource(
        source_id,
        web_export_float(raw_time, spec.target_time),
        velocity_path,
        pressure_path,
        displacement_path,
    )
end

function native_resolved_fsi_web_export_source_from_directory(
    root::String,
    dir::String,
    spec::NativeResolvedFSIWebExportSpec,
)
    velocity = joinpath(dir, NATIVE_RESOLVED_FSI_DEFAULT_VELOCITY_XDMF)
    pressure = joinpath(dir, NATIVE_RESOLVED_FSI_DEFAULT_PRESSURE_XDMF)
    displacement = joinpath(dir, NATIVE_RESOLVED_FSI_DEFAULT_DISPLACEMENT_XDMF)
    isfile(velocity) || return nothing
    spec.allow_velocity_only || (isfile(pressure) && isfile(displacement)) || return nothing
    source_id = dir == root ? "direct" : basename(dir)
    time_s = web_export_snapshot_token_time(source_id, spec.target_time)
    return NativeResolvedFSIWebExportSnapshotSource(source_id, time_s, velocity, pressure, displacement)
end

function native_resolved_fsi_web_export_matches_source_id(
    source::NativeResolvedFSIWebExportSnapshotSource,
    index::Int,
    selector::String,
)
    selector == source.source_id && return true
    selector == basename(dirname(source.velocity_xdmf)) && return true
    selector == web_export_frame_id(index) && return true
    return false
end

function native_resolved_fsi_web_export_select_sources(
    spec::NativeResolvedFSIWebExportSpec,
    sources::Vector{NativeResolvedFSIWebExportSnapshotSource},
)
    skipped = String[]
    selected = NativeResolvedFSIWebExportSnapshotSource[]
    for (index, source) in enumerate(sources)
        include_match = isempty(spec.snapshot_include) ||
                        any(selector -> native_resolved_fsi_web_export_matches_source_id(source, index, selector), spec.snapshot_include)
        exclude_match = any(selector -> native_resolved_fsi_web_export_matches_source_id(source, index, selector), spec.snapshot_exclude)
        if !include_match || exclude_match
            push!(skipped, source.source_id)
            continue
        end
        push!(selected, source)
    end
    strided = NativeResolvedFSIWebExportSnapshotSource[]
    for (index, source) in enumerate(selected)
        if (index - 1) % spec.snapshot_stride == 0
            push!(strided, source)
        else
            push!(skipped, source.source_id)
        end
    end
    if spec.max_snapshots !== nothing && length(strided) > spec.max_snapshots
        append!(skipped, String[source.source_id for source in strided[(spec.max_snapshots + 1):end]])
        strided = strided[1:spec.max_snapshots]
    end
    return strided, skipped
end
