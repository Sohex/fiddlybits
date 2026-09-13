using Test

# The answers: rule of decision 0029, and the reference record it reads.

include(joinpath(@__DIR__, "..", "..", "tools", "gate", "answers.jl"))

const A = "a" ^ 64
const B = "b" ^ 64

"Run a git command in `dir` with a fixed local identity, discarding its output."
run_git(dir::AbstractString, args::Vector{String}) =
    run(pipeline(Cmd(`git -c user.email=test@example.com -c user.name=test $args`;
                      dir = dir); stdout = devnull, stderr = devnull))

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

    @testset "a git revision is read text, or the absence of a path, never a swallowed failure" begin
        repo = mktempdir()
        run_git(repo, ["init", "-q"])
        write(joinpath(repo, "a.txt"), "hi\n")
        run_git(repo, ["add", "a.txt"])
        run_git(repo, ["commit", "-q", "-m", "init"])

        @test occursin("hi", Answers.at_revision("HEAD:a.txt"; dir = repo))
        @test occursin("hi", Answers.at_revision(":a.txt"; dir = repo))

        # A path absent at a revision is an answer, not an error.
        @test Answers.at_revision("HEAD:missing.txt"; dir = repo) == ""
        write(joinpath(repo, "untracked.txt"), "x\n")
        @test Answers.at_revision(":untracked.txt"; dir = repo) == ""

        # A revision that does not resolve is a git failure, never read as absent.
        @test_throws ErrorException Answers.at_revision("BOGUS:a.txt"; dir = repo)

        # No commit yet: HEAD itself does not resolve, so reading HEAD's record fails
        # rather than being read as "the record is new".
        unborn = mktempdir()
        run_git(unborn, ["init", "-q"])
        @test_throws ErrorException Answers.at_revision("HEAD:whatever.txt"; dir = unborn)

        # The caller's own locale never reaches git: an absent path still reads as
        # absent, whether or not this machine has the named locale's translations.
        withenv("LANG" => "de_DE.UTF-8", "LC_ALL" => "de_DE.UTF-8",
                "LANGUAGE" => "de_DE:de") do
            @test Answers.at_revision("HEAD:missing.txt"; dir = repo) == ""
        end
    end

    @testset "the computed hash comes from a checkout of the index, not the working tree" begin
        repo = mktempdir()
        run_git(repo, ["init", "-q"])
        mkpath(joinpath(repo, "case"))
        script = joinpath("case", "echo_value.jl")
        write(joinpath(repo, "case", "value.txt"), "A\n")
        write(joinpath(repo, script),
              "println(strip(read(joinpath(@__DIR__, \"value.txt\"), String)))\n")
        run_git(repo, ["add", "-A"])
        run_git(repo, ["commit", "-q", "-m", "init"])

        @test Answers.staged_tree_hash(repo, script) == "A"

        # Stage B, then edit the working tree back to A: the staged tree still says B.
        write(joinpath(repo, "case", "value.txt"), "B\n")
        run_git(repo, ["add", "-A"])
        write(joinpath(repo, "case", "value.txt"), "A\n")
        @test Answers.staged_tree_hash(repo, script) == "B"
    end

    @testset "staged code B, staged record A, working tree returned to A: refused" begin
        repo = mktempdir()
        run_git(repo, ["init", "-q"])
        mkpath(joinpath(repo, "tools", "gate"))
        mkpath(joinpath(repo, "bench"))
        reference_script(value) = "println(\"" * value * "\")\n"

        write(joinpath(repo, "tools", "gate", "reference.jl"), reference_script("A"))
        write(joinpath(repo, "bench", "reference.toml"), "[case]\nname = \"x\"\nhash = \"A\"\n")
        run_git(repo, ["add", "-A"])
        run_git(repo, ["commit", "-q", "-m", "init at A"])

        # Stage code that answers B; the record stays staged at A.
        write(joinpath(repo, "tools", "gate", "reference.jl"), reference_script("B"))
        run_git(repo, ["add", "tools/gate/reference.jl"])

        # An unstaged edit returns the working tree to A's behaviour.
        write(joinpath(repo, "tools", "gate", "reference.jl"), reference_script("A"))

        # The computed hash is the staged code's, B, not the working tree's, A; the
        # staged record still says A, so the two disagree.
        computed = Answers.staged_tree_hash(repo, joinpath("tools", "gate", "reference.jl"))
        staged = Answers.hash_of(Answers.read_index("bench/reference.toml"; dir = repo))
        head = Answers.hash_of(Answers.read_head("bench/reference.toml"; dir = repo))
        @test computed == "B"
        @test staged == "A"
        @test Answers.verdict(; computed, staged, head, message = "") === :stale_record

        message = joinpath(repo, "commit-message.txt")
        write(message, "Restore the old behaviour\n")

        old_stderr = stderr
        rd, wr = redirect_stderr()
        result = Answers.main([message]; root = repo)
        redirect_stderr(old_stderr)
        close(wr)
        captured = read(rd, String)

        @test result != 0
        @test occursin("does not match", captured)
    end

    include("load_latency.jl")
    include("parallel_gate.jl")
end
