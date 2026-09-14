# Parsed by test/nightly/runtests.jl and never run: an @inbounds inside a kernel body,
# in a plain @kernel and in one generated through @eval, and none in host code.

using KernelAbstractions: @kernel, @index, @Const

@kernel function copy_kernel!(out, @Const(xs))
    i = @index(Global)
    @inbounds out[i] = xs[i]
end

for name in (:copy_again!,)
    @eval @kernel function $name(out, @Const(xs))
        i = @index(Global)
        @inbounds for j in 1:1
            out[i] = xs[i]
        end
    end
end
