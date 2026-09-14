+++
id = "0008"
title = "One clock in SI seconds; every temporal quantity derived from the system; the epoch declared"
status = "accepted"
date = 2026-09-08
+++

## Decision

The model has one clock: `SimTime`, seconds since the run epoch, as a float. Every
interval a component acts over is an explicit `Interval{t0, t1}` with both bounds.
The sidereal day is the declared sidereal rotation period of decision 0004. The solar
day of each source (which varies around an eccentric orbit), the mean solar day of
each source (a second function), the orbital period, the mean and true anomaly, the
stellar distance, the declination, the hour angle at a cell, the instellation at a
cell from every source, the phase of each moon, eclipse geometry, and the stellar
cycle factor are all pure functions of the system struct and a `SimTime`. The true
anomaly is obtained by solving Kepler's equation to rounding for any eccentricity
below one, never by a series truncated in eccentricity. For a synchronous rotator the
solar day of that source is undefined and the function returns `NotEvaluable` by
name; for a retrograde rotator the solar day is shorter than the sidereal day; the
sense is the one decision 0004 derives from the obliquity, and where the positive pole
lies in the orbit plane within rounding there is no sense, and the solar and mean solar
day of every source return `NotEvaluable` by name; a
consumer that needs a day reads the mean solar day of the source of largest
instellation and declares its fallback where that is undefined (decision 0023).
Secular variation of the orbital elements and of the spin axis is a declared absence:
the elements are constants of the run until the rotation-state and obliquity
components of decision 0032 exist, and the long-term expansions of Berger (1978) are
not carried; only the instantaneous geometry is. Nothing rounds a year to whole
days; no array is sized by "days per year"; no constant is both a day and a unit of
time.

Forcing is a list of intervals of any length with a field per interval, contiguous
and non-overlapping. A daily-cadence forcing and a thirty-hour-cadence forcing and a
per-timestep forcing are the same code path; there is no cadence enumeration.

The model timestep of each component is a `Bracketed` numeric in the profile with a
`Derived` ceiling (a Courant condition from the radius, the level and the wave speed
that binds, the wave speed evaluated over the profile's state brackets per
REQ-NUM-005), and the constructor refuses a step above its ceiling.

### The epoch

`t = 0` is the instant at which the declared orbital elements and the declared rotation
phase hold. Each orbit's phase there is its mean longitude at the epoch, and the planet's
own is zero, because the planet's mean position at `t = 0` is the origin every longitude
is measured from (decision 0004, section The reference directions of the orbit
hierarchy). The rotation phase is the planet's sub-primary longitude at the epoch, read
at the same instant (decision 0004, section The spin axis and the rotation phase in the
orbit frame). Every position, hour angle and sub-source longitude at a later `t` is
`Derived` from these, with the orbital periods and the sidereal rotation period. Nothing
else declares where `t = 0` is. The elements and the rotation phase enter every run's
identity with the system, and placing `t = 0` on a calendar is a rendering choice.

The named events are `Derived` from the elements and are never declared. An event
function returns the latest instant, at or before a given `t`, at which the event's
definition holds:

- **The vernal equinox.** The instant the direction from the planet toward the primary
  of its orbit crosses the equatorial plane toward the positive pole. The planet's true
  longitude is then the longitude of its equator's ascending node, so the event exists
  wherever the equinox direction `gamma` of decision 0004 exists, whatever the number of
  stars. Where the sine of the obliquity does not exceed the rounding of the subsolar
  latitude, that direction never leaves the equator within rounding, and the event
  returns `NotEvaluable` by name.
- **The periapsis of a named orbit.** The instant that orbit's mean anomaly is zero.
  Where the eccentricity does not exceed the rounding of the distance, the distance has
  no minimum within rounding, and the event returns `NotEvaluable` by name.

"Vernal" is a label for a geometric event, not a season; which hemisphere calls it
spring is a rendering choice.

