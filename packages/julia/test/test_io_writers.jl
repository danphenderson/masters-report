@testset "StenosisHemodynamics internal I/O writer helpers" begin
    mktempdir() do dir
        csv_path = joinpath(dir, "nested", "table.csv")
        rows = [
            ("plain", 1.25, true),
            ("needs,quotes", nothing, false),
            ("quote \"mark\"", NaN, "line\nbreak"),
        ]

        StenosisHemodynamics.write_csv_table(
            csv_path,
            ("label", "value", "flag"),
            rows;
            overwrite=false,
            real_formatter=x -> isfinite(x) ? string(round(x; digits=2)) : string(x),
        )

        @test read(csv_path, String) ==
              "label,value,flag\n" *
              "plain,1.25,true\n" *
              "\"needs,quotes\",,false\n" *
              "\"quote \"\"mark\"\"\",NaN,\"line\nbreak\"\n"
        @test_throws ArgumentError StenosisHemodynamics.write_csv_table(
            csv_path,
            ("label",),
            [("replacement",)];
            overwrite=false,
        )

        padded_path = joinpath(dir, "padded.csv")
        StenosisHemodynamics.write_csv_table(
            padded_path,
            ("a", "b"),
            [(1,), (2, 3, 4)];
            pad_rows=true,
        )
        @test readlines(padded_path) == ["a,b", "1,", "2,3"]

        json_path = joinpath(dir, "manifest.json")
        StenosisHemodynamics.write_json(
            json_path,
            Dict(
                "z" => nothing,
                "a" => [1, true, "text"],
                "bad_number" => Inf,
            );
            overwrite=false,
        )
        json_text = read(json_path, String)
        @test occursin("\"a\": [1, true, \"text\"]", json_text)
        @test occursin("\"bad_number\": null", json_text)
        @test occursin("\"z\": null", json_text)
        @test_throws ArgumentError StenosisHemodynamics.write_json(json_path, Dict("a" => 2); overwrite=false)

        digest = StenosisHemodynamics.sha256_file(csv_path)
        @test length(digest) == 64
        @test all(in("0123456789abcdef"), digest)
    end
end
