#!/usr/bin/env julia

if VERSION < v"1.12"
    error("packages/stenotic-hemodynamics/bin/stenotic-hemodynamics.jl requires Julia 1.12 or newer.")
end

using StenoticHemodynamics

StenoticHemodynamics.run_cli(ARGS)
