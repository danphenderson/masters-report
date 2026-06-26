"""
    AbstractTimeBackend

Time-integration backend protocol.

Backends choose how a validated `Params` object is advanced in time. New
backends should define `backend_name`, `backend_algorithm_name` or
`run_algorithm_name`, `supports_backend(method, backend)`, and
`simulate(params, backend; progress_every=0)`. Backend compatibility must be
expressed with trait dispatch rather than open-coded method checks.
"""
abstract type AbstractTimeBackend end

"""
Native fixed-step finite-volume backend.

This preserves the original in-repo SSP RK3 stepping behavior and remains the
default for `simulate(params)`.
"""
struct NativeRK3Backend <: AbstractTimeBackend
    solver_threads::Int

    function NativeRK3Backend(solver_threads::Integer)
        solver_threads >= 1 || throw(ArgumentError("solver_threads must be positive"))
        return new(Int(solver_threads))
    end
end

function NativeRK3Backend(; solver_threads::Integer = 1)
    return NativeRK3Backend(solver_threads)
end

"""
SciML/OrdinaryDiffEq backend.

Wraps the same `SemiDiscreteSimulation` as an `ODEProblem` and solves it with
the policy and tolerances stored in `SolveSpec`.
"""
struct SciMLTimeBackend <: AbstractTimeBackend
    solve::SolveSpec
end

function SciMLTimeBackend(; solve::SolveSpec = SolveSpec())
    return SciMLTimeBackend(validate(solve))
end

backend_name(::NativeRK3Backend) = "native"
backend_name(::SciMLTimeBackend) = "sciml"
backend_name(backend::AbstractTimeBackend) = string(nameof(typeof(backend)))
backend_algorithm_name(::NativeRK3Backend) = "ssprk"
backend_algorithm_name(backend::SciMLTimeBackend) = algorithm_name(backend.solve.algorithm)
solver_thread_count(::AbstractTimeBackend) = 1
solver_thread_count(backend::NativeRK3Backend) = backend.solver_threads
native_solver_threading_enabled(backend::NativeRK3Backend) = backend.solver_threads > 1 && Threads.nthreads() > 1
native_solver_threading_enabled(::AbstractTimeBackend) = false

"""
    supports_backend(method, backend) -> Bool

Internal compatibility query between spatial methods and time backends. New
methods or backends should specialize this method and the lower-level spatial
method traits rather than adding `isa` checks to `simulate`.
"""
supports_backend(::AbstractSpatialMethod, ::NativeRK3Backend) = true
supports_backend(method::AbstractSpatialMethod, ::SciMLTimeBackend) =
    !requires_fixed_timestep(method) && !requires_native_modal_solver(method)
supports_backend(::AbstractSpatialMethod, ::AbstractTimeBackend) = false

unsupported_backend_message(method::AbstractSpatialMethod, backend::AbstractTimeBackend) =
    "$(spatial_method_name(method)) does not support $(backend_name(backend)) backend"

unsupported_backend_message(method::FVLaxWendroffMethod, ::SciMLTimeBackend) =
    "$(spatial_method_name(method)) requires native fixed-step prediction and is not available with SciMLTimeBackend"

unsupported_backend_message(method::DGMethod, ::SciMLTimeBackend) =
    "DG degree $(method.degree) currently uses the native modal DG solver, not SciMLTimeBackend"

function assert_backend_supported(method::AbstractSpatialMethod, backend::AbstractTimeBackend)
    supports_backend(method, backend) || throw(ArgumentError(unsupported_backend_message(method, backend)))
    return method
end

run_algorithm_name(params::Params, backend::NativeRK3Backend) = time_stepper_name(params.time_stepper)
run_algorithm_name(::Params, backend::SciMLTimeBackend) = backend_algorithm_name(backend)

