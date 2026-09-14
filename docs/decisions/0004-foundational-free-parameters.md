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
  default composition; the sidereal rotation period (the constructor refuses any field
  named "day"; the solar and mean solar day are derived by decision 0008); the
  obliquity, the angle from the planet's orbit normal to the positive pole of rotation,
  from which the sense of rotation relative to the orbit normal is `Derived` and never
  declared; the longitude of the ascending node of the planet's equator on its orbit
  plane, which fixes the pole's azimuth; the sub-primary longitude at the epoch, which
  fixes the rotation phase; and the planet's orbit, declared as below. How the three
  angles place the body frame in the orbit frame is the section The spin axis and the
  rotation phase in the orbit frame.
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
  longitude of periapsis, and the mean longitude at the epoch, each longitude measured
  as the section The reference directions of the orbit hierarchy names. The planet's
  orbit declares no mean longitude at the epoch, because its mean position at `t = 0`
  is the origin every longitude is measured from. A planet orbit
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
  inclination, longitude of the ascending node, longitude of periapsis, mean longitude
  at the epoch), with the reference plane named as the planet's equator or the
  planet's orbit. Their
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

### The spin axis and the rotation phase in the orbit frame

Decision 0005 declares the body frame `Mesh.BODY_FRAME`. Its spin axis is the positive
pole of rotation, the pole following the right-hand rule (Archinal et al. 2018, p. 22),
and its prime meridian is longitude zero. Placing that frame in the orbit frame at a
time `t` needs three angles: two for the pole and one for the prime meridian about the
pole. The planet declares all three. The obliquity and the longitude of its equator's
ascending node place the pole, and the rotation phase places the prime meridian about
it.

**The positive pole.** Let `n` be the planet's orbit normal, the direction about which
the planet moves counterclockwise seen from outside. The obliquity `epsilon` is the
angle from `n` to the positive pole `p`, admitted in `[0, pi]`. Let `N` be the unit
vector on the planet's orbit plane at the longitude `Omega_E`, the declared
`equator_ascending_node_longitude`, measured as the section The reference directions of
the orbit hierarchy measures every longitude. The pole in the orbit frame is

    p = cos(epsilon) n + sin(epsilon) (N x n)

This is `n` turned through `epsilon` about `N`, the rule by which every plane of the
hierarchy is hung on its parent, so `N` is the ascending node of the equator on the orbit
plane: `n x p = sin(epsilon) N`. The equinox direction `gamma`, the unit vector from the
planet toward the primary of its orbit at the vernal equinox of decision 0008, is `-N`.
It is the ascending node of the primary's apparent path on the planet's equator,
`gamma = (p x n) / sin(epsilon)`, so the planet's true longitude at the vernal equinox is
`Omega_E`. `gamma` exists wherever `sin(epsilon)` exceeds its rounding, the threshold
below which decision 0008's vernal equinox returns `NotEvaluable`, and it does not
depend on how many stars are declared.

- **Azimuth.** The pole's azimuth about `n` is `Omega_E`. Where `sin(epsilon)` is zero,
  `p` is `n` or `-n` whatever `Omega_E` is, and nothing reads it.
- **Sense.** The sense of rotation relative to the orbit normal is `Derived` from the
  obliquity and never declared: prograde where `cos(epsilon)` exceeds its rounding,
  retrograde where `-cos(epsilon)` does. Between the two there is no sense, because the
  positive pole lies in the orbit plane, and every reader of the sense returns
  `NotEvaluable` by name (decision 0008).
- **Synchronous rotation.** A synchronous rotation is admissible only where the sense is
  prograde.
- **Disposition.** The obliquity and `Omega_E` carry the dispositions of any declared
  angle.

**The rotation phase.** The planet declares `lambda0`, the sub-primary longitude at the
epoch, admitted in `(-pi, pi]`. It is the longitude by `Mesh.longitude(BODY_FRAME, ...)`
of the direction from the planet toward the primary of its orbit at `t = 0`, expressed
in body coordinates. The primary is the star or barycentre `orbits.planet.primary`
names. From `lambda0`, the frame is placed at every time:

- **At `t = 0`.** Let `u` be the unit projection of that direction onto the equatorial
  plane. The prime meridian is then `m0 = cos(lambda0) u - sin(lambda0) (p x u)`, which
  gives the direction toward the primary exactly the longitude `lambda0`.
- **At later `t`.** The body turns about `p` through `2 pi t / P`, `P` being the
  sidereal rotation period. The turn is positive about the positive pole on every
  configuration.
