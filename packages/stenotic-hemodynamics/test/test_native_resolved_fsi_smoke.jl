const NativeResolvedFSIMeshResolution = StenoticHemodynamics.NativeResolvedFSIMeshResolution
const NativeResolvedFSINavierStokesSmokeResult = StenoticHemodynamics.NativeResolvedFSINavierStokesSmokeResult
const NativeResolvedFSINavierStokesSmokeSpec = StenoticHemodynamics.NativeResolvedFSINavierStokesSmokeSpec
const NativeResolvedFSIPartitionedSmokeResult = StenoticHemodynamics.NativeResolvedFSIPartitionedSmokeResult
const NativeResolvedFSIPartitionedSmokeSpec = StenoticHemodynamics.NativeResolvedFSIPartitionedSmokeSpec
const NativeResolvedFSISmokeResult = StenoticHemodynamics.NativeResolvedFSISmokeResult
const NativeResolvedFSISmokeSpec = StenoticHemodynamics.NativeResolvedFSISmokeSpec
const NativeResolvedFSIWorkflowStatus = StenoticHemodynamics.NativeResolvedFSIWorkflowStatus
const default_native_resolved_fsi_navier_stokes_smoke_output_dir =
    StenoticHemodynamics.default_native_resolved_fsi_navier_stokes_smoke_output_dir
const default_native_resolved_fsi_partitioned_smoke_output_dir =
    StenoticHemodynamics.default_native_resolved_fsi_partitioned_smoke_output_dir
const default_native_resolved_fsi_smoke_output_dir = StenoticHemodynamics.default_native_resolved_fsi_smoke_output_dir
const native_resolved_fsi_navier_stokes_smoke_spec = StenoticHemodynamics.native_resolved_fsi_navier_stokes_smoke_spec
const native_resolved_fsi_partitioned_smoke_spec = StenoticHemodynamics.native_resolved_fsi_partitioned_smoke_spec
const native_resolved_fsi_mesh = StenoticHemodynamics.native_resolved_fsi_mesh
const native_resolved_fsi_radial_wall_velocity_function =
    StenoticHemodynamics.native_resolved_fsi_radial_wall_velocity_function
const native_resolved_fsi_smoke_spec = StenoticHemodynamics.native_resolved_fsi_smoke_spec
const run_native_resolved_fsi_navier_stokes_smoke = StenoticHemodynamics.run_native_resolved_fsi_navier_stokes_smoke
const run_native_resolved_fsi_partitioned_smoke = StenoticHemodynamics.run_native_resolved_fsi_partitioned_smoke
const run_native_resolved_fsi_smoke = StenoticHemodynamics.run_native_resolved_fsi_smoke

