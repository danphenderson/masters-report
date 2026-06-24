const CANIC_2024_SOURCE_URL = "https://github.com/qcutexu/Extended-1D-AQ-system.git"
const CANIC_2024_SOURCE_COMMIT = "056a9da2b36b480691f18025d242d2c00f6e7180"
const CANIC_2024_SOURCE_LICENSE = "GPL-3.0"
const CANIC_SECTION41_PAPER_TIME_S = 1.0
const CANIC_SECTION41_DEFAULT_OUTPUT_DIR = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "canic-replication", "section41")
const CANIC_SECTION41_DEFAULT_MODELS = ("canic-extended-1d", "classical-1d-no-slip")
const CANIC_SECTION41_EXPECTED_FILENAMES = (
    "velocity.xdmf",
    "velocity.h5",
    "pressure.xdmf",
    "pressure.h5",
    "displace.xdmf",
    "displace.h5",
)

struct CanicSection41ReplicationSpec
    data_root::String
    output_dir::String
    report_assets_dir::String
    coordinate_mode::String
    nx::Int
    dt_s::Float64
    tfinal_s::Float64
    section_count::Int
    radial_sample_count::Int
    time_atol_s::Float64
    models::Vector{String}
    publish_report_assets::Bool
    overwrite::Bool
end

function CanicSection41ReplicationSpec(;
    data_root::AbstractString = DEFAULT_RESOLVED3D_DATA_ROOT,
    output_dir::AbstractString = CANIC_SECTION41_DEFAULT_OUTPUT_DIR,
    report_assets_dir::AbstractString = joinpath("report", "assets"),
    coordinate_mode::AbstractString = "deformed",
    nx::Integer = 100,
    dt_s::Real = 1.0e-5,
    tfinal_s::Real = CANIC_SECTION41_PAPER_TIME_S,
    section_count::Integer = 200,
    radial_sample_count::Integer = 41,
    time_atol_s::Real = 1.0e-6,
    models = CANIC_SECTION41_DEFAULT_MODELS,
    publish_report_assets::Bool = false,
    overwrite::Bool = false,
)
    coordinate_mode_value = replace(lowercase(strip(String(coordinate_mode))), "_" => "-")
    coordinate_mode_value in ("reference", "deformed") ||
        throw(ArgumentError("Canic Section 4.1 coordinate_mode must be reference or deformed"))
    model_values = [forward_model_name(forward_model(String(model))) for model in models]
    !isempty(model_values) || throw(ArgumentError("Canic Section 4.1 replication requires at least one 1D model"))
    nx_value = Int(nx)
    section_count_value = Int(section_count)
    radial_sample_count_value = Int(radial_sample_count)
    nx_value > 0 || throw(ArgumentError("Canic Section 4.1 nx must be positive"))
    Float64(dt_s) > 0.0 || throw(ArgumentError("Canic Section 4.1 dt_s must be positive"))
    Float64(tfinal_s) >= 0.0 || throw(ArgumentError("Canic Section 4.1 tfinal_s must be nonnegative"))
    section_count_value >= 2 || throw(ArgumentError("Canic Section 4.1 section_count must be at least 2"))
    radial_sample_count_value >= 2 ||
        throw(ArgumentError("Canic Section 4.1 radial_sample_count must be at least 2"))
    Float64(time_atol_s) >= 0.0 || throw(ArgumentError("Canic Section 4.1 time_atol_s must be nonnegative"))
    return CanicSection41ReplicationSpec(
        String(data_root),
        String(output_dir),
        String(report_assets_dir),
        coordinate_mode_value,
        nx_value,
        Float64(dt_s),
        Float64(tfinal_s),
        section_count_value,
        radial_sample_count_value,
        Float64(time_atol_s),
        model_values,
        publish_report_assets,
        overwrite,
    )
end

struct CanicSection41ReplicationResult
    spec::CanicSection41ReplicationSpec
    status::String
    provenance_json::String
    parameter_audit_csv::String
    comparison_csv::String
    summary_csv::String
    radial_velocity_csv::String
    figure6_diagnostics_csv::String
    parameter_audit_tex::String
    summary_tex::String
