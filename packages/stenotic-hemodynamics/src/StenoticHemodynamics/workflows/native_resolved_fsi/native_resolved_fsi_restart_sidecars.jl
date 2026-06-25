function native_resolved_fsi_checkpoint_digest_values(label::AbstractString, values)
    io = IOBuffer()
    println(io, String(label))
    for value in values
        println(io, value isa Real ? repr(value) : string(value))
    end
    return bytes2hex(sha256(take!(io)))
end

function native_resolved_fsi_checkpoint_digest_array(label::AbstractString, array)
    io = IOBuffer()
    println(io, String(label))
    println(io, ndims(array))
    println(io, join(size(array), ","))
    for value in array
        println(io, value isa Real ? repr(value) : string(value))
    end
    return bytes2hex(sha256(take!(io)))
end

function native_resolved_fsi_checkpoint_boundary_tags_digest(tags::NativeResolvedFSIMeshTags)
    io = IOBuffer()
    for (label, values) in (
        ("inlet_faces", tags.inlet_faces),
        ("outlet_faces", tags.outlet_faces),
        ("wall_faces", tags.wall_faces),
        ("inlet_nodes", tags.inlet_nodes),
        ("outlet_nodes", tags.outlet_nodes),
        ("wall_nodes", tags.wall_nodes),
        ("interior_cells", tags.interior_cells),
    )
        println(io, label)
        println(io, ndims(values))
        println(io, join(size(values), ","))
        for value in values
            println(io, value)
        end
    end
    return bytes2hex(sha256(take!(io)))
end

function native_resolved_fsi_checkpoint_mesh_identity(mesh::NativeResolvedFSIMesh)
    return Dict{String,Any}(
        "case_id" => string(mesh.case_spec.case_id),
        "severity_percent" => mesh.case_spec.severity_percent,
        "length_cm" => mesh.case_spec.length_cm,
        "rmax_cm" => mesh.case_spec.rmax_cm,
        "delta_r_cm" => mesh.case_spec.delta_r_cm,
        "rmin_cm" => mesh.case_spec.rmin_cm,
        "mesh_resolution" => Dict{String,Any}(
            "axial" => mesh.geometry.resolution.axial,
            "radial" => mesh.geometry.resolution.radial,
            "angular" => mesh.geometry.resolution.angular,
        ),
        "node_count" => size(mesh.coordinates, 1),
        "tetrahedron_count" => size(mesh.topology, 1),
        "reference_coordinates_sha256" =>
            native_resolved_fsi_checkpoint_digest_array("reference_coordinates_cm", mesh.coordinates),
        "topology_sha256" => native_resolved_fsi_checkpoint_digest_array("topology", mesh.topology),
        "boundary_tags_sha256" => native_resolved_fsi_checkpoint_boundary_tags_digest(mesh.tags),
        "axial_coordinates_sha256" =>
            native_resolved_fsi_checkpoint_digest_array("axial_coordinates_cm", mesh.geometry.axial_coordinates_cm),
        "reference_radii_sha256" =>
            native_resolved_fsi_checkpoint_digest_array("reference_radii_cm", mesh.geometry.reference_radii_cm),
    )
end

function native_resolved_fsi_wall_velocity_fluid_bc_status(fluid_wall_boundary_mode::Symbol)
    if fluid_wall_boundary_mode === NATIVE_RESOLVED_FSI_PARTITIONED_EXACT_FLUID_WALL_BOUNDARY_MODE
        return "stationary_wall_on_deformed_geometry_for_exact_inlet_outlet_mode"
    end
    if fluid_wall_boundary_mode === NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_FLUID_WALL_BOUNDARY_MODE
        return "prescribed_radial_wall_velocity_on_deformed_geometry"
    end
    return "unknown_wall_boundary_handoff"
end

