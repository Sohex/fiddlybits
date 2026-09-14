+++
id = "REQ-BIO-008"
title = "Plant water potentials are stored as pressures and converted to head only with the system's gravity; hydraulic and mechanical height ceilings are derived from traits and gravity as a coupled prior; root depth, regolith depth and groundwater access are three quantities with one water debit"
old_path = ["/home/cfutro/git/vesper/biosphere/notes/plant-hydraulics-groundwater-audit.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Gravity enters plant water relations twice and Earth models hide both entries
(measured on the old world's port at 1.306 Earth gravity, on ClimaLand and on
FATES, at the archived commit and in
/home/cfutro/git/vesper/notes/external-model-survey.md sections 41 and 54):

- A published xylem vulnerability parameter of -4 MPa was stored as
  -408.16 m of head, computed as -4 / 0.0098, which is rho g / 1e6 at EARTH
  gravity; the use site converted back with the model's own gravity. A port
  that moves gravity and carries the stored head forward makes the error
  twice, presenting -5.22 MPa where the literature says -4. Any plant
  hydraulics parameter published as a pressure and stored as a head carries
  the gravity of whoever stored it, and nothing in the stored value says so.
- The two height ceilings scale differently: hydraulic,
  h_max = |psi_crit| / (rho_w g), as g^-1 (0.766 of Earth at 1.306 g);
  mechanical, Greenhill self-loaded buckling
  H proportional to (E / (rho g))^(1/3) d^(2/3), as g^-1/3 (0.915 of Earth).
  The hydraulic ceiling tightens two and a half times faster with gravity, so a
  configuration at higher gravity moves the binding constraint toward
  hydraulics; on Earth either can bind. Both figures assume unchanged material
  properties, and the hydraulic one is a ceiling on the gravitational component
  of tension alone, lowered by path resistance in both cases.
- Holding height fixed at 1.306 g requires about 1.143 times the diameter and
  1.306 times the stem cross-section, so the same canopy height costs roughly
  31 percent more stem structure before crown, branch, anchorage or safety
  factor respond; once diameter scales as height to the 1.5 power, structural
  biomass scales about as height to the fourth power (King 2005), so changing
  only a maximum-height constant misses the main carbon effect. The active
  model imposed an Earth height-diameter relation with a 0.67 exponent and a
  hard-coded 150 m cutoff independent of gravity and hydraulic state.
- In FATES the gravitational head of the plant water column appears with
  Earth's 9.8 hard-coded; at 12.81 m/s2 that term rises 30.7 percent and
  raises hydraulic-failure mortality, capping height through a mortality
  term rather than an allometric limit: the same ceiling arriving in an
  independent model by a different route.
- Root depth, regolith depth and groundwater access were three different
  quantities collapsed into one: an Earth-biome root profile (Jackson et al.
  1996) truncated at 1.5 m with all residual mass placed in the bottom layer,
  water capacity scaled by regolith depth with sub-bedrock capacity forced
  into soil-texture layers, and no lower hydraulic boundary; the groundwater
  solver already removed a bulk evapotranspiration sink, so giving the
  vegetation an additional groundwater supply would spend the same water
  twice. Deep water moved only on days with rain, preserving an artificial
  dry-season reservoir capable of supporting evergreens for the wrong reason
  (the LPJ-GUESS-RE finding).
- Height, vulnerability and conductance form a coupled trait prior; importing
  each independently creates hydraulic strategies no organism exhibits.

## Why it carries

Gravity is a free parameter of the system (A0) and enters plant form and
water transport through two different powers, so neither an Earth allometry
coefficient nor an Earth head can be carried as a number. The one land column
(B4) owns soil water by layer and a per-tile aquifer store, and A5 gives every
quantity one writer, so the double-debit the old architecture invited is
unrepresentable only if the vegetation's water demand is fulfilled by the
column and never withdrawn by the vegetation itself. The dimension-on-the-type
design (A2) is what turns the head-versus-pressure trap into a type error.

## What this system must do

1. Every plant water potential in the trait registry is stored as a pressure
   (Pa) and carries that dimension on its type; conversion to head happens at
   the use site with `System.g`. A trait entry declared in metres of head is
   refused.
2. Height ceilings are derived, not declared: the hydraulic ceiling from
   psi_crit, rho_w, g and the path resistance of the strategy's conductance
   traits; the mechanical ceiling from the buckling relation with wood
   elastic modulus and wet density as traits (both `Bracketed` on published
   wood property ranges) and a `Bracketed` safety factor. The height-diameter
   allometry coefficient is derived from the same relation at the system's
   gravity; no hard height cutoff exists. Height, vulnerability, conductance
   and wood density are sampled as a coupled prior in the strategy space
   (REQ-BIO-006).
3. Hydraulic-failure mortality is a declared model form alongside
   carbon-starvation mortality, with the mapping from conductance loss to
   mortality `Bracketed`; drought is a continuum of plant water potential, not
   a supply-demand scalar.
4. Root profile is a strategy trait (rooting depth and shape) truncated by the
   tile's regolith depth from B1 and B8, with the truncated residual accounted
   for and never dumped into the deepest layer; weathered-bedrock storage is a
   layer of the column with its own properties, not extra capacity in a soil
   layer.
5. Water uptake is by soil layer against the column's resolved water potential
   and from the tile aquifer store where the root profile reaches it (B4); the
   vegetation returns demand per layer and receives fulfilled uptake per
   source from the column, which debits each store once (REQ-BIO-019). Deep
   drainage and capillary flow run every step, not only on wet days. The soil
   artifact's reference wilting pressure (REQ-PED-007) is a labelled
   convention for reporting plant-available water; uptake limits and
   hydraulic-failure mortality read the strategy's own critical potential.
6. Extra structural carbon from gravity-aware allometry propagates through
   construction and maintenance respiration, litter, fuel and light
   competition (REQ-BIO-007), never as a uniform multiplier on metabolism.

## Enforced by

- Type: `Dim` on `Field` and trait entries distinguishes Pa from m (A2);
  `EarthRatios` forbids physical use of Earth's g.
- Oracle: the Greenhill and hydraulic ceilings against their analytic forms at
  two gravities (C3 analytic tier); the gravity-invariance test: identical
  traits at two g with path resistance set to zero produce ceilings in the
  derived ratios g^-1 and g^-1/3, and the full ceilings with path resistance
  are reported beside them.
- Ledger: water uptake against the land column's layer and aquifer stores
  closes at every step (A5 exchange).
- Decision records for B4 and B7.

## References

- McMahon, T. (1973). Size and Shape in Biology. Science 179, 1201-1204.
  DOI: 10.1126/science.179.4079.1201. Elastic similarity and self-weight
  buckling.
- King, D. A. (2005). Linking tree form, allocation and growth with an
  allometrically explicit model. Ecological Modelling 185, 77-91.
  DOI: to confirm. The allocation consequence of a buckling constraint.
- Koch, G. W., Sillett, S. C., Jennings, G. M. and Davis, S. D. (2004). The
  limits to tree height. Nature 428, 851-854. DOI: 10.1038/nature02417. The
  hydraulic ceiling measured.
- Givnish, T. J., Wong, S. C., Stuart-Williams, H., Holloway-Phillips, M. and
  Farquhar, G. D. (2014). Determinants of maximum tree height in Eucalyptus
  species along a rainfall gradient in Victoria, Australia. Ecology 95,
  2991-3007. DOI: to confirm. Hydraulic and allocation limits acting together.
- Anderegg, W. R. L. et al. (2016). Meta-analysis reveals that hydraulic
  traits explain cross-species patterns of drought-induced tree mortality
  across the globe. Proceedings of the National Academy of Sciences 113,
  5024-5029. DOI: 10.1073/pnas.1525678113.
- Christoffersen, B. O. et al. (2016). Linking hydraulic traits to tropical
  forest function in a size-structured and trait-driven model (TFS v.1-Hydro).
  Geoscientific Model Development 9, 4227-4255.
  DOI: 10.5194/gmd-9-4227-2016. A trait-driven hydraulics formulation with
  potentials as pressures.
- Bonan, G. B., Williams, M., Fisher, R. A. and Oleson, K. W. (2014). Modeling
  stomatal conductance in the earth system: linking leaf water-use efficiency
  and water transport along the soil-plant-atmosphere continuum. Geoscientific
  Model Development 7, 2193-2222. DOI: 10.5194/gmd-7-2193-2014.
- Jackson, R. B. et al. (1996). A global analysis of root distributions for
  terrestrial biomes. Oecologia 108, 389-411. DOI: 10.1007/BF00333714. The
  Earth root profile that is a `Sourced` envelope, not a planetary constant.
- /home/cfutro/git/vesper/notes/external-model-survey.md sections 41 and 54.

## Amendments

- 2026-09-08: wilting point reconciled with REQ-PED-007 (soil artifact carries
  a labelled reference pressure; uptake uses the strategy's critical
  potential) (audit row 35), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: gravity-invariance oracle stated for the gravitational component
  with the full ceiling reported (audit row 36), from
  notes/findings/2026-09-08-implicit-earth-audit.md
