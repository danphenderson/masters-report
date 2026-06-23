using Printf

function observed_order_ratio(error_coarse::Float64, error_fine::Float64, ratio::Float64)
    isfinite(error_coarse) && isfinite(error_fine) && isfinite(ratio) || return NaN
    error_coarse > 0.0 && error_fine > 0.0 && ratio > 1.0 || return NaN
    return log(error_coarse / error_fine) / log(ratio)
end
