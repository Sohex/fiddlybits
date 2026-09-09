+++
id = "REQ-OCN-007"
title = "Coupling class, circulation formulation and ecosystem tier are three separable decisions, and a marine ecosystem reaches climate through a named set of pathways each with one owner"
old_path = ["/home/cfutro/docs/world/notes/audits/ocean-and-marine-biosphere.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's ocean audit found that the question "go beyond a slab, and
with which ecosystem model" conflated three separable halves that the candidate
model names ran together: the coupling class (how fluxes cross and who owns
the transport partition), the circulation host (what solves the ocean), and
the ecosystem tier (fixed functional types against an emergent trait-based
community). It priced four pathways by which a modelled marine ecosystem can
reach the climate, measured against the predecessor's bootstrap climatology:
(5a) pigment darkening of the water-leaving reflectance, 0.014 to 0.28 K on
that configuration, a declared and unsourced span, discounted by 0.712 for the
K star's smaller band-1 share; (5b) pigment heating of the mixed layer through
shortwave penetration, structurally absent in a slab that deposits all
shortwave in its top layer, and not fixed by adding layers; (5c) biogenic
sulfur to cloud droplets, needing an aerosol-cloud term that did not exist;
(5d) ocean carbon, 0.18 to 1.59 K per 50 to 200 ppmv of repartitioning, a
first-order control only when pCO2 is prognostic. It concluded the ecosystem is
a leaf of the pipeline until carbon is prognostic, while ocean physics sits
inside the climate loop because a heat transport moves the global mean. When
the resolved circulation tier was dropped, "connectivity now rides entirely on
resolution", which made the strait and sill inventory load-bearing (8b, 9d).
Section 8c: an external ocean model does not escape the implicit-Earth audit,
and latitude is valid for geometry and Coriolis but not as a water-mass,
productivity or regime classifier; 8g found a shelf lithology classifier keyed
on |lat| < 30 degrees in the terrain generator. Section 8d: "reached the ocean"
is a boundary condition and not marine nutrition; marine CH4 and N2O are named
sources to the shared atmospheric trace-gas ledger, never an independent
setting of an atmospheric abundance; the no-carve and all-carve river delivery
values are boundary brackets, not productivity endmembers.

## Why it carries

A generic builder answers the three questions separately because they fail in
different ways (tuning of a partition, Earth-fitted skill of a host, Earth
taxa in a tier), and because a declared absence at any one of them still
needs its interface (the first founding principle of Part F). The pathways
from marine biology to climate are physical and identical on any planet with
an ocean and a star: surface optics, subsurface heating, aerosol precursors,
and carbon. Each must be present with one owner or a declared absence with the
interface in place and its leverage bracketed. Latitude as a classifier is the
Earth-normative coupling in its purest form.

## What this system must do

- The ocean subsystem's decision records answer three questions separately:
  the coupling class (synchronous, A5 and B3), the circulation formulation
  (B3), and the ecosystem tier (trait-based, REQ-OCN-008). Any one may be a
  declared absence; its `Exchange` fields exist regardless.
- The four climate pathways are each a declared field with one owner:
  water-leaving reflectance per band (ecosystem writes; B2's surface albedo
  reads; REQ-OCN-012); the shortwave attenuation profile (ecosystem writes;
  the ocean column reads; B2's shortwave is deposited at depth, not in the top
  layer); marine aerosol precursor emissions (ecosystem writes; B2's
  activation reads); DIC, alkalinity and the air-sea CO2 flux (the carbonate
  system writes; B8's carbon balance reads), the flux using B3's transfer
  velocity in the water-side friction velocity and the Schmidt number, never a
  wind-speed law at a reference height, and B3's equilibria under the
  composition fence of REQ-OCN-003. Until a pathway is built it is a declared
  absence with the field present and its expected leverage bracketed in the
  error budget.
- No classifier in the ocean or the marine biosphere keys on latitude,
  hemisphere or a named basin; water masses, productivity regimes and
  shelf classes are derived from state (temperature, light, nutrients,
  carbonate saturation, connectivity, terrigenous supply).
- Riverine delivery of water, solutes and sediment is a boundary condition
  from B5 with its own ledger at the coast; the marine budget begins there and
  closes internally; every marine trace-gas source is a named term of the
  shared atmospheric ledger.

## Enforced by

- B3, B7 and B10 decision records; decision 0002's scope fence for what is a
  declared absence.
- A5 `assemble`: every declared exchange field has a writer or a declared
  absence.
- Lint: no latitude, hemisphere or basin-name symbol in ocean or marine
  biosphere physics modules outside geometry and Coriolis.
- C5 failure-modes review row for latitude-as-classifier.
- The error-budget register: every declared absence carries a bracketed
  leverage, reviewed at each milestone.

## References

- Follows, M. J., Dutkiewicz, S., Grant, S. and Chisholm, S. W. (2007).
  "Emergent Biogeography of Microbial Communities in a Model Ocean". Science
  315, 1843-1846. DOI: 10.1126/science.1138544.
- Morel, A. and Antoine, D. (1994). "Heating Rate within the Upper Ocean in
  Relation to its Bio-optical State". Journal of Physical Oceanography 24,
  1652-1665. DOI: to confirm. (The subsurface heating pathway.)
- Charlson, R. J., Lovelock, J. E., Andreae, M. O. and Warren, S. G. (1987).
  "Oceanic phytoplankton, atmospheric sulphur, cloud albedo and climate".
  Nature 326, 655-661. DOI: 10.1038/326655a0. (The aerosol precursor pathway.)
- Sarmiento, J. L. and Gruber, N. (2006). "Ocean Biogeochemical Dynamics".
  Princeton University Press. ISBN: to confirm. (The carbon pathway and the
  marine element budgets.)

## Amendments

- 2026-09-08: the air-sea CO2 flux pathway named as using B3's friction-velocity transfer law and composition-fenced equilibria (rows 2, 3), from notes/findings/2026-09-08-implicit-earth-audit.md
