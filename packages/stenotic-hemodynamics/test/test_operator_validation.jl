@testset "StenoticHemodynamics operator validation workflow" begin
    mktempdir() do dir
        spec = StenoticHemodynamics.OperatorValidationSpec(
            output_dir=dir,
            sample_z_cm=[0.25, 0.5, 0.75],
            plane_shift_center_cm=0.5,
            plane_shifts_cm=[-0.05, 0.0, 0.05],
            overwrite=true,
        )
        @test StenoticHemodynamics.workflow_kind(spec) == "cross_section_operator_validation"
        @test StenoticHemodynamics.default_output_paths(spec).summary_csv ==
              joinpath(dir, "cross_section_operator_validation.csv")

        result = StenoticHemodynamics.run_operator_validation(spec)
        @test result isa StenoticHemodynamics.OperatorValidationResult
        @test length(result.rows) == 9
        @test isfile(result.summary_csv)
        @test isfile(result.summary_tex)
        @test all(row -> row.status == "pass", result.rows)
        @test all(row -> row.cut_status == "valid", result.rows)

        constant_mid = only(row for row in result.rows if row.validation_case == "constant" && row.z_cm == 0.5)
        @test constant_mid.area_cm2 ≈ 0.125 atol=1.0e-14
        @test constant_mid.mean_velocity_cm_s ≈ spec.constant_value_cm_s atol=1.0e-12
        @test constant_mid.flow_cm3_s ≈ spec.constant_value_cm_s * constant_mid.area_cm2 atol=1.0e-12
        @test constant_mid.mean_abs_error_cm_s <= spec.tolerance
        @test constant_mid.flow_abs_error_cm3_s <= spec.tolerance

        affine_mid = only(row for row in result.rows if row.validation_case == "affine" && row.z_cm == 0.5)
        expected_affine_mean =
            spec.affine_coefficients[1] +
            spec.affine_coefficients[2] * (1.0 / 6.0) +
            spec.affine_coefficients[3] * (1.0 / 6.0) +
            spec.affine_coefficients[4] * 0.5
        @test affine_mid.area_cm2 ≈ 0.125 atol=1.0e-14
        @test affine_mid.expected_mean_velocity_cm_s ≈ expected_affine_mean atol=1.0e-12
        @test affine_mid.mean_velocity_cm_s ≈ expected_affine_mean atol=1.0e-12
        @test affine_mid.max_triangle_mean_error_cm_s <= spec.tolerance

        plane_base = only(row for row in result.rows if row.validation_case == "plane_shift" && row.shift_cm == 0.0)
        plane_left = only(row for row in result.rows if row.validation_case == "plane_shift" && row.shift_cm < 0.0)
        plane_right = only(row for row in result.rows if row.validation_case == "plane_shift" && row.shift_cm > 0.0)
        @test plane_base.area_delta_cm2 ≈ 0.0 atol=1.0e-14
        @test plane_base.flow_delta_cm3_s ≈ 0.0 atol=1.0e-14
        @test plane_base.mean_velocity_delta_cm_s ≈ 0.0 atol=1.0e-14
        @test plane_left.z_cm ≈ 0.45
        @test plane_right.z_cm ≈ 0.55
        @test plane_left.area_delta_cm2 > 0.0
        @test plane_right.area_delta_cm2 < 0.0
        @test plane_left.mean_velocity_delta_cm_s < 0.0
        @test plane_right.mean_velocity_delta_cm_s > 0.0

        csv_rows = read_simple_csv(result.summary_csv)
        @test length(csv_rows) == length(result.rows)
        @test parse(Float64, only(row for row in csv_rows if row["validation_case"] == "constant" && row["z_cm"] == "0.5")["mean_velocity_cm_s"]) ≈
              spec.constant_value_cm_s
        tex_source = read(result.summary_tex, String)
        @test occursin("\\begin{tabular}", tex_source)
        @test occursin("plane\\_shift", tex_source)
    end

    @test_throws ArgumentError StenoticHemodynamics.validate_workflow_spec(
        StenoticHemodynamics.OperatorValidationSpec(sample_z_cm=[1.0]),
    )
    @test_throws ArgumentError StenoticHemodynamics.OperatorValidationSpec(affine_coefficients=[1.0, 2.0, 3.0])
end
