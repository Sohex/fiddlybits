+++
id = "REQ-ATM-007"
title = "Dust emission carries a drag partition over roughness measured per surface class, with the sub-grid wind as a declared closure and the emission bracket reported with the partition's validity"
old_path = ["/home/cfutro/docs/world/notes/audits/dust-intensity-levers.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's offline dust component (Kok emission with a
Shao-Lu threshold and a drag partition over a per-lithology roughness mosaic) on
a planet whose erodible substrate was closed-basin fill and evaporite crust.

- Two published cautions about roughness tabulation did not transfer, for
  structural reasons. Collapsing a within-class roughness distribution to a
  point biased emission LOW, by 1.02 to 1.40 depending on the measured spread,
  not high (section 1). A level bracket on one roughness map was an intensity
  lever, not a spatial one: the emission pattern correlated at 0.96 to 0.995
  across a factor of 10.6 in total (section 2). Soil texture could not be the
  intensity lever because the clay fraction sat at its declared cap over 87 per
  cent of the emission (section 3).
- One class's roughness bracket was worth the whole emission bracket (10.4 of
  10.5) through its erodible weight. Re-sourcing it was done under six criteria
  fixed before any measured value was read, including a prediction that could
  fail (the mixture-derived rough end must exceed 1e-4 m) and the rule that
  whatever the mix does to the bracket is adopted. The prediction held at
  8e-4 m; both ends of the old bracket sat below every aerodynamic measurement
  of the surfaces the class was made of; the class ordering flipped.
- The z0 bracket narrowed from a factor of 10 to 8 and the emission bracket
  widened from 10.5 to 1143, because the drag-partition efficiency fell from
  0.53 to 0.24 and the emission integrates a cubic above a threshold that goes as
  1/efficiency over a Weibull tail: the class had moved into a steeper part of
  the scheme. The approximation's own validity (within 20 per cent above an
  efficiency of 0.2) was checked before the number was quoted, and the next
  narrowing was identified as the wind tail, not the roughness.
- Terrain geometry cannot supply an aeolian roughness: the scale gap between
  the mesh and centimetre roughness elements was six orders of magnitude, and
  connected erodible patches were basin-fill provinces, not playas (section 5).
- Using a drag partition at all was worth factors of 2.7 to 64 on this surface
  against a published Earth range of 2 to 3 (section 7). A scalar in-model
  roughness equal to the mosaic's erodible-area-weighted geometric mean
  reproduced the per-cell arm to 0.997 (section 6).

## Why it carries

Decision 0018 puts Kok dust emission on bare tiles and decision 0022 carries dust
as an in-line tracer. The physics that transfers is the partition and the
threshold; what does not transfer is any Earth roughness distribution or any
Earth caution about it, because the sign and size of a tabulation bias and the
leverage of a roughness bracket depend on where the surface sits in the
partition's curve. The pre-registered re-sourcing is the method every
`Bracketed` constant is narrowed by (decision 0007): measured endpoints over
named surfaces, a prediction that can fail, and the result adopted whether it
widens or narrows.

## What this system must do

1. Emission per bare tile follows the Kok scaling with a threshold friction
   velocity from Shao-Lu at the tile's gravity and air density, and a drag
   partition over the tile's aerodynamic roughness (decision 0018). What the Kok
   formulation can carry is gravity and air density through its explicit prefactor
   and through the threshold; what it cannot carry is inside its fit: the
   coefficients were fitted on one planet's soils and its standardised threshold
   normalises the tile's threshold to that planet's reference air density and a
   reference threshold. Those two normalisers are `EarthRatios` denominators
   (REQ-SYS-101), never physical constants; the fit coefficients are `Bracketed`
   (mechanisms: loose sand at the low end, crusted soil at the high end) with that
   provenance and swept; the Shao and Lu (2000) threshold law is the one decision
   0018 names, its coefficient `Sourced` and its interparticle cohesion term
   `Bracketed` between the loose-sand and the crusted-soil ends, because it was
   measured for one planet's minerals and humidity.
