using Test
using Fiddlybits: Fields

# The Semantics vocabulary is closed by this check rather than by the language:
# docs/plans/fiddlybits-52v.3-fields.md, row 52v.3.2, and the docstring on
# Fields.Semantics, which names this file.
#
# It reads the types door. Four of the eight members take a parameter and have no one
# instance to stand for them, so semantics_types() enumerates types where
# Events.kinds() and Time.time_semantics() enumerate instances; one definition behind
# both doors is test/closure.jl.

isdefined(@__MODULE__, :VocabularyClosure) ||
    include(joinpath(@__DIR__, "..", "closure.jl"))
using .VocabularyClosure: closed_type_set, TypeFixture

@testset "Fields.semantics_closure" begin
    @testset "the enumeration is complete" begin
        undeclared, unreachable = closed_type_set(Fields.Semantics,
                                                  Fields.semantics_types())
        @test isempty(undeclared)
        @test isempty(unreachable)
        @test length(Fields.semantics_types()) == 8
    end

    @testset "the enumeration is the set decision 0006 declares" begin
        @test Fields.semantics_types() == (Fields.Extensive, Fields.Intensive,
                                           Fields.FluxDensity, Fields.Fraction,
                                           Fields.CategoricalLabel,
                                           Fields.CategoricalFraction,
                                           Fields.VectorComponent, Fields.Quantiles)
    end

    @testset "positive control: an omission from this enumeration is reported" begin
        all_but_last = Fields.semantics_types()[1:(end - 1)]
        undeclared, _ = closed_type_set(Fields.Semantics, all_but_last)
        @test undeclared == [Fields.Quantiles]
    end

    @testset "positive control: an omitted type is reported, parametric or not" begin
        undeclared, unreachable = closed_type_set(TypeFixture.Tone, TypeFixture.partial())
        @test undeclared == [TypeFixture.Graded]
        @test isempty(unreachable)
        @test closed_type_set(TypeFixture.Tone, TypeFixture.whole()) == (Any[], Any[])
    end

    @testset "positive control: a type outside the hierarchy is reported unreachable" begin
        _, unreachable = closed_type_set(TypeFixture.Tone,
                                         (TypeFixture.Flat, TypeFixture.Graded, Int))
        @test unreachable == [Int]
    end
end

# The operator enumeration of fiddlybits-52v.3.4:
# docs/plans/fiddlybits-52v.3-fields.md, section "The operators and the refusal
# table", and decision 0006's "an enumeration test walks every semantics type
# against every operator and asserts each pair either has a method or appears
# in the declared refusal table". test/fields/reduce.jl already walks
# coarsen, refine and time_reduce against Fields.REFUSAL_TABLE and
# Fields.NOT_CONSERVED_TABLE to assert the return form of every method that
# exists; that walk cannot ask the question this one does, because a method
# that was never written never reaches a `Set` built from `methods`. For every
# one of the eight heads above, this closes coarsen, refine and time_reduce
# against Semantics the same way the enumeration above closes Semantics
# against itself. test/fields/inference.jl rides the same two doors,
# Fields.semantics_types() and Time.time_semantics(), for its @inferred
# assertion.

"""
    head(T)

The generic head of the type `T`: `VectorComponent{:east_north}`, the bare
`VectorComponent` and a method's own free type variable bound to one all read
back as `VectorComponent`, which is the granularity `semantics_types()` and
`REFUSAL_TABLE` share. `T`'s own parameter, open for `VectorComponent`'s basis
and for `CategoricalLabel`'s and `CategoricalFraction`'s legend, is not part
of what this file closes.
"""
head(T::Type) = Base.unwrap_unionall(T).name.wrapper
head(T::TypeVar) = head(T.ub)

"""
    strip_where(T)

`T` with every `UnionAll` layer it carries removed, its free type variables
left in place inside whatever they parametrise.
"""
function strip_where(T)
    while T isa UnionAll
        T = T.body
    end
    return T
end

"""
    field_semantics_head(m)

The semantics head the `Field` argument of the method `m` of `coarsen` or
`refine` dispatches on: `m`'s signature stripped of every `where`, its second
slot (the field argument; the first is `typeof(op)`), stripped again, and its
first type parameter, read through `head`.
"""
function field_semantics_head(m::Method)
    arg = strip_where(m.sig).parameters[2]
    arg = arg isa TypeVar ? arg.ub : arg
    return head(strip_where(arg).parameters[1])