**One phase is not declared twice.** An epoch reference, being an event kind, a source
and an offset in seconds from the event to `t = 0`, would declare again the phase the
elements already declare at `t = 0`. For the periapsis of an orbit of period `P`, the
offset is `P M(0) / (2 pi)` plus whole periods, and the whole periods carry nothing while
the elements are constants of the run. For the vernal equinox, the offset is the time
from the planet's true longitude at the equinox to its position at `t = 0`. Wherever the
two declarations disagree, the orbit is at two places at `t = 0`. The elements are
declared and the events are `Derived`, for the reasons the alternatives give.

### Calendar

A calendar (months, named epochs, era counts) is a rendering concern. The render
module formats a `SimTime` against a declared calendar; no physics module may import
the language's date library, and a lint enforces that.

### The terrain's clocks

The terrain snapshot's ages and rates (surface age, exposure age, uplift and
denudation rates, cover deposition ages) are on this same clock, in seconds, with a
deep-clock origin declared by the tectonic seed. A duration is therefore defined
everywhere in the system, which the predecessor's terrain generator could not offer.

## Alternatives considered

- **A calendar clock with a fixed year length in days** (what every model in the
  predecessor's survey carried, and what the predecessor's climate model had to be
  patched away from). Lost: it welds the day and the year, both of which are
  derived quantities here, into the time axis.
- **An epoch reference declared as an event kind, a source and an offset, with the
  phase of the orbit it is read of `Derived` from it.** For: `t = 0` is placed against
  a named event, in seconds. Against, three things. One event fixes the phase of one
  orbit, so every other orbit still declares its own, and whether the planet orbit's
  phase is declared or `Derived` would depend on which kind a configuration names. The
  vernal equinox does not exist at zero obliquity, nor the periapsis on a circular
  orbit, so a configuration has to pick a kind before it can be constructed, and the
  constructor refuses case by case. And a superior conjunction of a named source names
  no observer for the conjunction. Lost.
- **The epoch reference and the elements both declared, the one checked against the
  other.** For: `t = 0` is stated both ways. Against: a quantity that is both declarable
  and derivable is a place two values can disagree (decision 0004, the alternative of a
  larger foundational set). Lost.
- **The periapsis of the planet's orbit as `t = 0` on every configuration.** For: purely
  orbital and independent of the obliquity. Against: a circular orbit has no periapsis,
  and the planet's anomalistic phase at `t = 0` could no longer be declared. Lost.
- **The vernal equinox as `t = 0` by default.** Against: the instant does not exist at
  zero obliquity, so a rule that fills the epoch silently would fill it with nothing on
  exactly those configurations. Lost.
- **The true longitude at `t = 0` as each orbit's declared phase, in place of the mean
  longitude.** For: `t = 0` at the vernal equinox is then declared exactly. Against: a
  catalogued body's tabulated mean longitude (Standish and Williams, Table 1) converts
  to it only through a Kepler solve, which `Systems` sits below; and the mean anomaly the
  solve reads is `Derived` from the mean longitude by a subtraction. Lost.
- **The rotation phase read at an event rather than at `t = 0`.** Lost. It would make
  the orientation at `t = 0` move with the orbital phase declared there, so the two
  could not be declared independently.
- **Integer timesteps as the time axis** (the predecessor's climatology files
  carried `units = timesteps` with no calendar). It made every downstream tool that
  assumed a calendar either refuse or silently impose one. Lost; SI seconds are a
  unit every tool can carry.

## Consequences

- The instellation function takes every star and every reflecting moon in the
  system; a single-star system is the one-element case, not a special case.
- The stellar cycle is a forcing modulation inside the run, never an offline
  correction.
- Oracles implied, registered as the `system.*` section of `docs/oracles/registry.toml`
  and each run on `Earth()` and on a synthetic non-Earth instance with closed forms
  (retrograde spin, high eccentricity, two sources, zero obliquity): the orbital
  period derived for a test instance from its own mass and semi-major axis matches
  the analytic Kepler value to rounding; orbit-mean insolation as a function of
  latitude, obliquity and eccentricity matches the analytic result to rounding; at the
  instant each event function returns, that event's definition holds, and the vernal
  equinox returns `NotEvaluable` at zero obliquity and the periapsis on a circular
  orbit; the solar-day function integrates to the
  sidereal-day relation over an orbit for prograde, retrograde and synchronous
  instances; multi-source instellation with one source's luminosity set to zero
  equals the single-source function; time encode and decode are inverses.

