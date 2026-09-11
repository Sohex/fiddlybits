module Kernels

@noinline nofuse_mul(a, b) = a * b

@kernel function axpy_bitwise_kernel!(y, a, @Const(x))
    i = @index(Global)
    y[i] = fma(a, x[i], y[i])
end

@kernel function axpy_fused_kernel!(y, a, @Const(x))
    i = @index(Global)
    y[i] = a * x[i] + y[i]
end

function axpy_reference!(y, a, x)
    for i in eachindex(y, x)
        y[i] = a * x[i] + y[i]
    end
    return y
end

@kernel function stencil_gather_bitwise_kernel!(out, @Const(in), @Const(weight), nk)
    i = @index(Global)
    acc = zero(eltype(out))
    for k in 1:nk
        acc = fma(in[k, i], weight[k, i], acc)
    end
    out[i] = acc
end

@kernel function stencil_gather_fused_kernel!(out, @Const(in), @Const(weight), nk)
    i = @index(Global)
    acc = zero(eltype(out))
    for k in 1:nk
        acc += in[k, i] * weight[k, i]
    end
    out[i] = acc
end

function stencil_gather_reference!(out, in, weight, nk)
    for i in eachindex(out)
        acc = zero(eltype(out))
        for k in 1:nk
            acc += in[k, i] * weight[k, i]
        end
        out[i] = acc
    end
    return out
end

"""
    compensated(a, b, c)

The product rounded on its own and then added. The text `muladd(a, b, c)` and
the text `a * b + c` stand in this docstring and are not calls.
"""
compensated(a, b, c) = nofuse_mul(a, b) + c

"""
    scale_shift!(y, x)

`y` set to `2 * x + y` at every element over a declared `Float64`, written as
`fma`. The counterpart in the dirty fixture writes the same shape as a bare
multiply and a bare add.
"""
function scale_shift!(y::Vector{Float64}, x::Vector{Float64})
    for i in eachindex(y, x)
        y[i] = fma(2.0, x[i], y[i])
    end
    return y
end

end
