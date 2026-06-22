@testset "package benchmark smoke profile" begin
    mktempdir() do dir
        spec = StenoticHemodynamics.PackageBenchmarkSpec(;
            profile="smoke",
            output_dir=dir,
            overwrite=true,
            include_resolved3d=false,
            publish_report_assets=false,
        )
        result = @test_logs (:info, "package benchmark started") (:info, "package benchmark stage completed") (:info, "package benchmark completed") match_mode=:any begin
            StenoticHemodynamics.run_package_benchmark(spec)
        end
        @test result.output_dir == dir
        @test isfile(result.manifest_path)
        expected = Set([
            "case_results.csv",
            "refinement.csv",
            "backend_parity.csv",
            "stokes_ic.csv",
            "rheology_profile.csv",
            "boundary_openbf.csv",
            "resolved3d.csv",
        ])
        @test Set(basename.(result.csv_paths)) == expected
        for path in result.csv_paths
            @test isfile(path)
            lines = readlines(path)
            @test length(lines) >= 2
            @test occursin("status", lines[1])
        end
        manifest = read(result.manifest_path, String)
        @test occursin("\"synthetic_waveform.csv\"", manifest)
        @test_throws ArgumentError StenoticHemodynamics.run_package_benchmark(
            StenoticHemodynamics.PackageBenchmarkSpec(; output_dir=dir),
        )
    end
end

@testset "package benchmark path helpers" begin
    mktempdir() do dir
        output_dir = joinpath(dir, "benchmark")
        spec = StenoticHemodynamics.PackageBenchmarkSpec(output_dir=output_dir)
        paths = StenoticHemodynamics.default_output_paths(spec)

        @test paths.case_results == joinpath(output_dir, "case_results.csv")
        @test paths.refinement == joinpath(output_dir, "refinement.csv")
        @test paths.backend_parity == joinpath(output_dir, "backend_parity.csv")
        @test paths.stokes_ic == joinpath(output_dir, "stokes_ic.csv")
        @test paths.rheology_profile == joinpath(output_dir, "rheology_profile.csv")
        @test paths.boundary_openbf == joinpath(output_dir, "boundary_openbf.csv")
        @test paths.resolved3d == joinpath(output_dir, "resolved3d.csv")
        @test paths.manifest == joinpath(output_dir, "manifest.json")

        mkpath(output_dir)
        write(paths.case_results, "case results\n")
        write(paths.refinement, "refinement\n")
        write(paths.manifest, "manifest\n")
        manifest_inputs = StenoticHemodynamics.manifest_output_paths(
            output_dir,
            [paths.refinement, paths.case_results, paths.case_results, paths.manifest],
            paths.manifest,
        )
        @test manifest_inputs == [paths.case_results, paths.refinement]
        @test paths.manifest ∉ manifest_inputs
    end
end

@testset "package benchmark output guard" begin
    mktempdir() do dir
        keep_path = joinpath(dir, "keep.txt")
        manifest_path = joinpath(dir, "manifest.json")
        stokes_dir = joinpath(dir, "stokes_ic")
        write(keep_path, "not owned by the benchmark workflow")
        write(manifest_path, "old manifest")
        mkpath(stokes_dir)
        write(joinpath(stokes_dir, "old.csv"), "old")

        StenoticHemodynamics.prepare_package_benchmark_output_dir(dir; overwrite=true)

        @test isdir(dir)
        @test isfile(keep_path)
        @test !isfile(manifest_path)
        @test !isdir(stokes_dir)
    end

    mktempdir() do dir
        owned_file = joinpath(dir, "synthetic_waveform.csv")
        owned_dir = joinpath(dir, "resolved3d")
        owned_nested = joinpath(dir, "refinement_raw")
        keep_dir = joinpath(dir, "notes")
        keep_nested_file = joinpath(keep_dir, "keep.txt")
        write(owned_file, "owned")
        mkpath(owned_dir)
        write(joinpath(owned_dir, "row.csv"), "owned")
        mkpath(owned_nested)
        write(joinpath(owned_nested, "detail.csv"), "owned")
        mkpath(keep_dir)
        write(keep_nested_file, "preserve")

        StenoticHemodynamics.prepare_package_benchmark_output_dir(dir; overwrite=true)

        @test !isfile(owned_file)
        @test !isdir(owned_dir)
        @test !isdir(owned_nested)
        @test isdir(keep_dir)
        @test isfile(keep_nested_file)
    end

    @test_throws ArgumentError StenoticHemodynamics.prepare_package_benchmark_output_dir(pwd(); overwrite=true)
    @test_throws ArgumentError StenoticHemodynamics.prepare_package_benchmark_output_dir(
        joinpath(pwd(), "packages", "stenotic-hemodynamics", "src");
        overwrite=true,
    )

    mktempdir() do dir
        file_path = joinpath(dir, "not_a_directory")
        write(file_path, "content")
        @test_throws ArgumentError StenoticHemodynamics.prepare_package_benchmark_output_dir(file_path; overwrite=true)
    end
end

@testset "package benchmark resolved3d skip rows" begin
    mktempdir() do dir
        disabled_spec = StenoticHemodynamics.PackageBenchmarkSpec(
            output_dir=joinpath(dir, "disabled"),
            include_resolved3d=false,
        )
        disabled_rows = StenoticHemodynamics.resolved3d_rows("overnight", disabled_spec)
        @test length(disabled_rows) == 1
        @test disabled_rows[1][1] == "resolved3d"
        @test disabled_rows[1][end - 2] == "skipped"
        @test disabled_rows[1][end - 1] == 0.0
        @test disabled_rows[1][end] == "include_resolved3d=false"

        smoke_spec = StenoticHemodynamics.PackageBenchmarkSpec(
            output_dir=joinpath(dir, "smoke"),
            include_resolved3d=true,
        )
        smoke_rows = StenoticHemodynamics.resolved3d_rows("smoke", smoke_spec)
        @test length(smoke_rows) == 1
        @test smoke_rows[1][1] == "resolved3d"
        @test smoke_rows[1][4] == ""
        @test smoke_rows[1][end - 2] == "skipped"
        @test smoke_rows[1][end] == "smoke profile does not run resolved-3D diagnostics"
    end
end
