using Test
using Fiddlybits: Dispositions, Dimensions, Verdicts

# system.disposition_refusals: docs/plans/fiddlybits-52v.4-system.md, section "The
# five dispositions", the refusal table. Every disposition refuses construction
# without its required fields, and the refusal names the field.

using .DispositionFixtures: locator, sourced, derived, bracketed, irreducible, closure,
                            KNOWN_FIELDS

"`f()` run for its side effect; the `Verdicts.Refusal` it raises, or the value it
returns when it does not refuse."
caught(f) = try
    f()
catch err
    err
end

@testset "every fixture constructs without refusing" begin
    @test sourced() isa Dispositions.Sourced
    @test derived() isa Dispositions.Derived
    @test bracketed() isa Dispositions.Bracketed
    @test irreducible() isa Dispositions.Irreducible
    @test closure() isa Dispositions.Closure
end

@testset "Locator: a locator built from an identifier with no table" begin
    @test_throws UndefKeywordError Dispositions.Locator(identifier = "10.1/x")

    e = caught(() -> locator(table = ""))
    @test e isa Verdicts.Refusal
    @test occursin("table", e.reason)

    e = caught(() -> locator(identifier = ""))
    @test e isa Verdicts.Refusal
end

@testset "Derived: a from naming an invented field" begin
    e = caught(() -> derived(from = (:invented,)))
    @test e isa Verdicts.Refusal
    @test occursin("invented", e.reason)
    @test e.quantity == "Derived from"

    e = caught(() -> derived(from = ()))
    @test e isa Verdicts.Refusal
    @test occursin("no field", e.reason)
end

@testset "Bracketed: a value above its high end, and outside it below" begin
    e = caught(() -> bracketed(value = 3.0))
    @test e isa Verdicts.Refusal
    @test occursin("outside the bracket", e.reason)

    e = caught(() -> bracketed(value = -1.0))
    @test e isa Verdicts.Refusal
end

@testset "Bracketed: a bracket with one mechanism" begin
    e = caught(() -> bracketed(pushes_down = ""))
    @test e isa Verdicts.Refusal
    @test occursin("low end", e.reason)

    e = caught(() -> bracketed(pushes_up = ""))
    @test e isa Verdicts.Refusal
    @test occursin("high end", e.reason)
end

@testset "Irreducible: no argument, and no sensitivity, each omitted in turn" begin
    e = caught(() -> irreducible(argument = ""))
    @test e isa Verdicts.Refusal
    @test occursin("argument", e.reason)

    e = caught(() -> irreducible(sensitivity = ""))
    @test e isa Verdicts.Refusal
    @test occursin("sensitivity", e.reason)
end

@testset "Closure: a Sourced coefficient, and a single level" begin
    e = caught(() -> closure(coefficient = sourced()))
    @test e isa Verdicts.Refusal
    @test occursin("Bracketed", e.reason)

    e = caught(() -> closure(levels = (3,)))
    @test e isa Verdicts.Refusal
    @test occursin("fewer than two levels", e.reason)
end

@testset "value and dimension" begin
    s = sourced(value = 3.0)
    @test Dispositions.value(s) == 3.0
    @test Dispositions.dimension(s) === Dimensions.DIMENSIONLESS

    c = closure()
    @test Dispositions.value(c) == Dispositions.value(c.coefficient)
    @test Dispositions.dimension(c) === Dimensions.DIMENSIONLESS
end
