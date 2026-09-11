module Kernels

@noinline nofuse_mul(a, b) = a * b

@kernel function axpy_bitwise_kernel!(y, a, @Const(x))
    i = @index(Global)
    y[i] = a * x[i] + y[i]
end

@kernel function stencil_gather_bitwise_kernel!(out, @Const(in), @Const(weight), nk)
    i = @index(Global)
    acc = zero(eltype(out))
    for k in 1:nk
        acc += in[k, i] * weight[k, i]
    end
    out[i] = acc
end

@inline horner(z, c) = muladd(horner(z, Base.tail(c)), z, c[1])

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
    scale_shift!(y, x)

`y` set to `2 * x + y` at every element over a declared `Float64`, with an
integer literal as the multiply's first operand.
"""
function scale_shift!(y::Vector{Float64}, x::Vector{Float64})
    for i in eachindex(y, x)
        y[i] = 2 * x[i] + y[i]
    end
    return y
end

end