end

function canic_section41_case_records()
    sev23 = native_resolved_fsi_case_spec(:sev23)
    sev40 = native_resolved_fsi_case_spec(:sev40)
    sev50 = native_resolved_fsi_case_spec(:sev50)
    return [
        (
            case_id=:sev23,
            imported_label="77",
            paper_severity_percent=23.0,
            paper_label=sev23.paper_label,
            reduced_severity=native_resolved_fsi_reduced_geometry_severity(sev23),
            rmin_cm=sev23.rmin_cm,
            delta_r_cm=sev23.delta_r_cm,
            expected_upstream_time_s=0.9995,
        ),
        (
            case_id=:sev40,
            imported_label="60",
            paper_severity_percent=40.0,
            paper_label=sev40.paper_label,
            reduced_severity=native_resolved_fsi_reduced_geometry_severity(sev40),
            rmin_cm=sev40.rmin_cm,
            delta_r_cm=sev40.delta_r_cm,
            expected_upstream_time_s=0.9995,
        ),
        (
            case_id=:sev50,
            imported_label="50",
            paper_severity_percent=50.0,
            paper_label=sev50.paper_label,
            reduced_severity=native_resolved_fsi_reduced_geometry_severity(sev50),
            rmin_cm=sev50.rmin_cm,
            delta_r_cm=sev50.delta_r_cm,
            expected_upstream_time_s=1.4995,
        ),
    ]
end

function canic_section41_case_dir(data_root::AbstractString, imported_label::AbstractString)
    root = String(data_root)
    label = String(imported_label)
    candidates = (
        joinpath(root, label),
        joinpath(root, "case3_all_3d_results", label),
    )
    for candidate in candidates
        isdir(candidate) && return candidate
    end
    return first(candidates)
end

function canic_section41_required_files(data_root::AbstractString)
    paths = String[]
    for record in canic_section41_case_records()
        case_dir = canic_section41_case_dir(data_root, record.imported_label)
        for filename in CANIC_SECTION41_EXPECTED_FILENAMES
            push!(paths, joinpath(case_dir, filename))
        end
    end
    return paths
end

canic_section41_missing_files(data_root::AbstractString) =
    [path for path in canic_section41_required_files(data_root) if !isfile(path)]

function canic_section41_resolved_case(record, data_root::AbstractString, time_atol_s::Real)
    case_dir = canic_section41_case_dir(data_root, record.imported_label)
    velocity_xdmf = joinpath(case_dir, "velocity.xdmf")
    return Resolved3DCaseSpec(
        record.imported_label,
        record.paper_severity_percent,
        velocity_xdmf;
        pressure_xdmf=joinpath(case_dir, "pressure.xdmf"),
        displacement_xdmf=joinpath(case_dir, "displace.xdmf"),
        target_time=record.expected_upstream_time_s,
        time_atol=time_atol_s,
    )
end

function canic_section41_output_paths(output_dir::AbstractString)
    root = String(output_dir)
    return (
        provenance_json=joinpath(root, "canic-section41-provenance.json"),
        parameter_audit_csv=joinpath(root, "canic-section41-parameter-audit.csv"),
        comparison_csv=joinpath(root, "canic-section41-comparison.csv"),
        summary_csv=joinpath(root, "canic-section41-summary.csv"),
        radial_velocity_csv=joinpath(root, "canic-section41-radial-velocity.csv"),
        figure6_diagnostics_csv=joinpath(root, "canic-section41-figure6-diagnostics.csv"),
        parameter_audit_tex=joinpath(root, "canic-section41-parameter-audit.tex"),
        summary_tex=joinpath(root, "canic-section41-summary.tex"),
    )
end

function canic_section41_report_output_paths(report_assets_dir::AbstractString)
    root = String(report_assets_dir)
    return (
        data_dir=joinpath(root, "data", "canic-replication"),
        table_dir=joinpath(root, "tables", "canic-replication"),
    )
