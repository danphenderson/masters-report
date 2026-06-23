const NativeResolvedFSIWorkflowSpec = StenoticHemodynamics.NativeResolvedFSIWorkflowSpec
const NativeResolvedFSIWorkflowResult = StenoticHemodynamics.NativeResolvedFSIWorkflowResult
const NativeResolvedFSIMeshResolution = StenoticHemodynamics.NativeResolvedFSIMeshResolution
const NativeResolvedFSIProductionDryRunPlan = StenoticHemodynamics.NativeResolvedFSIProductionDryRunPlan
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
const native_resolved_fsi_partitioned_production_dry_run =
    StenoticHemodynamics.native_resolved_fsi_partitioned_production_dry_run
const native_resolved_fsi_partitioned_production_estimated_field_payload_bytes =
    StenoticHemodynamics.native_resolved_fsi_partitioned_production_estimated_field_payload_bytes
const native_resolved_fsi_partitioned_production_spec =
    StenoticHemodynamics.native_resolved_fsi_partitioned_production_spec
const native_resolved_fsi_production_workflow_plans = StenoticHemodynamics.native_resolved_fsi_production_workflow_plans
const native_resolved_fsi_read_restart_metadata = StenoticHemodynamics.native_resolved_fsi_read_restart_metadata
const native_resolved_fsi_resume_partitioned_production =
    StenoticHemodynamics.native_resolved_fsi_resume_partitioned_production
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
    @test default_spec.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
    @test default_spec.inlet_umax_cm_s ≈ 45.0
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
        "boundary-pressure_drop_weak_inlet_outlet_gauge_smoke",
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
    @test tiny_spec.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
    @test default_native_resolved_fsi_partitioned_production_output_dir(tiny_spec) ==
          joinpath(
        "tmp/native-production-test",
        "sev40",
        "4x2x10",
        "boundary-pressure_drop_weak_inlet_outlet_gauge_smoke",
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
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(inlet_outlet_boundary_mode=:unsupported)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(inlet_umax_cm_s=NaN)
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(
        inlet_outlet_boundary_mode=:poiseuille_inlet_zero_outlet_stress_section41,
        inlet_umax_cm_s=0.0,
        pressure_drop_dyn_cm2=0.0,
    )
    @test_throws ArgumentError NativeResolvedFSIPartitionedProductionSpec(pressure_drop_dyn_cm2=0.0)
    exact_boundary_spec = NativeResolvedFSIPartitionedProductionSpec(
        inlet_outlet_boundary_mode=:poiseuille_inlet_zero_outlet_stress_section41,
        pressure_drop_dyn_cm2=0.0,
    )
    @test exact_boundary_spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
    @test exact_boundary_spec.inlet_umax_cm_s ≈ 45.0
    @test exact_boundary_spec.pressure_drop_dyn_cm2 == 0.0
    @test occursin(
        "boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45",
        default_native_resolved_fsi_partitioned_production_output_dir(exact_boundary_spec),
    )
    @test default_native_resolved_fsi_partitioned_production_output_dir(exact_boundary_spec) !=
          default_native_resolved_fsi_partitioned_production_output_dir(NativeResolvedFSIPartitionedProductionSpec())
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
        @test all(occursin("state-carrying partitioned native FSI", plan.status) for plan in plans)
        @test all(occursin("not a paper-grade reproduction", plan.status) for plan in plans)
        @test occursin("23% stenosis", plans[1].status)
        @test occursin("50% stenosis", plans[3].status)
        @test default_native_resolved_fsi_partitioned_production_output_dir(plans[1].production_spec) ==
              joinpath(
            dir,
            "production",
            "sev23",
            "4x2x10",
            "boundary-pressure_drop_weak_inlet_outlet_gauge_smoke",
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

@testset "StenoticHemodynamics native resolved-FSI production dry run" begin
    resolution = NativeResolvedFSIMeshResolution(axial=4, radial=2, angular=10)
    mktempdir() do dir
        plan = only(native_resolved_fsi_production_workflow_plans(
            case_ids=(:sev23,),
            resolution=resolution,
            output_root=joinpath(dir, "production"),
            dt_s=1.0e-4,
            tfinal_s=2.0e-4,
            snapshot_times_s=[1.0e-4, 2.0e-4],
            time_atol=1.0e-12,
        ))
        dry_run = native_resolved_fsi_partitioned_production_dry_run(
            plan;
            imported_data_root=joinpath(dir, "missing-imported"),
        )

        expected_output_dir = default_native_resolved_fsi_partitioned_production_output_dir(plan.production_spec)
        @test dry_run isa NativeResolvedFSIProductionDryRunPlan
        @test dry_run.workflow_plan === plan
        @test dry_run.case_id === :sev23
        @test dry_run.mesh_resolution == resolution
        @test dry_run.expected_node_count == (resolution.axial + 1) * (1 + resolution.radial * resolution.angular)
        @test dry_run.expected_tetrahedron_count == 3 * resolution.axial * resolution.angular * (2 * resolution.radial - 1)
        @test dry_run.snapshot_times_s == [1.0e-4, 2.0e-4]
        @test dry_run.estimated_field_payload_bytes ==
              native_resolved_fsi_partitioned_production_estimated_field_payload_bytes(plan.production_spec)
        @test dry_run.snapshot_count_within_default_guard
        @test dry_run.estimated_output_payload_within_default_guard
        @test isempty(dry_run.required_override_flags)
        @test dry_run.output_dir == expected_output_dir
        @test dry_run.snapshot_output_dirs == [
            joinpath(expected_output_dir, "snapshot-t0p0001"),
            joinpath(expected_output_dir, "snapshot-t0p0002"),
        ]
        @test dry_run.manifest_csv == joinpath(expected_output_dir, "snapshot_manifest.csv")
        @test dry_run.diagnostics_csv == joinpath(expected_output_dir, "snapshot_diagnostics.csv")
        @test dry_run.restart_metadata_json == joinpath(expected_output_dir, "restart_metadata.json")
        @test dry_run.parity_observations_csv ==
              joinpath(expected_output_dir, "section41-observations", "section41_observations.csv")
        @test dry_run.parity_summary_csv ==
              joinpath(expected_output_dir, "section41-observations", "section41_observation_summary.csv")
        @test dry_run.boundary_mode == "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test dry_run.boundary_mode_class == "local_smoke_loading"
        @test dry_run.inlet_condition_status == "pressure_drop_weak_loading_not_poiseuille_profile"
        @test dry_run.outlet_condition_status == "outlet_gauge_pressure_reference_not_zero_outlet_stress_evidence"
        @test dry_run.pressure_gauge_status == "post_sampling_outlet_mean_normalization_not_gridap_nullspace_constraint"
        @test occursin("gridap_zero_mean_pressure_constraint_active", dry_run.pressure_nullspace_status)
        @test occursin("local_smoke_loading_only", dry_run.pressure_nullspace_status)
        @test dry_run.section41_boundary_status == "deferred_or_not_selected"
        @test occursin("local smoke boundary evidence", dry_run.boundary_status)
        @test occursin("not_exact_section41_boundary_equivalence", dry_run.boundary_equivalence_status)
        @test occursin("explicit_membrane_oscillator_dt_guard", dry_run.wall_stability_status)
        @test occursin("local pressure-drop smoke loading", dry_run.wall_stability_status)
        @test dry_run.imported_case.case_label == "77"
        @test !dry_run.imported_available
        @test occursin("dry-run ready", dry_run.status)
        @test occursin("no production solver executed", dry_run.status)
        @test occursin("no files written", dry_run.status)
        @test occursin("boundary_mode=pressure_drop_weak_inlet_outlet_gauge_smoke", dry_run.status)
        @test occursin("section41_boundary_status=deferred_or_not_selected", dry_run.status)
        @test occursin("pressure_nullspace_status=gridap_zero_mean_pressure_constraint_active", dry_run.status)
        @test occursin("wall_stability_status=", dry_run.status)
        @test occursin("required override flags: none", dry_run.status)
        @test !ispath(dry_run.output_dir)
        @test !ispath(dirname(dry_run.parity_observations_csv))

        blocked_resolution = NativeResolvedFSIMeshResolution(axial=1000, radial=1000, angular=20)
        blocked_snapshot_times = [index * 1.0e-4 for index in 1:51]
        blocked_plan = only(native_resolved_fsi_production_workflow_plans(
            case_ids=(:sev23,),
            resolution=blocked_resolution,
            output_root=joinpath(dir, "blocked-production"),
            dt_s=1.0e-4,
            tfinal_s=last(blocked_snapshot_times),
            snapshot_times_s=blocked_snapshot_times,
            allow_many_snapshots=true,
            allow_large_output=true,
        ))
        blocked_dry_run = native_resolved_fsi_partitioned_production_dry_run(
            blocked_plan;
            imported_data_root=joinpath(dir, "missing-imported"),
        )
        @test blocked_dry_run.expected_node_count ==
              (blocked_resolution.axial + 1) * (1 + blocked_resolution.radial * blocked_resolution.angular)
        @test blocked_dry_run.expected_tetrahedron_count ==
              3 * blocked_resolution.axial * blocked_resolution.angular * (2 * blocked_resolution.radial - 1)
        @test blocked_dry_run.estimated_field_payload_bytes >
              StenoticHemodynamics.NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES
        @test !blocked_dry_run.snapshot_count_within_default_guard
        @test !blocked_dry_run.estimated_output_payload_within_default_guard
        @test blocked_dry_run.required_override_flags == ["allow_many_snapshots", "allow_large_output"]
        @test occursin("allow_many_snapshots, allow_large_output", blocked_dry_run.status)
        @test !ispath(blocked_dry_run.output_dir)

        exact_plan = only(native_resolved_fsi_production_workflow_plans(
            case_ids=(:sev23,),
            resolution=resolution,
            output_root=joinpath(dir, "exact-production"),
            dt_s=1.0e-4,
            tfinal_s=2.0e-4,
            snapshot_times_s=[2.0e-4],
            inlet_outlet_boundary_mode=:poiseuille_inlet_zero_outlet_stress_section41,
            inlet_umax_cm_s=45.0,
            pressure_drop_dyn_cm2=0.0,
        ))
        exact_dry_run = native_resolved_fsi_partitioned_production_dry_run(
            exact_plan;
            imported_data_root=joinpath(dir, "missing-imported"),
        )
        @test exact_dry_run.boundary_mode == "poiseuille_inlet_zero_outlet_stress_section41"
        @test exact_dry_run.boundary_mode_class == "exact_section41"
        @test exact_dry_run.inlet_condition_status == "poiseuille_profile_umax_45_cm_s"
        @test exact_dry_run.outlet_condition_status == "zero_outlet_stress_natural_traction"
        @test exact_dry_run.pressure_gauge_status ==
              "post_sampling_outlet_mean_normalization_not_gridap_nullspace_constraint"
        @test occursin("gridap_zero_mean_pressure_constraint_active", exact_dry_run.pressure_nullspace_status)
        @test occursin("not_wall_stability_remediation", exact_dry_run.pressure_nullspace_status)
        @test exact_dry_run.section41_boundary_status == "implemented_smoke_validated"
        @test occursin("partitioned production smoke-scale threading evidence", exact_dry_run.boundary_status)
        @test occursin("exact_section41_boundary_mode_selected_smoke_validated", exact_dry_run.boundary_equivalence_status)
        @test occursin("known_wall_stability_blocker", exact_dry_run.wall_stability_status)
        @test occursin("dry-run does not certify wall-pressure/load stability", exact_dry_run.wall_stability_status)
        @test occursin("production runner support advances the exact inlet/outlet boundary mode", exact_plan.status)
        @test occursin("section41_boundary_status=implemented_smoke_validated", exact_plan.status)
        @test occursin("boundary_mode=poiseuille_inlet_zero_outlet_stress_section41", exact_dry_run.status)
        @test occursin("section41_boundary_status=implemented_smoke_validated", exact_dry_run.status)
        @test occursin("pressure_nullspace_status=gridap_zero_mean_pressure_constraint_active", exact_dry_run.status)
        @test occursin("known_wall_stability_blocker", exact_dry_run.status)
        @test occursin("production execution is available only through explicit production specs", exact_dry_run.status)
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
        @test occursin("state-carrying partitioned solve", result.method_status.status)
        @test occursin("prescribed radial wall-velocity Dirichlet", result.method_status.status)
        @test occursin("monolithic ALE", result.method_status.status)
        @test occursin("cumulative per-snapshot summaries", result.method_status.status)
        @test occursin("snapshot manifest", result.output_status.status)
        @test occursin("diagnostics CSV", result.output_status.status)
        @test result.diagnostics_status.ready
        @test result.restart_status.ready
        @test occursin("persisted resume remains explicitly deferred", result.restart_status.status)
        manifest_lines = readlines(result.manifest_csv)
        @test length(manifest_lines) == 2
        @test startswith(
            manifest_lines[1],
            "case_id,snapshot_time_s,output_dir,velocity_xdmf,pressure_xdmf,displacement_xdmf,provenance,node_count,tetrahedron_count,estimated_field_payload_bytes,status",
        )
        @test occursin("boundary_mode", manifest_lines[1])
        @test occursin("section41_boundary_status", manifest_lines[1])
        @test occursin("boundary_equivalence_status", manifest_lines[1])
        @test occursin("sev23,0.0001", manifest_lines[2])
        @test occursin(",state_carrying_partitioned,", manifest_lines[2])
        @test occursin(",ready,pressure_drop_weak_inlet_outlet_gauge_smoke,local_smoke_loading,deferred_or_not_selected,", manifest_lines[2])
        diagnostic_row = only(result.diagnostic_rows)
        @test diagnostic_row.output_dir == result.output_dir
        @test diagnostic_row.provenance == "state_carrying_partitioned"
        @test diagnostic_row.solver_convergence_ready
        @test diagnostic_row.wall_update_ready
        @test diagnostic_row.output_ready
        @test diagnostic_row.importer_roundtrip_ready
        @test diagnostic_row.coupling_iteration_count == 1
        @test diagnostic_row.max_coupling_iterations_used == 1
        @test isfinite(diagnostic_row.final_coupling_displacement_residual_cm)
        @test diagnostic_row.fluid_wall_boundary_mode == "prescribed_radial_wall_velocity"
        @test diagnostic_row.boundary_mode == "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test diagnostic_row.boundary_mode_class == "local_smoke_loading"
        @test diagnostic_row.inlet_condition_status == "pressure_drop_weak_loading_not_poiseuille_profile"
        @test diagnostic_row.outlet_condition_status ==
              "outlet_gauge_pressure_reference_not_zero_outlet_stress_evidence"
        @test diagnostic_row.pressure_gauge_status ==
              "post_sampling_outlet_mean_normalization_not_gridap_nullspace_constraint"
        @test occursin("gridap_zero_mean_pressure_constraint_active", diagnostic_row.pressure_nullspace_status)
        @test occursin("local_smoke_loading_only", diagnostic_row.pressure_nullspace_status)
        @test diagnostic_row.section41_boundary_status == "deferred_or_not_selected"
        @test occursin("local smoke boundary evidence", diagnostic_row.boundary_status)
        @test occursin("not_exact_section41_boundary_equivalence", diagnostic_row.boundary_equivalence_status)
        @test diagnostic_row.wall_displacement_max_cm > 0.0
        @test diagnostic_row.minimum_current_radius_cm > 0.0
        @test diagnostic_row.minimum_signed_tetra_volume6 > 0.0
        diagnostic_lines = readlines(result.diagnostics_csv)
        @test length(diagnostic_lines) == 2
        @test occursin("solver_convergence_ready", diagnostic_lines[1])
        @test occursin("max_coupling_iterations_used", diagnostic_lines[1])
        @test occursin("fluid_wall_boundary_mode", diagnostic_lines[1])
        @test occursin("boundary_mode", diagnostic_lines[1])
        @test occursin("section41_boundary_status", diagnostic_lines[1])
        @test occursin("pressure_nullspace_status", diagnostic_lines[1])
        @test occursin("wall_update_ready", diagnostic_lines[1])
        @test occursin("provenance", diagnostic_lines[1])
        @test occursin(",ready", diagnostic_lines[2])
        @test result.restart_metadata["snapshot_manifest_csv"] == result.manifest_csv
        @test result.restart_metadata["diagnostics_csv"] == result.diagnostics_csv
        @test result.restart_metadata["restart_provenance"] == "state_carrying_partitioned"
        @test result.restart_metadata["state_carrying_restart"] == true
        @test result.restart_metadata["max_coupling_iterations_used"] == result.smoke_result.max_coupling_iterations_used
        @test result.restart_metadata["fluid_wall_boundary_mode"] == "prescribed_radial_wall_velocity"
        @test result.restart_metadata["wall_velocity_fluid_bc_status"] ==
              "prescribed_radial_wall_velocity_on_deformed_geometry"
        @test result.restart_metadata["boundary_mode"] == "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test result.restart_metadata["boundary_mode_class"] == "local_smoke_loading"
        @test result.restart_metadata["inlet_condition_status"] == "pressure_drop_weak_loading_not_poiseuille_profile"
        @test result.restart_metadata["outlet_condition_status"] ==
              "outlet_gauge_pressure_reference_not_zero_outlet_stress_evidence"
        @test result.restart_metadata["pressure_gauge_status"] ==
              "post_sampling_outlet_mean_normalization_not_gridap_nullspace_constraint"
        @test occursin("gridap_zero_mean_pressure_constraint_active", result.restart_metadata["pressure_nullspace_status"])
        @test occursin("local_smoke_loading_only", result.restart_metadata["pressure_nullspace_status"])
        @test result.restart_metadata["section41_boundary_status"] == "deferred_or_not_selected"
        @test occursin("local smoke boundary evidence", result.restart_metadata["boundary_status"])
        @test occursin("not_exact_section41_boundary_equivalence", result.restart_metadata["boundary_equivalence_status"])
        @test length(result.restart_metadata["coupling_residual_history"]) ==
              length(result.smoke_result.coupling_residual_history)
        @test result.restart_metadata["resume_supported"] == false
        @test result.restart_metadata["resume_status"] == "deferred"
        @test result.restart_metadata["current_snapshot_time_s"] ≈ result.saved_time_s
        @test length(result.restart_metadata["current_wall_displacement_cm"]) ==
              length(result.smoke_result.wall_displacement_cm)
        @test haskey(result.restart_metadata, "state_payload")
        state_payload = result.restart_metadata["state_payload"]
        @test state_payload["schema_version"] == 1
        @test state_payload["saved_time_s"] ≈ result.saved_time_s
        @test state_payload["last_snapshot_index"] == 1
        @test state_payload["final_wall_displacement_cm"] == result.smoke_result.wall_displacement_cm
        @test state_payload["final_wall_velocity_cm_s"] == result.smoke_result.wall_velocity_cm_s
        @test state_payload["current_radii_cm"] == result.smoke_result.current_radii_cm
        @test state_payload["final_wall_pressure_dyn_cm2"] == result.smoke_result.wall_pressure_dyn_cm2
        @test state_payload["solver_provenance"] == "state_carrying_partitioned"
        @test state_payload["state_carrying_in_run"] == true
        @test state_payload["resume_supported"] == false
        @test state_payload["resume_status"] == "deferred"
        restart_metadata_text = read(result.restart_metadata_json, String)
        @test occursin("\"resume_supported\": false", restart_metadata_text)
        @test occursin("\"restart_provenance\": \"state_carrying_partitioned\"", restart_metadata_text)
        @test occursin("\"state_carrying_restart\": true", restart_metadata_text)
        @test occursin("\"state_payload\"", restart_metadata_text)
        @test occursin("\"schema_version\": 1", restart_metadata_text)
        @test occursin("\"fluid_wall_boundary_mode\": \"prescribed_radial_wall_velocity\"", restart_metadata_text)
        @test occursin("\"boundary_mode\": \"pressure_drop_weak_inlet_outlet_gauge_smoke\"", restart_metadata_text)
        @test occursin("\"pressure_nullspace_status\": \"gridap_zero_mean_pressure_constraint_active", restart_metadata_text)
        @test occursin("\"section41_boundary_status\": \"deferred_or_not_selected\"", restart_metadata_text)
        @test only(result.restart_metadata["snapshot_outputs"])["provenance"] == "state_carrying_partitioned"
        @test only(result.restart_metadata["snapshot_outputs"])["boundary_mode"] ==
              "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test only(result.restart_metadata["snapshot_outputs"])["section41_boundary_status"] ==
              "deferred_or_not_selected"

        parsed_restart_metadata = native_resolved_fsi_read_restart_metadata(result.restart_metadata_json)
        @test parsed_restart_metadata isa Dict{String,Any}
        @test parsed_restart_metadata["snapshot_manifest_csv"] == result.manifest_csv
        @test parsed_restart_metadata["diagnostics_csv"] == result.diagnostics_csv
        @test parsed_restart_metadata["restart_provenance"] == "state_carrying_partitioned"
        @test parsed_restart_metadata["state_carrying_restart"] == true
        @test parsed_restart_metadata["resume_supported"] == false
        @test parsed_restart_metadata["resume_status"] == "deferred"
        @test parsed_restart_metadata["boundary_mode"] == "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test parsed_restart_metadata["boundary_mode_class"] == "local_smoke_loading"
        @test occursin("gridap_zero_mean_pressure_constraint_active", parsed_restart_metadata["pressure_nullspace_status"])
        @test parsed_restart_metadata["section41_boundary_status"] == "deferred_or_not_selected"
        parsed_state_payload = parsed_restart_metadata["state_payload"]
        @test parsed_state_payload["schema_version"] == 1
        @test parsed_state_payload["saved_time_s"] ≈ result.saved_time_s
        @test parsed_state_payload["last_snapshot_index"] == 1
        @test parsed_state_payload["final_wall_displacement_cm"] == result.smoke_result.wall_displacement_cm
        @test parsed_state_payload["final_wall_velocity_cm_s"] == result.smoke_result.wall_velocity_cm_s
        @test parsed_state_payload["current_radii_cm"] == result.smoke_result.current_radii_cm
        @test parsed_state_payload["final_wall_pressure_dyn_cm2"] == result.smoke_result.wall_pressure_dyn_cm2
        @test parsed_state_payload["solver_provenance"] == "state_carrying_partitioned"
        @test parsed_state_payload["state_carrying_in_run"] == true
        @test parsed_state_payload["resume_supported"] == false
        @test parsed_state_payload["resume_status"] == "deferred"
        parsed_snapshot_output = only(parsed_restart_metadata["snapshot_outputs"])
        @test parsed_snapshot_output["output_dir"] == result.output_dir
        @test parsed_snapshot_output["velocity_xdmf"] == result.smoke_result.velocity_xdmf
        @test parsed_snapshot_output["pressure_xdmf"] == result.smoke_result.pressure_xdmf
        @test parsed_snapshot_output["displacement_xdmf"] == result.smoke_result.displacement_xdmf
        @test parsed_snapshot_output["provenance"] == "state_carrying_partitioned"
        @test parsed_snapshot_output["time_step_count"] == result.smoke_result.time_step_count
        @test parsed_snapshot_output["boundary_mode"] == "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test parsed_snapshot_output["section41_boundary_status"] == "deferred_or_not_selected"

        resume_error = try
            native_resolved_fsi_resume_partitioned_production(result.restart_metadata_json)
            nothing
        catch err
            err
        end
        @test resume_error isa ArgumentError
        @test occursin("persisted resume from restart metadata is unsupported", sprint(showerror, resume_error))
        @test occursin("state_carrying_partitioned", sprint(showerror, resume_error))
        @test occursin("state_payload may record state", sprint(showerror, resume_error))
        @test occursin("resume_supported is false", sprint(showerror, resume_error))

        payloadless_metadata = deepcopy(result.restart_metadata)
        delete!(payloadless_metadata, "state_payload")
        payloadless_metadata_path = joinpath(dir, "payloadless-state-carrying-restart-metadata.json")
        StenoticHemodynamics.write_json(payloadless_metadata_path, payloadless_metadata; overwrite=true)
        payloadless_restart_metadata = native_resolved_fsi_read_restart_metadata(payloadless_metadata_path)
        @test payloadless_restart_metadata["restart_provenance"] == "state_carrying_partitioned"
        @test payloadless_restart_metadata["state_carrying_restart"] == true
        @test !haskey(payloadless_restart_metadata, "state_payload")

        invalid_metadata = deepcopy(result.restart_metadata)
        delete!(only(invalid_metadata["snapshot_outputs"]), "time_step_count")
        invalid_metadata_path = joinpath(dir, "invalid-state-carrying-restart-metadata.json")
        StenoticHemodynamics.write_json(invalid_metadata_path, invalid_metadata; overwrite=true)
        invalid_error = try
            native_resolved_fsi_read_restart_metadata(invalid_metadata_path)
            nothing
        catch err
            err
        end
        @test invalid_error isa ArgumentError
        @test occursin("snapshot_outputs[1]", sprint(showerror, invalid_error))
        @test occursin("requires 'time_step_count'", sprint(showerror, invalid_error))

        invalid_boundary_metadata = deepcopy(result.restart_metadata)
        invalid_boundary_metadata["section41_boundary_status"] = "implemented_smoke_validated"
        invalid_boundary_metadata_path = joinpath(dir, "invalid-boundary-restart-metadata.json")
        StenoticHemodynamics.write_json(invalid_boundary_metadata_path, invalid_boundary_metadata; overwrite=true)
        invalid_boundary_error = try
            native_resolved_fsi_read_restart_metadata(invalid_boundary_metadata_path)
            nothing
        catch err
            err
        end
        @test invalid_boundary_error isa ArgumentError
        @test occursin("section41_boundary_status", sprint(showerror, invalid_boundary_error))

        missing_payload_field_metadata = deepcopy(result.restart_metadata)
        delete!(missing_payload_field_metadata["state_payload"], "final_wall_velocity_cm_s")
        missing_payload_field_path = joinpath(dir, "missing-state-payload-field-restart-metadata.json")
        StenoticHemodynamics.write_json(missing_payload_field_path, missing_payload_field_metadata; overwrite=true)
        missing_payload_field_error = try
            native_resolved_fsi_read_restart_metadata(missing_payload_field_path)
            nothing
        catch err
            err
        end
        @test missing_payload_field_error isa ArgumentError
        @test occursin("state_payload", sprint(showerror, missing_payload_field_error))
        @test occursin("requires 'final_wall_velocity_cm_s'", sprint(showerror, missing_payload_field_error))

        malformed_payload_metadata = deepcopy(result.restart_metadata)
        malformed_payload_metadata["state_payload"]["current_radii_cm"][2] = -1.0
        malformed_payload_path = joinpath(dir, "malformed-state-payload-restart-metadata.json")
        StenoticHemodynamics.write_json(malformed_payload_path, malformed_payload_metadata; overwrite=true)
        malformed_payload_error = try
            native_resolved_fsi_read_restart_metadata(malformed_payload_path)
            nothing
        catch err
            err
        end
        @test malformed_payload_error isa ArgumentError
        @test occursin("state_payload", sprint(showerror, malformed_payload_error))
        @test occursin("current_radii_cm", sprint(showerror, malformed_payload_error))
        @test occursin("positive", sprint(showerror, malformed_payload_error))
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
        @test all(occursin(",state_carrying_partitioned,", line) for line in manifest_lines[2:end])
        @test all(
            occursin(",ready,pressure_drop_weak_inlet_outlet_gauge_smoke,local_smoke_loading,deferred_or_not_selected,", line)
            for line in manifest_lines[2:end]
        )
        @test occursin("state-carrying partitioned solve", multi_result.method_status.status)
        @test multi_result.diagnostics_status.ready
        @test multi_result.restart_status.ready
        @test all(row -> dirname(row.output_dir) == multi_result.output_dir, multi_result.diagnostic_rows)
        @test [row.snapshot_index for row in multi_result.diagnostic_rows] == [1, 2]
        @test [row.snapshot_time_s for row in multi_result.diagnostic_rows] == [1.0e-4, 2.0e-4]
        @test [row.time_step_count for row in multi_result.diagnostic_rows] == [1, 2]
        @test all(row -> row.provenance == "state_carrying_partitioned", multi_result.diagnostic_rows)
        diagnostic_lines = readlines(multi_result.diagnostics_csv)
        @test length(diagnostic_lines) == 3
        @test occursin("snapshot-t0p0001", diagnostic_lines[2])
        @test occursin("snapshot-t0p0002", diagnostic_lines[3])
        @test multi_result.restart_metadata["current_snapshot_index"] == 2
        @test multi_result.restart_metadata["snapshot_times_s"] == [1.0e-4, 2.0e-4]
        @test length(multi_result.restart_metadata["snapshot_outputs"]) == 2
        @test multi_result.restart_metadata["restart_provenance"] == "state_carrying_partitioned"
        @test multi_result.restart_metadata["state_carrying_restart"] == true
        @test multi_result.restart_metadata["resume_supported"] == false
        @test multi_result.restart_metadata["boundary_mode"] == "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test multi_result.restart_metadata["section41_boundary_status"] == "deferred_or_not_selected"
        @test [snapshot["time_step_count"] for snapshot in multi_result.restart_metadata["snapshot_outputs"]] == [1, 2]
        @test all(
            snapshot -> snapshot["boundary_mode"] == "pressure_drop_weak_inlet_outlet_gauge_smoke",
            multi_result.restart_metadata["snapshot_outputs"],
        )
        @test multi_result.restart_metadata["state_payload"]["last_snapshot_index"] == 2
        @test multi_result.restart_metadata["state_payload"]["saved_time_s"] ≈ multi_result.saved_time_s
        @test multi_result.restart_metadata["state_payload"]["final_wall_displacement_cm"] ==
              multi_result.smoke_result.wall_displacement_cm
        @test all(
            snapshot ->
                snapshot["provenance"] == "state_carrying_partitioned" &&
                    isdir(snapshot["output_dir"]) &&
                    isfile(snapshot["velocity_xdmf"]) &&
                    isfile(snapshot["pressure_xdmf"]) &&
                    isfile(snapshot["displacement_xdmf"]),
            multi_result.restart_metadata["snapshot_outputs"],
        )

        parsed_multi_restart_metadata = native_resolved_fsi_read_restart_metadata(multi_result.restart_metadata_json)
        @test parsed_multi_restart_metadata["restart_provenance"] == "state_carrying_partitioned"
        @test parsed_multi_restart_metadata["state_carrying_restart"] == true
        @test [snapshot["time_step_count"] for snapshot in parsed_multi_restart_metadata["snapshot_outputs"]] == [1, 2]
        @test parsed_multi_restart_metadata["boundary_mode"] == "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test parsed_multi_restart_metadata["state_payload"]["last_snapshot_index"] == 2
    end

    mktempdir() do dir
        legacy_output_dir = joinpath(dir, "legacy-snapshot")
        mkpath(legacy_output_dir)
        manifest_csv = joinpath(dir, "snapshot_manifest.csv")
        diagnostics_csv = joinpath(dir, "snapshot_diagnostics.csv")
        velocity_xdmf = joinpath(legacy_output_dir, "velocity.xdmf")
        pressure_xdmf = joinpath(legacy_output_dir, "pressure.xdmf")
        displacement_xdmf = joinpath(legacy_output_dir, "displace.xdmf")
        for path in (manifest_csv, diagnostics_csv, velocity_xdmf, pressure_xdmf, displacement_xdmf)
            write(path, "")
        end
        legacy_metadata_path = joinpath(dir, "legacy-restart-metadata.json")
        StenoticHemodynamics.write_json(
            legacy_metadata_path,
            Dict{String,Any}(
                "restart_provenance" => "independent_smoke_backed_snapshots",
                "resume_supported" => false,
                "resume_status" => "deferred",
                "snapshot_manifest_csv" => manifest_csv,
                "diagnostics_csv" => diagnostics_csv,
                "snapshot_outputs" => Any[
                    Dict{String,Any}(
                        "output_dir" => legacy_output_dir,
                        "velocity_xdmf" => velocity_xdmf,
                        "pressure_xdmf" => pressure_xdmf,
                        "displacement_xdmf" => displacement_xdmf,
                    ),
                ],
            );
            overwrite=true,
        )
        legacy_metadata = native_resolved_fsi_read_restart_metadata(legacy_metadata_path)
        @test legacy_metadata["restart_provenance"] == "independent_smoke_backed_snapshots"
        @test !haskey(only(legacy_metadata["snapshot_outputs"]), "time_step_count")
        @test !haskey(legacy_metadata, "boundary_mode")
    end

    mktempdir() do dir
        coupling_iteration_spec = NativeResolvedFSIPartitionedProductionSpec(
            resolution=resolution,
            output_root=joinpath(dir, "production"),
            dt_s=1.0e-4,
            tfinal_s=1.0e-4,
            snapshot_times_s=[1.0e-4],
            coupling_iteration_count=2,
            coupling_tolerance=1.0e-30,
            coupling_under_relaxation=0.5,
        )
        coupling_result = run_native_resolved_fsi_partitioned_production(coupling_iteration_spec)
        @test coupling_result.output_status.ready
        @test coupling_result.method_status.ready
        @test coupling_result.smoke_result.max_coupling_iterations_used == 2
        @test !coupling_result.smoke_result.coupling_converged
        @test coupling_result.smoke_result.fluid_wall_boundary_mode == :prescribed_radial_wall_velocity
        @test length(coupling_result.smoke_result.coupling_residual_history) == 2
        @test all(
            row -> row.under_relaxation ≈ coupling_iteration_spec.coupling_under_relaxation,
            coupling_result.smoke_result.coupling_residual_history,
        )
        @test all(
            row -> row.fluid_wall_boundary_mode == "prescribed_radial_wall_velocity",
            coupling_result.smoke_result.coupling_residual_history,
        )
        coupling_diagnostic_row = only(coupling_result.diagnostic_rows)
        @test coupling_diagnostic_row.coupling_iteration_count == 2
        @test coupling_diagnostic_row.coupling_under_relaxation ≈ 0.5
        @test coupling_diagnostic_row.max_coupling_iterations_used == 2
        @test coupling_diagnostic_row.coupling_residual_count == 2
        @test coupling_diagnostic_row.fluid_wall_boundary_mode == "prescribed_radial_wall_velocity"
        coupling_diagnostic_header = first(readlines(coupling_result.diagnostics_csv))
        @test occursin("final_coupling_displacement_residual_cm", coupling_diagnostic_header)
        @test occursin("fluid_wall_boundary_mode", coupling_diagnostic_header)
        @test coupling_result.restart_metadata["coupling_iteration_count"] == 2
        @test coupling_result.restart_metadata["coupling_under_relaxation"] ≈ 0.5
        @test coupling_result.restart_metadata["max_coupling_iterations_used"] == 2
        @test coupling_result.restart_metadata["fluid_wall_boundary_mode"] == "prescribed_radial_wall_velocity"
        @test coupling_result.restart_metadata["wall_velocity_fluid_bc_status"] ==
              "prescribed_radial_wall_velocity_on_deformed_geometry"
        @test coupling_result.restart_metadata["boundary_mode"] == "pressure_drop_weak_inlet_outlet_gauge_smoke"
        @test coupling_result.restart_metadata["section41_boundary_status"] == "deferred_or_not_selected"
        @test length(coupling_result.restart_metadata["coupling_residual_history"]) == 2
        @test occursin("prescribed radial wall-velocity Dirichlet", coupling_result.method_status.status)
    end

    mktempdir() do dir
        exact_production_spec = NativeResolvedFSIPartitionedProductionSpec(
            resolution=resolution,
            output_root=joinpath(dir, "exact-production"),
            inlet_outlet_boundary_mode=:poiseuille_inlet_zero_outlet_stress_section41,
            inlet_umax_cm_s=45.0,
            pressure_drop_dyn_cm2=0.0,
            dt_s=1.0e-6,
            tfinal_s=1.0e-6,
            snapshot_times_s=[1.0e-6],
        )
        exact_production_result = run_native_resolved_fsi_partitioned_production(exact_production_spec)
        @test exact_production_result.output_status.ready
        @test exact_production_result.method_status.ready
        @test exact_production_result.restart_status.ready
        @test exact_production_result.smoke_result.inlet_outlet_boundary_mode ==
              :poiseuille_inlet_zero_outlet_stress_section41
        @test exact_production_result.smoke_result.section41_boundary_status.ready
        @test exact_production_result.smoke_result.pressure_projection_fallback_count == 0
        @test occursin("exact Section 4.1 inlet/outlet boundary mode", exact_production_result.method_status.status)
        @test occursin("pressure-drop fallback disabled", exact_production_result.method_status.status)
        @test occursin("paper-grade Section 4.1 parity", exact_production_result.method_status.status)
        @test occursin("remain out of scope", exact_production_result.method_status.status)
        exact_diagnostic_row = only(exact_production_result.diagnostic_rows)
        @test exact_diagnostic_row.boundary_mode == "poiseuille_inlet_zero_outlet_stress_section41"
        @test exact_diagnostic_row.boundary_mode_class == "exact_section41"
        @test exact_diagnostic_row.inlet_condition_status == "poiseuille_profile_umax_45_cm_s"
        @test exact_diagnostic_row.outlet_condition_status == "zero_outlet_stress_natural_traction"
        @test occursin("gridap_zero_mean_pressure_constraint_active", exact_diagnostic_row.pressure_nullspace_status)
        @test occursin("not_wall_stability_remediation", exact_diagnostic_row.pressure_nullspace_status)
        @test occursin(
            "pressure_drop_resistance_fallback_disabled",
            exact_diagnostic_row.wall_pressure_projection_status,
        )
        @test exact_diagnostic_row.section41_boundary_status == "implemented_smoke_validated"
        @test occursin("exact_section41_boundary_mode_selected_smoke_validated", exact_diagnostic_row.boundary_equivalence_status)
        @test exact_diagnostic_row.pressure_projection_fallback_count == 0
        @test exact_production_result.restart_metadata["inlet_umax_cm_s"] ≈ 45.0
        @test exact_production_result.restart_metadata["boundary_mode"] ==
              "poiseuille_inlet_zero_outlet_stress_section41"
        @test occursin(
            "gridap_zero_mean_pressure_constraint_active",
            exact_production_result.restart_metadata["pressure_nullspace_status"],
        )
        @test occursin("not_wall_stability_remediation", exact_production_result.restart_metadata["pressure_nullspace_status"])
        @test occursin(
            "pressure_drop_resistance_fallback_disabled",
            exact_production_result.restart_metadata["wall_pressure_projection_status"],
        )
        @test exact_production_result.restart_metadata["section41_boundary_status"] == "implemented_smoke_validated"
        exact_snapshot_metadata = only(exact_production_result.restart_metadata["snapshot_outputs"])
        @test exact_snapshot_metadata["inlet_umax_cm_s"] ≈ 45.0
        @test exact_snapshot_metadata["boundary_mode"] == "poiseuille_inlet_zero_outlet_stress_section41"
        @test occursin("gridap_zero_mean_pressure_constraint_active", exact_snapshot_metadata["pressure_nullspace_status"])
        @test occursin("pressure_drop_resistance_fallback_disabled", exact_snapshot_metadata["wall_pressure_projection_status"])
        parsed_exact_metadata = native_resolved_fsi_read_restart_metadata(
            exact_production_result.restart_metadata_json,
        )
        @test parsed_exact_metadata["inlet_umax_cm_s"] ≈ 45.0
        @test parsed_exact_metadata["boundary_mode"] == "poiseuille_inlet_zero_outlet_stress_section41"
        @test occursin("gridap_zero_mean_pressure_constraint_active", parsed_exact_metadata["pressure_nullspace_status"])
        @test occursin(
            "pressure_drop_resistance_fallback_disabled",
            parsed_exact_metadata["wall_pressure_projection_status"],
        )

        missing_umax_metadata = deepcopy(exact_production_result.restart_metadata)
        delete!(missing_umax_metadata, "inlet_umax_cm_s")
        missing_umax_path = joinpath(dir, "missing-exact-umax-restart-metadata.json")
        StenoticHemodynamics.write_json(missing_umax_path, missing_umax_metadata; overwrite=true)
        missing_umax_error = try
            native_resolved_fsi_read_restart_metadata(missing_umax_path)
            nothing
        catch err
            err
        end
        @test missing_umax_error isa ArgumentError
        @test occursin("inlet_umax_cm_s", sprint(showerror, missing_umax_error))

        invalid_projection_metadata = deepcopy(exact_production_result.restart_metadata)
        invalid_projection_metadata["wall_pressure_projection_status"] =
            "direct_wall_pressure_sampling_with_pressure_drop_resistance_fallback_if_needed; wall_pressure_profile_outlet_gauged_before_membrane_update"
        invalid_projection_path = joinpath(dir, "invalid-wall-pressure-projection-restart-metadata.json")
        StenoticHemodynamics.write_json(invalid_projection_path, invalid_projection_metadata; overwrite=true)
        invalid_projection_error = try
            native_resolved_fsi_read_restart_metadata(invalid_projection_path)
            nothing
        catch err
            err
        end
        @test invalid_projection_error isa ArgumentError
        @test occursin("wall_pressure_projection_status", sprint(showerror, invalid_projection_error))
    end

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
