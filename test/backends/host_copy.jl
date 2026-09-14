using Test
using CUDA
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits: Backends, Events
using Fiddlybits.Verdicts: Refusal

# host_buffer, copy_to_host! and free_host_buffer!, the host copy stage of the
# store's writer: docs/plans/fiddlybits-52v.6-provenance.md, section "The
# writer", and docs/plans/fiddlybits-52v.7-kernels.md, section "The device
# layer". What the door relies on in CUDA.jl is docs/imports/cuda.md, section
# "Page-locked memory and the queued copy".
#
# The spin kernel takes its length as a runtime argument, calibrated by
# doubling, so a kernel is still running when the door under test returns. The
# orders these checks read are the stream's and the task scheduler's; nothing
# here sleeps.

const HOST_COPY_SENTINEL = -7.0

@kernel function host_copy_spin_kernel!(out, @Const(src), spins)
    i = @index(Global)
    acc = zero(eltype(out))
    for _ in 1:spins
        acc += one(eltype(out))
    end
    out[i] = src[i] + acc
end

@kernel function host_copy_double_kernel!(out, @Const(src))
    i = @index(Global)
    out[i] = src[i] + src[i]
end

"The elapsed seconds of `f()`, discarding its value."
host_copy_elapsed(f) = (t = time(); f(); time() - t)

"""
    host_copy_spins(backend, target)

The `spins` argument that makes `host_copy_spin_kernel!` take at least
`target` seconds on `backend` over one work item, found by doubling.
"""
function host_copy_spins(backend, target::Real)
    out = Backends.on(fill(HOST_COPY_SENTINEL, 1), backend)
    src = Backends.on([1.0], backend)
    Backends.launch!(host_copy_spin_kernel!, backend, 1, out, src, 1)
    Backends.complete!(backend)
    spins = 1 << 16
    for _ in 1:40
        t = host_copy_elapsed() do
            Backends.launch!(host_copy_spin_kernel!, backend, 1, out, src, spins)
            Backends.complete!(backend)
        end
        t >= target && return spins
        spins *= 2
    end
    return spins
end

"The `Refusal` `f()` raises, or `nothing` when it returns."
function host_copy_refusal(f)
    try
        f()
        return nothing
    catch err
        err isa Refusal || rethrow()
        return err
    end
end

"""
    copied_values(gpu, n, spins; between)

The spin kernel writes `1 + spins` into a device array and a second kernel
then writes `2`. With `between`, `copy_to_host!` is called between the two
launches; without it, after the second. Returns the host buffer's values once
`after!(CPU(), point)` has returned.
"""
function copied_values(gpu, n::Integer, spins::Integer; between::Bool)
    cpu = Backends.CPU(1)
    out = Backends.on(fill(HOST_COPY_SENTINEL, n), gpu)
    src = Backends.on(fill(1.0, n), gpu)
    host = Backends.host_buffer(gpu, Float64, n)
    Backends.complete!(gpu)

    Backends.launch!(host_copy_spin_kernel!, gpu, n, out, src, spins)
    point = between ? Backends.copy_to_host!(host, out) : nothing
    Backends.launch!(host_copy_double_kernel!, gpu, n, out, src)
    between || (point = Backends.copy_to_host!(host, out))
    Backends.after!(cpu, point)

    values = copy(host)
    Backends.complete!(gpu)
    Backends.free_host_buffer!(host)
    return values
end

"""
    door_state(gpu, n, spins, door)

Queues the spin kernel, calls `door(host, out)`, and reads at once what this
task's `queued` record holds and whether the returned `Handoff`'s event is
still outstanding on the device (`false` when `door` returns none). Returns
`(queued, outstanding, values)`, `values` read once the work is finished.
"""
function door_state(gpu, n::Integer, spins::Integer, door)
    cpu = Backends.CPU(1)
    out = Backends.on(fill(HOST_COPY_SENTINEL, n), gpu)
    src = Backends.on(fill(1.0, n), gpu)
    host = Backends.host_buffer(gpu, Float64, n)
    Backends.complete!(gpu)

    Backends.launch!(host_copy_spin_kernel!, gpu, n, out, src, spins)
    point = door(host, out)
    queued = copy(Backends.queued(gpu))
    outstanding = point isa Backends.Handoff && point.event !== nothing && !CUDA.isdone(point.event)

    point isa Backends.Handoff && Backends.after!(cpu, point)
    Backends.complete!(gpu)
    values = copy(host)
    Backends.free_host_buffer!(host)
    return queued, outstanding, values
