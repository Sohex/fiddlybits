+++
id = "REQ-TER-005"
title = "Every conversion inventories what it lost, and a fallback is a counted event rather than a silent branch"
old_path = ["/home/cfutro/git/vesper/config/spatial_conversion.yaml"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's conversion envelope required five inventories of every
crossing: nearest fallbacks, ownership changes, connectivity changes,
discarded spectral content, unmapped extensive stores. Each was learned from a
loss that had been invisible. Measured on the predecessor's
`canonical-10m-carve2` build, past T85 the ten-million-region mesh stopped
covering every Gaussian cell and the reduction fell back to the nearest region
centre, a point sample of a categorical field, on 32 cells at T127 and 365 at
T170: a finer grid was not a free route out of the coastline rounding, because
past a certain level the reduction starts substituting for the mesh.
`lib/remap.py` separated the two orphan cases and treated them differently:
a destination cell with no valid source is an error (a mask disagreement, not
sparse coverage), because backfilling it from the nearest source would put an
invented flux into an ocean cell that integrates it for ten thousand years; a
valid source with no valid destination moves to the nearest valid destination
by great-circle distance, and the ledger records how much area moved and how
far the furthest went; an intensive state in an orphaned cell has nothing to
conserve and is dropped and counted. The land mosaic's groundwater-fed tile did
not exist and was refused by name rather than defaulted. The basin catalogue
had two floors, a physical area floor and a numerical cell-count floor, and the
manifest published which one bound, because a statement about which floor
governs is a statement about a build.

## Why it carries

Design idea 13: refuse rather than snap, interpolate or backfill. Exact nesting
removes the between-model orphan case, but refinement boundaries, tiles,
external data placed on the hierarchy, connectivity graph updates and NetCDF
export all lose something, and the loss is only safe when it is visible in the
artifact and counted. A fallback that runs silently is a source term nobody
declared.

## What this system must do

- Every operator returns an inventory beside its ledger: the count and area of
  nearest fallbacks (refused by default; enabled only by a named policy on the
  operator), the cells whose owner changed, the connectivity-graph edges that
  changed (a strait closed, a basin merged, a land bridge flooded; decision F1
  makes these events), the content discarded (sub-grid variance dropped when a
  distribution is collapsed to a mean; spectral modes dropped at a filter),
  and every extensive store with no destination.
- An absent input is a declared absence by name with its interface complete
  (founding principle 1), never a default value.
- Every derived catalogue's manifest names its physical floor, its numerical
  floor, and which one bound.
- An artifact whose inventory is missing does not enter the store.

## Enforced by

- A2 operator return type; A5 `assemble` checks; A6 store refusal.
- Part E tripwire: a declared feature (strait, island, isthmus) absent from a
  coarse-level artifact blocks.
- F1: a change in connectivity-graph topology is an event that forces a
  climate refresh, so the inventory is read, not only written.

## References

- Jones, P. W. (1999). "First- and Second-Order Conservative Remapping Schemes
  for Grids in Spherical Coordinates". Monthly Weather Review 127, 2204-2210.
  DOI: 10.1175/1520-0493(1999)127<2204:FASOCR>2.0.CO;2. Coverage as a
  first-class output of a crossing.
- Barnes, R., Callaghan, K. L., Wickert, A. D. (2020). "Computing water flow
  through complex landscapes - Part 2: Finding hierarchies in depressions and
  morphological segmentations". Earth Surface Dynamics 8, 431-445.
  DOI: 10.5194/esurf-8-431-2020. What a depression floor selects and what
  merging means.
