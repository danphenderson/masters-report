function print_compare3d_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d [--data-root PATH] [--coordinate-mode reference|deformed] [--output-dir PATH] [--target-time SECONDS] [--time-atol SECONDS] [--case-workers N] [--solver-threads N] [--overwrite] [--publish-report-assets]
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d --nxs 200,400,800 [--data-root PATH] [--coordinate-mode reference|deformed] [--output-dir PATH] [--target-time SECONDS] [--time-atol SECONDS] [--case-workers N] [--solver-threads N] [--overwrite] [--publish-report-assets]
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d --nxs 200,400,800 --reuse-grid-summary PATH [--grid-summary-csv PATH] [--grid-summary-tex PATH] [--overwrite]
    """)
end

function run_compare3d_cli(args::Vector{String})
    values, flags = parse_cli_options(args, COMPARISON_VALUE_OPTIONS, COMPARISON_FLAG_OPTIONS)
    if "help" in flags
        print_compare3d_usage()
        return nothing
    end
    plan = compare3d_command_plan_from_values(values, flags)

    if plan.mode == :reuse_grid_sensitivity
        result = run_grid_sensitivity_from_summary_csv(plan.source_summary_csv; plan.run_kwargs...)
        println("compare_3d_grid_summary_csv,$(result.summary_csv)")
        println("compare_3d_grid_summary_tex,$(result.summary_tex)")
        if plan.publish_report_assets
            paths = publish_resolved3d_grid_sensitivity_assets(
                result;
                output_dir=plan.report_assets_dir,
                overwrite=plan.run_kwargs.overwrite,
            )
            for path in paths
                println("compare_3d_report_asset,$path")
            end
        end
        return result
    elseif plan.mode == :grid_sensitivity
        result = run_available_resolved3d_grid_sensitivity(; plan.run_kwargs...)
        if result === nothing
            println("compare_3d_status,skipped_missing_data")
            return nothing
        end
        println("compare_3d_grid_summary_csv,$(result.summary_csv)")
        println("compare_3d_grid_summary_tex,$(result.summary_tex)")
        if plan.publish_report_assets
            paths = publish_resolved3d_grid_sensitivity_assets(
                result;
                output_dir=plan.report_assets_dir,
                overwrite=plan.run_kwargs.overwrite,
            )
            for path in paths
                println("compare_3d_report_asset,$path")
            end
        end
        return result
    end

    result = run_available_resolved3d_comparison(; plan.run_kwargs...)
    if result === nothing
        println("compare_3d_status,skipped_missing_data")
        return nothing
    end
    println("compare_3d_summary_csv,$(result.summary_csv)")
    println("compare_3d_sensitivity_csv,$(result.sensitivity_csv)")
    if plan.publish_report_assets
        paths = publish_resolved3d_report_assets(
            result;
            output_dir=plan.report_assets_dir,
            overwrite=plan.run_kwargs.overwrite,
        )
        for path in paths
            println("compare_3d_report_asset,$path")
        end
    end
    return result
end
