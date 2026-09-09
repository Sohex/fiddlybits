+++
id = "0004"
title = "Foundational free parameters are only those that cannot be derived and sit upstream of everything"
status = "accepted"
date = 2026-09-08
+++

## Decision

The system's free inputs are the quantities that no mechanism in the model can derive
and that nothing else in the model precedes. Everything else is a state the run
produces, or a declared-with-bracket initial condition where the model has no
mechanism yet, and the parameter's disposition (decision 0007) says which.

The foundational set:

- **Stars, one or more.** Mass, age and metallicity as the primary declarations.
  Luminosity, effective temperature, radius and spectrum are derived from those where
  a stellar model is carried, and are `Bracketed` declarations where it is not. The
  stellar model is a `Sourced` law with a declared (mass, age, metallicity) domain,
  and the derivation refuses outside that domain by name, because a relation fitted
  on one stellar sample is silent about the stars it was not fitted on. The stellar
  radius is `Derived` from the carried model or `Bracketed`, never absent, because
  the eclipse and transit geometry of decision 0032 reads it. The spectrum is a
  declared artifact read from a stellar atmosphere grid (an input manifest under
  `docs/inputs/`) until such a grid is part of the system; interpolation in the grid
  refuses outside the grid's convex hull in its own axes, and the grid identifier is
  part of the run identity. Activity and the ultraviolet output are declared with
  brackets. Periodic variability is declared as zero or more cycle components
  (amplitude, period, phase); a component of zero amplitude is admissible and its
  period is never read as a window (decision 0023).
- **The planet's bulk.** Mass; radius, or a composition vector (iron, silicate,
  water and envelope mass fractions) from which radius follows by an interior model
  where one is carried, the model a `Sourced` law with a declared domain and no
  default composition; the sidereal rotation period, with the sense of rotation
  relative to the planet's orbit normal (the constructor refuses any field named
  "day"; the solar and mean solar day are derived by decision 0008); obliquity,
  measured from the planet's orbit normal; and the planet's orbit, declared as below.
  Gravity is a `Derived` field of radius and latitude, `g(r, phi)`, from the mass,
  the radial distance and the rotation vector with the centrifugal term included; a
  caller who also passes a surface value is refused on disagreement. The figure of
  the planet is a `Derived` hydrostatic figure from the rotation and the interior
  model, or a declared absence with the equator-pole gravity difference `Bracketed`
  (faster rotation and a less centrally condensed interior push it up; slower
  rotation and a denser core push it down) and reported. The mesh radius of decision
  0005 is the volumetric mean radius of that figure, and the geopotential of a cell
  is computed from `g(r, phi)`, never from a sphere.
- **Orbits.** Every orbit is declared per body pair in a named hierarchy (the planet
  about a named star or barycentre, each moon about the planet, each companion star
  about the primary or the barycentre), with the reference plane named for each:
  semi-major axis, eccentricity, inclination, longitude of the ascending node,
  argument of periapsis, and the phase at the epoch of decision 0008. A planet orbit
  may alternatively be declared as the top-of-atmosphere flux with the luminosity in
  a single-star system only; with more than one star the constructor refuses that
  form, because the flux is then not a constant of the orbit.
- **The lithosphere block of `System`.** Mantle potential temperature, mantle thermal
  diffusivity, mantle thermal expansivity, mantle density, crustal density per
  province class, crustal thickness per province class, and radiogenic heat
  production, each `Bracketed` with both ends argued from the declared mass, age and
  bulk composition: secular cooling with age and a smaller mass push the potential
  temperature and the heat production down, while the radiogenic inventory of the
  bulk composition and a larger mass push them up; the mineralogy the composition
  admits and the pressure at depth bound the diffusivity, the expansivity and the
  densities on both sides; melt production at the potential temperature bounds a
  province's crustal thickness from below and the erosion of an old province bounds
  it from above. The terrain subsystem derives subsidence, elastic thickness, ridge
  depth and basal heat flux from this block; Earth's values are reported as
  distances from it, never used as the point.
- **Moons, zero or more.** Mass; radius; a reflectance spectrum artifact (a `Sourced`
  input, its band values `Derived` against the declared stellar spectra); and the
  orbit about the planet in the form above (semi-major axis, eccentricity,
  inclination, longitude of the ascending node, argument of periapsis, phase), with
  the reference plane named as the planet's equator or the planet's orbit. Their
  tides, the planet's rotation evolution, obliquity stability, eclipses and reflected
  light are derived effects, and which of those exist in the physics at any point is
  recorded in decision 0002; the light effects are derived from the start (decision
  0032), which is why a moon's radius, reflectance and orbit orientation are
  foundational and carry no default.
