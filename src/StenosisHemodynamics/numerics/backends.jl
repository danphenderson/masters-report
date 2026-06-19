abstract type AbstractTimeBackend end

"""
Native fixed-step finite-volume backend.

This preserves the original in-repo SSP RK3 stepping behavior and remains the
default for `simulate(params)`.
"""
struct NativeRK3Backend <: AbstractTimeBackend end

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
backend_algorithm_name(::NativeRK3Backend) = "ssprk"
backend_algorithm_name(backend::SciMLTimeBackend) = algorithm_name(backend.solve.algorithm)

"""
    simulate(params, backend; progress_every=0) -> SimulationResult
    simulate(params; backend=NativeRK3Backend(), progress_every=0)

Advance one case through the selected backend and return the final state.
"""
function simulate(p::Params, backend::NativeRK3Backend; progress_every::Int = 0)
    p.space isa DGMethod && return simulate_dg(p, p.space; progress_every=progress_every)

    start_ns = telemetry_start_ns()
    @telemetry_info "simulation started" event="simulation_started" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="started"
    try
        validate(p)

        initial = initial_state_result(p)
        z, A, Q, dx = initial.z, initial.area, initial.flow, initial.dx
        step_cache = NativeStepCache(length(A))
        diagnostics = DiagnosticsAccumulator(A, dx)
        t = 0.0
        step = 0

        while t < p.tfinal - 1.0e-14
            dt = min(choose_dt(A, Q, z, dx, p), p.tfinal - t)
            record_timestep_diagnostics!(diagnostics, A, Q, z, dx, dt, p)
            native_step!(A, Q, z, dx, dt, t, p, step_cache, diagnostics)
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
        @telemetry_info "simulation completed" event="simulation_completed" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="ok" elapsed_s=telemetry_elapsed_s(start_ns) rows=length(A)
        return result
    catch err
        @telemetry_error "simulation failed" event="simulation_failed" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="error" elapsed_s=telemetry_elapsed_s(start_ns) reason=sprint(showerror, err)
        rethrow()
    end
end

function simulate(p::Params, backend::SciMLTimeBackend; progress_every::Int = 0)
    start_ns = telemetry_start_ns()
    @telemetry_info "simulation started" event="simulation_started" stage="simulate" backend=backend_name(backend) method=spatial_method_name(p.space) nx=p.nx tfinal=p.tfinal status="started"
    try
        _ = progress_every
        validate(p)
        p.space isa FVLaxWendroffMethod &&
            throw(ArgumentError("fv-lax-wendroff requires native fixed-step prediction and is not available with SciMLTimeBackend"))
        p.space isa DGMethod && p.space.degree > 0 &&
            throw(ArgumentError("DG degree $(p.space.degree) currently uses the native modal DG solver, not SciMLTimeBackend"))

        sim = semidiscretize(p)
        initial = initial_state_result(p)
        prob = ode_problem(sim; u0=pack_state(initial.area, initial.flow))
        sol = solve_ode_problem(prob, backend)
        final_state = Vector(sol.u[end])
        A, Q = unpack_state(final_state, sim.layout)

        if !all(isfinite, A) || !all(isfinite, Q)
            error("non-finite SciML solution at t=$(sol.t[end])")
        end
        minimum(A) > 0.0 || error("nonpositive SciML area at t=$(sol.t[end])")

        result = SimulationResult(copy(sim.z), A, Q, sol.t[end], sciml_step_count(sol), initial.summary)
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
