abstract type AbstractWallLaw end

"""
    CanicKoiterWallLaw()

Koiter thin-membrane elastic wall law used by the Canic extended 1D
stenotic-artery model. The conservative solver uses the paper's constant
reference-radius convention with R0* = rmax.
"""
struct CanicKoiterWallLaw <: AbstractWallLaw end

wall_law_name(::CanicKoiterWallLaw) = "canic-koiter-thin-membrane"
wall_law_path_token(wall_law::AbstractWallLaw) = replace(wall_law_name(wall_law), "-" => "_")

validate(::CanicKoiterWallLaw) = nothing
