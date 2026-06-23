const NativeResolvedFSIParityResult = StenoticHemodynamics.NativeResolvedFSIParityResult
const NativeResolvedFSIParitySpec = StenoticHemodynamics.NativeResolvedFSIParitySpec
const NativeResolvedFSIParityStatus = StenoticHemodynamics.NativeResolvedFSIParityStatus
const NativeResolvedFSIProductionDryRunPlan = StenoticHemodynamics.NativeResolvedFSIProductionDryRunPlan
const NativeResolvedFSIProductionParityPlan = StenoticHemodynamics.NativeResolvedFSIProductionParityPlan
const Resolved3DCaseSpec = StenoticHemodynamics.Resolved3DCaseSpec
const native_resolved_fsi_partitioned_production_dry_run =
    StenoticHemodynamics.native_resolved_fsi_partitioned_production_dry_run
const native_resolved_fsi_production_parity_plans = StenoticHemodynamics.native_resolved_fsi_production_parity_plans
const native_resolved_fsi_production_workflow_plans = StenoticHemodynamics.native_resolved_fsi_production_workflow_plans
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

        @test result.velocity_operator_status.ready
        @test result.pressure_operator_status.ready
        @test result.operator_status.ready
        @test !result.operator_status.skipped
        @test result.operator_status.discrepancy_count == 0
        @test result.operator_status.max_abs_difference ≈ 0.0 atol = 1.0e-12
        @test occursin("velocity section/radial/node-slab observations matched", result.velocity_operator_status.status)
        @test occursin("pressure section-average observations matched", result.pressure_operator_status.status)
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

        @test !result.velocity_operator_status.ready
        @test result.velocity_operator_status.discrepancy_count > 0
        @test result.velocity_operator_status.max_abs_difference > 0.0
        @test occursin("velocity observation parity", result.velocity_operator_status.status)

        @test !result.pressure_operator_status.ready
        @test result.pressure_operator_status.discrepancy_count > 0
        @test result.pressure_operator_status.max_abs_difference > 0.0
        @test occursin("pressure section-average parity", result.pressure_operator_status.status)

        @test !result.operator_status.ready
        @test !result.operator_status.skipped
        @test result.operator_status.discrepancy_count > 0
        @test result.operator_status.max_abs_difference > 0.0
        @test occursin("operator parity summary", result.operator_status.status)
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
        @test optional_result.velocity_operator_status.skipped
        @test optional_result.pressure_operator_status.skipped
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

@testset "StenoticHemodynamics native resolved-FSI pressure operator seam" begin
    mktempdir() do dir
        native_case = write_native_resolved_fsi_parity_fixture(dir, "native")
        imported_case = write_native_resolved_fsi_parity_fixture(dir, "imported"; pressure_offset_dyn_cm2=2.0)
        result = run_native_resolved_fsi_parity(native_resolved_fsi_parity_spec(native_case, imported_case))

        @test result.velocity_operator_status.ready
        @test !result.pressure_operator_status.ready
        @test result.pressure_operator_status.max_abs_difference ≈ 2.0 atol = 1.0e-12
        @test !result.operator_status.ready
    end
end

@testset "StenoticHemodynamics native resolved-FSI production parity plans" begin
    mktempdir() do dir
        write_native_resolved_fsi_parity_fixture(dir, "77")
        write_native_resolved_fsi_parity_fixture(dir, "60")
        workflow_plans = native_resolved_fsi_production_workflow_plans()
        plans = native_resolved_fsi_production_parity_plans(
            workflow_plans=workflow_plans,
            imported_data_root=dir,
        )

        @test length(plans) == 3
        @test all(plan isa NativeResolvedFSIProductionParityPlan for plan in plans)
        @test [plan.workflow_plan.case_spec.case_id for plan in plans] == [:sev23, :sev40, :sev50]
        @test plans[1].imported_case.case_label == "77"
        @test plans[2].imported_case.case_label == "60"
        @test plans[1].imported_available
        @test plans[2].imported_available
        @test !plans[3].imported_available
        @test occursin("ready", plans[1].status)
        @test occursin("ready", plans[2].status)
        @test occursin("expected-skip", plans[3].status)
        @test occursin("sev50", plans[3].status)
    end
end