@testset "StenoticHemodynamics native resolved-FSI radial wall velocity helper" begin
    resolution = NativeResolvedFSIMeshResolution(axial=2, radial=1, angular=6)
    mesh = native_resolved_fsi_mesh(:sev23, resolution)
    length_cm = mesh.case_spec.length_cm

    centerline_velocity = native_resolved_fsi_radial_wall_velocity_function(mesh, _ -> error("profile should not be sampled"))(
        (0.0, 0.0, 0.5 * length_cm),
    )
    @test centerline_velocity[1] == 0.0
    @test centerline_velocity[2] == 0.0
    @test centerline_velocity[3] == 0.0

    sampled_z = Float64[]
    clamped_velocity = native_resolved_fsi_radial_wall_velocity_function(mesh, z -> begin
        push!(sampled_z, z)
        1.0
    end)
    clamped_velocity((mesh.case_spec.rmax_cm, 0.0, -1.0))
    clamped_velocity((mesh.case_spec.rmax_cm, 0.0, length_cm + 1.0))
    @test sampled_z == [0.0, length_cm]

    @test_throws ArgumentError native_resolved_fsi_radial_wall_velocity_function(mesh, _ -> Inf)(
        (mesh.case_spec.rmax_cm, 0.0, 0.5 * length_cm),
    )
    @test_throws ArgumentError native_resolved_fsi_radial_wall_velocity_function(mesh, _ -> NaN)(
        (mesh.case_spec.rmax_cm, 0.0, 0.5 * length_cm),
    )

    wall_node_index = findfirst(
        node ->
            isapprox(mesh.coordinates[node, 3], 0.5 * length_cm; atol=1.0e-12) &&
                abs(mesh.coordinates[node, 1]) > 1.0e-12 &&
                abs(mesh.coordinates[node, 2]) > 1.0e-12,
        mesh.tags.wall_nodes,
    )
    @test wall_node_index !== nothing
    wall_point = mesh.coordinates[mesh.tags.wall_nodes[wall_node_index], :]
    radial_distance = hypot(wall_point[1], wall_point[2])
    outward_velocity = native_resolved_fsi_radial_wall_velocity_function(mesh, _ -> 2.5)(wall_point)
    inward_velocity = native_resolved_fsi_radial_wall_velocity_function(mesh, _ -> -1.25)(wall_point)

    @test outward_velocity[1] ≈ 2.5 * wall_point[1] / radial_distance
    @test outward_velocity[2] ≈ 2.5 * wall_point[2] / radial_distance
    @test outward_velocity[3] == 0.0
    @test inward_velocity[1] ≈ -1.25 * wall_point[1] / radial_distance
    @test inward_velocity[2] ≈ -1.25 * wall_point[2] / radial_distance
    @test inward_velocity[3] == 0.0
end

@testset "StenoticHemodynamics native resolved-FSI fixed-wall Stokes smoke" begin
    resolution = NativeResolvedFSIMeshResolution(axial=2, radial=1, angular=6)
    default_spec = native_resolved_fsi_smoke_spec(case_id=:sev23, resolution=resolution)
    @test default_spec isa NativeResolvedFSISmokeSpec
    @test default_spec.saved_time_s ≈ 1.0 atol=1.0e-12
    @test default_native_resolved_fsi_smoke_output_dir(default_spec) ==
          joinpath("tmp", "simulations", "output", "native-resolved-fsi-smoke", "sev23", "2x1x6", "fixed-wall-stokes-t1")

    @test_throws ArgumentError NativeResolvedFSISmokeSpec(saved_time_s=0.0)
    @test_throws ArgumentError NativeResolvedFSISmokeSpec(pressure_drop_dyn_cm2=0.0)

    mktempdir() do dir
        spec = NativeResolvedFSISmokeSpec(
            case_id=:sev23,
            resolution=resolution,
            output_dir=joinpath(dir, "smoke-bundle"),
            saved_time_s=1.0,
            time_atol=1.0e-12,
            pressure_drop_dyn_cm2=40.0,
        )
        result = run_native_resolved_fsi_smoke(spec)

        @test result isa NativeResolvedFSISmokeResult
        @test result.schema_status isa NativeResolvedFSIWorkflowStatus
        @test result.geometry_status.ready
        @test result.schema_status.ready
        @test result.time_status.ready
        @test result.field_status.ready
        @test result.fluid_model == :fixed_wall_stokes
        @test result.velocity_dofs > 0
        @test result.pressure_dofs > 0
        @test result.saved_time_s ≈ 1.0 atol=1.0e-12
        @test result.output_dir == joinpath(dir, "smoke-bundle")
        @test result.estimated_field_payload_bytes == size(result.mesh.coordinates, 1) * 7 * sizeof(Float64)
        @test isfile(result.mesh_h5)
        @test isfile(result.velocity_xdmf)
        @test isfile(result.velocity_h5)
        @test isfile(result.pressure_xdmf)
        @test isfile(result.pressure_h5)
        @test isfile(result.displacement_xdmf)
        @test isfile(result.displacement_h5)
        @test result.loaded_coordinates == result.mesh.coordinates
        @test result.loaded_topology == result.mesh.topology
        @test result.loaded_deformed_coordinates == result.mesh.coordinates
        @test all(iszero, result.loaded_displacement)
        @test all(isfinite, result.loaded_velocity)
        @test all(isfinite, result.loaded_pressure)
        @test maximum(abs, result.loaded_velocity) > 0.0
        @test maximum(result.loaded_pressure) > minimum(result.loaded_pressure)

        outlet_pressure_mean =
            sum(result.loaded_pressure[node] for node in result.mesh.tags.outlet_nodes) / length(result.mesh.tags.outlet_nodes)
        @test abs(outlet_pressure_mean) <= 1.0e-9
        @test result.sampling_fallback_count >= 0
        @test occursin("Stokes", result.field_status.status)
        @test occursin("required pressure, displacement", result.schema_status.status)
    end
