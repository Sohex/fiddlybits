# The initial inventories: the volatile budget, the bulk crustal composition, the
# ocean solutes' ionic composition, the initial atmosphere and the condensable.
# docs/plans/fiddlybits-52v.4-system.md, sections "Scope" and "The struct"; decision
# 0004, initial inventories.

using ..Verdicts: refuse
using ..Dimensions: MASS, DIMENSIONLESS
using ..Dispositions: Disposition, Bracketed, value

"""
    SpeciesAmounts(; species, amounts)

The volatile budget: the named `species` and a tuple of one mass per species, each
declared and zero or above.
"""
struct SpeciesAmounts{FT,N}
    species::NTuple{N,Symbol}
    amounts::NTuple{N,Disposition{FT,typeof(MASS)}}

    SpeciesAmounts{FT,N}(::Checked, s, a) where {FT,N} = new{FT,N}(s, a)
end

function SpeciesAmounts(; kwargs...)
    site = "Systems.SpeciesAmounts"
    k, _ = read_keywords(site, values(kwargs), (:species, :amounts), ())
    species = require_names("species", site, k.species)
    amounts = require_length("amounts", site, k.amounts, length(species), "species")
    FT = float_type("amounts", site, first(amounts))
    for d in amounts
        require_interval("amounts", site,
            require_disposition("amounts", site, d, FT, MASS, DECLARED),
            zero(FT), true, typemax(FT), true)
    end
    return SpeciesAmounts{FT,length(species)}(Checked(), species, amounts)
end

"The bases a set of fractions is declared on."
const FRACTION_BASES = (:mass, :mole)

"""
    Fractions(; basis, members, fractions)

A composition: the `basis`, `:mass` or `:mole`; the named `members`; and a tuple of
one fraction per member, each declared in `[0, 1]`, summing to one within rounding.
"""
struct Fractions{FT,N}
    basis::Symbol
    members::NTuple{N,Symbol}
    fractions::NTuple{N,Disposition{FT,typeof(DIMENSIONLESS)}}

    Fractions{FT,N}(::Checked, b, m, f) where {FT,N} = new{FT,N}(b, m, f)
end

function Fractions(; kwargs...)
    site = "Systems.Fractions"
    k, _ = read_keywords(site, values(kwargs), (:basis, :members, :fractions), ())
    k.basis in FRACTION_BASES || refuse(
        "basis", site, "$(k.basis) is not one of $(join(FRACTION_BASES, ", "))")
    members = require_names("members", site, k.members)
    fractions = require_length("fractions", site, k.fractions, length(members), "member")
    FT = float_type("fractions", site, first(fractions))
    for d in fractions
        require_interval("fractions", site,
            require_disposition("fractions", site, d, FT, DIMENSIONLESS, DECLARED),
            zero(FT), true, one(FT), true)
    end
    require_unit_sum("fractions", site, fractions)
    return Fractions{FT,length(members)}(Checked(), k.basis, members, fractions)
end

"""
    NoCondensable(; argument)

The condensable declared absent, with the argument for its absence.
"""
struct NoCondensable
    argument::String

    NoCondensable(::Checked, a) = new(a)
end

function NoCondensable(; kwargs...)
    site = "Systems.NoCondensable"
    k, _ = read_keywords(site, values(kwargs), (:argument,), ())
    (k.argument isa AbstractString && !isempty(k.argument)) || refuse(
        "argument", site, "the absence carries no argument")
    return NoCondensable(Checked(), String(k.argument))
end

"""
    Inventories

The initial inventories of a system. Build it with the keyword constructor, which has
no defaults:

    Inventories(; volatiles, crust, ocean_solutes, atmosphere, condensable)

`volatiles` is a `SpeciesAmounts`. `crust` and `ocean_solutes` are `Fractions` on the
mass basis, the second over the major ions of the dissolved load. `atmosphere` is a
`Fractions` on the mole basis, the initial composition, each fraction `Bracketed`.
`condensable` is a species of `volatiles`, by name, or a `NoCondensable`.
"""
struct Inventories{FT,V,C,O,A,Q}
    volatiles::V
    crust::C
    ocean_solutes::O
    atmosphere::A
    condensable::Q

    Inventories{FT,V,C,O,A,Q}(::Checked, fields...) where {FT,V,C,O,A,Q} =
        new{FT,V,C,O,A,Q}(fields...)
end

function Inventories(; kwargs...)
    site = "Systems.Inventories"
    k, _ = read_keywords(site, values(kwargs),
                         (:volatiles, :crust, :ocean_solutes, :atmosphere, :condensable), ())
    volatiles = require_type("volatiles", site, k.volatiles, SpeciesAmounts)
    FT = typeof(value(first(volatiles.amounts)))
    crust = require_type("crust", site, k.crust, Fractions{FT})
    solutes = require_type("ocean_solutes", site, k.ocean_solutes, Fractions{FT})
    atmosphere = require_type("atmosphere", site, k.atmosphere, Fractions{FT})
    for (name, f, basis) in (("crust", crust, :mass), ("ocean_solutes", solutes, :mass),
                             ("atmosphere", atmosphere, :mole))
        f.basis === basis || refuse(
            name, site, "declared on the $(f.basis) basis where the $(basis) basis is required")
    end
    for d in atmosphere.fractions
        require_disposition("atmosphere", site, d, FT, DIMENSIONLESS, (Bracketed,))
    end
    condensable = k.condensable
    if condensable isa Symbol
        condensable in volatiles.species || refuse(
            "condensable", site,
            "$(condensable) is not a species of the volatile budget $(volatiles.species)")
    else
        require_type("condensable", site, condensable, NoCondensable)
    end
    return Inventories{FT,typeof(volatiles),typeof(crust),typeof(solutes),
                       typeof(atmosphere),typeof(condensable)}(
        Checked(), volatiles, crust, solutes, atmosphere, condensable)
end
