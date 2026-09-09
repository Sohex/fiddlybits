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
name; for a retrograde rotator the solar day is shorter than the sidereal day; a
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

The system struct carries a declared epoch reference, a pair (event kind, source
index) drawn from a named set, and a declared offset in seconds from that event;
`t = 0` is the event plus the offset in orbit zero. The event kinds are: the vernal
equinox of the named source, defined as the instant the subsolar point of that source
crosses the planet's equator in the direction that puts the positive rotation-axis
hemisphere toward the source; the periapsis of the named orbit; and, for a
synchronous rotator, the superior conjunction of the named source. The equinox kind
is admissible only when the obliquity exceeds a threshold derived from rounding
(below it the subsolar point never leaves the equator and the instant does not
exist) and when exactly one source is declared primary; otherwise construction
refuses by name and the caller declares another kind. The reference direction for
the argument of periapsis of decision 0004 is the equinox of the primary where it
exists and the ascending node on the orbit's reference plane otherwise. The pair,
the offset and that direction are recorded in every run's identity. "Vernal" is a
label for a geometric event, not a season; which hemisphere calls it spring is a
rendering choice.

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
- **Epoch at periapsis of orbit zero, for every configuration.** Purely orbital and
  independent of obliquity, but then the seasonal phase is a derived offset
  everywhere. Lost as the sole rule; kept as one of the named event kinds, and the
  one a zero-obliquity or multi-primary configuration declares.
- **The equinox as an unconditional default.** Lost: the instant does not exist at
  zero obliquity and "the primary star" is undefined for an equal binary, so a rule
  that fills the epoch silently would fill it with nothing on exactly those
  configurations.
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
  latitude, obliquity and eccentricity matches the analytic result to rounding; the
  declared epoch event's instant is reproduced from the declared orbit, and the
  equinox kind refuses at zero obliquity; the solar-day function integrates to the
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

## Amendments

- 2026-09-08: the sidereal day is the declared sidereal rotation period; the solar and mean solar day are per source, undefined by name for a synchronous rotator; the true anomaly is a Kepler solve to rounding and Berger's secular variations are a declared absence, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the epoch is a declared (event kind, source index) pair with the equinox kind admissible only above a rounding-derived obliquity threshold and with one declared primary; the reference direction for the argument of periapsis is named, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the implied oracles are the registry's system.* section, each run on Earth() and a synthetic non-Earth instance, from notes/findings/2026-09-08-implicit-earth-audit.md.
