using Test

# gate.checkout_depot and gate.eviction_reproduction: the depot every `julia` the gate,
# the pre-push hook and the nightly bed start compiles into (tools/gate/depot.jl), and the
# eviction of one checkout's package image by another checkout's compile, reproduced on
# two checkouts of a fixture package.
# notes/findings/2026-09-13-concurrent-checkouts-evict-each-others-package-image.md has
# the failure, the verdicts and the alternatives.
#
# The eviction is forced, not waited for. `Evictee` depends on `Gatekeeper`, whose
# `__init__` touches the file `EVICTION_READY` names and then waits for the file
# `EVICTION_RELEASE` names. The loader runs a dependency's `__init__` after it has chosen
# the image of the package being loaded and before it opens that image's shared object,
# so the reader holds there while the writer, in the other checkout, compiles its own
# source under `JULIA_MAX_NUM_PRECOMPILE_FILES=1` and so removes every other image of
# `Evictee` from the depot it writes into. Then the reader is released.

module EvictionDriver
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")), "tools", "gate", "run.jl"))
end

module EvictionFixture

using ..EvictionDriver: in_checkout, checkout_depot, git_at

const GATEKEEPER_UUID = "8a3c1d52-6f0e-4b7a-9c2d-1e5f4a6b7c80"
const EVICTEE_UUID = "3f9b2e71-0c4d-4a8e-b6f1-7d2c9e0a5b13"

"What the reader and the writer run: load `Evictee` and print the value its source holds."
const READ = "using Evictee; print(Evictee.value())"

"The warm-up the gate ran before this row: load the package and nothing else."
const PLAIN_WARM = "using Evictee"

git(dir, args::Cmd) =
    run(pipeline(git_at(dir, `-c user.email=gate@fiddlybits -c user.name=gate $(args)`);
                 stdout = devnull, stderr = devnull))

"""
    gatekeeper(dir)

Write the `Gatekeeper` package into `dir` and return `dir`. Its `__init__` does nothing
while an image is being generated or when `EVICTION_READY` is unset; otherwise it touches
the file `EVICTION_READY` names and returns once the file `EVICTION_RELEASE` names exists.
"""
function gatekeeper(dir::AbstractString)
    mkpath(joinpath(dir, "src"))
    write(joinpath(dir, "Project.toml"),
          "name = \"Gatekeeper\"\nuuid = \"$(GATEKEEPER_UUID)\"\nversion = \"0.1.0\"\n")
    write(joinpath(dir, "src", "Gatekeeper.jl"), """
        module Gatekeeper
        function __init__()
            Base.generating_output() && return
            ready = get(ENV, "EVICTION_READY", "")
            isempty(ready) && return
            touch(ready)
            while !isfile(ENV["EVICTION_RELEASE"])
                sleep(0.05)
            end
        end
        end
        """)
    return dir
end

"Write `Evictee`'s source at `root`, returning `value`."
evictee_source(root::AbstractString, value::Int) =
    write(joinpath(root, "src", "Evictee.jl"),
          "module Evictee\nusing Gatekeeper\nvalue() = $(value)\nend\n")

"""
    main_checkout(dir, gk, value)

A git repository at `dir` on `main` whose root is the `Evictee` project, depending on
the `Gatekeeper` at `gk` by path, with `value` in its source, committed. Returns `dir`.
"""
function main_checkout(dir::AbstractString, gk::AbstractString, value::Int)
    mkpath(joinpath(dir, "src"))
    write(joinpath(dir, "Project.toml"),
          "name = \"Evictee\"\nuuid = \"$(EVICTEE_UUID)\"\nversion = \"0.1.0\"\n\n" *
          "[deps]\nGatekeeper = \"$(GATEKEEPER_UUID)\"\n")
    write(joinpath(dir, "Manifest.toml"),
          "julia_version = \"$(VERSION)\"\nmanifest_format = \"2.0\"\n\n" *
          "[[deps.Gatekeeper]]\npath = \"$(gk)\"\nuuid = \"$(GATEKEEPER_UUID)\"\nversion = \"0.1.0\"\n")
    evictee_source(dir, value)
    git(dir, `init -q -b main`)
    git(dir, `add -A`)
    git(dir, `commit -q -m base`)
    return dir
end

