# The orbit hierarchy: one orbit per body pair, each naming its bodies and its
# reference plane, with the eccentricity refused outside the elliptic range.
# docs/plans/fiddlybits-52v.4-system.md, section "The struct"; decisions 0004 (orbits)
# and 0008 (the eccentricity guard, amendment of 2026-09-10).

using ..Verdicts: refuse
using ..Dimensions: Dim, LENGTH, DIMENSIONLESS
using ..Dispositions: Disposition, Derived, value

"A body an orbit names, by kind and declared index."
abstract type Body end

"The star declared at `index` in `System`'s `stars`."
struct StarBody <: Body
    index::Int
    StarBody(index::Integer) = index >= 1 ? new(index) :
        refuse("star index", "Systems.StarBody", "$(index) is below one")
end

"The planet."
struct PlanetBody <: Body end

"The moon declared at `index` in `System`'s `moons`."
struct MoonBody <: Body
    index::Int
    MoonBody(index::Integer) = index >= 1 ? new(index) :
        refuse("moon index", "Systems.MoonBody", "$(index) is below one")
end

"The barycentre of two or more distinct stars, named by their indices."
struct StarBarycentre{N} <: Body
    indices::NTuple{N,Int}
    function StarBarycentre(indices::Integer...)
        length(indices) >= 2 || refuse(
            "barycentre", "Systems.StarBarycentre", "$(indices) names fewer than two stars")
        length(unique(indices)) == length(indices) || refuse(
            "barycentre", "Systems.StarBarycentre", "$(indices) names one star twice")
        all(i -> i >= 1, indices) || refuse(
            "barycentre", "Systems.StarBarycentre", "$(indices) holds an index below one")
        return new{length(indices)}(Tuple(Int.(indices)))
    end
end

"The reference planes an orbit may name."
const REFERENCE_PLANES = (:invariable_plane, :primary_equator, :planet_orbit, :planet_equator)

"The kinds of primary an orbit of each kind of secondary may name."
admitted_primaries(::MoonBody) = (PlanetBody,)
admitted_primaries(::PlanetBody) = (StarBody, StarBarycentre)
admitted_primaries(::StarBody) = (StarBody, StarBarycentre)

"The reference planes an orbit of each kind of secondary may name."
admitted_planes(::MoonBody) = (:planet_equator, :planet_orbit)
admitted_planes(::PlanetBody) = (:invariable_plane, :primary_equator)
admitted_planes(::StarBody) = (:invariable_plane, :planet_orbit)

"The dimension of an irradiance: mass time^-3."
const IRRADIANCE = Dim{1,0,-3,0,0}()

"The keywords every orbit form shares."
const ORBIT_SHARED = (:primary, :secondary, :reference_plane, :eccentricity, :inclination,
                      :longitude_of_ascending_node, :argument_of_periapsis,
                      :mean_anomaly_at_epoch)

"""
    require_eccentricity(site, d, FT)

`d` when it is a declared dimensionless disposition every value of which, a
`Bracketed`'s ends included, lies in the elliptic range `[0, 1)`. Refuses at `site`
naming the value otherwise.
"""
function require_eccentricity(site::AbstractString, d, ::Type{FT}) where {FT}
    require_disposition("eccentricity", site, d, FT, DIMENSIONLESS, DECLARED)
    for e in declared_values(d)
        (zero(FT) <= e < one(FT)) || refuse(
            "eccentricity", site, "$(e) lies outside the elliptic range [0, 1)")
    end
    return d
end

