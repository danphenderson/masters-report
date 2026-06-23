function report_case_token(severity::Real)
    return "severity$(round(Int, severity))"
end

function report_case_label_tex(severity::Real)
    return "$(round(Int, severity))\\% stenosis"
end

function report_case_percent_tex(severity::Real)
    return "$(round(Int, severity))\\%"
end

function report_coordinate_mode(result::ComparisonResult)
    mode = replace(lowercase(strip(String(result.spec.coordinate_mode))), "_" => "-")
    mode in ("reference", "deformed") || throw(ArgumentError("unsupported report coordinate mode '$mode'"))
    return mode
end

function report_slice_token(z::Real)
    return replace(string(round(Float64(z); digits=3)), "." => "p", "-" => "m")
end

function report_fmt(value)
    value isa Bool && return value ? "true" : "false"
    value isa Integer && return string(value)
    value isa Real || return string(value)
    number = Float64(value)
    isfinite(number) || return "nan"
    return string(round(number; sigdigits=12))
end

minimum_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : minimum(values)
median_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : median(values)
