# The device move: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer".

using ..Events: moved
using ..Verdicts: refuse
import Adapt
import CUDA
import KernelAbstractions

"""
    backend_of(array)

The backend name `array` currently lives on, from
`KernelAbstractions.get_backend(array)`: `:cpu` for `KernelAbstractions.CPU`,
`:gpu` for `CUDA.CUDABackend`. Refuses for any other backend that function
returns, and for an array type it cannot resolve to one.
"""
function backend_of(array::AbstractArray)
    ka = KernelAbstractions.get_backend(array)
    ka isa KernelAbstractions.CPU && return :cpu
    ka isa CUDA.CUDABackend && return :gpu
    refuse("array backend", "Backends.backend_of",
           "KernelAbstractions.get_backend returned $(typeof(ka)), neither CPU nor CUDABackend")
end

"""
    on(array::AbstractArray, backend::CPU)
    on(array::AbstractArray, backend::GPU)

`array` moved to `backend`. Returns `array` unchanged, recording nothing,
when it already lives on `backend`; otherwise returns a copy on `backend`
and records the move through `Events.moved`, from the backend `array`
lived on to `backend`'s name.
"""
function on(array::AbstractArray, backend::CPU)
    from = backend_of(array)
    from === :cpu && return array
    moved(array, from, :cpu)
    return Array(array)
end

function on(array::AbstractArray, backend::GPU)
    ka_backend(backend)
    from = backend_of(array)
    from === :gpu && return array
    moved(array, from, :gpu)
    return CUDA.CuArray(array)
end

"""
    adapt_for(x, backend::Backend)

`x` with every array it carries moved to `backend`, through
`Adapt.adapt_structure`.
"""
adapt_for(x, backend::Backend) = Adapt.adapt(array_type(backend), x)
