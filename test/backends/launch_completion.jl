using Test
using CUDA
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits: Backends
using Fiddlybits.Verdicts: Refusal

# launch! queues a kernel and returns; complete! is where a host waits for it,
# and Backends.on calls complete! before it copies device memory to the host:
# docs/plans/fiddlybits-52v.7-kernels.md, section "The device layer", and
# decision 0038 on stages that are not separated by a barrier.
#
# The checks below are timing checks and a race demonstration, because that is
# what the property is. They run one work item over a spin whose length is a
# runtime argument, so the loop cannot be folded away: the kernel adds 1.0 to
# an accumulator `spins` times, which is exactly Float64(spins) for every
# `spins` below 2^53, and writes src[i] + that.

const SPIN_SENTINEL = -7.0

@kernel function spin_write_kernel!(out, @Const(src), spins)
    i = @index(Global)
    acc = zero(eltype(out))
    for _ in 1:spins
        acc += one(eltype(out))
    end
    out[i] = src[i] + acc
end

@kernel function double_kernel!(out, @Const(src))
    i = @index(Global)
    out[i] = src[i] + src[i]
end

"The elapsed seconds of `f()`, discarding its value."
elapsed(f) = (t = time(); f(); time() - t)

"""
    calibrated_spins(backend, target)

The `spins` argument that makes `spin_write_kernel!` take at least `target`
seconds on `backend` over one work item, found by doubling from a compiled
starting point rather than assumed from a clock rate.
"""
function calibrated_spins(backend, target::Real)
    out = Backends.on(fill(SPIN_SENTINEL, 1), backend)
    src = Backends.on([1.0], backend)
    Backends.launch!(spin_write_kernel!, backend, 1, out, src, 1)
    Backends.complete!(backend)
    spins = 1 << 16
    for _ in 1:40
        t = elapsed() do
            Backends.launch!(spin_write_kernel!, backend, 1, out, src, spins)
            Backends.complete!(backend)
        end
        t >= target && return spins
        spins *= 2
    end
    return spins
end

