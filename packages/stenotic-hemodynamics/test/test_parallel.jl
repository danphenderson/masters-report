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
    @test StenoticHemodynamics.NativeRK3Backend().solver_threads == 1
    @test StenoticHemodynamics.NativeRK3Backend(solver_threads=2).solver_threads == 2
    @test_throws ArgumentError StenoticHemodynamics.NativeRK3Backend(solver_threads=0)
    @test !StenoticHemodynamics.native_solver_threading_enabled(StenoticHemodynamics.NativeRK3Backend())
    @test StenoticHemodynamics.native_solver_threading_enabled(
        StenoticHemodynamics.NativeRK3Backend(solver_threads=Threads.nthreads()),
    ) == (Threads.nthreads() > 1)
    @test collect(StenoticHemodynamics.thread_slot_range(1:10, 1, 3)) == [1, 2, 3]
    @test collect(StenoticHemodynamics.thread_slot_range(1:10, 2, 3)) == [4, 5, 6]
    @test collect(StenoticHemodynamics.thread_slot_range(1:10, 3, 3)) == [7, 8, 9, 10]
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

@testset "StenoticHemodynamics native solver threading" begin
    params = Params(nx=10, tfinal=2.0e-5, dt=1.0e-5, initial_condition=GeometryRestIC())
    serial = simulate(params, StenoticHemodynamics.NativeRK3Backend(); progress_every=0)
    mismatched_threads = Threads.nthreads() == 2 ? 3 : 2
    @test_throws ArgumentError simulate(
        params,
        StenoticHemodynamics.NativeRK3Backend(solver_threads=mismatched_threads);
        progress_every=0,
    )

    threaded_rows = parallel_case_map([params]; parallel_workers=1, threads_per_worker=2, force_process=true) do worker_params
        result = simulate(worker_params, StenoticHemodynamics.NativeRK3Backend(solver_threads=2); progress_every=0)
        (
            threads=Threads.nthreads(),
            area=result.area,
            flow=result.flow,
            solver_threads=StenoticHemodynamics.NativeRK3Backend(solver_threads=2).solver_threads,
        )
    end
    threaded = only(threaded_rows)

    @test threaded.threads == 2
    @test threaded.solver_threads == 2
    @test threaded.area == serial.area
    @test threaded.flow == serial.flow

    values = Dict("nxs" => "10,12", "case-workers" => "0", "solver-threads" => "2", "section-count" => "3")
    plan = StenoticHemodynamics.compare3d_command_plan_from_values(values, Set(["no-svg"]))
    @test plan.mode == :grid_sensitivity
    @test plan.run_kwargs.case_workers == 0
    @test plan.run_kwargs.solver_threads == 2
end
