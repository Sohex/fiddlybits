using Test
using CUDA

# A kernel that faults on the device raises at complete!, not at its launch,
# because the launch no longer waits for it. The refusal names the kernels
# queued since the last completion, which for a single launch is that launch.
#
# A device fault leaves the CUDA context unusable, so each arm runs in a fresh
# process and the parent reads what it printed.

const FAULT_PROJECT = normpath(joinpath(@__DIR__, "..", ".."))

"""
    run_fault(offset)

The output of a process that queues one kernel writing at `out[i + offset]`
over four work items on a four-element array and then calls
`Backends.complete!`. `offset` of zero is in range; anything positive is not.
"""
function run_fault(offset::Integer)
    code = """
        using CUDA
        using KernelAbstractions: @kernel, @index
        using Fiddlybits: Backends
        using Fiddlybits.Verdicts: Refusal

        @kernel function out_of_range_kernel!(out, offset)
            i = @index(Global)
            out[i + offset] = 1.0
        end

        gpu = Backends.GPU(1)
        out = Backends.on(zeros(Float64, 4), gpu)
        Backends.launch!(out_of_range_kernel!, gpu, 4, out, $(Int(offset)))
        println("LAUNCH RETURNED")
        try
            Backends.complete!(gpu)
            println("COMPLETED WITHOUT REFUSAL")
        catch err
            err isa Refusal || rethrow()
            println("REFUSED AT ", err.site, " :: ", err.reason)
        end
    """
    cmd = `julia --startup-file=no --project=$FAULT_PROJECT -e $code`
    return read(pipeline(ignorestatus(cmd); stderr = devnull), String)
end

@testset "a device fault refuses at complete!, naming the kernel" begin
    @test CUDA.functional()

    faulted = run_fault(4)
    @test occursin("LAUNCH RETURNED", faulted)
    @test occursin("REFUSED AT Backends.complete!", faulted)
    @test occursin("out_of_range_kernel!", faulted)

    @testset "positive control: the same kernel in range completes" begin
        clean = run_fault(0)
        @test occursin("LAUNCH RETURNED", clean)
        @test occursin("COMPLETED WITHOUT REFUSAL", clean)
        @test !occursin("REFUSED AT", clean)
    end
end