@testset "StenoticHemodynamics native resolved-FSI production dry-run imported parity paths" begin
    mktempdir() do dir
        write_native_resolved_fsi_parity_fixture(dir, "77")
        workflow_plan = only(native_resolved_fsi_production_workflow_plans(
            case_ids=(:sev23,),
            output_root=joinpath(dir, "production"),
        ))
        dry_run = native_resolved_fsi_partitioned_production_dry_run(workflow_plan; imported_data_root=dir)

        @test dry_run isa NativeResolvedFSIProductionDryRunPlan
        @test dry_run.imported_available
        @test dry_run.imported_case.case_label == "77"
        @test dry_run.parity_observations_csv ==
              joinpath(dry_run.output_dir, "section41-observations", "section41_observations.csv")
        @test dry_run.parity_summary_csv ==
              joinpath(dry_run.output_dir, "section41-observations", "section41_observation_summary.csv")
        @test !ispath(dry_run.output_dir)
        @test !ispath(dirname(dry_run.parity_summary_csv))
        @test ispath(joinpath(dir, "77", "velocity.xdmf"))
    end
end

@testset "StenoticHemodynamics native resolved-FSI production observation artifacts" begin
    mktempdir() do dir
        native_case = write_native_resolved_fsi_parity_fixture(dir, "native")
        write_native_resolved_fsi_parity_fixture(dir, "77")
        workflow_plan = only(native_resolved_fsi_production_workflow_plans(case_ids=(:sev23,)))
        plan = only(native_resolved_fsi_production_parity_plans(
            workflow_plans=[workflow_plan],
            imported_data_root=dir,
        ))

        artifact = run_native_resolved_fsi_parity(
            plan,
            native_case;
            output_dir=joinpath(dir, "observations"),
            sample_z_cm=[0.25, 0.5, 0.75],
            radial_profile_z_cm=[0.5],
            radial_bin_count=3,
            node_slab_half_widths_cm=[0.6],
        )

        @test artifact.artifact_status.ready
        @test artifact.imported_status.ready
        @test artifact.velocity_operator_status.ready
        @test artifact.pressure_operator_status.ready
        @test artifact.operator_status.ready
        @test artifact.output_dir == joinpath(dir, "observations")
        @test isfile(artifact.observations_csv)
        @test artifact.summary_csv == joinpath(dir, "observations", "section41_observation_summary.csv")
        @test isfile(artifact.summary_csv)
        @test length(artifact.observation_rows) == 15
        observation_sort_keys = [
            (row.case_id, row.source, row.quantity, row.z_cm, row.case_label) for row in artifact.observation_rows
        ]
        @test observation_sort_keys == sort(observation_sort_keys)
        @test count(row -> row.source == "native", artifact.observation_rows) == 6
        @test count(row -> row.source == "imported", artifact.observation_rows) == 6
        @test count(row -> row.source == "parity", artifact.observation_rows) == 3
        @test all(row -> row.operator_name == "CrossSectionQuadratureOperator", artifact.observation_rows)
        @test all(row -> row.coordinate_mode == "deformed", artifact.observation_rows)
        @test all(row -> row.area_valid, artifact.observation_rows)
        parity_rows = [row for row in artifact.observation_rows if row.source == "parity"]
        @test all(row -> row.paired_source == "native:imported", parity_rows)
        @test all(row -> isapprox(row.mean_velocity_abs_difference_cm_s, 0.0; atol=1.0e-12), parity_rows)
        @test all(row -> isapprox(row.mean_pressure_abs_difference_dyn_cm2, 0.0; atol=1.0e-12), parity_rows)

        lines = readlines(artifact.observations_csv)
        @test length(lines) == 16
        @test startswith(lines[2], "sev23,77,imported,pressure,")
        @test startswith(
            lines[1],
            "case_id,case_label,source,quantity,snapshot_time_s,z_cm,operator_name,coordinate_mode,area_cm2,flow_cm3_s,mean_velocity_cm_s,mean_pressure_dyn_cm2",
        )
        @test occursin("mean_velocity_abs_difference_cm_s", lines[1])
        @test occursin("mean_pressure_abs_difference_dyn_cm2", lines[1])
        @test any(occursin(",native,velocity,", line) for line in lines[2:end])
        @test any(occursin(",imported,pressure,", line) for line in lines[2:end])
        @test any(occursin(",parity,velocity_pressure,", line) for line in lines[2:end])

        @test length(artifact.summary_rows) == 6
        summary_sort_keys = [(row.case_id, row.source, row.quantity) for row in artifact.summary_rows]
        @test summary_sort_keys == sort(summary_sort_keys)
        @test all(row -> row.case_id == "sev23", artifact.summary_rows)
        @test count(row -> row.source == "native", artifact.summary_rows) == 2
        @test count(row -> row.source == "imported", artifact.summary_rows) == 2
        @test count(row -> row.source == "parity", artifact.summary_rows) == 2
        parity_velocity_summary = only(row for row in artifact.summary_rows if row.source == "parity" && row.quantity == "velocity")
        parity_pressure_summary = only(row for row in artifact.summary_rows if row.source == "parity" && row.quantity == "pressure")
        @test parity_velocity_summary.row_count == 3
        @test parity_velocity_summary.ready_row_count == 3
        @test parity_velocity_summary.max_mean_velocity_abs_difference_cm_s ≈ 0.0 atol = 1.0e-12
        @test isnan(parity_velocity_summary.max_mean_pressure_abs_difference_dyn_cm2)
        @test occursin("velocity section/radial/node-slab observations matched", parity_velocity_summary.status)
        @test parity_pressure_summary.row_count == 3
        @test parity_pressure_summary.ready_row_count == 3
        @test isnan(parity_pressure_summary.max_mean_velocity_abs_difference_cm_s)
        @test parity_pressure_summary.max_mean_pressure_abs_difference_dyn_cm2 ≈ 0.0 atol = 1.0e-12
        @test occursin("pressure section-average observations matched", parity_pressure_summary.status)

        summary_lines = readlines(artifact.summary_csv)
        @test length(summary_lines) == 7
        @test summary_lines[1] ==
            "case_id,source,quantity,row_count,ready_row_count,max_mean_velocity_abs_difference_cm_s,max_mean_pressure_abs_difference_dyn_cm2,status"
        @test any(occursin(",parity,velocity,3,3,0.0,NaN,", line) for line in summary_lines[2:end])
        @test any(occursin(",parity,pressure,3,3,NaN,0.0,", line) for line in summary_lines[2:end])
    end