end

function canic_section41_params(record, model_name_value::AbstractString, spec::CanicSection41ReplicationSpec)
    return Params(
        nx=spec.nx,
        tfinal=spec.tfinal_s,
        dt=spec.dt_s,
        severity=record.reduced_severity,
        model=forward_model(model_name_value),
        velocity_profile=ParabolicVelocityProfile(),
        space=DGMethod(1),
        time_stepper=SSPRK3Stepper(),
        initial_condition=GeometryRestIC(),
        inlet_umax=45.0,
        rho=1.055,
        nu=0.04,
        young=5.02e6,
        wall_h=0.06,
        sigma=0.5,
    )
end

function canic_section41_pressure_observation(
    field::Resolved3DVelocityField,
    pressure_values::AbstractVector{<:Real},
    z_cm::Float64,
)
    return native_resolved_fsi_parity_pressure_section_observation(field, pressure_values, z_cm)
end

function canic_section41_radial_velocity_profile(
    uavg_cm_s::Real,
    section_radius_cm::Real,
    reference_radius_cm::Real,
    reference_radius_derivative::Real;
    rho_g_cm3::Real = 1.055,
    nu_cm2_s::Real = 0.04,
    length_cm::Real = 6.0,
    sample_count::Integer = 41,
    wall_velocity_cm_s::Real = 0.0,
)
    count = Int(sample_count)
    count >= 2 || throw(ArgumentError("radial velocity sample_count must be at least 2"))
    radius = Float64(section_radius_cm)
    radius > 0.0 || throw(ArgumentError("radial velocity section radius must be positive"))
    uavg = Float64(uavg_cm_s)
    r0 = Float64(reference_radius_cm)
    r0z = Float64(reference_radius_derivative)
    rho = Float64(rho_g_cm3)
    nu = Float64(nu_cm2_s)
    length_value = Float64(length_cm)
    wall_target = Float64(wall_velocity_cm_s)
    ur_scale = uavg * 1.5 * r0 / length_value
    uz_scale = uavg * 1.5
    re_value = rho * uavg / max(nu, eps()) * r0 * 2.0
    epsilon = max(radius * 1.0e-6, 1.0e-9)
    r_values = collect(range(epsilon, radius; length=count - 1))

    if abs(ur_scale) <= 1.0e-14 || abs(r0z) <= 1.0e-14
        return [(r_cm=0.0, radial_velocity_cm_s=0.0); [(r_cm=r, radial_velocity_cm_s=0.0) for r in r_values]]
    end

    function rhs(r, y1, y2)
        y2_value = y2
        y1_value = y1
        term = (y1_value * re_value / ur_scale - r0 / max(r, epsilon)) * y2_value
        forcing = (
            2.0 * y1_value * re_value * uz_scale / (r0 * ur_scale) * (1.0 - r^2 / radius^2) -
            4.0 * uz_scale / radius
        ) * r0z
        return y2_value, term + forcing - r0 * y1_value / max(r^2, epsilon^2)
    end

    function integrate(initial_slope)
        y1 = 0.0
        y2 = Float64(initial_slope)
        output = [(r_cm=0.0, radial_velocity_cm_s=0.0)]
        previous_r = epsilon
        for r in r_values
            h = r - previous_r
            if h > 0.0
                k1_1, k1_2 = rhs(previous_r, y1, y2)
                half_h = 0.5 * h
                k2_1, k2_2 = rhs(previous_r + half_h, y1 + half_h * k1_1, y2 + half_h * k1_2)
                k3_1, k3_2 = rhs(previous_r + half_h, y1 + half_h * k2_1, y2 + half_h * k2_2)
                k4_1, k4_2 = rhs(r, y1 + h * k3_1, y2 + h * k3_2)
                y1 += h * (k1_1 + 2.0 * k2_1 + 2.0 * k3_1 + k4_1) / 6.0
                y2 += h * (k1_2 + 2.0 * k2_2 + 2.0 * k3_2 + k4_2) / 6.0
            end
            push!(output, (r_cm=r, radial_velocity_cm_s=y1 * ur_scale))
            previous_r = r
        end
        return output
    end

    first_guess = 0.0
    second_guess = r0z == 0.0 ? 1.0 : -r0z
    first_solution = integrate(first_guess)
    second_solution = integrate(second_guess)
    first_residual = last(first_solution).radial_velocity_cm_s - wall_target
    second_residual = last(second_solution).radial_velocity_cm_s - wall_target
    slope = abs(second_residual - first_residual) > 1.0e-14 ?
            second_guess - second_residual * (second_guess - first_guess) / (second_residual - first_residual) :
            first_guess
    return integrate(slope)
