# The device move: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer".

using ..Events: moved
import Adapt
import CUDA

"""
    backend_of(array)

The backend name `array` currently lives on, read from its concrete type:
`:gpu` for a `CUDA.CuArray`, `:cpu` for any other `AbstractArray`.
"""
backend_of(::CUDA.CuArray) = :gpu
backend_of(::AbstractArray) = :cpu

"""
    on(array::AbstractArray, backend::CPU)
    on(array::AbstractArray, backend::GPU)

`array` moved to `backend`, recording the move through `Events.moved` from
the backend `array` currently lives on to `backend`'s name. Returns `array`
unchanged when it already lives on `backend`, and a copy on `backend`
otherwise.
"""
function on(array::AbstractArray, backend::CPU)
    from = backend_of(array)
    moved(array, from, :cpu)
    return from === :cpu ? array : Array(array)
end

function on(array::AbstractArray, backend::GPU)
    ka_backend(backend)
    from = backend_of(array)
    moved(array, from, :gpu)
    return from === :gpu ? array : CUDA.CuArray(array)
end

"""
    adapt_for(x, backend::Backend)

`x` with every array it carries moved to `backend`, through
`Adapt.adapt_structure`.
"""
adapt_for(x, backend::Backend) = Adapt.adapt(array_type(backend), x)
