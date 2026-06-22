import DelimitedFiles: readdlm

function FlowWaveformInlet(path::AbstractString; flow_scale::Real = 1.0)
    data = readdlm(path)
    values = Float64.(data)

    if ndims(values) != 2 || isempty(values)
        throw(ArgumentError("inlet file '$path' must contain numeric time/flow samples"))
    elseif size(values, 2) == 2
        times = values[:, 1]
        flows = values[:, 2]
    else
        flat = vec(values)
        iseven(length(flat)) ||
            throw(ArgumentError("inlet file '$path' must contain pairs of time and flow values"))
        times = flat[1:2:end]
        flows = flat[2:2:end]
    end

    return FlowWaveformInlet(times, Float64(flow_scale) .* flows; source_path=path)
end
