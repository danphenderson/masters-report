#!/usr/bin/env julia

if VERSION < v"1.12"
    error("scripts/stenosis-hemodynamics.jl requires Julia 1.12 or newer.")
end

using StenosisHemodynamics

StenosisHemodynamics.run_cli(ARGS)
