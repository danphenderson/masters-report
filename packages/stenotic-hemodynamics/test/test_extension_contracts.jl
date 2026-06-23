isdefined(@__MODULE__, :assert_finite_positive_state) || include("test_helpers.jl")

const EXTENSION_CONTRACT_PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const EXTENSION_CONTRACT_SRC_ROOT = joinpath(EXTENSION_CONTRACT_PACKAGE_ROOT, "src", "StenoticHemodynamics")
const EXTENSION_CONTRACT_TEST_ROOT = joinpath(EXTENSION_CONTRACT_PACKAGE_ROOT, "test")

function extension_contract_julia_files(root::String)
    files = String[]
    for (dir, _, names) in walkdir(root)
        for name in sort(names)
            endswith(name, ".jl") || continue
            push!(files, joinpath(dir, name))
        end
    end
    return sort(files)
end

function extension_contract_import_roots(node)::Vector{Symbol}
    node isa Symbol && return Symbol[node]
    node isa Expr || return Symbol[]

    if node.head == :. || node.head == Symbol(":")
        isempty(node.args) && return Symbol[]
        return extension_contract_import_roots(first(node.args))
    end

    roots = Symbol[]
    for arg in node.args
        append!(roots, extension_contract_import_roots(arg))
    end
    return roots
end

function extension_contract_direct_import_lines(file::String, module_name::String)
    source = read(file, String)
    module_symbol = Symbol(module_name)
    lines = Int[]
    pos = firstindex(source)

    while true
        line_number = pos <= firstindex(source) ? 1 : count(==('\n'), SubString(source, firstindex(source), prevind(source, pos))) + 1
        expr, next_pos = Meta.parse(source, pos; raise=true, filename=file)
        expr === nothing && break

        if expr isa Expr && expr.head in (:using, :import)
            roots = Set{Symbol}()
            for arg in expr.args
                union!(roots, extension_contract_import_roots(arg))
            end
            module_symbol in roots && push!(lines, line_number)
        end

        pos = next_pos
    end

    return lines
end

function extension_contract_scan_direct_imports(files::Vector{String}, module_name::String)
    hits = Dict{String,Vector{Int}}()
    for file in files
        lines = extension_contract_direct_import_lines(file, module_name)
        isempty(lines) || (hits[relpath(file, EXTENSION_CONTRACT_PACKAGE_ROOT)] = lines)
    end
    return hits
end

function extension_contract_scan_line_pattern(files::Vector{String}, pattern::Regex)
    hits = Dict{String,Vector{Int}}()
    for file in files
        lines = Int[]
        for (line_number, line) in enumerate(eachline(file))
            occursin(pattern, line) && push!(lines, line_number)
        end
        isempty(lines) || (hits[relpath(file, EXTENSION_CONTRACT_PACKAGE_ROOT)] = lines)
    end
    return hits
end

function extension_contract_disallowed_sites(
    sites::Dict{String,Vector{Int}},
    allowed_relpaths::AbstractSet{String},
)
    return Dict(path => lines for (path, lines) in sites if !(path in allowed_relpaths))
end

function extension_contract_format_sites(sites::Dict{String,Vector{Int}})
    entries = String[]
    for path in sort(collect(keys(sites)))
        push!(entries, "  - $path (lines $(join(sites[path], ", ")))")
    end
    return join(entries, "\n")
end

function extension_contract_failure_message(policy::String, sites::Dict{String,Vector{Int}})
    return string(policy, "\nViolating files:\n", extension_contract_format_sites(sites))
end

function extension_contract_no_violations(policy::String, sites::Dict{String,Vector{Int}})
    isempty(sites) && return true
    @error extension_contract_failure_message(policy, sites)
    return false
end

function extension_contract_package_file(relpath::String)
    return joinpath(EXTENSION_CONTRACT_PACKAGE_ROOT, relpath)
end

