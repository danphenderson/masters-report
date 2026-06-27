isdefined(@__MODULE__, :read_simple_csv) || include("test_helpers.jl")

function membrane_fsi_float_column(rows, column::String)
    return [parse(Float64, row[column]) for row in rows]
end

@testset "StenoticHemodynamics membrane FSI mathematics" begin
    params = Params(nx=8, tfinal=0.0, severity=23.0, initial_condition=GeometryRestIC())

    @testset "Canic membrane stiffness and clamped displacement" begin
        c0 = StenoticHemodynamics.canic_membrane_c0(params; reference_radius=params.rmax)
        @test c0 ≈ StenoticHemodynamics.wall_stiffness(params) / params.rmax^2
        wall_force = [100.0, 200.0, 300.0, 400.0]
        displacement = StenoticHemodynamics.clamped_membrane_displacement(
            wall_force,
            params;
            reference_radius=params.rmax,
        )
        @test displacement[begin] == 0.0
        @test displacement[end] == 0.0
        @test displacement[2] ≈ wall_force[2] / c0
        @test displacement[3] ≈ wall_force[3] / c0
        @test_throws ArgumentError StenoticHemodynamics.canic_membrane_c0(params; reference_radius=0.0)
    end

    @testset "radius callback validation is generic and fail-closed" begin
        ic = StationaryStokesIC(pressure_drop_pa=40.0, mesh_nz=2, mesh_nr=1, mesh_ntheta=4)
        mesh = StenoticHemodynamics.generated_stokes_mesh(params, ic; radius_at_z=z -> big"0.18")
        @test length(mesh.coordinates) > 0
        @test_throws ArgumentError StenoticHemodynamics.generated_stokes_mesh(params, ic; radius_at_z=z -> 0.0)
        @test_throws ArgumentError StenoticHemodynamics.generated_stokes_mesh(params, ic; radius_at_z=z -> "0.18")
    end
end

@testset "StenoticHemodynamics quasi-static membrane FSI smoke and edge cases" begin
    mktempdir() do dir
        params = Params(nx=8, tfinal=0.0, severity=0.0, initial_condition=GeometryRestIC())
        ic = StationaryStokesIC(pressure_drop_pa=40.0, mesh_nz=4, mesh_nr=1, mesh_ntheta=4)
        solution = StenoticHemodynamics.solve_quasistatic_membrane_fsi(
            params,
            ic;
            max_iterations=2,
            tolerance_cm=1.0,
            damping=1.0,
        )
        @test solution.converged
        @test solution.iterations == 1
        @test solution.displacement[begin] == 0.0
        @test solution.displacement[end] == 0.0
        @test maximum(solution.displacement) > 0.0
        @test minimum(solution.current_radius) > 0.0
        @test all(isfinite, solution.wall_pressure)
        @test solution.wall_pressure[end] ≈ 0.0 atol = 1.0e-8
        @test all(row -> isfinite(row.residual_cm), solution.history)
        recomputed_solution, recomputed_pressure, recomputed_force = StenoticHemodynamics.membrane_stokes_state(
            params,
            ic,
            solution.z,
            solution.current_radius,
        )
        @test solution.wall_pressure ≈ recomputed_pressure
        @test solution.wall_force ≈ recomputed_force
        @test solution.stokes_solution.velocity_dofs == recomputed_solution.velocity_dofs
        @test last(solution.history).wall_pressure_max_dyn_cm2 ≈ maximum(solution.wall_pressure)
        @test last(solution.history).current_radius_max_cm ≈ maximum(solution.current_radius)

        custom_radius = z -> 0.16 + 0.01 * sin(pi * Float64(z) / params.length_cm)^2
        custom_solution = StenoticHemodynamics.solve_quasistatic_membrane_fsi(
            params,
            ic;
            max_iterations=2,
            tolerance_cm=1.0,
            damping=1.0,
            reference_radius=0.17,
            reference_radius_at_z=custom_radius,
        )
        @test custom_solution.reference_radius[begin] ≈ custom_radius(0.0)
        @test custom_solution.reference_radius[3] ≈ custom_radius(custom_solution.z[3])
        @test minimum(custom_solution.current_radius) > 0.0

        profile_csv = joinpath(dir, "profile.csv")
        StenoticHemodynamics.write_membrane_fsi_profile_csv(profile_csv, solution; overwrite=true)
        @test isfile(profile_csv)
        @test "displacement_cm" in split(readline(profile_csv), ",")
    end
