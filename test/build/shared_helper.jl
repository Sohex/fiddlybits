# build.one_definition_per_helper: a helper two test suites share has one definition,
# and a second door reaching it neither replaces it nor takes its name in silence.
#
# `test/runtests.jl` includes every suite into `Main`, so a name a suite defines there
# is visible to every later suite and a second definition of it wins, saying nothing
# (notes/findings/2026-09-12-a-silent-method-overwrite-in-main.md). `test/closure.jl`
# is the shared helper this is checked on; the fixtures under
# `fixtures/shared_helper` are a stand-in for it, so what is asserted here does not
# depend on what any vocabulary contains.

module SharedHelper

const FIXTURES = joinpath(@__DIR__, "fixtures", "shared_helper")
const TEST_ROOT = normpath(joinpath(@__DIR__, ".."))

"""
    two_doors(first, second)

Load fixture `first`, then fixture `second`, into `Main` of a fresh process, and
report `(same, stderr)`: whether the module the helper defines survived the second
load as the same object, and everything the process wrote to stderr.
"""
function two_doors(first::AbstractString, second::AbstractString)
    body = """
        include(raw"$(joinpath(FIXTURES, first))")
        original = SharedFixtureHelper
        include(raw"$(joinpath(FIXTURES, second))")
        exit(SharedFixtureHelper === original ? 0 : 2)
        """
    return run_case(body)
end

"""
    run_case(body)

`(ok, stderr)` for `body` run by a fresh copy of the `julia` running this suite:
whether it exited zero, and what it wrote to stderr. A fresh process rather than a
fresh `Module` because a replaced module warns at the level of the runtime, below
anything `redirect_stderr` reaches, and `Base.julia_cmd()` rather than `julia`
because what is asserted is the behaviour of this Julia and not of whichever one
comes first on the path.
"""
function run_case(body::AbstractString)
    errfile = tempname()
    cmd = `$(Base.julia_cmd()) --startup-file=no -e $body`
    ok = try
        run(pipeline(cmd; stdout = devnull, stderr = errfile))
        true
    catch
        false
    end
    text = isfile(errfile) ? read(errfile, String) : ""
    isfile(errfile) && rm(errfile)
    return ok, text
end

"Every `.jl` file under `root`."
function sources(root::AbstractString)
    files = String[]
    for (dir, _, names) in walkdir(root), name in names
        endswith(name, ".jl") && push!(files, joinpath(dir, name))
    end
    return sort(files)
end

"""
    definitions(root, name)

The files under `root` that define a function called `name` at any indentation, in
either the `function` form or the assignment form. Both are anchored to the start of
the line, so a call on the right of an assignment is not a definition.
"""
function definitions(root::AbstractString, name::AbstractString)
    keyword = Regex("^\\s*function\\s+$(name)\\b")
    assignment = Regex("^\\s*$(name)\\(.*\\)\\s*=[^=]")
    return [f for f in sources(root)
            if any(line -> occursin(keyword, line) || occursin(assignment, line),
                   eachline(f))]
end

"""
    callers(root, name)

The files under `root` that call `name` and do not define it.
"""
function callers(root::AbstractString, name::AbstractString)
    pattern = Regex("\\b$(name)\\(")
    defined = Set(definitions(root, name))
    return [f for f in sources(root)
            if !(f in defined) && any(line -> occursin(pattern, line), eachline(f))]
end

end # module SharedHelper

using Test

@testset "build.one_definition_per_helper" begin
    @testset "the tree: closed_set is defined once and every caller imports it" begin
        found = SharedHelper.definitions(SharedHelper.TEST_ROOT, "closed_set")
        @test found == [joinpath(SharedHelper.TEST_ROOT, "closure.jl")]

        users = SharedHelper.callers(SharedHelper.TEST_ROOT, "closed_set")
        @test !isempty(users)
        for file in users
            @test occursin("VocabularyClosure", read(file, String))
        end
    end

    @testset "positive control: the scan finds both definition forms, and no import" begin
        found = SharedHelper.definitions(SharedHelper.FIXTURES, "answer")
        @test Set(basename.(found)) ==
              Set(["helper.jl", "inline_a.jl", "inline_b.jl", "own_answer.jl"])
    end

    @testset "a second guarded door loads nothing and warns nothing" begin
        same, err = SharedHelper.two_doors("guarded_a.jl", "guarded_b.jl")
        @test same
        @test isempty(strip(err))
    end

    @testset "positive control: a second unguarded door replaces the module" begin
        same, err = SharedHelper.two_doors("unguarded_a.jl", "unguarded_b.jl")
        @test !same
        @test !isempty(strip(err))
    end

    @testset "positive control: two doors defining it inline overwrite in silence" begin
        ok, err = SharedHelper.run_case("""
            include(raw"$(joinpath(SharedHelper.FIXTURES, "inline_a.jl"))")
            answer() === :first || exit(3)
            include(raw"$(joinpath(SharedHelper.FIXTURES, "inline_b.jl"))")
            exit(answer() === :second ? 0 : 2)
            """)
        @test ok
        @test isempty(strip(err))
    end

    @testset "positive control: a door defining the shared name is refused, not obeyed" begin
        ok, err = SharedHelper.run_case("""
            include(raw"$(joinpath(SharedHelper.FIXTURES, "guarded_a.jl"))")
            include(raw"$(joinpath(SharedHelper.FIXTURES, "own_answer.jl"))")
            exit(0)
            """)
        @test !ok
        @test occursin("must be explicitly imported to be extended", err)
    end
end