end

function canic_section41_parameter_audit_rows(spec::CanicSection41ReplicationSpec)
    rows = Any[]
    push!(rows, (
        "source_url",
        "upstream",
        CANIC_2024_SOURCE_URL,
        CANIC_2024_SOURCE_URL,
        "informational",
        "upstream repository used only as optional comparator/provenance source",
    ))
    push!(rows, (
        "source_commit",
        "upstream",
        CANIC_2024_SOURCE_COMMIT,
        CANIC_2024_SOURCE_COMMIT,
        "informational",
        "pinned upstream commit for raw 3D bundles and MATLAB reference scripts",
    ))
    push!(rows, (
        "young_modulus_dyn_cm2",
        "PDF Table 1 vs upstream MATLAB Variables.m",
        "5.02e6",
        "2.0e4",
        "mismatch_requires_classification",
        "use PDF Table 1 for local Julia replication; do not treat MATLAB scripts as exact executable specification",
    ))
    for record in canic_section41_case_records()
        velocity_xdmf = joinpath(canic_section41_case_dir(spec.data_root, record.imported_label), "velocity.xdmf")
        observed_time = isfile(velocity_xdmf) ? parse_xdmf_velocity(velocity_xdmf).time : NaN
        status = isfinite(observed_time) ?
                 (abs(observed_time - CANIC_SECTION41_PAPER_TIME_S) <= spec.time_atol_s ?
                  "matches_paper_time" :
                  "source_time_differs_from_paper_text") :
                 "missing_optional_raw_input"
        push!(rows, (
            "snapshot_time_s_case$(record.imported_label)",
            "PDF Section 4.1 vs upstream XDMF",
            CANIC_SECTION41_PAPER_TIME_S,
            observed_time,
            status,
            "comparison loader uses upstream XDMF time for this case and records the paper-time offset",
        ))
        push!(rows, (
            "rmin_cm_$(record.case_id)",
            "PDF geometry",
            record.rmin_cm,
            record.rmin_cm,
            "accepted",
            "local reduced severity is chosen to reproduce the paper radius exactly",
        ))
    end
    return rows
end

function canic_section41_provenance(spec::CanicSection41ReplicationSpec)
    files = Dict{String,Any}()
    for path in canic_section41_required_files(spec.data_root)
        files[path] = isfile(path) ? Dict("sha256" => sha256_file(path), "bytes" => filesize(path)) : nothing
    end
    return Dict(
        "workflow" => "canic-2024-section-4-1-replication",
        "status" => "source-artifact replication",
        "upstream_url" => CANIC_2024_SOURCE_URL,
        "upstream_commit" => CANIC_2024_SOURCE_COMMIT,
        "upstream_license" => CANIC_2024_SOURCE_LICENSE,
        "upstream_code_policy" => "optional external comparator/provenance only; no GPL source copied into package implementation",
        "data_root" => spec.data_root,
        "coordinate_mode" => spec.coordinate_mode,
        "models" => spec.models,
        "paper_time_s" => CANIC_SECTION41_PAPER_TIME_S,
        "raw_files" => files,
    )
end