end

@testset "StenoticHemodynamics native resolved-FSI staged partitioned smoke" begin
    resolution = NativeResolvedFSIMeshResolution(axial=2, radial=1, angular=6)
    default_spec = native_resolved_fsi_partitioned_smoke_spec(case_id=:sev23, resolution=resolution)
    @test default_spec isa NativeResolvedFSIPartitionedSmokeSpec
    @test default_spec.dt_s ≈ 1.0e-4 atol=1.0e-12
    @test default_spec.tfinal_s ≈ 1.0e-4 atol=1.0e-12
    @test default_spec.coupling_iteration_count == 1
    @test default_spec.coupling_tolerance ≈ 1.0e-8
    @test default_spec.coupling_under_relaxation ≈ 1.0
    @test default_native_resolved_fsi_partitioned_smoke_output_dir(default_spec) ==
          joinpath(
        "tmp",
        "simulations",
        "output",
        "native-resolved-fsi-smoke",
        "sev23",
        "2x1x6",
        "partitioned-dt0p0001-tfinal0p0001",
    )

    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(dt_s=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(tfinal_s=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(picard_iteration_count=0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(picard_tolerance=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(wall_density_g_cm3=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(wall_damping_g_cm2_s=-1.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(pressure_drop_dyn_cm2=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(coupling_iteration_count=0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(coupling_tolerance=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(coupling_under_relaxation=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedSmokeSpec(coupling_under_relaxation=1.01)

    mktempdir() do dir
        spec = NativeResolvedFSIPartitionedSmokeSpec(
            case_id=:sev23,
            resolution=resolution,
            output_dir=joinpath(dir, "partitioned-smoke-bundle"),
            dt_s=1.0e-4,
            tfinal_s=1.0e-4,
            time_atol=1.0e-12,
            pressure_drop_dyn_cm2=40.0,
            picard_iteration_count=8,
            picard_tolerance=1.0e-8,
            wall_density_g_cm3=1.0,
            wall_damping_g_cm2_s=0.0,
            coupling_iteration_count=2,
            coupling_tolerance=1.0e-30,
            coupling_under_relaxation=0.5,
        )
        result = run_native_resolved_fsi_partitioned_smoke(spec)

        @test result isa NativeResolvedFSIPartitionedSmokeResult
        @test result.schema_status isa NativeResolvedFSIWorkflowStatus
        @test result.geometry_status.ready
        @test result.schema_status.ready
        @test result.time_status.ready
        @test result.field_status.ready
        @test occursin("prescribed radial wall-velocity Dirichlet", result.field_status.status)
        @test !occursin("fixed-wall", result.field_status.status)
        @test !occursin("ALE", result.field_status.status)
        @test !occursin("fixed-wall-fluid", result.field_status.status)
        @test result.fluid_model == :partitioned_prescribed_wall_velocity_iterated_wall_output_smoke
        @test result.velocity_dofs > 0
        @test result.pressure_dofs > 0
        @test result.time_step_count == 1
        @test 1 <= result.max_picard_iterations_used <= spec.picard_iteration_count
        @test result.picard_converged
        @test result.max_coupling_iterations_used == spec.coupling_iteration_count
        @test isfinite(result.final_coupling_displacement_residual_cm)
        @test result.final_coupling_displacement_residual_cm >= 0.0
        @test !result.coupling_converged
        @test result.fluid_wall_boundary_mode == :prescribed_radial_wall_velocity
        @test length(result.coupling_residual_history) == result.time_step_count * spec.coupling_iteration_count
        @test [row.coupling_iteration for row in result.coupling_residual_history] == [1, 2]
        @test all(row -> row.under_relaxation ≈ spec.coupling_under_relaxation, result.coupling_residual_history)
        @test all(
            row -> row.fluid_wall_boundary_mode == "prescribed_radial_wall_velocity",
            result.coupling_residual_history,
        )
        @test result.post_update_fluid_refresh
        @test isfinite(result.final_picard_update_norm)
        @test result.final_picard_update_norm >= 0.0
        @test result.saved_time_s ≈ spec.tfinal_s atol=1.0e-12
        @test result.output_dir == joinpath(dir, "partitioned-smoke-bundle")
        @test result.wall_mass_g_cm2 > 0.0
        @test result.wall_stiffness_c0_dyn_cm3 > 0.0
        @test result.stability_dt_limit_s >= spec.dt_s
        @test result.minimum_current_radius_cm > 0.0
        @test result.minimum_signed_tetra_volume6 > 0.0
        @test result.pressure_projection_fallback_count >= 0
        @test result.sampling_fallback_count >= 0
        @test result.estimated_field_payload_bytes == size(result.mesh.coordinates, 1) * 7 * sizeof(Float64)
        @test isfile(result.mesh_h5)
        @test isfile(result.velocity_xdmf)
        @test isfile(result.velocity_h5)
        @test isfile(result.pressure_xdmf)
        @test isfile(result.pressure_h5)
        @test isfile(result.displacement_xdmf)
        @test isfile(result.displacement_h5)
        @test result.loaded_coordinates == result.mesh.coordinates
        @test result.loaded_topology == result.mesh.topology
        @test result.loaded_deformed_coordinates == result.mesh.coordinates .+ result.loaded_displacement
        @test result.loaded_deformed_coordinates != result.mesh.coordinates
        @test all(isfinite, result.loaded_displacement)
        @test maximum(abs, result.loaded_displacement) > 0.0
        @test all(isfinite, result.loaded_velocity)
        @test all(isfinite, result.loaded_pressure)
        @test maximum(abs, result.loaded_velocity) > 0.0
        @test maximum(result.loaded_pressure) > minimum(result.loaded_pressure)
        @test result.wall_displacement_cm[begin] == 0.0
        @test result.wall_displacement_cm[end] == 0.0
        @test result.wall_velocity_cm_s[begin] == 0.0
        @test result.wall_velocity_cm_s[end] == 0.0
        @test maximum(abs, result.wall_displacement_cm) > 0.0
        @test maximum(abs, result.wall_velocity_cm_s) > 0.0
        @test minimum(result.current_radii_cm) > 0.0

        outlet_pressure_mean =
            sum(result.loaded_pressure[node] for node in result.mesh.tags.outlet_nodes) / length(result.mesh.tags.outlet_nodes)
        @test abs(outlet_pressure_mean) <= 1.0e-9
        @test occursin("partitioned", lowercase(result.field_status.status))
        @test occursin("R_ref = p.rmax", result.field_status.status)
        @test occursin("required pressure, displacement", result.schema_status.status)
    end
end

@testset "StenoticHemodynamics native resolved-FSI fixed-wall Navier-Stokes smoke" begin
    resolution = NativeResolvedFSIMeshResolution(axial=2, radial=1, angular=6)
    default_spec = native_resolved_fsi_navier_stokes_smoke_spec(case_id=:sev23, resolution=resolution)
    @test default_spec isa NativeResolvedFSINavierStokesSmokeSpec
    @test default_spec.dt_s ≈ 0.25 atol=1.0e-12
    @test default_spec.tfinal_s ≈ 1.0 atol=1.0e-12
    @test default_native_resolved_fsi_navier_stokes_smoke_output_dir(default_spec) ==
          joinpath(
        "tmp",
        "simulations",
        "output",
        "native-resolved-fsi-smoke",
        "sev23",
        "2x1x6",
        "fixed-wall-navier-stokes-dt0p25-tfinal1",
    )

    @test_throws ArgumentError NativeResolvedFSINavierStokesSmokeSpec(dt_s=0.0)
    @test_throws ArgumentError NativeResolvedFSINavierStokesSmokeSpec(tfinal_s=0.0)
    @test_throws ArgumentError NativeResolvedFSINavierStokesSmokeSpec(picard_iteration_count=0)
    @test_throws ArgumentError NativeResolvedFSINavierStokesSmokeSpec(picard_tolerance=0.0)
    @test_throws ArgumentError NativeResolvedFSINavierStokesSmokeSpec(pressure_drop_dyn_cm2=0.0)

    mktempdir() do dir
        spec = NativeResolvedFSINavierStokesSmokeSpec(
            case_id=:sev23,
            resolution=resolution,
            output_dir=joinpath(dir, "navier-stokes-smoke-bundle"),
            dt_s=0.5,
            tfinal_s=1.0,
            time_atol=1.0e-12,
            pressure_drop_dyn_cm2=40.0,
            picard_iteration_count=8,
            picard_tolerance=1.0e-8,
        )
        result = run_native_resolved_fsi_navier_stokes_smoke(spec)

        @test result isa NativeResolvedFSINavierStokesSmokeResult
        @test result.schema_status isa NativeResolvedFSIWorkflowStatus
        @test result.geometry_status.ready
        @test result.schema_status.ready
        @test result.time_status.ready
        @test result.field_status.ready
        @test result.fluid_model == :fixed_wall_navier_stokes_backward_euler_picard
        @test result.velocity_dofs > 0
        @test result.pressure_dofs > 0
        @test result.time_step_count == 2
        @test 1 <= result.max_picard_iterations_used <= spec.picard_iteration_count
        @test result.picard_converged
        @test isfinite(result.final_picard_update_norm)
        @test result.final_picard_update_norm >= 0.0
        @test result.saved_time_s ≈ 1.0 atol=1.0e-12
        @test result.output_dir == joinpath(dir, "navier-stokes-smoke-bundle")
        @test result.estimated_field_payload_bytes == size(result.mesh.coordinates, 1) * 7 * sizeof(Float64)
        @test isfile(result.mesh_h5)
        @test isfile(result.velocity_xdmf)
        @test isfile(result.velocity_h5)
        @test isfile(result.pressure_xdmf)
        @test isfile(result.pressure_h5)
        @test isfile(result.displacement_xdmf)
        @test isfile(result.displacement_h5)
        @test result.loaded_coordinates == result.mesh.coordinates
        @test result.loaded_topology == result.mesh.topology
        @test result.loaded_deformed_coordinates == result.mesh.coordinates
        @test all(iszero, result.loaded_displacement)
        @test all(isfinite, result.loaded_velocity)
        @test all(isfinite, result.loaded_pressure)
        @test maximum(abs, result.loaded_velocity) > 0.0
        @test maximum(result.loaded_pressure) > minimum(result.loaded_pressure)

        outlet_pressure_mean =
            sum(result.loaded_pressure[node] for node in result.mesh.tags.outlet_nodes) / length(result.mesh.tags.outlet_nodes)
        @test abs(outlet_pressure_mean) <= 1.0e-9
        @test result.sampling_fallback_count >= 0
        @test occursin("Navier-Stokes", result.field_status.status)
        @test occursin("backward-Euler", result.field_status.status)
        @test occursin("required pressure, displacement", result.schema_status.status)
    end
end
