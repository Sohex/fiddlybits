# Parsed by test/nightly/runtests.jl and never run: an @inbounds in host code, beside a
# kernel that carries none.

using KernelAbstractions: @kernel, @index, @Const

@kernel function copy_kernel!(out, @Const(xs))
    i = @index(Global)
    out[i] = xs[i]
end

function first_element(v)
    @inbounds return v[1]
end
