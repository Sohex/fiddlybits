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
whatever they had reached. `on` is the device-to-host copy that waits;
`copy_to_host!` is the one that queues its copy and returns a `Handoff`, and
its host bytes are read once `after!(CPU(), point)` has returned.
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
copying it, through `HostAdaptor`; a structure holding no device array
completes nothing.
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

`x` completed, through `complete!`, then converted to `a.to`.
"""
Adapt.adapt_storage(a::HostAdaptor, x::AbstractArray) = (complete!(x); convert(a.to, x))

# The host copy: docs/plans/fiddlybits-52v.6-provenance.md, section "The
# writer", the host copy stage.

"The site every refusal of `copy_to_host!` names."
const HOST_COPY_SITE = "Backends.copy_to_host!"

"""
    host_buffer(backend::CPU, T, n)
    host_buffer(backend::GPU, T, n)

A `Vector{T}` of `n` uninitialised elements for `copy_to_host!` to copy into.

On `CPU`, a plain `Vector{T}`. On `GPU`, the vector page-locked through
`CUDA.pin`, which registers its memory with the driver and attaches a
finalizer that unregisters it when the vector is collected;
`free_host_buffer!` unregisters it before then. A vector of no elements is
returned without a page lock, `CUDA.pin` refusing an empty range.

Refuses an `n` below zero, a `T` that is not a bits type, and, on `GPU`, a
host where CUDA reports no functional device.
"""
function host_buffer(backend::CPU, T::Type, n::Integer)
    check_buffer_shape(T, n)
    return Vector{T}(undef, n)
end

function host_buffer(backend::GPU, T::Type, n::Integer)
    ka_backend(backend)
    check_buffer_shape(T, n)
    buffer = Vector{T}(undef, n)
    n == 0 && return buffer
    CUDA.pin(buffer)
    return buffer
end

"""
    check_buffer_shape(T, n)

Refuses, at `Backends.host_buffer`, an `n` below zero and a `T` that is not a
bits type.
"""
function check_buffer_shape(T::Type, n::Integer)
    n >= 0 ||
        refuse("host buffer length", "Backends.host_buffer", "length $n is below zero")
    isbitstype(T) ||
        refuse("host buffer element type", "Backends.host_buffer", "$T is not a bits type")
    return nothing
end

"""
    page_locked(host::Vector)

Whether the CUDA driver reports the addresses of `host`'s first and last
elements as page-locked host memory, through `CUDA.is_pinned`. `false` for a
vector with no elements and on a host where CUDA reports no functional device.
"""
page_locked(host::Vector) =
    !isempty(host) && CUDA.functional() &&
    CUDA.is_pinned(pointer(host)) && CUDA.is_pinned(pointer(host, length(host)))

"""
    free_host_buffer!(buffer::Vector)

Release the page lock `host_buffer` took on `buffer` and return nothing.
`buffer` stays a valid host `Vector` without a page lock. The release runs
the finalizer `CUDA.pin` attached, through `Base.finalize`, which runs every
finalizer registered on `buffer` at the call and removes it.

A copy into `buffer` is landed by the time `after!(CPU(), point)` has returned
for its `point`; the caller frees a buffer only after that, for every copy
queued into it.

Returns at once for a buffer with no elements and for one that is not
page-locked, which includes every `host_buffer` from `CPU`. Refuses, naming its
address, a buffer still page-locked once its finalizers have run.
"""
function free_host_buffer!(buffer::Vector)
    page_locked(buffer) || return nothing
    finalize(buffer)
    page_locked(buffer) &&
        refuse("host buffer", "Backends.free_host_buffer!",
               "the Vector{$(eltype(buffer))} of $(length(buffer)) elements at " *
               "$(pointer(buffer)) is still page-locked after its finalizers ran")
    return nothing
end

"""
    copy_to_host!(host::Vector, array::AbstractArray)

Copy `array`'s elements, in linear order, into `host`, and return a `Handoff`.

For a device array the copy is queued on the stream this task queues on,
behind every kernel this task has queued there and ahead of every kernel it
queues after, and this returns without a host wait. Once
`after!(CPU(), point)` has returned for the returned `point`, `host` holds the
values the kernels queued before this call left in `array`. The caller keeps
`host` and `array` reachable until then. The move is recorded once through
`Events.moved` from `:gpu` to `:cpu`, and not at all when `array` has no
elements. An `array` last written from another task is ordered by calling
`after!` with that task's `Handoff` before this call, as a launch is. A kernel
that faults on the device before the copy is not raised by
`after!(CPU(), point)`; the next `complete!` on the task that queued it raises
it (`fiddlybits-52v.6.32`).

For a host array the copy is taken at the call, nothing is recorded, and the
`Handoff` is `handoff(CPU())`.

Refuses, naming what differs, a `host` that is not a `Vector`, one whose
element type is not `array`'s, one whose length is not `array`'s, a device
`array` that is not a `CUDA.CuArray`, and, for a device `array` with elements,
a `host` the driver does not report as page-locked, which
`host_buffer(GPU(), T, n)` makes.
"""
function copy_to_host!(host::AbstractArray, array::AbstractArray)
    check_host(host, array)
    backend_of(array) === :cpu && return copy_at_call!(host, array)
    return queue_host_copy!(host, array)
end

"""
    check_host(host, array)

Refuses, at `Backends.copy_to_host!`, a `host` that is not a `Vector` of
`array`'s element type and length, naming the first of the three that differs.
"""
function check_host(host::AbstractArray, array::AbstractArray)
    host isa Vector ||
        refuse("host buffer", HOST_COPY_SITE, "the host is a $(typeof(host)), not a Vector")
    eltype(host) === eltype(array) ||
        refuse("host buffer", HOST_COPY_SITE,
               "the host holds $(eltype(host)) elements and the array holds $(eltype(array)) elements")
    length(host) == length(array) ||
        refuse("host buffer", HOST_COPY_SITE,
               "the host holds $(length(host)) elements and the array holds $(length(array))")
    return nothing
end

"""
    copy_at_call!(host, array)

`array` copied into `host` at the call; returns `handoff(CPU())`.
"""
function copy_at_call!(host::Vector, array::AbstractArray)
    copyto!(host, array)
    return handoff(CPU())
end

"""
    queue_host_copy!(host, array)

`array`'s bytes copied into `host` through CUDA's pointer copy with
`async = true` on this task's stream, the move recorded through `record_move`,
and `handoff(GPU())` returned. An `array` with no elements queues nothing.
Refuses an `array` that is not a `CUDA.CuArray` and a `host` that is not
page-locked.
"""
function queue_host_copy!(host::Vector{T}, array::AbstractArray{T}) where {T}
    array isa CUDA.CuArray ||
        refuse("device array", HOST_COPY_SITE,
               "the array is a $(typeof(array)); a copy to the host is queued from a CUDA.CuArray")
    isempty(array) && return handoff(GPU())
    page_locked(host) ||
        refuse("host buffer", HOST_COPY_SITE,
               "the host Vector{$T} of $(length(host)) elements at $(pointer(host)) is not " *
               "page-locked; Backends.host_buffer(GPU(), $T, $(length(host))) makes one that is")
    GC.@preserve host array unsafe_copyto!(pointer(host), pointer(array), length(array); async = true)
    record_move(array, :gpu, :cpu)
    return handoff(GPU())
end
