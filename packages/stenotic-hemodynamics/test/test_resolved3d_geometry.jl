const parse_xdmf_velocity = StenoticHemodynamics.parse_xdmf_velocity

@testset "StenoticHemodynamics resolved 3D parsing and loading" begin
    mktempdir() do dir
        xdmf_path, coords, velocity_values = write_synthetic_xdmf_hdf5_case(joinpath(dir, "synthetic"))

        metadata = parse_xdmf_velocity(xdmf_path)
        @test metadata.time ≈ 5.0e-5
        @test metadata.geometry_file == "velocity.h5"
        @test metadata.geometry_path == "/Mesh/0/mesh/geometry"
        @test metadata.geometry_dims == (size(coords, 1), 3)
        @test metadata.topology_path == "/Mesh/0/mesh/topology"
        @test metadata.topology_dims == (2, 4)
        @test metadata.velocity_path == "/VisualisationVector/0"
        @test metadata.velocity_dims == (size(velocity_values, 1), 3)

        case_spec = StenoticHemodynamics.Resolved3DCaseSpec("synthetic", 23.0, xdmf_path; target_time=5.0e-5)
        field = StenoticHemodynamics.load_resolved3d_velocity(case_spec)
        @test size(field.coordinates) == size(coords)
        @test size(field.velocity) == size(velocity_values)
        @test minimum(field.topology) == 1
        @test maximum(field.topology) <= size(coords, 1)
        @test field.metadata.time ≈ 5.0e-5

        mismatched_time = StenoticHemodynamics.Resolved3DCaseSpec("synthetic", 23.0, xdmf_path; target_time=1.0, time_atol=1.0e-8)
        @test_throws ArgumentError StenoticHemodynamics.load_resolved3d_velocity(mismatched_time)

        missing_xdmf_path, _, _ = write_synthetic_xdmf_hdf5_case(
            joinpath(dir, "missing_velocity");
            omit_velocity_dataset=true,
        )
        missing_velocity = StenoticHemodynamics.Resolved3DCaseSpec("missing", 23.0, missing_xdmf_path; target_time=5.0e-5)
        @test_throws ArgumentError StenoticHemodynamics.load_resolved3d_velocity(missing_velocity)
    end
end

