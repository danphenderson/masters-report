#!/usr/bin/env julia

using LinearAlgebra
using Printf
using StenoticHemodynamics

const PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const REPO_ROOT = normpath(joinpath(PACKAGE_ROOT, "..", ".."))
const BENCH_OUTPUT_PARENT = joinpath(REPO_ROOT, "tmp", "native-resolved-fsi-production-benchmark")

const BENCH_BLAS_THREADS = parse(Int, get(ENV, "OPENBLAS_NUM_THREADS", "1"))
LinearAlgebra.BLAS.set_num_threads(BENCH_BLAS_THREADS)
LinearAlgebra.BLAS.get_num_threads() == BENCH_BLAS_THREADS || error(
    "native resolved-FSI benchmark requested BLAS=$(BENCH_BLAS_THREADS) but runtime reports " *
    "$(LinearAlgebra.BLAS.get_num_threads())",
)

function native_resolved_fsi_expected_julia_threads()
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

const BENCH_EXPECTED_JULIA_THREADS = native_resolved_fsi_expected_julia_threads()
if BENCH_EXPECTED_JULIA_THREADS !== nothing &&
   Threads.nthreads() != BENCH_EXPECTED_JULIA_THREADS
    error(
        "native resolved-FSI benchmark requested JULIA_NUM_THREADS=$(BENCH_EXPECTED_JULIA_THREADS) " *
        "but runtime reports $(Threads.nthreads())",
    )
end

const BENCHMARK_CASES = (
    (
        label="small_8x2x8_3steps",
        resolution=StenoticHemodynamics.NativeResolvedFSIMeshResolution(axial=8, radial=2, angular=8),
        steps=3,
    ),
    (
        label="medium_16x3x12_1step",
        resolution=StenoticHemodynamics.NativeResolvedFSIMeshResolution(axial=16, radial=3, angular=12),
        steps=1,
    ),
)

function selected_benchmark_cases()
    selector = lowercase(get(ENV, "NATIVE_RESOLVED_FSI_BENCH_CASE", "all"))
    selector == "all" && return BENCHMARK_CASES
    selected = filter(case -> lowercase(case.label) == selector || startswith(lowercase(case.label), selector), BENCHMARK_CASES)
    isempty(selected) && throw(ArgumentError(
        "unknown NATIVE_RESOLVED_FSI_BENCH_CASE=$(repr(selector)); use all, small, or medium",
    ))
    return Tuple(selected)
end

function benchmark_output_root(label::AbstractString)
    thread_label = replace(string(Threads.nthreads()), "." => "p")
    pid_label = string(getpid())
    root = joinpath(BENCH_OUTPUT_PARENT, label, "threads$(thread_label)-pid$(pid_label)")
    mkpath(root)
    return root
end

csv_cell(value) = begin
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

function print_benchmark_header()
    println(join((
        "case",
        "julia_threads",
        "blas_threads",
        "elapsed_wall_time_s",
        "allocated_bytes",
        "gc_time_s",
        "gridap_model_setup_s",
        "gridap_space_setup_s",
        "gridap_measure_setup_s",
        "gridap_operator_assembly_s",
        "gridap_affine_operator_s",
        "gridap_matrix_extraction_s",
        "gridap_rhs_extraction_s",
        "linear_symbolic_factorization_s",
        "linear_numeric_factorization_s",
        "linear_backsolve_s",
        "fluid_solve_total_s",
        "wall_pressure_sampling_s",
        "wall_update_s",
        "diagnostics_s",
        "checkpoint_output_s",
        "output_write_s",
        "step_total_s",
        "phase_timing_total_s",
        "gridap_matrix_rows",
        "gridap_matrix_cols",
        "gridap_matrix_nnz",
        "gridap_matrix_structure_digest",
        "gridap_matrix_value_digest",
        "gridap_rhs_digest",
        "gridap_reuse_status",
        "gridap_reuse_miss_reason",
        "gridap_operator_component_status",
        "gridap_operator_component_terms",
        "gridap_solver_backend_status",
        "gridap_context_reused",
        "gridap_model_reused",
        "gridap_fe_spaces_reused",
        "gridap_measures_reused",
        "gridap_matrix_structure_stable",
        "gridap_symbolic_factorization_eligible",
        "gridap_symbolic_factorization_reused",
        "gridap_symbolic_factorization_cache_status",
        "gridap_symbolic_factorization_setup_count",
        "gridap_symbolic_factorization_reuse_count",
        "gridap_numeric_factorization_reused",
        "gridap_numeric_factorization_cache_status",
        "gridap_numeric_factorization_cache_key",
        "gridap_numeric_factorization_matrix_value_digest",
        "gridap_numeric_factorization_setup_count",
        "gridap_numeric_factorization_reuse_count",
        "gridap_reuse_reason_codes",
        "gridap_mesh_topology_digest",
        "gridap_coordinate_value_digest",
        "gridap_matrix_value_baseline_digest",
        "gridap_matrix_value_digest_observation_count",
        "gridap_matrix_value_digest_unique_count",
        "gridap_matrix_value_digest_current_count",
        "gridap_matrix_value_digest_repeat_count",
        "gridap_matrix_value_digest_history_tail",
        "picard_converged",
        "coupling_converged",
        "max_coupling_iterations_used",
        "final_coupling_displacement_residual_cm",
        "wall_pressure_digest",
        "wall_displacement_digest",
        "output_dir",
    ), ","))
