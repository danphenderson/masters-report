@testset "package benchmark smoke profile" begin
    mktempdir() do dir
        spec = PackageBenchmarkSpec(;
            profile="smoke",
            output_dir=dir,
            overwrite=true,
            include_python=false,
            include_resolved3d=false,
            publish_report_assets=false,
        )
        result = @test_logs (:info, "package benchmark started") (:info, "package benchmark stage completed") (:info, "package benchmark completed") match_mode=:any begin
            run_package_benchmark(spec)
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
            "python_mps.csv",
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
        @test_throws ArgumentError run_package_benchmark(PackageBenchmarkSpec(; output_dir=dir))
    end
end
