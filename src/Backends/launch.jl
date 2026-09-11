# The kernel launch and its completion: docs/plans/fiddlybits-52v.7-kernels.md,
# section "The device layer".

using ..Verdicts: refuse
import CUDA
import KernelAbstractions

"""
    QUEUED_KEY
    QUEUED_TRACE

`QUEUED_KEY` is the task-local storage key under which `launch!` records the
kernels it has queued on a device backend and no `complete!` has waited for
yet. `QUEUED_TRACE` is how many of them that record holds before it stops
growing, so a chain that never completes does not grow without bound.
"""
const QUEUED_KEY = :fiddlybits_backends_queued
const QUEUED_TRACE = 32

"The record `queued` returns for a backend that keeps none. Never written to."
const NO_KERNELS = Any[]

"""
    queued(backend::Backend)

The kernels `launch!` has queued on `backend` from this task that no
`complete!` has waited for yet, in the order they were queued, up to
`QUEUED_TRACE` of them. Empty for `CPU`, whose launch returns only after
every work item has run, and emptied by every `complete!`.
"""
queued(::CPU) = NO_KERNELS
queued(::GPU) = queued_trace()

queued_trace() = get!(() -> Any[], task_local_storage(), QUEUED_KEY)::Vector{Any}

"""
    launch!(kernel, backend::Backend, n::Integer, args...)

Compile `kernel` (a `KernelAbstractions.@kernel` function) for `backend`'s
device at `backend`'s workgroup size and queue it over `n` work items with
`args`.

On `CPU` the kernel has run over every work item by the time this returns.
On `GPU` the kernel has been queued on the backend's stream and may still be
running: it runs after every kernel this task queued on that backend before
it, before every kernel this task queues on it after, and is finished only
once `complete!` has returned for the backend or for an array it wrote.
`Backends.on` and `Backends.adapt_for` call `complete!` before they read
device memory on the host, so a host read never reaches an unfinished write
through this module.
"""
function launch!(kernel, backend::Backend, n::Integer, args...)
    dev = ka_backend(backend)
    compiled = kernel(dev, workgroup(backend))
    compiled(args...; ndrange = n)
    record_queued!(backend, kernel)
    return nothing
end

record_queued!(::CPU, kernel) = nothing

function record_queued!(backend::GPU, kernel)
    trace = queued(backend)
    length(trace) < QUEUED_TRACE && push!(trace, kernel)
    return nothing
end

"""
    complete!(backend::Backend)
    complete!(array::AbstractArray)

Block until the kernels `launch!` queued have finished, then empty `queued`
and return nothing. The `Backend` form waits for every kernel this task
queued on that backend; the array form waits for every operation queued on
the stream that last held `array`, which is the kernel that wrote it even
when another task queued it.

Returns at once for `CPU` and for a host array, whose kernels have run by the
time `launch!` returned.

Refuses, carrying the raised error's own message and naming the kernels
`queued` holds, when the wait raises. A kernel that faults on the device
raises here and not at its launch, because its launch did not wait for it.
"""
complete!(::CPU) = nothing
complete!(backend::GPU) = complete_on(ka_backend(backend))
complete!(array::AbstractArray) = backend_of(array) === :cpu ? nothing : complete_on(array)

complete_on(dev::KernelAbstractions.Backend) =
    wait_queued(() -> KernelAbstractions.synchronize(dev))
complete_on(array::CUDA.CuArray) = wait_queued(() -> CUDA.synchronize(array))
complete_on(array::AbstractArray) = complete_on(KernelAbstractions.get_backend(array))

"""
    wait_queued(wait)

Run `wait`, empty this task's `queued` record and return nothing. Refuses
when `wait` raises, carrying that error's own message and naming every kernel
the record holds.
"""
function wait_queued(wait)
    trace = queued_trace()
    try
        wait()
    catch err
        named = isempty(trace) ?
            "no kernel queued through Backends.launch! on this task" :
            join(trace, ", ") *
            (length(trace) < QUEUED_TRACE ? "" : ", and any queued after them")
        empty!(trace)
        refuse("kernel completion", "Backends.complete!",
               "$(sprint(showerror, err)); raised by one of the kernels queued " *
               "since the last completion: $named")
    end
    empty!(trace)
    return nothing
end
