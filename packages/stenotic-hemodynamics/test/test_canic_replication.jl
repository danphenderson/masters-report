@testset "StenoticHemodynamics Canic Section 4.1 replication workflow" begin
    records = StenoticHemodynamics.canic_section41_case_records()
    @test [record.imported_label for record in records] == ["77", "60", "50"]
    @test records[1].case_id == :sev23
    @test records[1].reduced_severity ≈ 100.0 * 0.0406 / 0.18
    @test StenoticHemodynamics.native_resolved_fsi_imported_case_spec("50").case_id == :sev50

    mktempdir() do dir
        missing = StenoticHemodynamics.canic_section41_missing_files(joinpath(dir, "missing"))
        @test length(missing) == 18
        @test occursin(joinpath("77", "velocity.xdmf"), first(missing))
    end

    mktempdir() do dir
        data_root = joinpath(dir, "case3_all_3d_results")
        for (label, time) in (("77", 0.9995), ("60", 0.9995), ("50", 1.4995))
            write_synthetic_fsi_xdmf_hdf5_case(joinpath(data_root, label); time=time)
        end

        spec = StenoticHemodynamics.CanicSection41ReplicationSpec(
            data_root=dir,
            output_dir=joinpath(dir, "out"),
            nx=6,
            tfinal_s=0.0,
            section_count=3,
            radial_sample_count=5,
            models=("canic-extended-1d",),
            overwrite=true,
        )
        @test isempty(StenoticHemodynamics.canic_section41_missing_files(spec.data_root))
        audit_rows = StenoticHemodynamics.canic_section41_parameter_audit_rows(spec)
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
        @test occursin("qualitative_3d_velocity_field_diagnostic", read(result.figure6_diagnostics_csv, String))
    end
end
