+++
id = "REQ-HYD-006"
title = "Every depression is a node of the drainage physics, with no selection floor and its state measured on the terrain the water sits on"
old_path = ["/home/cfutro/git/vesper/notes/audits/basin-catalogue-floor.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's terrain generator selected which depressions entered a basin
catalogue by three floors (cell count, area, depth) plus a nesting rule, and the
catalogue decided every later pass. Measured 2026-08-24 and 2026-08-25 on two pre-carve
builds of the predecessor's generated world at 2.5M and 10M regions (mean cell 293.80
and 73.45 km2), with three controls on the instrument (reproduction id for id;
sensitivity, halving every floor admits strictly more; residue, two independent paths
to the below-sea-level count):

- The mesh floor bound at 2.5M (+123% basins when relaxed) and not at 10M (+0.1%), the
  crossover a resolution audit had predicted.
- The depth floor was named in kilometres and compared in the generator's dimensionless
  elevation parameter, whose conversion to length is quartic on land and saturated at
  its top: one declared number demanded 0.000 to 0.49 km of physical depth (median 62
  to 85 m), 21 to 22% of preserved basins were shallower than the floor they had
  cleared, and basins with zero physical depth passed. Reading the floor as a length at
  reference gravity rather than at the planet's moved 186 and 553 basins; it was
  settled at reference because the relief scaling multiplied both sides.
- What the catalogue missed below its area floor converged in AREA (0.405% to 0.364%
  of land across a fourfold refinement) and not in COUNT (9.5% to 4.9%): a property of
  the declared floor, not of the mesh.
- "Preserved" was not "still closed". Conditioning passes outside the protection
  contract lowered the median preserved basin's rim to 0.80 of its catalogued relief;
  16 of 9,419 preserved basins had zero capacity on the finished terrain and were
  published with a full retain and a hypsometry measured on the pre-conditioning
  surface; no field let a consumer tell them apart.
- The retain fraction was computed against the finished depression in metres and spent
  by the generator against the natural depression in model units: the median
  instruction bought about twice the incision it asked for, across a factor of thirty,
  until the basis was declared at the interface and converted, leaving a residual
  bracket of 0.46 to 1.68 from the ratio's own spread.

## Why it carries

B1 makes closed basins physics: a pit is a lake node receiving water and sediment, and
a sill is incised only by overflow discharge. B5 routes on a depression hierarchy with
fill-spill-merge. In that design there is no catalogue and no floor to mis-specify, and
the audit is the evidence for why: a floor in the wrong unit decided the outcome, the
count of small depressions never converges while their area does, a state a consumer
reads must be measured on the artifact the consumer reads, and a fraction crossing a
boundary must state its basis. The dimension-on-the-type rule (A2, A3) and the exact
nesting of A1 are what make these unrepresentable; the controls on the instrument
generalise to every selection or threshold audit.

## What this system must do

- Drainage on the terrain level treats every depression as a node of the hierarchy,
  with no cell, area or depth floor. If any consumer needs a minimum feature size it is
  a declared Bracketed resolution parameter swept across levels, and the missed AREA is
  reported at each level.
- Every basin quantity (hypsometry, capacity, spill level and target, catchment) is
  computed from the terrain state at the time it is read, exact at the terrain level
  and reduced by area through nesting; no basin state is carried from an earlier
  surface.
- Lengths are SI on the type; gravity enters incision through `K`, isostasy and
  strength (B1), never as an export scaling, so a depth is one number and a threshold
  on it cannot mean two things.
- A fraction or instruction crossing a component boundary declares its basis (which
  depth, which surface, which unit) in the contract; the receiver refuses an
  undeclared basis. There is no basin instruction at all in this design (REQ-HYD-008),
  but the rule holds for every boundary.
- Any instrument that measures the effect of a selection or threshold carries
  reproduction, sensitivity and residue controls that can fail.

## Enforced by

A2 dimensioned `Field` types; the M0 area and nesting identities; a lint that the
hydrology module declares no size floor; a convergence-with-level oracle on lake area
and closed-drainage share; the A5 assemble check on contract bases.

## References

- Computing water flow through complex landscapes - Part 2: Finding hierarchies in
  depressions and morphological segmentations. Barnes, Callaghan, Wickert (2020), Earth
  Surface Dynamics 8, 431-445. DOI: 10.5194/esurf-8-431-2020
- Computing water flow through complex landscapes - Part 3: Fill-Spill-Merge: flow
  routing in depression hierarchies. Barnes, Callaghan, Wickert (2021), Earth Surface
  Dynamics 9, 105-121. DOI: 10.5194/esurf-9-105-2021
- Priority-flood: An optimal depression-filling and watershed-labeling algorithm for
  digital elevation models. Barnes, Lehman, Mulla (2014), Computers and Geosciences 62,
  117-127. DOI: 10.1016/j.cageo.2013.04.024
- A very efficient O(n), implicit and parallel method to solve the stream power
  equation governing fluvial incision and landscape evolution. Braun, Willett (2013),
  Geomorphology 180-181, 170-179. DOI: 10.1016/j.geomorph.2012.10.008