end

@testset "StenoticHemodynamics native resolved-FSI production observation expected skip" begin
    mktempdir() do dir
        native_case = write_native_resolved_fsi_parity_fixture(dir, "native")
        workflow_plan = only(native_resolved_fsi_production_workflow_plans(case_ids=(:sev23,)))
        plan = only(native_resolved_fsi_production_parity_plans(
            workflow_plans=[workflow_plan],
            imported_data_root=joinpath(dir, "missing-imported"),
        ))

        artifact = run_native_resolved_fsi_parity(
            plan,
            native_case;
            output_dir=joinpath(dir, "observations-skip"),
            sample_z_cm=[0.25, 0.5],
            radial_profile_z_cm=[0.5],
            radial_bin_count=3,
            node_slab_half_widths_cm=[0.6],
        )

        @test artifact.artifact_status.ready
        @test !artifact.imported_status.ready
        @test occursin("expected-skip", artifact.imported_status.status)
        @test artifact.parity_result.imported_bundle === nothing
        @test artifact.operator_status.skipped
        @test isfile(artifact.observations_csv)
        @test isfile(artifact.summary_csv)
        @test length(artifact.observation_rows) == 4
        observation_sort_keys = [
            (row.case_id, row.source, row.quantity, row.z_cm, row.case_label) for row in artifact.observation_rows
        ]
        @test observation_sort_keys == sort(observation_sort_keys)
        @test all(row -> row.source == "native", artifact.observation_rows)
        @test count(row -> row.quantity == "velocity", artifact.observation_rows) == 2
        @test count(row -> row.quantity == "pressure", artifact.observation_rows) == 2
        @test all(row -> row.area_valid, artifact.observation_rows)
        @test !any(row -> row.source == "parity", artifact.observation_rows)

        @test length(artifact.summary_rows) == 4
        native_summary_rows = [row for row in artifact.summary_rows if row.source == "native"]
        imported_summary_rows = [row for row in artifact.summary_rows if row.source == "imported"]
        @test length(native_summary_rows) == 2
        @test length(imported_summary_rows) == 2
        @test all(row -> row.row_count == 2, native_summary_rows)
        @test all(row -> row.ready_row_count == 2, native_summary_rows)
        @test all(row -> row.status == "ready", native_summary_rows)
        @test Set(row.quantity for row in imported_summary_rows) == Set(["velocity", "pressure"])
        @test all(row -> row.row_count == 0, imported_summary_rows)
        @test all(row -> row.ready_row_count == 0, imported_summary_rows)
        @test all(row -> isnan(row.max_mean_velocity_abs_difference_cm_s), imported_summary_rows)
        @test all(row -> isnan(row.max_mean_pressure_abs_difference_dyn_cm2), imported_summary_rows)
        @test all(row -> occursin("expected-skip", row.status), imported_summary_rows)
        @test all(row -> occursin("missing required three-field XDMF inputs", row.status), imported_summary_rows)
        summary_lines = readlines(artifact.summary_csv)
        @test length(summary_lines) == 5
        @test any(occursin(",imported,velocity,0,0,NaN,NaN,", line) for line in summary_lines[2:end])
        @test any(occursin(",imported,pressure,0,0,NaN,NaN,", line) for line in summary_lines[2:end])
        @test any(occursin("expected-skip", line) for line in summary_lines[2:end])
    end
end
