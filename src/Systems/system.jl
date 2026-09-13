# System{FT}: the one struct a system is declared in, keyword-only with no defaults,
# with the refusals that read more than one block. docs/plans/fiddlybits-52v.4-system.md,
# section "The struct"; decisions 0004, 0007 and 0008.

using ..Verdicts: refuse
using ..Dimensions: TIME, LENGTH, DIMENSIONLESS
using ..Dispositions: Derived, value
using ..Reductions: error_bound

"""
    System

A declared system. Build it with the keyword constructor, which has no defaults:

    System(; stars, planet, orbits, moons, inventories, numerics)

`stars` is a tuple of one or more `Star`s, `planet` a `Planet`, `orbits` an
`OrbitHierarchy`, `moons` a tuple of zero or more `Moon`s, `inventories` an
`Inventories` and `numerics` a `Numerics`, all over one `FT`.

A synchronous rotation is held as a `SynchronousPeriod` `Derived` from the planet's
orbit, and a `FluxOrbit` as an `Orbit` whose semi-major axis is `Derived` from the
star's luminosity. A caller may also pass `sidereal_rotation_period` and
`semi_major_axis` beside those two forms, and `equatorial_surface_gravity` and
`polar_surface_gravity` (gravity on the volumetric mean radius at latitude zero and
pi/2); each is refused when it disagrees with the Derived value beyond its rounding
bound, and the first two are refused as second declarations beside the declared
forms.
"""
struct System{FT,S,P,O,M,I,N}
    stars::S
    planet::P
    orbits::O
    moons::M
    inventories::I
    numerics::N

    System{FT,S,P,O,M,I,N}(::Checked, fields...) where {FT,S,P,O,M,I,N} =
        new{FT,S,P,O,M,I,N}(fields...)
end

"The field names of `System`, the set a cross-block `Derived` value names its inputs in."
const SYSTEM_FIELDS = fieldnames(System)

"The Derived values `System` checks when a caller supplies them."
const SYSTEM_CHECKED = (:equatorial_surface_gravity, :polar_surface_gravity,
                        :sidereal_rotation_period, :semi_major_axis)

"The masses of the bodies `b` names, as a tuple."
body_masses(stars, planet, moons, b::StarBody) = (value(stars[b.index].mass),)
body_masses(stars, planet, moons, b::StarBarycentre) =
    Tuple(value(stars[i].mass) for i in b.indices)
body_masses(stars, planet, moons, ::PlanetBody) = (value(planet.mass),)
body_masses(stars, planet, moons, b::MoonBody) = (value(moons[b.index].mass),)

"The masses of both bodies of `orbit`, as one tuple."
orbit_masses(stars, planet, moons, orbit) =
    (body_masses(stars, planet, moons, orbit.primary)...,
     body_masses(stars, planet, moons, orbit.secondary)...)

"""
    orbital_period(system, orbit)

`orbital_period` of `orbit`, an orbit `system` holds, over the masses of its two
bodies.
"""
orbital_period(s::System{FT}, orbit::Orbit) where {FT} =
    orbital_period(FT, value(orbit.semi_major_axis),
                   orbit_masses(s.stars, s.planet, s.moons, orbit))

"""
    require_body(site, body, stars, moons)

`body` when every index it names is a declared star or moon; refuses at `site`
naming the body otherwise.
"""
function require_body(site::AbstractString, b::Body, n_stars::Int, n_moons::Int)
    indices = b isa StarBody ? (b.index,) : b isa StarBarycentre ? b.indices : ()
    for i in indices
        i <= n_stars || refuse("orbits", site, "$(b) names star $(i) of $(n_stars) declared")
    end
    b isa MoonBody && b.index > n_moons && refuse(
        "orbits", site, "$(b) names moon $(b.index) of $(n_moons) declared")
    return b
end

