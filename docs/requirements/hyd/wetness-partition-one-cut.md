+++
id = "REQ-HYD-009"
title = "One mutually exclusive wetness partition per cell, cut against one solve, crossing to tiles as areas that never mean depths"
old_path = ["/home/cfutro/git/vesper/notes/audits/wetness-partition-cut.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured 2026-09-05 on the predecessor's generated world (build `canonical-10m-carve2`,
4,328,732 land regions, twelve time bins). The lake balance was solved twice, as an
annual equilibrium and as a periodic steady state through the bins, and painted twice:
annual lake 2.1189% of land; wet in every bin 2.0673%; wet in some bins 0.1576%. The
symmetric difference between the annual paint and the assigned open-water class was
0.0684% of land, 0.032 of the lake area, and every square kilometre of it lay inside
the depression footprint: the two solves disagreed about where a shoreline sits and
about nothing else. Taking open water from the annual paint and seasonal inundation
from the cycle would have claimed 2,566 regions twice; the exclusive assignment refused
that by construction, so the partition was cut against one solve, the cycle, which is
the one that carries the seasonal class: wet in every bin is open water, wet in some
bins is seasonal inundation, and the depression floor neither takes is playa. The dry
mineral residual did not move to the digit (89.0869% under either cut). A basin whose
year did not close has no cycle, and for its regions the annual paint is the only
statement that exists; that count (3 regions) is written rather than absorbed. The
number to watch is the share of the disagreement lying outside the depression
footprint, zero here; non-zero would mean the two solves disagree about something
other than a shoreline.

The surrounding rules from `/home/cfutro/git/vesper/hydrography/README.md`: a
majority label discards every minority surface however much leverage it has, so a
class crosses as an area share; the playa class is the depression floor at or below its
spill not covered by the lake, checked as an identity against the basin's own
area-at-spill; each class carries its area (extensive) and its share (categorical)
computed independently, so the pair is a check on the population; a class with no
mechanism producing it (saturated non-inundated mineral soil, peat, river surface) is
declared absent with its reason rather than estimated; and no cell-mean water table
depth, capacity or latitude selector may stand in for an area. Seasonally inundated
land is three quantities under one name: a closed basin's (from hypsometry), a
floodplain's (needs a height-above-drainage distribution and a routing model), and
seasonally saturated soil (a water content, not an area).

## Why it carries

B5 says wetness classes cross to tiles as areas; B4 gives the column lake, wetland and
bare tiles; B7 keys wetland methane on area; A2 makes a categorical field's only
reduction a fraction; REQ-HYD-012 books lake evaporation on the open-water area and
runoff on the land area. The partition rule is what stops double counting that a
ledger renormalising shares would hide, and the choice of one solve to cut against is
the general rule for any classification derived from two solutions of one balance.

## What this system must do

- Each column's land tiles are a partition of its land area derived from the terrain
  level by exact nesting: one class per fine cell, shares summing to one over land, area
  and share computed independently and checked against each other.
- Inundation classes are cut against the periodic lake solution (REQ-HYD-011); the
  equilibrium solution is never mixed into the same partition. A basin without a closed
  cycle is flagged, its cells take the equilibrium state, and the count is emitted.
- A class with no producing mechanism is a declared absence, never a residual; a
  floodplain area exists only with the routing model of B5 and a channel width.
- No depth, capacity or mean water table stands in for an area; no geographic selector
  picks a class.
- The playa-area identity against hypsometry and the disagreement-outside-footprint
  diagnostic are emitted on every run.

## Enforced by

A2 type: a categorical `Field` coarsens only by `cell_fraction`; a self-test with
named violating cases (a mask that forgot the lake, land in no class, a share added
beside the partition, a rule selecting the catchment instead of the floor); the
partition-sum identity; the open-water share against REQ-HYD-001's oracle.

## References

- Estimating the volume and age of water stored in global lakes using a geo-statistical
  approach. Messager et al. (2016), Nature Communications 7, 13603.
  DOI: 10.1038/ncomms13603
- Development and validation of a global database of lakes, reservoirs and wetlands.
  Lehner, Doll (2004), Journal of Hydrology 296, 1-22.
  DOI: 10.1016/j.jhydrol.2004.03.028
