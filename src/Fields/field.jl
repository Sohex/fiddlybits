# The typed field: docs/plans/fiddlybits-52v.3-fields.md, sections "Types and
# functions" and "The closed vocabularies".
#
# A Field is a host-side wrapper. Its array may live on either device and the wrapper
# itself never enters a kernel: every kernel in this package takes bare arrays, and the
# one struct decision 0011 passes to a kernel is the stripped constant block of
# decision 0007. So nothing is dropped at the device boundary, and adapt carries the
# whole wrapper across with only its array converted.

using ..Verdicts: refuse
using ..Dimensions: Dim, require_same_dim, signature
using ..Time: TimeSemantics, TimeSupport
using ..Mesh: Support, require_same_support
using ..Backends: LAYOUT
import Adapt
import UUIDs

"""
    Semantics

What a number means across space. The closed set decision 0006 declares;
`semantics_types()` enumerates it and `test/fields/semantics_closure.jl` closes it
against that enumeration.
"""
abstract type Semantics end

"A quantity whose cell value is a total over the cell, so a coarse cell is a sum."
struct Extensive <: Semantics end

"A quantity per unit of something, whose coarsening names its rule or refuses."
struct Intensive <: Semantics end

"A quantity per unit area and time, coarsened by an area-weighted mean."
struct FluxDensity <: Semantics end

"A share of a cell, in the unit interval, coarsened by an area-weighted mean."
struct Fraction <: Semantics end

"A class drawn from `Legend`, read from the artifact's legend and never an integer code."
struct CategoricalLabel{Legend} <: Semantics end

"The area share of each class of `Legend` in a cell."
struct CategoricalFraction{Legend} <: Semantics end

"One component of a vector in basis `Basis`; only `:cartesian` may change support."
struct VectorComponent{Basis} <: Semantics end

"A table of the quantiles `P` within a cell: a table and not a moment."
struct Quantiles{P} <: Semantics end

"""
    semantics_types()

Every `Semantics` type, in the order decision 0006 declares them.

Types rather than singletons, which is how this enumeration differs from
`Time.time_semantics()`: four of the eight take a parameter and have no one instance
to stand for them.
"""
semantics_types() = (Extensive, Intensive, FluxDensity, Fraction, CategoricalLabel,
                     CategoricalFraction, VectorComponent, Quantiles)

"The states an `Origin` can be in. Closed; the constructor refuses any other."
const ORIGIN_STATES = (:stamped, :unstamped)

"""
    Origin

Where a field's numbers came from, carried by value: the content key, the one writer,
the hash of the parameter subset the writer read, and the run.

`Provenance` computes the key and the parameter hash and stamps them; this module only
carries them, holds no type from `Provenance`, which sits above it, and is not named
`Provenance`, because a struct sharing a name with the module that fills it is a
reader's trap.

An origin that has not been stamped says so by name in `state`, and `content_key` and
`parameter_digest` refuse to read it. The bytes behind an unstamped origin are zero and
no door reaches them, so a zero digest is never returned as though it were a real one.
"""
struct Origin
    state::Symbol
    writer::Symbol
    run::UUIDs.UUID
    key::NTuple{32,UInt8}
    parameters::NTuple{32,UInt8}

    function Origin(state::Symbol, writer::Symbol, run::UUIDs.UUID,
                    key::NTuple{32,UInt8}, parameters::NTuple{32,UInt8})
        state in ORIGIN_STATES || refuse(
            "origin state", "Fields.Origin",
            "$(state) is not one of $(join(ORIGIN_STATES, ", "))")
        return new(state, writer, run, key, parameters)
    end
end

"The digest an unstamped origin holds and no door returns."
const NO_DIGEST = ntuple(_ -> 0x00, 32)

"""
    unstamped(writer, run)

The origin of a field `writer` has just computed in `run`: a writer and a run, and a
content key and parameter hash that do not exist yet and are refused rather than
returned as zeros. `Provenance` replaces it with a stamped one.
"""
unstamped(writer::Symbol, run::UUIDs.UUID) =
    Origin(:unstamped, writer, run, NO_DIGEST, NO_DIGEST)

"""
    stamped(writer, run, key, parameters)

The origin of a field `Provenance` has keyed.
"""
stamped(writer::Symbol, run::UUIDs.UUID, key::NTuple{32,UInt8},
        parameters::NTuple{32,UInt8}) = Origin(:stamped, writer, run, key, parameters)

"""
    is_stamped(o)

Whether `o` carries a content key.
"""
is_stamped(o::Origin) = o.state === :stamped