end

"""
    forcing_semantics_head(m)

The same for a method of `time_reduce`, whose second slot is a `Time.Forcing`
carrying the field type one level deeper, in `Forcing`'s own second
parameter.
"""
function forcing_semantics_head(m::Method)
    arg = strip_where(m.sig).parameters[2]
    arg = arg isa TypeVar ? arg.ub : arg
    fld = strip_where(arg).parameters[2]
    fld = fld isa TypeVar ? fld.ub : fld
    return head(strip_where(fld).parameters[1])
end

"""
    missing_coverage(op, extractor, entries, universe, root)

The members of `universe` (every declared subtype of the abstract type
`root`) that neither a method of the generic function `op` nor an entry of
`entries` (each holding a `semantics` field, matched through `head`)
declares: `op`'s own coverage read off `methods(op)` through `extractor`,
which is `field_semantics_head` for `coarsen` and `refine` and
`forcing_semantics_head` for `time_reduce`. A method or entry whose head is
`root` itself, or `Any` (an unconstrained type parameter), covers every
member of `universe` at once, which is how `time_reduce`'s two
`REFUSAL_TABLE` entries and its three working methods, none of which name a
`Semantics` subtype, close over every one of them without naming any.
Returns the uncovered members sorted by name; empty means every pair either
resolves to a method or is declared refused.
"""
function missing_coverage(op, extractor, entries, universe, root::Type)
    covered = Set{Any}()
    for m in methods(op)
        push!(covered, extractor(m))
    end
    for e in entries
        push!(covered, head(e.semantics))
    end
    (root in covered || Any in covered) && return Any[]
    return sort(collect(setdiff(Set(universe), covered)), by = string)
end

"Entries of `Fields.REFUSAL_TABLE` declared for `operator`."
refusal_entries(operator::Symbol) =
    filter(e -> e.operator === operator, Fields.REFUSAL_TABLE)

@testset "the operator table is closed against the Semantics set" begin
    universe = Fields.semantics_types()

    @testset "refine" begin
        @test isempty(missing_coverage(Fields.refine, field_semantics_head,
                                       refusal_entries(:refine), universe,
                                       Fields.Semantics))
    end

    @testset "time_reduce" begin
        @test isempty(missing_coverage(Fields.time_reduce, forcing_semantics_head,
                                       refusal_entries(:time_reduce), universe,
                                       Fields.Semantics))
    end

    @testset "coarsen" begin
        # fiddlybits-52v.3.16: coarsen dispatches to neither a method nor a
        # REFUSAL_TABLE entry for CategoricalFraction. Visible rather than
        # assumed (docs/workflow.md): @test_broken fails the moment the gap
        # closes, which is what forces this line back to a plain @test rather
        # than staying green on its own.
        missing = missing_coverage(Fields.coarsen, field_semantics_head,
                                   refusal_entries(:coarsen), universe, Fields.Semantics)
        @test missing == [Fields.CategoricalFraction]
        @test_broken isempty(missing)
    end
end

"""
A hierarchy no module under test declares, standing in for `Semantics`, and a
one-argument generic function standing in for `coarsen`/`refine`, so
`missing_coverage`'s positive control does not read the production tables.
`Jagged` carries neither a method of `f` nor an entry of `TABLE`, which is the
control fiddlybits-52v.3.4 asks for: a semantics added to a fixture with no
row in its table fails the walk.
"""
module OperatorClosureFixture

abstract type Shape end
struct Round <: Shape end
struct Square <: Shape end
struct Jagged <: Shape end

"`Round` is the one shape `f` resolves for."
f(::Round) = :measured

"Every entry `f` is declared to refuse, in `missing_coverage`'s shape."
const TABLE = ((operator = :f, semantics = Square, sentence = "squares refuse by name"),)

types() = (Round, Square, Jagged)

end # module OperatorClosureFixture

@testset "positive control: a fixture semantics type added with neither fails the walk" begin
    OF = OperatorClosureFixture
    simple_head(m) = head(strip_where(m.sig).parameters[2])

    missing = missing_coverage(OF.f, simple_head, OF.TABLE, OF.types(), OF.Shape)
    @test missing == [OF.Jagged]

    @testset "control: the whole set closes once Jagged is no longer in it" begin
        @test isempty(missing_coverage(OF.f, simple_head, OF.TABLE,
                                       (OF.Round, OF.Square), OF.Shape))
    end
end
