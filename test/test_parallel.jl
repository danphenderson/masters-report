const parallel_case_map = StenosisHemodynamics.parallel_case_map

@testset "StenosisHemodynamics case worker configuration" begin
    @test StenosisHemodynamics.default_case_workers(Dict("JULIA_CASE_WORKERS" => "3")) == 3
    @test StenosisHemodynamics.default_case_workers(Dict("JULIA_CASE_WORKERS" => "")) == 1
    @test StenosisHemodynamics.effective_case_workers(3, 10) == 3
    @test StenosisHemodynamics.effective_case_workers(3, 0) == 0
    @test_throws ArgumentError StenosisHemodynamics.default_case_workers(Dict("JULIA_CASE_WORKERS" => "many"))
    @test parallel_case_map(x -> x + 1, [1, 2, 3]; parallel_workers=1) == [2, 3, 4]

    worker_rows = parallel_case_map([1, 2]; parallel_workers=2) do value
        (
            value=value,
            pid=Distributed.myid(),
            threads=Threads.nthreads(),
            blas_threads=LinearAlgebra.BLAS.get_num_threads(),
        )
    end

    @test [row.value for row in worker_rows] == [1, 2]
    @test all(row.pid != 1 for row in worker_rows)
    @test all(row.threads == 1 for row in worker_rows)
    @test all(row.blas_threads == 1 for row in worker_rows)
end