- **Initial inventories.** The volatile budget (water, nitrogen, carbon, noble gases,
  sulphur as needed by the composition), and the bulk crustal composition the
  tectonic seed draws lithologies from. The atmosphere's composition at equilibrium
  is a result of the run wherever the model carries the cycle (carbon, water); it is a
  declared initial condition with a bracket where it does not (nitrogen partial
  pressure until an outgassing-escape balance exists). The ocean solute inventory
  carries a declared ionic composition (the major ions as mass fractions of the
  dissolved load); seawater thermodynamics are `Irreducible` inside the
  Reference-Composition anomaly tolerance of the declared composition and refused
  beyond it, with the fence written in decision 0017.

What is explicitly **not** foundational, and is therefore a derived state or a
bracketed initial condition with a mechanism to remove it later:

- Ocean salinity and its distribution (a salt budget with river solute, brine
  rejection and evaporite sinks; the global inventory is a bracketed initial
  condition).
- Sea level and the land fraction (from the volatile inventory, the terrain and the
  ice).
- Ice cover, snow cover, lake extent, drainage topology, vegetation cover, soil
  properties, dust burden, cloud properties.
- The carbon dioxide partial pressure (solved by the weathering-outgassing balance
  where the carbon loop runs; a bracketed declaration before that).
- Any coupling between latitude and climate, between relief and ice, between
  drainage and aridity. These are computed outcomes of the declared system; none is a
  rule. The predecessor's record shows a world in which polar summers were hotter
  than the tropics and ice sat in mid-latitude relief; nothing about that generalises
  except that nothing about Earth's arrangement generalises either.

## Alternatives considered

- **Declare what the predecessor declared** (its planet file carried salinity, mixed
  layer depth, sea-ice material constants, a land albedo assumption and a fixed
  carbon dioxide pressure as inputs). Each of those was a declaration standing in for
  a mechanism, and each drifted from the state the run produced. Lost; the design
  exists to replace the declarations with mechanisms, and the interfaces for those
  mechanisms exist from the founding (decision 0003, principle 1).
- **A larger foundational set for convenience** (declare the spectrum, the day
  length, the year length directly). Every derived quantity that is also declarable
  is a place two values can disagree. The constructor accepts a value for a derived
  field only to check it, and refuses on disagreement.

## Consequences

- The `System` struct of decision 0007 has exactly this shape: stars, planet (with
  its lithosphere block), orbits, moons, inventories, numerics.
- The M0 gate of decision 0034 validates every `Derived` field of this struct on
  `Earth()` and on a synthetic non-Earth instance with closed forms, so a derivation
  that is right on one configuration by coincidence has a test that can fail.
- The clock of decision 0008 derives every temporal quantity from this set.
- Every subsystem record names which bracketed initial conditions it still carries
  and which mechanism would remove them.
- The multi-star and moon interfaces (instellation from several sources, eclipse
  geometry, tidal forcing fields) are complete at the founding; their physics
  arrives per decision 0002.

## References

- The predecessor's planet parameter file and its status vocabulary (determined,
  declared, provisional, derived): `/home/cfutro/docs/world/config/planet.yaml`.
- The predecessor's audit of derived quantities that were written down and drifted:
  `/home/cfutro/docs/world/notes/audits/frozen-derived-quantities.md`.
- The predecessor's finding that ocean salinity was the declared value least likely
  to be right on a world with a large internally drained share:
  `/home/cfutro/docs/world/config/planet.yaml`, ocean block, and
  `/home/cfutro/docs/world/notes/audits/ocean-tier-implicit-earth.md`.
- Murray and Dermott (1999), Solar System Dynamics (locator in decision 0032): the
  orbital-element set and the hydrostatic figure the planet and orbit blocks are
  shaped by.
- Millero, Feistel, Wright and McDougall (2008): the Reference Composition of
  seawater and the anomaly tolerance the solute inventory's fence is stated against.
- Turcotte and Schubert (2014), Geodynamics: the lithosphere quantities the terrain
  subsystem derives from the lithosphere block.

## Amendments

- 2026-09-08: stars carry a Sourced stellar model with a declared (mass, age, metallicity) domain, a radius that is never absent, grid interpolation refusing outside the hull, and cycle components of zero amplitude admissible, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the declared rotation is the sidereal rotation period with sense relative to the orbit normal, and a field named "day" is refused, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: gravity is Derived as g(r, phi) with the centrifugal term, the figure of the planet is Derived or a declared absence with a Bracketed equator-pole difference, and the mesh radius is named as the volumetric mean radius, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: orbits are declared per body pair in a named hierarchy with node, argument of periapsis and reference plane, and the flux-declared form is admitted for a single star only, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the lithosphere block of System is added, each field Bracketed with both ends argued, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: moons carry radius, a reflectance spectrum artifact, node, argument of periapsis and a named reference plane, because decision 0032 derives their light from the start, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the ocean solute inventory carries an ionic composition with seawater thermodynamics Irreducible inside the Reference-Composition anomaly tolerance, from notes/findings/2026-09-08-implicit-earth-audit.md.
