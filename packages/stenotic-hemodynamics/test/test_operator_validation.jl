function operator_validation_closed_form_field(
    coordinates,
    topology;
    axial_velocity,
    transverse_velocity = _ -> (0.0, 0.0),
)
    coordinate_matrix = Matrix{Float64}(coordinates)
    topology_matrix = Matrix{Int}(topology)
    velocity = zeros(Float64, size(coordinate_matrix, 1), 3)

    for i in axes(coordinate_matrix, 1)
        coord = view(coordinate_matrix, i, :)
        transverse = transverse_velocity(coord)
        velocity[i, 1] = transverse[1]
        velocity[i, 2] = transverse[2]
        velocity[i, 3] = axial_velocity(coord)
    end

    case = StenoticHemodynamics.Resolved3DCaseSpec(
        "operator-validation-closed-form",
        0.0,
        "synthetic://operator-validation-closed-form";
        target_time=0.0,
    )
    metadata = StenoticHemodynamics.XDMFVelocityMetadata(
        0.0,
        "synthetic",
        "/geometry",
        size(coordinate_matrix),
        "synthetic",
        "/topology",
        size(topology_matrix),
        "synthetic",
        "/velocity",
        size(velocity),
    )
    return StenoticHemodynamics.Resolved3DVelocityField(
        case,
        metadata,
        topology_matrix,
        coordinate_matrix,
        velocity,
    )
end

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

@testset "StenoticHemodynamics operator validation closed-form geometry" begin
    @testset "single tetrahedron plane cut has analytic transverse area" begin
        field = operator_validation_closed_form_field(
            [
                0.0 0.0 0.0
                1.0 0.0 0.0
                0.0 1.0 0.0
                0.0 0.0 1.0
            ],
            [1 2 3 4];
            axial_velocity=_ -> 6.0,
            transverse_velocity=coord -> (100.0 + coord[1], -50.0 + coord[2]),
        )

        cut = StenoticHemodynamics.quadrature_section_observation(field, 0.25)
        row = StenoticHemodynamics.operator_validation_row(
            "constant_closed_form_single_tetra",
            field,
            (6.0, 0.0, 0.0, 0.0),
            0.25,
            0.0,
            nothing,
            1.0e-11,
        )

        @test cut.area_valid
        @test cut.cut_status == "valid"
        @test cut.intersection_count == 3
        @test cut.area_cm2 ≈ 9.0 / 32.0 atol=1.0e-12
        @test cut.mean_velocity_cm_s ≈ 6.0 atol=1.0e-12
        @test cut.flow_cm3_s ≈ 27.0 / 16.0 atol=1.0e-12
        @test row.status == "pass"
        @test row.area_cm2 ≈ 9.0 / 32.0 atol=1.0e-12
        @test row.expected_area_cm2 ≈ 9.0 / 32.0 atol=1.0e-12
        @test row.mean_velocity_cm_s ≈ 6.0 atol=1.0e-12
        @test row.expected_mean_velocity_cm_s ≈ 6.0 atol=1.0e-12
        @test row.flow_cm3_s ≈ 27.0 / 16.0 atol=1.0e-12
        @test row.expected_flow_cm3_s ≈ 27.0 / 16.0 atol=1.0e-12
    end

    @testset "disjoint tetrahedra aggregate to analytic area and affine mean" begin
        coefficients = (1.25, 2.0, -0.5, 3.0)
        affine_axial = coord ->
            coefficients[1] + coefficients[2] * coord[1] + coefficients[3] * coord[2] + coefficients[4] * coord[3]
        field = operator_validation_closed_form_field(
            [
                0.0 0.0 0.0
                1.0 0.0 0.0
                0.0 1.0 0.0
                0.0 0.0 1.0
                2.0 0.0 0.0
                4.0 0.0 0.0
                2.0 2.0 0.0
                2.0 0.0 1.0
            ],
            [
                1 2 3 4
                5 6 7 8
            ];
            axial_velocity=affine_axial,
            transverse_velocity=coord -> (coord[1] - coord[2], coord[1] + coord[2]),
        )

        cut = StenoticHemodynamics.quadrature_section_observation(field, 0.5)
        row = StenoticHemodynamics.operator_validation_row(
            "affine_closed_form_disjoint_tetrahedra",
            field,
            coefficients,
            0.5,
            0.0,
            nothing,
            1.0e-11,
        )

        @test cut.area_valid
        @test cut.cut_status == "valid"
        @test cut.intersection_count == 6
        @test cut.area_cm2 ≈ 5.0 / 8.0 atol=1.0e-12
        @test cut.mean_velocity_cm_s ≈ 32.0 / 5.0 atol=1.0e-12
        @test cut.flow_cm3_s ≈ 4.0 atol=1.0e-12
        @test row.status == "pass"
        @test row.area_cm2 ≈ 5.0 / 8.0 atol=1.0e-12
        @test row.expected_area_cm2 ≈ 5.0 / 8.0 atol=1.0e-12
        @test row.mean_velocity_cm_s ≈ 32.0 / 5.0 atol=1.0e-12
        @test row.expected_mean_velocity_cm_s ≈ 32.0 / 5.0 atol=1.0e-12
        @test row.flow_cm3_s ≈ 4.0 atol=1.0e-12
        @test row.expected_flow_cm3_s ≈ 4.0 atol=1.0e-12
        @test row.max_triangle_mean_error_cm_s <= 1.0e-12
    end
end