"""
    worktree(main, dir, value)

A `git worktree` of `main` at `dir`, with `value` written into its source. Returns `dir`.
"""
function worktree(main::AbstractString, dir::AbstractString, value::Int)
    git(main, `worktree add -q $(dir)`)
    evictee_source(dir, value)
    return dir
end

"""
    depots_from(shared)

The `DEPOT_PATH` Julia builds from `JULIA_DEPOT_PATH="<shared>:"`: `shared`, then the
depots bundled with Julia, and not the user's depot.
"""
depots_from(shared::AbstractString) =
    String.(split(read(addenv(`julia --startup-file=no -e 'print(join(DEPOT_PATH, "\n"))'`,
                              "JULIA_DEPOT_PATH" => shared * ":"), String), '\n'))

bare(root::AbstractString, code::AbstractString) =
    `julia --startup-file=no --project=$(root) -e $(code)`

"""
    old_tooling(cmd, root, inherited)

`cmd` as the gate built it before this row: carrying the depots its parent read,
`inherited`, and none of its own.
"""
old_tooling(cmd::Cmd, root::AbstractString, inherited::Vector{String}) =
    addenv(cmd, "JULIA_DEPOT_PATH" => join(inherited, ':'))

"`cmd` as the gate builds it: `in_checkout` at `root` ahead of `inherited`."
the_gate(cmd::Cmd, root::AbstractString, inherited::Vector{String}) =
    in_checkout(cmd, root; inherited = inherited)

"`(ok, output)` for `cmd` run to completion, stdout and stderr together."
function captured(cmd::Cmd)
    io = IOBuffer()
    ok = success(pipeline(cmd; stdout = io, stderr = io))
    return ok, String(take!(io))
end

"The `Evictee` image files in `depot`, sorted."
images(depot::AbstractString) =
    let dir = joinpath(depot, "compiled", "v$(VERSION.major).$(VERSION.minor)", "Evictee")
        isdir(dir) ? sort(filter(endswith(".ji"), readdir(dir))) : String[]
    end

"""
    held_read(reader, writer, between)

Start `reader` with `EVICTION_READY` and `EVICTION_RELEASE` set; once it has touched the
ready file, run `writer` under `JULIA_MAX_NUM_PRECOMPILE_FILES=1` to completion, call
`between()`, and release the reader. Returns `(reader_ok, reader_output, writer_ok,
writer_output, between_result)`. Refuses, with the reader's output, when the reader exits
before touching the ready file.
"""
function held_read(reader::Cmd, writer::Cmd, between)
    control = mktempdir()
    ready, release = joinpath(control, "ready"), joinpath(control, "release")
    io = IOBuffer()
    process = run(pipeline(addenv(reader, "EVICTION_READY" => ready,
                                  "EVICTION_RELEASE" => release);
                           stdout = io, stderr = io); wait = false)
    local written, seen
    try
        while !isfile(ready)
            process_exited(process) &&
                error("the reader exited before Gatekeeper.__init__ held it:\n" *
                      String(take!(io)))
            sleep(0.05)
        end
        written = captured(addenv(writer, "JULIA_MAX_NUM_PRECOMPILE_FILES" => "1"))
        seen = between()
    finally
        touch(release)
    end
    ok = success(process)
    return ok, String(take!(io)), written[1], written[2], seen
end

"""
    arm(rule, writer_rule, warm; prior, pairs)

One run of the reproduction on a fresh shared depot and two fresh checkouts of `Evictee`
with differing source: the main checkout of a repository and a worktree of it. For each
`(reader, writer)` of `pairs`, naming `:main` or `:worktree`: when `prior`, the reader's
source is first loaded under `old_tooling`, which leaves its image in the shared depot;
the reader runs `warm` under `rule`; the writer's source is changed to a value neither
checkout has held; then `held_read` of `READ` under `rule` for the reader and
`writer_rule` for the writer. Returns one named tuple per pair.
"""
function arm(rule, writer_rule, warm::AbstractString; prior::Bool, pairs)
    gk = gatekeeper(mktempdir())
    shared = mktempdir()
    inherited = depots_from(shared)
    main = main_checkout(mktempdir(), gk, 1)
    roots = Dict(:main => main, :worktree => worktree(main, joinpath(mktempdir(), "worktree"), 2))
    held = Dict(:main => 1, :worktree => 2)
    results = []
    for (r, w) in pairs
        reader, writer = roots[r], roots[w]
        if prior
            ok, text = captured(old_tooling(bare(reader, PLAIN_WARM), reader, inherited))
            ok || error("the prior load of $(r) failed:\n" * text)
        end
        ok, text = captured(rule(bare(reader, warm), reader, inherited))
        ok || error("the warm-up of $(r) failed:\n" * text)
        held[w] = maximum(last, held) + 1
        evictee_source(writer, held[w])
        own = checkout_depot(reader)
        before = (shared = images(shared), own = images(own))
        reader_ok, reader_text, writer_ok, writer_text, after =
            held_read(rule(bare(reader, READ), reader, inherited),
                      writer_rule(bare(writer, READ), writer, inherited),
                      () -> (shared = images(shared), own = images(own)))
        push!(results, (reader_ok = reader_ok, reader_text = reader_text,
                        reader_value = held[r], writer_ok = writer_ok,
                        writer_text = writer_text, writer_value = held[w],
                        before = before, after = after))
    end
    return results