@testset "launch! queues and complete! waits" begin
    @test CUDA.functional()

    gpu = Backends.GPU(1)
    cpu = Backends.CPU(1)
    # Long enough that the host-side scatter these checks sit in, a garbage
    # collection or another job's turn on a shared card, stays well under the
    # fractions of it asserted below.
    spins = calibrated_spins(gpu, 0.2)

    @testset "launch! returns before the kernel has finished, complete! after" begin
        out = Backends.on(fill(SPIN_SENTINEL, 1), gpu)
        src = Backends.on([1.0], gpu)

        # elapsed compiles a specialization for every closure it is handed,
        # and that compilation is tens of milliseconds, longer than the kernel
        # below. Each shape is therefore written once and run twice: once over
        # a one-spin kernel to compile it, then over the calibrated one to
        # measure it. Compiled between t_launch and t_complete instead, the
        # kernel finishes while the compiler runs and the completion measures
        # nothing.
        held = Ref(1)
        chain() = (Backends.launch!(spin_write_kernel!, gpu, 1, out, src, held[]);
                   Backends.complete!(gpu))
        queue() = Backends.launch!(spin_write_kernel!, gpu, 1, out, src, held[])
        finish() = Backends.complete!(gpu)

        elapsed(chain)
        elapsed(queue)
        elapsed(finish)

        held[] = spins
        whole = elapsed(chain)
        t_launch = elapsed(queue)
        t_complete = elapsed(finish)

        @test t_launch < whole / 10
        @test t_complete > whole / 2

        @testset "positive control: a launch that waits is seen by the same check" begin
            # The CPU backend's launch runs every work item before it returns,
            # so it is the shape this check has to be able to reject: were the
            # barrier back in launch!, the GPU numbers above would look like
            # these.
            cpu_spins = calibrated_spins(cpu, 0.05)
            out_cpu = fill(SPIN_SENTINEL, 1)
            src_cpu = [1.0]
            whole_cpu = elapsed() do
                Backends.launch!(spin_write_kernel!, cpu, 1, out_cpu, src_cpu, cpu_spins)
                Backends.complete!(cpu)
            end
            t_launch_cpu = elapsed(() ->
                Backends.launch!(spin_write_kernel!, cpu, 1, out_cpu, src_cpu, cpu_spins))
            @test !(t_launch_cpu < whole_cpu / 10)
        end
    end

    @testset "queued records what launch! queued and complete! empties it" begin
        out = Backends.on(fill(SPIN_SENTINEL, 4), gpu)
        src = Backends.on(fill(1.0, 4), gpu)

        Backends.complete!(gpu)
        @test isempty(Backends.queued(gpu))

        Backends.launch!(double_kernel!, gpu, 4, out, src)
        Backends.launch!(double_kernel!, gpu, 4, out, src)
        @test length(Backends.queued(gpu)) == 2

        Backends.complete!(gpu)
        @test isempty(Backends.queued(gpu))

        @testset "the CPU backend keeps no record" begin
            out_cpu = fill(SPIN_SENTINEL, 4)
            src_cpu = fill(1.0, 4)
            Backends.launch!(double_kernel!, cpu, 4, out_cpu, src_cpu)
            @test isempty(Backends.queued(cpu))
        end
    end

    @testset "a read through Backends.on waits for the kernel that wrote it" begin
        n = 4
        out = Backends.on(fill(SPIN_SENTINEL, n), gpu)
        src = Backends.on(fill(1.0, n), gpu)
        expected = fill(1.0 + Float64(spins), n)

        whole = elapsed() do
            Backends.launch!(spin_write_kernel!, gpu, n, out, src, spins)
            Backends.complete!(gpu)
        end

        read_back = nothing
        t_read = elapsed() do
            Backends.launch!(spin_write_kernel!, gpu, n, out, src, spins)
            read_back = Backends.on(out, cpu)
        end

        @test read_back == expected
        @test read_back != fill(SPIN_SENTINEL, n)
        @test t_read > whole / 2

        @testset "positive control: a read with no ordering sees the unfinished write" begin
            # The copy below is issued on a stream of its own with no
            # dependency on the kernel's, which is what Backends.on refuses to
            # do. It is a race, so it is scored over repeats: one stale read
            # is what makes the check above a check.
            stale = 0
            for _ in 1:5
                Backends.complete!(gpu)
                fill!(out, SPIN_SENTINEL)
                Backends.complete!(gpu)
                host = Vector{Float64}(undef, n)
                CUDA.pin(host)
                ptr = pointer(out)
                other = CUDA.CuStream()
                Backends.launch!(spin_write_kernel!, gpu, n, out, src, spins)
                GC.@preserve out host begin
                    unsafe_copyto!(pointer(host), ptr, n; stream = other, async = true)
                end
                CUDA.synchronize(other)
                all(host .== SPIN_SENTINEL) && (stale += 1)
                Backends.complete!(gpu)
            end
            @test stale > 0
        end
    end

    @testset "two launches chain in order with no completion between them" begin
        n = 4
        first_out = Backends.on(fill(SPIN_SENTINEL, n), gpu)
        second_out = Backends.on(fill(SPIN_SENTINEL, n), gpu)
        src = Backends.on(fill(1.0, n), gpu)

        Backends.launch!(spin_write_kernel!, gpu, n, first_out, src, spins)
        Backends.launch!(double_kernel!, gpu, n, second_out, first_out)
        read_back = Backends.on(second_out, cpu)

        expected = fill(2 * (1.0 + Float64(spins)), n)
        @test read_back == expected

        @testset "positive control: the wrong order is a different answer" begin
            # Had the second kernel read first_out before the first kernel
            # wrote it, it would have doubled the sentinel, which is not the
            # answer asserted above.
            @test expected != fill(2 * SPIN_SENTINEL, n)
        end
    end

    @testset "a failed wait refuses naming the kernels queued since the last completion" begin
        out = Backends.on(fill(SPIN_SENTINEL, 4), gpu)
        src = Backends.on(fill(1.0, 4), gpu)
        Backends.complete!(gpu)

        Backends.launch!(double_kernel!, gpu, 4, out, src)
        Backends.launch!(spin_write_kernel!, gpu, 4, out, src, 1)
        raised = try
            Backends.wait_queued(() -> error("the device reported a fault"))
            nothing
        catch err
            err
        end

        @test raised isa Refusal
        @test raised.site == "Backends.complete!"
        @test occursin("double_kernel!", raised.reason)
        @test occursin("spin_write_kernel!", raised.reason)
        @test occursin("the device reported a fault", raised.reason)
        @test isempty(Backends.queued(gpu))

        @testset "positive control: a wait that returns refuses nothing" begin
            Backends.launch!(double_kernel!, gpu, 4, out, src)
            @test Backends.wait_queued(() -> nothing) === nothing
            @test isempty(Backends.queued(gpu))
        end

        Backends.complete!(gpu)
    end
end
