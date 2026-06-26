#!/usr/bin/env julia

using Gridap
using LinearAlgebra
using Printf
using StenoticHemodynamics

const PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const REPO_ROOT = normpath(joinpath(PACKAGE_ROOT, "..", ".."))
const PROBE_OUTPUT_PARENT = joinpath(REPO_ROOT, "tmp", "native-resolved-fsi-block-solver-probe")

const PROBE_BLAS_THREADS = parse(Int, get(ENV, "OPENBLAS_NUM_THREADS", "1"))
LinearAlgebra.BLAS.set_num_threads(PROBE_BLAS_THREADS)
LinearAlgebra.BLAS.get_num_threads() == PROBE_BLAS_THREADS || error(
    "native resolved-FSI block/solver probe requested BLAS=$(PROBE_BLAS_THREADS) but runtime reports " *
    "$(LinearAlgebra.BLAS.get_num_threads())",
)

function expected_julia_threads()
    raw = strip(get(ENV, "JULIA_NUM_THREADS", ""))
    isempty(raw) && return nothing
    lowercase(raw) == "auto" && return nothing
    occursin(",", raw) && return nothing
    return try
        parse(Int, raw)
    catch
        nothing
    end
end

const EXPECTED_JULIA_THREADS = expected_julia_threads()
if EXPECTED_JULIA_THREADS !== nothing && Threads.nthreads() != EXPECTED_JULIA_THREADS
    error(
        "native resolved-FSI block/solver probe requested JULIA_NUM_THREADS=$(EXPECTED_JULIA_THREADS) " *
        "but runtime reports $(Threads.nthreads())",
    )
end

const DEFAULT_PROBE_CASES = (
    (
        label="small_8x2x8",
        resolution=StenoticHemodynamics.NativeResolvedFSIMeshResolution(axial=8, radial=2, angular=8),
    ),
    (
        label="medium_16x3x12",
        resolution=StenoticHemodynamics.NativeResolvedFSIMeshResolution(axial=16, radial=3, angular=12),
    ),
)

const EXTENDED_PROBE_CASES = (
    (
        label="large_24x4x16",
        resolution=StenoticHemodynamics.NativeResolvedFSIMeshResolution(axial=24, radial=4, angular=16),
    ),
)

const ALL_PROBE_CASES = (DEFAULT_PROBE_CASES..., EXTENDED_PROBE_CASES...)

function nonnegative_probe_int_env(name::String, default::Int)
    raw = strip(get(ENV, name, string(default)))
    value = try
        parse(Int, raw)
    catch
        throw(ArgumentError("$name must be an integer, got $(repr(raw))"))
    end
    value >= 0 || throw(ArgumentError("$name must be nonnegative, got $value"))
    return value
end

const PROBE_ASSEMBLY_WARMUPS = nonnegative_probe_int_env("NATIVE_RESOLVED_FSI_ASSEMBLY_WARMUPS", 0)
const PROBE_ASSEMBLY_REPEATS = max(1, nonnegative_probe_int_env("NATIVE_RESOLVED_FSI_ASSEMBLY_REPEATS", 1))
const PROBE_BACKEND_WARMUPS = nonnegative_probe_int_env("NATIVE_RESOLVED_FSI_BACKEND_WARMUPS", 0)
const PROBE_BACKEND_REPEATS = max(1, nonnegative_probe_int_env("NATIVE_RESOLVED_FSI_BACKEND_REPEATS", 1))

function selected_probe_cases()
    selector = lowercase(get(ENV, "NATIVE_RESOLVED_FSI_PROBE_CASE", "small"))
    selector == "all" && return DEFAULT_PROBE_CASES
    selector in ("extended", "all_extended", "all_bounded") && return ALL_PROBE_CASES
    selector in ("large", "larger") && return EXTENDED_PROBE_CASES
    selected = filter(case -> lowercase(case.label) == selector || startswith(lowercase(case.label), selector), ALL_PROBE_CASES)
    isempty(selected) && throw(ArgumentError(
        "unknown NATIVE_RESOLVED_FSI_PROBE_CASE=$(repr(selector)); use all, all_bounded, small, medium, or large",
    ))
    return Tuple(selected)
end

csv_cell(value) = begin
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

elapsed_s(start_ns::UInt64) = Float64(time_ns() - start_ns) / 1.0e9

vector_l2_norm(values) = sqrt(sum(abs2, values))

function relative_l2_difference(candidate, reference)
    difference_norm = vector_l2_norm(candidate .- reference)
    reference_norm = vector_l2_norm(reference)
    reference_norm > 0.0 && return difference_norm / reference_norm
    return difference_norm == 0.0 ? 0.0 : Inf
end

function residual_summary(matrix, solution, rhs)
    residual = matrix * solution .- rhs
    return (
        residual_l2=vector_l2_norm(residual),
        residual_relative_l2=relative_l2_difference(matrix * solution, rhs),
        residual_max_abs=isempty(residual) ? 0.0 : maximum(abs, residual),
    )
end