@testset "StenoticHemodynamics cross-section quadrature" begin
    mktempdir() do dir
        xdmf_path, _, _ = write_single_tetra_xdmf_hdf5_case(joinpath(dir, "tetra"))
        case_spec = StenoticHemodynamics.Resolved3DCaseSpec("tetra", 0.0, xdmf_path; target_time=5.0e-5)
        field = StenoticHemodynamics.load_resolved3d_velocity(case_spec)

        mid = StenoticHemodynamics.quadrature_section_observation(field, 0.5)
        @test mid.area_valid
        @test mid.cut_status == "valid"
        @test mid.area_cm2 ≈ 0.125
        @test mid.flow_cm3_s / mid.area_cm2 ≈ 10.5
        @test mid.intersection_count == 3

        face = StenoticHemodynamics.quadrature_section_observation(field, 0.0)
        @test face.area_valid
        @test face.cut_status == "valid"
        @test face.area_cm2 ≈ 0.5
        @test face.mean_velocity_cm_s ≈ 10.0

        empty = StenoticHemodynamics.quadrature_section_observation(field, 2.0)
        @test !empty.area_valid
        @test empty.cut_status == "empty-plane"
        @test empty.intersection_count == 0

        tangent = StenoticHemodynamics.quadrature_section_observation(field, 1.0)
        @test !tangent.area_valid
        @test tangent.cut_status == "degenerate-cut"

        radial = StenoticHemodynamics.radial_profile_observations(
            field,
            0.5,
            1.0,
            4,
            StenoticHemodynamics.CrossSectionQuadratureOperator(),
        )
        @test sum(row.area_valid ? row.area_cm2 : 0.0 for row in radial) ≈ mid.area_cm2
        @test any(row.intersection_count > 0 for row in radial)

        constant_path, _, _ = write_single_tetra_xdmf_hdf5_case(
            joinpath(dir, "constant");
            velocity_function=coord -> 12.25,
        )
        constant_field = StenoticHemodynamics.load_resolved3d_velocity(
            StenoticHemodynamics.Resolved3DCaseSpec("constant", 0.0, constant_path; target_time=5.0e-5),
        )
        constant_mid = StenoticHemodynamics.quadrature_section_observation(constant_field, 0.5)
        @test constant_mid.area_valid
        @test constant_mid.mean_velocity_cm_s ≈ 12.25 atol=1.0e-12
        @test constant_mid.flow_cm3_s ≈ 12.25 * constant_mid.area_cm2 atol=1.0e-12

        linear_path, _, _ = write_single_tetra_xdmf_hdf5_case(
            joinpath(dir, "linear");
            velocity_function=coord -> 2.0 + 3.0 * coord[1] + 5.0 * coord[2] + 7.0 * coord[3],
        )
        linear_field = StenoticHemodynamics.load_resolved3d_velocity(
            StenoticHemodynamics.Resolved3DCaseSpec("linear", 0.0, linear_path; target_time=5.0e-5),
        )
        linear_mid = StenoticHemodynamics.quadrature_section_observation(linear_field, 0.5)
        exact_linear_mean = 2.0 + 3.0 * (1.0 / 6.0) + 5.0 * (1.0 / 6.0) + 7.0 * 0.5
        @test linear_mid.area_valid
        @test linear_mid.area_cm2 ≈ 0.125 atol=1.0e-12
        @test linear_mid.mean_velocity_cm_s ≈ exact_linear_mean atol=1.0e-12
        @test linear_mid.flow_cm3_s ≈ linear_mid.area_cm2 * exact_linear_mean atol=1.0e-12

        vertex_path, _, _ = write_custom_tetra_xdmf_hdf5_case(
            joinpath(dir, "vertex_on_plane"),
            [
                0.0 0.0 0.0
                1.0 0.0 -1.0
                0.0 1.0 -1.0
                0.0 0.0 1.0
            ];
            velocity_function=coord -> 4.0 + coord[1] - coord[2] + 2.0 * coord[3],
        )
        vertex_field = StenoticHemodynamics.load_resolved3d_velocity(
            StenoticHemodynamics.Resolved3DCaseSpec("vertex", 0.0, vertex_path; target_time=5.0e-5),
        )
        vertex_cut = StenoticHemodynamics.quadrature_section_observation(vertex_field, 0.0)
        @test vertex_cut.area_valid
        @test vertex_cut.cut_status == "valid"
        @test isfinite(vertex_cut.flow_cm3_s)
        @test vertex_cut.intersection_count == 3

        edge_path, _, _ = write_custom_tetra_xdmf_hdf5_case(
            joinpath(dir, "edge_on_plane"),
            [
                0.0 0.0 0.0
                1.0 0.0 0.0
                0.0 1.0 1.0
                0.0 0.0 1.0
            ],
        )
        edge_field = StenoticHemodynamics.load_resolved3d_velocity(
            StenoticHemodynamics.Resolved3DCaseSpec("edge", 0.0, edge_path; target_time=5.0e-5),
        )
        edge_cut = StenoticHemodynamics.quadrature_section_observation(edge_field, 0.0)
        @test !edge_cut.area_valid
        @test edge_cut.cut_status == "degenerate-cut"
        @test edge_cut.intersection_count == 0
    end
end

