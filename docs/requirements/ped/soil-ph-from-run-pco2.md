+++
id = "REQ-PED-003"
title = "Soil pH is a crossing between mineral buffers with the calcite end solved from the run's pCO2 after validation at the published pressure, and lithology entering as a base-cation supply flux ratio"
old_path = ["/home/cfutro/docs/world/pedology/notes/pedogenesis-value-provenance.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Slessarev et al. (2016) drew a spatially random sample of 20,000 subsoil pH values
from 60,291 and found the distribution bimodal: a calcite-buffered mode near 8.2 and a
gibbsite-buffered mode near 5.1 with an abrupt step where mean annual precipitation
begins to exceed potential evapotranspiration; predicting only those two values from
the sign of the water balance explains 42% of the variance; neutral soils are uncommon
because that range is held by slow primary-mineral dissolution; in the wettest quartile
profiles on carbonate bedrock are 2.6 times more likely to exceed pH 6.5. The
predecessor's form, `pH = G + (D - G) exp(-s L / u)` with `L = ln(1 + q / q_ref)` a
leaching index and `u` the parent's base-cation supply as a fraction of a
calcite-saturated soil's, has two parent-independent ends (a cell that exports nothing
sits on calcite whatever its rock, because unexported calcium accumulates as pedogenic
calcite until the solution saturates; a fully leached cell sits on gibbsite) and keeps
the lithology contrast at finite leaching, which the paper's carbonate deviation is a
statement about.

The calcite end is not a number the project holds. It is solved from the carbonate
equilibrium at the run's `pCO2`, and validated first at the pressure the paper states:
8.236 at 3.45e-4 atm against the published 8.2. The paper's remark that pH was 8.3
before 1977 carries no pressure, so an earlier check that chose 3.30e-4 atm to land on
it was withdrawn as an input chosen after the answer; what the remark constrains is
that the solution crosses 8.25 within that decade's ambient CO2, and the implementation
puts the crossing at 328 ppmv, which can fail. The equation as PRINTED in the paper
merges the hydroxide and bicarbonate terms into a product where the charge balance has
a sum, and drops the two charges a carbonate ion carries; derived from the charge
balance instead, the first loss is worth half a pH unit and the second 0.0012 pH at the
paper's pressure. Evaluated at 450 ppm (measured 2026-08-27, as a record of that day):
8.163 open to the atmosphere, 7.498 at ten times atmospheric in soil air, 6.832 at a
hundred times, with the soil-air enrichment a declared bracket. The gibbsite end (5.1)
is implicit-Earth: through the paper's eq. (7) it fixes an exchange ratio CaX/AlX of
2.7 that is a property of Earth's lithology, weathering and biology; the exchange
chemistry travels, the population does not; bracketed 4.64 to 5.28 over two decades of
that ratio; it carries no CO2 term and cannot be derived the same way.

The supply `u` is a flux ratio, not a pH: Meybeck (1987) Table 2C bicarbonate per rock
relative to carbonate rock, and independently GEM-CO2's alkalinity yields, agree to
better than a factor of two on every category where the requirement (both paper
findings holding at once, `u <= 0.4319` at the declared buffers) turns on a factor of
2.32. An affine pH encoding could not express supplies below 0.159, which three of
four sourced supplies are; solving the paper's equation at each lithology's measured
alkalinity for a fresh-solution pH was rejected on mechanism, because a fresh parent
is not a state the model can be in. A closed basin's soda buffer belongs to the sump:
95.7% of endorheic catchment area sat on the alkaline path of the chemical divide
(REQ-PED-008), so the buffer enters as the one the salt-crust tile relaxes FROM, not as
an additive offset on the whole basin floor (which had put +0.8 on fully leached
cells draining at 11.55 mm/yr); the salt crust is sub-grid at coarse resolution (1.39%
of land, no cell above a quarter) and the term is worth 0.003 pH on a land mean. The
leaching slope's bracket is three readings of one upper bound; no lower bound exists
because bimodality is satisfied in the degenerate limit where all land sits on one
buffer.

## Why it carries

