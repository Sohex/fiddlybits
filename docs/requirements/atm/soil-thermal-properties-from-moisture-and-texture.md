+++
id = "REQ-ATM-009"
title = "Soil thermal conductivity and heat capacity are functions of the column's own water content, texture and bulk density, computed at call time from one relation"
old_path = ["/home/cfutro/git/vesper/notes/audits/soil-thermal-inertia.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's land column, whose soil heat solver carried one
conductivity (1.8 W/m/K) and one volumetric heat capacity (2.4e6 J/m3/K) for
every non-glaciated cell, a moist mineral soil with a thermal inertia of 2078
J/m2/K/s^0.5.

- Johansen's interpolation, read from the monograph rather than a restatement:
  dry conductivity is a function of bulk density and nothing else; mineralogy
  enters only through the saturated conductivity, multiplied by a Kersten number
  that is zero when dry. Sweeping saturation moved thermal inertia by a factor
  of 4.9; bulk density at the dry end by 1.61; mineralogy at saturation by 1.36
  (1.23 on a coarse column, because the monograph's coarse low-quartz branch
  raises the other-minerals conductivity); mineralogy at the dry end by exactly
  1.00 ("The measurement").
- The recorded finding, that barren classes were damped 3.3 times too much and
  the fix was a per-cell lithology field, was right about the magnitude and
  wrong about the attribution: those surfaces were over-damped because they
  were dry, and a lithology field would have written a uniform value over
  exactly the cells it was specified for. Reading the source overturned the
  deliverable; the one branch a restatement had lost moved the term down.
- The moisture dependence needed no new field: the column already carried its
  water prognostically and the heat solver did not read it. What blocked it was
  a declaration, the mapping from a plant-available bucket store to a degree of
  pore saturation, which needs a porosity and a retention relation that belong to
  the land-column property contract. The dry surfaces sat below the wilting
  point and needed a thin surface layer that could dry below it, a change to the
  column rather than to a constant (`model-earth-centrism.md` finding 14).
- The method's own validity floor (saturation above 0.1) was reported beside the
  answer, and the dry-end value was labelled qualitatively right and
  quantitatively outside the method's claim.

## Why it carries

Decision 0018 gives the land column Richards soil water, soil heat with phase
change and per-tile texture from pedology (decision 0022), so every input the
relation needs is state or a declared property, and the relation can be
evaluated at call time (design idea 5). The lesson generalises to every material
property: the dominant term is found by sweeping the terms of the published
relation, not assumed from the label a finding was filed under, and the source
is read rather than a restatement of it (decision 0003, fourth principle).

## What this system must do

1. Per soil layer, conductivity and volumetric heat capacity are functions of
   the layer's volumetric water and ice content, porosity, bulk density, quartz
   fraction and organic fraction, through Johansen's interpolation with the
   texture-branched Kersten number and the organic blending, evaluated at every
   call from the Richards state (decision 0018).
2. Porosity, bulk density, texture and quartz fraction come from the pedology
   component per tile (decision 0022); no soil thermal constant is declared in the
   atmosphere or land-column parameter structs.
3. Phase change is in the soil heat solver (decision 0018) and the latent term
   uses the same water content the conductivity reads.
4. The relation is one function shared by every consumer of soil temperature
   (climate column, vegetation, permafrost diagnostics), and its validity floor is
   evaluated: a layer below it is flagged in the ledger rather than silently
   extrapolated.
5. Oracles: the diurnal and seasonal damping depths against the analytic
   solution for a homogeneous column, with the forcing periods read from the
   system's solar-day and orbital-period functions (decision 0008) and the oracle
   run at two declared rotation periods and two orbital periods so a hard-coded
   day or year in the harness is caught; the Stefan problem for freezing;
   site-level soil temperature amplitude on the Earth instance as REPORT rows
   (decisions 0026, 0034).

## Enforced by

- Decision 0018 (one land column, computed from state), decision 0022
  (pedology supplies texture), decision 0009 (one owner for soil properties).
- The analytic oracles of decision 0026 and the M5 site benchmarks (decision
  0034).
- The disposition check of decision 0007: a soil thermal number that is not
  `Derived` from state does not construct.

## References

- Farouki, O. T. (1981). *Thermal Properties of Soils.* CRREL Monograph 81-1.
  DOI: 10.21236/ada111734. Section 7.11 and Table 24: Johansen's method, the
  dry-conductivity relation in bulk density, the texture-branched Kersten number
  and the coarse low-quartz branch.
- Lawrence, D. M., Slater, A. G. (2008). *Incorporating organic soil into a global
  climate model.* Clim. Dyn. 30, 145-160. DOI: 10.1007/s00382-007-0278-1. The
  organic-fraction blending of the same relation.
- Lawrence, D. M., et al. (2019). *The Community Land Model Version 5:
  Description of New Features, Benchmarking, and Impact of Forcing Uncertainty.*
  J. Adv. Model. Earth Syst. 11(12), 4245-4287. DOI: 10.1029/2018MS001583 (to
  confirm). The column structure decision 0018 models on.

## Amendments

- 2026-09-08: made the damping-depth oracles read their periods from the system and run at two rotation and two orbital periods (audit row 20), from notes/findings/2026-09-08-implicit-earth-audit.md
