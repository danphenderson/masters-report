#!/usr/bin/env julia

# Backward-compatible entrypoint. The implementation lives in
# simulations/canic_extended_1d/.

include(joinpath(@__DIR__, "canic_extended_1d", "CanicExtended1D.jl"))
using .CanicExtended1D

CanicExtended1D.run_cli(ARGS)