- **The placement rule.** The orientation whose columns are the prime meridian,
  `p x` the prime meridian, and `p` passes `Mesh.require_body_orientation` with the
  angular velocity `(2 pi / P) p`.
- **The one gap.** `u` does not exist only where the primary lies on the spin axis at
  `t = 0`, which needs `p` in the orbit plane. There the placement refuses by name, and
  the configuration declares another `Omega_E`.

The value is read at `t = 0`, the instant at which the declared mean longitudes also hold
(decision 0008). The orbital phases set where in each orbit `t = 0` falls, and `lambda0`
sets which longitude faces the primary there, independently of them.

**What reads the phase.** Every source's sub-source longitude at `t` is
`Mesh.longitude` of that source's direction in body coordinates. The hour angle of a
source at a cell is the cell's longitude minus the sub-source longitude, wrapped into
`(-pi, pi]`, so both are `Derived` and neither is declared. On a synchronous rotator
with a circular orbit at zero obliquity, the direction to the primary turns about
`p = n` at the body's own rate, so the sub-primary longitude is `lambda0` at every `t`.
The declared value is that rotator's permanent sub-stellar longitude by name, and a
configuration with no solar day declares it the same way as any other.

**The phase's disposition.** For a body with no accurately observable fixed surface
features, the expression for the prime meridian angle `W` defines the prime meridian
(Archinal et al. 2018, p. 6). A generated body is in that case: its geography is
generated in the body frame, and no feature defines its longitudes. `lambda0` is
`Irreducible` on such a body, for three reasons:

- No component of this system derives an orientation about the spin axis; the
  rotation-state component of decision 0032 is a declared absence.
- It is not `Bracketed`, because nothing pushes a periodic angle up or down.
- It is not `Derived`, because no rule computes it.

The sensitivity its record names is what the value moves. On a synchronous rotator,
that is which body-fixed longitudes face the primary for the whole run. On any other,
it is the local time at each longitude at a given `t`. That finding belongs to the
sweeps plan, `fiddlybits-755.1`. A configuration standing for a catalogued body carries
`lambda0` `Sourced` instead, from the published orientation model: the rotational
elements the report tabulates as `W` at a standard epoch plus a rate in days from it
(Archinal et al. 2018, Table 1, p. 8).

### The reference directions of the orbit hierarchy

Every angle an orbit declares, beside its inclination, is a longitude. It is measured on
the orbit's reference plane from that plane's origin to the ascending node, and from the
node along the orbit. The planes form a tree, each hung on a parent, and each plane's
origin is carried to it from its parent's. The tree is rooted in a declared body's
position, so no origin is a coordinate.

**The planes.** Each plane has a normal and a parent:

- The root is the reference plane the planet's orbit names, `invariable_plane` or
  `primary_equator`. It has no parent.
- `planet_orbit` has the normal `n`. Its parent is the root, with the planet orbit's
  inclination and node.
- `planet_equator` has the normal `p`, the positive pole. Its parent is `planet_orbit`,
  with the obliquity as its inclination and `Omega_E` as its node (section The spin axis
  and the rotation phase in the orbit frame).
- An orbit's own plane has the orbital normal, the direction about which the secondary
  moves counterclockwise seen from outside. Its parent is the reference plane the orbit
  names.

A companion on `invariable_plane` needs that plane to be the root, so it is refused
beside a planet orbit on `primary_equator`. `primary_equator` needs a star as the
planet's primary, so it is refused about a barycentre. Both refusals are
`fiddlybits-52v.4.17`. What fixes each root plane's normal is `fiddlybits-52v.4.18`.

**The node.** A plane with normal `h`, on a parent with normal `k`, lies at the
inclination `i` from `k` to `h`, in `[0, pi]`. Its ascending node is along `k x h`: for
an orbit, the point where the secondary crosses the parent plane toward the side `k`
points to. It is the node the JPL elements measure the longitude of the ascending node
to, and it is the node their rotation `R_z(-Omega) R_x(-I) R_z(-omega)` tilts the orbit
about (Standish and Williams, section Formulae for using the Keplerian elements). It is
also the node an IAU prime meridian is measured from: W is measured easterly along the
body's equator from the node Q of that equator on the ICRF equator, Q being the node at
`alpha0 + 90` degrees (Archinal et al. 2018, p. 6).