"""
    shared_elements(site, k, FT)

The bodies, the reference plane and the five shared elements of an orbit's keywords
`k`, checked: the secondary a `PlanetBody`, `MoonBody` or `StarBody`; the primary of
a kind that secondary admits; the plane one of `REFERENCE_PLANES` that it admits; the
eccentricity by `require_eccentricity`; the inclination in `[0, pi]`; the node, the
argument of periapsis and the mean anomaly at the epoch in `[0, 2 pi)`.
"""
function shared_elements(site::AbstractString, k::NamedTuple, ::Type{FT}) where {FT}
    secondary = k.secondary
    secondary isa Union{PlanetBody,MoonBody,StarBody} || refuse(
        "secondary", site, "a $(typeof(secondary)) is not a body that orbits")
    primary = require_type("primary", site, k.primary, Body)
    any(K -> primary isa K, admitted_primaries(secondary)) || refuse(
        "primary", site,
        "a $(nameof(typeof(primary))) is not a primary a $(nameof(typeof(secondary))) " *
        "orbits; admitted: $(join(map(nameof, admitted_primaries(secondary)), ", "))")
    plane = k.reference_plane
    plane in admitted_planes(secondary) || refuse(
        "reference_plane", site,
        "$(plane) is not a reference plane of a $(nameof(typeof(secondary))) orbit; " *
        "admitted: $(join(admitted_planes(secondary), ", "))")
    angle(name, high, closed) = require_interval(String(name), site,
        require_disposition(String(name), site, k[name], FT, DIMENSIONLESS, DECLARED),
        zero(FT), true, high, closed)
    return (primary, secondary, plane, require_eccentricity(site, k.eccentricity, FT),
            angle(:inclination, FT(pi), true),
            angle(:longitude_of_ascending_node, 2 * FT(pi), false),
            angle(:argument_of_periapsis, 2 * FT(pi), false),
            angle(:mean_anomaly_at_epoch, 2 * FT(pi), false))
end

"""
    Orbit

One orbit of the hierarchy. Build it with a keyword constructor, which has no
defaults:

    Orbit(; primary, secondary, reference_plane, semi_major_axis, eccentricity,
            inclination, longitude_of_ascending_node, argument_of_periapsis,
            mean_anomaly_at_epoch)

or, for the planet about a single star, `FluxOrbit`. The angles are in radians. The
`flux_at_semi_major_axis` field is `nothing` for an orbit declared by its elements,
and holds the declared flux for one `System` resolved from a `FluxOrbit`, whose
semi-major axis is then `Derived`.
"""
struct Orbit{FT,P<:Body,S<:Body,A,F}
    primary::P
    secondary::S
    reference_plane::Symbol
    semi_major_axis::A
    flux_at_semi_major_axis::F
    eccentricity::Disposition{FT,typeof(DIMENSIONLESS)}
    inclination::Disposition{FT,typeof(DIMENSIONLESS)}
    longitude_of_ascending_node::Disposition{FT,typeof(DIMENSIONLESS)}
    argument_of_periapsis::Disposition{FT,typeof(DIMENSIONLESS)}
    mean_anomaly_at_epoch::Disposition{FT,typeof(DIMENSIONLESS)}

    Orbit{FT,P,S,A,F}(::Checked, fields...) where {FT,P,S,A,F} = new{FT,P,S,A,F}(fields...)
end

function build_orbit(FT, p, s, plane, a, flux, e, i, node, arg, m)
    return Orbit{FT,typeof(p),typeof(s),typeof(a),typeof(flux)}(
        Checked(), p, s, plane, a, flux, e, i, node, arg, m)
end

function Orbit(; kwargs...)
    site = "Systems.Orbit"
    k, _ = read_keywords(site, values(kwargs), (ORBIT_SHARED..., :semi_major_axis), ())
    FT = float_type("semi_major_axis", site, k.semi_major_axis)
    a = require_positive("semi_major_axis", site,
        require_disposition("semi_major_axis", site, k.semi_major_axis, FT, LENGTH, DECLARED))
    p, s, plane, e, i, node, arg, m = shared_elements(site, k, FT)
    return build_orbit(FT, p, s, plane, a, nothing, e, i, node, arg, m)
end

