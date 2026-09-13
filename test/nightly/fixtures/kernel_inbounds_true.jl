# Parsed by test/nightly/runtests.jl and never run: a kernel given inbounds=true, with no
# @inbounds anywhere.

using KernelAbstractions: @kernel, @index, @Const

@kernel inbounds=true function copy_kernel!(out, @Const(xs))
    i = @index(Global)
    out[i] = xs[i]
end
