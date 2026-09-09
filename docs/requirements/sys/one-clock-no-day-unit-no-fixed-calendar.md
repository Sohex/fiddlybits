+++
id = "REQ-SYS-102"
title = "One clock in seconds; a day constant is never the model's time unit; a calendar is never fixed-length; a rate fitted per Earth day is never evaluated on another clock"
old_path = ["/home/cfutro/docs/world/exoplasim/notes/parameter-decisions.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's vendored spectral GCM and its driver scripts, on a
planet with a 30-hour rotation and an orbit of about half an Earth year.

- `day_24hr = 86400` was hardcoded, in no namelist, and did two jobs: the unit in
  which timescales were entered, and the model's nondimensional unit of time,
  which was `sidereal_day / 2 pi` and coincides with it only on Earth. Every
  damping timescale, the Rayleigh sponge and the restoration time were applied
  over `1/rotspd` = 1.25 times their declared value; the shape of the damping
  survived and only its level was wrong (`model-earth-centrism.md` finding 2;
  `opaque-constants.md` finding 2). The nondimensional timestep `2 pi / ntspd`
  was exact only because an integer division truncated to the right value on
  the rung table, and stops being exact below a 12.4-minute step.
- The model's calendar kept a 360-day Earth year and 30-day months that its
  initialiser never updated: the calendar year was 5760 steps against an orbit
  of 5850, a "calendar day" was half a day, encode and decode were not inverses,
  and every cold start began at orbital phase 0.799 instead of the declared
  epoch (finding 18). A day count of 365 would have switched the module to the
  Gregorian leap rule. The wrapper reset the days per year from a hard-coded
  360-Earth-day run whenever the rotation period was not 1 (this note, "Non-Earth
  rotation/calendar workaround").
- A top-of-model sponge of 20 and 100 "days" was live in every run and declared
  nowhere; declaring it in rotations rather than days changed what it meant on a
  30-hour rotator by a factor of 1.25 (finding 20).
- Convective cloud fraction was an Earth regression on precipitation in mm per
  day, evaluated with the planet's solar day: +0.029 in cloud fraction from a
  free choice of which day to use, and the fit's own day convention was not
  recorded (finding 23). A carbon module used 3.154e9, Earth's seconds per year
  times 100, two lines from a correct use of the orbit (dormant section).
- A water-budget closure labelled per orbit was computed per Earth year, twice
  its stated value (`inherited-earth-constants.md` finding 6); four spellings of
  the year lived outside the one module that owned it (`opaque-constants.md`,
  smaller findings); Koppen thresholds developed for Earth-year totals had to be
  annualised to 365.2425 days to mean anything (this note, "Climate interpretation
  conventions"); an output-writing cadence of five Earth days did not divide the
  orbit (`opaque-constants.md`, NSTPW).

## Why it carries

Every configuration of a generic builder has its own rotation, orbit and, with
moons and multiple stars, several derived periods; none of them is 86400 s or
365.25 d. The defect class is a time unit that is also a physical period, and a
calendar that is a data structure rather than a rendering. It survives any
language and any model unless the clock is one quantity in seconds and every
period is derived. The regression finding generalises to any empirical fit whose
predictor is a rate per Earth day: the fit's normalisation is part of its identity.

## What this system must do

1. One clock: `SimTime` in SI seconds and explicit `Interval{t0,t1}` everywhere
   (decision 0008). The sidereal day is the declared sidereal rotation period of
   decision 0004, and a field named "day" is refused by the constructor; the solar
   day and mean solar day per source, year, orbital phase, declination,
   instellation and eclipse geometry are pure functions of `System` and the
   clock; none is stored as a constant a kernel could read as a unit. A consumer
   that needs a day (the daily tier of decision 0023) reads the mean solar day of
   the source of largest instellation and declares its fallback for a
   configuration where that is undefined; a cadence is a `Derived` duration in
   seconds, never a count of days, orbits or cycles alone.
2. No nondimensional time unit exists in physics code. Where a scheme is written
   nondimensionally in its source, the conversion to seconds happens once, at a
   named boundary, from the system's own period.
3. A timescale is declared with the physical quantity that sets it: the damping
   of a dynamical-core test case (a case literal in its forcing struct, decision
   0026) in rotations, a relaxation in seconds, a residence time as `dz / v_t`, a
   persistence criterion in units of the orbital tier's step where a cycle must
   close (0023); the model's own sponge is `Derived` from the resolved
   gravity-wave spectrum (decisions 0013, 0016). It is converted exactly once.
4. An empirical regression whose predictor or response is a rate per Earth day
   is re-expressed in SI at ingestion with the fit's normalising day recorded in
   its source entry; where the source does not state that day, the constant is
   `Irreducible` with that reason.
5. The calendar is a render concern (decision 0008): no month, no leap rule and no
   year length in physics modules; `Dates` is lint-banned there. Output time axes
   carry seconds and orbital phase. Any annualised rate is annualised to the
   declared orbit and its name carries the period it is per.
6. Forcing is a list of intervals of any length; nothing assumes a cadence that
   divides a day or an orbit.

## Enforced by

- Decision 0008 and the `SimTime` / `Interval` types; a lint banning `Dates` from
  physics modules and banning there the same literal list the import checklist
  greps in Tier A (REQ-PROC-008): the day and year in every spelling (86400, 86164,
  3600, 1440, 24, 360, 365, 365.25, 365.2425 and the seconds per Earth year), the
  planetary constants (9.81, 9.80665, 6371 and its metre forms, 7.2921e-5, 1361,
  1367, 101325, 1013.25) and their kin, each a lint literal and not a value this
  system uses.
- An identity oracle (decision 0026, the registry's `system.*` section): a
  timescale declared in rotations yields the same per-step damping fraction at two
  rotation rates; the orbital phase at the declared epoch event is the declared
  phase; encode and decode of any time are inverses; the solar-day function
  integrates to the sidereal relation for prograde, retrograde and synchronous
  instances.
- The M0 gate: derived periods from the Earth test instance reproduce the known
  solar day, sidereal day and year, and the same functions on a synthetic non-Earth
  instance (retrograde spin, high eccentricity, two sources) reproduce their closed
  forms.
- A registry rule (decision 0030): a Sourced regression entry states the time
  normalisation of its fit.

## References

- Berger, A. (1978). *Long-Term Variations of Daily Insolation and Quaternary
  Climatic Changes.* J. Atmos. Sci. 35(12), 2362-2367.
  DOI: 10.1175/1520-0469(1978)035<2362:LTVODI>2.0.CO;2 (to confirm). The
  insolation-from-orbital-elements formulation the old model's fixed-orbit
  branch reduced to, and the form in which declination and instellation are
  pure functions of orbital phase. Only the instantaneous geometry is carried;
  the secular expansions are a declared absence (decision 0008).

## Amendments

- 2026-09-08: the sidereal day is the declared rotation period and a "day" field is refused; a cadence is a Derived duration in seconds; the lint literal list matches REQ-PROC-008 Tier A; the identity oracles are the registry's system.* rows and the M0 gate runs them on a synthetic non-Earth instance as well, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: cross-area review: the timescale declared in rotations is a test case's damping literal, the model sponge stays Derived per 0013 and 0016, and a persistence criterion is stated in the orbital tier's step, from notes/findings/2026-09-08-implicit-earth-audit.md
