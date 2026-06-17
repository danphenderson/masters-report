#!/bin/sh
#=
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
exec "$PROJECT_ROOT/scripts/julia-release" "$0" "$@"
=#

if VERSION < v"1.12"
    error("simulations/run_canic_extended_1d.jl requires Julia 1.12 or newer.")
end

include(joinpath(@__DIR__, "canic_extended_1d", "CanicExtended1D.jl"))
using .CanicExtended1D

CanicExtended1D.run_cli(ARGS)
