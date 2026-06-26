using Test
using StenoticHemodynamics

@testset "StenoticHemodynamics public API boundary" begin
    exported_names = setdiff(Set(names(StenoticHemodynamics; all=false, imported=false)), Set([:StenoticHemodynamics]))

    expected_exports = Set(Symbol[
        :AbstractAlgorithmPolicy,
        :AbstractForcingTerm,
        :AbstractForwardModel,
        :AbstractInitialConditionSpec,
        :AbstractInletBoundary,
        :AbstractLimiter,
        :AbstractNativeTimeStepper,
        :AbstractOutletBoundary,
        :AbstractRheology,
        :AbstractSpatialMethod,
        :AbstractTimeBackend,
        :AbstractVelocityProfile,
        :AbstractWallLaw,
        :AutoPolicy,
        :CanicExtendedOneDModel,
        :CanicKoiterWallLaw,
        :CarreauRheology,
        :CarreauYasudaRheology,
        :CassonRheology,
        :ClassicalParabolicOneDModel,
        :DGMethod,
        :FVFirstOrderMethod,
        :FVGeometryRestWellBalancedMethod,
        :FVLaxWendroffMethod,
        :FVMUSCLMethod,
        :FVWENO3Method,
        :FixedAreaCharacteristicOutlet,
        :FlatVelocityProfile,
        :FlowWaveformInlet,
        :ForwardEulerStepper,
        :GeometryRestIC,
        :InitialConditionSummary,
        :ManufacturedForcing,
        :ManufacturedSolutionIC,
        :MinmodLimiter,
        :NativeRK3Backend,
        :NativeSSPRKPolicy,
        :NewtonianRheology,
        :NoForcing,
        :ParabolicVelocityProfile,
        :Params,
        :PowerLawRheology,
        :PowerVelocityProfile,
        :ReflectionCoefficientOutlet,
        :Rodas5PPolicy,
        :SSPRK2Stepper,
        :SSPRK3Stepper,
        :SSPRK54Stepper,
        :SciMLTimeBackend,
        :SimulationDiagnostics,
        :SimulationResult,
        :SolveSpec,
        :StationaryStokesIC,
        :SteadyVelocityInlet,
        :Tsit5Policy,
        :Vern7Policy,
        :Vern9Policy,
        :algorithm_name,
        :algorithm_policy,
        :backend_algorithm_name,
        :backend_name,
        :characteristic_shear_rate,
        :characteristic_speeds,
        :degrees_of_freedom,
        :diagnostic_pressure,
        :effective_dynamic_viscosity,
        :effective_kinematic_viscosity,
        :evolution_pressure,
        :forcing_name,
        :forward_model,
        :forward_model_name,
        :initial_condition,
        :initial_condition_name,
        :initial_condition_values,
        :initial_state_result,
        :inlet_boundary_name,
        :inlet_flow,
        :limiter_name,
        :mean_to_max_velocity_ratio,
        :minmod,
        :model_name,
        :momentum_alpha,
        :outlet_boundary_name,
        :pressure,
        :profile_exponent,
        :profile_name,
        :radial_profile_velocity,
        :reconstructed_axial_velocity,
        :rheology_name,
        :shear_rate_factor,
        :simulate,
        :spatial_method_name,
        :stenosis_throat_z,
        :time_stepper_name,
        :variable_radius_terms_enabled,
        :velocity,
        :wall_boundary_condition,
        :wall_law_name,
    ])
    @test exported_names == expected_exports

    classical = forward_model("classical-parabolic-1d")
    legacy_classical = forward_model("classical-1d-no-slip")
    @test classical isa ClassicalParabolicOneDModel
    @test legacy_classical isa ClassicalParabolicOneDModel
    @test legacy_classical isa ClassicalNoSlip1DModel
    @test forward_model_name(legacy_classical) == "classical-parabolic-1d"

    params = Params(initial_condition=GeometryRestIC(), severity=30.0)
    z = [2.75]
    area = [0.035]
    flow = [0.012]
    r0, r0z, _ = StenoticHemodynamics.stenosis(z[1], params)
    K = StenoticHemodynamics.wall_stiffness(params)
    gamma_plus_two = StenoticHemodynamics.gamma_plus_two(params)
    nu_eff = StenoticHemodynamics.effective_kinematic_viscosity(area[1], flow[1], r0, params)
    local_wall_pressure = K / r0^2 * (sqrt(area[1]) - r0)
    evolution_wall_pressure = K / params.rmax^2 * (sqrt(area[1]) - r0)
    diagnostic_wall_pressure = local_wall_pressure + gamma_plus_two * params.rho * nu_eff * flow[1] / area[1] * r0z / r0
    @test diagnostic_pressure(area, flow, z, params) == pressure(area, flow, z, params)
    @test !isapprox(r0, params.rmax; rtol=1.0e-8)
    @test !isapprox(local_wall_pressure, evolution_wall_pressure; rtol=1.0e-8)
    @test evolution_pressure(area, flow, z, params)[1] ≈ evolution_wall_pressure
    @test diagnostic_pressure(area, flow, z, params)[1] ≈ diagnostic_wall_pressure

    parabolic = ParabolicVelocityProfile()
    @test reconstructed_axial_velocity(3.0, 0.0, 2.0, parabolic) ≈ 6.0
    @test radial_profile_velocity(3.0, 0.0, 2.0, parabolic) ≈
          reconstructed_axial_velocity(3.0, 0.0, 2.0, parabolic)

    internal_names = Symbol[
        :parse_args,
        :parse_xdmf_velocity,
        :XDMFVelocityMetadata,
        :GeneratedStokesMesh,
        :generated_stokes_mesh,
        :area_view,
        :flow_view,
        :state_views,
        :legendre_value,
        :legendre_derivative,
        :dg_quadrature,
        :dg_degrees_of_freedom,
        :VanLeerLimiter,
        :method_family,
        :supports_backend,
        :requires_fixed_timestep,
        :requires_native_modal_solver,
        :assert_backend_supported,
        :unsupported_backend_message,
        :run_algorithm_name,
        :limited_slope,
        :vanleer,
        :workflow_kind,
        :validate_workflow_spec,
        :default_output_paths,
        :CLI_COMMAND_HANDLERS,
        :CLI_COMMAND_NAMES,
        :observed_order,
        :parallel_case_map,
        :default_output_stub,
        :study_summary_path,
        :SectionComparisonRow,
        :RadialProfileRow,
        :NodeSlabSensitivityRow,
        :OperatorValidationResult,
        :OperatorValidationRow,
        :OperatorValidationSpec,
        :ComparisonSummaryRow,
        :DynamicMembraneMode,
        :ManufacturedVerificationRow,
        :MembraneFSISolution,
        :MembraneFSIValidationResult,
        :MembraneFSIValidationRow,
        :MembraneFSIValidationSpec,
        :PHRefinementDemoRow,
        :QuasiStaticMembraneMode,
        :RestStateDriftRow,
        :RefinementStudyRow,
        :StationaryStokesRefinementRow,
        :StudyRunSummary,
        :write_csv_table,
        :csv_cell,
        :csv_record,
        :write_json,
        :sha256_file,
        :guarded_open_write,
        :write_study_csv,
        :write_refinement_study_csv,
        :write_refinement_latex_tables,
        :write_stationary_stokes_refinement_tex,
        :write_section_comparison_svg,
        :AbstractStudySpec,
        :ComparisonResult,
        :ComparisonSpec,
        :CrossSectionQuadratureOperator,
        :GeometryExportOptions,
        :GridConvergenceStudySpec,
        :ManufacturedVerificationResult,
        :ManufacturedVerificationSpec,
        :NodeSlabOperator,
        :NativeResolvedFSICaseSpec,
        :NativeResolvedFSIGeometry,
        :NativeResolvedFSIMesh,
        :NativeResolvedFSIMeshResolution,
        :NativeResolvedFSIMeshTags,
        :NativeResolvedFSINavierStokesSmokeResult,
        :NativeResolvedFSINavierStokesSmokeSpec,
        :NativeResolvedFSIPartitionedProductionResult,
        :NativeResolvedFSIPartitionedProductionSpec,
        :NativeResolvedFSIPartitionedSmokeResult,
        :NativeResolvedFSIPartitionedSmokeSpec,
        :NativeResolvedFSIParityResult,
        :NativeResolvedFSIParitySpec,
        :NativeResolvedFSIParityStatus,
        :NativeResolvedFSIProductionParityPlan,
        :NativeResolvedFSIProductionWorkflowPlan,
        :NativeResolvedFSISmokeResult,
        :NativeResolvedFSISmokeSpec,
        :NativeResolvedFSIWorkflowResult,
        :NativeResolvedFSIWorkflowSpec,
        :NativeResolvedFSIWorkflowStatus,
        :OpenBFRunSpec,
        :OutputSpec,
        :PHRefinementDemoResult,
        :PHRefinementDemoSpec,
        :PackageBenchmarkResult,
        :PackageBenchmarkSpec,
        :PackedStateLayout,
        :RefinementStudyResult,
        :RefinementStudySpec,
        :RestStateDriftResult,
        :RestStateDriftSpec,
        :Resolved3DCaseSpec,
        :Resolved3DFieldBundle,
        :Resolved3DWriterPaths,
        :Resolved3DWriterResult,
        :Resolved3DVelocityField,
        :SemiDiscreteSimulation,
        :SeveritySweepSpec,
        :StationaryStokesRefinementResult,
        :StationaryStokesRefinementSpec,
        :StudyResult,
        :default_native_resolved_fsi_navier_stokes_smoke_output_dir,
        :default_native_resolved_fsi_partitioned_production_output_dir,
        :default_native_resolved_fsi_partitioned_production_output_root,
        :default_native_resolved_fsi_partitioned_smoke_output_dir,
        :available_resolved3d_cases,
        :default_native_resolved_fsi_smoke_output_dir,
        :default_resolved3d_cases,
        :default_resolved3d_data_root,
        :default_native_resolved_fsi_output_dir,
        :export_stenosis_geometry_figures,
        :load_openbf_config,
        :load_resolved3d_velocity,
        :native_resolved_fsi_boundary_tag_names,
        :native_resolved_fsi_case_spec,
        :native_resolved_fsi_case_specs,
        :native_resolved_fsi_geometry,
        :native_resolved_fsi_lifted_displacement,
        :native_resolved_fsi_mesh,
        :native_resolved_fsi_navier_stokes_smoke_spec,
        :native_resolved_fsi_partitioned_production_estimated_field_payload_bytes,
        :native_resolved_fsi_partitioned_production_spec,
        :native_resolved_fsi_partitioned_smoke_spec,
        :native_resolved_fsi_node_tag_counts,
        :native_resolved_fsi_parity_spec,
        :native_resolved_fsi_production_parity_plans,
        :native_resolved_fsi_production_workflow_plans,
        :native_resolved_fsi_radius,
        :native_resolved_fsi_section_area,
        :native_resolved_fsi_smoke_spec,
        :native_resolved_fsi_synthetic_wall_lift,
        :native_resolved_fsi_tag_counts,
        :native_resolved_fsi_throat_z,
        :native_resolved_fsi_zero_displacement,
        :ode_problem,
        :pack_state,
        :params_from_openbf_config,
        :publish_resolved3d_report_assets,
        :run_available_resolved3d_comparison,
        :run_cli,
        :run_comparison,
        :run_manufactured_verification,
        :run_membrane_fsi_validation,
        :run_operator_validation,
        :run_package_benchmark,
        :run_ph_refinement_demo,
        :run_refinement_study,
        :run_rest_state_drift,
        :run_simulation,
        :run_native_resolved_fsi,
        :run_native_resolved_fsi_navier_stokes_smoke,
        :run_native_resolved_fsi_partitioned_production,
        :run_native_resolved_fsi_partitioned_smoke,
        :run_native_resolved_fsi_parity,
        :run_native_resolved_fsi_production_workflow,
        :run_native_resolved_fsi_smoke,
        :run_native_resolved_fsi_workflow,
        :run_stationary_stokes_refinement,
        :solve_quasistatic_membrane_fsi,
        :run_study,
        :rhs!,
        :semidiscretize,
        :solve_stationary_stokes,
        :unpack_state,
        :write_csv,
        :write_resolved3d_field_bundle,
        :write_svg,
    ]
    @test isempty(intersect(exported_names, internal_names))

    qualified_internal_names = Symbol[
        :run_cli,
        :run_study,
        :run_comparison,
        :run_available_resolved3d_comparison,
        :run_operator_validation,
        :run_package_benchmark,
        :run_manufactured_verification,
        :run_rest_state_drift,
        :load_openbf_config,
        :params_from_openbf_config,
        :load_resolved3d_velocity,
        :load_resolved3d_field_bundle,
        :publish_resolved3d_report_assets,
        :ComparisonSpec,
        :OperatorValidationResult,
        :OperatorValidationSpec,
        :ManufacturedVerificationSpec,
        :RestStateDriftSpec,
        :MembraneFSIValidationSpec,
        :NativeResolvedFSICaseSpec,
        :NativeResolvedFSIMesh,
        :NativeResolvedFSIMeshResolution,
        :NativeResolvedFSIParitySpec,
        :NativeResolvedFSIPartitionedProductionResult,
        :NativeResolvedFSIPartitionedProductionSpec,
        :NativeResolvedFSIProductionDryRunPlan,
        :NativeResolvedFSIProductionParityPlan,
        :NativeResolvedFSIProductionWorkflowPlan,
        :NativeResolvedFSISmokeSpec,
        :NativeResolvedFSIWorkflowSpec,
        :Resolved3DWriterPaths,
        :default_native_resolved_fsi_output_dir,
        :default_native_resolved_fsi_navier_stokes_smoke_output_dir,
        :default_native_resolved_fsi_partitioned_production_output_dir,
        :default_native_resolved_fsi_partitioned_production_output_root,
        :default_native_resolved_fsi_partitioned_smoke_output_dir,
        :default_native_resolved_fsi_smoke_output_dir,
        :native_resolved_fsi_case_spec,
        :native_resolved_fsi_imported_case_spec,
        :native_resolved_fsi_mesh,
        :native_resolved_fsi_navier_stokes_weak_form_coefficients,
        :native_resolved_fsi_navier_stokes_smoke_spec,
        :native_resolved_fsi_partitioned_diagnostic_outlet_gauge_pressure_profile,
        :native_resolved_fsi_partitioned_physical_wall_pressure_profile,
        :native_resolved_fsi_partitioned_production_dry_run,
        :native_resolved_fsi_partitioned_production_default_guard_report,
        :native_resolved_fsi_partitioned_production_estimated_field_payload_bytes,
        :native_resolved_fsi_partitioned_production_spec,
        :native_resolved_fsi_partitioned_smoke_spec,
        :native_resolved_fsi_partitioned_validate_physical_wall_pressure_profile,
        :native_resolved_fsi_parity_spec,
        :native_resolved_fsi_pressure_space_policy,
        :native_resolved_fsi_boundary_equivalence_status,
        :native_resolved_fsi_boundary_status_fields,
        :native_resolved_fsi_reduced_geometry_severity,
        :native_resolved_fsi_production_boundary_mode,
        :native_resolved_fsi_production_parity_matrix_rows,
        :native_resolved_fsi_production_parity_plans,
        :native_resolved_fsi_production_workflow_plans,
        :native_resolved_fsi_read_restart_metadata,
        :native_resolved_fsi_resume_partitioned_production,
        :native_resolved_fsi_wall_pressure_forcing_status,
        :native_resolved_fsi_wall_pressure_projection_status,
        :resolved3d_exact_canic_geometry_severity,
        :NativeResolvedFSINavierStokesSmokeSpec,
        :NativeResolvedFSIPartitionedSmokeSpec,
        :run_native_resolved_fsi_parity,
        :run_native_resolved_fsi_partitioned_production_batch,
        :run_native_resolved_fsi_navier_stokes_smoke,
        :run_native_resolved_fsi_partitioned_production,
        :run_native_resolved_fsi_partitioned_smoke,
        :run_native_resolved_fsi_production_workflow,
        :native_resolved_fsi_smoke_spec,
        :run_native_resolved_fsi_smoke,
        :run_native_resolved_fsi_workflow,
        :write_resolved3d_field_bundle,
    ]
    @test all(name -> isdefined(StenoticHemodynamics, name), qualified_internal_names)
    @test isempty(intersect(exported_names, qualified_internal_names))

    native_production_boundary_names = Symbol[
        :NativeResolvedFSIProductionDryRunPlan,
        :native_resolved_fsi_partitioned_production_dry_run,
        :native_resolved_fsi_partitioned_production_default_guard_report,
        :native_resolved_fsi_read_restart_metadata,
        :native_resolved_fsi_resume_partitioned_production,
    ]
    @test all(name -> isdefined(StenoticHemodynamics, name), native_production_boundary_names)
    @test isempty(intersect(exported_names, native_production_boundary_names))

    cli_handlers = StenoticHemodynamics.CLI_COMMAND_HANDLERS
    normalized_cli_command_names = replace.(split(StenoticHemodynamics.CLI_COMMAND_NAMES, ", "), "_" => "-")
    @test !any(
        name -> all(token -> occursin(token, name), ("native", "resolved", "fsi", "production")),
        normalized_cli_command_names,
    )
    @test all(
        name -> !haskey(cli_handlers, name),
        [
            "native-fsi",
            "native-resolved-fsi",
            "native-resolved-fsi-production",
            "native-resolved-fsi-production-dry-run",
            "production",
        ],
    )
    native_resolved_fsi_cli_blocked_handlers = Function[
        StenoticHemodynamics.native_resolved_fsi_partitioned_production_dry_run,
        StenoticHemodynamics.run_native_resolved_fsi_partitioned_production,
        StenoticHemodynamics.run_native_resolved_fsi_production_workflow,
    ]
    @test !any(
        handler -> any(blocked_handler -> handler === blocked_handler, native_resolved_fsi_cli_blocked_handlers),
        values(cli_handlers),
    )
    @test cli_handlers["fsi"] === StenoticHemodynamics.run_fsi_cli
    cli_help_path = tempname()
    open(cli_help_path, "w") do io
        redirect_stdout(io) do
            StenoticHemodynamics.run_cli(["--help"])
        end
    end
    cli_help_text = read(cli_help_path, String)
    @test occursin("fsi           Run membrane-FSI validation and native resolved-FSI status workflows", cli_help_text)
    default_capture_path = tempname()
    default_status = open(default_capture_path, "w") do io
        redirect_stdout(io) do
            StenoticHemodynamics.run_fsi_cli([
                "native-status",
                "--case-id",
                "sev23",
                "--mesh",
                "2x1x6",
                "--snapshot-times",
                "1e-4",
                "--imported-data-root",
                joinpath(mktempdir(), "missing-imported"),
            ])
        end
    end
    default_text = read(default_capture_path, String)
    @test default_status isa StenoticHemodynamics.NativeResolvedFSIProductionDryRunPlan
    @test default_status.output_dir ==
          StenoticHemodynamics.default_native_resolved_fsi_partitioned_production_output_dir(
        default_status.workflow_plan.production_spec,
    )
    @test !isfile(default_status.manifest_csv)
    @test !isfile(default_status.diagnostics_csv)
    @test !isfile(default_status.restart_metadata_json)
    @test !isfile(default_status.batch_status_jsonl)
    @test !isfile(default_status.batch_benchmark_json)
    @test default_status.boundary_mode == "pressure_drop_weak_inlet_outlet_gauge_smoke"
    @test occursin("native_resolved_fsi_status,dry_run", default_text)
    @test occursin("batch_status_jsonl,", default_text)
    @test occursin("batch_status_csv,", default_text)
    @test occursin("batch_benchmark_json,", default_text)
    @test occursin("batch_failure_json,", default_text)
    @test occursin("checkpoint_dir,", default_text)
    @test occursin("checkpoint_roles,wall_state|mesh_identity|fluid_state|coupling_state|output_linkage", default_text)
    @test occursin("production_spec_digest,", default_text)
    @test occursin("estimated_time_step_count,1", default_text)
    @test occursin("expected_fluid_solve_upper_bound,2", default_text)
    @test occursin("estimated_preproduction_runtime_s,", default_text)
    @test occursin("boundary_mode,pressure_drop_weak_inlet_outlet_gauge_smoke", default_text)
    @test occursin("pressure_nullspace_status,gridap_zero_mean_pressure_constraint_active", default_text)
    @test occursin("wall_stability_status,explicit_membrane_oscillator_dt_guard", default_text)

    mktempdir() do dir
        output_path = joinpath(dir, "native-status-stdout.txt")
        result = open(output_path, "w") do io
            redirect_stdout(io) do
                StenoticHemodynamics.run_fsi_cli([
                    "native-status",
                    "--case-id",
                    "sev23",
                    "--mesh",
                    "2x1x6",
                    "--snapshot-times",
                    "1e-4",
                    "--output-root",
                    joinpath(dir, "native-status"),
                    "--imported-data-root",
                    joinpath(dir, "missing-imported"),
                    "--inlet-outlet-boundary-mode",
                    "poiseuille_inlet_zero_outlet_stress_section41",
                    "--ic-pressure-drop-dyn-cm2",
                    "0.0",
                    "--status-every",
                    "1",
                ])
            end
        end
        text = read(output_path, String)
        @test result isa StenoticHemodynamics.NativeResolvedFSIProductionDryRunPlan
        @test result.boundary_mode == "poiseuille_inlet_zero_outlet_stress_section41"
        @test result.boundary_mode_class == "exact_section41"
        @test result.section41_boundary_status == "implemented_smoke_validated"
        @test !ispath(result.output_dir)
        @test occursin("native_resolved_fsi_status,dry_run", text)
        @test occursin("required_override_flags,none", text)
        @test occursin("boundary_mode,poiseuille_inlet_zero_outlet_stress_section41", text)
        @test occursin("boundary_mode=poiseuille_inlet_zero_outlet_stress_section41", text)
        @test occursin("boundary_mode_class,exact_section41", text)
        @test occursin("section41_boundary_status,implemented_smoke_validated", text)
        @test occursin("section41_boundary_status=implemented_smoke_validated", text)
        @test occursin("boundary_equivalence_status,exact_section41_boundary_mode_selected_smoke_validated", text)
        @test occursin("pressure_nullspace_status,no_gridap_zero_mean_pressure_constraint", text)
        @test occursin("exact_natural_cauchy_traction_pressure_reference", text)
        @test occursin("not_wall_stability_remediation", text)
        @test occursin("wall_stability_status,explicit_membrane_oscillator_dt_guard", text)
        @test occursin("sev23_development_exact_boundary_artifact_gate_passed_tfinal0p01", text)
        @test occursin("one-iteration coupling remains bounded evidence", text)
        @test occursin("snapshot_manifest_csv,", text)
        @test occursin("snapshot_diagnostics_csv,", text)
        @test occursin("restart_metadata_json,", text)
        @test occursin("batch_status_jsonl,", text)
        @test occursin("batch_benchmark_json,", text)
        @test occursin("expected_fluid_solve_upper_bound,2", text)
        @test occursin("parity_observations_csv,", text)
        @test occursin("parity_summary_csv,", text)
        @test occursin("imported_bundle_status,expected-skip", text)
        @test occursin("smoke-scale/operator-readiness evidence only", text)
        @test occursin("not paper-grade native resolved-FSI Section 4.1 reproduction", text)
        @test occursin("no production solver executed", result.status)
    end

    private_partitioned_production_helpers = Symbol[
        :native_resolved_fsi_partitioned_production_manifest_path,
        :native_resolved_fsi_partitioned_production_manifest_row,
        :native_resolved_fsi_partitioned_production_method_status,
        :native_resolved_fsi_partitioned_production_output_status,
        :native_resolved_fsi_partitioned_production_run_snapshot,
        :native_resolved_fsi_partitioned_production_snapshot_output_dir,
        :native_resolved_fsi_partitioned_production_snapshot_token,
        :native_resolved_fsi_partitioned_production_validate_runner_scope,
        :native_resolved_fsi_partitioned_production_write_manifest,
    ]
    @test all(name -> !isdefined(StenoticHemodynamics, name), private_partitioned_production_helpers)
end
