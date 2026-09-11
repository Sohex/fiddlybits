using Test

# The answers: rule of decision 0029, and the reference record it reads.

include(joinpath(@__DIR__, "..", "..", "tools", "gate", "answers.jl"))

const A = "a" ^ 64
const B = "b" ^ 64

@testset "gate" begin
    @testset "the rule decides on four strings" begin
        # Nothing staged to judge.
        @test Answers.verdict(computed = A, staged = "", head = A, message = "") === :no_hash

        # The record disagrees with what the code produces.
        @test Answers.verdict(computed = A, staged = B, head = B, message = "") === :stale_record
        @test Answers.verdict(computed = A, staged = B, head = B,
                              message = "answers: a mechanism") === :stale_record

        # The record is new in this commit, which is not a change to declare.
        @test Answers.verdict(computed = A, staged = A, head = "", message = "") === :ok

        # Unmoved.
        @test Answers.verdict(computed = A, staged = A, head = A, message = "") === :ok

        # Moved with no mechanism: the refusal this rule exists for.
        @test Answers.verdict(computed = B, staged = B, head = A,
                              message = "Speed up the solve") === :undeclared_change

        # Moved with a mechanism.
        @test Answers.verdict(computed = B, staged = B, head = A,
                              message = "Speed up the solve\n\nanswers: the residual changed\n") === :ok
    end

    @testset "the mechanism line is a line, not a word anywhere" begin
        moved(msg) = Answers.verdict(computed = B, staged = B, head = A, message = msg)
        @test moved("this answers: nothing") === :undeclared_change
        @test moved("answers:") === :undeclared_change
        @test moved("answers: ") === :undeclared_change
        @test moved("answers: x") === :ok
        @test moved("a line\nanswers: x\nanother") === :ok
    end

    @testset "every refusal names the hashes that decided it" begin
        for v in (:no_hash, :stale_record, :undeclared_change)
            text = Answers.explain(v; computed = A, staged = B, head = A)
            @test !isempty(text)
            @test startswith(text, "gate:")
        end
        @test occursin(B, Answers.explain(:stale_record; computed = A, staged = B, head = A))
        @test occursin(A, Answers.explain(:undeclared_change; computed = B, staged = B, head = A))
    end

    @testset "the record is read from its own text" begin
        @test Answers.hash_of("[case]\nname = \"x\"\nhash = \"$A\"\n") == A
        @test Answers.hash_of("hash = \"\"\n") == ""
        @test Answers.hash_of("name = \"x\"\n") == ""
        @test Answers.hash_of("# hash = \"$A\"\n") == ""
    end

    @testset "the tracked record matches what the code produces" begin
        root = normpath(joinpath(@__DIR__, "..", ".."))
        out = read(`julia --startup-file=no --project=$root $(joinpath(root, "tools", "gate", "reference.jl")) --check`, String)
        @test occursin("matches", out)
    end
end