end

"""
    yield_order(gpu, n, spins, hold)

One task queues the spin kernel and a copy of what it writes, schedules a
second task on its own thread, and calls `hold(point)` on the copy's
`Handoff`. Returns `(outstanding, finished, values)`: whether the copy was
still outstanding when `hold` began, whether the second task had run by the
time `hold` returned, and the host values after it.
"""
function yield_order(gpu, n::Integer, spins::Integer, hold)
    out = Backends.on(fill(HOST_COPY_SENTINEL, n), gpu)
    src = Backends.on(fill(1.0, n), gpu)
    host = Backends.host_buffer(gpu, Float64, n)
    Backends.complete!(gpu)

    finished = Ref(false)
    waiter = @async begin
        Backends.launch!(host_copy_spin_kernel!, gpu, n, out, src, spins)
        point = Backends.copy_to_host!(host, out)
        other = @async (finished[] = true)
        outstanding = !CUDA.isdone(point.event)
        hold(point)
        seen = finished[]
        wait(other)
        Backends.complete!(gpu)
        (outstanding, seen, copy(host))
    end
    result = fetch(waiter)
    Backends.free_host_buffer!(host)
    return result
end

@testset "copy_to_host! queues a copy behind the kernels that wrote the array" begin
    @test CUDA.functional()

    gpu = Backends.GPU(1)
    cpu = Backends.CPU(1)
    n = 4
    spins = host_copy_spins(gpu, 0.25)
    first_values = fill(1.0 + Float64(spins), n)
    second_values = fill(2.0, n)

    # One pass over a one-spin kernel first, so that no check below runs this
    # file's first compilation of a method between a launch and a read.
    copied_values(gpu, n, 1; between = true)
    copied_values(gpu, n, 1; between = false)
    door_state(gpu, n, 1, Backends.copy_to_host!)
    door_state(gpu, n, 1, (host, out) -> (copyto!(host, Backends.on(out, cpu)); nothing))
    yield_order(gpu, n, 1, point -> Backends.after!(cpu, point))
    yield_order(gpu, n, 1, point -> CUDA.synchronize(point.event; blocking = true))

    @testset "(1) a copy queued between two kernels holds the first kernel's values" begin
        @test first_values != second_values
        @test copied_values(gpu, n, spins; between = true) == first_values

        @testset "positive control: the copy taken after the second kernel holds its values" begin
            held = copied_values(gpu, n, spins; between = false)
            @test held == second_values
            @test held != first_values
        end
    end

    @testset "(2) the door leaves the preceding kernel queued and returns before it finishes" begin
        queued, outstanding, values = door_state(gpu, n, spins, Backends.copy_to_host!)
        @test length(queued) == 1
        @test queued[1] === host_copy_spin_kernel!
        @test outstanding
        @test values == first_values

        @testset "positive control: a door built on on, which completes first, leaves nothing queued" begin
            on_door = (host, out) -> (copyto!(host, Backends.on(out, cpu)); nothing)
            queued_on, _, values_on = door_state(gpu, n, spins, on_door)
            @test isempty(queued_on)
            @test values_on == first_values
        end
    end

    @testset "(3) one move is counted per copy" begin
        pair = (:gpu, :cpu)
        count() = get(Events.move_counts(), pair, 0)
        copies = 3
        out = Backends.on(fill(1.0, n), gpu)
        host = Backends.host_buffer(gpu, Float64, n)

        before = count()
        for _ in 1:copies
            Backends.after!(cpu, Backends.copy_to_host!(host, out))
        end
        @test count() - before == copies
        @test host == fill(1.0, n)

        @testset "an array with no elements queues nothing and counts nothing" begin
            empty_device = Backends.on(Float64[], gpu)
            before_empty = count()
            point = Backends.copy_to_host!(Backends.host_buffer(gpu, Float64, 0), empty_device)
            @test point isa Backends.Handoff
            @test count() == before_empty
        end

        @testset "positive control: a copy that also moves through on counts two, which the check rejects" begin
            before_two = count()
            for _ in 1:copies
                Backends.after!(cpu, Backends.copy_to_host!(host, out))
                Backends.on(out, cpu)
            end
            @test count() - before_two == 2 * copies
            @test count() - before_two != copies
        end
        Backends.free_host_buffer!(host)
    end

    @testset "(4) a task waiting on the handoff yields its thread" begin
        outstanding, finished, values = yield_order(gpu, n, spins, point -> Backends.after!(cpu, point))
        @test outstanding
        @test finished
        @test values == first_values

        @testset "positive control: a wait that blocks its thread leaves the second task unfinished" begin
            blocked = point -> CUDA.synchronize(point.event; blocking = true)
            outstanding_b, finished_b, values_b = yield_order(gpu, n, spins, blocked)
            @test outstanding_b
            @test !finished_b
            @test values_b == first_values
        end
    end

    @testset "(5) a host that differs from the array refuses, naming what differs" begin
        out = Backends.on(collect(1.0:n), gpu)

        unpinned = host_copy_refusal(() -> Backends.copy_to_host!(Vector{Float64}(undef, n), out))
        @test unpinned isa Refusal
        @test unpinned.site == "Backends.copy_to_host!"
        @test occursin("not page-locked", unpinned.reason)

        narrow = Backends.host_buffer(gpu, Float32, n)
        wrong_type = host_copy_refusal(() -> Backends.copy_to_host!(narrow, out))
        @test wrong_type isa Refusal
        @test occursin("Float32", wrong_type.reason) && occursin("Float64", wrong_type.reason)
        Backends.free_host_buffer!(narrow)

        long = Backends.host_buffer(gpu, Float64, n + 3)
        wrong_length = host_copy_refusal(() -> Backends.copy_to_host!(long, out))
        @test wrong_length isa Refusal
        @test occursin("holds $(n + 3) elements", wrong_length.reason)
        @test occursin("holds $n", wrong_length.reason)
        Backends.free_host_buffer!(long)

        not_vector = host_copy_refusal(() -> Backends.copy_to_host!(zeros(2, 2), out))
        @test not_vector isa Refusal
        @test occursin("not a Vector", not_vector.reason)

        part = Backends.host_buffer(gpu, Float64, 2)
        not_cuarray = host_copy_refusal(() -> Backends.copy_to_host!(part, view(out, 1:2:n)))
        @test not_cuarray isa Refusal
        @test occursin("SubArray", not_cuarray.reason)
        Backends.free_host_buffer!(part)

        @testset "positive control: a page-locked host of the array's type and length copies" begin
            host = Backends.host_buffer(gpu, Float64, n)
            @test host_copy_refusal(() -> Backends.after!(cpu, Backends.copy_to_host!(host, out))) === nothing
            @test host == collect(1.0:n)

            grid = Backends.on([1.0 3.0; 2.0 4.0], gpu)
            Backends.after!(cpu, Backends.copy_to_host!(host, grid))
            @test host == [1.0, 2.0, 3.0, 4.0]

            @testset "free_host_buffer! releases the page lock, and the freed host refuses" begin
                @test CUDA.is_pinned(pointer(host))
                Backends.free_host_buffer!(host)
                @test !CUDA.is_pinned(pointer(host))
                freed = host_copy_refusal(() -> Backends.copy_to_host!(host, out))
                @test freed isa Refusal
                @test occursin("not page-locked", freed.reason)
                @test Backends.free_host_buffer!(host) === nothing
            end
        end

        @testset "host_buffer's shape" begin
            @test Backends.host_buffer(gpu, Float32, 0) == Float32[]
            @test Backends.host_buffer(cpu, Float32, 3) isa Vector{Float32}
            @test length(Backends.host_buffer(cpu, Float32, 3)) == 3
            below = host_copy_refusal(() -> Backends.host_buffer(gpu, Float64, -1))
            @test below isa Refusal && occursin("below zero", below.reason)
            boxed = host_copy_refusal(() -> Backends.host_buffer(cpu, String, 2))
            @test boxed isa Refusal && occursin("not a bits type", boxed.reason)
        end
    end

    @testset "(5) on CPU the host holds the values at the call" begin
        array = collect(1.0:n)
        host = Backends.host_buffer(cpu, Float64, n)
        before = Events.move_counts()

        point = Backends.copy_to_host!(host, array)
        @test host == collect(1.0:n)
        @test point.event === nothing
        @test Events.move_counts() == before

        @testset "positive control: a write after the call does not reach the host" begin
            # A door that held `array` and copied at the wait would hold the
            # zeros written here.
            fill!(array, 0.0)
            @test Backends.after!(cpu, point) === nothing
            @test host == collect(1.0:n)
            @test host != array
        end

        @testset "an unpinned host is taken for a host array" begin
            plain = Vector{Float64}(undef, n)
            @test host_copy_refusal(() -> Backends.copy_to_host!(plain, collect(1.0:n))) === nothing
            @test plain == collect(1.0:n)
        end
    end
end
