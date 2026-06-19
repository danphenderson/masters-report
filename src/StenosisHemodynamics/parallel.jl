using Distributed
using LinearAlgebra

const DEFAULT_CASE_WORKER_ENV = "JULIA_CASE_WORKERS"

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

function effective_case_workers(case_count::Integer, requested_workers::Integer = default_case_workers())
    case_count >= 0 || throw(ArgumentError("case_count must be nonnegative"))
    requested_workers >= 0 || throw(ArgumentError("requested_workers must be nonnegative"))
    return min(case_count, requested_workers)
end

function parallel_case_map(f, cases; parallel_workers::Integer = default_case_workers())
    case_vector = collect(cases)
    worker_count = effective_case_workers(length(case_vector), parallel_workers)
    worker_count <= 1 && return map(f, case_vector)

    worker_ids = case_worker_ids!(worker_count)
    return pmap(f, CachingPool(worker_ids), case_vector)
end

function case_worker_ids!(worker_count::Integer)
    worker_count >= 1 || throw(ArgumentError("worker_count must be positive"))

    current_workers = case_worker_ids()
    if length(current_workers) < worker_count
        add_case_workers!(worker_count - length(current_workers))
        current_workers = case_worker_ids()
    end

    selected = current_workers[1:worker_count]
    initialize_case_workers!(selected)
    return selected
end

function case_worker_ids()
    return [worker_id for worker_id in workers() if worker_id != myid()]
end

function add_case_workers!(worker_count::Integer)
    worker_count >= 1 || return Int[]

    project = Base.active_project()
    project_flag = project === nothing ? "--project=@." : "--project=$(dirname(project))"
    return addprocs(
        worker_count;
        exeflags=[project_flag, "--threads=1", "--gcthreads=1"],
        enable_threaded_blas=false,
        env=Dict(
            "JULIA_NUM_THREADS" => "1",
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
            using StenosisHemodynamics
        end
        ))
    end

    return worker_ids
end