B8 requires pH buffers at the run's `pCO2`, and B8's carbon loop solves `pCO2`, so soil
pH must be a function of it: an equilibrium end is Derived (A3), not transplanted; the
gibbsite end is Irreducible with its argument and a Bracket; the supplies are Sourced.
The generic rules are: validate a derived equilibrium at the source's own published
state before evaluating it anywhere else; check a source's printed equation by
derivation; an input chosen after the answer is not a test; a solute stays where
drainage does not export it, so a buffer is keyed on drainage and zoning rather than on
rock; a zoned sub-grid feature is a tile area, not an offset.

## What this system must do

- Soil pH per tile is a crossing between a calcite buffer and a gibbsite buffer driven
  by the tile's leaching index from the column's own drainage (REQ-PED-005), with a
  third, soda, buffer on the sump tile only. The crossing is placed by a mass balance
  of the kinetic base-cation release (REQ-PED-001) against the drainage export of
  calcium, the calcite side holding while release exceeds export; the exponential
  leaching-index form with its reference runoff and slope is the labelled Earth
  reduced arm.
- The calcite end is solved from the carbonate system at the run's `pCO2`, the tile's
  resolved soil temperature and the Bracketed soil-air enrichment, with each
  equilibrium constant Sourced with the temperature range it was fitted over and a
  refusal outside that range; the solver is validated at the published pressure and
  temperature (8.2 at 3.45e-4 atm; crossing 8.25 within the pre-1977 ambient range) as
  a unit test that can fail; the equation is derived from the charge balance and
  checked against the printed form. A number written into a Derived key is refused.
- The gibbsite end is Irreducible with the exchange-ratio argument and its Bracket
  swept; a cation-exchange model replaces it when one exists.
- Lithology enters as a base-cation supply flux ratio Sourced from two independent
  compilations through the lithology registry (REQ-PED-004); a supply whose implied
  fresh solution falls outside the derived silicate bracket is refused; a province that
  is not a rock carries a composition-spanning Bracket.
- The soda buffer is the sump tile's, from the basin's brine path (REQ-PED-008),
  Bracketed by measured closed-basin lake water until a trona or nahcolite saturation
  solve at the run's `pCO2` exists.
- Earth oracle: the bimodality (mode positions, share in transit, wettest-quartile
  carbonate deviation) against Slessarev's resampled distribution as REPORT metrics.

## Enforced by

Unit tests at the published state; A3 refusal of values on Derived keys; the lithology
registry self-check; the Earth REPORT entry; the tile partition (REQ-HYD-009) carrying
the sump area.

## References

- Water balance creates a threshold in soil pH at the global scale. Slessarev, Lin,
  Bingham, Johnson, Dai, Schimel, Chadwick (2016), Nature 540, 567-569.
  DOI: 10.1038/nature20139
- Global chemical weathering of surficial rocks estimated from river dissolved loads.
  Meybeck (1987), American Journal of Science 287, 401-428. DOI: 10.2475/ajs.287.5.401
- A global model for present-day atmospheric/soil CO2 consumption by chemical erosion
  of continental rocks (GEM-CO2). Amiotte Suchet, Probst (1995), Tellus B 47, 273-280.
  DOI: to confirm
- Worldwide distribution of continental rock lithology: Implications for the
  atmospheric/soil CO2 uptake by continental weathering and alkalinity river transport
  to the oceans. Amiotte Suchet, Probst, Ludwig (2003), Global Biogeochemical Cycles
  17, 1038. DOI: 10.1029/2002GB001891
- The buffer equilibria this record rests on are taken from Slessarev et al. (2016),
  held and read, with the carbonate system constants from Zeebe and Wolf-Gladrow
  (2001) chapter 1 and Millero (1995), both held. Stumm and Morgan, Aquatic
  Chemistry (3rd edition, Wiley 1996, ISBN 978-0-471-51185-4), is the textbook
  background and is not held; nothing here is taken from it.
- Turkish Borate Deposits: Geological Setting, Genesis and Overview of the Deposits.
  Helvaci (2019). Identifier confirmed in the references index (INDEX.md, held).

## Amendments

- 2026-09-08: calcite end evaluated at the tile's resolved soil temperature with each
  constant carrying its fitted range (audit row 21), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: the buffer crossing placed by a release-against-export mass balance with
  the leaching-index form as the Earth reduced arm (audit row 24), from
  notes/findings/2026-09-08-implicit-earth-audit.md
