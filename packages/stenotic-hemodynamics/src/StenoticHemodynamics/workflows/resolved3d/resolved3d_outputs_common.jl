function report_case_token(severity::Real)
    return "severity$(round(Int, severity))"
end

function report_case_label_tex(severity::Real)
    return "$(round(Int, severity))\\% stenosis"
end

function report_percent_text(severity::Real; digits::Int = 2)
    rounded = round(Float64(severity); digits=digits)
    text = string(rounded)
    if !occursin(".", text)
        return text * "." * repeat("0", digits)
    end
    whole, fractional = split(text, "."; limit=2)
    if length(fractional) >= digits
        return text
    end
    return whole * "." * fractional * repeat("0", digits - length(fractional))
end

function report_case_label_tex(case_label::AbstractString, severity::Real)
    if string(case_label) == "77" && !isapprox(Float64(severity), 23.0; rtol=0.0, atol=1.0e-9)
        return "C23 ($(report_percent_text(severity))\\%)"
    end
    return report_case_label_tex(severity)
end

function report_case_dat_label(case_label::AbstractString, severity::Real)
    if string(case_label) == "77" && !isapprox(Float64(severity), 23.0; rtol=0.0, atol=1.0e-9)
        return "C23($(report_percent_text(severity))\\%)"
    end
    return report_case_percent_tex(severity)
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