@testset "StenoticHemodynamics resolved 3D comparison diagnostics" begin
    mktempdir() do dir
        xdmf_path, _, _ = write_synthetic_xdmf_hdf5_case(joinpath(dir, "case77"); time=4.5e-5)
        case_spec = StenoticHemodynamics.Resolved3DCaseSpec("77", 23.0, xdmf_path; target_time=5.0e-5)
        output_dir = joinpath(dir, "out")
        spec = StenoticHemodynamics.ComparisonSpec(
            cases=[case_spec],
            base_params=Params(nx=8, tfinal=5.0e-5, severity=23.0, initial_condition=GeometryRestIC()),
            output_dir=output_dir,
            section_count=3,
            profile_slices=[0.0],
            radial_bins=5,
            overwrite=true,
            write_svg=false,
        )
        expected_spec_type =
            StenoticHemodynamics.ComparisonSpec{NativeRK3Backend,StenoticHemodynamics.CrossSectionQuadratureOperator}
        @test typeof(spec) <: expected_spec_type

        result = StenoticHemodynamics.run_comparison(spec)
        @test length(result.section_rows) == 3
        @test length(result.profile_rows) == 5
        @test length(result.sensitivity_rows) == 9
        @test length(result.summary_rows) == 1
        @test isfile(result.section_csvs[1])
        @test isfile(result.profile_csvs[1])
        @test isfile(result.sensitivity_csv)
        @test isfile(result.summary_csv)
        time_columns = [
            "target_time_s",
            "time_atol_s",
            "one_d_completed_time_s",
            "one_d_terminal_time_error_s",
            "xdmf_target_time_error_s",
            "cross_model_time_offset_s",
        ]
        provenance_columns = [
            "model",
            "nx",
            "dt_s",
            "initial_condition",
            "backend",
            "run_status",
        ]
        production_columns = [
            "accepted_dt_min",
            "accepted_dt_max",
            "realized_cfl_max",
            "min_solver_area",
            "min_physical_area_cm2",
            "solver_volume_defect",
            "positivity_projection_count",
            "final_area_flux_balance",
            "final_rhs_area_max_abs",
            "final_rhs_flow_max_abs",
        ]
        for path in (result.section_csvs[1], result.profile_csvs[1], result.sensitivity_csv, result.summary_csv)
            header = split(readline(path), ",")
            @test "time_offset_s" in header
            @test all(in(header), time_columns)
            @test all(in(header), provenance_columns)
            if path == result.summary_csv
                @test all(in(header), production_columns)
            end
            csv_row = first(read_simple_csv(path))
            xdmf_time = parse(Float64, csv_row["xdmf_time_s"])
            target_time = parse(Float64, csv_row["target_time_s"])
            one_d_completed_time = parse(Float64, csv_row["one_d_completed_time_s"])
            @test csv_row["model"] == "canic-extended-1d"
            @test csv_row["nx"] == "8"
            @test parse(Float64, csv_row["dt_s"]) ≈ spec.base_params.dt
            @test csv_row["initial_condition"] == "geometry-rest"
            @test csv_row["backend"] == "native"
            @test csv_row["run_status"] == "ok"
            @test parse(Float64, csv_row["time_atol_s"]) ≈ case_spec.time_atol
            @test parse(Float64, csv_row["time_offset_s"]) ≈ parse(Float64, csv_row["xdmf_target_time_error_s"])
            @test parse(Float64, csv_row["xdmf_target_time_error_s"]) ≈ abs(xdmf_time - target_time)
            @test parse(Float64, csv_row["cross_model_time_offset_s"]) ≈ abs(xdmf_time - one_d_completed_time)
        end

        report_dir = joinpath(dir, "report-assets")
        report_paths = StenoticHemodynamics.publish_resolved3d_report_assets(result; output_dir=report_dir, overwrite=true)
        area_audit_path = joinpath(report_dir, "area-audit.dat")
        node_slab_report_path = joinpath(report_dir, "node-slab-sensitivity.csv")
        production_report_path = joinpath(report_dir, "production-diagnostics.dat")
        @test area_audit_path in report_paths
        @test isfile(area_audit_path)
        @test node_slab_report_path in report_paths
        @test isfile(node_slab_report_path)
        @test production_report_path in report_paths
        @test isfile(production_report_path)
        node_slab_report_header = split(readline(node_slab_report_path), ",")
        @test "time_offset_s" in node_slab_report_header
        @test all(in(node_slab_report_header), time_columns)
        production_report_header = split(readline(production_report_path))
        @test all(in(production_report_header), ["case", "dt_min", "cfl_max", "rhs_flow_max"])

        valid_sections = [row for row in result.section_rows if row.area_valid]
        @test !isempty(valid_sections)
        for row in valid_sections
            @test row.operator == "CrossSectionQuadratureOperator"
            @test row.intersection_count > 0
            @test row.cut_status == "valid"
            @test row.mean_u3d_cm_s ≈ 10.0 + row.z_cm
            @test isfinite(row.mean_u1d_cm_s)
            @test isfinite(row.abs_velocity_error_cm_s)
            @test isfinite(row.rel_error)
        end
        @test only(result.summary_rows).area_valid_count == length(valid_sections)
        @test isfinite(only(result.summary_rows).l2_velocity_error_cm_s)
        @test isfinite(only(result.summary_rows).relative_l1_velocity_error)
        @test isfinite(only(result.summary_rows).rel_l2_velocity_error)
        @test isfinite(only(result.summary_rows).flow_l2_error_cm3_s)
        @test isfinite(only(result.summary_rows).profile_l2_error_cm_s)
        @test isfinite(only(result.summary_rows).characteristic_radicand_min)
        @test only(result.summary_rows).accepted_dt_min > 0.0
        @test only(result.summary_rows).accepted_dt_max > 0.0
        @test only(result.summary_rows).realized_cfl_max > 0.0
        @test only(result.summary_rows).min_solver_area > 0.0
        @test only(result.summary_rows).min_physical_area_cm2 > 0.0
        @test only(result.summary_rows).positivity_projection_count == 0
        @test isfinite(only(result.summary_rows).final_area_flux_balance)
        @test isfinite(only(result.summary_rows).final_rhs_area_max_abs)
        @test isfinite(only(result.summary_rows).final_rhs_flow_max_abs)
        for rows in (result.section_rows, result.profile_rows, result.sensitivity_rows, result.summary_rows)
            @test !isempty(rows)
            for row in rows
                @test row.target_time_s ≈ case_spec.target_time
                @test row.time_atol_s ≈ case_spec.time_atol
                @test row.model == "canic-extended-1d"
                @test row.nx == spec.base_params.nx
                @test row.dt_s ≈ spec.base_params.dt
                @test row.initial_condition == "geometry-rest"
                @test row.backend == "native"
                @test row.run_status == "ok"
                @test row.one_d_completed_time_s ≈ case_spec.target_time
                @test row.one_d_terminal_time_error_s ≈ abs(row.one_d_completed_time_s - row.target_time_s)
                @test row.xdmf_target_time_error_s ≈ abs(row.xdmf_time_s - row.target_time_s)
                @test row.cross_model_time_offset_s ≈ abs(row.xdmf_time_s - row.one_d_completed_time_s)
                @test row.time_error_s ≈ row.xdmf_target_time_error_s
            end
        end

        area_audit_lines = readlines(area_audit_path)
        @test split(area_audit_lines[1]) == [
            "case",
            "sections",
            "eps_min_percent",
            "eps_median_percent",
            "eps_mean_percent",
            "eps_max_percent",
            "area3d_min_cm2",
            "area3d_max_cm2",
            "aref_min_cm2",
            "aref_max_cm2",
        ]
        area_audit_values = split(area_audit_lines[2])
        @test area_audit_values[1] == "C23"
        @test parse(Int, area_audit_values[2]) == length(valid_sections)
        @test parse(Float64, area_audit_values[3]) >= 0.0
        @test parse(Float64, area_audit_values[6]) >= parse(Float64, area_audit_values[3])

        populated_profiles = [row for row in result.profile_rows if row.area_valid]
        @test !isempty(populated_profiles)
        @test all(isfinite(row.mean_u1d_cm_s) for row in result.profile_rows)
        @test all(isfinite(row.mean_u3d_cm_s) for row in populated_profiles)
        @test all(isfinite(row.abs_velocity_error_cm_s) for row in populated_profiles)

        slab_rows = [row for row in result.sensitivity_rows if row.node_count > 0]
        @test !isempty(slab_rows)
        @test all(row.mean_u3d_cm_s ≈ 10.0 + row.z_cm for row in slab_rows)
    end
