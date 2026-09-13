# strip(system): the isbits constants of a System, the one route from parameters to a
# device. docs/plans/fiddlybits-52v.4-system.md, section "The struct"; decision 0007.
#
# Names travel on the stripped types as type parameters (a body, a reference plane, a
# province class, a species), so an isbits struct still reads its members by name.

using ..Verdicts: refuse
using ..Dispositions: value

"One cycle component of a star's variability, as plain values."
struct StrippedCycle{FT}
    amplitude::FT
    period::FT
    phase::FT
end

"A star's band output, as plain values."
struct StrippedBand{FT}
    upper_wavelength::FT
    luminosity_fraction::FT
end

"A star's scalar constants. The spectrum stays on the host."
struct StrippedStar{FT,K}
    mass::FT
    age::FT
    metal_mass_fraction::FT
    luminosity::FT
    radius::FT
    effective_temperature::FT
    variability::NTuple{K,StrippedCycle{FT}}
    ultraviolet::StrippedBand{FT}
    activity::StrippedBand{FT}
end

"The lithosphere block, its province classes named by the type parameter `Classes`."
struct StrippedLithosphere{FT,Classes,K}
    mantle_potential_temperature::FT
    mantle_thermal_diffusivity::FT
    mantle_thermal_expansivity::FT
    mantle_density::FT
    radiogenic_heat_production::FT
    crustal_density::NTuple{K,FT}
    crustal_thickness::NTuple{K,FT}
end

"""
    province_value(lithosphere, member, class)

The value of the per-class `member` (`:crustal_density` or `:crustal_thickness`) for
the province class named `class`; refuses a class the lithosphere does not name.
"""
function province_value(l::StrippedLithosphere{FT,Classes}, member::Symbol,
                        class::Symbol) where {FT,Classes}
    i = findfirst(==(class), Classes)
    i === nothing && refuse("province class", "Systems.province_value",
                            "$(class) is not one of $(Classes)")
    return getfield(l, member)[i]
end

"""
The planet's constants, its rotation sense named by the type parameter `Sense`
(`:prograde`, `:retrograde` or `:synchronous`).
"""
struct StrippedPlanet{FT,Sense,Classes,K}
    mass::FT
    gravitational_parameter::FT
    volumetric_mean_radius::FT
    sidereal_rotation_period::FT
    obliquity::FT
    equator_pole_gravity_difference::FT
    lithosphere::StrippedLithosphere{FT,Classes,K}
end

"""
One orbit's constants, its primary and secondary bodies and its reference plane named
by the type parameters `Primary`, `Secondary` and `Plane`.
"""
struct StrippedOrbit{FT,Primary,Secondary,Plane}
    semi_major_axis::FT
    eccentricity::FT
    inclination::FT
    longitude_of_ascending_node::FT
    argument_of_periapsis::FT
    mean_anomaly_at_epoch::FT
    primary_mass::FT
    secondary_mass::FT
end

"The orbit hierarchy's constants, by name."
struct StrippedOrbits{P,M,C}
    planet::P
    moons::M
    companions::C
end

"A moon's constants. The reflectance stays on the host."
struct StrippedMoon{FT}
    mass::FT
    radius::FT
end

"A set of named amounts or fractions, the names carried by the type parameter `Names`."
struct StrippedNamed{FT,Basis,Names,N}
    values::NTuple{N,FT}
end

"""
The inventories' constants, the condensable named by the type parameter `Condensable`
(a species, or the type `NoCondensable`).
"""
struct StrippedInventories{V,C,O,A,Condensable}
    volatiles::V
    crust::C
    ocean_solutes::O
    atmosphere::A
end

"The numerics' constants, the epoch kind and source named by type parameters."
struct StrippedNumerics{FT,Kind,Source}
    epoch_offset::FT
    exner_reference_pressure::FT
end

"The isbits constants of a `System`."
struct StrippedSystem{FT,S,P,O,M,I,N}
    stars::S
    planet::P
    orbits::O
    moons::M
    inventories::I
    numerics::N
end