## References

- The predecessor's audit of its day constant doing two jobs and of its fixed-length
  calendar: `/home/cfutro/docs/world/notes/audits/model-earth-centrism.md`,
  mechanism II and section 18.
- The predecessor's argument that its terrain had no time axis and that a duration
  was undefined rather than unmeasured:
  `/home/cfutro/docs/world/docs/src/reference/no-time-axis.md`.
- The predecessor's calendar port for its vegetation model and what it did not reach:
  `/home/cfutro/docs/world/biosphere/notes/time-base-unit-contract.md`.
- Berger, A. (1978), "Long-Term Variations of Daily Insolation and Quaternary
  Climatic Changes", J. Atmos. Sci. 35 (locator in REQ-SYS-102): the instantaneous
  insolation geometry this record uses, and the secular expansions it declares
  absent.
- Murray and Dermott (1999), Solar System Dynamics (locator in decision 0032):
  Kepler's equation and the orbital-element conventions.
- Archinal, B. A., et al. "Report of the IAU Working Group on Cartographic Coordinates and Rotational Elements: 2015." Celestial Mechanics and Dynamical Astronomy 130 (2018), article 22. DOI: 10.1007/s10569-017-9805-5. Page 6 (W0 as the value of the prime meridian angle W at a named epoch, and W varying with time from it): the form the rotation phase read at `t = 0` takes.
- Standish, E. M., and J. G. Williams (1992), as reformatted on the JPL Solar System Dynamics page "Approximate Positions of the Planets", https://ssd.jpl.nasa.gov/planets/approx_pos.html (fetched 2026-09-13). Section Formulae for using the Keplerian elements (the mean longitude among the six elements, and `M = L - varpi`) and the heading of Table 1 (elements with respect to the mean ecliptic and equinox of J2000, with their rates per century from J2000.0): the form each orbit's phase at `t = 0` takes.

## Amendments

- 2026-09-08: the sidereal day is the declared sidereal rotation period; the solar and mean solar day are per source, undefined by name for a synchronous rotator; the true anomaly is a Kepler solve to rounding and Berger's secular variations are a declared absence, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the epoch is a declared (event kind, source index) pair with the equinox kind admissible only above a rounding-derived obliquity threshold and with one declared primary; the reference direction for the argument of periapsis is named, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the implied oracles are the registry's system.* section, each run on Earth() and a synthetic non-Earth instance, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-10: the Kepler solve is this project's own and takes a named form. Markley's
  closed form supplies the starting value, and two Newton steps refine it on the residual
  `(1 - e)E + e(E - sin E) - M` with the derivative `1 - e + 2 e sin^2(E/2)`, which are
  Markley equations 30 to 35; `E - sin E` below half a radian is the series through
  `E^15`. The iteration count is fixed, so every lane does the same work. An eccentricity
  outside the elliptic range is refused once by the `System` constructor and never inside
  a per-cell kernel. From `notes/findings/2026-09-10-kepler-in-a-portable-kernel.md` and
  `notes/findings/2026-09-10-sampling-the-kepler-hard-region.md`, carried by
  `fiddlybits-52v.10`.
- 2026-09-13: the planet's argument of periapsis is measured from the equinox direction of decision 0004 wherever the sine of the obliquity exceeds its rounding, whatever the number of stars; the rotation phase is the planet's sub-primary longitude read at t = 0, not at the event; the solar and mean solar day return NotEvaluable where the positive pole lies in the orbit plane; carried by fiddlybits-52v.5.7.
- 2026-09-13: an epoch reference and the orbital phase at t = 0 declare one phase twice, so t = 0 is the instant the declared elements and rotation phase hold, each orbit's phase is its mean longitude at the epoch (the planet's zero by the root origin of decision 0004), the epoch reference and its equinox refusals go from the system, and the vernal equinox and the periapsis are Derived event instants returning NotEvaluable by name where they do not exist; the superior conjunction kind goes, and the planet's periapsis is a longitude like every orbit's (superseding the equinox as its reference in the amendment above); section The epoch and its alternatives, carried by fiddlybits-52v.5.8, with the System fields in fiddlybits-52v.4.17.
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
