using SHA

const NativeResolvedFSIWebExportSpec = StenoticHemodynamics.NativeResolvedFSIWebExportSpec
const NativeResolvedFSIWebExportResult = StenoticHemodynamics.NativeResolvedFSIWebExportResult
const run_native_resolved_fsi_web_export = StenoticHemodynamics.run_native_resolved_fsi_web_export

function read_binary_bytes(path::String)
    return open(path, "r") do io
        read(io)
    end
end

function write_synthetic_web_export_production_dir(root::String)
    snapshots = [
        ("snapshot-t0p1", 0.1, 0.01),
        ("snapshot-t0p2", 0.2, 0.02),
        ("snapshot-t0p3", 0.3, 0.03),
    ]
    outputs = Any[]
    for (index, (dir_name, time_s, displacement_scale)) in enumerate(snapshots)
        snapshot_dir = joinpath(root, dir_name)
        velocity_xdmf, _, _, _, _ =
            write_synthetic_fsi_xdmf_hdf5_case(snapshot_dir; time=time_s, displacement_scale=displacement_scale)
        push!(outputs, Dict{String,Any}(
            "snapshot_index" => index,
            "snapshot_time_s" => time_s,
            "output_dir" => snapshot_dir,
            "velocity_xdmf" => velocity_xdmf,
            "pressure_xdmf" => joinpath(snapshot_dir, "pressure.xdmf"),
            "displacement_xdmf" => joinpath(snapshot_dir, "displace.xdmf"),
            "status" => "ready",
        ))
    end
    StenoticHemodynamics.write_json(
        joinpath(root, "restart_metadata.json"),
        Dict{String,Any}(
            "restart_schema_version" => 2,
            "snapshot_outputs" => outputs,
        );
        overwrite=true,
    )
    return snapshots
end

@testset "StenoticHemodynamics native resolved-FSI web export" begin
    mktempdir() do dir
        case_dir = joinpath(dir, "bundle")
        velocity_xdmf, coords, velocity, pressure, displacement =
            write_synthetic_fsi_xdmf_hdf5_case(case_dir; time=0.25)
        output_dir = joinpath(dir, "web")

        spec = NativeResolvedFSIWebExportSpec(
            velocity_xdmf=velocity_xdmf,
            output_dir=output_dir,
            case_id=:sev23,
            target_time=0.25,
            include_tetra_debug=true,
        )
        result = run_native_resolved_fsi_web_export(spec)

        @test result isa NativeResolvedFSIWebExportResult
        @test result.output_dir == output_dir
        @test isfile(result.manifest_json)
        @test result.manifest["schema_version"] == 1
        @test result.manifest["case_id"] == "sev23"
        @test result.manifest["coordinate_mode"] == "reference"
        @test occursin("not paper-grade", result.manifest["claim_boundary"])

        geometry = result.manifest["geometry"]
        @test geometry["node_count"] == size(coords, 1)
        @test geometry["tetrahedron_count"] == 2
        @test geometry["surface_triangle_count"] == 8
        @test geometry["reference_positions"]["byte_size"] == size(coords, 1) * 3 * sizeof(Float32)
        @test geometry["surface_indices"]["byte_size"] == 8 * 3 * sizeof(UInt32)
        @test geometry["tetra_indices_debug"]["byte_size"] == 2 * 4 * sizeof(UInt32)

        fields = result.manifest["fields"]
        @test fields["velocity"]["asset"]["byte_size"] == size(velocity, 1) * 3 * sizeof(Float32)
        @test fields["pressure"]["asset"]["byte_size"] == size(pressure, 1) * sizeof(Float32)
        @test fields["displacement"]["asset"]["byte_size"] == size(displacement, 1) * 3 * sizeof(Float32)

        reference_path = joinpath(output_dir, geometry["reference_positions"]["path"])
        @test bytes2hex(sha256(read_binary_bytes(reference_path))) == geometry["reference_positions"]["sha256"]

        derived_path = joinpath(output_dir, result.manifest["snapshots"][1]["derived"]["path"])
        @test isfile(derived_path)
        @test haskey(result.manifest["snapshots"][1]["ranges"], "speed_cm_s")
        @test isempty(result.manifest["sidecars"])
        @test result.frame_count == 1
    end
