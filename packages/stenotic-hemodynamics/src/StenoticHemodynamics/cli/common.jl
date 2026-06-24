const VALUE_OPTIONS = Set([
    "model",
    "severity",
    "nx",
    "tfinal",
    "dt",
    "cfl",
    "space",
    "degree",
    "limiter",
    "time-stepper",
    "ic",
    "ic-pressure-drop-pa",
    "ic-pressure-drop-dyn-cm2",
    "ic-mesh-nz",
    "ic-mesh-nr",
    "ic-mesh-ntheta",
    "ic-diagnostics",
    "velocity-profile",
    "profile-exponent",
    "profile-shear-factor",
    "alpha",
    "nu",
    "rheology",
    "eta0",
    "eta-inf",
    "lambda-s",
    "yasuda-a",
    "flow-index",
    "yield-stress",
    "plastic-viscosity",
    "consistency",
    "min-eta",
    "max-eta",
    "shear-floor",
    "young",
    "inlet-umax",
    "backend",
    "alg",
    "abstol",
    "reltol",
    "maxiters",
    "output",
    "svg",
    "progress-every",
])

const FLAG_OPTIONS = Set([
    "help",
    "no-svg",
    "overwrite",
    "save-everystep",
])

const BENCHMARK_VALUE_OPTIONS = Set(["profile", "output-dir", "progress-every"])
const BENCHMARK_FLAG_OPTIONS = Set(["help", "overwrite", "include-resolved3d", "publish-report-assets"])

const OPENBF_VALUE_OPTIONS = Set(["config"])
const OPENBF_FLAG_OPTIONS = Set(["help", "verbose", "out-files", "save-stats"])

const STUDY_VALUE_OPTIONS = union(VALUE_OPTIONS, Set([
    "severities",
    "nxs",
    "degrees",
    "meshes",
    "output-dir",
    "summary-csv",
    "parallel-workers",
    "pressure-drop-pa",
]))
const STUDY_FLAG_OPTIONS = union(FLAG_OPTIONS, Set(["overwrite"]))

const FSI_VALUE_OPTIONS = union(STUDY_VALUE_OPTIONS, Set([
    "case-id",
    "mesh",
    "snapshot-times",
    "output-root",
    "imported-data-root",
    "inlet-outlet-boundary-mode",
    "wall-mode",
    "max-coupling-iters",
    "coupling-tolerance-cm",
    "damping",
    "reference-radius-cm",
    "history-stride",
    "wall-density",
    "wall-dt",
    "wall-tfinal",
    "manifest-json",
    "summary-tex",
    "report-assets-dir",
    "status-every",
]))
const FSI_FLAG_OPTIONS = union(STUDY_FLAG_OPTIONS, Set([
    "overwrite",
    "publish-report-assets",
    "allow-many-snapshots",
    "allow-large-output",
]))

const VERIFY_VALUE_OPTIONS = union(VALUE_OPTIONS, Set([
    "degrees",
    "h-degree",
    "h-nxs",
    "nxs",
    "p-nx",
    "dt-values",
    "elapsed-times",
    "severities",
    "output-dir",
    "summary-csv",
    "summary-tex",
]))
const VERIFY_FLAG_OPTIONS = union(FLAG_OPTIONS, Set(["overwrite", "disable-dg-limiter"]))

const COMPARISON_VALUE_OPTIONS = union(VALUE_OPTIONS, Set([
    "data-root",
    "output-dir",
    "target-time",
    "time-atol",
    "nxs",
    "reuse-grid-summary",
    "section-count",
    "radial-bins",
    "radial-bin-counts",
    "radial-radius-modes",
    "coordinate-mode",
    "profile-slices",
    "node-slab-half-widths",
    "grid-summary-csv",
    "grid-summary-tex",
    "report-assets-dir",
]))
const COMPARISON_FLAG_OPTIONS = union(FLAG_OPTIONS, Set(["overwrite", "publish-report-assets"]))

const OPERATOR_VALIDATION_VALUE_OPTIONS = Set([
    "output-dir",
    "summary-csv",
    "summary-tex",
    "sample-z",
    "plane-center",
    "plane-shifts",
    "constant-value",
    "affine-coefficients",
    "tolerance",
])
const OPERATOR_VALIDATION_FLAG_OPTIONS = Set(["help", "overwrite"])

const VISUALIZATION_VALUE_OPTIONS = Set([
    "schema-version",
    "input-production-dir",
    "velocity-xdmf",
    "pressure-xdmf",
    "displacement-xdmf",
    "output-dir",
    "case-id",
    "target-time",
    "time-atol",
    "coordinate-mode",
    "geometry-mode",
    "diagnostics-csv",
    "restart-metadata-json",
    "observations-csv",
    "observation-summary-csv",
    "batch-benchmark-json",
    "snapshot-include",
    "snapshot-exclude",
    "snapshot-stride",
    "max-snapshots",
])
const VISUALIZATION_FLAG_OPTIONS = Set([
    "help",
    "overwrite",
    "include-tetra-debug",
    "no-observations",
    "no-derived",
    "allow-velocity-only",
])

function require_value(args::Vector{String}, i::Int, key::String)
    i < length(args) || error("missing value for --$key")
    return args[i + 1]
end

function parse_cli_options(args::Vector{String}, value_options::Set{String}, flag_options::Set{String})
    values = Dict{String,String}()
    flags = Set{String}()
    i = 1

    while i <= length(args)
        arg = args[i]
        if arg == "--help" || arg == "-h"
            push!(flags, "help")
            i += 1
        elseif startswith(arg, "--")
            raw_key = arg[3:end]
            if occursin("=", raw_key)
                key, value = split(raw_key, "=", limit=2)
                if key in flag_options
                    error("--$key does not accept a value")
                elseif key in value_options
                    values[key] = value
                    i += 1
                else
                    error("unknown option --$key")
                end
            else
                key = raw_key
                if key in flag_options
                    push!(flags, key)
                    i += 1
                elseif key in value_options
                    values[key] = require_value(args, i, key)
                    i += 2
                else
                    error("unknown option --$key")
                end
            end
        else
            error("unexpected argument: $arg")
        end
    end

    return values, flags
end
