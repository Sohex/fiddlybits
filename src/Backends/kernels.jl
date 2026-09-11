# The reference kernels this module carries for its own tests: docs/plans/
# fiddlybits-52v.7-kernels.md, section "The device layer", and decision 0027.

using ..Verdicts: refuse
using KernelAbstractions: @kernel, @index, @Const

"""
    nofuse_mul(a, b)

`a * b`, returned through a call the compiler may not inline. Bitwise mode
(decision 0029) routes every multiply that feeds an add through this
function; the fused kernels below do not.
"""
@noinline nofuse_mul(a, b) = a * b

"""
    axpy_fused_kernel!(y, a, x)
    axpy_bitwise_kernel!(y, a, x)

`y[i] = a * x[i] + y[i]` at global index `i`. The fused form may compile to
one rounding step on the GPU; the bitwise form never does.
"""
@kernel function axpy_fused_kernel!(y, a, @Const(x))
    i = @index(Global)
    y[i] = a * x[i] + y[i]
end

@kernel function axpy_bitwise_kernel!(y, a, @Const(x))
    i = @index(Global)
    y[i] = nofuse_mul(a, x[i]) + y[i]
end

"""
    axpy!(y, a, x, backend)

`y[i] = a * x[i] + y[i]` for every `i`, launched on `backend` at the kernel
`backend`'s bitwise mode (decision 0029) selects. Refuses when `y` and `x`
differ in length.
"""
function axpy!(y::AbstractVector, a::Real, x::AbstractVector, backend::Backend)
    n = length(y)
    n == length(x) ||
        refuse("axpy extent", "Backends.axpy!", "y has length $n, x has length $(length(x))")
    kernel = bitwise(backend) ? axpy_bitwise_kernel! : axpy_fused_kernel!
    launch!(kernel, backend, n, y, eltype(y)(a), x)
    return y
end

"""
    axpy_reference!(y, a, x)

The naive serial reference for `axpy!` (decision 0027): the same update, one
cell at a time in index order, with no fusion barrier of its own.
"""
function axpy_reference!(y::AbstractVector, a::Real, x::AbstractVector)
    for i in eachindex(y, x)
        y[i] = a * x[i] + y[i]
    end
    return y
end

"""
    stencil_gather_fused_kernel!(out, in, neighbour, weight, nk)
    stencil_gather_bitwise_kernel!(out, in, neighbour, weight, nk)

`out[i]` the fixed-order sum over `k` in `1:nk` of
`in[neighbour[k, i]] * weight[k, i]`. The fused form may compile to one
rounding step per term on the GPU; the bitwise form never does.
"""
@kernel function stencil_gather_fused_kernel!(out, @Const(in), @Const(neighbour), @Const(weight), nk)
    i = @index(Global)
    acc = zero(eltype(out))
    for k in 1:nk
        acc += in[neighbour[k, i]] * weight[k, i]
    end
    out[i] = acc
end

@kernel function stencil_gather_bitwise_kernel!(out, @Const(in), @Const(neighbour), @Const(weight), nk)
    i = @index(Global)
    acc = zero(eltype(out))
    for k in 1:nk
        acc += nofuse_mul(in[neighbour[k, i]], weight[k, i])
    end
    out[i] = acc
end

"""
    stencil_gather!(out, in, neighbour, weight, backend)

`out[i]` the fixed-order weighted sum of `in` at the cells `neighbour[:, i]`
names, launched on `backend` at the kernel `backend`'s bitwise mode (decision
0029) selects. `neighbour` and `weight` are shaped `nk` by `length(out)`.
Refuses when `neighbour` and `weight` are not shaped alike or not sized to
`out`.
"""
function stencil_gather!(out::AbstractVector, in::AbstractVector,
                          neighbour::AbstractMatrix, weight::AbstractMatrix, backend::Backend)
    n = length(out)
    size(neighbour) == size(weight) ||
        refuse("stencil gather shape", "Backends.stencil_gather!",
               "neighbour is $(size(neighbour)), weight is $(size(weight))")
    size(neighbour, 2) == n ||
        refuse("stencil gather extent", "Backends.stencil_gather!",
               "out has length $n, neighbour has $(size(neighbour, 2)) columns")
    kernel = bitwise(backend) ? stencil_gather_bitwise_kernel! : stencil_gather_fused_kernel!
    launch!(kernel, backend, n, out, in, neighbour, weight, size(neighbour, 1))
    return out
end

"""
    stencil_gather_reference!(out, in, neighbour, weight)

The naive serial reference for `stencil_gather!` (decision 0027): the same
sum, one cell and one neighbour at a time in index order, with no fusion
barrier of its own.
"""
function stencil_gather_reference!(out::AbstractVector, in::AbstractVector,
                                    neighbour::AbstractMatrix, weight::AbstractMatrix)
    nk = size(neighbour, 1)
    for i in axes(out, 1)
        acc = zero(eltype(out))
        for k in 1:nk
            acc += in[neighbour[k, i]] * weight[k, i]
        end
        out[i] = acc
    end
    return out
end
