using Test
using Distributed
using LinearAlgebra
using StenoticHemodynamics

const parallel_case_map = StenoticHemodynamics.parallel_case_map

@testset "StenoticHemodynamics case worker configuration" begin
    @test StenoticHemodynamics.default_case_workers(Dict("JULIA_CASE_WORKERS" => "3")) == 3
    @test StenoticHemodynamics.default_case_workers(Dict("JULIA_CASE_WORKERS" => "")) == 1
    @test StenoticHemodynamics.effective_case_workers(3, 10) == 3
    @test StenoticHemodynamics.effective_case_workers(3, 0) == 0
    @test StenoticHemodynamics.effective_case_workers(0, 0; force_process=true) == 0
    @test StenoticHemodynamics.effective_case_workers(1, 0; force_process=true) == 1
    @test_throws ArgumentError StenoticHemodynamics.default_case_workers(Dict("JULIA_CASE_WORKERS" => "many"))
    @test_throws ArgumentError parallel_case_map(identity, [1]; threads_per_worker=0)
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

    forced_rows = parallel_case_map([:single]; parallel_workers=1, threads_per_worker=2, force_process=true) do value
        (
            value=value,
            pid=Distributed.myid(),
            threads=Threads.nthreads(),
            blas_threads=LinearAlgebra.BLAS.get_num_threads(),
        )
    end

    @test only(forced_rows).value === :single
    @test only(forced_rows).pid != 1
    @test only(forced_rows).threads == 2
    @test only(forced_rows).blas_threads == 1
end
