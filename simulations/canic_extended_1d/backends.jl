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

SciMLTimeBackend() = SciMLTimeBackend(SolveSpec())

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
    validate(p)

    z, A, Q, dx = initial_state(p)
    t = 0.0
    step = 0

    while t < p.tfinal - 1.0e-14
        dt = min(choose_dt(A, Q, z, dx, p), p.tfinal - t)
        A, Q = rk3_step(A, Q, z, dx, dt, p)
        t += dt
        step += 1

        if progress_every > 0 && step % progress_every == 0
            @info "simulation progress" step t dt minA=minimum(A) maxU=maximum(abs.(Q ./ A))
        end

        if !all(isfinite, A) || !all(isfinite, Q)
            error("non-finite solution at t=$(t)")
        end
    end

    return SimulationResult(z, A, Q, t, step)
end

function simulate(p::Params, backend::SciMLTimeBackend; progress_every::Int = 0)
    validate(p)

    sim = semidiscretize(p)
    prob = ode_problem(sim)
    sol = solve_ode_problem(prob, backend)
    final_state = Vector(sol.u[end])
    A, Q = unpack_state(final_state, sim.layout)

    if !all(isfinite, A) || !all(isfinite, Q)
        error("non-finite SciML solution at t=$(sol.t[end])")
    end
    minimum(A) > 0.0 || error("nonpositive SciML area at t=$(sol.t[end])")

    return SimulationResult(copy(sim.z), A, Q, sol.t[end], sciml_step_count(sol))
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