function print_block_header()
    println(join((
        "record_type",
        "case",
        "trial_role",
        "trial_index",
        "julia_threads",
        "blas_threads",
        "rows",
        "cols",
        "nnz",
        "boundary_mode",
        "pressure_constraint",
        "quadrature_degree",
        "full_matrix_structure_digest",
        "full_matrix_value_digest",
        "full_rhs_digest",
        "stable_matrix_nnz",
        "convection_matrix_nnz",
        "sparse_block_matrix_structure_digest_matches",
        "sparse_block_matrix_value_digest_matches",
        "sparse_block_matrix_relative_l2_difference",
        "sparse_block_matrix_max_abs_difference",
        "sparse_block_matrix_within_tolerance",
        "form_sum_matrix_value_digest_matches",
        "form_sum_matrix_relative_l2_difference",
        "form_sum_matrix_within_tolerance",
        "sparse_block_rhs_value_digest_matches",
        "sparse_block_rhs_relative_l2_difference",
        "sparse_block_rhs_max_abs_difference",
        "sparse_block_rhs_within_tolerance",
        "form_sum_rhs_value_digest_matches",
        "form_sum_rhs_relative_l2_difference",
        "form_sum_rhs_within_tolerance",
        "full_assembly_s",
        "stable_matrix_assembly_s",
        "convection_matrix_assembly_s",
        "component_form_sum_assembly_s",
        "previous_rhs_assembly_s",
        "boundary_rhs_assembly_s",
        "sparse_sum_s",
        "component_terms",
    ), ","))
end

function print_backend_header()
    println(join((
        "record_type",
        "case",
        "backend",
        "trial_role",
        "trial_index",
        "status",
        "julia_threads",
        "blas_threads",
        "elapsed_wall_time_s",
        "allocated_bytes",
        "gc_time_s",
        "symbolic_setup_s",
        "numeric_factorization_s",
        "backsolve_s",
        "residual_l2",
        "residual_relative_l2",
        "residual_max_abs",
        "solution_digest",
        "reference_solution_digest",
        "solution_value_digest_matches_reference",
        "solution_relative_l2_difference",
        "error",
    ), ","))
end

function run_gridap_lusolver_backend(matrix, rhs)
    solver = LUSolver()
    start_ns = time_ns()
    symbolic = symbolic_setup(solver, matrix)
    symbolic_s = elapsed_s(start_ns)
    start_ns = time_ns()
    numeric = numerical_setup(symbolic, matrix)
    numeric_s = elapsed_s(start_ns)
    solution = similar(rhs)
    start_ns = time_ns()
    solve!(solution, numeric, rhs)
    backsolve_s = elapsed_s(start_ns)
    return (
        symbolic_setup_s=symbolic_s,
        numeric_factorization_s=numeric_s,
        backsolve_s=backsolve_s,
        solution=solution,
    )
end

function run_julia_sparse_lu_backend(matrix, rhs)
    start_ns = time_ns()
    factorization = lu(matrix)
    numeric_s = elapsed_s(start_ns)
    start_ns = time_ns()
    solution = factorization \ rhs
    backsolve_s = elapsed_s(start_ns)
    return (
        symbolic_setup_s=NaN,
        numeric_factorization_s=numeric_s,
        backsolve_s=backsolve_s,
        solution=solution,
    )
end

function run_julia_sparse_backslash_backend(matrix, rhs)
    start_ns = time_ns()
    solution = matrix \ rhs
    elapsed = elapsed_s(start_ns)
    return (
        symbolic_setup_s=NaN,
        numeric_factorization_s=NaN,
        backsolve_s=elapsed,
        solution=solution,
    )
end

const SOLVER_BACKENDS = (
    ("gridap_lusolver", run_gridap_lusolver_backend),
    ("julia_sparse_lu", run_julia_sparse_lu_backend),
    ("julia_sparse_backslash", run_julia_sparse_backslash_backend),
)

