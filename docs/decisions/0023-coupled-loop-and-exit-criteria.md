+++
id = "0023"
title = "The coupled loop: five timestep tiers, asynchronous terrain coupling, exits declared before the run"
status = "accepted"
date = 2026-09-08
+++

## Decision

Everything runs in one process on one mesh (0009), so the predecessor's five loops
of separate processes exchanging frozen artifacts become one integration with
declared durations and declared exit brackets.

**Timestep tiers.**

| tier | subsystems | step | driver |
|---|---|---|---|
| fast | atmosphere dynamics and physics, land column, sea-ice thermodynamics, tracer transport, canopy assimilation | the atmosphere step (a `Bracketed` interval with a `Derived` Courant ceiling, 0008); radiation at its declared interval with its `Derived` ceiling (0014) | atmosphere |
| ocean | ocean dynamics, sea-ice drift | the ocean step, sub-cycled by the coupler | ocean |
| daily | vegetation growth and allocation, fire, fast river routing | the mean solar day of the source of largest instellation (`Derived`, 0008); where that is undefined (a synchronous rotator) or exceeds a declared fraction of the orbital period, a `Bracketed` interval in seconds from the profile (0014; mechanisms: the fast tier's step at the low end, the orbital period at the high end), and the branch taken is recorded in the run identity | vegetation |
| orbital | demography, establishment and mortality, climate statistics accumulation | the longest declared periodic forcing with non-zero amplitude (the orbital period, or a longer cycle component), floored at a `Bracketed` duration in seconds (mechanisms: the fast tier's step at the low end, the orbital period at the high end) | vegetation, coupler |
| slow | terrain, hydrology (depression hierarchy, fill-spill-merge, water table), glacier flow (substepped), pedology, carbon balance, minerals | the terrain step | terrain |

**Every step and every window is a duration in seconds.** Each tier's step and each
window in this record is a `Derived` duration from a named relaxation or forcing
timescale of the configuration, rounded to whole periods only where a cycle must
close on itself (a seasonal cycle, a declared stellar cycle); no cadence is declared
as a count of days, orbits or cycles alone, because a configuration may have no such
period. Events that are seasonal by mechanism (leaf shedding, an establishment
attempt) fire on a seasonal amplitude above its bracket, never on the period itself;
a configuration with no seasonal cycle reports the orbital tier as coinciding with
the daily tier by name.

**Stellar cycle.** The forcing module modulates each source's flux with the declared
cycle components (0008). Climate statistics the slow tier reads are accumulated over
a declared number of the statistics window, which is `Derived` as the longest period
over the declared periodic forcings with non-zero amplitude, with the orbital period
as its floor; a cycle component of zero amplitude is never read as a window. So the
overflow time fraction per basin, the snowline and the lake balance are measured
distributions, not means.

**Asynchronous terrain coupling.** The slow tier advances one terrain step per call
using the accumulated climate statistics. The climate is refreshed (a warm restart
whose length is `Derived` from the fast-system relaxation time, the mixed-layer heat
capacity over the radiative feedback measured on the run's own A/A arm, rounded up to
whole orbital periods so the seasonal cycle closes, plus one statistics window, and
reported in seconds beside the count of orbits) when a declared change criterion
fires on the boundary conditions aggregated to the climate level (topography, land,
lake and ice fractions, connectivity graph topology, pCO2, vegetation albedo), or
after at most a declared number of terrain steps. A topology change in the
connectivity graph (0005) always fires. The acceleration factor is therefore a ratio
of declared quantities and is a `Bracketed` value to sweep, never a constant.

**Commissioning.** From the seed and the decayed initial terrain: a climate
commissioning at the profile's commissioning level with the ocean coupled, alternating
with accelerated ocean-only segments until the deep-drift bracket closes (0017);
vegetation and soil pools use an implicit steady-state accelerator for the slow pools
during commissioning, with a declared statement of what it is invalid for (peat,
inert permafrost carbon). Then the slow tier runs with refreshes. Then a final
operating run at the profile's operating level from the commissioning state, with a
reconvergence window after the level change `Derived` from the same fast-system
relaxation time as the warm restart.

**Exit criteria, fixed before the run, each with its own tolerance.** Top-of-atmosphere
and surface energy balance over an autocorrelation-corrected window (the window
estimated from the series itself per REQ-NUM-005); deep-ocean temperature drift;
sea-ice and glacier volume drift; lake area and drainage-share stationarity across a
declared number of statistics windows; pCO2 drift; land carbon drift; the terrain's
declared duration elapsed; every closure ledger (area, volume, water, salt, energy,
carbon, nitrogen, phosphorus) inside its derived tolerance at every reduction. A cap
on refreshes or on orbits is a refusal boundary, never a second success condition.

**Every tolerance is dimensionless.** The top-of-atmosphere and surface imbalance
tolerance is a fraction of the configuration's global-mean absorbed instellation, or
a multiple of the measured A/A scatter of that balance; each reservoir's drift
tolerance (deep ocean, ice, lakes, pCO2, land carbon) is a fraction of the
reservoir's stock per unit of the reservoir's own relaxation time, or a multiple of
the A/A scatter; ledgers are in units of the derived roundoff bound. The profile
stores the dimensionless bracket, and the run report prints the SI value beside it.
A tolerance registered in watts per square metre, kelvin or bars is refused at
registration, because it is a scale from another configuration.

**Verdicts.** `Converged`, `Bracketed`, `Refused`, `NotEvaluable` (0009). A loop
declared antitone cannot return `Converged`. A finalizer re-evaluates every exit at
the final state and reports `NotEvaluable` as its own verdict where the instrument
does not exist at the operating level, never substituting a coarser artifact.

**Profiles.** The two profiles (0014) set the levels, cadences, refresh criteria and
brackets; a fast-profile result is labelled as such wherever it appears.

## Alternatives considered

- *A verdict map iterated to a fixed point* (the predecessor's loop A). Rejected: the
  map was antitone, so it oscillated and could only bracket; the physical situation is
  a slow threshold process under fast variable forcing, which integrates.
- *Synchronous terrain stepping at the climate step.* Rejected: the timescales differ
  by many orders; the asynchronous coupling with a change criterion is the standard
  form.
- *A fixed acceleration factor.* Rejected: it is a ratio of declared quantities and
  must be swept like any bracket.

## Consequences

- The predecessor's loops A, O, B and C do not exist as loops; their circuits are
  tiers of one integration. Loop D (the resolution ladder) is the profile pair.
- Every exit has an instrument that can evaluate it before the run starts, or the
  run refuses to start.
- The refresh criterion is the one place where the fast and slow tiers negotiate,
  and it is declared, swept and reported.
- The daily tier's branch (mean solar day or profile fallback), the statistics
  window, the warm-restart length and every dimensionless tolerance are part of the
  run identity, so a synchronous rotator and a fast rotator at one profile are two
  identities, not one.
- The tier-2 registry bar `earth.ceres_toa_balance` is the Earth instance's
  distance report; the coupled-loop exit reads the dimensionless form above, never
  that bar.

## References

- Sausen, R. and Voss, R., "Techniques for asynchronous and periodically synchronous coupling of atmosphere and ocean models. Part I: general strategy and application to the cyclo-stationary case", Climate Dynamics 12 (1996). DOI: to confirm
- Voss, R. and Sausen, R., "Techniques for asynchronous and periodically synchronous coupling of atmosphere and ocean models. Part II: impact of variability", Climate Dynamics 12 (1996). DOI: to confirm
- Bryan, K., "Accelerating the Convergence to Equilibrium of Ocean-Climate Models", Journal of Physical Oceanography 14 (1984). DOI: 10.1175/1520-0485(1984)014<0666:ATCTEO>2.0.CO;2
- Willeit, M. and Ganopolski, A., "PALADYN v1.0, a comprehensive land surface-vegetation-carbon cycle model that addresses the computational efficiency needs of ESMs", Geoscientific Model Development 9 (2016). DOI: 10.5194/gmd-9-3817-2016 (the slow-pool accelerator and its stated invalidity)
- Willeit, M. et al., "The Earth system model CLIMBER-X v1.0 - Part 1: Climate model description and validation", Geoscientific Model Development 15 (2022). DOI: 10.5194/gmd-15-5905-2022

## Amendments

- 2026-09-08: every tier step and window is a Derived duration in seconds from a named timescale; the daily tier steps on the mean solar day of the dominant source with a Bracketed profile fallback recorded in the run identity; the orbital tier steps on the longest non-zero periodic forcing, floored; seasonal events fire on a mechanism, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the statistics window is the maximum over non-zero periodic forcings with the orbital period as floor, and a zero-amplitude cycle is never a window; the warm restart and the reconvergence window derive from the fast-system relaxation time, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: every exit tolerance is dimensionless (fraction of absorbed instellation, units of A/A scatter, per unit relaxation time) and stored so in the profile; an absolute tolerance is refused at registration, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: cross-area review: both ends named for the daily tier's fallback interval and the orbital tier's floor, from notes/findings/2026-09-08-implicit-earth-audit.md