**The origin.** A plane's origin is its parent's origin carried onto it by the rotation
through `i` about the line of the node. With the parent's origin as the first axis, `k`
as the third, and the node at the longitude `Omega`, that rotation is
`R_z(Omega) R_x(i) R_z(-Omega)`. A longitude along the plane is the angle from its
origin, counterclockwise about `h`. It is the broken angle of the JPL elements: a point
at the angle `u` past the node has the longitude `Omega + u`. The longitude of periapsis
is `varpi = Omega + omega`, where `omega` is the argument of periapsis measured from the
node. The page gives `omega = varpi - Omega` and `M = L - varpi`. Its component form of
`R_z(-Omega) R_x(-I) R_z(-omega)` is the matrix `R_z(Omega) R_x(i) R_z(-Omega) R_z(varpi)`:
the rotation above, applied after a turn through `varpi` about the orbit's normal.

**The root origin.** The root's origin is the planet's mean position at `t = 0`, carried
back onto the root by the inverse of the planet orbit's rotation. Equivalently, the
planet's mean longitude at the epoch is zero by definition, and the planet's orbit
declares none. The mean position is the direction the secondary would have at its mean
anomaly on a circular orbit of the same period (Berger 1978, Appendix: the mean anomaly
of a mean earth rotating at constant angular speed, counted from perihelion, and its
mean longitude `lambda_m = M + varpi-tilde`).

**What each orbit declares.**

- The semi-major axis and the eccentricity.
- The inclination `i`.
- The longitude of the ascending node `Omega`.
- The longitude of periapsis `varpi`.
- The mean longitude at the epoch `L0`, the longitude of the mean position at `t = 0`;
  every orbit but the planet's declares it.

These are the six elements the JPL page tabulates, less the rates the run declares absent
(decision 0008). The argument of periapsis `omega = varpi - Omega` is a `Derived` door,
never declared, and so is the mean anomaly at `t`, `M = L0 + 2 pi t / P - varpi`, where
`P` is the orbital period. The planet's mean anomaly at `t = 0` is therefore `-varpi`.
Every angle carries the dispositions of any declared angle.

