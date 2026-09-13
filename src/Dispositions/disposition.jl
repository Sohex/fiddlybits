# The five dispositions: docs/plans/fiddlybits-52v.4-system.md, section "The five
# dispositions"; decision 0007; REQ-SYS-001; REQ-SYS-103.
#
# The reference check on a Sourced locator is lint_sourced (test/lint/lint_sourced.jl),
# not a constructor refusal.

using ..Dimensions: Dim
using ..Verdicts: refuse

"""
    Disposition{T,D}

The recorded origin of one constant, over its value type `T` and its dimension
signature `D`. `value(d)` and `dimension(d)` are the two doors every subtype answers.
"""
abstract type Disposition{T,D<:Dim} end

"""
    dispositions()

The five `Disposition` subtypes, in the order decision 0007 declares them.
"""
dispositions() = (Sourced, Derived, Bracketed, Irreducible, Closure)

"""
    Sourced{T,D}(; value, dim, locator)

A measured or laboratory value with its `Locator`.
"""
struct Sourced{T,D<:Dim} <: Disposition{T,D}
    value::T
    locator::Locator

    function Sourced{T,D}(value::T, locator::Locator) where {T,D<:Dim}
        return new{T,D}(value, locator)
    end
end

function Sourced(; value::T, dim::D, locator::Locator) where {T,D<:Dim}
    return Sourced{T,D}(value, locator)
end

"""
    Derived{T,D,N}(; value, dim, from, rule, fields)

A value computed by `rule` from the fields named in `from`. `fields` is the field
name set of whatever declares this value; every entry of `from` is checked against
it, and `from` names at least one field.
"""
struct Derived{T,D<:Dim,N} <: Disposition{T,D}
    value::T
    from::NTuple{N,Symbol}
    rule::Symbol

    function Derived{T,D,N}(value::T, from::NTuple{N,Symbol},
                            rule::Symbol) where {T,D<:Dim,N}
        return new{T,D,N}(value, from, rule)
    end
end

function Derived(; value::T, dim::D, from::NTuple{N,Symbol}, rule::Symbol,
                  fields::NTuple{M,Symbol}) where {T,D<:Dim,N,M}
    isempty(from) && refuse(
        "Derived from", "Dispositions.Derived", "names no field")
    for f in from
        f in fields || refuse(
            "Derived from", "Dispositions.Derived",
            "$(f) is not a field of $(fields)")
    end
    return Derived{T,D,N}(value, from, rule)
end

"""
    Bracketed{T,D}(; value, dim, low, high, pushes_down, pushes_up, sweep)

A declared value inside `[low, high]`, both mechanisms named, and the sweep the
value is declared under.
"""
struct Bracketed{T,D<:Dim} <: Disposition{T,D}
    value::T
    low::T
    high::T
    pushes_down::String
    pushes_up::String
    sweep::Symbol

    function Bracketed{T,D}(value::T, low::T, high::T, pushes_down::String,
                            pushes_up::String, sweep::Symbol) where {T,D<:Dim}
        return new{T,D}(value, low, high, pushes_down, pushes_up, sweep)
    end
end

function Bracketed(; value::T, dim::D, low::T, high::T,
                    pushes_down::AbstractString, pushes_up::AbstractString,
                    sweep::Symbol) where {T,D<:Dim}
    low <= value <= high || refuse(
        "Bracketed value", "Dispositions.Bracketed",
        "$(value) lies outside the bracket [$(low), $(high)]")
    isempty(pushes_down) && refuse(
        "Bracketed pushes_down", "Dispositions.Bracketed",
        "no mechanism named for the low end")
    isempty(pushes_up) && refuse(
        "Bracketed pushes_up", "Dispositions.Bracketed",
        "no mechanism named for the high end")
    return Bracketed{T,D}(value, low, high, String(pushes_down), String(pushes_up),
                          sweep)
end

"""
    Irreducible{T,D}(; value, dim, argument, sensitivity)

A value with no derivation available to this system, the argument for why none
exists, and a reference to the sensitivity finding naming what it moves.
"""
struct Irreducible{T,D<:Dim} <: Disposition{T,D}
    value::T
    argument::String
    sensitivity::String

    function Irreducible{T,D}(value::T, argument::String,
                              sensitivity::String) where {T,D<:Dim}
        return new{T,D}(value, argument, sensitivity)
    end
end

function Irreducible(; value::T, dim::D, argument::AbstractString,
                      sensitivity::AbstractString) where {T,D<:Dim}
    isempty(argument) && refuse(
        "Irreducible argument", "Dispositions.Irreducible",
        "no argument for why no sourced form exists")
    isempty(sensitivity) && refuse(
        "Irreducible sensitivity", "Dispositions.Irreducible",
        "no bounded sensitivity named")
    return Irreducible{T,D}(value, String(argument), String(sensitivity))
end

"""
    Closure{T,D,N}(; law, coefficient, levels)

A coefficient standing for truncated sub-grid variance: a scaling law in mesh
spacing and resolved state, a `Bracketed` coefficient, and the mesh levels it is
swept across.
"""
struct Closure{T,D<:Dim,N} <: Disposition{T,D}
    law::Symbol
    coefficient::Bracketed{T,D}
    levels::NTuple{N,Int}

    function Closure{T,D,N}(law::Symbol, coefficient::Bracketed{T,D},
                            levels::NTuple{N,Int}) where {T,D<:Dim,N}
        return new{T,D,N}(law, coefficient, levels)
    end
end

function Closure(; law::Symbol, coefficient::Disposition{T,D},
                  levels::NTuple{N,Int}) where {T,D<:Dim,N}
    coefficient isa Bracketed{T,D} || refuse(
        "Closure coefficient", "Dispositions.Closure",
        "$(nameof(typeof(coefficient))) is not Bracketed")
    length(levels) >= 2 || refuse(
        "Closure levels", "Dispositions.Closure",
        "$(levels) names fewer than two levels")
    length(unique(levels)) >= 2 || refuse(
        "Closure levels", "Dispositions.Closure",
        "$(levels) names one level, twice")
    return Closure{T,D,N}(law, coefficient, levels)
end

"""
    value(d)

The one door out of every `Disposition`: the quantity `d` carries, regardless of how
it was justified. A `Closure` answers with its coefficient's value.
"""
value(d::Disposition) = d.value
value(d::Closure) = value(d.coefficient)

"""
    dimension(d)

The `Dim` the value of `d` carries.
"""
dimension(::Disposition{T,D}) where {T,D} = D()
