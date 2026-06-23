function native_resolved_fsi_smoke_roundtrip_bundle(
    mesh::NativeResolvedFSIMesh,
    output_dir::AbstractString,
    case_label::AbstractString,
    velocity::Matrix{Float64},
    pressure::Vector{Float64},
    displacement::Matrix{Float64};
    saved_time_s::Float64,
    time_atol::Float64,
    overwrite::Bool,
)
    writer_result = write_resolved3d_field_bundle(
        output_dir,
        mesh.coordinates,
        mesh.topology,
        velocity,
        pressure,
        displacement;
        time=saved_time_s,
        overwrite=overwrite,
    )

    case_spec = Resolved3DCaseSpec(
        case_label,
        mesh.case_spec.severity_percent,
        writer_result.paths.velocity_xdmf;
        pressure_xdmf=writer_result.paths.pressure_xdmf,
        displacement_xdmf=writer_result.paths.displacement_xdmf,
        target_time=saved_time_s,
        time_atol=time_atol,
    )
    bundle = load_resolved3d_field_bundle(case_spec; require_pressure=true, require_displacement=true)
    deformed_field = resolved3d_velocity_field_from_bundle(bundle, "deformed")

    return (
        writer_result=writer_result,
        bundle=bundle,
        loaded_coordinates=Matrix{Float64}(bundle.velocity.coordinates),
        loaded_topology=Matrix{Int}(bundle.velocity.topology),
        loaded_velocity=Matrix{Float64}(bundle.velocity.velocity),
        loaded_pressure=Vector{Float64}(bundle.pressure),
        loaded_displacement=Matrix{Float64}(bundle.displacement),
        loaded_deformed_coordinates=Matrix{Float64}(deformed_field.coordinates),
    )
end

