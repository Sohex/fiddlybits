using Test
using CUDA
using Fiddlybits: Backends

# adapt_for(x, CPU) completes only the device arrays x actually carries, through the
# same complete! test Backends.on uses at each array it reads, rather than draining
# the whole device before it starts: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer", and decision 0038 on stages that are not separated by a barrier.
#
# spin_write_kernel!, calibrated_spins and elapsed come from launch_completion.jl,
# included before this file in runtests.jl.

@testset "adapt_for(x, CPU) follows the arrays it actually moves" begin
    @test CUDA.functional()

    gpu = Backends.GPU(1)
    cpu = Backends.CPU(1)
    spins = calibrated_spins(gpu, 0.2)

    @testset "a host-resident structure completes nothing" begin
        out = Backends.on(fill(SPIN_SENTINEL, 1), gpu)
        src = Backends.on([1.0], gpu)

        whole = elapsed() do
            Backends.launch!(spin_write_kernel!, gpu, 1, out, src, spins)
            Backends.complete!(gpu)
        end

        host_only = (data = [1.0, 2.0, 3.0],)
        Backends.launch!(spin_write_kernel!, gpu, 1, out, src, spins)
        there = nothing
        t_adapt = elapsed(() -> there = Backends.adapt_for(host_only, cpu))

        @test t_adapt < whole / 10
        @test there.data == host_only.data

        @testset "positive control: the kernel queued before the call is left running" begin
            @test !isempty(Backends.queued(gpu))
        end

        Backends.complete!(gpu)
        @test isempty(Backends.queued(gpu))
    end

    @testset "a structure holding a device array reads what its kernel finished writing" begin
        # No pause sits between launch! and adapt_for, and spins is calibrated to
        # keep the kernel running for a target well above either call's own
        # overhead, so the kernel is still writing out when adapt_for starts.
        out = Backends.on(fill(SPIN_SENTINEL, 1), gpu)
        src = Backends.on([1.0], gpu)
        expected = [1.0 + Float64(spins)]

        Backends.launch!(spin_write_kernel!, gpu, 1, out, src, spins)
        @test !isempty(Backends.queued(gpu))

        device_holder = (data = out,)
        there = Backends.adapt_for(device_holder, cpu)

        @test there.data isa Array
        @test there.data == expected
        @test isempty(Backends.queued(gpu))

        @testset "positive control: a kernel still writing is what the wait is for" begin
            # queued(gpu) was non-empty just before adapt_for ran: nothing had
            # waited for the kernel writing out yet, and adapt_for read the
            # finished value regardless.
            @test expected != fill(SPIN_SENTINEL, 1)
        end
    end

    @testset "an empty device array is placed with nothing to wait for" begin
        empty_out = Backends.on(Float64[], gpu)
        there = Backends.adapt_for((data = empty_out,), cpu)
        @test there.data isa Array
        @test isempty(there.data)
    end
end
