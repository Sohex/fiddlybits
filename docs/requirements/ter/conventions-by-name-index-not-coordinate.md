+++
id = "REQ-TER-010"
title = "A convention travels by name, matching is by index never by coordinate, and there is one geometry source"
old_path = ["/home/cfutro/git/vesper/notes/audits/grid-convention-and-runoff.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's `precarve-craton` build and its baseline
climatology: a coupling matrix's columns were reconciled to a climatology's by
matching longitude labels. The correct mapping was the identity, because the
mask the climate model read back was bit-identical index-for-index (1.0000
agreement) to the one it was handed, and 0.5955 when shifted by 64 of 128
columns. The remap shifted by 64 columns, half a planet. Endorheic catchment
area landing on cells the model called ocean read 1.01 per cent
index-for-index and 49.77 per cent under the remap; 1,172 of 3,621 basins, 32.4
per cent, received a different verdict; lake areas, three albedo fields and the
baseline climatology built on them were contaminated, and the remedy was a
re-run of the whole loop. It was a recurrence: the remap had been the fix for
an earlier antipodal defect, correct while an image path carried a different
convention, and it outlived the thing it corrected; its own sweep missed a
sink lookup that landed 65 columns out; the same defect was introduced three
times, once as its own fix. The check that existed asserted a longitude
variable was present and could not fail (REQ-TER-004). Figures relabelled to
the other convention showed the coast 180 degrees from the maps, the visible
evidence for the false premise that two products sharing a grid disagreed
about longitude.

`lib/nc_geometry.py` records why the fix is a name and not a number: every
derived quantity a reader could check agreed between the two conventions
(column count, width, weight sum, span); only the origin differed, and an
export centre offered as a model label landed exactly half a column out, which
matches every cell half a planet away instead of matching none. So the
declaration carried the convention by name, the reader reconstructed the axis
from the named convention and refused a file whose axis was not it, at a
tolerance four orders tighter than the half-column ambiguity it existed to
catch. The same document records two more frame traps: the mesh's Cartesian
coordinates were y-up, and assuming z-up rotated the planet 90 degrees; an ice
mask was matched by region index with the seed and region count in a sidecar
and refused on mismatch, "never match this by coordinate". And: "share one
coordinate source and never reconstruct one", after three scripts on three
occasions silently matched zero cells.

## Why it carries

Design idea 7. One mesh (decision A1) makes the between-model seam
unrepresentable, and the cubed sphere was rejected partly because panel seams
are this class. But the class returns at every boundary with the outside:
NetCDF export, external DEMs and lake databases, a reference dynamical-core
arm, and the 0-based disk versus 1-based memory index boundary (decision F7). A
translation layer is worse than the defect because it implies there is
something to translate; a correction to a convention is itself a convention
and must die with its cause.

## What this system must do

- Indices cross the disk boundary inside a `CellId` type that refuses
  arithmetic (F7), so a mixed-base defect is a type error.
- Matching between two arrays on one support is by index, asserted by equal
  support identity (REQ-TER-002); no operator matches by coordinate.
- Exactly one geometry constructor exists; no second expression of a
  coordinate, column, row or frame appears anywhere (lint).
- A NetCDF export declares its convention by name (longitude origin, axis-up,
  datum, radius) and the reader reconstructs the axis from the name and refuses
  a file that does not match it within a tolerance derived from the storage
  precision, orders tighter than the smallest ambiguity between conventions.
- External data are placed on the hierarchy by one operator that records the
  frame it assumed (axis-up, longitude origin, vertical datum) in the artifact.
- A check on any crossing has a right answer with a physical bound (catchment
  area on ocean cells bounded by coastal rounding), not a presence test.
- A fix that corrects a convention names the cause it corrects and is removed
  by the change that removes the cause.

## Enforced by

- F7 `CellId`; A6 store refusal on missing support identity.
- The declared-geometry export and refusing reader; import review for the
  NetCDF dependency.
- Lint: coordinate arithmetic outside the mesh module is refused.
- Oracle: a field written to NetCDF and read back matches by index bitwise;
  a file with a deliberately shifted axis is refused.

## References

- Eaton, B. et al. "NetCDF Climate and Forecast (CF) Metadata Conventions".
  Locator: https://cfconventions.org. DOI: to confirm. The declared vocabulary
  for axes, bounds and CRS an export must carry.
- Hortal, M., Simmons, A. J. (1991). "Use of Reduced Gaussian Grids in Spectral
  Models". Monthly Weather Review 119, 1057-1074.
  DOI: 10.1175/1520-0493(1991)119<1057:UORGGI>2.0.CO;2. Why two grids that
  agree on every derived number can still be two conventions.
