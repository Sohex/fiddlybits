+++
id = "REQ-HYD-001"
title = "Terminal-lake equilibrium test against Earth lakes, with a pre-registered bar and a refusal on error correlation"
old_path = ["/home/cfutro/docs/world/hydrography/notes/lake-solver-validation.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

A terminal lake in equilibrium with its catchment satisfies `R (C - A) = (E - P) A`,
so `A / C = R / (R + E - P)` for catchment area `C`, lake area `A`, catchment runoff
depth `R` and open-water evaporation and precipitation `E`, `P`. The relation is scale
free and needs no hypsometry, which is what makes it testable on Earth without testing
Earth's basin shapes.

The predecessor registered the test before any data was fetched (2026-08-17): PASS if
the median absolute log10 ratio of predicted to observed lake area is below 0.30,
MARGINAL to 0.60, FAIL above 0.60 or if the error correlates with basin size, aridity
or lake area, on the stated ground that a correlation means a missing term rather than
noise. Scored over 145 Earth terminal lakes from HydroLAKES v1.0 joined to HydroBASINS
level 5, the result was FAIL: median absolute log ratio 0.622, 30% of lakes within a
factor of two, and the error correlated with catchment runoff at +0.760 and with
catchment area at +0.467. The failure was two-sided. The wettest runoff quartile
over-predicted about fivefold because the relation lets a lake grow until evaporation
consumes its supply while a real basin stops at its sill and passes the rest on: the
missing term was the spill cap, which the full solver had and the relation did not.
The driest quartile under-predicted about eightfold: groundwater inflow that no surface
balance sees (a third of one lake's input) and arid terminal lakes that are relicts of
wetter climates rather than equilibria. The middle quartile carried a bias of +0.077
with a scatter of 0.374. Measured on the predecessor's generated world, 1,737 of 2,465
water-holding basins sat at their spill, so the relation governed the fate of only 728;
the population the Earth test speaks to was the minority.

Two further measurements attach. Representing two real closed basins (Qaidam, Great
Salt Lake) at about 15 km from Copernicus DEM 90 m understates flooded storage by 13%
at 400 m above the floor and by 30 to 50% in the 25 to 100 m range, and misses shallow
flooding on a broad pan entirely, because block averaging fills a floor with the ridges
around it; the bias is one-signed toward spilling. The area-volume scaling `V = c A^k`
of the solved lakes gave `k = 1.26` against 1.17 to 1.21 for Earth lakes above 10 km2,
a shape check that passed. A comparison of basins filled to their spill against Earth's
present-day, mostly shrunken, lakes was run first and is a category error.

## Why it carries

This is an Earth oracle of the second tier (C1): a planet-independent relation scored
against an observational compilation with verdicts fixed before the run. The rule that
a correlation between error and a forcing variable is a FAIL regardless of the median
is a general design rule for every oracle in the registry; a bar on the median alone
would have called two structurally missing terms "scatter". The two-sided failure also
names what a lake model must carry before its Earth score means anything: a spill cap
from hypsometry, a groundwater term (REQ-HYD-003), and an explicit statement of which
basins are in equilibrium at all. The M2 gate in the plan is this test with no error
correlation.

## What this system must do

- Register the terminal-lake oracle with its bar, its three verdicts and the refusal on
  error correlation (against runoff, catchment area, aridity index and lake area) before
  any Earth lake data is fetched, per C2.
- Score the full lake cascade of B5 (depression hierarchy, fill-spill-merge, hypsometry
  from the terrain level, groundwater exchange), not the bare relation. Classify each
  scored basin as evaporation-limited or spill-limited from the solution; the
  equilibrium relation is scored on the first population and the spill cap on the
  second, against area at spill and capacity measured from DEM data at the terrain
  level's spacing.
- Select basins by whether a defensible pre-development water balance exists, stated per
  basin before scoring; use long-term mean lake areas, never a single year; report every
  basin including the misses, stratified by runoff quartile.
- Report the mesh-scale storage understatement as a one-signed bias at each hierarchy
  level (a convergence-with-level oracle), and the `V = c A^k` exponent as a REPORT
  metric of shape.
- Never compare full-to-spill basins against present-day Earth lake areas.

## Enforced by

Oracle registry entry (M2 gate); C1 verdict semantics; C5 mutation run: a build with
the spill cap disabled must fail the correlation clause, and a build with the
groundwater term disabled must show the dry-tail bias.

## References

- Estimating the volume and age of water stored in global lakes using a geo-statistical
  approach. Messager, Lehner, Grill, Nedeva, Schmitt (2016), Nature Communications 7,
  13603. DOI: 10.1038/ncomms13603
- Global river hydrography and network routing: baseline data and new approaches to
  study the world's large river systems. Lehner, Grill (2013), Hydrological Processes 27,
  2171-2186. DOI: 10.1002/hyp.9740
- Recent global decline in endorheic basin water storages. Wang, Song, Wei, Yin, Zhou,
  Nardi, Zhu (2018), Nature Geoscience 11, 926-932. DOI: 10.1038/s41561-018-0265-7
- Copernicus DEM GLO-90. European Space Agency (2021). DOI: to confirm (ESA product
  record 10.5270/ESA-c5d3d65 is believed to be the locator).
