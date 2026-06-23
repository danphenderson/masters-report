const NativeResolvedFSIWorkflowSpec = StenoticHemodynamics.NativeResolvedFSIWorkflowSpec
const NativeResolvedFSIWorkflowResult = StenoticHemodynamics.NativeResolvedFSIWorkflowResult
const NativeResolvedFSIMeshResolution = StenoticHemodynamics.NativeResolvedFSIMeshResolution
const NativeResolvedFSIProductionWorkflowPlan = StenoticHemodynamics.NativeResolvedFSIProductionWorkflowPlan
const NativeResolvedFSIPartitionedProductionResult = StenoticHemodynamics.NativeResolvedFSIPartitionedProductionResult
const NativeResolvedFSIPartitionedProductionSpec = StenoticHemodynamics.NativeResolvedFSIPartitionedProductionSpec
const NativeResolvedFSIPartitionedSmokeResult = StenoticHemodynamics.NativeResolvedFSIPartitionedSmokeResult
const NativeResolvedFSIWorkflowStatus = StenoticHemodynamics.NativeResolvedFSIWorkflowStatus
const default_native_resolved_fsi_partitioned_production_output_dir =
    StenoticHemodynamics.default_native_resolved_fsi_partitioned_production_output_dir
const default_native_resolved_fsi_output_dir = StenoticHemodynamics.default_native_resolved_fsi_output_dir
const native_resolved_fsi_case_spec = StenoticHemodynamics.native_resolved_fsi_case_spec
const native_resolved_fsi_lifted_displacement = StenoticHemodynamics.native_resolved_fsi_lifted_displacement
const native_resolved_fsi_mesh = StenoticHemodynamics.native_resolved_fsi_mesh
const native_resolved_fsi_partitioned_production_estimated_field_payload_bytes =
    StenoticHemodynamics.native_resolved_fsi_partitioned_production_estimated_field_payload_bytes
const native_resolved_fsi_partitioned_production_spec =
    StenoticHemodynamics.native_resolved_fsi_partitioned_production_spec
const native_resolved_fsi_production_workflow_plans = StenoticHemodynamics.native_resolved_fsi_production_workflow_plans
const native_resolved_fsi_synthetic_wall_lift = StenoticHemodynamics.native_resolved_fsi_synthetic_wall_lift
const native_resolved_fsi_zero_displacement = StenoticHemodynamics.native_resolved_fsi_zero_displacement
const run_native_resolved_fsi = StenoticHemodynamics.run_native_resolved_fsi
const run_native_resolved_fsi_partitioned_production =
    StenoticHemodynamics.run_native_resolved_fsi_partitioned_production
const run_native_resolved_fsi_production_workflow = StenoticHemodynamics.run_native_resolved_fsi_production_workflow
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

