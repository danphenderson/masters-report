if !isdefined(@__MODULE__, :write_custom_tetra_xdmf_hdf5_case)
    include(joinpath(@__DIR__, "test_helpers.jl"))
end

function write_section41_pressure_gauge_fsi_xdmf_hdf5_case(
    case_dir::String;
    time::Float64,
)
    length_cm = StenoticHemodynamics.SECTION41_LENGTH_CM
    coords = [
        0.0 0.0 0.0
        0.10 0.0 length_cm
        0.0 0.10 length_cm
        -0.10 0.0 length_cm
    ]
    velocity_xdmf, _, velocity_values = write_custom_tetra_xdmf_hdf5_case(
        case_dir,
        coords;
        time=time,
        velocity_function=coord -> 10.0 + coord[3],
    )
    topology = Int32[0 1 2 3]
    pressure_values = zeros(Float64, size(coords, 1), 1)
    displacement_values = zeros(Float64, size(coords, 1), 3)
    for i in axes(coords, 1)
        pressure_values[i, 1] = 20.0 + coords[i, 3]
    end
    write_xdmf_hdf5_field(case_dir, "pressure", coords, topology, pressure_values, "Scalar", time)
    write_xdmf_hdf5_field(case_dir, "displace", coords, topology, displacement_values, "Vector", time)
    return velocity_xdmf, coords, velocity_values, pressure_values, displacement_values
end

