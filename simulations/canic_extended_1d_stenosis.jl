#!/bin/sh
#=
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
exec "$PROJECT_ROOT/scripts/julia-release" "$0" "$@"
=#

# Backward-compatible entrypoint. The implementation lives in
# the CanicExtended1D package loaded from this repository project.

if VERSION < v"1.12"
    error("simulations/canic_extended_1d_stenosis.jl requires Julia 1.12 or newer.")
end

using CanicExtended1D

CanicExtended1D.run_cli(ARGS)
