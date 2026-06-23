function resolved3d_writer_fixture()
    coordinates = [
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        0.0 0.0 1.0
    ]
    topology = Int[
        1 2 3 4
    ]
    velocity = [
        0.0 0.0 10.0
        0.0 0.0 11.0
        0.0 0.0 12.0
        0.0 0.0 13.0
    ]
    pressure = [20.0, 21.0, 22.0, 23.0]
    displacement = [
        0.0 0.0 0.0
        0.05 0.0 0.0
        0.0 0.05 0.0
        0.0 0.0 0.02
    ]
    return coordinates, topology, velocity, pressure, displacement
end

@testset "StenoticHemodynamics resolved 3D writer round trip" begin
    mktempdir() do dir
        coordinates, topology, velocity, pressure, displacement = resolved3d_writer_fixture()
        paths = StenoticHemodynamics.Resolved3DWriterPaths(joinpath(dir, "bundle"))
        result = StenoticHemodynamics.write_resolved3d_field_bundle(
            paths,
            coordinates,
            topology,
            velocity,
            pressure,
            displacement;
            time=0.25,
        )

        @test result.time ≈ 0.25
        @test basename(result.paths.mesh_h5) == "mesh.h5"
        @test basename(result.paths.velocity_xdmf) == "velocity.xdmf"
        @test basename(result.paths.pressure_xdmf) == "pressure.xdmf"
        @test basename(result.paths.displacement_xdmf) == "displace.xdmf"
        @test isfile(result.paths.mesh_h5)
        @test isfile(result.paths.velocity_xdmf)
        @test isfile(result.paths.velocity_h5)
        @test isfile(result.paths.pressure_xdmf)
        @test isfile(result.paths.pressure_h5)
        @test isfile(result.paths.displacement_xdmf)
        @test isfile(result.paths.displacement_h5)

        stored_topology = HDF5.h5open(result.paths.mesh_h5, "r") do file
            read(file["/Mesh/0/mesh/topology"])
        end
        @test stored_topology == UInt32[0 1 2 3]

        velocity_meta = StenoticHemodynamics.parse_xdmf_velocity(result.paths.velocity_xdmf)
        pressure_meta = StenoticHemodynamics.parse_xdmf_field(result.paths.pressure_xdmf, "Scalar")
        displacement_meta = StenoticHemodynamics.parse_xdmf_field(result.paths.displacement_xdmf, "Vector")

        @test velocity_meta.time ≈ 0.25
        @test velocity_meta.geometry_file == "mesh.h5"
        @test velocity_meta.topology_file == "mesh.h5"
        @test velocity_meta.geometry_path == "/Mesh/0/mesh/geometry"
        @test velocity_meta.topology_path == "/Mesh/0/mesh/topology"
        @test velocity_meta.velocity_file == "velocity.h5"
        @test velocity_meta.velocity_path == "/VisualisationVector/0"
        @test pressure_meta.geometry_file == "mesh.h5"
        @test pressure_meta.topology_file == "mesh.h5"
        @test pressure_meta.field_file == "pressure.h5"
        @test pressure_meta.field_path == "/VisualisationVector/0"
        @test pressure_meta.attribute_type == "Scalar"
        @test displacement_meta.field_file == "displace.h5"
        @test displacement_meta.field_path == "/VisualisationVector/0"
        @test displacement_meta.attribute_type == "Vector"

        case_spec = StenoticHemodynamics.Resolved3DCaseSpec(
            "writer-round-trip",
            23.0,
            result.paths.velocity_xdmf;
            target_time=0.25,
        )
        bundle = StenoticHemodynamics.load_resolved3d_field_bundle(
            case_spec;
            require_pressure=true,
            require_displacement=true,
        )

        @test bundle.velocity.coordinates ≈ coordinates
        @test bundle.velocity.topology == topology
        @test bundle.velocity.velocity ≈ velocity
        @test bundle.pressure ≈ pressure
        @test bundle.displacement ≈ displacement
        @test bundle.deformed_coordinates ≈ coordinates .+ displacement

        reference_field = StenoticHemodynamics.resolved3d_velocity_field_from_bundle(bundle, "reference")
        deformed_field = StenoticHemodynamics.resolved3d_velocity_field_from_bundle(bundle, "deformed")
        @test reference_field.coordinates ≈ coordinates
        @test deformed_field.coordinates ≈ coordinates .+ displacement
    end
end

@testset "StenoticHemodynamics resolved 3D writer defaults and overwrite guard" begin
    mktempdir() do dir
        coordinates, topology, velocity, pressure, displacement = resolved3d_writer_fixture()
        output_dir = joinpath(dir, "bundle")

        result = StenoticHemodynamics.write_resolved3d_field_bundle(
            output_dir,
            coordinates,
            topology .- 1,
            velocity,
            reshape(pressure, :, 1),
            displacement;
        )
        @test result.time ≈ 1.0
        @test StenoticHemodynamics.parse_xdmf_velocity(result.paths.velocity_xdmf).time ≈ 1.0

        @test_throws ArgumentError StenoticHemodynamics.write_resolved3d_field_bundle(
            output_dir,
            coordinates,
            topology,
            velocity,
            pressure,
            displacement;
        )

        overwrite_result = StenoticHemodynamics.write_resolved3d_field_bundle(
            output_dir,
            coordinates,
            topology,
            velocity,
            pressure,
            displacement;
            overwrite=true,
            time=0.5,
        )
        @test overwrite_result.time ≈ 0.5
        @test StenoticHemodynamics.parse_xdmf_velocity(overwrite_result.paths.velocity_xdmf).time ≈ 0.5
    end
end
