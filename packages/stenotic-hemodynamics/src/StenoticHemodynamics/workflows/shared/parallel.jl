using Distributed
using LinearAlgebra

const DEFAULT_CASE_WORKER_ENV = "JULIA_CASE_WORKERS"

"""
    default_case_workers([env])

Return the requested process-level case worker count. The value is controlled by
`JULIA_CASE_WORKERS` and may be zero to force local serial execution.
"""
function default_case_workers(env::AbstractDict = ENV)
    raw = strip(get(env, DEFAULT_CASE_WORKER_ENV, "1"))
    isempty(raw) && return 1
    workers = try
        parse(Int, raw)
    catch
        throw(ArgumentError("$DEFAULT_CASE_WORKER_ENV must be an integer, got '$raw'"))
    end
    workers >= 0 || throw(ArgumentError("$DEFAULT_CASE_WORKER_ENV must be nonnegative"))
    return workers
end

"""
    effective_case_workers(case_count, requested_workers; force_process=false)

Clamp the requested worker count to the number of cases. When `force_process` is
true, a nonempty case set runs through at least one worker even if
`requested_workers` is zero.
"""
function effective_case_workers(
    case_count::Integer,
    requested_workers::Integer = default_case_workers();
    force_process::Bool = false,
)
    case_count >= 0 || throw(ArgumentError("case_count must be nonnegative"))
    requested_workers >= 0 || throw(ArgumentError("requested_workers must be nonnegative"))
    worker_count = min(case_count, requested_workers)
    if force_process && case_count > 0
        return min(case_count, max(worker_count, 1))
    end
    return worker_count
end

"""
    validate_threads_per_worker(threads_per_worker)

Validate and normalize the per-worker Julia thread count used when spawning case
workers.
"""
function validate_threads_per_worker(threads_per_worker::Integer)
    threads_per_worker >= 1 || throw(ArgumentError("threads_per_worker must be positive"))
    return Int(threads_per_worker)
end

"""
    parallel_case_map(f, cases; parallel_workers, threads_per_worker=1, force_process=false)

Map `f` over cases locally or through a `Distributed` worker pool. Worker
processes are selected by their Julia thread count, and BLAS/OpenMP thread pools
are capped inside workers so case-level parallelism remains explicit.
"""
function parallel_case_map(
    f,
    cases;
    parallel_workers::Integer = default_case_workers(),
    threads_per_worker::Integer = 1,
    force_process::Bool = false,
)
    case_vector = collect(cases)
    worker_count = effective_case_workers(length(case_vector), parallel_workers; force_process=force_process)
    worker_threads = validate_threads_per_worker(threads_per_worker)
    (worker_count == 0 || (!force_process && worker_count <= 1)) && return map(f, case_vector)

    worker_ids = case_worker_ids!(worker_count; threads_per_worker=worker_threads)
    return pmap(f, CachingPool(worker_ids), case_vector)
end

function case_worker_ids!(worker_count::Integer; threads_per_worker::Integer = 1)
    worker_count >= 1 || throw(ArgumentError("worker_count must be positive"))
    worker_threads = validate_threads_per_worker(threads_per_worker)

    current_workers = case_worker_ids_with_threads(worker_threads)
    if length(current_workers) < worker_count
        add_case_workers!(worker_count - length(current_workers); threads_per_worker=worker_threads)
        current_workers = case_worker_ids_with_threads(worker_threads)
    end

    selected = current_workers[1:worker_count]
    initialize_case_workers!(selected)
    return selected
end

function case_worker_ids()
    return [worker_id for worker_id in workers() if worker_id != myid()]
end

function case_worker_thread_count(worker_id::Integer)
    return fetch(remotecall_eval(Main, worker_id, :(Threads.nthreads())))
end

function case_worker_ids_with_threads(threads_per_worker::Integer)
    worker_threads = validate_threads_per_worker(threads_per_worker)
    return [worker_id for worker_id in case_worker_ids() if case_worker_thread_count(worker_id) == worker_threads]
end

function add_case_workers!(worker_count::Integer; threads_per_worker::Integer = 1)
    worker_count >= 1 || return Int[]
    worker_threads = validate_threads_per_worker(threads_per_worker)

    project = Base.active_project()
    project_flag = project === nothing ? "--project=@." : "--project=$(dirname(project))"
    return addprocs(
        worker_count;
        exeflags=[project_flag, "--threads=$(worker_threads)", "--gcthreads=1"],
        enable_threaded_blas=false,
        env=Dict(
            "JULIA_NUM_THREADS" => string(worker_threads),
            "JULIA_NUM_GC_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "OMP_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        ),
    )
end

function initialize_case_workers!(worker_ids = case_worker_ids())
    isempty(worker_ids) && return worker_ids

    for worker_id in worker_ids
        fetch(remotecall_eval(Main, worker_id, quote
            using LinearAlgebra
            LinearAlgebra.BLAS.set_num_threads(1)
            using StenoticHemodynamics
        end
        ))
    end

    return worker_ids
end