end

"Whether `output` ends with the value `value`, as `READ` prints it."
printed(output::AbstractString, value::Int) = endswith(strip(output), string(value))

"""
    julia_outside_rule(text)

The command literals in Julia source `text` that start `julia` or `\$(Base.julia_cmd())`
and are not an argument, at any depth, of a call to `in_checkout` or `in_depot`. Read from
the parsed syntax, so a docstring or a comment naming such a command is not one.
"""
function julia_outside_rule(text::AbstractString)
    found = String[]
    starts_julia = r"^\s*(julia\s|\$\(Base\.julia_cmd\(\)\))"
    function walk(node, wrapped::Bool)
        node isa Expr || return
        if node.head === :macrocall
            name = node.args[1]
            name = name isa GlobalRef ? name.name : name
            if name === Symbol("@cmd")
                literal = node.args[end]
                literal isa String && occursin(starts_julia, literal) && !wrapped &&
                    push!(found, literal)
                return
            end
        end
        if node.head === :call && node.args[1] in (:in_checkout, :in_depot)
            foreach(a -> walk(a, true), node.args[2:end])
            return
        end
        foreach(a -> walk(a, wrapped), node.args)
    end
    walk(Meta.parseall(text), false)
    return found
end

"""
    shell_julia_lines(text)

The lines of shell `text`, other than comments and `command -v julia`, that run `julia`.
"""
shell_julia_lines(text::AbstractString) =
    [String(l) for l in split(text, '\n')
     if !startswith(lstrip(l), "#") && occursin(r"(^|[\s'\"(])julia\s", l) &&
        !occursin("command -v julia", l)]

"The value `key` is given in `cmd`'s own environment, or `nothing`."
function env_value(cmd::Cmd, key::AbstractString)
    cmd.env === nothing && return nothing
    i = findfirst(startswith(key * "="), cmd.env)
    return i === nothing ? nothing : cmd.env[i][length(key)+2:end]
end

end # module EvictionFixture

