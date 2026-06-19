telemetry_start_ns() = time_ns()

telemetry_elapsed_s(start_ns::UInt64) = round((time_ns() - start_ns) / 1.0e9; digits=6)

macro telemetry_info(message, kwargs...)
    return esc(:(@info $message $(kwargs...)))
end

macro telemetry_warn(message, kwargs...)
    return esc(:(@warn $message $(kwargs...)))
end

macro telemetry_error(message, kwargs...)
    return esc(:(@error $message $(kwargs...)))
end
