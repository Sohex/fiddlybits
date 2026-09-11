using Test
using CUDA
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits: Backends

# handoff, after! and order_explicitly! are the cross-task ordering door:
# docs/plans/fiddlybits-52v.7-kernels.md, section "The device layer", and
# decision 0038 on stages that are not separated by a barrier.
#
# Two tasks queue on two streams, so the stream order that path 1 of
# notes/findings/2026-09-11-a-launch-that-queues-and-a-completion-that-is-
# stated.md rests on says nothing about them. What ordered them before this
# row was CUDA.jl's per-array bookkeeping, and order_explicitly! is what
# switches that off, which is what makes the control below able to fail.
#
# The checks are a race demonstration scored over repeats, because that is
# what the property is. The spin kernel takes a runtime spin count so the
# loop cannot be folded away: it adds 1.0 to an accumulator `spins` times,
# which is exactly Float64(spins) for every `spins` below 2^53.

const CROSS_SENTINEL = -7.0
const CROSS_REPEATS = 5
const CROSS_TIMINGS = 3

@kernel function cross_spin_kernel!(out, @Const(src), spins)
    i = @index(Global)
    acc = zero(eltype(out))
    for _ in 1:spins
        acc += one(eltype(out))
    end
    out[i] = src[i] + acc
end

@kernel function cross_double_kernel!(out, @Const(src))
    i = @index(Global)
    out[i] = src[i] + src[i]
end

"The elapsed seconds of `f()`, discarding its value."
cross_elapsed(f) = (t = time(); f(); time() - t)

"""
    cross_spins(backend, target)

The `spins` argument that makes `cross_spin_kernel!` take at least `target`
seconds on `backend` over one work item, found by doubling from a compiled
starting point rather than assumed from a clock rate.
"""
function cross_spins(backend, target::Real)
    out = Backends.on(fill(CROSS_SENTINEL, 1), backend)
    src = Backends.on([1.0], backend)
    Backends.launch!(cross_spin_kernel!, backend, 1, out, src, 1)
    Backends.complete!(backend)
    spins = 1 << 16
    for _ in 1:40
        t = cross_elapsed() do
            Backends.launch!(cross_spin_kernel!, backend, 1, out, src, spins)
            Backends.complete!(backend)
        end
        t >= target && return spins
        spins *= 2
    end
    return spins
end

"""
    handover(gpu, n, spins; ordered)

One repeat of the two-task shape: a producer task queues the spin kernel over
`out`, hands its queue point to a consumer task through a channel, and the
consumer doubles `out` into `result`. `ordered` says whether the consumer
calls `after!` on that point before it launches. Returns `result` on the host.

`out` is taken out of the library's per-array ordering, so `after!` is the
only thing that can order the two launches.
"""
function handover(gpu, n::Integer, spins::Integer; ordered::Bool)
    cpu = Backends.CPU(1)
    out = Backends.order_explicitly!(Backends.on(fill(CROSS_SENTINEL, n), gpu))
    src = Backends.on(fill(1.0, n), gpu)
    result = Backends.on(zeros(n), gpu)
    Backends.complete!(gpu)

    gate = Channel{Backends.Handoff}(1)
    producer = @async begin
        Backends.launch!(cross_spin_kernel!, gpu, n, out, src, spins)
        put!(gate, Backends.handoff(gpu))
    end
    consumer = @async begin
        point = take!(gate)
        ordered && Backends.after!(gpu, point)
        Backends.launch!(cross_double_kernel!, gpu, n, result, out)
        Backends.complete!(gpu)
    end
    wait(producer)
    wait(consumer)
    return Backends.on(result, cpu)
end

"""
    device_wait(gpu, n, spins)

The seconds `after!` takes on the `GPU` backend while the other task's kernel
is still running, and the seconds the completion that follows it takes. The
producer hands its queue point over and does not wait for its own kernel, so
this task takes the point while that kernel is running.
"""
function device_wait(gpu, n::Integer, spins::Integer)
    out = Backends.order_explicitly!(Backends.on(fill(CROSS_SENTINEL, n), gpu))
    src = Backends.on(fill(1.0, n), gpu)
    Backends.complete!(gpu)

    gate = Channel{Backends.Handoff}(1)
    producer = @async begin
        Backends.launch!(cross_spin_kernel!, gpu, n, out, src, spins)
        put!(gate, Backends.handoff(gpu))
    end
    point = take!(gate)
    t_after = cross_elapsed(() -> Backends.after!(gpu, point))
    t_complete = cross_elapsed(() -> Backends.complete!(gpu))
    wait(producer)
    return t_after, t_complete
