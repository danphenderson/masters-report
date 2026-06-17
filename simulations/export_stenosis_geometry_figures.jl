#!/bin/sh
#=
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
exec "$PROJECT_ROOT/scripts/julia-release" "$0" "$@"
=#

if VERSION < v"1.12"
    error(
        "simulations/export_stenosis_geometry_figures.jl requires Julia 1.12 or newer. " *
        "Run it with ./scripts/julia-release simulations/export_stenosis_geometry_figures.jl ...",
    )
end

using CanicExtended1D

opts = CanicExtended1D.parse_export_args(ARGS)
opts === nothing || export_stenosis_geometry_figures(opts)