function native_resolved_fsi_restart_checkpoint_manifest_entry(role::String, path::String, metadata_dir::String)
    return Dict{String,Any}(
        "role" => role,
        "path" => relpath(path, metadata_dir),
        "sha256" => sha256_file(path),
        "byte_size" => filesize(path),
    )
end

function native_resolved_fsi_write_restart_checkpoint_state(
    local_spec::NativeResolvedFSIPartitionedProductionSpec,
    snapshot_results::Vector{NamedTuple},
    rows::Vector{NamedTuple},
    manifest_csv::String,
    diagnostics_csv::String,
    restart_metadata_json::String;
    resume_context = nothing,
)
    final_snapshot = snapshot_results[end]
    final_smoke = final_snapshot.smoke_result
    final_solve = final_snapshot.solve_result
    metadata_dir = dirname(restart_metadata_json)
    checkpoint_dir = joinpath(metadata_dir, "checkpoint")
    wall_state_path = joinpath(checkpoint_dir, "wall_state.json")
    mesh_identity_path = joinpath(checkpoint_dir, "mesh_identity.json")
    fluid_state_path = joinpath(checkpoint_dir, "fluid_state.json")
    coupling_state_path = joinpath(checkpoint_dir, "coupling_state.json")
    output_linkage_path = joinpath(checkpoint_dir, "output_linkage.json")
    completed_snapshot_count = resume_context === nothing ? 0 : resume_context.completed_snapshot_count
    current_snapshot_index = completed_snapshot_count + length(snapshot_results)
    next_pending_snapshot_index = current_snapshot_index < length(local_spec.snapshot_times_s) ?
        current_snapshot_index + 1 :
        nothing

    write_json(wall_state_path, Dict{String,Any}(
        "schema_version" => 1,
        "representation" => "durable_reduced_wall_state",
        "wall_axial_coordinates_cm" => copy(final_smoke.wall_axial_coordinates_cm),
        "reference_radii_cm" => copy(final_smoke.mesh.geometry.reference_radii_cm),
        "wall_displacement_cm" => copy(final_smoke.wall_displacement_cm),
        "wall_velocity_cm_s" => copy(final_smoke.wall_velocity_cm_s),
        "current_radii_cm" => copy(final_smoke.current_radii_cm),
        "wall_pressure_dyn_cm2" => copy(final_smoke.wall_pressure_dyn_cm2),
        "physical_wall_forcing_pressure_dyn_cm2" => copy(final_smoke.wall_pressure_dyn_cm2),
        "pressure_gauge_convention" => "outlet_gauge_normalization_export_only_not_membrane_forcing",
        "wall_pressure_forcing_status" =>
            native_resolved_fsi_wall_pressure_forcing_status(final_smoke.inlet_outlet_boundary_mode),
        "wall_density_g_cm3" => local_spec.wall_density_g_cm3,
        "wall_mass_g_cm2" => final_smoke.wall_mass_g_cm2,
        "wall_stiffness_c0_dyn_cm3" => final_smoke.wall_stiffness_c0_dyn_cm3,
        "wall_stiffness_c0_dyn_cm3_vector" =>
            fill(final_smoke.wall_stiffness_c0_dyn_cm3, length(final_smoke.wall_axial_coordinates_cm)),
        "wall_stiffness_policy" => string(local_spec.wall_stiffness_policy),
        "wall_damping_g_cm2_s" => final_smoke.wall_damping_g_cm2_s,
        "wall_reference_radius_policy" => string(local_spec.wall_reference_radius_policy),
        "minimum_current_radius_cm" => final_smoke.minimum_current_radius_cm,
        "clamped_endpoint_status" => "inlet_and_outlet_wall_state_zeroed",
        "clamped_endpoint_tolerance_cm" => 0.0,
    ); overwrite=local_spec.overwrite)
    mesh_identity = native_resolved_fsi_checkpoint_mesh_identity(final_smoke.mesh)
    mesh_identity["schema_version"] = 1
    mesh_identity["representation"] = "native_mesh_identity"
    mesh_identity["mesh_h5"] = final_smoke.mesh_h5
    mesh_identity["mesh_h5_sha256"] = sha256_file(final_smoke.mesh_h5)
    mesh_identity["minimum_signed_tetra_volume6"] = final_smoke.minimum_signed_tetra_volume6
    write_json(mesh_identity_path, mesh_identity; overwrite=local_spec.overwrite)
    write_json(fluid_state_path, Dict{String,Any}(
        "schema_version" => 1,
        "representation" => "gridap_free_dof_checkpoint",
        "restartable_fe_state" => true,
        "velocity_dofs" => final_smoke.velocity_dofs,
        "pressure_dofs" => final_smoke.pressure_dofs,
        "velocity_free_dof_values" => native_resolved_fsi_copy_free_dof_values(final_solve.velocity),
        "pressure_free_dof_values" => native_resolved_fsi_copy_free_dof_values(final_solve.pressure),
        "previous_velocity_free_dof_values" => native_resolved_fsi_copy_free_dof_values(final_solve.velocity),
        "coordinate_mode" => "current_deformed_coordinates",
        "pressure_state_role" => "pressure_initial_guess_and_audit_state",
        "velocity_xdmf" => final_smoke.velocity_xdmf,
        "velocity_h5" => final_smoke.velocity_h5,
        "velocity_h5_sha256" => sha256_file(final_smoke.velocity_h5),
        "pressure_xdmf" => final_smoke.pressure_xdmf,
        "pressure_h5" => final_smoke.pressure_h5,
        "pressure_h5_sha256" => sha256_file(final_smoke.pressure_h5),
        "displacement_xdmf" => final_smoke.displacement_xdmf,
        "displacement_h5" => final_smoke.displacement_h5,
        "displacement_h5_sha256" => sha256_file(final_smoke.displacement_h5),
        "pressure_gauge_offset_dyn_cm2" => final_smoke.pressure_gauge_offset_dyn_cm2,
        "pressure_gauge_convention" => "outlet_gauge_normalization_export_only_not_membrane_forcing",
        "max_picard_iterations_used" => final_smoke.max_picard_iterations_used,
        "final_picard_update_norm" => final_smoke.final_picard_update_norm,
        "picard_converged" => final_smoke.picard_converged,
    ); overwrite=local_spec.overwrite)
    write_json(coupling_state_path, Dict{String,Any}(
        "schema_version" => 1,
        "representation" => "partitioned_coupling_state_and_cursor",
        "completed_snapshot_count" => current_snapshot_index,
        "current_snapshot_index" => current_snapshot_index,
        "next_pending_snapshot_index" => next_pending_snapshot_index,
        "current_snapshot_time_s" => final_snapshot.snapshot_time_s,
        "current_saved_time_s" => final_smoke.saved_time_s,
        "current_time_step_count" => final_smoke.time_step_count,
        "dt_s" => local_spec.dt_s,
        "tfinal_s" => local_spec.tfinal_s,
        "snapshot_times_s" => copy(local_spec.snapshot_times_s),
        "time_atol" => local_spec.time_atol,
        "coupling_iteration_count" => local_spec.coupling_iteration_count,
        "coupling_tolerance" => local_spec.coupling_tolerance,
        "coupling_under_relaxation" => local_spec.coupling_under_relaxation,
        "max_coupling_iterations_used" => final_smoke.max_coupling_iterations_used,
        "final_coupling_displacement_residual_cm" => final_smoke.final_coupling_displacement_residual_cm,
        "coupling_converged" => final_smoke.coupling_converged,
        "pressure_projection_fallback_count" => final_smoke.pressure_projection_fallback_count,
        "sampling_fallback_count" => final_smoke.sampling_fallback_count,
        "minimum_signed_tetra_volume6" => final_smoke.minimum_signed_tetra_volume6,
        "fluid_wall_boundary_mode" => string(final_smoke.fluid_wall_boundary_mode),
        "coupling_residual_history" => Any[
            Dict{String,Any}(string(key) => value for (key, value) in pairs(row))
            for row in final_smoke.coupling_residual_history
        ],
    ); overwrite=local_spec.overwrite)
    current_snapshot_outputs = Any[
        Dict{String,Any}(
            "snapshot_index" => snapshot.snapshot_index,
            "snapshot_time_s" => snapshot.snapshot_time_s,
            "saved_time_s" => snapshot.smoke_result.saved_time_s,
            "output_dir" => snapshot.output_dir,
            "velocity_xdmf" => snapshot.smoke_result.velocity_xdmf,
            "velocity_h5" => snapshot.smoke_result.velocity_h5,
            "velocity_h5_sha256" => sha256_file(snapshot.smoke_result.velocity_h5),
            "pressure_xdmf" => snapshot.smoke_result.pressure_xdmf,
            "pressure_h5" => snapshot.smoke_result.pressure_h5,
            "pressure_h5_sha256" => sha256_file(snapshot.smoke_result.pressure_h5),
            "displacement_xdmf" => snapshot.smoke_result.displacement_xdmf,
            "displacement_h5" => snapshot.smoke_result.displacement_h5,
            "displacement_h5_sha256" => sha256_file(snapshot.smoke_result.displacement_h5),
            "status" => snapshot.status.status,
            "ownership" => "current_resume_output_root",
        ) for snapshot in snapshot_results
    ]
    all_snapshot_outputs = resume_context === nothing ?
        current_snapshot_outputs :
        vcat(deepcopy(resume_context.completed_snapshot_outputs), current_snapshot_outputs)
    write_json(output_linkage_path, Dict{String,Any}(
        "schema_version" => 1,
        "representation" => "sidecar_and_output_linkage",
        "snapshot_manifest_csv" => manifest_csv,
        "snapshot_manifest_sha256" => sha256_file(manifest_csv),
        "diagnostics_csv" => diagnostics_csv,
        "diagnostics_sha256" => sha256_file(diagnostics_csv),
        "snapshot_outputs" => all_snapshot_outputs,
        "diagnostic_row_count" => completed_snapshot_count + length(rows),
        "completed_parent_snapshot_count" => completed_snapshot_count,
        "current_run_snapshot_count" => length(snapshot_results),
        "output_ownership_policy" => resume_context === nothing ?
            "current_run_owns_all_listed_outputs" :
            "forked_resume_references_parent_completed_outputs_and_owns_only_current_resume_output_root",
        "parent_restart_metadata_json" =>
            resume_context === nothing ? nothing : resume_context.parent_restart_metadata_json,
    ); overwrite=local_spec.overwrite)

    return Any[
        native_resolved_fsi_restart_checkpoint_manifest_entry("wall_state", wall_state_path, metadata_dir),
        native_resolved_fsi_restart_checkpoint_manifest_entry("mesh_identity", mesh_identity_path, metadata_dir),
        native_resolved_fsi_restart_checkpoint_manifest_entry("fluid_state", fluid_state_path, metadata_dir),
        native_resolved_fsi_restart_checkpoint_manifest_entry("coupling_state", coupling_state_path, metadata_dir),
        native_resolved_fsi_restart_checkpoint_manifest_entry("output_linkage", output_linkage_path, metadata_dir),
    ]
