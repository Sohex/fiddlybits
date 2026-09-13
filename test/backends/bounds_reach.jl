using Test
using CUDA

# backends.bounds_checks_reach_kernels: what `--check-bounds=yes` does to a kernel
# launched through `Backends.launch!` under `@inbounds`, on the CPU backend and on the
# card, against the default. Decision 0055 rests on it;
# notes/findings/2026-09-13-check-bounds-reaches-kernels-on-the-card.md has the table.
#
# The probe kernels are tools/gate/bounds_probe.jl, which the gate and the nightly also
# run before a pass under the flag. Each configuration runs in its own process, with
# its flag stated rather than inherited, and a read that raises on the card is the last
# arm of its process.

module BoundsReach
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")), "tools", "gate", "run.jl"))
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")), "tools", "gate", "bounds_probe.jl"))
end

const BOUNDS_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

@testset "backends.bounds_checks_reach_kernels" begin
    @test CUDA.functional()

    default_arms = ["marker_cpu", "marker_gpu", "read_inbounds_cpu", "read_checked_cpu",
                    "read_inbounds_gpu", "read_checked_gpu"]
    flagged_arms = ["marker_cpu", "marker_gpu", "read_inbounds_cpu", "read_inbounds_gpu"]
    default_run = Threads.@spawn BoundsReach.run_probe(BOUNDS_ROOT, `--check-bounds=auto`,
                                                      default_arms)
    flagged_run = Threads.@spawn BoundsReach.run_probe(BOUNDS_ROOT, `--check-bounds=yes`,
                                                      flagged_arms)

    @testset "the kernels this process compiles follow its own flag" begin
        expected = Base.JLOptions().check_bounds == 1 ? "checked" : "elided"
        cpu = first(BoundsReach.BoundsProbe.run_arm("marker_cpu"))
        gpu = first(BoundsReach.BoundsProbe.run_arm("marker_gpu"))
        println("backends: check_bounds = ", Base.JLOptions().check_bounds,
                "; bounds checks in kernels under @inbounds: cpu ", cpu, ", gpu ", gpu)
        @test cpu == expected
        @test gpu == expected
    end

    default = fetch(default_run)
    flagged = fetch(flagged_run)

    @testset "under the default an @inbounds read past the end is silent" begin
        @test default["check_bounds"] == 0
        @test default["marker_cpu"] == "elided"
        @test default["marker_gpu"] == "elided"
        @test default["read_inbounds_cpu"] == "silent"
        @test default["read_inbounds_gpu"] == "silent"

        @testset "positive control: the same read without @inbounds raises" begin
            @test default["read_checked_cpu"] == "raised at launch"
            @test occursin("BoundsError", default["read_checked_cpu_detail"])
            @test default["read_checked_gpu"] == "raised at completion"
            @test occursin("KernelException", default["read_checked_gpu_detail"])
            @test occursin("read_past_checked!", default["read_checked_gpu_detail"])
        end
    end

    @testset "under --check-bounds=yes the @inbounds read raises on both backends" begin
        @test flagged["check_bounds"] == 1
        @test flagged["marker_cpu"] == "checked"
        @test flagged["marker_gpu"] == "checked"
        @test flagged["read_inbounds_cpu"] == "raised at launch"
        @test occursin("BoundsError", flagged["read_inbounds_cpu_detail"])
        @test flagged["read_inbounds_gpu"] == "raised at completion"
        @test occursin("KernelException", flagged["read_inbounds_gpu_detail"])
        @test occursin("read_past_inbounds!", flagged["read_inbounds_gpu_detail"])
    end
end
