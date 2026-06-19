"""
    ensure_parent(path)

Create the parent directory for `path` when it is non-empty and absent.
"""
function ensure_parent(path::String)
    dir = dirname(path)
    if !isempty(dir) && !isdir(dir)
        mkpath(dir)
    end
    return path
end

"""
    guarded_open_write(path, overwrite) do io

Open `path` for writing after creating its parent directory. Existing files are
rejected unless `overwrite=true`.
"""
function guarded_open_write(writer, path::String, overwrite::Bool)
    ensure_parent(path)
    if isfile(path) && !overwrite
        throw(ArgumentError("refusing to overwrite existing file '$path'; pass overwrite=true to allow replacement"))
    end
    open(path, "w") do io
        writer(io)
    end
    return path
end

"""
    csv_cell(value; real_formatter=nothing)

Return `value` encoded as one RFC-4180-style CSV cell. `nothing` is encoded as
an empty cell, and optional `real_formatter` customizes numeric formatting.
"""
function csv_cell(value; real_formatter = nothing)
    if value === nothing
        return ""
    end
    text = real_formatter !== nothing && value isa Real && !(value isa Bool) ? real_formatter(value) : string(value)
    if any(occursin.(["\"", ",", "\n", "\r"], Ref(text)))
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

"""
    csv_record(values; real_formatter=nothing)

Encode an iterable of values as a single comma-separated CSV record.
"""
function csv_record(values; real_formatter = nothing)
    return join((csv_cell(value; real_formatter=real_formatter) for value in values), ",")
end

"""
    write_csv_table(path, header, rows; overwrite=true, pad_rows=false, real_formatter=nothing)

Write a CSV table with a header row and iterable data rows. When `pad_rows=true`,
rows are padded or truncated to the header length.
"""
function write_csv_table(
    path::String,
    header,
    rows;
    overwrite::Bool = true,
    pad_rows::Bool = false,
    real_formatter = nothing,
)
    header_values = collect(header)
    guarded_open_write(path, overwrite) do io
        println(io, csv_record(header_values; real_formatter=real_formatter))
        for row in rows
            row_values = collect(row)
            if pad_rows
                row_values =
                    length(row_values) < length(header_values) ?
                    vcat(row_values, fill("", length(header_values) - length(row_values))) :
                    row_values[1:length(header_values)]
            end
            println(io, csv_record(row_values; real_formatter=real_formatter))
        end
    end
    return path
end

"""
    write_json(path, value; overwrite=true)
    write_json(io, value, indent=0)

Write simple JSON for dictionaries, vectors, booleans, finite numbers, strings,
and `nothing`, without adding an external dependency.
"""
function write_json(path::String, value; overwrite::Bool = true)
    guarded_open_write(path, overwrite) do io
        write_json(io, value, 0)
        write(io, "\n")
    end
    return path
end

function write_json(io, value, indent::Int = 0)
    pad = repeat(" ", indent)
    if value isa AbstractDict
        write(io, "{")
        first = true
        for key in sort!(collect(keys(value)); by=string)
            first || write(io, ",")
            write(io, "\n", repeat(" ", indent + 2), json_string(string(key)), ": ")
            write_json(io, value[key], indent + 2)
            first = false
        end
        write(io, "\n", pad, "}")
    elseif value isa AbstractVector
        write(io, "[")
        for (i, item) in enumerate(value)
            i == 1 || write(io, ", ")
            write_json(io, item, indent)
        end
        write(io, "]")
    elseif value isa Bool
        write(io, value ? "true" : "false")
    elseif value isa Number
        if isfinite(float(value))
            write(io, string(value))
        else
            write(io, "null")
        end
    elseif value === nothing
        write(io, "null")
    else
        write(io, json_string(string(value)))
    end
end

"""
    json_string(text)

Return `text` as a JSON string literal.
"""
function json_string(text::String)
    escaped = replace(text, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t")
    return "\"" * escaped * "\""
end

"""
    sha256_file(path)

Return the SHA-256 digest of `path` as lowercase hexadecimal text.
"""
function sha256_file(path::String)
    open(path, "r") do io
        return bytes2hex(sha256(io))
    end
end