function native_resolved_fsi_smoke_schema_status(bundle, writer_result, deformed_coordinates::Matrix{Float64})
    required_files_exist = all(
        isfile,
        (
            writer_result.paths.mesh_h5,
            writer_result.paths.velocity_xdmf,
            writer_result.paths.velocity_h5,
            writer_result.paths.pressure_xdmf,
            writer_result.paths.pressure_h5,
            writer_result.paths.displacement_xdmf,
            writer_result.paths.displacement_h5,
        ),
    )
    ready = required_files_exist &&
            bundle.pressure !== nothing &&
            bundle.displacement !== nothing &&
            bundle.deformed_coordinates !== nothing &&
            size(deformed_coordinates, 2) == 3
    status = ready ?
        "fixed-wall smoke writer/importer round trip succeeded with required pressure, displacement, and deformed coordinates" :
        "fixed-wall smoke writer/importer round trip is incomplete"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_smoke_geometry_status(
    mesh::NativeResolvedFSIMesh,
    loaded_coordinates::Matrix{Float64},
    loaded_topology::Matrix{Int},
)
    tag_counts = native_resolved_fsi_tag_counts(mesh)
    ready = loaded_coordinates == mesh.coordinates &&
            loaded_topology == mesh.topology &&
            tag_counts.inlet > 0 &&
            tag_counts.outlet > 0 &&
            tag_counts.wall > 0
    status = ready ?
        "reference native mesh geometry/topology reloaded exactly with $(size(mesh.coordinates, 1)) nodes and $(size(mesh.topology, 1)) tetrahedra" :
        "reloaded smoke geometry/topology does not match NativeResolvedFSIMesh"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_smoke_time_status(spec::NativeResolvedFSISmokeSpec, bundle, writer_result)
    pressure_metadata = bundle.pressure_metadata
    displacement_metadata = bundle.displacement_metadata
    ready = abs(writer_result.time - spec.saved_time_s) <= spec.time_atol &&
            abs(bundle.velocity.metadata.time - spec.saved_time_s) <= spec.time_atol &&
            pressure_metadata !== nothing &&
            abs(pressure_metadata.time - spec.saved_time_s) <= spec.time_atol &&
            displacement_metadata !== nothing &&
            abs(displacement_metadata.time - spec.saved_time_s) <= spec.time_atol
    status = ready ?
        "staged fixed-wall smoke bundle saved and reloaded at $(spec.saved_time_s) s" :
        "fixed-wall smoke time metadata does not match the requested saved time"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_navier_stokes_smoke_time_status(
    spec::NativeResolvedFSINavierStokesSmokeSpec,
    bundle,
    writer_result,
)
    pressure_metadata = bundle.pressure_metadata
    displacement_metadata = bundle.displacement_metadata
    ready = abs(writer_result.time - spec.tfinal_s) <= spec.time_atol &&
            abs(bundle.velocity.metadata.time - spec.tfinal_s) <= spec.time_atol &&
            pressure_metadata !== nothing &&
            abs(pressure_metadata.time - spec.tfinal_s) <= spec.time_atol &&
            displacement_metadata !== nothing &&
            abs(displacement_metadata.time - spec.tfinal_s) <= spec.time_atol
    status = ready ?
        "staged fixed-wall Navier-Stokes smoke bundle saved and reloaded at $(spec.tfinal_s) s" :
        "fixed-wall Navier-Stokes smoke time metadata does not match tfinal_s"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_partitioned_smoke_time_status(
    spec::NativeResolvedFSIPartitionedSmokeSpec,
    bundle,
    writer_result,
)
    pressure_metadata = bundle.pressure_metadata
    displacement_metadata = bundle.displacement_metadata
    ready = abs(writer_result.time - spec.tfinal_s) <= spec.time_atol &&
            abs(bundle.velocity.metadata.time - spec.tfinal_s) <= spec.time_atol &&
            pressure_metadata !== nothing &&
            abs(pressure_metadata.time - spec.tfinal_s) <= spec.time_atol &&
            displacement_metadata !== nothing &&
            abs(displacement_metadata.time - spec.tfinal_s) <= spec.time_atol
    status = ready ?
        "staged partitioned smoke bundle saved and reloaded at $(spec.tfinal_s) s" :
        "partitioned smoke time metadata does not match tfinal_s"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_smoke_field_status(
    mesh::NativeResolvedFSIMesh,
    velocity::Matrix{Float64},
    pressure::Vector{Float64},
    displacement::Matrix{Float64},
    deformed_coordinates::Matrix{Float64},
    sampling_fallback_count::Int,
)
    finite_fields = all(isfinite, velocity) && all(isfinite, pressure) && all(isfinite, displacement)
    nontrivial_velocity = maximum(abs, velocity) > 0.0
    nontrivial_pressure = maximum(pressure) > minimum(pressure)
    outlet_pressure_mean = sum(pressure[node] for node in mesh.tags.outlet_nodes) / length(mesh.tags.outlet_nodes)
    outlet_gauge_ok = abs(outlet_pressure_mean) <= 1.0e-9
    zero_displacement_ok = all(iszero, displacement)
    deformed_ok = deformed_coordinates == mesh.coordinates .+ displacement
    ready = finite_fields &&
            nontrivial_velocity &&
            nontrivial_pressure &&
            outlet_gauge_ok &&
            zero_displacement_ok &&
            deformed_ok
    status = ready ?
        "staged stationary Stokes smoke produced finite solver-backed velocity/pressure, outlet-gauge pressure, and explicit zero displacement (vertex fallbacks: $(sampling_fallback_count))" :
        "fixed-wall Stokes smoke field checks failed"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_navier_stokes_smoke_field_status(
    mesh::NativeResolvedFSIMesh,
    velocity::Matrix{Float64},
    pressure::Vector{Float64},
    displacement::Matrix{Float64},
    deformed_coordinates::Matrix{Float64},
    sampling_fallback_count::Int,
    time_step_count::Int,
    max_picard_iterations_used::Int,
    final_picard_update_norm::Float64,
    picard_converged::Bool,
)
    finite_fields = all(isfinite, velocity) && all(isfinite, pressure) && all(isfinite, displacement)
    nontrivial_velocity = maximum(abs, velocity) > 0.0
    nontrivial_pressure = maximum(pressure) > minimum(pressure)
    outlet_pressure_mean = sum(pressure[node] for node in mesh.tags.outlet_nodes) / length(mesh.tags.outlet_nodes)
    outlet_gauge_ok = abs(outlet_pressure_mean) <= 1.0e-9
    zero_displacement_ok = all(iszero, displacement)
    deformed_ok = deformed_coordinates == mesh.coordinates .+ displacement
    iteration_summary_ok = time_step_count > 0 &&
                           max_picard_iterations_used > 0 &&
                           isfinite(final_picard_update_norm)
    ready = finite_fields &&
            nontrivial_velocity &&
            nontrivial_pressure &&
            outlet_gauge_ok &&
            zero_displacement_ok &&
            deformed_ok &&
            iteration_summary_ok &&
            picard_converged
    status = ready ?
        "staged fixed-wall incompressible Navier-Stokes smoke used backward-Euler steps with Picard-linearized convection, finite solver-backed velocity/pressure, outlet-gauge pressure, and explicit zero displacement (steps: $(time_step_count), max Picard iterations: $(max_picard_iterations_used), final update norm: $(final_picard_update_norm), vertex fallbacks: $(sampling_fallback_count))" :
        "fixed-wall Navier-Stokes smoke field checks failed or Picard iterations hit the configured cap"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_partitioned_smoke_field_status(
    mesh::NativeResolvedFSIMesh,
    velocity::Matrix{Float64},
    pressure::Vector{Float64},
    displacement::Matrix{Float64},
    deformed_coordinates::Matrix{Float64},
    wall_displacement_cm::Vector{Float64},
    wall_velocity_cm_s::Vector{Float64},
    wall_pressure_dyn_cm2::Vector{Float64},
    current_radii_cm::Vector{Float64},
    sampling_fallback_count::Int,
    pressure_projection_fallback_count::Int,
    time_step_count::Int,
    max_picard_iterations_used::Int,
    final_picard_update_norm::Float64,
    picard_converged::Bool,
    max_coupling_iterations_used::Int,
    final_coupling_displacement_residual_cm::Float64,
    coupling_converged::Bool,
    fluid_wall_boundary_mode::Symbol,
    minimum_current_radius_cm::Float64,
    minimum_signed_tetra_volume6::Float64,
    post_update_fluid_refresh::Bool,
)
    finite_fields = all(isfinite, velocity) &&
                    all(isfinite, pressure) &&
                    all(isfinite, displacement) &&
                    all(isfinite, wall_displacement_cm) &&
                    all(isfinite, wall_velocity_cm_s) &&
                    all(isfinite, wall_pressure_dyn_cm2) &&
                    all(isfinite, current_radii_cm)
    nontrivial_velocity = maximum(abs, velocity) > 0.0
    nontrivial_pressure = maximum(pressure) > minimum(pressure)
    nontrivial_displacement = maximum(abs, displacement) > 0.0 && maximum(abs, wall_displacement_cm) > 0.0
    clamped_endpoints_ok = !isempty(wall_displacement_cm) &&
                           iszero(wall_displacement_cm[begin]) &&
                           iszero(wall_displacement_cm[end]) &&
                           iszero(wall_velocity_cm_s[begin]) &&
                           iszero(wall_velocity_cm_s[end])
    outlet_pressure_mean = sum(pressure[node] for node in mesh.tags.outlet_nodes) / length(mesh.tags.outlet_nodes)
    outlet_gauge_ok = abs(outlet_pressure_mean) <= 1.0e-9
    positive_radius_ok = minimum_current_radius_cm > 0.0
    positive_tetra_ok = minimum_signed_tetra_volume6 > 0.0
    deformed_ok = deformed_coordinates == mesh.coordinates .+ displacement
    iteration_summary_ok = time_step_count > 0 &&
                           max_picard_iterations_used > 0 &&
                           isfinite(final_picard_update_norm)
    coupling_summary_ok = max_coupling_iterations_used > 0 &&
                          isfinite(final_coupling_displacement_residual_cm) &&
                          fluid_wall_boundary_mode === NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_FLUID_WALL_BOUNDARY_MODE
    ready = finite_fields &&
            nontrivial_velocity &&
            nontrivial_pressure &&
            nontrivial_displacement &&
            clamped_endpoints_ok &&
            outlet_gauge_ok &&
            positive_radius_ok &&
            positive_tetra_ok &&
            deformed_ok &&
            iteration_summary_ok &&
            coupling_summary_ok &&
            picard_converged &&
            post_update_fluid_refresh
    status = ready ?
        "staged partitioned prescribed radial wall-velocity Dirichlet smoke used lagged explicit membrane updates with R_ref = p.rmax, a post-update fluid refresh on deformed geometry, finite solver-backed velocity/pressure, nonzero clamped displacement, positive radii, and non-inverted tetrahedra (coupled steps: $(time_step_count), max coupling iterations used: $(max_coupling_iterations_used), final coupling displacement residual: $(final_coupling_displacement_residual_cm), coupling converged: $(coupling_converged), max Picard iterations: $(max_picard_iterations_used), final update norm: $(final_picard_update_norm), wall-pressure projection fallbacks: $(pressure_projection_fallback_count), vertex fallbacks: $(sampling_fallback_count))" :
        "partitioned smoke field checks failed, prescribed wall-velocity boundary metadata was incomplete, radii became non-positive, tetrahedra inverted, or the staged fluid refresh did not converge"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end
