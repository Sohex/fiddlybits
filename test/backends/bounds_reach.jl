using Test
using CUDA

# backends.bounds_checks_reach_kernels: which bounds checks a kernel launched through
# `Backends.launch!` compiles, on the CPU backend and on the card, under the default
# configuration and under `--check-bounds=yes`. Decision 0055 rests on it;
# notes/findings/2026-09-13-check-bounds-reaches-kernels-on-the-card.md has the whole
# table, including the reads this file does not repeat.
#
# The probe kernels are tools/gate/bounds_probe.jl, which the gate and the nightly also
# run before a pass under the flag. Each configuration runs in its own process with its
# flag stated rather than inherited, and a read that raises on the card is the last arm
# of its process.
#
# What is read:
# - the marker arms, which read nothing out of range, give elided under the default and
#   checked under the flag; they are the control that the flag is what makes an
#   `@inbounds` read raise;
# - reads past the end and below index 1 that raise, under the flag with `@inbounds` and
#   under the default without it;
# - index 0 of a view, which is the parent's element before the view, so the read stays
#   inside allocated memory: the card reads it without raising in both configurations,
#   and the CPU backend raises under the flag.
# No `@inbounds` read under the default configuration leaves its array.

module BoundsReach
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")), "tools", "gate", "run.jl"))
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")), "tools", "gate", "bounds_probe.jl"))
end

const BOUNDS_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

@testset "backends.bounds_checks_reach_kernels" begin
    @test CUDA.functional()

    default_arms = ["marker_cpu", "marker_gpu", "read_checked_cpu", "zero_checked_cpu",
                    "view_checked_cpu", "view_checked_gpu", "read_checked_gpu"]
    flagged_arms = ["marker_cpu", "marker_gpu", "read_inbounds_cpu", "zero_inbounds_cpu",
                    "negative_inbounds_cpu", "view_inbounds_cpu", "view_inbounds_gpu",
                    "read_inbounds_gpu"]
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

    @testset "under the default @boundscheck blocks under @inbounds are elided" begin
        @test default["check_bounds"] == 0
        @test default["marker_cpu"] == "elided"
        @test default["marker_gpu"] == "elided"

        @testset "a read without @inbounds raises past the end on both backends" begin
            @test default["read_checked_cpu"] == "raised at launch"
            @test occursin("BoundsError", default["read_checked_cpu_detail"])
            @test default["read_checked_gpu"] == "raised at completion"
            @test occursin("KernelException", default["read_checked_gpu_detail"])
            @test occursin("read_past_checked!", default["read_checked_gpu_detail"])
        end

        @testset "below index 1 the CPU backend raises and the card does not check" begin
            @test default["zero_checked_cpu"] == "raised at launch"
            @test occursin("index [0]", default["zero_checked_cpu_detail"])
            @test default["view_checked_cpu"] == "raised at launch"
            @test default["view_checked_gpu"] == "silent"
            @test occursin("[4.0, 5.0, 6.0, 7.0]", default["view_checked_gpu_detail"])
        end
    end

    @testset "under --check-bounds=yes" begin
        @test flagged["check_bounds"] == 1
        @test flagged["marker_cpu"] == "checked"
        @test flagged["marker_gpu"] == "checked"

        @testset "an @inbounds read past the end raises on both backends" begin
            @test flagged["read_inbounds_cpu"] == "raised at launch"
            @test occursin("BoundsError", flagged["read_inbounds_cpu_detail"])
            @test flagged["read_inbounds_gpu"] == "raised at completion"
            @test occursin("KernelException", flagged["read_inbounds_gpu_detail"])
            @test occursin("read_past_inbounds!", flagged["read_inbounds_gpu_detail"])
        end

        @testset "an @inbounds read below index 1 raises on the CPU backend" begin
            @test flagged["zero_inbounds_cpu"] == "raised at launch"
            @test occursin("index [0]", flagged["zero_inbounds_cpu_detail"])
            @test flagged["negative_inbounds_cpu"] == "raised at launch"
            @test occursin("index [-7]", flagged["negative_inbounds_cpu_detail"])
            @test flagged["view_inbounds_cpu"] == "raised at launch"
            @test occursin("index [0]", flagged["view_inbounds_cpu_detail"])
        end

        @testset "and the card reads index 0 of a view without raising" begin
            @test flagged["view_inbounds_gpu"] == "silent"
            @test occursin("[4.0, 5.0, 6.0, 7.0]", flagged["view_inbounds_gpu_detail"])
        end
    end
end