end

@testset "StenoticHemodynamics native resolved-FSI temporal web export" begin
    mktempdir() do dir
        production_dir = joinpath(dir, "production")
        mkpath(production_dir)
        write_synthetic_web_export_production_dir(production_dir)

        output_dir = joinpath(dir, "web-v2")
        spec = NativeResolvedFSIWebExportSpec(
            input_production_dir=production_dir,
            output_dir=output_dir,
            case_id=:sev23,
            snapshot_stride=2,
            overwrite=true,
        )
        result = run_native_resolved_fsi_web_export(spec)

        @test result.manifest["schema_version"] == 2
        @test result.frame_count == 2
        @test result.manifest["snapshot_count"] == 2
        @test [row["frame_id"] for row in result.manifest["time_axis"]] == ["t0000", "t0001"]
        @test [row["time_s"] for row in result.manifest["time_axis"]] ≈ [0.1, 0.3]
        @test result.manifest["time_axis"][2]["delta_t_s"] ≈ 0.2
        @test result.estimated_playback_fps ≈ 5.0
        @test "snapshot-t0p2" in result.skipped_snapshots
        @test haskey(result.manifest, "available_fields")
        @test haskey(result.manifest, "global_ranges")
        @test haskey(result.manifest["global_ranges"], "speed_cm_s")
        @test result.manifest["mesh"]["node_indexing"] == "zero_based"

        geometry = result.manifest["geometry"]
        @test isfile(joinpath(output_dir, geometry["reference_positions"]["path"]))
        @test isfile(joinpath(output_dir, geometry["surface_indices"]["path"]))
        for snapshot in result.manifest["snapshots"]
            @test isfile(joinpath(output_dir, snapshot["fields"]["velocity"]["asset"]["path"]))
            @test isfile(joinpath(output_dir, snapshot["fields"]["pressure"]["asset"]["path"]))
            @test isfile(joinpath(output_dir, snapshot["fields"]["displacement"]["asset"]["path"]))
            @test haskey(snapshot["ranges"], "displacement_magnitude_cm")
        end

        selected_output_dir = joinpath(dir, "web-v2-selected")
        selected_spec = NativeResolvedFSIWebExportSpec(
            input_production_dir=production_dir,
            output_dir=selected_output_dir,
            case_id=:sev23,
            snapshot_include="snapshot-t0p1,snapshot-t0p3",
            snapshot_exclude="snapshot-t0p1",
            max_snapshots=1,
            overwrite=true,
        )
        selected_result = run_native_resolved_fsi_web_export(selected_spec)
        @test selected_result.frame_count == 1
        @test selected_result.manifest["snapshots"][1]["source_id"] == "snapshot-t0p3"
        @test "snapshot-t0p1" in selected_result.skipped_snapshots
        @test "snapshot-t0p2" in selected_result.skipped_snapshots
    end
end

@testset "StenoticHemodynamics native resolved-FSI web export guards" begin
    mktempdir() do dir
        case_dir = joinpath(dir, "bundle")
        velocity_xdmf, _, _ = write_synthetic_xdmf_hdf5_case(case_dir; time=0.25)
        output_dir = joinpath(dir, "web")

        @test_throws ArgumentError NativeResolvedFSIWebExportSpec(
            velocity_xdmf=velocity_xdmf,
            output_dir=output_dir,
            case_id=:sev23,
            target_time=0.25,
        )

        spec = NativeResolvedFSIWebExportSpec(
            velocity_xdmf=velocity_xdmf,
            output_dir=output_dir,
            case_id=:sev23,
            target_time=0.25,
            coordinate_mode=:reference,
            allow_velocity_only=true,
        )
        result = run_native_resolved_fsi_web_export(spec)
        @test result.manifest["fields"]["pressure"] === nothing
        @test result.manifest["fields"]["displacement"] === nothing
    end
end
