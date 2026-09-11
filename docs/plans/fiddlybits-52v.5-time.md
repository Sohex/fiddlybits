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
every declared source, eclipse geometry, and the epoch rule that fixes where `t = 0`
is. It also puts the calendar where it belongs, which is in `Render` and nowhere
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
| `src/Orbit/` | the Kepler solve, anomalies, distance, declination, hour angle, the day functions, the epoch rule | 52v.5.3 |
| `src/Instellation/` | per-cell flux from every source, eclipse geometry, the reflected-light interface | 52v.5.4 |
| `src/Render/calendar.jl` | calendar rendering, and nothing else that touches a date | 52v.5.5 |
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
takes that decision and amends decision 0012; this plan reads its outcome rather than
pre-empting it, and 52v.5.3 depends on it.

The same finding measured the two backends at one ulp apart on the well-conditioned
solve and thirty-five on the ill-conditioned one, from the transcendental libraries
alone. That is the cost of not having the project's own polynomial transcendentals
that decision 0029's bitwise mode calls for, and it is recorded on the kernels plan
rather than here.

```
eccentric_anomaly(e, M)        Markley start, two Newton steps on the stable residual
true_anomaly(e, E)
distance(orbit, t)             stellar distance from the declared elements
declination(system, source, t)
hour_angle(system, source, cell, t)
sidereal_day(system)           the declared rotation period
solar_day(system, source, t)   varies around an eccentric orbit
mean_solar_day(system, source) a second function, not an average of the first by name
```

For a synchronous rotator the solar day of that source is undefined and the function
returns `NotEvaluable` by name rather than a large number. For a retrograde rotator
the solar day is shorter than the sidereal day, which is an identity rather than a
special case.

### The epoch

The epoch is a declared pair, an event kind and a source index, plus an offset in
seconds; `t = 0` is that event plus the offset in orbit zero. The kinds:

| kind | defined as | refuses when |
| --- | --- | --- |
| vernal equinox | the instant the subsolar point of the named source crosses the equator in the direction putting the positive rotation-axis hemisphere toward the source | the obliquity is below a threshold derived from rounding, since the subsolar point then never leaves the equator and the instant does not exist; or when no single source is declared primary |
| periapsis | the periapsis of the named orbit | never |
| superior conjunction | for a synchronous rotator, of the named source | no source is named |

"Vernal" labels a geometric event and not a season; which hemisphere calls it spring
is a rendering choice. The reference direction for the argument of periapsis is the
equinox of the primary where it exists and the ascending node on the orbit's
reference plane otherwise. The pair, the offset and that direction go into every
run's identity.

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
| `system.epoch_event` | the two refusals are the control: a zero-obliquity instance and a two-primary instance |
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
| 52v.5.3 | frontier | `src/Orbit/`, `test/orbit/` | `system.kepler_period`, `system.epoch_event` and `system.solar_sidereal_relation` pass, each control firing; the synchronous instance returns `NotEvaluable` by name |
| 52v.5.4 | sonnet | `src/Instellation/`, `test/instellation/` | `system.orbit_mean_insolation` and `system.multi_source_instellation` pass with every composition arm |
| 52v.5.5 | local | `src/Render/calendar.jl`, `test/render/` | `lint_calendar` still passes and still flags its fixture; `test/render/no_calendar.jl` exists and passes, resolving that check for the import harness |
| 52v.5.6 | sonnet | none; reports only | all seven oracles ran; verdicts by name |

52v.5.3 depends on 52v.5.2 and on `fiddlybits-52v.10`; 52v.5.4 depends on 52v.5.3 and
on the fields plan; 52v.5.5 depends on 52v.5.2. `system.damping_in_rotations` is run
by 52v.5.2, since a timescale in rotations is a clock declaration.
