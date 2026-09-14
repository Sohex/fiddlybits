+++
id = "REQ-TER-001"
title = "A field's semantics is a property of the field, declared once and required at every reduction, never defaulted"
old_path = ["/home/cfutro/git/vesper/lib/remap.py"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's crossing library (`lib/remap.py`) carried three scalar
semantics and a vector one, each a different normalisation of the same
intersection-area weight matrix: an extensive total divides by the source area so
the global sum is preserved; a flux density divides by the destination area so
the integral is preserved, and a field of ones does not remap to ones, so the
coverage travels with the result; an intensive state divides by the covered area
so ones remap to ones and an uncovered destination contributes nothing rather
than a zero. The docstring records why the semantics was made a required
argument out of a closed set rather than a default: a temperature and a heat
flux are both float64 arrays, so routing an extensive quantity through the
intensive normalisation is undetectable by the operator, and the contract that
names each field's semantics lived outside the operator module.
`config/spatial_support.yaml` widened that to eight field semantics
(intensive_state, extensive_total, flux_density, categorical_label,
categorical_fraction, dimensionless_fraction, vector_component,
distribution_quantiles) and twelve aggregation operators, and mapped every term
to the reductions in `lib/gridding.py` so that a reduction added to the module
failed a gate until the vocabulary could name it.

The cost of lacking it was measured on the mesh-to-grid side. `lib/gridding.py`
records that a categorical field sampled by the region containing the cell
centre threw away the coastline at coarse truncation (a T21 cell holding about
1,200 mesh regions), and that a continuous field averaged over every region in
a cell dragged a coastal cell's rock albedo toward open water's 0.06 and its
elevation toward the seabed. Measured on the predecessor's offline ocean
crossing, a climatology passed through a non-conserving weight matrix into an
ocean integrated for of order ten thousand model years is a permanent,
spatially structured source term with unlimited time to express itself, not a
transient interpolation error.

## Why it carries

Any builder that moves quantities between supports faces the same fact: the
array type does not carry what the number means, and every normalisation is
correct for one meaning and wrong for the others. Whether a reduction preserves
a sum, an integral, a value, a histogram or a distribution is a property of the
physical quantity, decided before the first operator runs. The one-mesh design
(decision A1) removes the between-model crossing but keeps coarsen, refine,
time-reduce, tile-to-column and export operations, and each of them needs the
semantics as much as the old crossing did.

## What this system must do

- Every field carries its semantics as a type parameter (`Field{S,T,D,L,A}`,
  decision A2): extensive total, intensive state, flux density, categorical
  label, categorical fraction, dimensionless fraction, vector component in a
  named basis, or distribution quantiles.
- `coarsen`, `refine`, `time_reduce` and every crossing dispatch on the
  semantics. An intensive field has no plain `coarsen`; the caller names the
  operator (covered-area mean, expectation under a declared law, quantiles).
- No default semantics exists anywhere in the system. A reduction called
  without one, or with one the field's type refuses, fails the build, not the
  run.
- Vectors change support only in the Cartesian basis: lifted at the source
  cells' frames, remapped as three components, projected at the destination.
  Components are never remapped as independent scalars.
- The operator set is closed; each operator is claimed by exactly one
  vocabulary term, and a new reduction fails the build until the vocabulary
  names it.

## Enforced by

- Type parameters on `Field` (decision A2); a refusal table plus an enumeration
  test over every (semantics, operator) pair so a missing method is a build
  failure; JET in CI.
- Mesh oracles, tier 1 (decision C3): constant-field preservation for intensive
  fields, extensive-integral preservation for extensive and flux-density
  fields, vector round trip, at every level pair and across every refinement
  boundary.
- A lint that refuses any reduction over a spatial or time axis outside the
  operator module.

## References

- Jones, P. W. (1999). "First- and Second-Order Conservative Remapping Schemes
  for Grids in Spherical Coordinates". Monthly Weather Review 127, 2204-2210.
  DOI: 10.1175/1520-0493(1999)127<2204:FASOCR>2.0.CO;2. The intersection-area
  weight and which area it divides by.
- Ringler, T. D., Thuburn, J., Klemp, J. B., Skamarock, W. C. (2010). "A unified
  approach to energy conservation and potential vorticity dynamics for
  arbitrarily-structured C-grids". Journal of Computational Physics 229,
  3065-3090. DOI: 10.1016/j.jcp.2009.12.007. What each primal and dual operator
  conserves on an unstructured sphere.