end

@testset "StenoticHemodynamics resolved 3D grid sensitivity" begin
    mktempdir() do dir
        xdmf_path, _, _ = write_synthetic_xdmf_hdf5_case(joinpath(dir, "case77"); time=5.0e-5)
        case_spec = StenoticHemodynamics.Resolved3DCaseSpec("77", 23.0, xdmf_path; target_time=5.0e-5)
        output_dir = joinpath(dir, "grid")
        spec = StenoticHemodynamics.GridSensitivitySpec(
            cases=[case_spec],
            base_params=Params(nx=6, tfinal=5.0e-5, severity=23.0, initial_condition=GeometryRestIC()),
            output_dir=output_dir,
            nxs=[6, 8],
            section_count=3,
            profile_slices=[0.0],
            radial_bins=3,
            overwrite=true,
            write_svg=false,
        )

        result = StenoticHemodynamics.run_grid_sensitivity(spec)
        @test result isa StenoticHemodynamics.GridSensitivityResult
        @test length(result.comparison_results) == 2
        @test length(result.summary_rows) == 2
        @test isfile(result.summary_csv)
        @test isfile(result.summary_tex)
        @test all(isfile(comparison.summary_csv) for comparison in result.comparison_results)
        @test all(isdir(joinpath(output_dir, "nx$(nx)")) for nx in spec.nxs)

        header = split(readline(result.summary_csv), ",")
        @test all(
            in(header),
            [
                "mean_physical_flow_bias_1d_minus_3d_cm3_s",
                "mean_physical_flow_discrepancy_cm3_s",
                "rms_physical_flow_discrepancy_cm3_s",
                "case",
                "mean_velocity_bias_1d_minus_3d_cm_s",
                "mean_velocity_discrepancy_cm_s",
                "rms_velocity_discrepancy_cm_s",
                "max_velocity_discrepancy_cm_s",
                "max_velocity_discrepancy_z_cm",
                "relative_rms_velocity_discrepancy",
                "adjacent_from_nx",
                "adjacent_rms_velocity_difference_cm_s",
            ],
        )

        rows = sort(read_simple_csv(result.summary_csv); by=row -> parse(Int, row["nx"]))
        @test [parse(Int, row["nx"]) for row in rows] == [6, 8]
        @test all(row["case"] == "C23" for row in rows)
        @test all(row["severity"] == "23" for row in rows)
        @test parse(Int, rows[1]["adjacent_from_nx"]) == 0
        @test parse(Int, rows[2]["adjacent_from_nx"]) == 6
        @test all(parse(Int, row["valid_section_count"]) > 0 for row in rows)
        @test all(isfinite(parse(Float64, row["mean_velocity_bias_1d_minus_3d_cm_s"])) for row in rows)
        @test all(isfinite(parse(Float64, row["rms_velocity_discrepancy_cm_s"])) for row in rows)
        @test all(isfinite(parse(Float64, row["relative_rms_velocity_discrepancy"])) for row in rows)
        @test isfinite(parse(Float64, rows[2]["adjacent_rms_velocity_difference_cm_s"]))
        @test 0.0 <= parse(Float64, rows[2]["max_velocity_discrepancy_z_cm"]) <= spec.base_params.length_cm

        tex = read(result.summary_tex, String)
        @test occursin("\\begin{tabular}", tex)
        @test occursin("C23", tex)
        @test occursin(" & 8 & ", tex)
        table_rows = [line for line in split(tex, '\n') if occursin(" & ", line)]
        @test !isempty(table_rows)
        @test all(line -> endswith(line, "\\\\"), table_rows)

        reuse_csv = joinpath(output_dir, "reuse-summary.csv")
        reuse_tex = joinpath(output_dir, "reuse-summary.tex")
        reuse = StenoticHemodynamics.run_grid_sensitivity_from_summary_csv(
            result.summary_csv;
            output_dir=joinpath(output_dir, "reuse"),
            nxs=spec.nxs,
            summary_csv=reuse_csv,
            summary_tex=reuse_tex,
            overwrite=true,
        )
        @test isempty(reuse.comparison_results)
        @test isfile(reuse.summary_csv)
        @test isfile(reuse.summary_tex)
        @test read(reuse.summary_csv, String) == read(result.summary_csv, String)
        @test read(reuse.summary_tex, String) == tex
        @test_throws ArgumentError StenoticHemodynamics.run_grid_sensitivity_from_summary_csv(
            result.summary_csv;
            output_dir=joinpath(output_dir, "bad-reuse"),
            nxs=[6, 10],
            overwrite=true,
        )

        @test_throws ArgumentError StenoticHemodynamics.GridSensitivitySpec(
            cases=[case_spec],
            nxs=[8, 6],
            profile_slices=[0.0],
        )
    end
