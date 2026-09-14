+++
id = "REQ-PED-002"
title = "A law convex in a lithology property is evaluated per rock and then averaged; mixing the rocks first is a different and biased answer"
old_path = ["/home/cfutro/git/vesper/pedology/README.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's regolith law is convex in erodibility, and erodibility spans a
factor of fourteen across the terrain export's lithology table. Its README states the
rule it settled on: "The law is applied to EACH ROCK a cell holds and the depths are
then averaged ... mixing a cell's rocks into one erodibility first is a different and
always thinner answer", with the difference between the two orders carried in the soil
report on every map built. The same order-of-operations fact appeared three more
times in the same component. Weathering intensity goes as runoff to the 0.65, so on a
land whose runoff mean was 130 mm/yr against a median of 3.8 (two thirds of land under
50 mm/yr, measured 2026-08-17 on the predecessor's generated world) the mean of the
intensity was 0.380 while the intensity of the mean climate was 0.572; the one that
feeds solute fluxes is the mean of the law. The chemical divide (REQ-PED-008) was
weighted per catchment cell before the nonlinear branching was applied, and its check
is that a basin draining one rock class returns that class's own row (worst error
1.2e-15 over 108 basins). A convex consumer of soil pH, `exp(2 (pH - 10))`, handed one
pH per cell understated its land mean by 8.7% relative to resolving the salt crust
inside the cell. Permeability classes are log-normal, and the class statistic that
transfers is the geometric mean (Gleeson et al. 2011), not an arithmetic mean of `k`.

## Why it carries

This is Jensen's inequality applied at a reduction, which is what A2's field
semantics exist to make explicit: a categorical field such as lithology reduces only by
fraction, and a quantity derived from it by a nonlinear law has no plain coarsen. A1's
exact nesting makes the fine-level distribution inside every coarse cell available at
no cost, so the correct order is always possible. The rule is planet-independent and
applies to every lithology-keyed law in B8 (regolith, weathering, permeability,
phosphorus, brine chemistry, albedo spectra per surface class) and to every consumer
that is convex in a soil property.

## What this system must do

- A function of lithology is evaluated at the finest level where lithology is a single
  class (the terrain level's cell, or a stratigraphy layer within it) and reduced to
  the consumer's level by the declared operator; a kernel taking a lithology argument
  dispatches on the single-class type and cannot receive a mixture.
- A categorical field's only `coarsen` is a fraction vector; evaluating a law on a
  coarsened categorical field is a type error caught by the A2 refusal table.
- Where a reduction must precede a nonlinear law for cost, the Jensen error is computed
  from the exact fine distribution and reported against the effect, under the same
  admissibility test as REQ-HYD-005; a class statistic (geometric mean for a log-normal
  class) is declared with the class.
- A single-lithology identity (the reduction of a constant is that constant, to
  floating-point tolerance) runs per commit for every lithology-keyed reduction.
- Land means of skewed fields are reported beside their quantiles, and the report names
  which of "mean of the law" and "law of the mean" each downstream flux consumed.

## Enforced by

A2 `Field` refusal table with JET in CI; the single-lithology identity test; C4
mutation run (swapping the order must move the regolith oracle); the soil artifact's
aggregation block.

## References

- Sur les fonctions convexes et les inegalites entre les valeurs moyennes. Jensen
  (1906), Acta Mathematica 30, 175-193. DOI: 10.1007/BF02418571
- Mapping permeability over the surface of the Earth. Gleeson et al. (2011),
  Geophysical Research Letters 38, L02401. DOI: 10.1029/2010GL045565
