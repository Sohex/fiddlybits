+++
epic = "fiddlybits-52v.5"
title = "One clock in SI seconds, the orbit and rotation functions, multi-source instellation, and the calendar kept in Render"
decisions = ["0008", "0023", "0029", "0032"]
requirements = ["REQ-SYS-102", "REQ-SYS-002", "REQ-NUM-005"]
oracles = ["system.kepler_period", "system.epoch_event", "system.solar_sidereal_relation", "system.orbit_mean_insolation", "system.multi_source_instellation", "system.damping_in_rotations", "system.time_encode_decode"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the one clock and everything that is a pure function of the system
struct and a time: the orbit and rotation geometry, the instellation at a cell from
every declared source, eclipse geometry, and the instants of the named events, which are
`Derived` from the elements declared at `t = 0`. It also puts the calendar where it belongs, which is in `Render` and nowhere
else.

Nothing here carries a day as a unit. The sidereal day is the declared rotation
period; the solar day of each source is a function that varies around an eccentric
orbit; the mean solar day is a second function. No array is sized by days per year,
nothing rounds a year to whole days, and no constant is both a day and a unit of
time. A consumer that needs a day reads the mean solar day of the source of largest
instellation and declares its fallback where that is undefined.

Secular variation of the orbital elements and of the spin axis is a declared absence
with a complete interface: the elements are constants of the run until the
rotation-state and obliquity components of decision 0032 exist, and only the
instantaneous geometry is carried. The long-term expansions of Berger are not
carried; Berger's daily-insolation form is read as an oracle arm for the
instantaneous geometry and for nothing else.

The tides, rotation-state evolution, obliquity stability and moon-induced
perturbations of decision 0032 are declared absences here too. Their interfaces are
complete and their bodies refuse with the record's identifier, so a configuration
with a large moon runs without tidal mixing and its report says so by name.

## Module boundaries

The skeleton plan split this area across three submodules to break a cycle, and the
rows follow that split rather than the area's name.

| path | holds | row |
| --- | --- | --- |
| `src/Time/` | `SimTime`, `Interval`, `duration`, `TimeSupport`, the `TimeSemantics` types, forcing lists | 52v.5.2 |
| `src/Orbit/kepler.jl`, `src/Orbit/Orbit.jl` | the Kepler solve and `true_anomaly`; merged and closed | 52v.10 |
| `src/Orbit/` otherwise | the orbit frames, distance, declination, hour angle, the day functions, the event instants | 52v.5.3 |
| `src/Instellation/` | per-cell flux from every source, eclipse geometry, the reflected-light interface | 52v.5.4 |
| `src/Render/calendar.jl` | calendar rendering, and nothing else that touches a date | 52v.5.5 |
| `src/Render/Render.jl` | the module's includes; shared with the provenance plan's `export.jl`, each row adding its own line | 52v.5.5, 52v.6.3 |
| `test/time/`, `test/orbit/`, `test/instellation/`, `test/render/` | one suite each | 52v.5.2 to 52v.5.5 |

`Time` is below `Fields` and references only `Verdicts`: it carries the clock types
and no field. `Orbit` references `Systems`, `Time` and `Verdicts`, and no field
either, because its quantities are per body rather than per cell. `Instellation` is
above `Fields` and is where everything per cell lives. `time_reduce` over the
`TimeSemantics` types is declared in `Fields`, not here.

## Types and functions

### The clock

```
SimTime            seconds since the run epoch, a float
Interval(t0, t1)   both bounds explicit, in SI seconds
duration(i)
```

Every interval a component acts over is explicit in both bounds. Forcing is a list of
intervals of any length with a field per interval, contiguous and non-overlapping,
and the constructor checks that. A daily-cadence forcing, a thirty-hour-cadence
forcing and a per-timestep forcing are the same code path: there is no cadence
enumeration, because a cadence enumeration is a place a planet's day gets in.

`TimeSemantics` is the closed set `Static`, `Instantaneous`, `IntervalMean`,
`IntervalAccumulation`, `EndpointState`, enumerated here and closed by the test the
fields plan runs.

A timescale declared in rotations and a timescale declared in seconds are different
declarations, not one with a conversion: `system.damping_in_rotations` is the
identity that a damping declared in rotations gives the same fraction per rotation at
two rotation periods, which is what stops a relaxation time from silently meaning one
planet's day.

### The orbit

The true anomaly comes from solving Kepler's equation to rounding for any
eccentricity below one, never from a series truncated in eccentricity. Insolation.jl
is refused by decision 0012 for exactly that truncation.

**The solve is project-owned, and its form is measured rather than chosen.**
`notes/findings/2026-09-10-kepler-in-a-portable-kernel.md` settles three things. The
accuracy is a property of the residual and not of the method: the naive residual
`E - e sin E - M` loses every digit as the eccentricity approaches one, putting an
eighty-step bisection 2930 ulps out and Markley's closed form 13500 ulps out at
`e = 1 - 1e-12`, while the stable residual `(1 - e)E + e(E - sin E)` holds every
solver under two ulps at every eccentricity tried. The series for `E - sin E` below
half a radian needs seven terms; five is short by a relative 7.8e-13 and cost 95 ulps
at moderate eccentricity. And the packaged bracketing solvers do not compile for the
device inside a portable kernel, because a logging call sits on each solver's refusal
branch and the device compiler compiles the branch whether or not it is taken.

The form the measurement supports is Markley's closed form as the starting value,
which is not iterative, followed by two Newton steps on the stable residual: under one
ulp of pi uniformly, branch-free apart from the small-angle crossover, and a fixed
cost per lane, which is what decision 0029 wants from a kernel. `fiddlybits-52v.10`
took that decision, amended decisions 0008 and 0012, and merged the solve; it is in
the tree and its suite passes on both backends. A second finding from that row
changed how the oracle is sampled: a sample uniform in mean anomaly cannot reach the
region the paper names, so `system.kepler_period` now samples the eccentric anomaly
and derives the mean anomaly from it
(`notes/findings/2026-09-10-sampling-the-kepler-hard-region.md`).

One thing that row merged is superseded by the plan review. `Orbit.check_eccentricity`
was placed here as the guard the `System` constructor would call, and `Systems` sits
below `Orbit` in the include order, so it cannot. The guard is the constructor's own
refusal (the system plan's table), and 52v.5.3 removes the function from `Orbit` and
moves its test to `test/system/`.

The same finding measured the two backends at one ulp apart on the well-conditioned
solve and thirty-five on the ill-conditioned one, from the transcendental libraries
alone. That is the cost of not having the project's own polynomial transcendentals
that decision 0029's bitwise mode calls for, and it is recorded on the kernels plan
rather than here.

```
eccentric_anomaly(e, M)        Markley start, two Newton steps on the stable residual
true_anomaly(e, E)
plane_rotation(system, plane)  a plane's axes in the root frame, composed along its parents
argument_of_periapsis(orbit)   longitude_of_periapsis - longitude_of_ascending_node
mean_anomaly(orbit, t)         mean longitude at t minus longitude_of_periapsis
position(system, body, t)      a body's position about its primary, in the root frame
true_longitude(system, t)      the planet's true longitude along its orbit plane
distance(orbit, t)             stellar distance from the declared elements
declination(system, source, t)
positive_pole(system)          the spin axis in the orbit frame, from the obliquity and the equator's node
event_time(system, event, t)   the latest instant at or before t of VernalEquinox() or Periapsis(body)
body_orientation(system, t)    Mesh.BODY_FRAME placed in the orbit frame at t
sub_source_longitude(system, source, t)
hour_angle(system, source, cell, t)
sidereal_day(system)           the declared rotation period
solar_day(system, source, t)   varies around an eccentric orbit
mean_solar_day(system, source) a second function, not an average of the first by name
```

For a synchronous rotator the solar day of that source is undefined and the function
returns `NotEvaluable` by name rather than a large number. For a retrograde rotator
the solar day is shorter than the sidereal day, which is an identity rather than a
special case. The sense is `Planet`'s `Derived` one, read from the obliquity, and where
the positive pole lies in the orbit plane within rounding there is none: `solar_day`
and `mean_solar_day` return `NotEvaluable` by name there too.

**The rotation reads two declarations of `Planet` by name, and nothing else.** Decision
0004, section The spin axis and the rotation phase in the orbit frame, defines both;
what this module computes from them:

- `positive_pole` is `cos(obliquity) n + sin(obliquity) (N x n)`, `n` the planet's orbit
  normal and `N` the unit vector at `equator_ascending_node_longitude` (`Omega_E`) on the
  planet's orbit plane. In that plane's frame it is
  `(sin(Omega_E) sin(obliquity), -cos(Omega_E) sin(obliquity), cos(obliquity))`. It has
  no branch on the sense and reads no `gamma`, which is `-N` and is read only by the
  vernal equinox.
- `body_orientation(system, t)` is the 3 by 3 matrix whose columns are the orbit-frame
  images of `BODY_FRAME`'s prime meridian, ninety east and spin axis. The spin axis is
  `positive_pole`. The prime meridian at `t = 0` is
  `cos(lambda0) u - sin(lambda0) (p x u)`, where `lambda0` is
  `planet.sub_primary_longitude_at_epoch`, `p` the positive pole, and `u` the unit
  projection onto the equatorial plane of the direction from the planet toward
  `orbits.planet.primary` at `t = 0`. The prime meridian at `t` is the prime meridian
  at `t = 0` turned about `p` through `2 pi t / sidereal_day(system)`. Every orientation it returns passes
  `Mesh.require_body_orientation` with the angular velocity
  `(2 pi / sidereal_day(system)) p`. Where `u` does not exist, which is only where the
  primary lies on the spin axis at `t = 0`, it refuses by name, and the configuration
  declares another `equator_ascending_node_longitude`.
- `sub_source_longitude(system, source, t)` is `Mesh.longitude(BODY_FRAME, ...)` of the
  direction toward `source` carried into body coordinates by the transpose of
  `body_orientation(system, t)`. At `t = 0`, for the planet orbit's primary, it is the
  declared `lambda0`.
- `hour_angle(system, source, cell, t)` is `Mesh.longitude` of the cell centre minus
  `sub_source_longitude(system, source, t)`, wrapped into `(-pi, pi]`: zero when the
  source is on the cell's meridian, and positive once the surface has carried the cell
  east of the sub-source point. `declination(system, source, t)` is the `Mesh.latitude`
  of the same body-coordinate direction.

For a synchronous rotator on a circular orbit at zero obliquity, the direction to the
primary turns about `p` at the body's own rate. Its sub-primary longitude is therefore
`lambda0` at every `t`, which makes the declared value that rotator's permanent
sub-stellar longitude by name. `fiddlybits-52v.4.13` added the longitude to `Planet` and
gave the obliquity its range, with the sense `Derived`.

**The orbit frames.** Decision 0004, section The reference directions of the orbit
hierarchy, defines them. What this module computes from that section:

- Every plane has a frame whose first axis is the plane's origin and whose third is its
  normal. The root is the plane `orbits.planet` names, and its origin is the planet's
  mean position at `t = 0`.
- `plane_rotation` composes, from a plane up to the root, the rotation of each plane on
  its parent: through the inclination `i` about the node at longitude `Omega`, which is
  `R_z(Omega) R_x(i) R_z(-Omega)`, `R_z` and `R_x` being right-handed turns about the
  parent frame's third and first axes. `planet_orbit` hangs on the root by the planet
  orbit's inclination and node. `planet_equator` hangs on `planet_orbit` by the obliquity
  and `equator_ascending_node_longitude`. Each orbit's own plane hangs on the plane it
  names.
- In its own plane's frame, an orbit's periapsis is at the angle `longitude_of_periapsis`
  from the first axis, and its secondary at `t` is at `longitude_of_periapsis + nu`. The
  distance and `nu` come from the Kepler solve on
  `mean_anomaly(orbit, t) = mean_longitude_at_epoch + 2 pi t / P - longitude_of_periapsis`,
  the planet's `mean_longitude_at_epoch` being zero. Carried to the parent frame, this is
  the component form of Standish and Williams, `R_z(Omega) R_x(i) R_z(omega)` applied to
  the in-plane position with its first axis at periapsis, `omega` being
  `argument_of_periapsis`.
- `true_longitude(system, t)` is the planet's `longitude_of_periapsis + nu`. The seasonal
  angles of Berger (1978) are `Derived` from it. The primary's true longitude from the
  vernal equinox, seen from the planet, is `true_longitude - equator_ascending_node_longitude`.
  The orbit declares the heliocentric longitude of periapsis as its catalogue gives it, and
  `longitude_of_periapsis - equator_ascending_node_longitude` is the longitude of perihelion
  in Berger's `lambda = nu + varpi-tilde`, which is his tabulated value with 180 degrees
  added (Berger 1978, Appendix, p. 2366); a comparison with a value Berger tabulates adds
  180 degrees to the tabulated value.
- Three invariances are identities 52v.5.3 tests. For each, the same change at a nonzero
  value is the control, and it must move the result:
  - at zero inclination the rotation is the identity whatever the node;
  - at zero eccentricity no position depends on `longitude_of_periapsis`;
  - at zero obliquity `positive_pole` does not depend on
    `equator_ascending_node_longitude`.

### The epoch

`t = 0` is the instant the declared elements and the rotation phase hold (decision 0008,
section The epoch). `System` declares no event and no offset. Each orbit's phase at
`t = 0` is its `mean_longitude_at_epoch`, and the planet's is zero by the definition of
the root origin. The rotation phase is `planet.sub_primary_longitude_at_epoch`, read at
the same instant. The two are independent declarations, so the orbital phase of `t = 0`
and the longitude facing the primary there are set apart.

The named events are `Derived` by `event_time(system, event, t)`, which returns the
latest instant at or before `t` at which the event's definition holds:

| event | defined as | NotEvaluable when |
| --- | --- | --- |
| `VernalEquinox()` | the direction from the planet toward `orbits.planet.primary` crosses the equatorial plane toward the positive pole; the planet's `true_longitude` is then `equator_ascending_node_longitude` | the sine of the obliquity does not exceed `Reductions.error_bound(FT, Systems.DECLINATION_TERMS, 1)`, the rounding of the subsolar latitude |
| `Periapsis(body)` | `mean_anomaly` of the orbit whose secondary is `body` is zero | the eccentricity does not exceed the rounding of the distance, with the term count stated beside the function |

For a planet about a barycentre, the vernal equinox is the event of the barycentre's
direction, and no count of stars makes it `NotEvaluable`. "Vernal" labels a geometric
event and not a season; which hemisphere calls it spring is a rendering choice.

A configuration whose primary lies on the spin axis at `t = 0` is refused by name by
`body_orientation` (section The orbit), not by `System`. Detecting it needs the true
position at `t = 0`, a Kepler solve that `Systems`, below `Orbit`, does not run.

### Instellation

Per-cell top-of-atmosphere flux from every declared star, summed over sources, with
each source's spectrum, luminosity and geometry. Eclipses and transits by moons or
companion stars, and the reflected-light interface for moons, are derived from the
start because they touch every radiation timestep.

The identities that decide it are compositional rather than absolute, which is what
makes them checkable without an external reference: one source with zero luminosity
gives the single-source answer; two identical sources at one geometry give twice it;
a moon of zero radius eclipses nothing; a moon of declared radius removes the
closed-form fraction.

The band-edge rule of decision 0032, that a configuration whose flux ratio between
sources varies over an orbit beyond a declared bracket is REPORT for every radiation
metric, belongs to the radiation milestone. This plan provides the per-source
orbit-mean flux that rule reads.

### The calendar

`Render` formats a `SimTime` against a declared calendar. No physics module imports
the language's date library, and `lint_calendar` decides that; the lint and its
fixtures already exist, so this row adds the rendering and checks the lint still
decides with it present.

`test/render/no_calendar.jl` is the leak test `docs/imports/ncdatasets.md` names, and
it asserts no date type reaches the store writer. It is one of the five checks the
import harness currently reports unresolved.

## Oracles

Seven registry entries, all of them already written under the `system` subsystem, all
provisional. No entry is added: this area's identities were the first ones the
registry skeleton carried.

| id | what makes it non-vacuous |
| --- | --- |
| `system.kepler_period` | the eccentricity `1 - 1e-12` is in the statistic, and the naive residual is the declared positive control that must fail |
| `system.epoch_event` | `NotEvaluable` is the control: the vernal equinox on the zero-obliquity instance and the periapsis on a circular fixture; and an equinox computed with `gamma` in place of the equator's node must fail |
| `system.solar_sidereal_relation` | it runs on a prograde, a retrograde and a synchronous instance, and the synchronous one must return `NotEvaluable` by name |
| `system.orbit_mean_insolation` | the instantaneous geometry is checked against Berger's daily-insolation form as a second arm |
| `system.multi_source_instellation` | every arm is a composition identity, so no external reference is needed |
| `system.damping_in_rotations` | it is run at two rotation periods, which is the only way the identity can fail |
| `system.time_encode_decode` | the round trip is exact in the integer part, and the lint arm is `lint_calendar` |

Four of the seven run on `SyntheticSynchronous()` and `SyntheticRetrograde()` as well
as `Earth()`, which is what stops a relation that happens to hold for one spin sense
from passing.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.5.2 | sonnet | `src/Time/`, `test/time/` | `system.time_encode_decode` passes; a forcing list with a gap and one with an overlap are both refused; the `TimeSemantics` enumeration is complete |
| 52v.5.3 | frontier | `src/Orbit/` except `kepler.jl`, `src/Orbit/Orbit.jl` for its includes, `test/orbit/` | `system.kepler_period`'s period arm, `system.epoch_event` and `system.solar_sidereal_relation` pass, each control firing; the synchronous instance returns `NotEvaluable` by name; `check_eccentricity` is gone from `Orbit` and its test lives in `test/system/` |
| 52v.5.4 | sonnet | `src/Instellation/`, `test/instellation/` | `system.orbit_mean_insolation` and `system.multi_source_instellation` pass with every composition arm |
| 52v.5.5 | local | `src/Render/calendar.jl`, `test/render/` | `lint_calendar` still passes and still flags its fixture; `test/render/no_calendar.jl` exists and passes, resolving that check for the import harness |
| 52v.5.6 | sonnet | none; reports only | all seven oracles ran; verdicts by name |

52v.5.3 depends on 52v.5.2 and on `fiddlybits-52v.10`; 52v.5.4 depends on 52v.5.3 and
on the fields plan; 52v.5.5 depends on 52v.5.2. `system.damping_in_rotations` is run
by 52v.5.2, since a timescale in rotations is a clock declaration.