"""
    content_key(o)
    parameter_digest(o)

The content key of `o`, and the hash of the parameter subset its writer read. Both
refuse an unstamped origin naming its writer, rather than returning the zeros it holds.
"""
content_key(o::Origin) =
    is_stamped(o) ? o.key : refuse("content key", "Fields.content_key",
        "the origin written by $(o.writer) is unstamped and has no content key")

parameter_digest(o::Origin) =
    is_stamped(o) ? o.parameters : refuse("parameter digest", "Fields.parameter_digest",
        "the origin written by $(o.writer) is unstamped and has no parameter digest")

Base.:(==)(a::Origin, b::Origin) =
    a.state === b.state && a.writer === b.writer && a.run == b.run &&
    a.key == b.key && a.parameters == b.parameters

"""
    Field{S,T,D,L,A,P}

Numbers with what they mean travelling on their type: the semantics `S`, the time
semantics `T`, the dimension `D`, the level `L` of the support they sit on, the array
type `A`, and the shape `P` that places the time support on the clock.

`L` and `P` are there for one reason between them: a `Field` holds a `Support{L}` and a
`TimeSupport{T,P}`, and a struct field whose type is not concrete is an inference hole
at the centre of every operator. `L` is the parameter decision 0006 already carries for
the first; `P` is the same move for the second, and it is fixed by `T` through
`Time.time_support_kind`, so no signature names it and `Field{S,T,D,L,A}` is what is
written in dispatch.

The data is `(cells, levels, extra...)`, the convention read from `Backends.LAYOUT`
rather than restated here.
"""
struct Field{S<:Semantics,T<:TimeSemantics,D<:Dim,L,A<:AbstractArray,P}
    data::A
    support::Support{L}
    time::TimeSupport{T,P}
    origin::Origin

    function Field{S,T,D,L,A,P}(data::A, support::Support{L}, time::TimeSupport{T,P},
                                origin::Origin) where {S,T,D,L,A,P}
        Base.require_one_based_indexing(data)
        return new{S,T,D,L,A,P}(data, support, time, origin)
    end
end

"""
    Field(; semantics, dimension, data, support, time, origin)

The one door. Every keyword is required, so a field cannot be built without all four of
semantics, time semantics (carried by `time`), dimension and support: there is no form
that takes an array alone, because the whole design is that those four travel with the
numbers.
"""
function Field(; semantics::S, dimension::D, data::A, support::Support{L},
                 time::TimeSupport{T,P}, origin::Origin) where
                {S<:Semantics,D<:Dim,A<:AbstractArray,L,T<:TimeSemantics,P}
    return Field{S,T,D,L,A,P}(data, support, time, origin)
end

"""
    CELL_AXIS

Which axis of a field's array holds the cells, read from `Backends.LAYOUT` rather than
written as a one here. A layout naming no cell axis fails the precompile.
"""
const CELL_AXIS = something(findfirst(==(:cells), LAYOUT))

"""
    cell_count(f)

How many cells `f` holds, along `CELL_AXIS`.
"""
cell_count(f::Field) = size(f.data, CELL_AXIS)

"""
    semantics(f)
    time_semantics(f)
    dimension(f)
    level(f)

What `f` declares, read back off its type as values.
"""
semantics(::Field{S}) where {S} = S()
time_semantics(::Field{S,T}) where {S,T} = T()
dimension(::Field{S,T,D}) where {S,T,D} = D()
level(::Field{S,T,D,L}) where {S,T,D,L} = L

"""
    data(f)
    support(f)
    time_support(f)
    origin(f)

What `f` holds.
"""
data(f::Field) = f.data
support(f::Field) = f.support
time_support(f::Field) = f.time
origin(f::Field) = f.origin

"""
    ==(a::Field, b::Field)

Compares every member: the data, the support identity, the time support and the
origin. Two fields of different types are never equal, so the four declarations are
part of the comparison by being part of the type.
"""
Base.:(==)(a::Field, b::Field) = false
Base.:(==)(a::F, b::F) where {F<:Field} =
    a.data == b.data && a.support == b.support && a.time == b.time &&
    a.origin == b.origin

"""
    hash(f::Field, h::UInt)

Hashes the members `==` compares, and the type, which carries the four declarations.
"""
Base.hash(f::Field, h::UInt) =
    hash(typeof(f), hash(f.data, hash(f.support, hash(f.time, hash(f.origin, h)))))

"""
    hash(o::Origin, h::UInt)

Hashes the members `==` compares.
"""
Base.hash(o::Origin, h::UInt) =
    hash(o.state, hash(o.writer, hash(o.run, hash(o.key, hash(o.parameters, h)))))

function Base.show(io::IO, f::Field)
    print(io, "Field(", nameof(typeof(semantics(f))), ", ",
          nameof(typeof(time_semantics(f))), ", ", signature(dimension(f)),
          ", level ", level(f), ", ", summary(f.data), ")")