"""
    require_hierarchy(site, stars, moons, orbits)

`orbits` when every body it names is declared, there is one moon orbit per moon, and
every star but one has exactly one orbit, none about itself. Refuses at `site`
otherwise.
"""
function require_hierarchy(site::AbstractString, stars::Tuple, moons::Tuple,
                           orbits::OrbitHierarchy)
    n, m = length(stars), length(moons)
    for o in (orbits.planet, orbits.moons..., orbits.companions...)
        require_body(site, o.primary, n, m)
        require_body(site, o.secondary, n, m)
    end
    length(orbits.moons) == m || refuse(
        "orbits", site, "$(length(orbits.moons)) moon orbits for $(m) declared moons")
    orbiting = [o.secondary.index for o in orbits.companions]
    length(unique(orbiting)) == length(orbiting) || refuse(
        "orbits", site, "a star has two companion orbits: $(orbiting)")
    length(orbiting) == n - 1 || refuse(
        "orbits", site,
        "$(length(orbiting)) companion orbits for $(n) stars; every star but one has one")
    for o in orbits.companions
        p, i = o.primary, o.secondary.index
        if (p isa StarBody && p.index == i) || (p isa StarBarycentre && i in p.indices)
            refuse("orbits", site, "star $(i) is declared to orbit $(p), which holds it")
        end
    end
    return orbits
end

"""
    resolve_planet_orbit(orbit, stars, supplied, site)

The planet's orbit as `System` holds it: an `Orbit` as declared, refusing a supplied
`semi_major_axis` as a second declaration; or a `FluxOrbit` as an `Orbit` whose
semi-major axis is `Derived` by `semi_major_axis_from_flux`, refused when more than
one star is declared, and checked against a supplied `semi_major_axis`.
"""
function resolve_planet_orbit(o::Orbit, stars::Tuple, supplied::NamedTuple,
                              site::AbstractString)
    haskey(supplied, :semi_major_axis) && refuse(
        "semi_major_axis", site, "declared in the planet's Orbit already; a second value is refused")
    return o
end

function resolve_planet_orbit(o::FluxOrbit{FT}, stars::Tuple, supplied::NamedTuple,
                              site::AbstractString) where {FT}
    length(stars) == 1 || refuse(
        "flux_at_semi_major_axis", site,
        "the planet's orbit is declared by its flux with $(length(stars)) stars " *
        "declared, where the flux is not a constant of the orbit (decision 0004)")
    luminosity = value(stars[o.primary.index].luminosity)
    a = semi_major_axis_from_flux(FT, luminosity, value(o.flux_at_semi_major_axis))
    haskey(supplied, :semi_major_axis) && check_supplied(
        "semi_major_axis", site, supplied.semi_major_axis, a, FLUX_SEMI_MAJOR_AXIS_TERMS, a)
    derived = Derived(value = a, dim = LENGTH, from = (:stars, :orbits),
                      rule = :flux_semi_major_axis, fields = SYSTEM_FIELDS)
    return build_orbit(FT, o.primary, o.secondary, o.reference_plane, derived,
                       o.flux_at_semi_major_axis, o.elements...)
end

"""
    resolve_rotation(planet, stars, moons, orbit, supplied, site)

The planet as `System` holds it: a `SiderealRotation` as declared, refusing a
supplied `sidereal_rotation_period` as a second declaration; or a
`SynchronousRotation` resolved to a `SynchronousPeriod`, refused unless the
`Derived` sense of decision 0004 is prograde, the orbital period of the planet's
orbit checked against a supplied `sidereal_rotation_period`.
"""
function resolve_rotation(p::Planet{FT,B,<:SiderealRotation}, stars, moons, orbit,
                          supplied::NamedTuple, site::AbstractString) where {FT,B}
    haskey(supplied, :sidereal_rotation_period) && refuse(
        "sidereal_rotation_period", site,
        "declared in the SiderealRotation already; a second value is refused")
    return p
end

function resolve_rotation(p::Planet{FT,B,SynchronousRotation}, stars, moons, orbit,
                          supplied::NamedTuple, site::AbstractString) where {FT,B}
    rotation_sense(p) === :prograde || refuse(
        "rotation", site,
        "a synchronous rotation is refused: its Derived sense from the obliquity is " *
        "not prograde (decision 0004)")
    masses = orbit_masses(stars, p, moons, orbit)
    period = orbital_period(FT, value(orbit.semi_major_axis), masses)
    haskey(supplied, :sidereal_rotation_period) && check_supplied(
        "sidereal_rotation_period", site, supplied.sidereal_rotation_period, period,
        orbital_period_terms(length(masses)), period)
    derived = Derived(value = period, dim = TIME, from = (:stars, :planet, :orbits),
                      rule = :synchronous_rotation_period, fields = SYSTEM_FIELDS)
    return with_rotation(p, SynchronousPeriod(derived))
end

