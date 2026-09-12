using Test
using Fiddlybits: Time

# Decision 0008: no constant is both a day and a unit of time, and nothing in this
# module is sized by a day. The module carries the declared rotation period and
# nothing derived from it, so a day appears here neither as a number nor as a name.
#
# The scan reads code only. A day may be named in a comment or a docstring, which is
# where the rule itself is stated.

module DayScan
    "The source with its docstrings, comments and string literals removed."
    function code_only(text::AbstractString)
        text = replace(text, r"\"\"\".*?\"\"\""s => " ")
        text = replace(text, r"#=.*?=#"s => " ")
        text = replace(text, r"#[^\n]*" => " ")
        text = replace(text, r"\"(?:[^\"\\]|\\.)*\"" => " ")
        return text
    end

    # The seconds in a day at two common roundings, and the day as a name. The name
    # is read with an underscore counting as a separator rather than as a letter, so
    # that SECONDS_PER_DAY and n_days are both caught and Monday and dayside are not.
    const PATTERNS = (r"\b86400\b", r"\b86164(?:\.[0-9]+)?\b", r"(?<![A-Za-z])days?(?![A-Za-z])"i)

    "Every site in `text` where a day stands as a unit."
    function sites(text::AbstractString)
        code = code_only(text)
        found = String[]
        for pattern in PATTERNS, m in eachmatch(pattern, code)
            push!(found, m.match)
        end
        return found
    end

    "Every site under `dir`, as path => sites."
    function scan(dir::AbstractString)
        found = Pair{String,Vector{String}}[]
        for (root, _, names) in walkdir(dir), name in names
            endswith(name, ".jl") || continue
            path = joinpath(root, name)
            s = sites(read(path, String))
            isempty(s) || push!(found, path => s)
        end
        return found
    end
end

const TIME_SRC = normpath(joinpath(@__DIR__, "..", "..", "src", "Time"))

@testset "Time carries no day as a unit" begin
    @testset "the module" begin
        @test isdir(TIME_SRC)
        @test !isempty(filter(n -> endswith(n, ".jl"), readdir(TIME_SRC)))
        @test DayScan.scan(TIME_SRC) == Pair{String,Vector{String}}[]
    end

    @testset "the scan can fail" begin
        @test DayScan.sites("const SECONDS_PER_DAY = 86400\n") == ["86400", "DAY"]
        @test DayScan.sites("steps = n_days * 4\n") == ["days"]
        @test DayScan.sites("period = 86164.0908\n") == ["86164.0908"]
        @test DayScan.sites("x = day\n") == ["day"]
    end

    @testset "the scan does not fire on a word that merely holds those letters" begin
        @test isempty(DayScan.sites("x = Monday\n"))
        @test isempty(DayScan.sites("x = dayside\n"))
        @test isempty(DayScan.sites("x = 864000\n"))
    end

    @testset "the scan reads code and not prose" begin
        @test isempty(DayScan.sites("# nothing here is a day\n"))
        @test isempty(DayScan.sites("\"\"\"\nNot a day.\n\"\"\"\nf() = 1\n"))
        @test isempty(DayScan.sites("label = \"day\"\n"))
    end
end