@testset "gate.checkout_depot" begin
    D = EvictionDriver
    F = EvictionFixture
    root = D.ROOT

    @testset "every julia the gate and the nightly bed start carries the checkout's depot first" begin
        depot = D.checkout_depot(root)
        expected = D.depot_path(depot)
        @test startswith(expected, depot * ":")
        commands = (D.warm_command(root), D.warm_command(root; extra = D.BOUNDS_FLAGS),
                    D.suite_command(root, "events", 4),
                    D.suite_command(root, "events", 4; extra = D.BOUNDS_FLAGS),
                    D.probe_command(root, D.BOUNDS_FLAGS, ["marker_cpu"]))
        for cmd in commands
            @test F.env_value(cmd, "JULIA_DEPOT_PATH") == expected
        end

        @testset "positive control: a command built without the rule carries no depot" begin
            @test F.env_value(`julia --project=$(root) -e 1`, "JULIA_DEPOT_PATH") === nothing
        end

        @testset "the warm-up is the one warm_code" begin
            @test D.warm_code("Fiddlybits") in D.warm_command(root).exec
        end
    end

    @testset "the depot is under the checkout's own git directory" begin
        gitdir = strip(read(D.git_at(root, `rev-parse --absolute-git-dir`), String))
        @test D.checkout_depot(root) == joinpath(gitdir, D.DEPOT_NAME)

        main = F.main_checkout(mktempdir(), F.gatekeeper(mktempdir()), 1)
        tree = F.worktree(main, joinpath(mktempdir(), "worktree"), 2)
        @test D.checkout_depot(main) == joinpath(realpath(main), ".git", D.DEPOT_NAME)
        @test startswith(D.checkout_depot(tree), joinpath(realpath(main), ".git", "worktrees") * "/")
        @test D.checkout_depot(main) != D.checkout_depot(tree)

        @testset "positive control: no checkout is refused" begin
            @test_throws ErrorException D.checkout_depot(mktempdir())
        end
    end

    @testset "no door starts a julia that loads the package outside the rule" begin
        read_tool(parts...) = read(joinpath(root, parts...), String)
        for file in (("tools", "gate", "run.jl"), ("tools", "gate", "answers.jl"),
                     ("tools", "nightly", "run.jl"))
            @test isempty(F.julia_outside_rule(read_tool(file...)))
        end
        @test all(l -> occursin("tools/gate/run.jl", l),
                  F.shell_julia_lines(read_tool("tools", "gate", "gate.sh")))
        @test all(l -> occursin("tools/nightly/run.jl", l),
                  F.shell_julia_lines(read_tool("tools", "nightly", "nightly.sh")))
        hook = read_tool(".beads", "hooks", "pre-push")
        @test isempty(F.shell_julia_lines(hook))
        @test occursin("tools/gate/gate.sh", hook)

        @testset "positive control: a julia command built bare is found" begin
            @test length(F.julia_outside_rule("cmd = `julia --project=\$(root) -e 1`")) == 1
            @test length(F.julia_outside_rule("f() = `\$(Base.julia_cmd()) -e 1`")) == 1
            @test length(F.shell_julia_lines("  julia --project=. -e 'using Fiddlybits'")) == 1
        end

        @testset "clean control: one wrapped, and one named in a docstring, are not" begin
            @test isempty(F.julia_outside_rule("f(d) = in_depot(`julia -e 1`, d)"))
            @test isempty(F.julia_outside_rule("\"\"\"\nRuns `julia --project=x`.\n\"\"\"\ng() = 1"))
        end
    end
end

@testset "gate.eviction_reproduction" begin
    F = EvictionFixture
    warm = EvictionDriver.warm_code("Evictee")

    @testset "positive control: under the tooling before this row the reader fails" begin
        (res,) = F.arm(F.old_tooling, F.old_tooling, F.PLAIN_WARM;
                       prior = false, pairs = [(:main, :worktree)])
        @test res.writer_ok
        @test F.printed(res.writer_text, res.writer_value)
        @test length(res.before.shared) == 1
        @test isempty(intersect(res.before.shared, res.after.shared))
        @test !res.reader_ok
        @test occursin("Error opening package file", res.reader_text)
    end

    # Every ordered (reader, writer) pair of the two checkouts, so each git directory
    # shape holds the depot in each role.
    repetitions = [(:main, :worktree), (:worktree, :main)]

    @testset "under the checkout's depot the reader loads, on every repetition" begin
        results = F.arm(F.the_gate, F.the_gate, warm; prior = false, pairs = repetitions)
        @test length(results) == length(repetitions)
        for res in results
            @test res.writer_ok
            @test F.printed(res.writer_text, res.writer_value)
            @test !isempty(res.before.own)
            @test res.before.own == res.after.own
            @test res.reader_ok
            @test F.printed(res.reader_text, res.reader_value)
        end
    end

    @testset "positive control: an image of the reader's source in the shared depot, loaded by a warm-up that only loads, is evicted by a writer outside the rule" begin
        (res,) = F.arm(F.the_gate, F.old_tooling, F.PLAIN_WARM;
                       prior = true, pairs = [(:main, :worktree)])
        @test res.writer_ok
        @test isempty(res.before.own)
        @test !res.reader_ok
        @test occursin("Error opening package file", res.reader_text)
    end

    @testset "warm_code compiles that reader into its own depot, and the reader loads, on every repetition" begin
        results = F.arm(F.the_gate, F.old_tooling, warm; prior = true, pairs = repetitions)
        @test length(results) == length(repetitions)
        for res in results
            @test res.writer_ok
            @test F.printed(res.writer_text, res.writer_value)
            @test !isempty(res.before.own)
            @test res.reader_ok
            @test F.printed(res.reader_text, res.reader_value)
        end
    end
end
