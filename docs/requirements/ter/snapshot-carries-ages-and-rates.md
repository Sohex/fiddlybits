+++
id = "REQ-TER-018"
title = "The terrain snapshot carries ages and rates on the system clock, so a duration is never undefined"
old_path = ["/home/cfutro/git/vesper/docs/src/reference/no-time-axis.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's terrain generator had no time axis: "no ages, no
stratigraphy and no unconformities, because there are no timesteps to hang
them on"; its erosion sliders were dimensionless intensities; "a duration is
UNDEFINED here, not unmeasured", and putting real units on the erosion law
would have been "real K over heuristic everything else". The workaround was an
expected-value argument over a stationary population with Earth as one
randomly chosen moment: a flood-basalt province is found erupting with
probability of order one per cent, so it is old; a control keyed on an absolute
age (a deposit class at 2.7 to 1.9 Ga) has no stationary population and was
excluded rather than approximated. The hydrography note shows what the
argument costs when a process needs a clock. A basin's rim survival depended on
an incision coefficient C, in metres per (m3/s)^0.5, calibrated on every run by
matching the DENSITY of standing through-flowing lakes on Earth at the size
class the mesh resolved (measured from HydroLAKES and HydroBASINS: 15 lakes
above 1,000 km2 within 35 degrees; Poisson bracket 128 to 218 on a value of
161). Reading the survivor EDGE instead gave an answer 300 times away, because
Earth's large standing lakes are rift basins maintained by subsidence, "not a
random sample of anything". The size class nearly inverted the conclusion (495
lakes above 10 km2 read as carve almost nothing; 15 above 1,000 km2 as carve
almost everything). Sweeping the size floor moved C by a factor of 8.17 against
a Poisson factor of 1.77, so the floor was the decisive lever and had to be
swept, and the marginal landform class ran from 422 basins to 46 across
defensible floors. The model reproduced the right number of standing basins by
a different mechanism (depth and low discharge rather than subsidence) and
could not represent a basin whose floor keeps dropping. The outlet gradient
and the basin's depth were the same relief counted twice (r = 0.735, exponent
1.04), so at n = 1 the depth cancelled and a coefficient absorbed a structural
choice. No absolute time-to-cut was ever available.

## Why it carries

The plan's terrain decision (a snapshot whose state carries its own ages and
rates) exists because of this; B1 declares two clocks and per-cell
stratigraphy; B5 makes the carve a process integrated against the climate; B8
integrates weathering over exposure age; A4 puts all of it on one clock. The
evidence says what the absence costs, what the stationary-population argument
can and cannot do, and that the calibrations it forced (density matching, a
swept size floor) belong as `REPORT` oracles, never as parameters.

## What this system must do

- Per-cell stratigraphy carries basement class and age, cover layers with
  thickness and deposition age, exposure age, cumulative denudation, and
  current uplift and erosion rates, every one a `SimTime` or a rate on the SI
  clock (A4).
- The deep clock assigns seed ages from declared distributions; the surface
  clock is integrated over `T_int`, which is `Bracketed` and swept (B1).
- A process that needs a duration reads it from the state: a sill is incised by
  the integrated overflow discharge over the surface clock (B5); a rim's
  survival is a computed outcome of K, discharge, slope, depth and `T_int`,
  never a fitted coefficient.
- No Earth density calibration is a parameter. Earth's standing-lake density at
  the size class the level resolves is a `REPORT` metric (C1) with its Poisson
  bracket, and the size class is matched to the level's physical floor before
  the density is read.
- The age-times-rate identity (cumulative denudation equals the integral of the
  erosion rate over the surface clock) is a gate test.
- Subsidence is a process or a declared absence with its interface complete,
  so "cannot be represented" is a named absence.
- A control keyed on an absolute age is evaluable only where the deep clock
  reaches it; otherwise it is `NotEvaluable` by name.
- A `Sourced` rate coefficient quoted per year (an incision coefficient, a
  diffusivity, a glacial erosion coefficient, a denudation rate, a firn
  accumulation term) records the year its source used and the power the year is
  raised to in the coefficient's dimension; the dimension type performs the
  conversion to SI seconds once, with that exponent, and a per-year value quoted
  without its exponent is refused at load.

## Enforced by

- A4 `SimTime` and `Interval` types; `Dates` lint-banned from physics.
- B1 state schema: an artifact without ages and rates is refused by the store.
- M1 gate: age times rate identity; no `FAIL` in the terrain registry.
- C1 registry: lake density as `REPORT` with size class and bracket recorded.
- A5 declared absences with complete interfaces.

## References

- Braun, J., Willett, S. D. (2013). "A very efficient O(n), implicit and
  parallel method to solve the stream power equation governing fluvial
  incision and landscape evolution". Geomorphology 180-181, 170-179.
  DOI: 10.1016/j.geomorph.2012.10.008.
- Whipple, K. X., Tucker, G. E. (1999). "Dynamics of the stream-power river
  incision model: Implications for height limits of mountain ranges, landscape
  response timescales, and research needs". Journal of Geophysical Research
  104(B8), 17661-17674. DOI: 10.1029/1999JB900120. Response timescales.
- Barnes, R., Callaghan, K. L., Wickert, A. D. (2021). "Computing water flow
  through complex landscapes - Part 3: Fill-Spill-Merge: flow routing in
  depression hierarchies". Earth Surface Dynamics 9, 105-121.
  DOI: 10.5194/esurf-9-105-2021. Overflow as the process that incises a sill.
- Messager, M. L., Lehner, B., Grill, G., Nedeva, I., Schmitt, O. (2016).
  "Estimating the volume and age of water stored in global lakes using a
  geo-statistical approach". Nature Communications 7, 13603.
  DOI: 10.1038/ncomms13603. HydroLAKES.
- Lehner, B., Grill, G. (2013). "Global river hydrography and network routing:
  baseline data and new approaches to study the world's large river systems".
  Hydrological Processes 27, 2171-2186. DOI: 10.1002/hyp.9740. HydroBASINS.
- Naldrett, A. J. (2004). "Magmatic Sulfide Deposits: Geology, Geochemistry and
  Exploration". Springer. DOI: to confirm. The absolute-age control the
  stationary argument cannot place.

## Amendments

- 2026-09-08: conversion rule for Sourced per-year coefficients with non-integer exponents added (row 27), from notes/findings/2026-09-08-implicit-earth-audit.md
