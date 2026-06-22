function run_export_assets_cli(args::Vector{String})
    opts = parse_export_args(args)
    opts === nothing && return nothing
    return export_stenosis_geometry_figures(opts)
end
