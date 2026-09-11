module Backends

@kernel function shift!(dst, src)
    i = @index(Global)
    dst[i] = src[i - 1]
end

end