function run_canic_section41_replication(spec::CanicSection41ReplicationSpec)
    missing = canic_section41_missing_files(spec.data_root)
    if !isempty(missing)
        return nothing
    end

    paths = canic_section41_output_paths(spec.output_dir)
    section_z = collect(range(0.0, SECTION41_LENGTH_CM; length=spec.section_count))
    comparison_rows = Any[]
    summary_rows = Any[]
    radial_rows = Any[]
    figure6_rows = Any[]

    for record in canic_section41_case_records()
        resolved_case = canic_section41_resolved_case(record, spec.data_root, spec.time_atol_s)
        bundle = load_resolved3d_field_bundle(resolved_case; require_pressure=true, require_displacement=true)
        field = resolved3d_velocity_field_from_bundle(bundle, spec.coordinate_mode)
        pressure_values = native_resolved_fsi_parity_required_pressure(bundle)
        velocity_observations = Dict{Float64,Any}()
        pressure_observations = Dict{Float64,Any}()

        for z_value in section_z
            z_cm = Float64(z_value)
            velocity_observations[z_cm] = section_observation(field, z_cm, CrossSectionQuadratureOperator())
            pressure_observations[z_cm] = canic_section41_pressure_observation(field, pressure_values, z_cm)
        end

        for model_value in spec.models
            params = canic_section41_params(record, model_value, spec)
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            u1d = velocity(result)
            p1d = pressure(result, params)
            velocity_abs_errors = Float64[]
            velocity_rel_errors = Float64[]
            pressure_abs_errors = Float64[]

            for z_value in section_z
                z_cm = Float64(z_value)
                velocity_observation = velocity_observations[z_cm]
                pressure_observation = pressure_observations[z_cm]
                u_1d = interpolate_linear(result.z, u1d, z_cm)
                p_1d = interpolate_linear(result.z, p1d, z_cm)
                u_3d = velocity_observation.mean_velocity_cm_s
                p_3d = pressure_observation.mean_pressure_dyn_cm2
                velocity_abs = abs_or_nan(u_1d, u_3d)
                velocity_rel = relative_error(velocity_abs, u_3d)
                pressure_abs = abs_or_nan(p_1d, p_3d)
                isfinite(velocity_abs) && push!(velocity_abs_errors, velocity_abs)
                isfinite(velocity_rel) && push!(velocity_rel_errors, velocity_rel)
                isfinite(pressure_abs) && push!(pressure_abs_errors, pressure_abs)
                push!(comparison_rows, (
                    string(record.case_id),
                    record.paper_severity_percent,
                    record.imported_label,
                    model_value,
                    spec.coordinate_mode,
                    z_cm,
                    bundle.velocity.metadata.time,
                    bundle.velocity.metadata.time - CANIC_SECTION41_PAPER_TIME_S,
                    velocity_observation.area_cm2,
                    u_3d,
                    u_1d,
                    velocity_abs,
                    velocity_rel,
                    p_3d,
                    p_1d,
                    pressure_abs,
                    velocity_observation.intersection_count,
                    velocity_observation.cut_status,
                    pressure_observation.cut_status,
                ))
            end

            max_velocity_rel = maximum_or_nan(velocity_rel_errors)
            velocity_status = model_value == "canic-extended-1d" ?
                              "computed_paper_model_summary" :
                              "computed_established_model_comparator"
            push!(summary_rows, (
                string(record.case_id),
                record.paper_severity_percent,
                record.imported_label,
                model_value,
                spec.coordinate_mode,
                length(section_z),
                bundle.velocity.metadata.time,
                bundle.velocity.metadata.time - CANIC_SECTION41_PAPER_TIME_S,
                maximum_or_nan(velocity_abs_errors),
                mean_or_nan(velocity_abs_errors),
                max_velocity_rel,
                mean_or_nan(velocity_rel_errors),
                maximum_or_nan(pressure_abs_errors),
                mean_or_nan(pressure_abs_errors),
                velocity_status,
            ))

            throat_z = native_resolved_fsi_throat_z(native_resolved_fsi_case_spec(record.case_id))
            area_at_throat = interpolate_linear(result.z, result.area, throat_z)
            radius_at_throat = sqrt(positive_area(area_at_throat))
            uavg_at_throat = interpolate_linear(result.z, u1d, throat_z)
            r0, r0z, _ = stenosis(throat_z, params)
            radial_profile = canic_section41_radial_velocity_profile(
                uavg_at_throat,
                radius_at_throat,
                r0,
                r0z;
                rho_g_cm3=params.rho,
                nu_cm2_s=params.nu,
                length_cm=params.length_cm,
                sample_count=spec.radial_sample_count,
            )
            for sample in radial_profile
                push!(radial_rows, (
                    string(record.case_id),
                    record.paper_severity_percent,
                    model_value,
                    throat_z,
                    radius_at_throat,
                    sample.r_cm,
                    sample.radial_velocity_cm_s,
                    "postprocessed_1d_radial_velocity",
                ))
            end
        end

        speed_values = [sqrt(sum(abs2, view(field.velocity, i, :))) for i in axes(field.velocity, 1)]
        axial_values = field.velocity[:, 3]
        radial_values = [hypot(field.velocity[i, 1], field.velocity[i, 2]) for i in axes(field.velocity, 1)]
        push!(figure6_rows, (
            string(record.case_id),
            record.paper_severity_percent,
            record.imported_label,
            spec.coordinate_mode,
            bundle.velocity.metadata.time,
            maximum(speed_values),
            maximum(axial_values),
            maximum(radial_values),
            minimum(axial_values),
            "qualitative_3d_velocity_field_diagnostic",
        ))
    end

    write_json(paths.provenance_json, canic_section41_provenance(spec); overwrite=spec.overwrite)
    write_csv_table(
        paths.parameter_audit_csv,
        ("quantity", "source_pair", "paper_or_local_value", "upstream_or_observed_value", "status", "note"),
        canic_section41_parameter_audit_rows(spec);
        overwrite=spec.overwrite,
    )
    write_csv_table(
        paths.comparison_csv,
        (
            "case_id",
            "paper_severity_percent",
            "imported_case",
            "model",
            "coordinate_mode",
            "z_cm",
            "snapshot_time_s",
            "paper_time_offset_s",
            "area_cm2",
            "mean_velocity_3d_cm_s",
            "mean_velocity_1d_cm_s",
            "velocity_abs_error_cm_s",
            "velocity_rel_error",
            "mean_pressure_3d_dyn_cm2",
            "pressure_1d_dyn_cm2",
            "pressure_abs_error_dyn_cm2",
            "intersection_count",
            "velocity_cut_status",
            "pressure_cut_status",
        ),
        comparison_rows;
        overwrite=spec.overwrite,
    )
    write_csv_table(
        paths.summary_csv,
        (
            "case_id",
            "paper_severity_percent",
            "imported_case",
            "model",
            "coordinate_mode",
            "section_count",
            "snapshot_time_s",
            "paper_time_offset_s",
            "max_velocity_abs_error_cm_s",
            "mean_velocity_abs_error_cm_s",
            "max_velocity_rel_error",
            "mean_velocity_rel_error",
            "max_pressure_abs_error_dyn_cm2",
            "mean_pressure_abs_error_dyn_cm2",
            "status",
        ),
        summary_rows;
        overwrite=spec.overwrite,
    )
    write_csv_table(
        paths.radial_velocity_csv,
        (
            "case_id",
            "paper_severity_percent",
            "model",
            "z_cm",
            "section_radius_cm",
            "r_cm",
            "radial_velocity_cm_s",
            "status",
        ),
        radial_rows;
        overwrite=spec.overwrite,
    )
    write_csv_table(
        paths.figure6_diagnostics_csv,
        (
            "case_id",
            "paper_severity_percent",
            "imported_case",
            "coordinate_mode",
            "snapshot_time_s",
            "max_speed_cm_s",
            "max_axial_velocity_cm_s",
            "max_radial_speed_cm_s",
            "min_axial_velocity_cm_s",
            "status",
        ),
        figure6_rows;
        overwrite=spec.overwrite,
    )
    write_canic_section41_parameter_audit_tex(paths.parameter_audit_tex, canic_section41_parameter_audit_rows(spec); overwrite=spec.overwrite)
    write_canic_section41_summary_tex(paths.summary_tex, summary_rows; overwrite=spec.overwrite)

    if spec.publish_report_assets
        report_paths = canic_section41_report_output_paths(spec.report_assets_dir)
        publish_canic_section41_report_assets(paths, report_paths; overwrite=spec.overwrite)
    end

    return CanicSection41ReplicationResult(
        spec,
        "ok",
        paths.provenance_json,
        paths.parameter_audit_csv,
        paths.comparison_csv,
        paths.summary_csv,
        paths.radial_velocity_csv,
        paths.figure6_diagnostics_csv,
        paths.parameter_audit_tex,
        paths.summary_tex,
    )