function run_backend_rows(case_label, matrix, rhs; trial_role="measured", trial_index=1)
    reference_solution = nothing
    reference_digest = ""
    rows = Vector{Tuple}()
    for _ in 1:PROBE_BACKEND_WARMUPS
        for (_, backend_runner) in SOLVER_BACKENDS
            try
                backend_runner(matrix, rhs)
            catch
            end
        end
    end
    for repeat_index in 1:PROBE_BACKEND_REPEATS
        for (backend_name, backend_runner) in SOLVER_BACKENDS
            backend_trial_index = trial_index == 1 ? string(repeat_index) : "$(trial_index).$(repeat_index)"
            timed = @timed begin
                try
                    result = backend_runner(matrix, rhs)
                    if reference_solution === nothing
                        reference_solution = copy(result.solution)
                        reference_digest = StenoticHemodynamics.native_resolved_fsi_vector_digest(reference_solution)
                    end
                    solution_digest = StenoticHemodynamics.native_resolved_fsi_vector_digest(result.solution)
                    residual = residual_summary(matrix, result.solution, rhs)
                    row = (
                        "solver_backend",
                        case_label,
                        backend_name,
                        trial_role,
                        backend_trial_index,
                        "ok",
                        Threads.nthreads(),
                        LinearAlgebra.BLAS.get_num_threads(),
                        0.0,
                        0,
                        0.0,
                        result.symbolic_setup_s,
                        result.numeric_factorization_s,
                        result.backsolve_s,
                        residual.residual_l2,
                        residual.residual_relative_l2,
                        residual.residual_max_abs,
                        solution_digest,
                        reference_digest,
                        solution_digest == reference_digest,
                        relative_l2_difference(result.solution, reference_solution),
                        "",
                    )
                    row
                catch error
                    (
                        "solver_backend",
                        case_label,
                        backend_name,
                        trial_role,
                        backend_trial_index,
                        "error",
                        Threads.nthreads(),
                        LinearAlgebra.BLAS.get_num_threads(),
                        0.0,
                        0,
                        0.0,
                        NaN,
                        NaN,
                        NaN,
                        NaN,
                        NaN,
                        NaN,
                        "",
                        reference_digest,
                        false,
                        NaN,
                        sprint(showerror, error),
                    )
                end
            end
            row = timed.value
            row = Base.setindex(row, @sprintf("%.9f", timed.time), 9)
            row = Base.setindex(row, timed.bytes, 10)
            row = Base.setindex(row, @sprintf("%.9f", timed.gctime), 11)
            push!(rows, row)
        end
    end
    return rows
end

function run_probe_case(case; trial_role="measured", trial_index=1, emit_row=true)
    mesh = StenoticHemodynamics.native_resolved_fsi_mesh(:sev23, case.resolution)
    mkpath(joinpath(PROBE_OUTPUT_PARENT, case.label))
    timed = @timed StenoticHemodynamics.native_resolved_fsi_first_picard_block_assembly_probe(
        mesh;
        inlet_outlet_boundary_mode=:poiseuille_inlet_zero_outlet_stress_section41,
        inlet_umax_cm_s=45.0,
        pressure_drop_dyn_cm2=0.0,
        dt_s=1.0e-4,
    )
    probe = timed.value
    block_row = (
        "block_assembly",
        case.label,
        trial_role,
        trial_index,
        Threads.nthreads(),
        LinearAlgebra.BLAS.get_num_threads(),
        probe.rows,
        probe.cols,
        probe.nnz,
        probe.boundary_mode,
        probe.pressure_constraint,
        probe.quadrature_degree,
        probe.full_matrix_structure_digest,
        probe.full_matrix_value_digest,
        probe.full_rhs_digest,
        probe.stable_matrix_nnz,
        probe.convection_matrix_nnz,
        probe.sparse_block_matrix_structure_digest_matches,
        probe.sparse_block_matrix_value_digest_matches,
        @sprintf("%.12e", probe.sparse_block_matrix_relative_l2_difference),
        @sprintf("%.12e", probe.sparse_block_matrix_max_abs_difference),
        probe.sparse_block_matrix_within_tolerance,
        probe.form_sum_matrix_value_digest_matches,
        @sprintf("%.12e", probe.form_sum_matrix_relative_l2_difference),
        probe.form_sum_matrix_within_tolerance,
        probe.sparse_block_rhs_value_digest_matches,
        @sprintf("%.12e", probe.sparse_block_rhs_relative_l2_difference),
        @sprintf("%.12e", probe.sparse_block_rhs_max_abs_difference),
        probe.sparse_block_rhs_within_tolerance,
        probe.form_sum_rhs_value_digest_matches,
        @sprintf("%.12e", probe.form_sum_rhs_relative_l2_difference),
        probe.form_sum_rhs_within_tolerance,
        @sprintf("%.9f", probe.full_assembly_s),
        @sprintf("%.9f", probe.stable_matrix_assembly_s),
        @sprintf("%.9f", probe.convection_matrix_assembly_s),
        @sprintf("%.9f", probe.component_form_sum_assembly_s),
        @sprintf("%.9f", probe.previous_rhs_assembly_s),
        @sprintf("%.9f", probe.boundary_rhs_assembly_s),
        @sprintf("%.9f", probe.sparse_sum_s),
        probe.component_terms,
    )
    emit_row && println(join(csv_cell.(block_row), ","))
    return probe
end

function main()
    print_block_header()
    probes = Pair{String,Any}[]
    for case in selected_probe_cases()
        for warmup_index in 1:PROBE_ASSEMBLY_WARMUPS
            run_probe_case(case; trial_role="warmup", trial_index=warmup_index, emit_row=false)
        end
        for repeat_index in 1:PROBE_ASSEMBLY_REPEATS
            push!(probes, case.label => run_probe_case(case; trial_role="measured", trial_index=repeat_index))
        end
    end
    print_backend_header()
    for (probe_index, (case_label, probe)) in enumerate(probes)
        for row in run_backend_rows(case_label, probe.full_matrix, probe.full_rhs; trial_role="measured", trial_index=probe_index)
            println(join(csv_cell.(row), ","))
        end
    end
    return nothing
end

main()
