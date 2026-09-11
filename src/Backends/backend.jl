# The device layer: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer".

using ..Verdicts: refuse
import KernelAbstractions
import CUDA

"""
    Backend

The device a kernel runs on (decision 0011). `CPU` and `GPU` are the two
concrete backends. Which backend a component runs on is part of the
component declaration, which sits above this module; this module defines
only the type.
"""
abstract type Backend end

"""
    CPU(workgroup; bitwise = false)

The CPU backend, launching at KernelAbstractions workgroup size `workgroup`.
`bitwise` selects the debug arithmetic of decision 0029: pure Julia
arithmetic, no fast-math, no implicit fused multiply-add, the same on every
backend.
"""
struct CPU <: Backend
    workgroup::Int
    bitwise::Bool
end
CPU(workgroup::Integer; bitwise::Bool = false) = CPU(Int(workgroup), bitwise)

"""
    GPU(workgroup; bitwise = false)

The GPU backend (CUDA), launching at KernelAbstractions workgroup size
`workgroup`, with the same `bitwise` meaning as `CPU`.
"""
struct GPU <: Backend
    workgroup::Int
    bitwise::Bool
end
GPU(workgroup::Integer; bitwise::Bool = false) = GPU(Int(workgroup), bitwise)

"""
    workgroup(backend::Backend)

The KernelAbstractions workgroup size `launch!` uses for `backend`.
"""
workgroup(b::Backend) = b.workgroup

"""
    bitwise(backend::Backend)

Whether `backend` runs in bitwise debug mode (decision 0029). A kernel
branches on this to route a multiply that feeds an add through the fusion
barrier instead of letting it fuse on the GPU backend; a kernel with a
transcendental in it also branches on this to choose the project's own
polynomial implementation over the platform library, once one exists
(fiddlybits-52v.7.8).
"""
bitwise(b::Backend) = b.bitwise

"""
    array_type(backend::Backend)

The array type `adapt_for` moves a struct's arrays to for `backend`.
"""
array_type(::CPU) = Array
array_type(::GPU) = CUDA.CuArray

"""
    ka_backend(backend::Backend)

The `KernelAbstractions.Backend` `launch!` compiles `backend`'s kernel for.
Refuses when `backend` is `GPU` and CUDA reports no functional device.
"""
ka_backend(::CPU) = KernelAbstractions.CPU()
function ka_backend(::GPU)
    CUDA.functional() ||
        refuse("GPU backend", "Backends.ka_backend", "CUDA reports no functional device on this host")
    return CUDA.CUDABackend()
end