end

"""
    host_wait(gpu, cpu, n, spins)

The seconds `after!` takes on the `CPU` backend, handed the same queue point
by the same two-task shape as `device_wait`.
"""
function host_wait(gpu, cpu, n::Integer, spins::Integer)
    out = Backends.order_explicitly!(Backends.on(fill(CROSS_SENTINEL, n), gpu))
    src = Backends.on(fill(1.0, n), gpu)
    Backends.complete!(gpu)

    gate = Channel{Backends.Handoff}(1)
    producer = @async begin
        Backends.launch!(cross_spin_kernel!, gpu, n, out, src, spins)
        put!(gate, Backends.handoff(gpu))
    end
    point = take!(gate)
    t_host = cross_elapsed(() -> Backends.after!(cpu, point))
    wait(producer)
    return t_host
end

@testset "handoff and after! order two tasks that share a device array" begin
    @test CUDA.functional()

    gpu = Backends.GPU(1)
    cpu = Backends.CPU(1)
    n = 4
    spins = cross_spins(gpu, 0.05)
    finished = fill(2 * (1.0 + Float64(spins)), n)
    unfinished = fill(2 * CROSS_SENTINEL, n)

    @testset "the consumer task sees the producer's finished write" begin
        @test finished != unfinished
        # One repeat over a one-spin kernel first, so that the repeats below
        # are not racing this file's first compilation of every method they
        # call.
        handover(gpu, n, 1; ordered = true)
        for _ in 1:CROSS_REPEATS
            @test handover(gpu, n, spins; ordered = true) == finished
        end

        @testset "positive control: without after! the consumer sees the sentinel" begin
            # The same two tasks with the door left shut. It is a race, so it
            # is scored over repeats: one unordered read is what makes the
            # check above a check.
            stale = 0
            for _ in 1:CROSS_REPEATS
                handover(gpu, n, spins; ordered = false) == unfinished && (stale += 1)
            end
            @test stale > 0
        end
    end

    @testset "after! waits on the device and not on the host" begin
        # A longer kernel than the race checks use, because these are timings
        # and the margin has to stand above the scatter of a shared card.
        slow_spins = cross_spins(gpu, 0.25)
        whole = cross_elapsed() do
            out = Backends.on(fill(CROSS_SENTINEL, n), gpu)
            src = Backends.on(fill(1.0, n), gpu)
            Backends.complete!(gpu)
            Backends.launch!(cross_spin_kernel!, gpu, n, out, src, slow_spins)
            Backends.complete!(gpu)
        end

        # One repeat over a one-spin kernel first, so the numbers below are not
        # this file's first compilation of every method they call.
        device_wait(gpu, n, 1)
        waits = [device_wait(gpu, n, slow_spins) for _ in 1:CROSS_TIMINGS]
        t_after, t_complete = waits[argmin(first.(waits))]

        @test t_after < whole / 10
        # The completion that follows is what says the kernel was still
        # running when after! returned: had it finished, this task would have
        # had nothing to wait for and the number above would mean nothing.
        @test t_complete > whole / 2

        @testset "positive control: the same point waited for on the host does stop" begin
            # after!(::CPU, point) is where the wait has to go, a CPU launch
            # having run its kernel before it returned. It is the shape the
            # GPU number above has to be able to reject.
            host_wait(gpu, cpu, n, 1)
            t_host = maximum(host_wait(gpu, cpu, n, slow_spins) for _ in 1:CROSS_TIMINGS)
            @test t_host > whole / 2
        end
    end

    @testset "the CPU backend hands off nothing, its kernels having run" begin
        out = fill(CROSS_SENTINEL, n)
        src = fill(1.0, n)
        Backends.launch!(cross_spin_kernel!, cpu, n, out, src, 1)
        point = Backends.handoff(cpu)
        @test point.event === nothing
        @test Backends.after!(cpu, point) === nothing
        @test Backends.after!(gpu, point) === nothing
        @test out == fill(2.0, n)
    end

    @testset "order_explicitly! returns a host array untouched" begin
        x = [1.0, 2.0, 3.0]
        @test Backends.order_explicitly!(x) === x
    end
end