"""
    named_value(stripped, name)

The value `name` holds in a `StrippedNamed`; refuses a name it does not carry.
"""
function named_value(s::StrippedNamed{FT,Basis,Names}, name::Symbol) where {FT,Basis,Names}
    i = findfirst(==(name), Names)
    i === nothing && refuse("name", "Systems.named_value", "$(name) is not one of $(Names)")
    return s.values[i]
end

strip_star(s::Star{FT}) where {FT} = StrippedStar{FT,length(s.variability)}(
    value(s.mass), value(s.age), value(s.metal_mass_fraction), value(s.luminosity),
    value(s.radius), value(s.effective_temperature),
    Tuple(StrippedCycle{FT}(value(c.amplitude), value(c.period), value(c.phase))
          for c in s.variability),
    StrippedBand{FT}(value(s.ultraviolet.upper_wavelength), value(s.ultraviolet.luminosity_fraction)),
    StrippedBand{FT}(value(s.activity.upper_wavelength), value(s.activity.luminosity_fraction)))

function strip_planet(p::Planet{FT,B,R,F,K}) where {FT,B,R,F,K}
    l = p.lithosphere
    lithosphere = StrippedLithosphere{FT,l.province_classes,K}(
        value(l.mantle_potential_temperature), value(l.mantle_thermal_diffusivity),
        value(l.mantle_thermal_expansivity), value(l.mantle_density),
        value(l.radiogenic_heat_production), map(value, l.crustal_density),
        map(value, l.crustal_thickness))
    return StrippedPlanet{FT,rotation_sense(p.rotation),l.province_classes,K}(
        value(p.mass), gravitational_parameter(FT, value(p.mass)),
        value(p.volumetric_mean_radius), value(rotation_period(p.rotation)),
        value(p.obliquity), value(p.figure.equator_pole_gravity_difference), lithosphere)
end

function strip_orbit(s::System{FT}, o::Orbit) where {FT}
    primary = sum(body_masses(s.stars, s.planet, s.moons, o.primary))
    secondary = sum(body_masses(s.stars, s.planet, s.moons, o.secondary))
    return StrippedOrbit{FT,o.primary,o.secondary,o.reference_plane}(
        value(o.semi_major_axis), value(o.eccentricity), value(o.inclination),
        value(o.longitude_of_ascending_node), value(o.argument_of_periapsis),
        value(o.mean_anomaly_at_epoch), primary, secondary)
end

strip_named(x::SpeciesAmounts{FT,N}) where {FT,N} =
    StrippedNamed{FT,:mass,x.species,N}(map(value, x.amounts))
strip_named(x::Fractions{FT,N}) where {FT,N} =
    StrippedNamed{FT,x.basis,x.members,N}(map(value, x.fractions))

"""
    strip(system)

The `StrippedSystem` of `system`: every scalar constant it holds as a plain `FT`, in
named fields, with the names a kernel reads members by carried as type parameters.
A function of `system` alone; the spectra and the reflectance tables are not scalars
and stay on the host.
"""
function strip(s::System{FT}) where {FT}
    inv = s.inventories
    condensable = inv.condensable isa Symbol ? inv.condensable : NoCondensable
    epoch = s.numerics.epoch
    stars = map(strip_star, s.stars)
    planet = strip_planet(s.planet)
    orbits = StrippedOrbits(strip_orbit(s, s.orbits.planet),
                            Tuple(strip_orbit(s, o) for o in s.orbits.moons),
                            Tuple(strip_orbit(s, o) for o in s.orbits.companions))
    moons = Tuple(StrippedMoon{FT}(value(m.mass), value(m.radius)) for m in s.moons)
    named = map(strip_named, (inv.volatiles, inv.crust, inv.ocean_solutes, inv.atmosphere))
    inventories = StrippedInventories{map(typeof, named)..., condensable}(named...)
    numerics = StrippedNumerics{FT,epoch.kind,epoch.source}(
        value(epoch.offset), value(s.numerics.exner_reference_pressure))
    return StrippedSystem{FT,typeof(stars),typeof(planet),typeof(orbits),typeof(moons),
                          typeof(inventories),typeof(numerics)}(
        stars, planet, orbits, moons, inventories, numerics)
end
