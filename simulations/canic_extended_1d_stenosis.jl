#!/bin/sh
#=
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
exec "$PROJECT_ROOT/scripts/julia-release" "$0" "$@"
=#

# Backward-compatible entrypoint. The implementation lives in
# simulations/canic_extended_1d/.

if VERSION < v"1.12"
    error("simulations/canic_extended_1d_stenosis.jl requires Julia 1.12 or newer.")
end

include(joinpath(@__DIR__, "canic_extended_1d", "CanicExtended1D.jl"))
using .CanicExtended1D

CanicExtended1D.run_cli(ARGS)
