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

"""
    QueuedTrace()

The record `QUEUED_KEY` holds: the kernel, the workgroup size and the work item
count of each launch, in three vectors of one length, in the order queued.
"""
struct QueuedTrace
    kernels::Vector{Any}
    workgroups::Vector{Int}
    counts::Vector{Int}
end
QueuedTrace() = QueuedTrace(Any[], Int[], Int[])

"Empties every vector of `trace`."
function empty_trace!(trace::QueuedTrace)
    empty!(trace.kernels)
    empty!(trace.workgroups)
    empty!(trace.counts)
    return trace
end

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
queued(::GPU) = queued_trace().kernels

"""
    queued_launches(backend::Backend)

`queued`'s launches with their shape: one `(kernel, workgroup, n)` named
tuple per launch, the workgroup size it launched at and its work item count,
in the order they were queued.
"""
queued_launches(::CPU) = NO_KERNELS

function queued_launches(::GPU)
    trace = queued_trace()
    return Any[(kernel = trace.kernels[i], workgroup = trace.workgroups[i], n = trace.counts[i])
               for i in eachindex(trace.kernels)]
end

queued_trace() = get!(QueuedTrace, task_local_storage(), QUEUED_KEY)::QueuedTrace

"""
    launch!(kernel, backend::Backend, n::Integer, args...)

Compile `kernel` (a `KernelAbstractions.@kernel` function) for `backend`'s
device and queue it over `n` work items with `args`, at the workgroup size
`launch_workgroup(backend, n)`, through `queue_kernel!`.

On `CPU` the kernel has run over every work item by the time this returns.
On `GPU` the kernel has been queued on the backend's stream and may still be
running: it runs after every kernel this task queued on that backend before
it, before every kernel this task queues on it after, and is finished only
once `complete!` has returned for the backend or for an array it wrote.
`Backends.on` and `Backends.adapt_for` call `complete!` before they read
device memory on the host, so a host read never reaches an unfinished write
through this module. A kernel queued from another task is ordered against
this one only through `handoff` and `after!`.
"""
function launch!(kernel, backend::Backend, n::Integer, args...)
    dev = ka_backend(backend)
    size = launch_workgroup(backend, n)
    queue_kernel!(kernel, dev, size, n, args...)
    record_queued!(backend, kernel, size, n)
    return nothing
end

"""
    STATIC_WORKGROUPS

The workgroup sizes `queue_kernel!` compiles into the kernel's type: every
power of two from 1 to 1024, the largest number of threads a CUDA block holds
along its first dimension (CUDACore `src/device/intrinsics/indexing.jl`,
`max_block_size`).
"""
const STATIC_WORKGROUPS = ntuple(i -> 2^(i - 1), 11)

"""
    queue_kernel!(kernel, dev, size, n, args...)

Launch `kernel` on the `KernelAbstractions.Backend` `dev` over `n` work items
with `args` at the workgroup size `size`. A `size` in `STATIC_WORKGROUPS` is
a parameter of the compiled kernel's type, one branch per size, each spelling
that type as `KernelAbstractions.StaticSize{(size,)}`; any other `size` is an
argument of the launch. Each branch calls a kernel whose type is written in
this method's source. Measured in
notes/findings/2026-09-13-the-launch-workgroup-as-a-type-parameter-or-an-argument.md.
"""
function queue_kernel! end

@eval function queue_kernel!(kernel, dev::KernelAbstractions.Backend, size::Int, n::Integer, args...)
    $(foldr(STATIC_WORKGROUPS; init = :(kernel(dev)(args...; ndrange = n, workgroupsize = size))) do w, rest
        :(size == $w ?
          kernel(dev, KernelAbstractions.StaticSize{($w,)}(), KernelAbstractions.DynamicSize())(args...; ndrange = n) :
          $rest)
    end)
    return nothing
end

record_queued!(::CPU, kernel, size, n) = nothing

function record_queued!(backend::GPU, kernel, size, n)
    trace = queued_trace()
    if length(trace.kernels) < QUEUED_TRACE
        push!(trace.kernels, kernel)
        push!(trace.workgroups, size)
        push!(trace.counts, n)
    end
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
        named = isempty(trace.kernels) ?
            "no kernel queued through Backends.launch! on this task" :
            join(("$(trace.kernels[i]) at workgroup $(trace.workgroups[i]) over $(trace.counts[i]) work items"
                  for i in eachindex(trace.kernels)), ", ") *
            (length(trace.kernels) < QUEUED_TRACE ? "" : ", and any queued after them")
        empty_trace!(trace)
        refuse("kernel completion", "Backends.complete!",
               "$(sprint(showerror, err)); raised by one of the kernels queued " *
               "since the last completion: $named")
    end
    empty_trace!(trace)
    return nothing
end

"""
    Handoff

A point in one task's queue on a device that another task can order its own
launches after. `handoff` makes one and `after!` consumes it; it carries a
CUDA event for a `GPU` handoff and nothing for a `CPU` one, whose kernels
have already run.

A `Handoff` is not a completion: the task that made it does not wait, and the
task that takes it waits on the device rather than on the host.
"""
struct Handoff
    event::Union{Nothing,CUDA.CuEvent}
end

"""
    handoff(backend::Backend)

A `Handoff` standing for everything this task has queued on `backend` up to
this call.

On `GPU` this records an event on the stream this task queues on. On `CPU` it
carries nothing, a CPU launch having run every work item before it returned.
"""
handoff(::CPU) = Handoff(nothing)

function handoff(backend::GPU)
    ka_backend(backend)
    event = CUDA.CuEvent(CUDA.EVENT_DISABLE_TIMING)
    CUDA.record(event)
    return Handoff(event)
end

"""
    after!(backend::Backend, point::Handoff)

Order everything this task queues on `backend` after this call behind the
work `point` stands for, and return without waiting for it on the host.

On `GPU` this makes the stream this task queues on wait for `point`'s event,
which is a wait on the device: the host returns at once and the kernels
queued after this call start only once the other task's work has finished.
On `CPU`, whose launch runs the kernel before it returns, a `GPU` `point` is
waited for on the host here instead, there being nowhere else to put the
wait; a `CPU` `point` is already finished and returns at once.

This is the only cross-task ordering this module states. Two tasks that share
a device array and do not use it are ordered by whatever per-array stream
bookkeeping the platform's library does on its own, which is a host-side stop
on this platform and nothing at all on a platform without it; `order_explicitly!`
is how an array is taken out of that bookkeeping.
"""
after!(::CPU, point::Handoff) =
    point.event === nothing ? nothing : (CUDA.synchronize(point.event); nothing)

function after!(backend::GPU, point::Handoff)
    ka_backend(backend)
    point.event === nothing && return nothing
    CUDA.wait(point.event)
    return nothing
end

"""
    order_explicitly!(array::AbstractArray)

Take `array` out of the platform library's implicit per-array ordering and
return it, so that `handoff` and `after!` are what order accesses to it from
more than one task.

Returns a host array unchanged, there being no device ordering to take it out
of. On a device array this switches off the synchronization CUDA.jl performs
when a launch from one task converts an array another task's stream last
owned; after it, an access from a second task that is not ordered by `after!`
is ordered by nothing at all.

The switch is a property of the memory and not of this `array` object, so it
reaches every array sharing the same allocation.
"""
function order_explicitly!(array::AbstractArray)
    backend_of(array) === :cpu && return array
    CUDA.enable_synchronization!(array, false)
    return array
end
