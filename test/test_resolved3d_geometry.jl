@testset "CanicExtended1D resolved 3D parsing and loading" begin
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

        case_spec = Resolved3DCaseSpec("synthetic", 23.0, xdmf_path; target_time=5.0e-5)
        field = load_resolved3d_velocity(case_spec)
        @test size(field.coordinates) == size(coords)
        @test size(field.velocity) == size(velocity_values)
        @test field.metadata.time ≈ 5.0e-5

        mismatched_time = Resolved3DCaseSpec("synthetic", 23.0, xdmf_path; target_time=1.0, time_atol=1.0e-8)
        @test_throws ArgumentError load_resolved3d_velocity(mismatched_time)

        missing_xdmf_path, _, _ = write_synthetic_xdmf_hdf5_case(
            joinpath(dir, "missing_velocity");
            omit_velocity_dataset=true,
        )
        missing_velocity = Resolved3DCaseSpec("missing", 23.0, missing_xdmf_path; target_time=5.0e-5)
        @test_throws ArgumentError load_resolved3d_velocity(missing_velocity)
    end
end

@testset "CanicExtended1D resolved 3D comparison diagnostics" begin
    mktempdir() do dir
        xdmf_path, _, _ = write_synthetic_xdmf_hdf5_case(joinpath(dir, "case77"))
        case_spec = Resolved3DCaseSpec("77", 23.0, xdmf_path; target_time=5.0e-5)
        output_dir = joinpath(dir, "out")
        spec = ComparisonSpec(
            cases=[case_spec],
            base_params=Params(nx=8, tfinal=5.0e-5, severity=23.0, initial_condition=GeometryRestIC()),
            output_dir=output_dir,
            section_count=3,
            profile_slices=[3.0],
            radial_bins=5,
            overwrite=true,
            write_svg=false,
        )

        result = run_comparison(spec)
        @test length(result.section_rows) == 3
        @test length(result.profile_rows) == 5
        @test length(result.summary_rows) == 1
        @test isfile(result.section_csvs[1])
        @test isfile(result.profile_csvs[1])
        @test isfile(result.summary_csv)

        for row in result.section_rows
            @test row.node_count > 0
            @test row.u3d_cm_s ≈ 10.0 + row.z_cm
            @test isfinite(row.u1d_cm_s)
            @test isfinite(row.abs_error_cm_s)
            @test isfinite(row.rel_error)
        end

        populated_profiles = [row for row in result.profile_rows if row.node_count > 0]
        @test !isempty(populated_profiles)
        @test all(isfinite(row.u1d_cm_s) for row in result.profile_rows)
        @test all(isfinite(row.u3d_cm_s) for row in populated_profiles)
        @test all(isfinite(row.abs_error_cm_s) for row in populated_profiles)
    end
end

@testset "CanicExtended1D resolved 3D absent-data skip" begin
    mktempdir() do dir
        missing_root = joinpath(dir, "not_present")
        @test isempty(available_resolved3d_cases(missing_root))
        @test run_available_resolved3d_comparison(data_root=missing_root, write_svg=false) === nothing
    end
end

@testset "stenosis geometry figure trajectory exports" begin
    mktempdir() do dir
        default_opts = GeometryExportOptions()
        @test isabspath(default_opts.output_dir)
        @test isabspath(default_opts.data_root)

        parsed_opts = CanicExtended1D.parse_export_args([
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

        opts = GeometryExportOptions(output_dir=dir, z_samples=31, theta_samples=12, overwrite=true)
        CanicExtended1D.export_analytic_summary(opts)
        summary_rows = read_simple_csv(joinpath(dir, "analytic_summary.csv"))
        sev73 = only(row for row in summary_rows if parse(Float64, row["severity"]) == 73.0)
        @test parse(Float64, sev73["rmin_over_rbase"]) ≈ 0.27 atol=5.0e-4

        paths = CanicExtended1D.export_stokes_particle_trajectories(
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
            r0, _, _ = CanicExtended1D.stenosis(z, params)
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