@testset "StenoticHemodynamics native resolved-FSI partitioned production spec policy" begin
    resolution = NativeResolvedFSIMeshResolution(axial=4, radial=2, angular=10)
    default_spec = native_resolved_fsi_partitioned_production_spec(case_id=:sev23, resolution=resolution)
    @test default_spec isa NativeResolvedFSIPartitionedProductionSpec
    @test default_spec.tfinal_s ≈ 1.0 atol=1.0e-12
    @test default_spec.snapshot_times_s == [1.0]
    @test default_spec.wall_stiffness_policy === :canic_membrane_c0
    @test default_spec.wall_reference_radius_policy === :params_rmax
    @test default_spec.coupling_iteration_count == 1
    @test default_spec.coupling_under_relaxation == 1.0
    @test default_native_resolved_fsi_partitioned_production_output_dir(default_spec) ==
          joinpath(
        "tmp",
        "simulations",
        "output",
        "native-resolved-fsi-production",
        "sev23",
        "4x2x10",
        "partitioned-production-dt0p0001-tfinal1",
        "snapshot-t1",
    )
    @test native_resolved_fsi_partitioned_production_estimated_field_payload_bytes(default_spec) ==
          BigInt((resolution.axial + 1) * (1 + resolution.radial * resolution.angular) * 7 * sizeof(Float64))

    tiny_spec = NativeResolvedFSIPartitionedProductionSpec(
        case_id=:sev40,
        resolution=resolution,
        output_root="tmp/native-production-test",
        dt_s=1.0e-4,
        tfinal_s=2.0e-4,
        snapshot_times_s=[1.0e-4, 2.0e-4],
        coupling_iteration_count=2,
        coupling_tolerance=1.0e-7,
        coupling_under_relaxation=0.5,
    )
    @test tiny_spec.snapshot_times_s == [1.0e-4, 2.0e-4]
    @test tiny_spec.coupling_iteration_count == 2
    @test tiny_spec.coupling_tolerance ≈ 1.0e-7
    @test tiny_spec.coupling_under_relaxation ≈ 0.5
    @test default_native_resolved_fsi_partitioned_production_output_dir(tiny_spec) ==
          joinpath(
        "tmp/native-production-test",
        "sev40",
        "4x2x10",
        "partitioned-production-dt0p0001-tfinal0p0002",
        "snapshots-n2-t0p0001-to-t0p0002",
    )

    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(dt_s=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(tfinal_s=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(snapshot_times_s=[NaN])
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(tfinal_s=0.2, snapshot_times_s=[0.2, 0.1])
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(tfinal_s=0.2, snapshot_times_s=[0.1, 0.1])
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(tfinal_s=0.2, snapshot_times_s=[-0.1])
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(tfinal_s=0.2, snapshot_times_s=[0.3])
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(picard_iteration_count=0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(picard_tolerance=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(wall_density_g_cm3=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(wall_damping_g_cm2_s=-1.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(wall_stiffness_policy=:constant_c0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(wall_reference_radius_policy=:local_radius)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(coupling_iteration_count=0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(coupling_tolerance=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(coupling_under_relaxation=0.0)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(coupling_under_relaxation=1.01)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(
        snapshot_times_s=collect(range(0.0, 1.0; length=51)),
    )
    @test NativeResolvedFSIPartitionedProductionSpec(
        snapshot_times_s=collect(range(0.0, 1.0; length=51)),
        allow_many_snapshots=true,
    ) isa NativeResolvedFSIPartitionedProductionSpec

    large_resolution = NativeResolvedFSIMeshResolution(axial=1000, radial=1000, angular=20)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(resolution=large_resolution)
    large_override = NativeResolvedFSIPartitionedProductionSpec(
        resolution=large_resolution,
        allow_large_output=true,
    )
    @test native_resolved_fsi_partitioned_production_estimated_field_payload_bytes(large_override) >
          StenoticHemodynamics.NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES
end

@testset "StenoticHemodynamics native resolved-FSI production workflow plans" begin
    resolution = NativeResolvedFSIMeshResolution(axial=4, radial=2, angular=10)
    mktempdir() do dir
        plans = native_resolved_fsi_production_workflow_plans(
            resolution=resolution,
            output_root=joinpath(dir, "production"),
        )
        @test length(plans) == 3
        @test all(plan isa NativeResolvedFSIProductionWorkflowPlan for plan in plans)
        @test [plan.case_spec.case_id for plan in plans] == [:sev23, :sev40, :sev50]
        @test all(plan -> isapprox(plan.workflow_spec.output_time_s, 1.0; atol=1.0e-12), plans)
        @test all(plan -> plan.production_spec isa NativeResolvedFSIPartitionedProductionSpec, plans)
        @test all(plan -> plan.production_spec.snapshot_times_s == [1.0], plans)
        @test all(plan -> plan.production_spec.output_root == joinpath(dir, "production"), plans)
        @test all(plan.workflow_spec.displacement_mode === :synthetic_radial_lift for plan in plans)
        @test all(
            plan ->
                plan.workflow_spec.resolution.axial == resolution.axial &&
                    plan.workflow_spec.resolution.radial == resolution.radial &&
                    plan.workflow_spec.resolution.angular == resolution.angular,
            plans,
        )
        @test plans[1].workflow_spec.output_dir == joinpath(dir, "production", "sev23")
        @test plans[2].workflow_spec.output_dir == joinpath(dir, "production", "sev40")
        @test plans[3].workflow_spec.output_dir == joinpath(dir, "production", "sev50")
        @test all(occursin("schema-only", plan.status) for plan in plans)
        @test all(occursin("coarse partitioned native FSI", plan.status) for plan in plans)
        @test all(occursin("not a paper-grade reproduction", plan.status) for plan in plans)
        @test occursin("23% stenosis", plans[1].status)
        @test occursin("50% stenosis", plans[3].status)
        @test default_native_resolved_fsi_partitioned_production_output_dir(plans[1].production_spec) ==
              joinpath(
            dir,
            "production",
            "sev23",
            "4x2x10",
            "partitioned-production-dt0p0001-tfinal1",
            "snapshot-t1",
        )

        tiny_plans = native_resolved_fsi_production_workflow_plans(
            resolution=resolution,
            output_root=joinpath(dir, "tiny-production"),
            tfinal_s=2.0e-4,
            snapshot_times_s=[1.0e-4, 2.0e-4],
            coupling_iteration_count=2,
            coupling_under_relaxation=0.5,
        )
        @test all(plan -> plan.workflow_spec.output_time_s ≈ 2.0e-4, tiny_plans)
        @test all(plan -> plan.production_spec.snapshot_times_s == [1.0e-4, 2.0e-4], tiny_plans)
        @test all(plan -> plan.production_spec.coupling_iteration_count == 2, tiny_plans)
        @test all(plan -> plan.production_spec.coupling_under_relaxation ≈ 0.5, tiny_plans)
    end
end

@testset "StenoticHemodynamics native resolved-FSI partitioned production runner" begin
    resolution = NativeResolvedFSIMeshResolution(axial=2, radial=1, angular=6)
    mktempdir() do dir
        plan = only(native_resolved_fsi_production_workflow_plans(
            case_ids=(:sev23,),
            resolution=resolution,
            output_root=joinpath(dir, "production"),
            dt_s=1.0e-4,
            tfinal_s=1.0e-4,
            snapshot_times_s=[1.0e-4],
            time_atol=1.0e-12,
            pressure_drop_dyn_cm2=40.0,
            picard_iteration_count=8,
            picard_tolerance=1.0e-8,
        ))
        result = run_native_resolved_fsi_production_workflow(plan)

        @test result isa NativeResolvedFSIPartitionedProductionResult
        @test result.spec === plan.production_spec
        @test result.smoke_result isa NativeResolvedFSIPartitionedSmokeResult
        @test result.output_status.ready
        @test result.method_status.ready
        @test result.saved_time_s ≈ plan.production_spec.tfinal_s atol=1.0e-12
        @test result.snapshot_times_s == [1.0e-4]
        @test result.output_dir == default_native_resolved_fsi_partitioned_production_output_dir(plan.production_spec)
        @test isfile(result.manifest_csv)
        @test isfile(result.diagnostics_csv)
        @test isfile(result.restart_metadata_json)
        @test length(result.snapshot_results) == 1
        @test length(result.diagnostic_rows) == 1
        @test result.snapshot_results[1].output_dir == result.output_dir
        @test result.smoke_result.output_dir == result.snapshot_results[1].output_dir
        @test isfile(joinpath(result.output_dir, "velocity.xdmf"))
        @test isfile(joinpath(result.output_dir, "pressure.xdmf"))
        @test isfile(joinpath(result.output_dir, "displace.xdmf"))
        @test result.smoke_result.post_update_fluid_refresh
        @test result.smoke_result.field_status.ready
        @test occursin("production snapshot harness", result.method_status.status)
        @test occursin("independent smoke-backed", result.method_status.status)
        @test occursin("monolithic ALE", result.method_status.status)
        @test occursin("per-snapshot smoke summaries", result.method_status.status)
        @test occursin("snapshot manifest", result.output_status.status)
        @test occursin("diagnostics CSV", result.output_status.status)
        @test result.diagnostics_status.ready
        @test result.restart_status.ready
        @test occursin("resume is explicitly deferred", result.restart_status.status)
        manifest_lines = readlines(result.manifest_csv)
        @test length(manifest_lines) == 2
        @test startswith(
            manifest_lines[1],
            "case_id,snapshot_time_s,output_dir,velocity_xdmf,pressure_xdmf,displacement_xdmf,node_count,tetrahedron_count,estimated_field_payload_bytes,status",
        )
        @test occursin("sev23,0.0001", manifest_lines[2])
        @test occursin(",ready", manifest_lines[2])
        diagnostic_row = only(result.diagnostic_rows)
        @test diagnostic_row.output_dir == result.output_dir
        @test diagnostic_row.solver_convergence_ready
        @test diagnostic_row.wall_update_ready
        @test diagnostic_row.output_ready
        @test diagnostic_row.importer_roundtrip_ready
        @test diagnostic_row.wall_displacement_max_cm > 0.0
        @test diagnostic_row.minimum_current_radius_cm > 0.0
        @test diagnostic_row.minimum_signed_tetra_volume6 > 0.0
        diagnostic_lines = readlines(result.diagnostics_csv)
        @test length(diagnostic_lines) == 2
        @test occursin("solver_convergence_ready", diagnostic_lines[1])
        @test occursin("wall_update_ready", diagnostic_lines[1])
        @test occursin(",ready", diagnostic_lines[2])
        @test result.restart_metadata["snapshot_manifest_csv"] == result.manifest_csv
        @test result.restart_metadata["diagnostics_csv"] == result.diagnostics_csv
        @test result.restart_metadata["restart_provenance"] == "independent_smoke_backed_snapshots"
        @test result.restart_metadata["resume_supported"] == false
        @test result.restart_metadata["resume_status"] == "deferred"
        @test result.restart_metadata["current_snapshot_time_s"] ≈ result.saved_time_s
        @test length(result.restart_metadata["current_wall_displacement_cm"]) ==
              length(result.smoke_result.wall_displacement_cm)
        restart_metadata_text = read(result.restart_metadata_json, String)
        @test occursin("\"resume_supported\": false", restart_metadata_text)
        @test occursin("\"restart_provenance\": \"independent_smoke_backed_snapshots\"", restart_metadata_text)
    end

    mktempdir() do dir
        multi_snapshot_spec = NativeResolvedFSIPartitionedProductionSpec(
            resolution=resolution,
            output_root=joinpath(dir, "production"),
            dt_s=1.0e-4,
            tfinal_s=2.0e-4,
            snapshot_times_s=[1.0e-4, 2.0e-4],
            time_atol=1.0e-12,
        )
        multi_result = run_native_resolved_fsi_partitioned_production(multi_snapshot_spec)
        @test multi_result.output_status.ready
        @test multi_result.method_status.ready
        @test multi_result.snapshot_times_s == [1.0e-4, 2.0e-4]
        @test length(multi_result.snapshot_results) == 2
        @test length(multi_result.diagnostic_rows) == 2
        @test [snapshot.snapshot_time_s for snapshot in multi_result.snapshot_results] == [1.0e-4, 2.0e-4]
        @test all(snapshot -> dirname(snapshot.output_dir) == multi_result.output_dir, multi_result.snapshot_results)
        @test [basename(snapshot.output_dir) for snapshot in multi_result.snapshot_results] ==
              ["snapshot-t0p0001", "snapshot-t0p0002"]
        @test all(snapshot -> isfile(snapshot.smoke_result.velocity_xdmf), multi_result.snapshot_results)
        @test all(snapshot -> isfile(snapshot.smoke_result.pressure_xdmf), multi_result.snapshot_results)
        @test all(snapshot -> isfile(snapshot.smoke_result.displacement_xdmf), multi_result.snapshot_results)
        @test all(snapshot -> snapshot.smoke_result.loaded_deformed_coordinates ==
                              snapshot.smoke_result.mesh.coordinates .+ snapshot.smoke_result.loaded_displacement,
            multi_result.snapshot_results)
        manifest_lines = readlines(multi_result.manifest_csv)
        @test length(manifest_lines) == 3
        @test occursin("snapshot-t0p0001", manifest_lines[2])
        @test occursin("snapshot-t0p0002", manifest_lines[3])
        @test all(endswith(line, ",ready") for line in manifest_lines[2:end])
        @test occursin("restart/state carry", multi_result.method_status.status)
        @test multi_result.diagnostics_status.ready
        @test multi_result.restart_status.ready
        @test all(row -> dirname(row.output_dir) == multi_result.output_dir, multi_result.diagnostic_rows)
        @test [row.snapshot_index for row in multi_result.diagnostic_rows] == [1, 2]
        @test [row.snapshot_time_s for row in multi_result.diagnostic_rows] == [1.0e-4, 2.0e-4]
        diagnostic_lines = readlines(multi_result.diagnostics_csv)
        @test length(diagnostic_lines) == 3
        @test occursin("snapshot-t0p0001", diagnostic_lines[2])
        @test occursin("snapshot-t0p0002", diagnostic_lines[3])
        @test multi_result.restart_metadata["current_snapshot_index"] == 2
        @test multi_result.restart_metadata["snapshot_times_s"] == [1.0e-4, 2.0e-4]
        @test length(multi_result.restart_metadata["snapshot_outputs"]) == 2
        @test multi_result.restart_metadata["resume_supported"] == false
    end

    coupling_iteration_spec = NativeResolvedFSIPartitionedProductionSpec(
        resolution=resolution,
        dt_s=1.0e-4,
        tfinal_s=1.0e-4,
        snapshot_times_s=[1.0e-4],
        coupling_iteration_count=2,
    )
    coupling_error = try
        run_native_resolved_fsi_partitioned_production(coupling_iteration_spec)
        nothing
    catch err
        err
    end
    @test coupling_error isa ArgumentError
    @test occursin("under-relaxation", sprint(showerror, coupling_error))

    zero_snapshot_spec = NativeResolvedFSIPartitionedProductionSpec(
        resolution=resolution,
        dt_s=1.0e-4,
        tfinal_s=1.0e-4,
        snapshot_times_s=[0.0, 1.0e-4],
    )
    zero_snapshot_error = try
        run_native_resolved_fsi_partitioned_production(zero_snapshot_spec)
        nothing
    catch err
        err
    end
    @test zero_snapshot_error isa ArgumentError
    @test occursin("positive snapshot times", sprint(showerror, zero_snapshot_error))
end
