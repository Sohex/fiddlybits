+++
id = "REQ-PED-009"
title = "Surface state derived from climate, drainage and chemistry on two independent axes, with declared precedence, a record of which rules fired, and mechanisms taken from primary sources"
old_path = ["/home/cfutro/git/vesper/pedology/README.md", "/home/cfutro/git/vesper/pedology/notes/derived-surface-classes.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The terrain generator gave what a rock IS; what the surface has BECOME under a
climate and a drainage is what albedo, dust emission and the phosphorus cycle key on.
The predecessor emitted two independent fields, `surface_cover` (water, loess,
diatomite, pavement, bare, soil: what wind and light see) and `duricrust` (gypcrete,
calcrete, silcrete, none: what is cementing at or below the surface), because they do
not compete for the same physical position; a single cover chain had lost basin fill
on 203 preserved basins by branch order. Precedence exists only within an axis and is
declared as an ordered list; every cell records which rule fired and which others it
also satisfied, because a rule that never fires and a rule that always fires are both
bugs and neither is visible without that record.

Reading the primary sources reversed two mechanisms. Desert pavement is a dust SINK,
not deflation armour: Wells et al. (1995) dated clasts with cosmogenic 3He and found
them at the surface the whole time, with dust accumulating beneath the clast mosaic as
an accretionary horizon; McFadden, Wells and Jercinovich (1987) put the clast source at
mechanically weathered bedrock highs, state that supply stops once the highs are worn
down and buried, and that moderate deposition is needed while high loess rates bury
the pavement. So pavement enters the dust model with the opposite sign, as a
suppressor and a store, its area is an upper bound on old surfaces, and it needs dust
without any minimum rate being sourced. Loess is trapping-limited, not flux-limited:
Muhs (2013) carries no accumulation rates, but the Sahara sits in the highest modern
flux bin and produces essentially no loess, so a rule keyed on deposition alone paints
loess on the source; the rule became a deposition threshold (50 g/m2/yr, Bracketed 10
to 200, read off one figure's before-and-after at one place) plus a trapping surface.
Silcrete got no climatic threshold (Fenske et al. 2025 say climate gives none) and was
placed by hydrological setting after Ullyott and Nash (2016): pan margin, drainage line
and groundwater types are placeable from the drainage and water table, the pedogenic
type was dropped, and the groundwater type waited on a water table. Gypcrete (Watson
1983: under about 250 mm/yr with potential evaporation exceeding precipitation in
every month, so monthly fields, not annual means) and calcrete (Alonso-Zarza 2003
windows) are two-sided climatic windows with ion gates from the chemical divide
(REQ-PED-008). Diatomite needs a lake persistent enough to be productive and then
desiccated enough to deflate, which is a cycle problem: the static proxy (the
strandline band between the solved lake and the spill, checked against hypsometry at
a ratio of 0.980) stands in for occupancy over the slow stellar-cycle component.
Measured 2026-08-17 on the pre-carve build of the predecessor's generated world, loess
ran from nothing to 47% of land across the aeolian roughness bracket (a factor of 40
in emission) while pavement ran the other way, one threshold read from two sides; the
classes are the most disposable product in the component because a climatology, a
lake solution and a dust field drive them.

## Why it carries

B4's column needs bare, wetland and lake tiles; B2's N-band surface albedo per surface
class and dust emission on bare tiles need a surface class; B1's stratigraphy holds
cover with deposition age; B8 carries aeolian deposition and evaporite cover. A2 makes
the classes categorical fields with fraction reductions. The general rules are: take
the sign of a mechanism from the primary source, because a class named for the wrong
mechanism enters a budget with the wrong sign; do not resolve in one chain things that
do not compete for a position; record which rules fired; every threshold Sourced or
Bracketed; a class about alternation needs the cycle, not one climatology.

## What this system must do

- Surface cover and cementation are two categorical fields on the terrain level,
  written into B1's cover stratigraphy with deposition age, each with declared
  precedence and a fired-and-satisfied record; a rule that never fires or always fires
  fails the report.
- Every threshold is Sourced or Bracketed with its source's own statement of the
  bound's direction, carries a time-base class per REQ-BIO-001 item 6 (a rate per Earth
  year or per Earth month is `PhysicalKinetic`, stored per second and converted once),
  and an interval a source names as a month is a declared fraction of the orbit;
  criteria at that interval or finer are evaluated on the resolved series. Where a
  source's window is written on a potential evaporation, the quantity is the column's
  own evaporation from a saturated bare tile (0018, one definition), never a
  combination-equation estimate.
- Pavement suppresses dust emission and stores deposition; its clast supply is drawn
  down on the clock (REQ-PED-001) so old surfaces lose it. Loess requires deposition
  above a Bracketed threshold on a trapping surface.
- Silcrete, calcrete and gypcrete are keyed on hydrology (the water table of
  REQ-HYD-003, drainage lines and pan margins from B5) and on the divide's ion supply.
- Diatomite is placed from lake occupancy statistics over the statistics window of
  0023, never from one climatology.
- The aeolian roughness bracket is swept and both loess and pavement are reported at
  its ends; the strandline area identity against hypsometry runs each time.

## Enforced by

A2 categorical semantics; A3 dispositions on every threshold; the fired-rule report;
the B9 cycle statistics; the dust ledger of B8.

## References

- Cosmogenic 3He surface-exposure dating of stone pavements: Implications for landscape
  evolution in deserts. Wells, McFadden, Poths, Olinger (1995), Geology 23, 613-616.
  DOI: to confirm
- Influences of eolian and pedogenic processes on the origin and evolution of desert
  pavements. McFadden, Wells, Jercinovich (1987), Geology 15, 504-508. DOI: to confirm
- The geologic records of dust in the Quaternary. Muhs (2013), Aeolian Research 9,
  3-48. DOI: 10.1016/j.aeolia.2012.08.001
- Distinguishing pedogenic and non-pedogenic silcretes in the landscape and geological
  record. Ullyott, Nash (2016), Proceedings of the Geologists' Association. DOI: to
  confirm
- Gypsum crusts in deserts. Watson (1983), Journal of Arid Environments 6, 3-14.
  DOI: to confirm
- Palaeoenvironmental significance of palustrine carbonates and calcretes in the
  geological record. Alonso-Zarza (2003), Earth-Science Reviews 60, 261-298.
  DOI: 10.1016/S0012-8252(02)00106-X
- Fenske et al. (2025), duricrust formation as a water-table fluctuation model. DOI: to
  confirm (verbatim title to be taken from the old index)

## Amendments

- 2026-09-08: thresholds carry time-base classes, a source's month is a declared
  fraction of the orbit, and potential evaporation is the column's saturated-bare-tile
  evaporation (audit rows 20, 38), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: diatomite placement reads the statistics window of 0023, from notes/findings/2026-09-08-implicit-earth-audit.md
