const NativeResolvedFSIParityResult = StenoticHemodynamics.NativeResolvedFSIParityResult
const NativeResolvedFSIParitySpec = StenoticHemodynamics.NativeResolvedFSIParitySpec
const NativeResolvedFSIParityStatus = StenoticHemodynamics.NativeResolvedFSIParityStatus
const Resolved3DCaseSpec = StenoticHemodynamics.Resolved3DCaseSpec
const run_native_resolved_fsi_parity = StenoticHemodynamics.run_native_resolved_fsi_parity
const write_resolved3d_field_bundle = StenoticHemodynamics.write_resolved3d_field_bundle

function native_resolved_fsi_parity_fixture(;
    coordinate_shift_cm::Real = 0.0,
    velocity_offset_cm_s::Real = 0.0,
    pressure_offset_dyn_cm2::Real = 0.0,
    displacement_offset_cm::Real = 0.0,
)
    coordinates = [
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        0.0 0.0 1.0
    ]
    coordinates[2, 1] += Float64(coordinate_shift_cm)

    topology = Int[
        1 2 3 4
    ]

    velocity = [
        0.0 0.0 10.0
        0.0 0.0 11.0
        0.0 0.0 12.0
        0.0 0.0 13.0
    ]
    velocity[:, 3] .+= Float64(velocity_offset_cm_s)

    pressure = Float64[20.0, 21.0, 22.0, 23.0] .+ Float64(pressure_offset_dyn_cm2)

    displacement = [
        0.0 0.0 0.0
        0.05 0.0 0.0
        0.0 0.05 0.0
        0.0 0.0 0.02
    ]
    displacement[2, 1] += Float64(displacement_offset_cm)

    return coordinates, topology, velocity, pressure, displacement
end

function write_native_resolved_fsi_parity_fixture(
    dir::AbstractString,
    bundle_name::AbstractString;
    time_s::Real = 1.0,
    coordinate_shift_cm::Real = 0.0,
    velocity_offset_cm_s::Real = 0.0,
    pressure_offset_dyn_cm2::Real = 0.0,
    displacement_offset_cm::Real = 0.0,
)
    coordinates, topology, velocity, pressure, displacement = native_resolved_fsi_parity_fixture(
        coordinate_shift_cm=coordinate_shift_cm,
        velocity_offset_cm_s=velocity_offset_cm_s,
        pressure_offset_dyn_cm2=pressure_offset_dyn_cm2,
        displacement_offset_cm=displacement_offset_cm,
    )
    output_dir = joinpath(dir, bundle_name)
    write_resolved3d_field_bundle(
        output_dir,
        coordinates,
        topology,
        velocity,
        pressure,
        displacement;
        time=time_s,
    )
    return Resolved3DCaseSpec(
        bundle_name,
        23.0,
        joinpath(output_dir, "velocity.xdmf");
        pressure_xdmf=joinpath(output_dir, "pressure.xdmf"),
        displacement_xdmf=joinpath(output_dir, "displace.xdmf"),
        target_time=time_s,
        time_atol=1.0e-12,
    )
end

function native_resolved_fsi_parity_spec(native_case::Resolved3DCaseSpec, imported_case::Resolved3DCaseSpec; require_imported::Bool = false)
    return NativeResolvedFSIParitySpec(
        native_case,
        imported_case;
        require_imported=require_imported,
        coordinate_mode="deformed",
        sample_z_cm=[0.25, 0.5, 0.75],
        radial_profile_z_cm=[0.5],
        radial_bin_count=3,
        node_slab_half_widths_cm=[0.6],
        geometry_atol_cm=1.0e-12,
        time_atol_s=1.0e-12,
        velocity_atol_cm_s=1.0e-12,
        pressure_atol_dyn_cm2=1.0e-12,
        displacement_atol_cm=1.0e-12,
        operator_atol=1.0e-12,
    )
end

@testset "StenoticHemodynamics native resolved-FSI parity exact fixture" begin
    mktempdir() do dir
        native_case = write_native_resolved_fsi_parity_fixture(dir, "native")
        imported_case = write_native_resolved_fsi_parity_fixture(dir, "imported")
        result = run_native_resolved_fsi_parity(native_resolved_fsi_parity_spec(native_case, imported_case))

        @test result isa NativeResolvedFSIParityResult
        @test result.native_bundle !== nothing
        @test result.imported_bundle !== nothing
        @test result.native_operator_field !== nothing
        @test result.imported_operator_field !== nothing
        @test result.schema_status isa NativeResolvedFSIParityStatus
        @test result.schema_status.ready
        @test result.geometry_status.ready
        @test result.time_status.ready
        @test result.velocity_status.ready
        @test result.pressure_status.ready
        @test result.displacement_status.ready
        @test result.native_operator_field.coordinates == result.native_bundle.deformed_coordinates
        @test result.imported_operator_field.coordinates == result.imported_bundle.deformed_coordinates

        @test !result.operator_status.ready
        @test !result.operator_status.skipped
        @test result.operator_status.discrepancy_count == 0
        @test result.operator_status.max_abs_difference ≈ 0.0 atol = 1.0e-12
        @test occursin("deferred", result.operator_status.status)
        @test occursin("pressure/displacement", result.operator_status.status)
        @test occursin("Section 4.1", result.operator_status.status)
    end