end

function publish_canic_section41_report_assets(paths, report_paths; overwrite::Bool = false)
    data_targets = (
        paths.provenance_json,
        paths.parameter_audit_csv,
        paths.comparison_csv,
        paths.summary_csv,
        paths.radial_velocity_csv,
        paths.figure6_diagnostics_csv,
    )
    for path in data_targets
        target = joinpath(report_paths.data_dir, basename(path))
        guarded_open_write(target, overwrite) do io
            write(io, read(path, String))
        end
    end
    for path in (paths.parameter_audit_tex, paths.summary_tex)
        target = joinpath(report_paths.table_dir, basename(path))
        guarded_open_write(target, overwrite) do io
            write(io, read(path, String))
        end
    end
    return nothing
end

function tex_escape_cell(value)
    text = string(value)
    text = replace(text, "\\" => "\\textbackslash{}")
    text = replace(text, "_" => "\\_")
    text = replace(text, "%" => "\\%")
    text = replace(text, "&" => "\\&")
    return text
end

function canic_section41_status_tex_label(value)
    text = String(value)
    labels = Dict(
        "computed_paper_model_summary" => "paper-model summary",
        "computed_established_model_comparator" => "classical comparator",
        "mismatch_requires_classification" => "source mismatch",
        "source_time_differs_from_paper_text" => "snapshot-time offset",
    )
    return get(labels, text, replace(text, "_" => " "))