@testset "StenoticHemodynamics Canic Section 4.1 source-artifact comparison workflow" begin
    records = StenoticHemodynamics.canic_section41_case_records()
    @test [record.imported_label for record in records] == ["77", "60", "50"]
    @test records[1].case_id == :sev23
    @test records[1].reduced_severity ≈ 100.0 * 0.0406 / 0.18
    @test records[1].expected_upstream_time_s ≈ 0.99949999999994532
    @test records[2].expected_upstream_time_s ≈ 0.99949999999994532
    @test records[3].expected_upstream_time_s ≈ 1.4994999999998904
    @test StenoticHemodynamics.native_resolved_fsi_imported_case_spec("50").case_id == :sev50
    sev50_time_alignment = StenoticHemodynamics.canic_section41_time_alignment(
        records[3].expected_upstream_time_s,
        1.0,
        1.0e-6,
    )
    @test !sev50_time_alignment.aligned
    @test sev50_time_alignment.imported_local_time_offset_s ≈ 0.4995
    @test sev50_time_alignment.status == "diagnostic_comparison_only_not_time_aligned_non_replication"
    default_spec = StenoticHemodynamics.CanicSection41ReplicationSpec()
    override_spec = StenoticHemodynamics.CanicSection41ReplicationSpec(tfinal_s=1.0)
    @test StenoticHemodynamics.canic_section41_time_target_policy(default_spec) == "per_case_imported_time"
    @test StenoticHemodynamics.canic_section41_time_target_policy(override_spec) == "global_tfinal_override"
    @test StenoticHemodynamics.canic_section41_local_target_time(records[3].expected_upstream_time_s, default_spec) ≈
          records[3].expected_upstream_time_s
    @test StenoticHemodynamics.canic_section41_local_target_time(records[3].expected_upstream_time_s, override_spec) ≈
          1.0
    sev50_override_alignment = StenoticHemodynamics.canic_section41_time_alignment(
        records[3].expected_upstream_time_s,
        1.0,
        1.0,
        1.0e-6;
        override_used=true,
    )
    @test !sev50_override_alignment.aligned
    @test !sev50_override_alignment.target_aligned
    @test sev50_override_alignment.status == "diagnostic_comparison_only_intentional_time_mismatch_non_replication"

    mktempdir() do dir
        missing = StenoticHemodynamics.canic_section41_missing_files(joinpath(dir, "missing"))
        @test length(missing) == 18
        @test occursin(joinpath("77", "velocity.xdmf"), first(missing))
    end

    mktempdir() do dir
        data_root = joinpath(dir, "case3_all_3d_results")
        for (label, time) in (
            ("77", records[1].expected_upstream_time_s),
            ("60", records[2].expected_upstream_time_s),
            ("50", records[3].expected_upstream_time_s),
        )
            write_section41_pressure_gauge_fsi_xdmf_hdf5_case(joinpath(data_root, label); time=time)
        end

        spec = StenoticHemodynamics.CanicSection41ReplicationSpec(
            data_root=dir,
            output_dir=joinpath(dir, "out"),
            nx=6,
            dt_s=0.5,
            section_count=3,
            radial_sample_count=5,
            models=("canic-extended-1d",),
            overwrite=true,
        )
        @test isempty(StenoticHemodynamics.canic_section41_missing_files(spec.data_root))
        audit_rows = StenoticHemodynamics.canic_section41_parameter_audit_rows(spec)
        @test eltype(audit_rows) === StenoticHemodynamics.CanicSection41ParameterAuditRow
        @test fieldnames(StenoticHemodynamics.CanicSection41ParameterAuditRow) == (
            :quantity,
            :source_pair,
            :paper_or_local_value,
            :upstream_or_observed_value,
            :status,
            :note,
        )
        @test propertynames(first(audit_rows)) == fieldnames(StenoticHemodynamics.CanicSection41ParameterAuditRow)
        @test fieldnames(StenoticHemodynamics.CanicSection41ComparisonRow) == (
            :case_id,
            :paper_severity_percent,
            :imported_case,
            :model,
            :coordinate_mode,
            :z_cm,
            :reference_time_s,
            :imported_time_s,
            :paper_time_offset_s,
            :local_target_time_s,
            :imported_local_target_time_offset_s,
            :local_completed_time_s,
            :imported_local_time_offset_s,
            :time_alignment_tolerance_s,
            :local_time_target_policy,
            :time_alignment_status,
            :area_cm2,
            :mean_velocity_3d_cm_s,
            :mean_velocity_1d_cm_s,
            :velocity_abs_error_cm_s,
            :velocity_rel_error,
            :mean_pressure_3d_dyn_cm2,
            :pressure_1d_dyn_cm2,
            :pressure_abs_error_dyn_cm2,
            :pressure_comparison_status,
            :intersection_count,
            :velocity_cut_status,
            :pressure_cut_status,
        )
        @test fieldnames(StenoticHemodynamics.CanicSection41SummaryRow) == (
            :case_id,
            :paper_severity_percent,
            :imported_case,
            :model,
            :coordinate_mode,
            :section_count,
            :reference_time_s,
            :imported_time_s,
            :paper_time_offset_s,
            :local_target_time_s,
            :imported_local_target_time_offset_s,
            :local_completed_time_s,
            :imported_local_time_offset_s,
            :time_alignment_tolerance_s,
            :local_time_target_policy,
            :time_alignment_status,
            :max_velocity_abs_error_cm_s,
            :mean_velocity_abs_error_cm_s,
            :max_velocity_rel_error,
            :mean_velocity_rel_error,
            :max_pressure_abs_error_dyn_cm2,
            :mean_pressure_abs_error_dyn_cm2,
            :pressure_comparison_status,
            :status,
        )
        @test fieldnames(StenoticHemodynamics.CanicSection41RadialVelocityRow) == (
            :case_id,
            :paper_severity_percent,
            :model,
            :z_cm,
            :section_radius_cm,
            :r_cm,
            :radial_velocity_cm_s,
            :status,
        )
        @test fieldnames(StenoticHemodynamics.CanicSection41Figure6DiagnosticsRow) == (
            :case_id,
            :paper_severity_percent,
            :imported_case,
            :coordinate_mode,
            :snapshot_time_s,
            :max_speed_cm_s,
            :max_axial_velocity_cm_s,
            :max_radial_speed_cm_s,
            :min_axial_velocity_cm_s,
            :status,
        )
        @test any(row -> row[1] == "young_modulus_dyn_cm2" && row[5] == "mismatch_requires_classification", audit_rows)
        @test any(row -> row[1] == "snapshot_time_s_case50" && row[5] == "source_time_differs_from_paper_text", audit_rows)

        radial_rows = StenoticHemodynamics.canic_section41_radial_velocity_profile(
            1.0,
            0.1,
            0.1,
            0.0;
            sample_count=5,
        )
        @test length(radial_rows) == 5
        @test all(row -> row.radial_velocity_cm_s == 0.0, radial_rows)
        nonzero_radial_rows = StenoticHemodynamics.canic_section41_radial_velocity_profile(
            1.0,
            0.1,
            0.1,
            0.02;
            sample_count=5,
        )
        @test length(nonzero_radial_rows) == 5
        @test all(row -> isfinite(row.radial_velocity_cm_s), nonzero_radial_rows)

        result = StenoticHemodynamics.run_canic_section41_replication(spec)
        @test result.status == "ok"
        for path in (
            result.provenance_json,
            result.parameter_audit_csv,
            result.comparison_csv,
            result.summary_csv,
            result.radial_velocity_csv,
            result.figure6_diagnostics_csv,
            result.parameter_audit_tex,
            result.summary_tex,
        )
            @test isfile(path)
        end
        @test occursin(StenoticHemodynamics.CANIC_2024_SOURCE_COMMIT, read(result.provenance_json, String))
        @test occursin("mismatch_requires_classification", read(result.parameter_audit_csv, String))
        @test occursin("source_time_differs_from_paper_text", read(result.parameter_audit_csv, String))
        @test occursin("canic-extended-1d", read(result.summary_csv, String))
        summary_tex = read(result.summary_tex, String)
        @test occursin("C23 (22.56\\%)", summary_tex)
        @test !occursin("sev23 &", summary_tex)
        @test occursin("qualitative_3d_velocity_field_diagnostic", read(result.figure6_diagnostics_csv, String))

        comparison_lines = split(chomp(read(result.comparison_csv, String)), '\n')
        comparison_header = split(comparison_lines[1], ',')
        @test comparison_header == collect(string.(fieldnames(StenoticHemodynamics.CanicSection41ComparisonRow)))
        comparison_text = join(comparison_lines, '\n')
        @test occursin(
            "reference_time_s,imported_time_s,paper_time_offset_s,local_target_time_s,imported_local_target_time_offset_s,local_completed_time_s,imported_local_time_offset_s,time_alignment_tolerance_s,local_time_target_policy,time_alignment_status",
            comparison_text,
        )
        @test occursin("pressure_comparison_status", comparison_text)
        @test occursin(StenoticHemodynamics.CANIC_SECTION41_PRESSURE_STATUS, comparison_text)

        summary_lines = split(chomp(read(result.summary_csv, String)), '\n')
        summary_header = split(summary_lines[1], ',')
        @test summary_header == collect(string.(fieldnames(StenoticHemodynamics.CanicSection41SummaryRow)))
        radial_header = split(first(readlines(result.radial_velocity_csv)), ',')
        @test radial_header == collect(string.(fieldnames(StenoticHemodynamics.CanicSection41RadialVelocityRow)))
        figure6_header = split(first(readlines(result.figure6_diagnostics_csv)), ',')
        @test figure6_header == collect(string.(fieldnames(StenoticHemodynamics.CanicSection41Figure6DiagnosticsRow)))
        summary_rows = [split(line, ',') for line in summary_lines[2:end]]
        header_index(name) = something(findfirst(==(name), summary_header), 0)
        case_id_index = header_index("case_id")
        model_index = header_index("model")
        reference_time_index = header_index("reference_time_s")
        imported_time_index = header_index("imported_time_s")
        local_completed_time_index = header_index("local_completed_time_s")
        local_target_time_index = header_index("local_target_time_s")
        target_offset_index = header_index("imported_local_target_time_offset_s")
        time_offset_index = header_index("imported_local_time_offset_s")
        time_status_index = header_index("time_alignment_status")
        time_policy_index = header_index("local_time_target_policy")
        pressure_error_index = header_index("max_pressure_abs_error_dyn_cm2")
        pressure_status_index = header_index("pressure_comparison_status")
        @test all(>(0), (
            case_id_index,
            model_index,
            reference_time_index,
            imported_time_index,
            local_target_time_index,
            target_offset_index,
            local_completed_time_index,
            time_offset_index,
            time_status_index,
            time_policy_index,
            pressure_error_index,
            pressure_status_index,
        ))
        sev50_summary = only(
            row for row in summary_rows
            if row[case_id_index] == "sev50" && row[model_index] == "canic-extended-1d"
        )
        @test parse(Float64, sev50_summary[reference_time_index]) ≈ 1.4995
        @test parse(Float64, sev50_summary[imported_time_index]) ≈ 1.4995
        @test parse(Float64, sev50_summary[local_target_time_index]) ≈ records[3].expected_upstream_time_s
        @test parse(Float64, sev50_summary[target_offset_index]) ≈ 0.0 atol = 1.0e-12
        @test parse(Float64, sev50_summary[local_completed_time_index]) ≈ records[3].expected_upstream_time_s
        @test parse(Float64, sev50_summary[time_offset_index]) ≈ 0.0 atol = 1.0e-12
        @test sev50_summary[time_policy_index] == "per_case_imported_time"
        @test sev50_summary[time_status_index] == "source_artifact_reconstruction_comparison_time_aligned"
        @test isfinite(parse(Float64, sev50_summary[pressure_error_index]))
        @test parse(Float64, sev50_summary[pressure_error_index]) >= 0.0
        @test sev50_summary[pressure_status_index] == StenoticHemodynamics.CANIC_SECTION41_PRESSURE_STATUS
    end
end