end

@testset "StenoticHemodynamics resolved 3D absent-data skip" begin
    mktempdir() do dir
        missing_root = joinpath(dir, "not_present")
        @test isempty(StenoticHemodynamics.available_resolved3d_cases(missing_root))
        @test StenoticHemodynamics.run_available_resolved3d_comparison(data_root=missing_root, write_svg=false) === nothing
        @test StenoticHemodynamics.run_available_resolved3d_grid_sensitivity(data_root=missing_root, write_svg=false) === nothing
    end
end

@testset "stenosis geometry figure trajectory exports" begin
    mktempdir() do dir
        default_opts = StenoticHemodynamics.GeometryExportOptions()
        @test isabspath(default_opts.output_dir)
        @test isabspath(default_opts.data_root)
        @test StenoticHemodynamics.portable_project_path(
            joinpath(StenoticHemodynamics.PROJECT_ROOT, "report", "assets", "out.csv"),
        ) == joinpath("report", "assets", "out.csv")
        @test StenoticHemodynamics.portable_project_path(joinpath(dir, "outside.csv")) == joinpath(dir, "outside.csv")

        parsed_opts = StenoticHemodynamics.parse_export_args([
            "--output-dir", dir,
            "--data-root", joinpath(dir, "resolved"),
            "--z-samples", "31",
            "--theta-samples", "12",
            "--overwrite",
        ])
        @test parsed_opts.output_dir == dir
        @test parsed_opts.data_root == joinpath(dir, "resolved")
        @test parsed_opts.z_samples == 31
        @test parsed_opts.theta_samples == 12
        @test parsed_opts.overwrite == true

        opts = StenoticHemodynamics.GeometryExportOptions(output_dir=dir, z_samples=31, theta_samples=12, overwrite=true)
        StenoticHemodynamics.export_analytic_summary(opts)
        summary_rows = read_simple_csv(joinpath(dir, "analytic_summary.csv"))
        sev73 = only(row for row in summary_rows if parse(Float64, row["severity"]) == 73.0)
        @test parse(Float64, sev73["rmin_over_rbase"]) ≈ 0.27 atol=5.0e-4

        mesh_paths = StenoticHemodynamics.export_mesh_view_data(opts)
        @test length(mesh_paths) == 3
        @test all(isfile, mesh_paths)
        mesh_manifest = only(row for row in read_simple_csv(mesh_paths[1]) if row["status"] == "written")
        @test parse(Float64, mesh_manifest["severity"]) == 50.0
        @test parse(Int, mesh_manifest["fem_mesh_nz"]) == 64
        @test parse(Int, mesh_manifest["fem_mesh_nr"]) == 6
        @test parse(Int, mesh_manifest["fem_mesh_ntheta"]) == 32
        @test parse(Int, mesh_manifest["fem_nodes"]) == 65 * (1 + 6 * 32)
        @test parse(Int, mesh_manifest["fem_cells"]) == 64 * 32 * (1 + 2 * (6 - 1)) * 3
        @test mesh_manifest["fvm_method"] == "fv-muscl-minmod"
        @test parse(Int, mesh_manifest["fvm_nx"]) == 400

        fem_rows = read_simple_csv(mesh_paths[2])
        fvm_rows = read_simple_csv(mesh_paths[3])
        @test !isempty(fem_rows)
        @test length(fvm_rows) == 400
        @test Set(row["line_group"] for row in fem_rows) ==
              Set(["wall-circumferential", "wall-axial", "cut-axial", "cut-radial"])
        for row in fem_rows[1:min(length(fem_rows), 20)]
            @test all(
                isfinite,
                (
                    parse(Float64, row["z1_cm"]),
                    parse(Float64, row["x1_cm"]),
                    parse(Float64, row["y1_cm"]),
                    parse(Float64, row["z2_cm"]),
                    parse(Float64, row["x2_cm"]),
                    parse(Float64, row["y2_cm"]),
                ),
            )
        end
        @test parse(Int, fvm_rows[1]["cell_index"]) == 1
        @test parse(Float64, fvm_rows[1]["z_left_cm"]) ≈ 0.0
        @test parse(Int, fvm_rows[end]["cell_index"]) == 400
        @test parse(Float64, fvm_rows[end]["z_right_cm"]) ≈ 6.0
        @test all(parse(Float64, row["r_center_cm"]) > 0.0 for row in fvm_rows)

        resolved_root = joinpath(dir, "resolved")
        _, coords, velocity_values = write_synthetic_xdmf_hdf5_case(joinpath(resolved_root, "77"); time=1.0)
        resolved_opts = StenoticHemodynamics.GeometryExportOptions(
            output_dir=dir,
            data_root=resolved_root,
            z_samples=31,
            theta_samples=12,
            overwrite=true,
        )
        velocity_paths = StenoticHemodynamics.export_resolved_velocity_nodes(resolved_opts)
        @test length(velocity_paths) == 2
        @test isfile(velocity_paths[1])
        @test isfile(velocity_paths[2])
        velocity_rows = read_simple_csv(velocity_paths[2])
        @test length(velocity_rows) == size(coords, 1)
        @test parse(Float64, velocity_rows[1]["z_cm"]) ≈ coords[1, 3]
        @test parse(Float64, velocity_rows[1]["uz_cm_s"]) ≈ velocity_values[1, 3]
        manifest_rows = read_simple_csv(velocity_paths[1])
        written = only(row for row in manifest_rows if row["status"] == "written")
        @test written["case_label"] == "77"
        @test parse(Int, written["node_count"]) == size(coords, 1)

        paths = StenoticHemodynamics.export_stokes_particle_trajectories(
            opts;
            ic=StationaryStokesIC(
                pressure_drop_pa=40.0,
                mesh_nz=2,
                mesh_nr=2,
                mesh_ntheta=8,
            ),
            z_samples=13,
            parallel_workers=1,
        )
        trajectory_rows = read_simple_csv(paths[1])
        @test length(trajectory_rows) == 3 * 5 * 13

        grouped = Dict{Tuple{Int,Int},Vector{Dict{String,String}}}()
        for row in trajectory_rows
            severity = round(Int, parse(Float64, row["severity"]))
            particle_id = parse(Int, row["particle_id"])
            key = (severity, particle_id)
            push!(get!(grouped, key, Dict{String,String}[]), row)

            z = parse(Float64, row["z_cm"])
            x = parse(Float64, row["x_cm"])
            y = parse(Float64, row["y_cm"])
            r_over_r0 = parse(Float64, row["r_over_r0"])
            t = parse(Float64, row["t_s"])
            ux = parse(Float64, row["ux_cm_s"])
            uy = parse(Float64, row["uy_cm_s"])
            uz = parse(Float64, row["uz_cm_s"])
            @test all(isfinite, (z, x, y, r_over_r0, t, ux, uy, uz))
            @test r_over_r0 <= 1.0001

            params = Params(severity=severity, initial_condition=GeometryRestIC())
            r0, _, _ = StenoticHemodynamics.stenosis(z, params)
            @test hypot(x, y) <= 1.0001 * r0
        end

        @test sort(unique(first(key) for key in keys(grouped))) == [23, 50, 73]
        @test all(length(rows) == 13 for rows in values(grouped))
        for rows in values(grouped)
            sort!(rows; by=row -> parse(Int, row["sample_index"]))
            z_values = [parse(Float64, row["z_cm"]) for row in rows]
            @test all(z_values[i] < z_values[i + 1] for i in 1:(length(z_values) - 1))
        end
    end
end