end

function run_benchmark_case(case)
    dt_s = 1.0e-4
    tfinal_s = case.steps * dt_s
    output_root = benchmark_output_root(case.label)
    spec = StenoticHemodynamics.NativeResolvedFSIPartitionedProductionSpec(
        case_id=:sev23,
        resolution=case.resolution,
        output_root=output_root,
        dt_s=dt_s,
        tfinal_s=tfinal_s,
        snapshot_times_s=(tfinal_s,),
        overwrite=true,
        inlet_outlet_boundary_mode=:poiseuille_inlet_zero_outlet_stress_section41,
        inlet_umax_cm_s=45.0,
    )
    timed = @timed StenoticHemodynamics.run_native_resolved_fsi_partitioned_production(spec)
    result = timed.value
    smoke = result.smoke_result
    diagnostics = smoke.solver_diagnostics
    phase = smoke.phase_timing_s
    row = (
        case.label,
        Threads.nthreads(),
        LinearAlgebra.BLAS.get_num_threads(),
        @sprintf("%.9f", timed.time),
        timed.bytes,
        @sprintf("%.9f", timed.gctime),
        @sprintf("%.9f", phase.gridap_model_setup_s),
        @sprintf("%.9f", phase.gridap_space_setup_s),
        @sprintf("%.9f", phase.gridap_measure_setup_s),
        @sprintf("%.9f", phase.gridap_operator_assembly_s),
        @sprintf("%.9f", phase.gridap_affine_operator_s),
        @sprintf("%.9f", phase.gridap_matrix_extraction_s),
        @sprintf("%.9f", phase.gridap_rhs_extraction_s),
        @sprintf("%.9f", phase.linear_symbolic_factorization_s),
        @sprintf("%.9f", phase.linear_numeric_factorization_s),
        @sprintf("%.9f", phase.linear_backsolve_s),
        @sprintf("%.9f", phase.fluid_solve_total_s),
        @sprintf("%.9f", phase.wall_pressure_sampling_s),
        @sprintf("%.9f", phase.wall_update_s),
        @sprintf("%.9f", phase.diagnostics_s),
        @sprintf("%.9f", phase.checkpoint_output_s),
        @sprintf("%.9f", phase.output_write_s),
        @sprintf("%.9f", phase.step_total_s),
        @sprintf("%.9f", StenoticHemodynamics.native_resolved_fsi_phase_timing_total_s(phase)),
        diagnostics.gridap_matrix_rows,
        diagnostics.gridap_matrix_cols,
        diagnostics.gridap_matrix_nnz,
        diagnostics.gridap_matrix_structure_digest,
        diagnostics.gridap_matrix_value_digest,
        diagnostics.gridap_rhs_digest,
        diagnostics.gridap_reuse_status,
        diagnostics.gridap_reuse_miss_reason,
        diagnostics.gridap_operator_component_status,
        diagnostics.gridap_operator_component_terms,
        diagnostics.gridap_solver_backend_status,
        diagnostics.gridap_context_reused,
        diagnostics.gridap_model_reused,
        diagnostics.gridap_fe_spaces_reused,
        diagnostics.gridap_measures_reused,
        diagnostics.gridap_matrix_structure_stable,
        diagnostics.gridap_symbolic_factorization_eligible,
        diagnostics.gridap_symbolic_factorization_reused,
        diagnostics.gridap_symbolic_factorization_cache_status,
        diagnostics.gridap_symbolic_factorization_setup_count,
        diagnostics.gridap_symbolic_factorization_reuse_count,
        diagnostics.gridap_numeric_factorization_reused,
        diagnostics.gridap_numeric_factorization_cache_status,
        diagnostics.gridap_numeric_factorization_cache_key,
        diagnostics.gridap_numeric_factorization_matrix_value_digest,
        diagnostics.gridap_numeric_factorization_setup_count,
        diagnostics.gridap_numeric_factorization_reuse_count,
        diagnostics.gridap_reuse_reason_codes,
        diagnostics.gridap_mesh_topology_digest,
        diagnostics.gridap_coordinate_value_digest,
        diagnostics.gridap_matrix_value_baseline_digest,
        diagnostics.gridap_matrix_value_digest_observation_count,
        diagnostics.gridap_matrix_value_digest_unique_count,
        diagnostics.gridap_matrix_value_digest_current_count,
        diagnostics.gridap_matrix_value_digest_repeat_count,
        diagnostics.gridap_matrix_value_digest_history_tail,
        smoke.picard_converged,
        smoke.coupling_converged,
        smoke.max_coupling_iterations_used,
        @sprintf("%.12e", smoke.final_coupling_displacement_residual_cm),
        StenoticHemodynamics.native_resolved_fsi_vector_digest(smoke.wall_pressure_dyn_cm2),
        StenoticHemodynamics.native_resolved_fsi_vector_digest(smoke.wall_displacement_cm),
        result.output_dir,
    )
    println(join(csv_cell.(row), ","))
    return result
end

function main()
    print_benchmark_header()
    for case in selected_benchmark_cases()
        run_benchmark_case(case)
    end
    return nothing
end

main()
