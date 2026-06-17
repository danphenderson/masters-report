#!/usr/bin/env julia

include(joinpath(@__DIR__, "canic_extended_1d", "CanicExtended1D.jl"))
using .CanicExtended1D

CanicExtended1D.run_cli(ARGS)
