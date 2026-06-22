function print_operator_validation_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics operator-validation [--output-dir PATH] [--summary-csv PATH] [--summary-tex PATH] [--sample-z LIST] [--plane-center CM] [--plane-shifts LIST] [--constant-value CM_PER_S] [--affine-coefficients C0,CX,CY,CZ] [--tolerance VALUE] [--overwrite]
    """)
end

function run_operator_validation_cli(args::Vector{String})
    values, flags = parse_cli_options(args, OPERATOR_VALIDATION_VALUE_OPTIONS, OPERATOR_VALIDATION_FLAG_OPTIONS)
    if "help" in flags
        print_operator_validation_usage()
        return nothing
    end
    spec = operator_validation_spec_from_values(values, flags)
    result = run_operator_validation(spec)
    println("operator_validation_csv,$(result.summary_csv)")
    println("operator_validation_tex,$(result.summary_tex)")
    return result
end
