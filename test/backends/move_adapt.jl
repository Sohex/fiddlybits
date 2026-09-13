using Test
using CUDA
using Fiddlybits: Backends

# adapt_for(x, CPU) completes only the device arrays x actually carries, through the
# same complete! test Backends.on uses at each array it reads:
# docs/plans/fiddlybits-52v.7-kernels.md, section "The device layer".
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

        @testset "positive control: a read with no ordering sees the unfinished write" begin
            # The copy below is issued on a stream of its own with no
            # dependency on the kernel's, which is what adapt_for's completion
            # refuses to do. It is a race, so it is scored over repeats: one
            # stale read is what makes the check above a check.
            stale = 0
            for _ in 1:5
                Backends.complete!(gpu)
                fill!(out, SPIN_SENTINEL)
                Backends.complete!(gpu)
                host = Vector{Float64}(undef, 1)
                CUDA.pin(host)
                ptr = pointer(out)
                other = CUDA.CuStream()
                Backends.launch!(spin_write_kernel!, gpu, 1, out, src, spins)
                GC.@preserve out host begin
                    unsafe_copyto!(pointer(host), ptr, 1; stream = other, async = true)
                end
                CUDA.synchronize(other)
                all(host .== SPIN_SENTINEL) && (stale += 1)
                Backends.complete!(gpu)
            end
            println("stale reads: ", stale, " of 5 trials")
            @test stale > 0
        end
    end

    @testset "an empty device array is placed with nothing to wait for" begin
        empty_out = Backends.on(Float64[], gpu)
        there = Backends.adapt_for((data = empty_out,), cpu)
        @test there.data isa Array
        @test isempty(there.data)
    end
end