end

@testset "StenoticHemodynamics membrane FSI workflow and dynamic gate" begin
    mktempdir() do dir
        params = Params(nx=8, tfinal=0.0, severity=0.0, initial_condition=GeometryRestIC())
        custom_radius = z -> 0.16 + 0.01 * sin(pi * Float64(z) / params.length_cm)^2
        nonconverged = StenoticHemodynamics.run_membrane_fsi_validation(
            StenoticHemodynamics.MembraneFSIValidationSpec(
                base_params=params,
                severities=[0.0],
                geometry_id="smooth-bulge",
                reference_radius_at_z=custom_radius,
                meshes=[(4, 1, 4)],
                output_dir=joinpath(dir, "quasi"),
                overwrite=true,
                max_coupling_iters=1,
                coupling_tolerance_cm=1.0e-30,
                damping=1.0,
                parallel_workers=0,
            ),
        )
        @test length(nonconverged.rows) == 1
        @test only(nonconverged.rows).status == "not-converged"
        @test only(nonconverged.rows).geometry_id == "smooth-bulge"
        @test isfile(nonconverged.summary_csv)
        @test isfile(nonconverged.summary_tex)
        @test isfile(nonconverged.manifest_json)
        @test isfile(only(nonconverged.rows).profile_csv)
        @test isfile(only(nonconverged.rows).history_csv)
        @test occursin("geometry_id", read(nonconverged.summary_csv, String))
        @test occursin("smooth-bulge", read(nonconverged.manifest_json, String))
        @test occursin("smooth_bulge", basename(only(nonconverged.rows).profile_csv))

        bad_geometry = StenoticHemodynamics.MembraneFSIValidationSpec(
            base_params=params,
            severities=[0.0],
            reference_radius_at_z=z -> 0.0,
            meshes=[(4, 1, 4)],
            output_dir=joinpath(dir, "bad-geometry"),
            overwrite=true,
            parallel_workers=0,
        )
        @test_throws ArgumentError StenoticHemodynamics.run_membrane_fsi_validation(bad_geometry)

        dynamic_solution = StenoticHemodynamics.solve_membrane_fsi(
            StenoticHemodynamics.DynamicMembraneMode(wall_density=1.0, dt=1.0e-5, tfinal=3.0e-5),
            params,
            StationaryStokesIC(pressure_drop_pa=40.0, mesh_nz=4, mesh_nr=1, mesh_ntheta=4);
            history_stride=1,
        )
        @test dynamic_solution.time_step_count == 3
        @test length(dynamic_solution.history) == 3
        @test maximum(abs.(dynamic_solution.wall_velocity)) > 0.0
        @test last(dynamic_solution.history).wall_pressure_max_dyn_cm2 ≈ maximum(dynamic_solution.wall_pressure)
        @test last(dynamic_solution.history).current_radius_max_cm ≈ maximum(dynamic_solution.current_radius)
        @test last(dynamic_solution.history).wall_velocity_max_cm_s ≈ maximum(dynamic_solution.wall_velocity)
        @test last(dynamic_solution.history).wall_velocity_max_cm_s > 0.0

        dynamic_solution_profile_csv = joinpath(dir, "dynamic-solution-profile.csv")
        dynamic_solution_history_csv = joinpath(dir, "dynamic-solution-history.csv")
        StenoticHemodynamics.write_membrane_fsi_profile_csv(
            dynamic_solution_profile_csv,
            dynamic_solution;
            overwrite=true,
        )
        StenoticHemodynamics.write_membrane_fsi_history_csv(
            dynamic_solution_history_csv,
            dynamic_solution;
            overwrite=true,
        )
        dynamic_solution_profile_rows = read_simple_csv(dynamic_solution_profile_csv)
        dynamic_solution_history_rows = read_simple_csv(dynamic_solution_history_csv)
        @test length(dynamic_solution_profile_rows) == length(dynamic_solution.z)
        @test length(dynamic_solution_history_rows) == length(dynamic_solution.history)
        @test maximum(membrane_fsi_float_column(dynamic_solution_profile_rows, "wall_velocity_cm_s")) ≈
              maximum(dynamic_solution.wall_velocity)
        @test maximum(membrane_fsi_float_column(dynamic_solution_profile_rows, "wall_velocity_cm_s")) > 0.0
        @test parse(Float64, last(dynamic_solution_history_rows)["wall_velocity_max_cm_s"]) ≈
              maximum(dynamic_solution.wall_velocity)
        @test parse(Float64, last(dynamic_solution_history_rows)["current_radius_max_cm"]) ≈
              maximum(dynamic_solution.current_radius)

        dynamic = StenoticHemodynamics.run_membrane_fsi_validation(
            StenoticHemodynamics.MembraneFSIValidationSpec(
                base_params=params,
                severities=[23.0],
                meshes=[(4, 1, 4)],
                mode=StenoticHemodynamics.DynamicMembraneMode(wall_density=1.0, dt=1.0e-5, tfinal=3.0e-5),
                output_dir=joinpath(dir, "dynamic"),
                overwrite=true,
                parallel_workers=0,
            ),
        )
        @test length(dynamic.rows) == 1
        dynamic_row = only(dynamic.rows)
        @test dynamic_row.wall_mode == "dynamic-membrane"
        @test dynamic_row.status == "ok"
        @test dynamic_row.error_message == ""
        @test dynamic_row.time_step_count == 3
        @test dynamic_row.time_s ≈ 3.0e-5
        @test isfinite(dynamic_row.wall_velocity_max_cm_s)
        @test dynamic_row.wall_velocity_max_cm_s > 0.0
        @test dynamic_row.current_radius_min_cm > 0.0
        @test isfile(dynamic_row.profile_csv)
        @test isfile(dynamic_row.history_csv)
        @test occursin("wall_velocity_cm_s", readline(dynamic_row.profile_csv))
        @test occursin("wall_velocity_max_cm_s", readline(dynamic_row.history_csv))
        dynamic_profile_rows = read_simple_csv(dynamic_row.profile_csv)
        dynamic_history_rows = read_simple_csv(dynamic_row.history_csv)
        @test length(dynamic_profile_rows) == dynamic_row.mesh_nz + 1
        @test length(dynamic_history_rows) == dynamic_row.time_step_count
        @test maximum(membrane_fsi_float_column(dynamic_profile_rows, "wall_velocity_cm_s")) ≈
              dynamic_row.wall_velocity_max_cm_s
        @test maximum(membrane_fsi_float_column(dynamic_profile_rows, "wall_velocity_cm_s")) > 0.0
        @test minimum(membrane_fsi_float_column(dynamic_profile_rows, "wall_velocity_cm_s")) ≈
              dynamic_row.wall_velocity_min_cm_s
        @test minimum(membrane_fsi_float_column(dynamic_profile_rows, "current_radius_cm")) ≈
              dynamic_row.current_radius_min_cm
        @test maximum(membrane_fsi_float_column(dynamic_profile_rows, "current_radius_cm")) ≈
              dynamic_row.current_radius_max_cm
        @test parse(Int, last(dynamic_history_rows)["step"]) == dynamic_row.time_step_count
        @test parse(Float64, last(dynamic_history_rows)["time_s"]) ≈ dynamic_row.time_s
        @test parse(Float64, last(dynamic_history_rows)["wall_velocity_max_cm_s"]) ≈
              dynamic_row.wall_velocity_max_cm_s
        @test parse(Float64, last(dynamic_history_rows)["current_radius_min_cm"]) ≈
              dynamic_row.current_radius_min_cm
        @test parse(Float64, last(dynamic_history_rows)["current_radius_max_cm"]) ≈
              dynamic_row.current_radius_max_cm
        @test !occursin("planned-dynamic-mode", read(dynamic.summary_csv, String))

        report_assets_dir = joinpath(dir, "report-assets")
        report_paths = StenoticHemodynamics.publish_membrane_fsi_report_assets(
            dynamic;
            report_assets_dir=report_assets_dir,
            overwrite=true,
        )
        @test joinpath(report_assets_dir, "data", "membrane-fsi", "summary.csv") in report_paths
        @test joinpath(report_assets_dir, "tables", "membrane-fsi", "summary.tex") in report_paths
        @test joinpath(report_assets_dir, "data", "membrane-fsi", "wall-profile-severity23.dat") in report_paths
        @test joinpath(report_assets_dir, "data", "membrane-fsi", "fixed-point-history-severity23.dat") in report_paths
        report_tex = read(joinpath(report_assets_dir, "tables", "membrane-fsi", "summary.tex"), String)
        @test occursin("C23 (22.56\\%)", report_tex)
        @test !occursin("23\\% stenosis", report_tex)
        @test !occursin(dynamic_row.case_id, report_tex)
    end
end
