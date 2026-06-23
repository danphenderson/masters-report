const NativeResolvedFSIMeshResolution = StenoticHemodynamics.NativeResolvedFSIMeshResolution
const NativeResolvedFSISmokeResult = StenoticHemodynamics.NativeResolvedFSISmokeResult
const NativeResolvedFSISmokeSpec = StenoticHemodynamics.NativeResolvedFSISmokeSpec
const NativeResolvedFSIWorkflowStatus = StenoticHemodynamics.NativeResolvedFSIWorkflowStatus
const default_native_resolved_fsi_smoke_output_dir = StenoticHemodynamics.default_native_resolved_fsi_smoke_output_dir
const native_resolved_fsi_smoke_spec = StenoticHemodynamics.native_resolved_fsi_smoke_spec
const run_native_resolved_fsi_smoke = StenoticHemodynamics.run_native_resolved_fsi_smoke

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