"""
    simulate(params, backend; progress_every=0) -> SimulationResult
    simulate(params; backend=NativeRK3Backend(), progress_every=0)

Advance one case through the selected backend and return the final state.
"""
function simulate(p::Params, backend::NativeRK3Backend; progress_every::Int = 0)
    method_family(p.space) == :discontinuous_galerkin && return simulate_dg(p, p.space; progress_every=progress_every)

    start_ns = telemetry_start_ns()
    threaded = native_solver_threading_enabled(backend)
    @telemetry_info "simulation started" event="simulation_started" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="started" solver_threads=backend.solver_threads julia_threads=Threads.nthreads()
    try
        validate(p)

        initial = initial_state_result(p)
        z, A, Q, dx = initial.z, initial.area, initial.flow, initial.dx
        step_cache = NativeStepCache(length(A))
        diagnostics = DiagnosticsAccumulator(A, dx)
        t = 0.0
        step = 0

        while t < p.tfinal - 1.0e-14
            dt = choose_dt_record_timestep!(diagnostics, A, Q, z, dx, p.tfinal - t, p; threaded=threaded)
            native_step!(A, Q, z, dx, dt, t, p, step_cache, diagnostics; threaded=threaded)
            t += dt
            step += 1
            record_mass_diagnostics!(diagnostics, A, dx)

            if progress_every > 0 && step % progress_every == 0
                @telemetry_info "simulation progress" event="simulation_progress" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="running" step t dt minA=minimum(A) maxU=maximum(abs.(Q ./ A))
            end

            if !all(isfinite, A) || !all(isfinite, Q)
                error("non-finite solution at t=$(t)")
            end
        end

        result = SimulationResult(z, A, Q, t, step, initial.summary, finalize_diagnostics(diagnostics))
        @telemetry_info "simulation completed" event="simulation_completed" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="ok" elapsed_s=telemetry_elapsed_s(start_ns) rows=length(A) solver_threads=backend.solver_threads julia_threads=Threads.nthreads()
        return result
    catch err
        @telemetry_error "simulation failed" event="simulation_failed" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="error" elapsed_s=telemetry_elapsed_s(start_ns) reason=sprint(showerror, err) solver_threads=backend.solver_threads julia_threads=Threads.nthreads()
        rethrow()
    end
end

function simulate(p::Params, backend::SciMLTimeBackend; progress_every::Int = 0)
    start_ns = telemetry_start_ns()
    @telemetry_info "simulation started" event="simulation_started" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="started"
    try
        _ = progress_every
        validate(p)
        assert_backend_supported(p.space, backend)

        sim = semidiscretize(p)
        initial = initial_state_result(p)
        prob = ode_problem(sim; u0=pack_state(initial.area, initial.flow))
        sol = solve_ode_problem(prob, backend)
        times = Float64.(collect(sol.t))
        area_snapshots = Vector{Vector{Float64}}(undef, length(sol.u))
        flow_snapshots = Vector{Vector{Float64}}(undef, length(sol.u))
        for i in eachindex(sol.u)
            area_snapshots[i], flow_snapshots[i] = unpack_state(Vector(sol.u[i]), sim.layout)
        end
        A = area_snapshots[end]
        Q = flow_snapshots[end]

        if !all(isfinite, A) || !all(isfinite, Q)
            error("non-finite SciML solution at t=$(sol.t[end])")
        end
        minimum(A) > 0.0 || error("nonpositive SciML area at t=$(sol.t[end])")

        diagnostics = finalize_snapshot_diagnostics(copy(sim.z), area_snapshots, flow_snapshots, times, sim.dx, p)
        result = SimulationResult(copy(sim.z), A, Q, sol.t[end], sciml_step_count(sol), initial.summary, diagnostics)
        @telemetry_info "simulation completed" event="simulation_completed" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="ok" elapsed_s=telemetry_elapsed_s(start_ns) rows=length(A)
        return result
    catch err
        @telemetry_error "simulation failed" event="simulation_failed" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="error" elapsed_s=telemetry_elapsed_s(start_ns) reason=sprint(showerror, err)
        rethrow()
    end
end

function simulate(p::Params; backend::AbstractTimeBackend = NativeRK3Backend(), progress_every::Int = 0)
    return simulate(p, backend; progress_every=progress_every)
end

function sciml_step_count(sol)
    if hasproperty(sol, :destats) && hasproperty(sol.destats, :nsteps)
        return sol.destats.nsteps
    end

    return max(length(sol.t) - 1, 0)
end