end

@testset "StenoticHemodynamics native resolved-FSI parity discrepancy categories" begin
    mktempdir() do dir
        native_case = write_native_resolved_fsi_parity_fixture(dir, "native"; time_s=1.0)
        imported_case = write_native_resolved_fsi_parity_fixture(
            dir,
            "imported";
            time_s=1.25,
            coordinate_shift_cm=0.01,
            velocity_offset_cm_s=0.5,
            pressure_offset_dyn_cm2=3.0,
            displacement_offset_cm=0.01,
        )
        result = run_native_resolved_fsi_parity(native_resolved_fsi_parity_spec(native_case, imported_case))

        @test result.schema_status.ready

        @test !result.geometry_status.ready
        @test result.geometry_status.discrepancy_count > 0
        @test result.geometry_status.max_abs_difference ≈ 0.01 atol = 1.0e-12

        @test !result.time_status.ready
        @test result.time_status.discrepancy_count == 3
        @test result.time_status.max_abs_difference ≈ 0.25 atol = 1.0e-12

        @test !result.velocity_status.ready
        @test result.velocity_status.discrepancy_count == 4
        @test result.velocity_status.max_abs_difference ≈ 0.5 atol = 1.0e-12

        @test !result.pressure_status.ready
        @test result.pressure_status.discrepancy_count == 4
        @test result.pressure_status.max_abs_difference ≈ 3.0 atol = 1.0e-12

        @test !result.displacement_status.ready
        @test result.displacement_status.discrepancy_count > 0
        @test result.displacement_status.max_abs_difference ≈ 0.02 atol = 1.0e-12

        @test !result.operator_status.ready
        @test !result.operator_status.skipped
        @test result.operator_status.discrepancy_count > 0
        @test result.operator_status.max_abs_difference > 0.0
        @test occursin("velocity observation parity", result.operator_status.status)
    end
end

@testset "StenoticHemodynamics native resolved-FSI parity missing imported bundle" begin
    mktempdir() do dir
        native_case = write_native_resolved_fsi_parity_fixture(dir, "native")
        missing_velocity_xdmf = joinpath(dir, "missing", "velocity.xdmf")

        optional_spec = NativeResolvedFSIParitySpec(
            native_case.velocity_xdmf,
            missing_velocity_xdmf;
            native_case_label=native_case.case_label,
            imported_case_label="missing-imported",
            native_severity=native_case.severity,
            imported_severity=native_case.severity,
            native_pressure_xdmf=native_case.pressure_xdmf,
            native_displacement_xdmf=native_case.displacement_xdmf,
            native_target_time=native_case.target_time,
            imported_target_time=native_case.target_time,
            native_time_atol=native_case.time_atol,
            imported_time_atol=native_case.time_atol,
            require_imported=false,
            coordinate_mode="deformed",
            sample_z_cm=[0.5],
            radial_profile_z_cm=[0.5],
            radial_bin_count=3,
            node_slab_half_widths_cm=[0.6],
        )
        optional_result = run_native_resolved_fsi_parity(optional_spec)

        @test optional_result.imported_bundle === nothing
        @test optional_result.schema_status.skipped
        @test optional_result.geometry_status.skipped
        @test optional_result.time_status.skipped
        @test optional_result.velocity_status.skipped
        @test optional_result.pressure_status.skipped
        @test optional_result.displacement_status.skipped
        @test optional_result.operator_status.skipped
        @test occursin("missing required three-field XDMF inputs", optional_result.schema_status.status)

        strict_spec = NativeResolvedFSIParitySpec(
            native_case.velocity_xdmf,
            missing_velocity_xdmf;
            native_case_label=native_case.case_label,
            imported_case_label="missing-imported",
            native_severity=native_case.severity,
            imported_severity=native_case.severity,
            native_pressure_xdmf=native_case.pressure_xdmf,
            native_displacement_xdmf=native_case.displacement_xdmf,
            native_target_time=native_case.target_time,
            imported_target_time=native_case.target_time,
            native_time_atol=native_case.time_atol,
            imported_time_atol=native_case.time_atol,
            require_imported=true,
            coordinate_mode="deformed",
            sample_z_cm=[0.5],
            radial_profile_z_cm=[0.5],
            radial_bin_count=3,
            node_slab_half_widths_cm=[0.6],
        )
        @test_throws ArgumentError run_native_resolved_fsi_parity(strict_spec)
    end
end
