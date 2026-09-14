# Numerics: the declared conventions of how a system is represented that no profile
# may vary. docs/plans/fiddlybits-52v.4-system.md, section "The struct"; decisions
# 0008 (the epoch), 0013 (the Exner reference pressure) and 0014.

using ..Verdicts: refuse
using ..Dimensions: Dim, TIME
using ..Dispositions: Disposition, value

"The epoch event kinds of decision 0008."
const EPOCH_KINDS = (:vernal_equinox, :periapsis, :superior_conjunction)

"""
    EpochReference(; kind, source, offset)

Where `t = 0` is: the event `kind`, one of `EPOCH_KINDS`; the `source` it is read
of, a `Body` (a `StarBody` for the vernal equinox and the superior conjunction, the
secondary of the orbit whose periapsis it is otherwise); and the declared `offset`
in seconds from that event.
"""
struct EpochReference{FT,B<:Body}
    kind::Symbol
    source::B
    offset::Disposition{FT,typeof(TIME)}

    EpochReference{FT,B}(::Checked, k, s, o) where {FT,B} = new{FT,B}(k, s, o)
end

function EpochReference(; kwargs...)
    site = "Systems.EpochReference"
    k, _ = read_keywords(site, values(kwargs), (:kind, :source, :offset), ())
    k.kind in EPOCH_KINDS || refuse(
        "kind", site, "$(k.kind) is not one of $(join(EPOCH_KINDS, ", "))")
    source = require_type("source", site, k.source, Body)
    if k.kind === :periapsis
        source isa Union{PlanetBody,MoonBody,StarBody} || refuse(
            "source", site, "a $(nameof(typeof(source))) has no orbit whose periapsis is named")
    else
        source isa StarBody || refuse(
            "source", site,
            "the $(k.kind) kind is read of a named star, and $(source) names none")
    end
    FT = float_type("offset", site, k.offset)
    offset = require_disposition("offset", site, k.offset, FT, TIME, DECLARED)
    return EpochReference{FT,typeof(source)}(Checked(), k.kind, source, offset)
end

"The dimension of a pressure: mass length^-1 time^-2."
const PRESSURE = Dim{1,-1,-2,0,0}()

"The precision the mesh geometry is formed in."
const GEOMETRY_PRECISION = Float64

"""
    Numerics

The conventions of a system's representation that no profile may vary. Build it with
the keyword constructor, which has no defaults:

    Numerics(; epoch, exner_reference_pressure, geometry_precision)

`epoch` is an `EpochReference`; `exner_reference_pressure` is a declared pressure
above zero; `geometry_precision` is the type the geometry is formed in, and anything
but `Float64` is refused.
"""
struct Numerics{FT,E}
    epoch::E
    exner_reference_pressure::Disposition{FT,typeof(PRESSURE)}
    geometry_precision::Type{Float64}

    Numerics{FT,E}(::Checked, e, p, g) where {FT,E} = new{FT,E}(e, p, g)
end

function Numerics(; kwargs...)
    site = "Systems.Numerics"
    k, _ = read_keywords(site, values(kwargs),
                         (:epoch, :exner_reference_pressure, :geometry_precision), ())
    FT = float_type("exner_reference_pressure", site, k.exner_reference_pressure)
    epoch = require_type("epoch", site, k.epoch, EpochReference{FT})
    pressure = require_positive("exner_reference_pressure", site,
        require_disposition("exner_reference_pressure", site, k.exner_reference_pressure,
                            FT, PRESSURE, DECLARED))
    k.geometry_precision === GEOMETRY_PRECISION || refuse(
        "geometry_precision", site,
        "$(k.geometry_precision) where the geometry is formed in $(GEOMETRY_PRECISION)")
    return Numerics{FT,typeof(epoch)}(Checked(), epoch, pressure, GEOMETRY_PRECISION)
end
