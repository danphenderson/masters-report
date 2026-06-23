function native_resolved_fsi_web_export_manifest_path(spec::NativeResolvedFSIWebExportSpec)
    return joinpath(spec.output_dir, "manifest.json")
end

function web_export_relative(path::String, root::String)
    return relpath(path, root)
end

function web_export_asset_descriptor(path::String, root::String)
    return Dict{String,Any}(
        "path" => web_export_relative(path, root),
        "byte_size" => filesize(path),
        "sha256" => sha256_file(path),
    )
end

function write_web_export_binary(path::String, values; overwrite::Bool)
    guarded_open_write(path, overwrite) do io
        write(io, values)
    end
    return path
end

function web_export_row_major_f32(matrix)
    values = Vector{Float32}(undef, size(matrix, 1) * size(matrix, 2))
    cursor = 1
    for i in axes(matrix, 1), j in axes(matrix, 2)
        values[cursor] = Float32(matrix[i, j])
        cursor += 1
    end
    return values
end

function web_export_vector_f32(values)
    out = Vector{Float32}(undef, length(values))
    for i in eachindex(values)
        out[i] = Float32(values[i])
    end
    return out
end

function web_export_row_major_zero_based_u32(matrix)
    values = Vector{UInt32}(undef, size(matrix, 1) * size(matrix, 2))
    cursor = 1
    for i in axes(matrix, 1), j in axes(matrix, 2)
        value = Int(matrix[i, j])
        value >= 1 || throw(ArgumentError("web export topology indices must be one-based before writing"))
        values[cursor] = UInt32(value - 1)
        cursor += 1
    end
    return values
end

function web_export_range(values)
    finite_values = Float64[Float64(value) for value in values if isfinite(value)]
    isempty(finite_values) && return Dict{String,Any}("min" => nothing, "max" => nothing)
    return Dict{String,Any}("min" => minimum(finite_values), "max" => maximum(finite_values))
end

function web_export_merge_ranges(ranges)
    mins = Float64[]
    maxes = Float64[]
    for range in ranges
        range isa AbstractDict || continue
        min_value = get(range, "min", nothing)
        max_value = get(range, "max", nothing)
        min_value === nothing || push!(mins, Float64(min_value))
        max_value === nothing || push!(maxes, Float64(max_value))
    end
    if isempty(mins) || isempty(maxes)
        return Dict{String,Any}("min" => nothing, "max" => nothing)
    end
    return Dict{String,Any}("min" => minimum(mins), "max" => maximum(maxes))
end

function web_export_speed(velocity::Matrix{Float64})
    speeds = Vector{Float64}(undef, size(velocity, 1))
    for i in axes(velocity, 1)
        speeds[i] = sqrt(velocity[i, 1]^2 + velocity[i, 2]^2 + velocity[i, 3]^2)
    end
    return speeds
end

function web_export_displacement_magnitude(displacement::Union{Nothing,Matrix{Float64}})
    displacement === nothing && return Float64[]
    magnitudes = Vector{Float64}(undef, size(displacement, 1))
    for i in axes(displacement, 1)
        magnitudes[i] = sqrt(displacement[i, 1]^2 + displacement[i, 2]^2 + displacement[i, 3]^2)
    end
    return magnitudes
end

function native_resolved_fsi_surface_triangles(topology::Matrix{Int})
    counts = Dict{NTuple{3,Int},Int}()
    for cell in axes(topology, 1)
        a, b, c, d = topology[cell, 1], topology[cell, 2], topology[cell, 3], topology[cell, 4]
        for face in ((a, b, c), (a, b, d), (a, c, d), (b, c, d))
            key = Tuple(sort!(collect(face)))
            counts[key] = get(counts, key, 0) + 1
        end
    end
    surface_faces = sort!([face for (face, count) in counts if count == 1])
    triangles = Matrix{Int}(undef, length(surface_faces), 3)
    for (i, face) in enumerate(surface_faces)
        triangles[i, 1] = face[1]
        triangles[i, 2] = face[2]
        triangles[i, 3] = face[3]
    end
    return triangles
end

function web_export_frame_id(index::Int)
    index >= 1 || throw(ArgumentError("web export frame index must be one-based"))
    return "t" * lpad(string(index - 1), 4, "0")
end

function web_export_snapshot_token_time(source_id::String, fallback::Float64)
    startswith(source_id, "snapshot-t") || return fallback
    token = replace(source_id[length("snapshot-t") + 1:end], "em" => "e-", "p" => ".")
    return try
        Float64(parse(Float64, token))
    catch
        fallback
    end
end

function web_export_resolve_source_path(path::String, root::String)
    isempty(path) && return path
    isabspath(path) && return path
    return normpath(joinpath(root, path))
end

function web_export_mapping_value(mapping, key::String, default = nothing)
    mapping isa AbstractDict || return default
    haskey(mapping, key) && return mapping[key]
    symbol_key = Symbol(key)
    haskey(mapping, symbol_key) && return mapping[symbol_key]
    return default
end

function web_export_float(value, fallback::Float64)
    value === nothing && return fallback
    return value isa AbstractString ? parse(Float64, value) : Float64(value)
end

function web_export_simple_csv_rows(path::String)
    isfile(path) || return Vector{Dict{String,String}}()
    lines = readlines(path)
    isempty(lines) && return Vector{Dict{String,String}}()
    header = split(lines[1], ",")
    rows = Dict{String,String}[]
    for line in lines[2:end]
        isempty(strip(line)) && continue
        values = split(line, ",")
        row = Dict{String,String}()
        for (index, key) in enumerate(header)
            row[key] = index <= length(values) ? values[index] : ""
        end
        push!(rows, row)
    end
    return rows
end

function copy_web_export_json_sidecar(
    output_path::String,
    source_path::String,
    label::String;
    overwrite::Bool,
)
    isempty(source_path) && return nothing
    isfile(source_path) || return Dict{String,Any}(
        "label" => label,
        "status" => "missing",
        "source_path" => source_path,
    )
    text = read(source_path, String)
    guarded_open_write(output_path, overwrite) do io
        write(io, text)
    end
    return merge(
        Dict{String,Any}("label" => label, "status" => "copied", "source_path" => source_path),
        web_export_asset_descriptor(output_path, dirname(dirname(output_path))),
    )
end

function copy_web_export_text_table_as_json(
    output_path::String,
    source_path::String,
    label::String;
    overwrite::Bool,
)
    isempty(source_path) && return nothing
    isfile(source_path) || return Dict{String,Any}(
        "label" => label,
        "status" => "missing",
        "source_path" => source_path,
    )
    lines = readlines(source_path)
    write_json(output_path, Dict{String,Any}(
        "label" => label,
        "source_path" => source_path,
        "format" => "csv-lines",
        "lines" => lines,
    ); overwrite=overwrite)
    return merge(
        Dict{String,Any}("label" => label, "status" => "copied", "source_path" => source_path),
        web_export_asset_descriptor(output_path, dirname(dirname(output_path))),
    )
end
