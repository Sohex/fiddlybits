+++
id = "REQ-HYD-011"
title = "Lake storage is integrated in closed form on the hypsometric curve per forcing interval, the year must close on itself, and the balance is published per interval"
old_path = ["/home/cfutro/git/vesper/hydrography/notes/lake-balance-integration.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured 2026-08-27 on the predecessor's generated world (build `canonical-10m-base`,
8,772 basins, 8,739 with an impoundment). An explicit sub-stepped integrator with an
accuracy limit (2% of capacity per step) and a stability limit refused to run: the
binding case was a small reservoir on a large river, 29.8 km3 of storage passing 1,381
km3/yr, pinned at its spill and not moving at all while every sub-step recomputed that
it was full. The requirement grew with the overflow cascade cycle by cycle (50, 95, 192
sub-steps, then past the limit), so no constant bounded it. A second defect: every
hypsometric curve built from mesh cells carried a whole cell of area at zero volume,
so 3,425 basins whose supply could not fill that first cell were charged open-water
evaporation over water they did not hold (79.8 km3 per cycle) and the seasonal
signature of exactly the playas the product describes was suppressed.

The repair removes the constants rather than adding one. The forcing is constant
within a bin and the curve is piecewise linear, so `dV/dt = S - D A(V)` is a linear
ordinary differential equation on every segment and its solution is the exponential;
each segment is solved exactly by computing the time to cross it. `A` is non-decreasing
in `V`, so the storage moves one way within a bin and crosses each level at most once:
the work is bounded by the curve's length, and reaching that bound is a defect in the
curve, not a bin needing finer integration. A spilling basin is charged the demand at
its spill area for the whole time it spills, and cycle means are the integrator's exact
time integrals rather than bin-end samples averaged. A basin below the first cell gets
the only lake the balance allows, area `S / D`, which is what the equilibrium solve
already returned at the bottom of its curve, so the two solves agree at the dry end.
Tolerances were declared from what double precision can carry: the closed form against
the exponential at 1e-13 (achieved 1.3e-16); a spilling basin passing 22 times its
capacity in one step, exact; agreement with a stiff reference integrator at rtol 1e-10
over 72 cases at 1e-6 of capacity (1.3e-9); per-bin, per-basin and set-wide closure at
1e-10 (2.9e-18, 1.1e-17, 2.2e-15). The bin-balance check refused at 0.0178 relative
before the sub-cell fix, which is how that defect was found. All 8,739 live basins
closed their year in 33 cycles.

A third defect fell out of the gap between the two solves: a 27% difference in lake
area (42.98 against 31.39 Mkm2) was 11.68 Mkm2 of forcing (the equilibrium solve had
read the evaporation scheme once on annual-mean air, REQ-HYD-007) and 0.09 Mkm2 of
storage response. Two solves of one balance must read one forcing. Left unsettled: the
cascade's timing inside a bin, since an upstream basin's overflow was delivered as a
rate held constant across the bin. The periodic criterion is the closure of the year on
itself in each basin's own volume, propagated down the spill cascade because a basin
whose volume repeats while its supply does not is riding a transient; the amplitude is
published only where the swing clears a tenth of the mean area and one mesh cell; bin
lengths must be in the same year unit as the fluxes, and the closure test is
insensitive to that mixing, so a separate check carries it.

## Why it carries

B5 gives lake level, area and volume with water conserved by construction; C3 names
closed-form lake cascades as an analytic oracle; A7 keeps every reservoir in FP64. The
exact segment walk is the general method for a monotone piecewise-linear ODE and
removes step-size and stability constants, which under A3 have no disposition to carry.
The sub-cell lake, the one-forcing rule, the periodic-closure criterion propagating
through a cascade, and closure tolerances derived from floating point are all
planet-independent. A4's single clock in seconds removes the year-unit trap by
construction.

## What this system must do

- Integrate every lake's volume over each forcing interval by exact segment solution on
  its hypsometric curve from the terrain level; no step-size, accuracy or stability
  constant exists in the integrator.
- A basin whose supply cannot fill the curve's first sample carries the balance's own
  area, and the hypsometric curve is exact at its samples at the finest level.
- The periodic steady state is the criterion: each basin's cycle repeats to a
  floating-point-derived relative tolerance in volume, propagated down the spill graph;
  a refused basin is flagged, never reported as a value.
- The water balance residual per interval, per basin and over the set is published
  against throughput and refused past its tolerance; reservoirs accumulate in FP64.
- The equilibrium and periodic solutions read one resolved forcing.
- Overflow delivery within an interval uses the crossing time from the upstream
  basin's own integration, so the cascade's timing is exact rather than held constant.
- Time is SI seconds on the one clock; a mutation that mixes a year unit into an
  interval must be caught by the amplitude check, not by closure.

## Enforced by

C3 oracle (closed-form cascade against a stiff reference integrator at declared
tolerance); the ledger (REQ-HYD-012); self-tests with the declared tolerances printed
whether they pass or not; C4 mutation run (sub-cell area removed; mixed time unit;
delivery held constant).

## References

- Computing water flow through complex landscapes - Part 3: Fill-Spill-Merge: flow
  routing in depression hierarchies. Barnes, Callaghan, Wickert (2021), Earth Surface
  Dynamics 9, 105-121. DOI: 10.5194/esurf-9-105-2021
- Solving Ordinary Differential Equations II: Stiff and Differential-Algebraic
  Problems. Hairer, Wanner (1996), Springer Series in Computational Mathematics 14.
  DOI: 10.1007/978-3-642-05221-7
