module Backends

@kernel function copy!(dst, src)
    i = @index(Global)
    dst[i] = src[i]
end

end
