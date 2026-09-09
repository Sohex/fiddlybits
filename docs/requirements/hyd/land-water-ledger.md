+++
id = "REQ-HYD-012"
title = "Land water is a ledger of mass with one owner per store, one debit per evaporative component, and closure at every interval down to the model step"
old_path = ["/home/cfutro/docs/world/hydrography/notes/land-water-ledger.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Recorded 2026-08-24 as a contract, resting on
`/home/cfutro/docs/world/biosphere/notes/soil-land-surface-hydraulic-consistency-audit.md`.
The predecessor had a water balance and not a ledger. Its land-atmosphere surplus
closed at equilibrium, its groundwater solver conserved its own recharge, and its
basin code added only signed exchange, and together they let one interval's positive
`P - E` over one cell be spent three times: as the climate model's bucket overflow, as
the surface-water builder's catchment runoff, and as the groundwater builder's
recharge. Each consumer was internally consistent. A balance answers "does the total
come out"; the coupled column needs "which store was debited, by which component, over
which interval".

The contract: substance is water mass, never a depth (a mass only once an area is
named) or a volume (a mass only once a density and a phase are named; snow at 330 and
at 275 to 500 kg/m3 in two models is the same water). Unit is kilograms per declared
interval; the area basis of each node (land cell, open-water fraction, coastline
segment) is an argument, because a script reconstructing a mass from another's depth
with its own area changes the mass silently. Closure is required at every interval
down to the model timestep, not only at the reporting interval: a ledger that closes
annually and not daily is the finding rather than the fix, so every term declares an
interval floor and an annual mean cannot feed a store that empties and refills inside
the year. Nodes have kinds (boundary, reservoir, terminal, interface) that decide what
closure does at them. A canopy node with no owner makes an absent interception store
countable; two models each holding the snowpack are one water counted twice; the
vegetation interface carries root uptake and transpiration as two terms so an unmatched
pair leaves a residual instead of being absorbed; an unowned-source boundary must
carry nothing, and the one crossing ever booked there became a declared absence with a
measured bound from three properties of the source model. The identity per node and
over the domain is mass conservation; a second invariant, that each evaporative
component (canopy, soil, transpiration, sublimation, open water, groundwater uptake) is
debited by exactly one term from exactly one store, is not implied by the first, since
two models withdrawing the same millimetre conserve mass and are still wrong. Every
phase change declares its transform and the latent heat it carries, with
`sublimation = vaporisation + fusion` held as an identity against a fourth constant
appearing elsewhere. The checker ships eleven closure fixtures (ten built wrong in a
named way) and twelve mutations of the declaration that it is required to catch; a
fixture or mutation that does not get its verdict fails the checker. Named absences
(soil water above field capacity in a column that stores a fraction of available
capacity; open-water evaporation of routed water, so a terminal lake was
unrepresentable) are entries with an owner, and a module that relies on an absence
names it so that closing the absence fails the module's gate. Seasonally inundated
area was three quantities under one name (closed basin, floodplain, saturated soil)
and had no owner until they were separated.

## Why it carries

A5 couples in one process with one declared writer per quantity and `Exchange`
objects closing ledgers at every boundary; A2 returns a ledger from every operator and
the store refuses an open one; C3 puts ledgers at every exchange with tolerances from
floating point and classifies the residual's time signature. B4's one land column makes
a shadow store unrepresentable, but not a double debit, an area-basis mismatch, an
interval mismatch or an unnamed phase change, and the fixtures that catch those are
the test of the ledger machinery itself. Every clause is conservation of mass and
ownership, independent of any planet.

## What this system must do

- The land water ledger is part of the `WorldState` store: every water store has one
  owner; every transfer has one source node, one destination node, a mass, an interval,
  a transform and its latent heat; kinds of node decide the closure check.
- Each evaporative component is debited once from one store; a second debit is an
  assemble-time error, not a residual.
- Closure is evaluated at the model step in FP64 with a floating-point-derived
  tolerance, and a residual's time signature is classified as leak, stock omission or
  roundoff.
- The area basis is part of a term's contract (tile area against column area); the
  ledger converts, and no consumer derives a mass with its own area.
- Absences are declared entries with an owner and a bound; a module relying on an
  absence names it, and closing the absence fails that module's gate.
- The checker's fixtures and declaration mutations ship with it and run per commit; an
  uncaught mutation fails the build.
- A producer supplying only a coarser interval than a store's own cannot feed that
  store (interval floor check at assemble).

## Enforced by

A5 assemble check; A2 `(field, ledger)` return and store refusal; C3 ledger oracle; C4
mutation run; the M5 gate (ledgers closed at the seam) and B9 exit (every ledger inside
tolerance).

## References

This record rests on conservation of mass and on the A2, A5 and C3 decision records
rather than on a published law. The old audit that motivated it is at the path given
above; no external primary source is claimed.