end

"""
    adapt_structure(to, f)

`f` with its array converted for `to` and everything else carried across unchanged.

Nothing is stripped, because nothing needs to be: the wrapper never enters a kernel.
Every kernel in this package takes bare arrays, and an operator unwraps at the launch
having already discharged the declarations on `f`'s type at compile time. That is what
`fields.adapt_roundtrip` asserts and why it can assert equality in every member.
"""
Adapt.adapt_structure(to, f::Field{S,T,D}) where {S,T,D} =
    Field(semantics = S(), dimension = D(), data = Adapt.adapt(to, f.data),
          support = f.support, time = f.time, origin = f.origin)

"""
    type_name(T)

`T` written with its parameters and without its module path, for the refusals that name
what two fields each declare.
"""
type_name(T::Type) = isempty(T.parameters) ? String(nameof(T)) :
    string(nameof(T), "{", join(map(repr, T.parameters), ", "), "}")

"""
    describe(f)

`f`'s four declarations as a phrase.
"""
describe(f::Field) =
    "a field declaring $(type_name(typeof(semantics(f)))), " *
    "$(type_name(typeof(time_semantics(f)))), " *
    "$(signature(dimension(f))) at level $(level(f))"

"""
    require_combinable(a, b, site)

Returns `nothing` when `a` and `b` may be combined elementwise, and raises at `site`
naming what differs otherwise.

Every mismatch of the four declarations is refused by name and none is left to arrive
as a `MethodError`. A declared refusal carrying a sentence is what the refusal table of
`docs/plans/fiddlybits-52v.3-fields.md` is made of; an absent method is that table's
failure state, not its shape.

Six things are compared, not four. The four declarations are checked in the order they
sit on the type, so the refusal names the first that differs rather than all of them.
The semantics and the time semantics are compared here; the dimension goes to
`Dimensions.require_same_dim` and the support to `Mesh.require_same_support`, because
each identity belongs to the module that declares it and a convention restated in two
places is two conventions.

The other two are where the operands sit, and they are compared because the result can
only carry one of each. A `TimeSupport` records where a value is on the clock, and an
`Origin`'s run records which run produced it. A result built from the left operand
inherits both, so allowing two operands to differ in either would make an operator
commutative in its numbers and not in what those numbers claim to be: `a + b` and
`b + a` would carry the same data over different intervals, or name one of two runs.
Combining across either is then a named operation whose own provenance says so, if it
is ever wanted, rather than something that happens by accident.

One method per operator rather than a matching method and a less specific one: a
signature naming only the parameters that must agree is the same type as one naming
none, so two such methods carry equal specificity and the later definition would win
whatever the intent.
"""
function require_combinable(a::Field, b::Field, site::AbstractString)
    semantics(a) === semantics(b) || refuse(
        "field combination", site,
        "$(describe(a)) and $(describe(b)) differ in semantics")
    time_semantics(a) === time_semantics(b) || refuse(
        "field combination", site,
        "$(describe(a)) and $(describe(b)) differ in time semantics")
    a.time == b.time || refuse(
        "field combination", site,
        "$(describe(a)) at $(a.time) and $(describe(b)) at $(b.time) sit at different " *
        "places on the clock, and a result carries one")
    require_same_dim(dimension(a), dimension(b), site)
    require_same_support(support(a), support(b), site)
    a.origin.run == b.origin.run || refuse(
        "field combination", site,
        "the operands were written in runs $(a.origin.run) and $(b.origin.run), and a " *
        "result carries one")
    return nothing
end

"""
    +(a::Field, b::Field)
    -(a::Field, b::Field)

Elementwise, over fields that agree in all four declarations, refused through
`require_combinable` otherwise. The result carries `a`'s support and time support and
an unstamped origin written by the operator, because its numbers are new numbers that
`Provenance` has not keyed.
"""
function Base.:+(a::Field, b::Field)
    require_combinable(a, b, "Fields.+")
    return rebuild(a, a.data .+ b.data, :+)
end

function Base.:-(a::Field, b::Field)
    require_combinable(a, b, "Fields.-")
    return rebuild(a, a.data .- b.data, :-)
end

"""
    rebuild(f, data, writer)

`f`'s declarations over `data`, with an unstamped origin written by `writer` in `f`'s
run. The one place an operator in this file builds its result, so the four declarations
are carried in one place rather than at each operator.
"""
rebuild(f::Field{S,T,D}, data::AbstractArray, writer::Symbol) where {S,T,D} =
    Field(semantics = S(), dimension = D(), data = data, support = f.support,
          time = f.time, origin = unstamped(writer, f.origin.run))
