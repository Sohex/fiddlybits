using Test
using CUDA

# A kernel that faults on the device raises at complete!, not at its launch,
# because the launch no longer waits for it. The refusal names the kernels
# queued since the last completion, which for a single launch is that launch.
#
# A kernel that faults before a queued host copy is raised by complete! on the
# task that queued both, and not by after!(CPU(), point) on a second task
# waiting on the copy's handoff: docs/imports/cuda.md, section "Page-locked
# memory and the queued copy". The two tasks are ordered by fetch; nothing
# here sleeps.
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

"""
    run_handoff_fault(offset; check_flag)

The output of a process in which the submitting task queues the kernel of
`run_fault` and then `Backends.copy_to_host!` of its array into a
`Backends.host_buffer`, and an `@async` waiter task calls
`Backends.after!(CPU(), point)` on the copy's handoff. With `check_flag` the
waiter then reads CUDA's kernel-exception flag through CUDACore's
`check_exceptions`. The submitting task fetches the waiter's outcome, prints
it, calls `Backends.complete!` for the backend, and prints the host buffer.
"""
function run_handoff_fault(offset::Integer; check_flag::Bool)
    check = check_flag ? "CUDA.CUDACore.check_exceptions()" : "nothing"
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
        cpu = Backends.CPU(1)
        out = Backends.on(zeros(Float64, 4), gpu)
        host = Backends.host_buffer(gpu, Float64, 4)
        Backends.complete!(gpu)

        Backends.launch!(out_of_range_kernel!, gpu, 4, out, $(Int(offset)))
        point = Backends.copy_to_host!(host, out)
        println("COPY QUEUED")

        waiter = @async try
            Backends.after!(cpu, point)
            $check
            "WAITER RETURNED WITHOUT REFUSAL"
        catch err
            "WAITER RAISED " * sprint(showerror, err)
        end
        println(fetch(waiter))

        try
            Backends.complete!(gpu)
            println("SUBMITTER COMPLETED WITHOUT REFUSAL")
        catch err
            err isa Refusal || rethrow()
            println("SUBMITTER REFUSED AT ", err.site, " :: ", err.reason)
        end
        println("HOST ", host)
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

@testset "a fault before a queued host copy is raised by complete! on the submitting task, not by after!" begin
    @test CUDA.functional()

    faulted = run_handoff_fault(4; check_flag = false)
    @test occursin("COPY QUEUED", faulted)
    @test occursin("WAITER RETURNED WITHOUT REFUSAL", faulted)
    @test !occursin("WAITER RAISED", faulted)
    @test occursin("SUBMITTER REFUSED AT Backends.complete! :: KernelException", faulted)
    @test occursin("out_of_range_kernel!", faulted)

    @testset "control: the same kernel in range returns cleanly from both waits" begin
        clean = run_handoff_fault(0; check_flag = false)
        @test occursin("COPY QUEUED", clean)
        @test occursin("WAITER RETURNED WITHOUT REFUSAL", clean)
        @test occursin("SUBMITTER COMPLETED WITHOUT REFUSAL", clean)
        @test !occursin("REFUSED AT", clean)
        @test occursin("HOST [1.0, 1.0, 1.0, 1.0]", clean)
    end

    @testset "positive control: a waiter that reads the flag after after! takes the fault from the submitter" begin
        taken = run_handoff_fault(4; check_flag = true)
        @test occursin("COPY QUEUED", taken)
        @test occursin("WAITER RAISED KernelException", taken)
        @test occursin("SUBMITTER COMPLETED WITHOUT REFUSAL", taken)
        @test !occursin("SUBMITTER REFUSED AT", taken)
    end
end
