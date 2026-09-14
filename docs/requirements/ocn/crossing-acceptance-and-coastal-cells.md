+++
id = "REQ-OCN-010"
title = "A support change that closes every ledger can still conserve against the wrong partition: every operator needs an identity with a known answer and a negative control, coastal cells are placed by rule, and vectors cross only in the Cartesian basis"
old_path = ["/home/cfutro/git/vesper/notes/audits/ocean-grid-crossing.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor built an exact conservative crossing from a Gaussian
atmosphere grid to an equal-area ocean grid (the weight matrix factorised into
two one-dimensional overlaps; closure residual 5.8e-18 relative against a
1e-12 bar) and found that conservation could not catch the failure that
mattered. A crossing built on midpoint-between-node row boundaries conserves
perfectly and quietly against a grid the model does not use; only a field
whose integral is known in advance (3 sin^2(lat) - 1 evaluated at the Gaussian
nodes, exactly zero under the model's own quadrature) discriminated, by seven
orders of magnitude (4.0e-3 against 2.7e-15). The export had shipped two
answers about its own cell areas: a nearest-row binning partition, 22 per cent
wide in the polar row at every resolution, which closed to 4 pi R^2 to the
last bit; a third partition in a weathering script 5.8 per cent wide; a fourth
(cos(lat) weights on Gaussian rows) 1.8 per cent wide in the polar row and
converging to that value rather than to zero. Two hardcoded radii were found
in scripts that agreed with the configuration by coincidence. At the coast, the
two masks could not agree at different supports; the rules adopted were that a
valid destination cell with no valid source is an error, not a backfill, and
that a valid source with no valid destination goes to the nearest valid
destination in the conserving matrix only, with the moved area reported (0.6
to 2.1 per cent of the sphere, up to 12 degrees of arc), while an intensive
orphan is dropped and counted.

The contract the operator was written against
(`cgenie-parallelism-and-coupling-support.md` section 5c) stated five rules:
normalisation is a property of the field (destination area for a total,
covered area for a density); the coverage fraction travels with the result;
an unmapped destination is an error; the closure residual is registered in
advance and stamped in the artifact; source edges come from the model's own
quadrature, never midpoints between centres. `ocean/notes/vector-crossing.md`
measured that remapping a tangent vector as two scalars passes the full-sphere
integral of a rigid rotation to round-off by symmetry (both grids uniform in
longitude, the frame error a phase cancelling around every row) and fails by
four to five orders only over a window that is not zonally symmetric; the
per-cell gap scales with the destination cell's longitude span and not with
latitude; the radial part the destination's tangent plane will not hold is up
to 9.6 per cent of the local speed at the coarsest pair and travels in the
ledger rather than being normalised away.

## Why it carries

A1 removes the atmosphere-ocean grid crossing, so the specific operator is
superseded, but level-to-level coarsening and refinement remain support
changes, the coast remains the place where the atmosphere's column tiling and
the ocean's wet cells meet, and the lesson about acceptance is general:
closure ledgers are necessary and not sufficient; every operator needs an
identity with a right answer the operator cannot see, and a negative control
that must miss the same bar, or the test decorates rather than discriminates.
Cell areas with more than one source are a defect that passes every
conservation check.

## What this system must do

- Every `coarsen` and `refine` operator on the hierarchy (A2) returns
  `(field, ledger)` and is certified by identities with known answers:
  constant-field preservation, extensive-integral preservation, a field whose
  exact integral is known analytically on the mesh (low-order spherical
  harmonics under the mesh's own quadrature), a grid crossed with itself as
  the identity, and a negative control (a deliberately wrong partition) that
  must fail the same bar. The bars are fixed before any operator runs.
- Cell areas and weights have exactly one source, the mesh module; no
  component computes its own areas; a `cos(lat)`, midpoint or nearest-node
  weight in a physics or analysis module is a lint failure.
- At the coast: the atmosphere's surface tiling and the ocean's wet cells are
  derived from the same terrain level, so the land-water partition inside a
  coarse cell is identical on both sides by construction (mosaic tiles, A1). A
  flux into a tile with no receiving water or land is a refusal, never a
  backfill. Any placement rule for a flux that has no destination on its own
  support (river discharge into coastal water, spreading into embayments) is
  a declared operator whose moved mass and displacement travel in the ledger.
- Normalisation is a property of the field's semantics `S` (A2); an
  intensive field has no plain `coarsen` and must name an operator; the
  coverage fraction is part of the result.
- Vector fields change support only in the Cartesian basis (idea 11), with
  the radial residual reported; the certification window for a vector
  operator is not zonally symmetric.

## Enforced by

- A1 and A2 decision records; the refusal table with an enumeration test and
  JET in CI.
- M0 gate: area and nesting identities; constant-field and
  extensive-integral preservation; vector round trips; the wrong-partition
  negative control registered as a must-miss.
- Lint on area and weight expressions outside the mesh module.
- C4 mutation run: a substituted midpoint partition must fail the
  known-integral identity.

## References

- Jones, P. W. (1999). "First- and Second-Order Conservative Remapping
  Schemes for Grids in Spherical Coordinates". Monthly Weather Review 127,
  2204-2210. DOI: to confirm. (Conservative remapping and its normalisation
  options.)
- Ullrich, P. A. and Taylor, M. A. (2015). "Arbitrary-Order Conservative and
  Consistent Remapping and a Theory of Linear Maps: Part I". Monthly Weather
  Review 143, 2419-2440. DOI: 10.1175/MWR-D-14-00343.1. (Consistency and
  conservation as separate properties of a linear map.)
- Williamson, D. L., Drake, J. B., Hack, J. J., Jakob, R. and Swarztrauber,
  P. N. (1992). "A standard test set for numerical approximations to the
  shallow water equations in spherical geometry". Journal of Computational
  Physics 102, 211-224. DOI: 10.1016/S0021-9991(05)80016-6. (Analytic fields
  on the sphere with known integrals.)