**The seasonal angles are `Derived`.** At the vernal equinox the planet's true longitude
is `Omega_E`. The true longitude of the primary seen from the planet, counted from the
vernal equinox, is `lambda = theta - Omega_E`, where `theta` is the planet's true
longitude. That is the longitude Berger's declination `sin(delta) = sin(epsilon)
sin(lambda)` reads (Berger 1978, Appendix). Berger's longitude of perihelion from the
vernal equinox, in his numerical form with 180 degrees subtracted because the sun is
treated as revolving around the earth (Fig. 1 caption), is `varpi - Omega_E`. It
satisfies his `lambda = nu + varpi-tilde`, `nu` being the true anomaly.

**The degenerate cases.** Each is the one rule at a particular value, not a second rule:

- **Zero inclination.** The node does not exist. The rotation through zero is the
  identity whatever `Omega` is, so the plane's origin is its parent's and nothing reads
  `Omega`. At zero obliquity the same holds for `Omega_E`: `p = n`, and neither the pole
  nor any plane hung on the equator reads it.
- **An inclination of `pi`.** The node does not exist either. The rotation is a half
  turn about the line at `Omega`, so the declared `Omega` still places the plane's origin,
  as its parent's origin reflected in that line. The declaration is redundant there:
  `Omega + d`, `varpi + 2d` and `L0 + 2d` place the same orbit, and no reader takes the
  line for a node. At an obliquity of `pi`, `p = -n` and the pole reads no `Omega_E`, and
  a moon on `planet_equator` reads it only as that line.
- **Zero eccentricity.** Periapsis does not exist. The true and mean anomalies are equal,
  so the angle past the node is `omega + nu = L - Omega`, and the position reads `Omega`,
  `i` and the mean longitude alone. `varpi` enters only the `Derived` doors `omega` and
  `M`, and cancels in that sum.
- **The root origin.** It exists on every configuration, because it is a rotation
  applied to the planet's mean position, which every orbit has.
- **An event.** Where a reader needs the vernal equinox or a periapsis as an instant,
  rather than as a direction, it returns `NotEvaluable` by name where the event does not
  exist (decision 0008, section The epoch).

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
- **Obliquity to the pole on the orbit normal's side, in `[0, pi/2]`, with the sense
  declared.** This is the IAU convention for planets and satellites. The north pole is
  the pole of rotation on the north side of the invariable plane, and the rotation is
  prograde or retrograde as `W` increases or decreases (Archinal et al. 2018, p. 6);
  Table 1 accordingly gives some planets a north pole with a decreasing `W` (p. 8).
  For: it matches catalogue coordinates, and the sense is written where a reader looks
  for it. Against, three things. The two declarations reach one pole only through a
  branch on the sense. At `pi/2` the pole on the normal's side does not exist, so the
  declared sense has nothing to be relative to, yet the pair is admissible. And a spin
  axis crossing the orbit plane, which the obliquity component of decision 0032 exists
  to follow, moves continuously while both declared quantities jump. Lost.
- **The obliquity to the positive pole and the sense both declared, the one checked
  against the other.** For: the sense is explicit. Against: a quantity that is both
  declarable and derivable is a place two values can disagree (the alternative of a
  larger foundational set, above).
  Lost.
- **The pole as a declared unit vector in the orbit frame.** Three numbers and a
  unit-length constraint for two degrees of freedom. Its azimuth would also declare a
  second time what `Omega_E` already carries. Lost.
- **The rotation phase as an angle from the equinox direction.** This is the analogue
  of the IAU's `W`, measured from the node of the body's equator (Archinal et al. 2018,
  p. 6). For: it is the catalogue form. Against: `gamma` does not exist where the sine
  of the obliquity is within rounding, which includes the zero-obliquity synchronous
  instance of decision 0034, so it needs a second reference direction by case. Lost.
- **A rule instead of a declaration: the prime meridian faces the primary at the epoch
  event, or at `t = 0`.** For: no field. Against: a rule at the event makes the time of
  day at `t = 0` move with the orbital phase declared there, so the season and the
  orientation stop being independent declarations. A rule at `t = 0` fixes a synchronous rotator's sub-stellar
  point to wherever the terrain seed put longitude zero, and moving the one against the
  other would then mean moving geography over the fixed mesh of decision 0005, a remap
  that decision has no place for. Either way, a configuration standing for a catalogued
  body cannot state its own orientation. Lost.
- **The hour angle of the primary at the prime meridian at `t = 0`**, which is
  `-lambda0`. Equivalent in content. Lost on the door: `Mesh.longitude` already reads
  the longitude, the hour angle is `Derived` from it, and declaring the second form as
  well would be a second definition.
- **The phase measured toward a named star rather than toward the orbit's primary.** For
  a planet about a barycentre, the direction to a named star does not turn with the
  orbit, so a synchronous rotator's permanent sub-stellar longitude would no longer be
  the declared value. Lost.
- **The local time at the prime meridian at `t = 0`.** It needs a solar day, and a
  synchronous rotator has none (decision 0008). Lost.

The alternatives to the reference directions of the orbit hierarchy:

- **The argument of periapsis and the mean anomaly at the epoch, with the node, as the
  declared set.** This is the classical set, measured from the node along the orbit. For:
  the textbook form, and the Kepler solve reads the mean anomaly with no subtraction.
  Against: at zero inclination the node both angles hang on does not exist, and the
  position reads only `Omega + omega`. Two declared angles are then without a referent
  and neither is unread. At zero eccentricity the same holds for `omega + M`. The
  longitudes leave exactly one angle unread at each. Lost.
- **The vernal equinox as the root origin.** This is the origin of the JPL elements
  (Standish and Williams, Table 1 heading, the mean ecliptic and equinox of J2000) and of
  Berger's longitudes. For: a catalogued body declares its elements as tabulated, and the
  seasonal angles are read with no subtraction. Against: `gamma` does not exist where the
  sine of the obliquity is within its rounding, which includes the zero-obliquity
  synchronous instance of decision 0034. It would therefore need a second origin by case,
  and a declared longitude would change meaning where a `Bracketed` obliquity crosses the
  threshold. Lost.
- **The planet's periapsis, or its node on the root, as the root origin.** For: each is
  a direction of the planet's own orbit. Against: the first does not exist on a circular
  orbit, nor the second on an orbit in the root plane. Lost.
- **A reference direction of the root plane declared by name alone.** For: every orbit's
  node is then a longitude from one fixed direction. Against: nothing fixes that
  direction, so it is a coordinate. The planet's node would also be a declared angle on
  which nothing the run computes depends, a rotation of the whole system about the root's
  normal. Lost.
- **The planet's true position at `t = 0` as the root origin.** For: the origin is where
  the planet is, and `t = 0` at the vernal equinox is then the exact declaration
  `Omega_E = 0`. Against, two things. A catalogued body's tabulated mean longitude
  converts to it only through a Kepler solve, which `Systems` sits below. And sweeping the
  planet's eccentricity or periapsis would move the origin, and with it every other body's
  declared position at `t = 0`. The mean position moves with neither. Lost.
- **A plane inclined beyond `pi/2` measured in its parent's sense**, a retrograde form of
  the broken angle. For: no half turn at an inclination of `pi`. Against: that form's own
  undefined case sits at zero inclination, so it has to switch forms at `pi/2`. A
  declared longitude then changes meaning where a `Bracketed` inclination or obliquity
  crosses `pi/2`, which is the crossing the obliquity's range `[0, pi]` exists to keep
  continuous. Lost.
- **The planet's argument of periapsis measured from `gamma` where `gamma` exists, and
  from its node otherwise.** For: one declaration carries both the pole's azimuth and the
  periapsis. Against, two things. The planet's periapsis against its own node on the root
  plane is then declared nowhere, so its orbit and a companion's on that plane have no
  relative geometry. And the reference changes at the rounding threshold. Lost.
- **The pole's azimuth as the longitude of perihelion from the vernal equinox**, Berger's
  precession angle, whose sine times the eccentricity is his precessional parameter
  (Berger 1978, eq. 2). For: insolation reads it directly. Against: it does not exist at
  zero eccentricity, so a tilted planet on a circular orbit would have no declared pole
  azimuth. Lost; it is `Derived` as `varpi - Omega_E`.

## Consequences

- The `System` struct of decision 0007 has exactly this shape: stars, planet (with
  its lithosphere block), orbits, moons, inventories, numerics.
- `Planet` carries `obliquity` in `[0, pi]` and `sub_primary_longitude_at_epoch`, and
  the sense is `Derived` (`fiddlybits-52v.4.13`); it also carries
  `equator_ascending_node_longitude`, and every `Orbit` carries
  `longitude_of_ascending_node`, `longitude_of_periapsis` and, except the planet's,
  `mean_longitude_at_epoch` (`fiddlybits-52v.4.17`). `Orbit` places `Mesh.BODY_FRAME`
  and every body from them, and every hour angle, sub-source longitude and declination
  reads that placement (`fiddlybits-52v.5.3`). Checks implied:
  - the hour angle at `t = 0` reproduces the declared longitude at every cell;
  - a synchronous rotator's sub-primary longitude is the declared value across an orbit;
  - every placement passes `Mesh.require_body_orientation`, and a retrograde rotator
    placed with its spin axis on the orbit normal's side is refused;
  - a companion star's declination on a circumbinary fixture matches its closed form
    from the declared longitudes, and fails when the angle past the node is read from
    the origin;
  - no position depends on the node at zero inclination or on the periapsis at zero
    eccentricity, and the pole does not depend on `Omega_E` at zero obliquity.
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
- Archinal, B. A., et al. "Report of the IAU Working Group on Cartographic Coordinates and Rotational Elements: 2015." Celestial Mechanics and Dynamical Astronomy 130 (2018), article 22. DOI: 10.1007/s10569-017-9805-5. Pages 6 (the north pole by the invariable plane; the node Q of the body's equator on the ICRF equator at alpha0 + 90 degrees, from which W is measured easterly along the body's equator to the prime meridian; prograde or retrograde as W increases or decreases; for a body with no accurately observable fixed surface features the expression for W defines the prime meridian), 8 (Table 1: W at the standard epoch plus a rate in days from it, with a decreasing W among the planets), 22 (the positive pole by the right-hand rule).
- Standish, E. M., and J. G. Williams (1992), as reformatted on the JPL Solar System Dynamics page "Approximate Positions of the Planets", https://ssd.jpl.nasa.gov/planets/approx_pos.html (fetched 2026-09-13). Section Formulae for using the Keplerian elements (the six elements including the mean longitude L, the longitude of perihelion varpi and the longitude of the ascending node Omega; omega = varpi - Omega and M = L - varpi; r_ecl = R_z(-Omega) R_x(-I) R_z(-omega) r' written out by components, with the x-axis toward the equinox) and the heading of Table 1 (elements with respect to the mean ecliptic and equinox of J2000): the element set and the broken angle of the section The reference directions of the orbit hierarchy.
- Berger, A. (1978). "Long-Term Variations of Daily Insolation and Quaternary Climatic Changes." Journal of the Atmospheric Sciences 35. DOI: 10.1175/1520-0469(1978)035<2362:ltvodi>2.0.co;2. Fig. 1 caption (the longitude of the perihelion measured from the moving vernal equinox, with 180 degrees subtracted because the sun is considered as revolving around the earth), eq. 2 (the precessional parameter e sin(varpi-tilde)) and the Appendix (true and mean anomaly counted from perihelion; true longitude from the vernal equinox with lambda = nu + varpi-tilde; mean longitude lambda_m = M + varpi-tilde; sin(delta) = sin(epsilon) sin(lambda)): the seasonal angles `Derived` from the declared longitudes.

## Amendments

- 2026-09-08: stars carry a Sourced stellar model with a declared (mass, age, metallicity) domain, a radius that is never absent, grid interpolation refusing outside the hull, and cycle components of zero amplitude admissible, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the declared rotation is the sidereal rotation period with sense relative to the orbit normal, and a field named "day" is refused, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: gravity is Derived as g(r, phi) with the centrifugal term, the figure of the planet is Derived or a declared absence with a Bracketed equator-pole difference, and the mesh radius is named as the volumetric mean radius, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: orbits are declared per body pair in a named hierarchy with node, argument of periapsis and reference plane, and the flux-declared form is admitted for a single star only, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the lithosphere block of System is added, each field Bracketed with both ends argued, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: moons carry radius, a reflectance spectrum artifact, node, argument of periapsis and a named reference plane, because decision 0032 derives their light from the start, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the ocean solute inventory carries an ionic composition with seawater thermodynamics Irreducible inside the Reference-Composition anomaly tolerance, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-13: the obliquity is the angle from the orbit normal to the positive pole of decision 0005, in [0, pi], and the sense of rotation is Derived from it and never declared; the planet declares its sub-primary longitude at the epoch, Irreducible on a generated body and Sourced on a catalogued one, from which the prime meridian at every t, every sub-source longitude and every hour angle are Derived; section The spin axis and the rotation phase in the orbit frame and its alternatives, carried by fiddlybits-52v.5.7, with the Planet fields in fiddlybits-52v.4.13 and the reference directions of the other orbit angles in fiddlybits-52v.5.8.
- 2026-09-13: every angle of the orbit hierarchy is a longitude, measured from its plane's origin by the broken angle of the JPL elements; each plane hangs on its parent by a rotation through its inclination about its ascending node, the planet's equator on its orbit by the obliquity and the declared longitude of the equator's ascending node, which now carries the pole's azimuth in place of the argument of periapsis from gamma; the root origin is the planet's mean position at t = 0, so the planet's orbit declares no mean longitude at the epoch; each orbit declares the longitudes of node and periapsis and the mean longitude at the epoch, with the argument of periapsis and the mean anomaly Derived; zero inclination, an inclination of pi, zero eccentricity and zero obliquity are named as cases of the one rule; section The reference directions of the orbit hierarchy and its alternatives, from Standish and Williams (JPL, Approximate Positions of the Planets) and Berger 1978, carried by fiddlybits-52v.5.8, with the System fields and the two plane refusals in fiddlybits-52v.4.17 and what fixes the root planes' normals in fiddlybits-52v.4.18.
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
- 2026-09-14: the seasonal angles. `varpi - Omega_E` is the longitude of perihelion of Berger's `lambda = nu + varpi-tilde`, which Berger's Appendix (1978, p. 2366) says is his numerically obtained value with 180 degrees added; the numerical form with 180 degrees subtracted (Fig. 1 caption) is `varpi - Omega_E - pi`, and the sentence of section The seasonal angles are Derived that equates the numerical form with `varpi - Omega_E` is superseded by this. A planet's orbit declares the heliocentric longitude of periapsis as its catalogue gives it (Standish and Williams, Table 1), and a comparison with a value Berger tabulates adds 180 degrees. Declaring a catalogue's longitudes as given places the root origin on the catalogue's equinox direction, from which the planet's true longitude at its vernal equinox is pi, so such a planet declares `Omega_E = pi`. User decision of 2026-09-14, raised by notes/findings/2026-09-14-an-audit-of-source-fitness.md; plan fiddlybits-52v.5 carries the identity, and Earth() on fiddlybits-52v.4.5 carries its declaration.
- 2026-09-14: the Reference-Composition anomaly tolerance of the ocean solute inventory is `Bracketed` on the Absolute Salinity Anomaly of the declared composition, with both ends argued in decision 0017's amendment of the same date. User decision of 2026-09-14, raised by notes/findings/2026-09-14-an-audit-of-source-fitness.md.