"""
    FluxOrbit(; primary, secondary, reference_plane, flux_at_semi_major_axis,
                eccentricity, inclination, longitude_of_ascending_node,
                argument_of_periapsis, mean_anomaly_at_epoch)

The planet's orbit declared by the top-of-atmosphere flux at its semi-major axis, a
positive irradiance, in place of the semi-major axis. The primary is a `StarBody`
and the secondary the `PlanetBody`. `System` derives the semi-major axis from the
star's luminosity, and refuses this form when more than one star is declared.
"""
struct FluxOrbit{FT,P,S}
    primary::P
    secondary::S
    reference_plane::Symbol
    flux_at_semi_major_axis::Disposition{FT,typeof(IRRADIANCE)}
    elements::NTuple{5,Disposition{FT,typeof(DIMENSIONLESS)}}

    FluxOrbit{FT,P,S}(::Checked, fields...) where {FT,P,S} = new{FT,P,S}(fields...)
end

function FluxOrbit(; kwargs...)
    site = "Systems.FluxOrbit"
    k, _ = read_keywords(site, values(kwargs), (ORBIT_SHARED..., :flux_at_semi_major_axis), ())
    FT = float_type("flux_at_semi_major_axis", site, k.flux_at_semi_major_axis)
    flux = require_positive("flux_at_semi_major_axis", site,
        require_disposition("flux_at_semi_major_axis", site, k.flux_at_semi_major_axis,
                            FT, IRRADIANCE, DECLARED))
    p, s, plane, e, i, node, arg, m = shared_elements(site, k, FT)
    (p isa StarBody && s isa PlanetBody) || refuse(
        "flux_at_semi_major_axis", site,
        "the flux form is the planet's orbit about one star, not a " *
        "$(nameof(typeof(s))) about a $(nameof(typeof(p)))")
    return FluxOrbit{FT,typeof(p),typeof(s)}(Checked(), p, s, plane, flux, (e, i, node, arg, m))
end

"""
    semi_major_axis_from_flux(FT, luminosity, flux)

`sqrt(luminosity / (4 pi flux))`: the distance at which a star of `luminosity`
gives `flux`.
"""
semi_major_axis_from_flux(::Type{FT}, luminosity::FT, flux::FT) where {FT<:AbstractFloat} =
    sqrt(luminosity / (4 * FT(pi) * flux))

"""
The rounded operations of `semi_major_axis_from_flux`: the rounding of `pi` into
`FT`, one multiply, one divide and one square root. The multiply by four is exact.
"""
const FLUX_SEMI_MAJOR_AXIS_TERMS = 4

"""
    OrbitHierarchy(; planet, moons, companions)

The orbits of a system, by name: the planet's orbit (an `Orbit` or a `FluxOrbit`
whose secondary is the `PlanetBody`); `moons`, a tuple holding the orbit of the moon
declared at each index at that index; and `companions`, a tuple of the orbits of
every star but one, each about another star or a barycentre.
"""
struct OrbitHierarchy{P,M,C}
    planet::P
    moons::M
    companions::C

    OrbitHierarchy{P,M,C}(::Checked, p, m, c) where {P,M,C} = new{P,M,C}(p, m, c)
end

function OrbitHierarchy(; kwargs...)
    site = "Systems.OrbitHierarchy"
    k, _ = read_keywords(site, values(kwargs), (:planet, :moons, :companions), ())
    planet = require_type("planet", site, k.planet, Union{Orbit,FluxOrbit})
    planet.secondary isa PlanetBody || refuse(
        "planet", site, "the planet's orbit names a $(nameof(typeof(planet.secondary)))")
    moons = require_type("moons", site, k.moons, Tuple)
    for (j, o) in enumerate(moons)
        require_type("moons", site, o, Orbit)
        o.secondary == MoonBody(j) || refuse(
            "moons", site,
            "the orbit at position $(j) names $(o.secondary), not the moon at index $(j)")
    end
    companions = require_type("companions", site, k.companions, Tuple)
    for o in companions
        require_type("companions", site, o, Orbit)
        o.secondary isa StarBody || refuse(
            "companions", site, "a companion orbit names a $(nameof(typeof(o.secondary)))")
    end
    return OrbitHierarchy{typeof(planet),typeof(moons),typeof(companions)}(
        Checked(), planet, moons, companions)
end