@testset "StenoticHemodynamics extension contracts" begin
    @testset "dependency boundary imports" begin
        src_files = extension_contract_julia_files(EXTENSION_CONTRACT_SRC_ROOT)
        test_files = extension_contract_julia_files(EXTENSION_CONTRACT_TEST_ROOT)
        src_and_test_files = sort!(vcat(src_files, test_files))

        native_resolved_fsi_adapter = joinpath("src", "StenoticHemodynamics", "adapters", "native_resolved_fsi.jl")
        native_resolved_fsi_gridap_surface =
            joinpath("src", "StenoticHemodynamics", "adapters", "native_resolved_fsi_gridap.jl")
        restart_metadata_reader =
            joinpath("src", "StenoticHemodynamics", "workflows", "native_resolved_fsi_restart.jl")
        openbf_protocol_adapter = joinpath("src", "StenoticHemodynamics", "adapters", "openbf_protocol.jl")

        for module_name in ("SciMLBase", "OrdinaryDiffEq")
            hits = extension_contract_scan_direct_imports(src_files, module_name)
            @test extension_contract_no_violations(
                "$module_name should not be imported directly in src; keep SciML loading behind src/StenoticHemodynamics/adapters/sciml_problem.jl.",
                hits,
            )
        end

        yaml_hits = extension_contract_scan_direct_imports(src_files, "YAML")
        @test extension_contract_no_violations(
            "YAML should not be imported directly in src; keep lazy loading behind src/StenoticHemodynamics/adapters/openbf_protocol.jl and reuse that loader for restart metadata.",
            yaml_hits,
        )

        for module_name in ("JSON", "JSON3")
            json_hits = extension_contract_scan_direct_imports(src_files, module_name)
            @test extension_contract_no_violations(
                "$module_name should not be imported directly in src; restart metadata JSON is parsed through the existing lazy YAML loader because JSON is valid YAML.",
                json_hits,
            )
        end
        json_lazy_loader_hits = extension_contract_scan_line_pattern(
            src_files,
            r"\bJSON3?_UUID\b|PkgId\([^)]*\"JSON3?\"",
        )
        @test extension_contract_no_violations(
            "JSON/JSON3 lazy loaders should not be added; restart metadata reading must reuse the existing YAML loader.",
            json_lazy_loader_hits,
        )

        restart_source = read(extension_contract_package_file(restart_metadata_reader), String)
        openbf_source = read(extension_contract_package_file(openbf_protocol_adapter), String)
        @test occursin("function load_yaml_file", openbf_source)
        @test occursin("load_yaml_file(path_string)", restart_source)
        @test occursin("JSON is valid YAML", restart_source)

        hdf5_violations = extension_contract_disallowed_sites(
            extension_contract_scan_direct_imports(src_and_test_files, "HDF5"),
            Set([
                joinpath("src", "StenoticHemodynamics", "adapters", "resolved3d_io.jl"),
                joinpath("src", "StenoticHemodynamics", "adapters", "resolved3d_writer.jl"),
                joinpath("test", "runtests.jl"),
            ]),
        )
        @test extension_contract_no_violations(
            "HDF5 imports should stay confined to resolved-3D I/O/writer adapters and the HDF5-inspecting test harness.",
            hdf5_violations,
        )

        ezxml_violations = extension_contract_disallowed_sites(
            extension_contract_scan_direct_imports(src_and_test_files, "EzXML"),
            Set([
                joinpath("src", "StenoticHemodynamics", "adapters", "resolved3d_io.jl"),
            ]),
        )
        @test extension_contract_no_violations(
            "EzXML imports should stay confined to the resolved-3D XDMF reader adapter.",
            ezxml_violations,
        )

        gridap_violations = extension_contract_disallowed_sites(
            extension_contract_scan_direct_imports(src_files, "Gridap"),
            Set([
                joinpath("src", "StenoticHemodynamics", "adapters", "stokes_ic.jl"),
                native_resolved_fsi_adapter,
                joinpath("src", "StenoticHemodynamics", "workflows", "stationary_stokes_refinement_gridap.jl"),
                joinpath("src", "StenoticHemodynamics", "workflows", "geometry_export_stokes_common.jl"),
            ]),
        )
        @test extension_contract_no_violations(
            "Gridap imports should stay confined to native/stokes adapter seams and stationary-Stokes workflow helpers.",
            gridap_violations,
        )

        native_adapter_source = read(extension_contract_package_file(native_resolved_fsi_adapter), String)
        native_gridap_source = read(extension_contract_package_file(native_resolved_fsi_gridap_surface), String)
        @test occursin("include(\"native_resolved_fsi_gridap.jl\")", native_adapter_source)
        @test occursin("native_resolved_fsi_radial_wall_velocity_function", native_gridap_source)
        @test occursin("dirichlet_tags=\"wall\"", native_gridap_source)
    end

    @testset "spatial method traits" begin
        fv_methods = (
            FVFirstOrderMethod(),
            FVMUSCLMethod(),
            FVWENO3Method(),
            FVLaxWendroffMethod(),
        )
        for method in fv_methods
            @test StenoticHemodynamics.method_family(method) == :finite_volume
            @test !StenoticHemodynamics.requires_native_modal_solver(method)
            @test degrees_of_freedom(7, method) == 14
        end

        @test StenoticHemodynamics.method_family(DGMethod(2)) == :discontinuous_galerkin
        @test !StenoticHemodynamics.requires_fixed_timestep(FVMUSCLMethod())
        @test StenoticHemodynamics.requires_fixed_timestep(FVLaxWendroffMethod())
        @test !StenoticHemodynamics.requires_native_modal_solver(DGMethod(0))
        @test StenoticHemodynamics.requires_native_modal_solver(DGMethod(1))
        @test degrees_of_freedom(7, DGMethod(3)) == 56
    end

    @testset "backend support traits" begin
        native = NativeRK3Backend()
        sciml = SciMLTimeBackend()

        @test StenoticHemodynamics.supports_backend(FVMUSCLMethod(), native)
        @test StenoticHemodynamics.supports_backend(FVMUSCLMethod(), sciml)
        @test !StenoticHemodynamics.supports_backend(FVLaxWendroffMethod(), sciml)
        @test StenoticHemodynamics.supports_backend(DGMethod(0), sciml)
        @test !StenoticHemodynamics.supports_backend(DGMethod(1), sciml)

        lax_params = Params(
            nx=8,
            tfinal=1.0e-5,
            space=FVLaxWendroffMethod(),
            initial_condition=GeometryRestIC(),
        )
        lax_error = try
            simulate(lax_params, sciml; progress_every=0)
            nothing
        catch err
            err
        end
        @test lax_error isa ArgumentError
        @test occursin("fixed-step", sprint(showerror, lax_error))

        dg_params = Params(
            nx=8,
            tfinal=1.0e-5,
            space=DGMethod(1),
            initial_condition=GeometryRestIC(),
        )
        dg_error = try
            simulate(dg_params, sciml; progress_every=0)
            nothing
        catch err
            err
        end
        @test dg_error isa ArgumentError
        @test occursin("native modal DG solver", sprint(showerror, dg_error))
    end

    @testset "Van Leer limiter extension pilot" begin
        limiter = StenoticHemodynamics.VanLeerLimiter()
        @test limiter_name(limiter) == "van-leer"
        @test StenoticHemodynamics.limited_slope([1.0, 2.0, 4.0], 2, limiter) ≈ 4.0 / 3.0
        @test StenoticHemodynamics.limited_slope([1.0, 2.0, 1.0], 2, limiter) == 0.0

        for method in (FVMUSCLMethod(limiter), FVLaxWendroffMethod(limiter))
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=method, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
            @test occursin("van-leer", spatial_method_name(method))
        end
    end

    @testset "workflow protocol helpers" begin
        mktempdir() do dir
            severity_spec = StenoticHemodynamics.SeveritySweepSpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                severities=[23.0],
                summary_csv=joinpath(dir, "severity.csv"),
                parallel_workers=0,
            )
            @test severity_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(severity_spec) == "severity_sweep"
            @test StenoticHemodynamics.default_output_paths(severity_spec).summary_csv == joinpath(dir, "severity.csv")
            @test StenoticHemodynamics.validate_workflow_spec(severity_spec) === severity_spec
            default_severity_spec = StenoticHemodynamics.SeveritySweepSpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                severities=[23.0],
                parallel_workers=0,
            )
            @test dirname(StenoticHemodynamics.study_summary_path(default_severity_spec)) ==
                  joinpath(StenoticHemodynamics.DEFAULT_SIMULATION_OUTPUT_ROOT, "studies")

            default_grid_spec = StenoticHemodynamics.GridConvergenceStudySpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                nxs=[8, 16],
                parallel_workers=0,
            )
            @test dirname(StenoticHemodynamics.study_summary_path(default_grid_spec)) ==
                  joinpath(StenoticHemodynamics.DEFAULT_SIMULATION_OUTPUT_ROOT, "studies")

            refinement_spec = StenoticHemodynamics.RefinementStudySpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                nxs=[8, 16],
                degrees=[0, 1],
                output_dir=joinpath(dir, "refinement"),
                parallel_workers=0,
            )
            refinement_paths = StenoticHemodynamics.default_output_paths(refinement_spec)
            @test StenoticHemodynamics.workflow_kind(refinement_spec) == "refinement"
            @test basename.(refinement_paths.csv_paths) == ["h_refinement.csv", "p_refinement.csv"]

            case_spec = StenoticHemodynamics.Resolved3DCaseSpec("77", 23.0, joinpath(dir, "velocity.xdmf"); target_time=5.0e-5)
            comparison_spec = StenoticHemodynamics.ComparisonSpec(
                cases=[case_spec],
                base_params=Params(nx=8, tfinal=5.0e-5, initial_condition=GeometryRestIC()),
                output_dir=joinpath(dir, "comparison"),
                section_count=3,
                profile_slices=[0.0],
                radial_bins=3,
                write_svg=true,
            )
            comparison_paths = StenoticHemodynamics.default_output_paths(comparison_spec)
            @test comparison_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(comparison_spec) == "resolved3d_comparison"
            @test basename(comparison_paths.summary_csv) == "comparison_summary.csv"
            @test basename(comparison_paths.overlay_svg) == "section_quadrature_overlay.svg"

            operator_spec = StenoticHemodynamics.OperatorValidationSpec(output_dir=joinpath(dir, "operator-validation"))
            operator_paths = StenoticHemodynamics.default_output_paths(operator_spec)
            @test operator_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(operator_spec) == "cross_section_operator_validation"
            @test basename(operator_paths.summary_csv) == "cross_section_operator_validation.csv"
            @test basename(operator_paths.summary_tex) == "cross_section_operator_validation.tex"

            fsi_spec = StenoticHemodynamics.MembraneFSIValidationSpec(
                base_params=Params(nx=8, tfinal=0.0, initial_condition=GeometryRestIC()),
                severities=[23.0],
                meshes=[(4, 1, 4)],
                output_dir=joinpath(dir, "fsi"),
                parallel_workers=0,
            )
            fsi_paths = StenoticHemodynamics.default_output_paths(fsi_spec)
            @test fsi_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(fsi_spec) == "membrane_fsi_validation"
            @test basename(fsi_paths.summary_csv) == "summary.csv"
            @test basename(fsi_paths.summary_tex) == "summary.tex"
            @test basename(fsi_paths.manifest_json) == "manifest.json"

            benchmark_spec = StenoticHemodynamics.PackageBenchmarkSpec(output_dir=joinpath(dir, "benchmark"))
            benchmark_paths = StenoticHemodynamics.default_output_paths(benchmark_spec)
            @test benchmark_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(benchmark_spec) == "package_benchmark"
            @test basename(benchmark_paths.case_results) == "case_results.csv"
            @test basename(benchmark_paths.manifest) == "manifest.json"
        end
    end

    @testset "CLI extension hooks" begin
        params, output, backend = StenoticHemodynamics.parse_args([
            "--space",
            "fv-muscl",
            "--limiter",
            "van_leer",
            "--tfinal",
            "1e-5",
            "--nx",
            "8",
            "--progress-every",
            "0",
            "--no-svg",
            "--ic",
            "geometry-rest",
        ])
        @test params.space isa FVMUSCLMethod
        @test params.space.limiter isa StenoticHemodynamics.VanLeerLimiter
        @test output.write_svg == false
        @test backend isa NativeRK3Backend
        @test spatial_method_name(params.space) == "fv-muscl-van-leer"

        handlers = StenoticHemodynamics.CLI_COMMAND_HANDLERS
        @test Set(keys(handlers)) == Set([
            "simulate",
            "openbf-run",
            "study",
            "stokes",
            "fsi",
            "verify",
            "compare-3d",
            "operator-validation",
            "benchmark",
            "export-assets",
        ])
        @test handlers["simulate"] === StenoticHemodynamics.run_simulate_cli
        @test handlers["fsi"] === StenoticHemodynamics.run_fsi_cli
        @test_throws ArgumentError StenoticHemodynamics.run_cli(["--tfinal", "1e-5"])
        @test_throws ArgumentError StenoticHemodynamics.run_cli(["not-a-command"])
    end
end
