const NativeResolvedFSIWorkflowSpec = StenoticHemodynamics.NativeResolvedFSIWorkflowSpec
const NativeResolvedFSIWorkflowResult = StenoticHemodynamics.NativeResolvedFSIWorkflowResult
const NativeResolvedFSIMeshResolution = StenoticHemodynamics.NativeResolvedFSIMeshResolution
const NativeResolvedFSIWorkflowStatus = StenoticHemodynamics.NativeResolvedFSIWorkflowStatus
const default_native_resolved_fsi_output_dir = StenoticHemodynamics.default_native_resolved_fsi_output_dir
const native_resolved_fsi_case_spec = StenoticHemodynamics.native_resolved_fsi_case_spec
const native_resolved_fsi_lifted_displacement = StenoticHemodynamics.native_resolved_fsi_lifted_displacement
const native_resolved_fsi_mesh = StenoticHemodynamics.native_resolved_fsi_mesh
const native_resolved_fsi_synthetic_wall_lift = StenoticHemodynamics.native_resolved_fsi_synthetic_wall_lift
const native_resolved_fsi_zero_displacement = StenoticHemodynamics.native_resolved_fsi_zero_displacement
const run_native_resolved_fsi = StenoticHemodynamics.run_native_resolved_fsi
const run_native_resolved_fsi_workflow = StenoticHemodynamics.run_native_resolved_fsi_workflow

@testset "StenoticHemodynamics native resolved-FSI workflow helpers" begin
    mesh = native_resolved_fsi_mesh(:sev23, NativeResolvedFSIMeshResolution(axial=2, radial=2, angular=8))

    zero_displacement = native_resolved_fsi_zero_displacement(mesh)
    @test size(zero_displacement) == size(mesh.coordinates)
    @test all(iszero, zero_displacement)

    wall_lift = native_resolved_fsi_synthetic_wall_lift(mesh; amplitude_cm=0.003)
    @test length(wall_lift) == length(mesh.geometry.axial_coordinates_cm)
    @test wall_lift[1] == 0.0
    @test wall_lift[end] == 0.0
    @test maximum(wall_lift) > 0.0

    lifted_displacement = native_resolved_fsi_lifted_displacement(mesh, wall_lift)
    @test size(lifted_displacement) == size(mesh.coordinates)
    @test maximum(abs, lifted_displacement) > 0.0
    @test all(iszero, lifted_displacement[node, component] for node in mesh.tags.inlet_nodes for component in 1:3)
    @test all(iszero, lifted_displacement[node, component] for node in mesh.tags.outlet_nodes for component in 1:3)
end

@testset "StenoticHemodynamics native resolved-FSI workflow round trip" begin
    resolution = NativeResolvedFSIMeshResolution(axial=2, radial=2, angular=8)
    default_spec = NativeResolvedFSIWorkflowSpec(case_id=:sev23, resolution=resolution)
    @test default_spec.output_time_s ≈ 1.0 atol=1.0e-12
    @test default_native_resolved_fsi_output_dir(default_spec) ==
          joinpath("tmp", "simulations", "output", "native-resolved-fsi", "sev23", "2x2x8", "zero-displacement-t1")

    mktempdir() do dir
        zero_spec = NativeResolvedFSIWorkflowSpec(
            case_id=:sev23,
            resolution=resolution,
            output_dir=joinpath(dir, "zero-bundle"),
            output_time_s=1.0,
            time_atol=1.0e-12,
            displacement_mode=:zero,
        )
        zero_result = run_native_resolved_fsi_workflow(zero_spec)

        @test zero_result isa NativeResolvedFSIWorkflowResult
        @test zero_result.schema_status isa NativeResolvedFSIWorkflowStatus
        @test zero_result.geometry_status.ready
        @test zero_result.schema_status.ready
        @test zero_result.time_status.ready
        @test zero_result.field_status.ready
        @test !zero_result.operator_status.ready
        @test occursin("deferred", zero_result.operator_status.status)
        @test zero_result.saved_time_s ≈ 1.0 atol=1.0e-12
        @test zero_result.output_dir == joinpath(dir, "zero-bundle")
        @test isfile(zero_result.mesh_h5)
        @test isfile(zero_result.velocity_xdmf)
        @test isfile(zero_result.velocity_h5)
        @test isfile(zero_result.pressure_xdmf)
        @test isfile(zero_result.pressure_h5)
        @test isfile(zero_result.displacement_xdmf)
        @test isfile(zero_result.displacement_h5)
        @test zero_result.loaded_coordinates == zero_result.mesh.coordinates
        @test zero_result.loaded_topology == zero_result.mesh.topology
        @test zero_result.loaded_deformed_coordinates == zero_result.mesh.coordinates
        @test all(iszero, zero_result.loaded_displacement)
        @test all(velocity[1] == 0.0 && velocity[2] == 0.0 for velocity in eachrow(zero_result.loaded_velocity))
        @test zero_result.boundary_tag_names == (:inlet, :outlet, :wall, :interior)
        @test zero_result.boundary_face_counts.interior == size(zero_result.mesh.topology, 1)
    end

    mktempdir() do dir
        lifted_spec = NativeResolvedFSIWorkflowSpec(
            case_id=:sev40,
            resolution=resolution,
            output_dir=joinpath(dir, "lifted-bundle"),
            output_time_s=1.0,
            time_atol=1.0e-12,
            displacement_mode=:synthetic_radial_lift,
            synthetic_lift_amplitude_cm=0.004,
        )
        lifted_result = run_native_resolved_fsi(lifted_spec)

        @test lifted_result.schema_status.ready
        @test lifted_result.geometry_status.ready
        @test lifted_result.time_status.ready
        @test lifted_result.field_status.ready
        @test maximum(abs, lifted_result.loaded_displacement) > 0.0
        @test lifted_result.loaded_deformed_coordinates == lifted_result.mesh.coordinates .+ lifted_result.loaded_displacement
        @test all(iszero, lifted_result.loaded_displacement[node, component] for node in lifted_result.mesh.tags.inlet_nodes for component in 1:3)
        @test all(iszero, lifted_result.loaded_displacement[node, component] for node in lifted_result.mesh.tags.outlet_nodes for component in 1:3)
        @test occursin("schema-only", lifted_result.field_status.status)
    end
end
