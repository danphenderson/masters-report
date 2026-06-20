#!/usr/bin/env julia

repo_root = normpath(joinpath(@__DIR__, ".."))
pushfirst!(LOAD_PATH, joinpath(repo_root, "julia"))
script = joinpath(repo_root, "julia", "bin", "stenosis-hemodynamics.jl")
include(script)
