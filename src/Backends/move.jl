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
returns, and for an array type it cannot resolve to one, which that function
reports by raising rather than by returning: a `BitArray` is such a type, and
the raised error is carried into the refusal's reason.
"""
function backend_of(array::AbstractArray)
    ka = try
        KernelAbstractions.get_backend(array)
    catch err
        refuse("array backend", "Backends.backend_of",
               "KernelAbstractions.get_backend cannot resolve $(typeof(array)) " *
               "to a backend: $(sprint(showerror, err))")
    end
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

The `CPU` form completes each device array `x` carries immediately before
copying it, through `HostAdaptor`, rather than draining the device before the
structure is walked: a structure holding no device array completes nothing.
"""
adapt_for(x, backend::GPU) = Adapt.adapt(array_type(backend), x)

adapt_for(x, backend::CPU) = Adapt.adapt(HostAdaptor(array_type(backend)), x)

"""
    HostAdaptor(to)

The `Adapt` target `adapt_for` walks a structure with for a move to `CPU`.
`to` is the array type `array_type(backend::CPU)` names.
"""
struct HostAdaptor{T}
    to::Type{T}
end

"""
    Adapt.adapt_storage(a::HostAdaptor, x::AbstractArray)

`x` completed and converted to `a.to`. The completion sits here, at the one
leaf `Adapt.adapt` converts, rather than at the top of the walk: an array
already on the host completes nothing, through the same test `complete!`
carries at every other call site, and an array still being written by a
kernel is waited for immediately before this call reads it.
"""
Adapt.adapt_storage(a::HostAdaptor, x::AbstractArray) = (complete!(x); convert(a.to, x))