end

function native_resolved_fsi_restart_metadata(
    local_spec::NativeResolvedFSIPartitionedProductionSpec,
    snapshot_results::Vector{NamedTuple},
    rows::Vector{NamedTuple},
    manifest_csv::String,
    diagnostics_csv::String,
    checkpoint_manifest;
    resume_context = nothing,
    execution_layout,
)
    final_snapshot = snapshot_results[end]
    final_smoke = final_snapshot.smoke_result
    resolution = local_spec.resolution
    final_boundary_status = native_resolved_fsi_boundary_status_fields(
        final_smoke.inlet_outlet_boundary_mode;
        inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
    )
    completed_snapshot_count = resume_context === nothing ? 0 : resume_context.completed_snapshot_count
    current_snapshot_index = completed_snapshot_count + length(snapshot_results)
    next_pending_snapshot_index = current_snapshot_index < length(local_spec.snapshot_times_s) ?
        current_snapshot_index + 1 :
        nothing
    snapshot_outputs = resume_context === nothing ? Any[] : deepcopy(resume_context.completed_snapshot_outputs)
    for snapshot in snapshot_results
        index = snapshot.snapshot_index
        snapshot_boundary_status = native_resolved_fsi_boundary_status_fields(
            snapshot.smoke_result.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
        )
        push!(snapshot_outputs, Dict{String,Any}(
            "snapshot_index" => index,
            "snapshot_time_s" => snapshot.snapshot_time_s,
            "saved_time_s" => snapshot.smoke_result.saved_time_s,
            "output_dir" => snapshot.output_dir,
            "velocity_xdmf" => snapshot.smoke_result.velocity_xdmf,
            "velocity_h5" => snapshot.smoke_result.velocity_h5,
            "velocity_h5_sha256" => sha256_file(snapshot.smoke_result.velocity_h5),
            "pressure_xdmf" => snapshot.smoke_result.pressure_xdmf,
            "pressure_h5" => snapshot.smoke_result.pressure_h5,
            "pressure_h5_sha256" => sha256_file(snapshot.smoke_result.pressure_h5),
            "displacement_xdmf" => snapshot.smoke_result.displacement_xdmf,
            "displacement_h5" => snapshot.smoke_result.displacement_h5,
            "displacement_h5_sha256" => sha256_file(snapshot.smoke_result.displacement_h5),
            "provenance" => snapshot.provenance,
            "time_step_count" => snapshot.smoke_result.time_step_count,
            "max_coupling_iterations_used" => snapshot.smoke_result.max_coupling_iterations_used,
            "final_coupling_displacement_residual_cm" =>
                snapshot.smoke_result.final_coupling_displacement_residual_cm,
            "coupling_converged" => snapshot.smoke_result.coupling_converged,
            "fluid_wall_boundary_mode" => string(snapshot.smoke_result.fluid_wall_boundary_mode),
            "inlet_umax_cm_s" => local_spec.inlet_umax_cm_s,
            "boundary_mode" => snapshot_boundary_status.boundary_mode,
            "boundary_mode_class" => snapshot_boundary_status.boundary_mode_class,
            "inlet_condition_status" => snapshot_boundary_status.inlet_condition_status,
            "outlet_condition_status" => snapshot_boundary_status.outlet_condition_status,
            "pressure_gauge_status" => snapshot_boundary_status.pressure_gauge_status,
            "pressure_nullspace_status" =>
                native_resolved_fsi_pressure_nullspace_status(snapshot.smoke_result.inlet_outlet_boundary_mode),
            "wall_pressure_projection_status" =>
                native_resolved_fsi_wall_pressure_projection_status(snapshot.smoke_result.inlet_outlet_boundary_mode),
            "wall_pressure_forcing_status" =>
                native_resolved_fsi_wall_pressure_forcing_status(snapshot.smoke_result.inlet_outlet_boundary_mode),
            "pressure_gauge_convention" => "outlet_gauge_normalization_export_only_not_membrane_forcing",
            "section41_boundary_status" => snapshot_boundary_status.section41_boundary_status,
            "boundary_status" => snapshot_boundary_status.boundary_status,
            "boundary_equivalence_status" =>
                native_resolved_fsi_boundary_equivalence_status(snapshot_boundary_status),
            "status" => snapshot.status.status,
            "ownership" => resume_context === nothing ?
                "current_run_output_root" :
                "current_resume_output_root",
        ))
    end
    coupling_residual_history = Any[
        Dict{String,Any}(
            "time_step_index" => row.time_step_index,
            "coupling_iteration" => row.coupling_iteration,
            "time_start_s" => row.time_start_s,
            "time_end_s" => row.time_end_s,
            "displacement_residual_cm" => row.displacement_residual_cm,
            "coupling_tolerance_cm" => row.coupling_tolerance_cm,
            "under_relaxation" => row.under_relaxation,
            "converged" => row.converged,
            "fluid_wall_boundary_mode" => row.fluid_wall_boundary_mode,
        ) for row in final_smoke.coupling_residual_history
    ]
    state_payload = Dict{String,Any}(
        "schema_version" => 1,
        "saved_time_s" => final_smoke.saved_time_s,
        "last_snapshot_index" => current_snapshot_index,
        "final_wall_displacement_cm" => copy(final_smoke.wall_displacement_cm),
        "final_wall_velocity_cm_s" => copy(final_smoke.wall_velocity_cm_s),
        "current_radii_cm" => copy(final_smoke.current_radii_cm),
        "final_wall_pressure_dyn_cm2" => copy(final_smoke.wall_pressure_dyn_cm2),
        "final_physical_wall_forcing_pressure_dyn_cm2" => copy(final_smoke.wall_pressure_dyn_cm2),
        "pressure_gauge_convention" => "outlet_gauge_normalization_export_only_not_membrane_forcing",
        "solver_provenance" => "state_carrying_partitioned",
        "state_carrying_in_run" => true,
        "resume_supported" => false,
        "resume_status" => "deferred",
    )
    paths = native_resolved_fsi_partitioned_production_sidecar_paths(local_spec)
    return Dict{String,Any}(
        "case_id" => string(local_spec.case_spec.case_id),
        "severity_percent" => local_spec.case_spec.severity_percent,
        "mesh_resolution" => Dict{String,Any}(
            "axial" => resolution.axial,
            "radial" => resolution.radial,
            "angular" => resolution.angular,
        ),
        "dt_s" => local_spec.dt_s,
        "tfinal_s" => local_spec.tfinal_s,
        "time_atol" => local_spec.time_atol,
        "output_root" => local_spec.output_root,
        "production_output_dir" => default_native_resolved_fsi_partitioned_production_output_dir(local_spec),
        "parent_restart_metadata_json" =>
            resume_context === nothing ? nothing : resume_context.parent_restart_metadata_json,
        "completed_parent_snapshot_count" => completed_snapshot_count,
        "next_pending_snapshot_index" => next_pending_snapshot_index,
        "resume_run_role" => resume_context === nothing ? "checkpoint_writer" : "forked_internal_resume",
        "resume_scope" => NATIVE_RESOLVED_FSI_RESTART_INTERNAL_RESUME_SCOPE,
        "internal_split_run_resume_supported" => true,
        "internal_split_run_resume_status" => NATIVE_RESOLVED_FSI_RESTART_INTERNAL_RESUME_STATUS,
        "public_resume_supported" => false,
        "public_resume_status" => NATIVE_RESOLVED_FSI_RESTART_PUBLIC_RESUME_STATUS,
        "default_process_resume_supported" => false,
        "default_process_resume_status" => NATIVE_RESOLVED_FSI_RESTART_DEFAULT_PROCESS_RESUME_STATUS,
        "output_ownership_policy" => resume_context === nothing ?
            "current_run_owns_all_listed_outputs" :
            "forked_resume_references_parent_completed_outputs_and_owns_only_current_resume_output_root",
        "process_id" => execution_layout.process_id,
        "thread_count" => execution_layout.thread_count,
        "parallel_workers" => execution_layout.parallel_workers,
        "threads_per_worker" => execution_layout.threads_per_worker,
        "force_process" => execution_layout.force_process,
        "snapshot_times_s" => copy(local_spec.snapshot_times_s),
        "current_snapshot_index" => current_snapshot_index,
        "current_snapshot_time_s" => final_snapshot.snapshot_time_s,
        "current_saved_time_s" => final_smoke.saved_time_s,
        "current_smoke_time_step_count" => final_smoke.time_step_count,
        "picard_iteration_count" => local_spec.picard_iteration_count,
        "picard_tolerance" => local_spec.picard_tolerance,
        "coupling_iteration_count" => local_spec.coupling_iteration_count,
        "coupling_tolerance" => local_spec.coupling_tolerance,
        "coupling_under_relaxation" => local_spec.coupling_under_relaxation,
        "wall_density_g_cm3" => local_spec.wall_density_g_cm3,
        "wall_damping_g_cm2_s" => local_spec.wall_damping_g_cm2_s,
        "wall_stiffness_policy" => string(local_spec.wall_stiffness_policy),
        "wall_reference_radius_policy" => string(local_spec.wall_reference_radius_policy),
        "allow_many_snapshots" => local_spec.allow_many_snapshots,
        "allow_large_output" => local_spec.allow_large_output,
        "max_coupling_iterations_used" => final_smoke.max_coupling_iterations_used,
        "final_coupling_displacement_residual_cm" =>
            final_smoke.final_coupling_displacement_residual_cm,
        "coupling_converged" => final_smoke.coupling_converged,
        "coupling_residual_history" => coupling_residual_history,
        "fluid_wall_boundary_mode" => string(final_smoke.fluid_wall_boundary_mode),
        "wall_velocity_fluid_bc_status" =>
            native_resolved_fsi_wall_velocity_fluid_bc_status(final_smoke.fluid_wall_boundary_mode),
        "inlet_umax_cm_s" => local_spec.inlet_umax_cm_s,
        "pressure_drop_dyn_cm2" => local_spec.pressure_drop_dyn_cm2,
        "inlet_outlet_boundary_mode" => string(local_spec.inlet_outlet_boundary_mode),
        "boundary_mode" => final_boundary_status.boundary_mode,
        "boundary_mode_class" => final_boundary_status.boundary_mode_class,
        "inlet_condition_status" => final_boundary_status.inlet_condition_status,
        "outlet_condition_status" => final_boundary_status.outlet_condition_status,
        "pressure_gauge_status" => final_boundary_status.pressure_gauge_status,
        "pressure_nullspace_status" =>
            native_resolved_fsi_pressure_nullspace_status(final_smoke.inlet_outlet_boundary_mode),
        "wall_pressure_projection_status" =>
            native_resolved_fsi_wall_pressure_projection_status(final_smoke.inlet_outlet_boundary_mode),
        "wall_pressure_forcing_status" =>
            native_resolved_fsi_wall_pressure_forcing_status(final_smoke.inlet_outlet_boundary_mode),
        "pressure_gauge_convention" => "outlet_gauge_normalization_export_only_not_membrane_forcing",
        "section41_boundary_status" => final_boundary_status.section41_boundary_status,
        "boundary_status" => final_boundary_status.boundary_status,
        "boundary_equivalence_status" => native_resolved_fsi_boundary_equivalence_status(final_boundary_status),
        "current_wall_displacement_cm" => copy(final_smoke.wall_displacement_cm),
        "current_wall_velocity_cm_s" => copy(final_smoke.wall_velocity_cm_s),
        "current_wall_pressure_dyn_cm2" => copy(final_smoke.wall_pressure_dyn_cm2),
        "current_physical_wall_forcing_pressure_dyn_cm2" => copy(final_smoke.wall_pressure_dyn_cm2),
        "current_geometry_status" => final_smoke.geometry_status.status,
        "current_minimum_radius_cm" => final_smoke.minimum_current_radius_cm,
        "current_minimum_signed_tetra_volume6" => final_smoke.minimum_signed_tetra_volume6,
        "current_output_status" => final_snapshot.status.status,
        "current_importer_roundtrip_ready" => rows[end].importer_roundtrip_ready,
        "snapshot_manifest_csv" => manifest_csv,
        "diagnostics_csv" => diagnostics_csv,
        "batch_status_jsonl" => paths.batch_status_jsonl,
        "batch_status_csv" => paths.batch_status_csv,
        "batch_benchmark_json" => paths.batch_benchmark_json,
        "batch_failure_json" => paths.batch_failure_json,
        "snapshot_outputs" => snapshot_outputs,
        "state_payload" => state_payload,
        "production_spec_digest" => native_resolved_fsi_partitioned_production_spec_digest(local_spec),
        "restart_schema_version" => 3,
        "restart_schema_status" => "schema_v3_durable_checkpoint",
        "checkpoint_manifest" => checkpoint_manifest,
        "checkpoint_schema_status" => "durable_checkpoint_ready",
        "restart_provenance" => "state_carrying_partitioned",
        "state_carrying_restart" => true,
        "resume_supported" => true,
        "resume_status" => "ready",
        "resume_note" =>
            "Schema v3 checkpoint sidecars record reduced wall state, regenerated mesh identity digests, Gridap free-DOF fluid state, coupling history, and the snapshot cursor for qualified internal split-run resume only. Public/default process resume and CLI resume remain intentionally unexposed.",
    )
