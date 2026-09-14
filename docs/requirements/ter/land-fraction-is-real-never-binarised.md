+++
id = "REQ-TER-012"
title = "Land fraction is a real quantity of every cell at every level, and no component binarises it"
old_path = ["/home/cfutro/git/vesper/notes/audits/coastline-threshold-cost.md", "/home/cfutro/git/vesper/notes/audits/partial-cell-tile-state.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's `canonical-10m-carve2` build across T21 to T170:
cells with a partial land share held 55.5 per cent of planet area at T21, 36.0
per cent at T42 and 13.8 per cent at T170. The binary threshold dropped 11.58
per cent of the mesh's land into the slab ocean at T21 (3.67 at T170) and
promoted 10.56 per cent of water to land; the net hid the two halves by 4.5 to
10x (REQ-TER-003). It also flooded, through a different door, the terrain the
fork existed to preserve: 6.44 per cent of below-datum closed-basin floor went
to the ocean at T21, and the land-volume closure carried the sign. The third
class (inland water) competed with land for the cell's classification and was
inert only because the class was empty. Every alternative rule was priced
beside the threshold: exempting any cell with below-datum land recovered all of
it and inflated the model's land by 46.8 per cent at T21; a share-based
exemption was inert at any safe strength, because the below-datum land the
threshold floods sits in cells that are mostly ocean; an area-conserving
threshold spent the closure that carries the sign. 0.5 was the only value that
made the rounding single, because the climate model binarised its own copy of
the mask at 0.5 in three modules (land, ocean, ice), so any other value rounded
the cell twice by two rules that did not know about each other. The measured
flux bracket, -0.0719 to +0.1253 W m-2 against a 0.12 W m-2 storage tolerance,
selected a tile representation.

The tile carrier then showed what a fraction without tile state is. Exactly one
surface owner advanced on each cell, and neither owner initialised outside its
mask. The completion that was to give the absent tile a finite copy had been
keyed on the fraction's endpoints, the complement of its own population: a
1.0e20 sentinel sat on 620 ocean-owned partial cells and an unassigned zero on
433 land-owned ones, 1,053 in total, exactly the partial cells the tiles
existed for, written into the restart under a name saying they were tile state.
They were inert until the next slice read them into a flux kernel under
floating-point traps. A land tile switched on over those 620 cells, 11.578 per
cent of the land area, would have started at open-water albedo with no canopy.
The remaining seams had an order: tile state, then restart, then dual
evaluation of exchange, then diagnostics; an exchange seam taken first
evaluates one surface twice and area-weights two copies of it, which returns
the binary answer through per-tile diagnostics that are not tiles. Cells with
fewer than 30 terrain regions of support held 0.028 per cent of land area, not
worth a repair against the declared tolerance.

## Why it carries

The plan's mosaic tiles (decision A1): an island is never rounded to ocean and
a strait never to land. The evidence sizes what binarisation costs at every
level, shows that no threshold value fixes it, that a fractional carrier
without tile state is a binary model wearing a fraction, that initial state
for a newly present tile is a boundary-condition question, and that a
below-datum land surface is land by connectivity and not by elevation sign.

## What this system must do

- Every cell at every level carries land, ocean and inland-water fractions as
  exact areas from the terrain level; a surface class is decided by
  connectivity to the world ocean (the connectivity graph, decision F1), never
  by the sign of elevation.
- Every surface owner (land column, ocean, sea ice, lake) advances wherever its
  fraction is positive; no module compares a fraction to a constant.
- A tile absent in a cell is a declared absence carrying no state, never a
  sentinel or a zero; a tile present in a cell has initial state from the
  boundary-condition builder (terrain level and neighbouring tiles), never from
  a flux kernel's first step.
- Exchange with the atmosphere is area-weighted over tiles that each hold their
  own state; the control that two deliberately identical tiles give the
  single-tile answer to roundoff is a test.
- The coastline ledger reports land lost, water promoted, and the land-volume
  closure as separate signed entries (REQ-TER-003).
- Refinement (F1) is invoked by an instrument for a feature's dynamics, never
  as the route out of the coastline, because past a certain level the
  reduction substitutes for the terrain (REQ-TER-005).

## Enforced by

- A1 mosaic tiles; B4 tile list; A5 one declared writer per quantity.
- Type: tile state is `Union{Tile, Absent}`; a sentinel is unrepresentable.
- Lint: a land fraction compared against a constant outside the mesh module is
  refused.
- Debug mode: floating-point traps on, so an undefined state is an error.
- M0 and M5 gates; Part E tripwire on a declared island, strait or isthmus
  absent from a coarse-level artifact.

## References

- Koster, R. D., Suarez, M. J. (1992). "Modeling the land surface boundary in
  climate models as a composite of independent vegetation stands". Journal of
  Geophysical Research 97(D3), 2697-2715. DOI: 10.1029/91JD01696.
- Avissar, R., Pielke, R. A. (1989). "A Parameterization of Heterogeneous Land
  Surfaces for Atmospheric Numerical Models and Its Impact on Regional
  Meteorology". Monthly Weather Review 117, 2113-2136.
  DOI: 10.1175/1520-0493(1989)117<2113:APOHLS>2.0.CO;2.
- Lawrence, D. M. et al. (2019). "The Community Land Model Version 5:
  Description of New Features, Benchmarking, and Impact of Forcing
  Uncertainty". Journal of Advances in Modeling Earth Systems 11, 4245-4287.
  DOI: 10.1029/2018MS001583.
- Best, M. J. et al. (2011). "The Joint UK Land Environment Simulator (JULES),
  model description - Part 1: Energy and water fluxes". Geoscientific Model
  Development 4, 677-699. DOI: 10.5194/gmd-4-677-2011. Tiles with their own
  state and separate exchange.
