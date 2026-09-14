+++
id = "REQ-BIO-010"
title = "Soil organic matter stoichiometry ramps are sourced to the figure and to the pool definition they were drawn against, each element's parameters are that element's, every declared pool is fed, transfer fractions close, mineral protection reads the pedology state, and an equilibrium accelerator reproduces the daily operator"
old_path = ["/home/cfutro/git/vesper/notes/audits/lpj-soil-cn-ratios.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

A CENTURY-family soil model carries its stoichiometry as ramps of the
carbon-to-nutrient ratio at which each pool receives carbon, against a
mineral nutrient driver up to a saturation threshold. The predecessor read
every such constant back to its source (measured on the old world's fork of
LPJ-GUESS-CNP at the archived commit, against the Parton papers it holds):

- The model's own documentation attributed four pool ratios to a paper that
  contains no ratio at all (the 2010 ForCent paper carries no stoichiometry;
  its phosphorus counterpart was miscited the same way). The real source,
  Parton et al. (1993) Figure 4(a), ramps three soil pools where the model
  ramped two, and its figure and text disagree at the low ends (active 2.14
  against a stated 3; passive 3.17 against 7); the text's arm was taken
  because the figure's floor lay below the stoichiometry of the material the
  pool stands for. The saturation threshold had been written as
  0.002 * 0.05 with no derivation for the 0.05, which made every ramp inert;
  the 0.002 is the figure's break point and the model's own documentation
  states the same cap for fixation.
- The phosphorus side had been built by copying the nitrogen side. The
  sapwood proportion was nitrogen's constant for bark plus sapwood over nine
  temperate species; the labile-phosphorus saturation threshold was Parton's
  own number read onto a pool defined differently (Hedley-labile, 6.6 to
  11.3 times the resin-extractable orthophosphate the figure was drawn
  against), so the ramp saturated everywhere: a right constant reading a pool
  its source did not define. A surface-microbial phosphorus ramp had no
  phosphorus source and was removed because decomposer biomass C:P is
  homeostatic with respect to its resource (Mooshammer et al. 2014, slope
  0.015, P = 0.118 over 405 samples) while the nitrogen ramp beside it kept
  its direct source.
- A strongly-sorbed phosphorus pool was declared, initialised, serialised and
  reported but assigned nowhere, so a reversible exchange became a first-order
  drain of the sorbed pool at 170 to 320 times the weathering supply, booked as
  an ecosystem loss; it did not surface as a conservation failure because the
  pool was excluded from the accounted total and the mass-balance checks were
  declared and called from nowhere.
- The equilibrium accelerator was not equivalent to the daily operator:
  leaching subtracted mass * (1 - mean daily fraction) per month, removing
  nearly the whole pool; phosphorus forcing was sampled as a triangular sum of
  year-to-date accumulators; the accelerated solve bypassed the sorption
  isotherm the daily path used and did not save and restore the sorbed pools.
- Mineral protection was five linear functions of texture from Earth
  grasslands; the clay control on passive formation is exactly zero above a
  clay fraction of one third, which a quarter of the measured land exceeded;
  the microbial partition's remainder can go negative on nearly pure sand
  under a leaching update the code applied in place of the paper's. Iron and
  aluminium oxides, allophane, aggregate capacity and polyvalent cation
  saturation, which the pedology model could partly supply, were read by
  nothing.
- Soil organic matter was one bulk column with no depth index while the water
  column had fifteen layers and the regolith ran 0.02 to 5 m. Occlusion of
  phosphorus was declared absent because the world had no time axis and a
  terminal sink inside a 40000-year numerical accelerator would drain every
  cell over a span the run does not represent.

## Why it carries

B7 adopts CENTURY-style carbon-nitrogen-phosphorus with an explicit phosphorus
weathering source, and B1 now gives every cell an exposure age, so the two
structural lessons are actionable: a stoichiometry ramp is sourced only when
both the numbers and the pool definition are, and a pedogenic sink that
integrates over a duration belongs on the terrain's clock rather than inside a
spin-up. The remaining findings are the conservation and provenance rules of
A3 and C3 applied to a pool network: every pool fed, every fraction set
closed, every check compiled in, every accelerator equal to what it
accelerates.

## What this system must do

1. Every pool stoichiometry ramp (maximum and minimum ratio, driver, saturation
   threshold) is `Sourced` to a figure or equation AND to the operational pool
   definition it was drawn against (extractant, depth, what the pool includes);
   a conversion between pool definitions is a `Bracketed` constant recorded at
   the ramp with both ends and their derivation. A figure-versus-text
   disagreement is recorded as a bracket, never silently resolved.
2. A parameter of one element is derived from a measurement of that element
   or is `Bracketed` and says so. A constant copied from another element
   carries the copy as its disposition argument and is refused as `Sourced`.
3. Every declared pool is the destination of at least one flux and the source
   of at least one or a declared terminal; the constructor refuses a pool
   nothing assigns. Every transfer-fraction set sums to one with non-negative
   remainders over the entire texture simplex and the whole moisture range,
   checked at construction. Conservation checks are compiled in, run every
   step, in FP64 accumulators, against a floating-point-derived tolerance (C3).
4. Any analytic or accelerated equilibrium solve reproduces the steady state
   of the operator stepped on the daily tier's step (0023) to a
   floating-point-derived tolerance (C3 linear pool steady state oracle),
   composes per-step survival fractions rather than applying means, and
   saves and restores every mineral pool across the solve; it is excluded
   from the physical trajectory (REQ-BIO-009).
5. Mineral protection and phosphorus sorption read the pedology state of B8
   (iron and aluminium oxide content, allophane, aggregate capacity, polyvalent
   cation saturation, andic fraction, clay, pH) through one interface with an
   unset sentinel that refuses rather than a zero; the texture-only form is a
   labelled reduced arm. Phosphate fixation by andic material is applied once,
   in the sorption isotherm or in the weathering source, never both.
6. Soil organic matter is vertically indexed on the land column's layers,
   sharing the depth coordinate with roots and water (REQ-BIO-008); litter
   enters at the depth the tissue occupied.
7. Phosphorus occlusion and the depletion of primary phosphorus over pedogenesis
   integrate over the cell's exposure age from B1, with the rate `Sourced`
   (Parton et al. 1988 K3 form) or `Bracketed`; a spin-up never stands in for a
   pedogenic history, and a soil declared old carries its depletion in its
   initial stocks (REQ-BIO-012).
8. Litter chemistry (lignin, nitrogen, phosphorus by tissue) comes from the
   strategy's traits (REQ-BIO-006), not a global constant.
9. The abiotic decomposition multiplier reads its moisture axis as water-filled
   pore space or matric potential from the column (the axis REQ-BIO-011 uses),
   never a ratio of precipitation to a potential evaporation; its temperature
   response is named in the `Irreducible` biology list of 0021 with the
   temperature range it was fitted over; the published monthly form on a
   potential-evaporation index is a labelled Earth reduced arm (0021 oxygen and
   pressure rule).

## Enforced by

- Type: pool and ramp structs with dispositions; constructor refusals for an
  unfed pool, a non-closing fraction set and an unset mineral proxy.
- Oracles: C3 linear pool steady states (stepped against accelerated);
  element ledgers per step; the mutation run deletes a pool assignment and
  must be caught.
- References index: a `Sourced` ramp whose source row is not `read` is
  refused (Part G).

## References

- Parton, W. J., Stewart, J. W. B. and Cole, C. V. (1988). Dynamics of C, N,
  P and S in grassland soils: a model. Biogeochemistry 5, 109-131.
  DOI: 10.1007/BF02180320. Figure 3 phosphorus ramps; page 115 the receiving
  pool convention; page 117 the inorganic rate constants including occlusion.
- Parton, W. J. et al. (1993). Observations and modeling of biomass and soil
  organic matter dynamics for the grassland biome worldwide. Global
  Biogeochemical Cycles 7, 785-809. DOI: 10.1029/93GB02042. Figure 4 nitrogen
  ramps and the texture controls.
- Parton, W. J., Schimel, D. S., Cole, C. V. and Ojima, D. S. (1987).
  Analysis of Factors Controlling Soil Organic Matter Levels in Great Plains
  Grasslands. Soil Science Society of America Journal 51, 1173-1179.
  DOI: 10.2136/sssaj1987.03615995005100050015x. Where the figure-versus-text
  disagreement would be settled from outside.
- Smith, B. et al. (2014). Implications of incorporating N cycling and N
  limitations on primary production in an individual-based dynamic vegetation
  model. Biogeosciences 11, 2027-2054. DOI: 10.5194/bg-11-2027-2014. The
  documentation whose Appendix C miscites the ramps.
- Wang, Y. P., Law, R. M. and Pak, B. (2010). A global model of carbon,
  nitrogen and phosphorus cycles for the terrestrial biosphere. Biogeosciences
  7, 2261-2282. DOI: 10.5194/bg-7-2261-2010. The sorption topology and the
  soil-order-fitted Langmuir parameters that do not transfer.
- Dantas de Paula, M. et al. (2025). Including the phosphorus cycle into the
  LPJ-GUESS dynamic global vegetation model (v4.1, r10994) - global patterns
  and temporal trends of N and P primary production limitation. Geoscientific
  Model Development 18, 2249-2274. DOI: 10.5194/gmd-18-2249-2025.
- Mooshammer, M., Wanek, W., Zechmeister-Boltenstern, S. and Richter, A.
  (2014). Stoichiometric imbalances between terrestrial decomposer
  communities and their resources: mechanisms and implications of microbial
  adaptations to their resources. Frontiers in Microbiology 5, 22.
  DOI: 10.3389/fmicb.2014.00022. Decomposer C:P homeostasis.
- Cleveland, C. C. and Liptzin, D. (2007). C:N:P stoichiometry in soil: is
  there a "Redfield ratio" for the microbial biomass? Biogeochemistry 85,
  235-252. DOI: 10.1007/s10533-007-9132-0.
- McGroddy, M. E., Daufresne, T. and Hedin, L. O. (2004). Scaling of C:N:P
  stoichiometry in forests worldwide: implications of terrestrial Redfield-type
  ratios. Ecology 85, 2390-2401. DOI: 10.1890/03-0351.
- Yang, X. and Post, W. M. (2011). Phosphorus transformations as a function of
  pedogenesis: A synthesis of soil phosphorus data using Hedley fractionation
  method. Biogeosciences 8, 2907-2916. DOI: 10.5194/bg-8-2907-2011. Why a
  Hedley-labile pool is not plant-available phosphorus.
- Walker, T. W. and Syers, J. K. (1976). The fate of phosphorus during
  pedogenesis. Geoderma 15, 1-19. DOI: 10.1016/0016-7061(76)90066-5. The
  depletion a pedogenic clock has to carry.
- Cotrufo, M. F., Wallenstein, M. D., Boot, C. M., Denef, K. and Paul, E.
  (2013). The Microbial Efficiency-Matrix Stabilization (MEMS) framework
  integrates plant litter decomposition with soil organic matter stabilization:
  do labile plant inputs form stable soil organic matter? Global Change Biology
  19, 988-995. DOI: 10.1111/gcb.12113.
- Lehmann, J. and Kleber, M. (2015). The contentious nature of soil organic
  matter. Nature 528, 60-68. DOI: 10.1038/nature16069. Mineral association
  and aggregation as the controls texture cannot carry.
- Koven, C. D. et al. (2013). The effect of vertically resolved soil
  biogeochemistry and alternate soil C and N models on C dynamics of CLM4.
  Biogeosciences 10, 7109-7131. DOI: 10.5194/bg-10-7109-2013. The depth
  coordinate.
- Wieder, W. R., Bonan, G. B. and Allison, S. D. (2013). Global soil carbon
  projections are improved by modelling microbial processes. Nature Climate
  Change 3, 909-912. DOI: 10.1038/nclimate1951. The explicit-microbial model
  form as a registered bracket.
- /home/cfutro/git/vesper/biosphere/notes/phosphorus-cycle-parameterisation.md,
  /home/cfutro/git/vesper/biosphere/notes/soil-decomposition-biogeochemistry-audit.md,
  /home/cfutro/git/vesper/biosphere/notes/mineral-reactivity-contract.md,
  /home/cfutro/git/vesper/biosphere/notes/soil-phosphorus-input-parameterisation.md.

## Amendments

- 2026-09-08: item 9: the abiotic decomposition multiplier reads the
  column's pore-space moisture axis, and its temperature response carries
  its fitted range (audit row 13), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cadence wording replaced by the daily tier of 0023, from
  notes/findings/2026-09-08-implicit-earth-audit.md