end

function native_resolved_fsi_write_restart_metadata(path::String, metadata::Dict{String,Any}, overwrite::Bool)
    return write_json(path, metadata; overwrite=overwrite)
end

function native_resolved_fsi_restart_status(metadata::Dict{String,Any}, restart_metadata_json::String)
    ready = isfile(restart_metadata_json) &&
            get(metadata, "restart_provenance", "") == "state_carrying_partitioned" &&
            get(metadata, "state_carrying_restart", false) == true &&
            get(metadata, "restart_schema_version", 1) in (1, 2, 3) &&
            (
                (
                    get(metadata, "restart_schema_version", 1) == 3 &&
                    get(metadata, "resume_supported", false) == true &&
                    get(metadata, "resume_status", "") == "ready" &&
                    get(metadata, "resume_scope", "") == NATIVE_RESOLVED_FSI_RESTART_INTERNAL_RESUME_SCOPE &&
                    get(metadata, "internal_split_run_resume_supported", false) == true &&
                    get(metadata, "internal_split_run_resume_status", "") ==
                    NATIVE_RESOLVED_FSI_RESTART_INTERNAL_RESUME_STATUS &&
                    get(metadata, "public_resume_supported", true) == false &&
                    get(metadata, "public_resume_status", "") ==
                    NATIVE_RESOLVED_FSI_RESTART_PUBLIC_RESUME_STATUS &&
                    get(metadata, "default_process_resume_supported", true) == false &&
                    get(metadata, "default_process_resume_status", "") ==
                    NATIVE_RESOLVED_FSI_RESTART_DEFAULT_PROCESS_RESUME_STATUS &&
                    get(metadata, "checkpoint_schema_status", "") == "durable_checkpoint_ready"
                ) ||
                (
                    get(metadata, "restart_schema_version", 1) in (1, 2) &&
                    get(metadata, "resume_supported", true) == false &&
                    get(metadata, "resume_status", "") == "deferred"
                )
            ) &&
            get(get(metadata, "state_payload", Dict{String,Any}()), "schema_version", nothing) == 1 &&
            (
                get(metadata, "restart_schema_version", 1) == 1 ||
                !isempty(get(metadata, "checkpoint_manifest", Any[]))
            )
    status = if ready && get(metadata, "restart_schema_version", 1) == 3
        "restart metadata was written with durable schema-v3 checkpoint sidecars ready for qualified internal split-run resume; public/default process resume remains unsupported"
    elseif ready
        "restart metadata was written with state-carrying partitioned snapshot provenance and non-resumable checkpoint sidecars; persisted resume remains explicitly deferred"
    else
        "restart metadata is missing or does not mark the current state-carrying non-resumable provenance"
    end
    return NativeResolvedFSIWorkflowStatus(ready, status)
end
