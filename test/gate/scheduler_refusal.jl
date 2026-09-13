using Test

# gate.sh refuses when SLURM_JOB_ID is set and reaches qrun when it is not,
# against a stand-in qrun on PATH.

const GATE_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const GATE_SCRIPT = joinpath(GATE_ROOT, "tools", "gate", "gate.sh")

"""
    stand_in_qrun(record_file)

A shell script that records its arguments to record_file and exits 0.
"""
function stand_in_qrun(record_file::AbstractString)
    return "#!/bin/sh\necho \"\$@\" >> \"$record_file\"\nexit 0\n"
end

@testset "gate.sh scheduler refusal" begin
    @testset "positive control: gate.sh refuses with SLURM_JOB_ID set, before calling qrun" begin
        tmpdir = mktempdir()
        try
            qrun_record = joinpath(tmpdir, "qrun_calls")
            qrun_script = joinpath(tmpdir, "qrun")

            write(qrun_script, stand_in_qrun(qrun_record))
            chmod(qrun_script, 0o755)

            withenv("SLURM_JOB_ID" => "12345",
                    "PATH" => tmpdir * ":" * get(ENV, "PATH", "")) do
                stderr_capture = IOBuffer()
                cmd = Cmd(`$GATE_SCRIPT`; dir = GATE_ROOT)
                exit_succeeded = success(pipeline(cmd; stderr = stderr_capture))
                @test !exit_succeeded

                # The stand-in qrun should not have been called
                @test !isfile(qrun_record)

                # Stderr should name the refusal
                stderr_text = String(take!(stderr_capture))
                @test occursin("submits its own job", stderr_text)
                @test occursin("run directly", stderr_text)
            end
        finally
            rm(tmpdir; recursive = true, force = true)
        end
    end

    @testset "gate.sh calls qrun without SLURM_JOB_ID" begin
        tmpdir = mktempdir()
        try
            qrun_record = joinpath(tmpdir, "qrun_calls")
            qrun_script = joinpath(tmpdir, "qrun")

            write(qrun_script, stand_in_qrun(qrun_record))
            chmod(qrun_script, 0o755)

            withenv("SLURM_JOB_ID" => nothing,
                    "PATH" => tmpdir * ":" * get(ENV, "PATH", "")) do
                stderr_capture = IOBuffer()
                cmd = Cmd(`$GATE_SCRIPT`; dir = GATE_ROOT)
                @test success(pipeline(cmd; stderr = stderr_capture))

                # The stand-in qrun should have been called exactly once
                @test isfile(qrun_record)
                content = read(qrun_record, String)
                calls = strip.(split(strip(content), "\n"))
                # Filter out empty lines
                calls = filter(!isempty, calls)
                @test length(calls) == 1
                @test occursin("-p gpu-share", calls[1])
            end
        finally
            rm(tmpdir; recursive = true, force = true)
        end
    end
end