"""
The rounded operations of the subsolar latitude `asin(sin(obliquity) sin(longitude))`:
three library transcendentals at two each, being within one ulp, and one multiply.
"""
const DECLINATION_TERMS = 7

"""
    require_epoch(site, epoch, planet, orbits, n_stars, n_moons)

`epoch` when its source is declared and its kind is admissible. A periapsis read of a
star needs that star to have an orbit. The vernal equinox needs the named star to be
the planet's single primary, and the sine of every obliquity the planet declares to
exceed `Reductions.error_bound(FT, DECLINATION_TERMS, 1)`, the rounding of the
subsolar latitude. The superior conjunction needs a synchronous rotator. Refuses at
`site` otherwise, naming decision 0008.
"""
function require_epoch(site::AbstractString, epoch::EpochReference, p::Planet{FT},
                       orbits::OrbitHierarchy, n_stars::Int, n_moons::Int) where {FT}
    source = require_body(site, epoch.source, n_stars, n_moons)
    if epoch.kind === :periapsis && source isa StarBody
        any(o -> o.secondary == source, orbits.companions) || refuse(
            "epoch", site, "the periapsis of $(source) is named, and that star has no orbit")
    elseif epoch.kind === :vernal_equinox
        primary = orbits.planet.primary
        primary == source || refuse(
            "epoch", site,
            "the vernal equinox of $(source) needs that star as the planet's single " *
            "primary, and the planet orbits $(primary) (decision 0008)")
        threshold = error_bound(FT, DECLINATION_TERMS, one(FT))
        for obliquity in declared_values(p.obliquity)
            sin(obliquity) > threshold || refuse(
                "obliquity", site,
                "the vernal equinox is refused at obliquity $(obliquity): its sine does " *
                "not exceed $(threshold), the rounding of the subsolar latitude, so the " *
                "equinox instant does not exist (decision 0008)")
        end
    elseif epoch.kind === :superior_conjunction
        p.rotation isa SynchronousPeriod || refuse(
            "epoch", site, "the superior conjunction kind is declared for a synchronous " *
            "rotator, and the planet's rotation is not synchronous (decision 0008)")
    end
    return epoch
end

function System(; kwargs...)
    site = "Systems.System"
    k, supplied = read_keywords(site, values(kwargs),
                                (:stars, :planet, :orbits, :moons, :inventories, :numerics),
                                SYSTEM_CHECKED)
    stars = require_type("stars", site, k.stars, Tuple)
    isempty(stars) && refuse("stars", site, "declares no star; a system has one or more")
    FT = typeof(value(require_type("stars", site, first(stars), Star).mass))
    for s in stars
        require_type("stars", site, s, Star{FT})
    end
    planet = require_type("planet", site, k.planet, Planet{FT})
    moons = require_type("moons", site, k.moons, Tuple)
    for moon in moons
        require_type("moons", site, moon, Moon{FT})
    end
    inventories = require_type("inventories", site, k.inventories, Inventories{FT})
    numerics = require_type("numerics", site, k.numerics, Numerics{FT})
    declared = require_hierarchy(site, stars, moons,
        require_type("orbits", site, k.orbits, OrbitHierarchy))
    planet_orbit = resolve_planet_orbit(declared.planet, stars, supplied, site)
    for o in (planet_orbit, declared.moons..., declared.companions...)
        typeof(value(o.eccentricity)) === FT || refuse(
            "orbits", site, "an orbit's type differs from the stars'")
    end
    orbits = OrbitHierarchy{typeof(planet_orbit),typeof(declared.moons),
                            typeof(declared.companions)}(
        Checked(), planet_orbit, declared.moons, declared.companions)
    held = resolve_rotation(planet, stars, moons, planet_orbit, supplied, site)

    radius = value(held.volumetric_mean_radius)
    for (name, phi) in ((:equatorial_surface_gravity, zero(FT)),
                        (:polar_surface_gravity, FT(pi) / 2))
        haskey(supplied, name) && check_supplied(
            String(name), site, supplied[name], gravity(held, radius, phi),
            GRAVITY_TERMS, gravity_magnitude(held, radius, phi))
    end
    require_epoch(site, numerics.epoch, held, orbits, length(stars), length(moons))

    return System{FT,typeof(stars),typeof(held),typeof(orbits),typeof(moons),
                  typeof(inventories),typeof(numerics)}(
        Checked(), stars, held, orbits, moons, inventories, numerics)
end