2. Roughness is declared per surface class, each value `Sourced` from an
   aerodynamic (wind-profile) determination over a named surface with its
   method; a modelling convention or an order-of-magnitude step is not a source.
   A class that is a mixture of surfaces combines them by the erodible-area-
   weighted geometric mean in ln z0, with the mixing weights from the terrain's
   own composition statement (decision 0015).
3. The sub-grid wind distribution feeding the cubic is a `Closure` with a
   declared shape parameter swept (REQ-SYS-104); the clay fraction comes from the
   pedology component with its cap declared (decision 0022).
4. The emission bracket over every `Bracketed` input is reported with the
   partition approximation's validity range checked at each bracket end, and
   the input carrying most of the bracket is named.
5. No geometric proxy from the terrain mesh stands in for aeolian roughness.
6. Earth oracle: global dust emission and burden inside the AeroCom compilation
   range as REPORT rows (decision 0025).

## Enforced by

- Decisions 0018, 0022, 0007 (`Sourced` requires site and method; `Closure`
  requires a scaling law).
- The oracle registry rows for dust (decision 0026) and the M10 gate "dust in
  compilation range" (decision 0034).
- The registry's pre-registration rule (decision 0025): a re-sourcing declares
  its prediction before the source is read.

## References

- Kok, J. F., Mahowald, N. M., Fratini, G., Gillies, J. A., Ishizuka, M., Leys,
  J. F., Mikami, M., Park, M.-S., Park, S.-U., Van Pelt, R. S., Zobeck, T. M.
  (2014). *An improved dust emission model - Part 1: Model description and
  comparison against measurements.* Atmos. Chem. Phys. 14, 13023-13041.
  DOI: 10.5194/acp-14-13023-2014.
- Shao, Y., Lu, H. (2000). *A simple expression for wind erosion threshold
  friction velocity.* J. Geophys. Res. 105(D17), 22437-22443.
  DOI: 10.1029/2000JD900304.
- Marticorena, B., Bergametti, G. (1995). *Modeling the atmospheric dust cycle:
  1. Design of a soil-derived dust emission scheme.* J. Geophys. Res. 100(D8),
  16415-16430. DOI: 10.1029/95JD00690. The drag partition.
- Greeley, R., Blumberg, D. G., McHone, J. F., Dobrovolskis, A., Iversen, J. D.,
  Lancaster, N., Rasmussen, K. R., Wall, S. D., White, B. R. (1997).
  *Applications of spaceborne radar laboratory data to the study of aeolian
  processes.* J. Geophys. Res. Planets 102(E5), 10971-10983.
  DOI: 10.1029/97JE00518. Table 2, aerodynamic roughness over named playa, fan
  and interdune surfaces.
- MacKinnon, D. J., Clow, G. D., Tigges, R. K., Reynolds, R. L., Chavez, P. S.
  (2004). *Comparison of aerodynamically and model-derived roughness lengths
  (z0) over diverse surfaces, central Mojave Desert, California, USA.*
  Geomorphology 63(1-2), 103-113. DOI: 10.1016/j.geomorph.2004.03.009.
- Menut, L., Perez, C., Haustein, K., Bessagnet, B., Prigent, C., Alfaro, S.
  (2013). *Impact of surface roughness and soil texture on mineral dust emission
  fluxes modeling.* J. Geophys. Res. Atmos. 118(12), 6505-6520.
  DOI: 10.1002/jgrd.50313. The cautions tested and found not to transfer.
- Prigent, C., Tegen, I., Aires, F., Marticorena, B., Zribi, M. (2005).
  *Estimation of the aerodynamic roughness length in arid and semi-arid regions
  over the globe with the ERS scatterometer.* J. Geophys. Res. 110, D09205.
  DOI: 10.1029/2004JD005370. The within-box spread the tabulation bias was
  measured from.

## Amendments

- 2026-09-08: stated what the Kok scaling can and cannot carry, made its normalisers EarthRatios denominators and its fit coefficients Bracketed, and dispositioned the Shao-Lu terms (audit row 7), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: both ends named for the Kok fit coefficients and the cohesion term; the threshold law named as the one decision 0018 names, from notes/findings/2026-09-08-implicit-earth-audit.md
