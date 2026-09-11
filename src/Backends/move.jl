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
lived on to `backend`'s name, unless `array` has no elements.

An array with no elements is placed on `backend` and nothing is recorded: a
move is bytes crossing between two devices and there are none to cross.

A move off a device calls `complete!(array)` before it copies, so the copy
reads what the kernels that wrote `array` finished writing rather than
whatever they had reached. This is the only device-to-host copy in `src/`,
and the wait is stated here rather than left to what a copy of unpinned
memory happens to do on a particular platform.
"""
function on(array::AbstractArray, backend::CPU)
    from = backend_of(array)
    from === :cpu && return array
    complete!(array)
    record_move(array, from, :cpu)
    return Array(array)
end

function on(array::AbstractArray, backend::GPU)
    ka_backend(backend)
    from = backend_of(array)
    from === :gpu && return array
    record_move(array, from, :gpu)
    return CUDA.CuArray(array)
end

"""
    record_move(array, from, to)

Record `array`'s move from backend `from` to backend `to` through
`Events.moved`, and record nothing when `array` has no elements. This is the
one place `on` decides what counts as a move.
"""
record_move(array::AbstractArray, from, to) =
    isempty(array) ? nothing : moved(array, from, to)

"""
    adapt_for(x, backend::Backend)

`x` with every array it carries moved to `backend`, through
`Adapt.adapt_structure`.

The `CPU` form completes the device first, because the arrays `x` carries may
be arrays a kernel is still writing; it completes nothing when CUDA reports no
functional device, there being no device work to wait for on such a host.
"""
adapt_for(x, backend::GPU) = Adapt.adapt(array_type(backend), x)

function adapt_for(x, backend::CPU)
    CUDA.functional() && complete_on(CUDA.CUDABackend())
    return Adapt.adapt(array_type(backend), x)
end
