using Test
using CUDA
using KernelAbstractions: @kernel, @index
using Fiddlybits: Backends, Verdicts

# Backends.launch_workgroup is the one door a launch's workgroup size is chosen at
# (docs/decisions/0058-a-launch-workgroup-is-chosen-per-launch-from-the-work-item-count.md).
# A pinned backend launches at its pin; an unpinned CPU backend at 1; an unpinned GPU
# backend at the smallest power of two that keeps the block count within the card's
# GPU_BLOCKS_AT_ONCE entry, and never past the card's warp size.

@kernel function launch_workgroup_fill!(out)
    i = @index(Global)
    out[i] = Float64(i)
end

@testset "Backends.launch_workgroup" begin
    @testset "a pinned backend launches at its pin, whatever the work item count" begin
        for backend in (Backends.CPU(16), Backends.GPU(16), Backends.CPU(3; bitwise = true))
            @test Backends.launch_workgroup(backend, 1) == Backends.workgroup(backend)
            @test Backends.launch_workgroup(backend, 10^6) == Backends.workgroup(backend)
        end
        @test Backends.workgroup(Backends.GPU()) === nothing
        @test Backends.workgroup(Backends.CPU()) === nothing
    end

    @testset "a backend is plain data a kernel can take as an argument" begin
        for backend in (Backends.CPU(), Backends.GPU(), Backends.CPU(8), Backends.GPU(64; bitwise = true))
            @test isbits(backend)
        end
    end

    @testset "a pin below 1 refuses" begin
        for (make, site) in ((Backends.CPU, "Backends.CPU"), (Backends.GPU, "Backends.GPU")), w in (0, -4)
            caught = try
                make(w)
                nothing
            catch err
                err
            end
            @test caught isa Verdicts.Refusal
            @test caught.site == site
            @test occursin("workgroup $w", caught.reason)
        end

        @testset "positive control: a pin of 1 is a pin" begin
            @test Backends.workgroup(Backends.GPU(1)) == 1
            @test Backends.launch_workgroup(Backends.GPU(1), 10^6) == 1
        end
    end

    @testset "at_workgroup pins and keeps the kind and the bitwise flag" begin
        for backend in (Backends.CPU(), Backends.GPU(; bitwise = true), Backends.GPU(8))
            pinned = Backends.at_workgroup(backend, 64)
            @test typeof(pinned) === typeof(backend)
            @test Backends.workgroup(pinned) == 64
            @test Backends.bitwise(pinned) == Backends.bitwise(backend)
        end
    end

    @testset "an unpinned CPU backend launches one work item per block" begin
        for n in (1, 7, 80, 327680)
            @test Backends.launch_workgroup(Backends.CPU(), n) == 1
        end
    end

    @testset "the GPU rule: the fewest threads per block within the block bound, capped at the warp" begin
        warp, blocks = 32, 128
        rule(n) = Backends.gpu_launch_workgroup(n, warp, blocks)
        @test rule(0) == 1
        @test rule(1) == 1
        @test rule(blocks) == 1
        @test rule(blocks + 1) == 2
        @test rule(2blocks) == 2
        @test rule(2blocks + 1) == 4
        @test rule(16blocks + 1) == warp
        @test rule(warp * blocks) == warp
        @test rule(warp * blocks + 1) == warp
        @test rule(10^9) == warp
        for n in (1, 5, 127, 128, 129, 1280, 5120, 20480, 81920)
            w = rule(n)
            @test ispow2(w) && w <= warp
            @test w == warp || cld(n, w) <= blocks
            @test w == 1 || cld(n, w ÷ 2) > blocks
        end

        @testset "positive control: a warp that is not a power of two still caps" begin
            @test Backends.gpu_launch_workgroup(10^6, 24, blocks) == 24
            @test Backends.gpu_launch_workgroup(10^6, 32, blocks) != 24
        end
    end

    @testset "the launch shape packs into one Int and back" begin
        for (id, warp, blocks) in ((0, 32, 128), (3, 1024, 1), (0, 2^20 - 1, 2^20 - 1))
            @test Backends.unpack_launch_shape(Backends.pack_launch_shape(id, warp, blocks)) == (id, warp, blocks)
        end
        @test Backends.unpack_launch_shape(0)[1] == -1

        @testset "positive control: a value that does not fit refuses" begin
            @test_throws Verdicts.Refusal Backends.pack_launch_shape(0, 2^20, 128)
            @test_throws Verdicts.Refusal Backends.pack_launch_shape(0, 32, 0)
            @test_throws Verdicts.Refusal Backends.pack_launch_shape(-1, 32, 128)
        end
    end

    @testset "a card with no measured block count refuses, naming it" begin
        caught = try
            Backends.gpu_blocks_at_once("a card nobody measured")
            nothing
        catch err
            err
        end
        @test caught isa Verdicts.Refusal
        @test caught.site == "Backends.launch_workgroup"
        @test occursin("a card nobody measured", caught.reason)

        @testset "positive control: the card this suite runs on is measured" begin
            @test CUDA.functional()
            @test Backends.gpu_blocks_at_once(CUDA.name(CUDA.device())) isa Int
        end
    end

    @testset "launch! launches at launch_workgroup, and queued_launches records it" begin
        @test CUDA.functional()
        warp, blocks = Backends.gpu_launch_shape()
        @test warp == CUDA.warpsize(CUDA.device())
        @test blocks == Backends.GPU_BLOCKS_AT_ONCE[CUDA.name(CUDA.device())]

        gpu = Backends.GPU()
        for n in (1, blocks + 1, 4blocks + 1, 64 * warp * blocks)
            out = CUDA.zeros(Float64, n)
            Backends.complete!(gpu)
            Backends.launch!(launch_workgroup_fill!, gpu, n, out)
            launches = Backends.queued_launches(gpu)
            Backends.complete!(gpu)
            @test launches == [(kernel = launch_workgroup_fill!, workgroup = Backends.gpu_launch_workgroup(n, warp, blocks), n = n)]
            @test Array(out) == Float64.(1:n)
        end

        @testset "positive control: a pinned launch records its pin, not the rule" begin
            n = 4blocks + 1
            out = CUDA.zeros(Float64, n)
            Backends.complete!(gpu)
            Backends.launch!(launch_workgroup_fill!, Backends.GPU(256), n, out)
            launches = Backends.queued_launches(gpu)
            Backends.complete!(gpu)
            @test only(launches).workgroup == 256
            @test only(launches).workgroup != Backends.gpu_launch_workgroup(n, warp, blocks)
        end
    end
end