end

function canic_section41_pressure_tex(value)
    pressure_value = Float64(value)
    if !isfinite(pressure_value)
        return "--"
    end
    exponent = floor(Int, log10(max(abs(pressure_value), eps())))
    mantissa = pressure_value / 10.0^exponent
    return "$(round(mantissa; digits=2))\\times10^{$exponent}"
end

function write_canic_section41_parameter_audit_tex(path::String, rows; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{tabular}{lll}")
        println(io, "\\toprule")
        println(io, "Quantity & Status & Note \\\\")
        println(io, "\\midrule")
        for row in rows
            if row[5] != "accepted" && row[5] != "informational"
                println(
                    io,
                    "$(tex_escape_cell(row[1])) & $(tex_escape_cell(canic_section41_status_tex_label(row[5]))) & " *
                    "$(tex_escape_cell(row[6])) \\\\",
                )
            end
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    return path
end

function write_canic_section41_summary_tex(path::String, rows; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "\\begin{tabular}{llrrl}")
        println(io, "\\toprule")
        println(io, "Case & Model & \\(D_{u,\\max}\\) & \\(D_{p,\\max}\\) & Role \\\\")
        println(io, "\\midrule")
        for row in rows
            println(
                io,
                "$(tex_escape_cell(row[1])) & $(tex_escape_cell(row[4])) & " *
                "$(round(100.0 * row[11]; digits=2))\\% & \\($(canic_section41_pressure_tex(row[13]))\\) & " *
                "$(tex_escape_cell(canic_section41_status_tex_label(row[15]))) \\\\",
            )
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    return path
end
