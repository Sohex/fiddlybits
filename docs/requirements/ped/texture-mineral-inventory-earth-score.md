+++
id = "REQ-PED-006"
title = "Texture from a mineral inventory with quartz conserved, level-setting constants Bracketed and swept jointly, andic and exchange properties on their controlling axes, and an Earth score over type localities of known lithology"
old_path = ["/home/cfutro/git/vesper/pedology/README.md", "/home/cfutro/git/vesper/pedology/notes/mineral-reactivity-supply.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The first biosphere driver mapped rock classes straight onto soil texture codes; that
table was parent material, not soil, since the same granite gives coarse grus in a cold
arid place and deep kaolinitic clay in a wet tropical one. The predecessor's texture
mixed each cell's parent materials and converted weatherable primary minerals to clay
as a saturating function of weathering intensity with quartz tracked separately and
never converted, which is the single distinction that makes granite and basalt
diverge under one climate. Two texture constants had no derivation and were given
brackets from mechanism: the sand-to-silt loss ratio is not derivable because two
mechanisms point opposite ways (specific surface area favours silt dissolving faster,
ratio 0.032; the size cascade replenishes silt from sand, ratio unbounded above), so
its bracket is 0.032 to 31.6 and the declared value is the one point carrying a
statement (loss in proportion to abundance); the clay conversion rate is
near-degenerate with the clay yield at low intensity, and the two must be swept
together because they separate only at high intensity where the Earth localities are
and the old world was not. A comment beside the old value had the surface-area
argument backwards, which is why the number did not follow from the sentence.

The texture model was scored against Earth by evaluating the model's own conversion
function at type localities whose lithology is known from published geology, against
SoilGrids, reporting bias, correlation and the mafic-felsic divergence the model exists
to reproduce; a scoring arm that inlined the conversion without the loss ratio and the
donor-pool caps predicted more clay than the model did, so a bias quoted from it
measured the score, not the map. Hillslope transport needs a slope: differencing
cell centres on the climate grid gave a land-mean gradient of 0.001 and the term did
nothing; the within-cell spread of mesh elevation over the mesh spacing gave 0.031,
still two orders below a real hillslope, so the term carries the pattern and not the
magnitude. Frost shattering needs freeze-thaw cycling, measured as the fraction of the
orbit whose diurnal extrema straddle freezing (0.088 of the orbit against 34.8% of
land having a frost season at all).

Andic material: allophane forms on the leaching axis, not the development axis
(Parfitt 2009: "the effect of time is subordinate to these factors"); its content
within fully andic material was taken from Parfitt, Russell and Orbell (1983) Table
III (0.22 kg/kg, Bracketed 0.02 to 0.35 across disagreeing populations), and both
that paper and Singleton et al. (1989) refuse to place the content inside the
transition window, where near-duplicate sites differ by an order of magnitude on
drainage class alone. Cation exchange capacity was derived additively from clay and
organic fractions with coefficients linear in pH (Helling, Chesters and Corey 1964),
its level Bracketed across nine soil orders and 37,921 pedons (Manrique, Jones and
Dyke 1991: 8.4 to 63 cmol(+)/kg of clay) because the level is a clay mineralogy the
component does not resolve; the polyvalent share from Solly et al. (2020) is a lower
bound and is declared as one because its consumer reads it as protection. The Fe-Al
oxide content (total-to-extractable step, one parent, one age band) and aggregate
capacity (no structure resolved) stayed declared absences; and closing all four
proxies would still not license the consuming model's mineral-aware arm, because no
source supplies a parameterised transfer from them to a protection coefficient.

## Why it carries

B8 makes texture and secondary minerals outputs of kinetic weathering on the clock
(REQ-PED-001), which replaces the saturating conversion but not the inventory logic:
primary minerals by rock class, quartz conserved, a size cascade with a Bracketed
ratio, degenerate pairs swept together. B1's hillslope diffusion is the declared
sub-grid closure and the terrain level carries the slope distribution, which answers
the catena's scale problem. The Earth scoring rules (score the production function,
not a re-implementation; report bias, correlation and the contrast the model exists to
reproduce; mineralogy tables are the declared Earth-lithology assumption) are general.
The andic and exchange findings are rules about which axis a transfer may be indexed
on, and the two-gate finding is a rule about what closing a proxy does and does not
buy.

## What this system must do

- Texture per stratigraphy layer is a prognostic mineral inventory: modal mineralogy
  per rock class (Sourced, declared as the Earth-lithology assumption), quartz
  conserved, dissolution kinetics from REQ-PED-001 driving a size cascade whose
  sand-to-silt ratio is Bracketed between the two mechanism limits.
- Degenerate parameter pairs are declared as such and swept together; a result quoted
  from one member alone fails review.
- Hillslope transport reads the terrain level's slope distribution (B1 closure); frost
  shattering reads the column's resolved freeze-thaw crossings.
- Andic fraction and allophane content are keyed on the leaching axis, with the
  transition window carried as a partial fraction and no content claimed inside it;
  exchange capacity is derived from clay, organic fraction and pH with its mineralogy
  level Bracketed; polyvalent saturation is declared a lower bound.
- A soil property whose only measured transfer indexes on an axis the system does not
  carry is a declared absence; with the clock present (REQ-PED-001), age-indexed
  transfers become evaluable and are re-examined.
- Earth oracle: SoilGrids at type localities of known lithology and age, scored by
  calling the production function; bias and correlation as bars, mafic-felsic
  divergence as REPORT; the exchange coefficients are refused unless they reproduce a
  second continent's measured organic-mineral split.

## Enforced by

M5 and M9 site oracles; A3 dispositions on every table value; the sweep declaration
in the parameter registry; C4 (the scoring arm calls production code, never a copy).

## References

- SoilGrids 2.0: producing soil information for the globe with quantified spatial
  uncertainty. Poggio, de Sousa, Batjes, Heuvelink, Kempen, Ribeiro, Rossiter (2021),
  SOIL 7, 217-240. DOI: 10.5194/soil-7-217-2021
- Allophane and imogolite: role in soil biogeochemical processes. Parfitt (2009), Clay
  Minerals 44, 135-155. DOI: 10.1180/claymin.2009.044.1.135
- Weathering sequence of soils from volcanic ash involving allophane and halloysite,
  New Zealand. Parfitt, Russell, Orbell (1983), Geoderma 29, 41-57.
  DOI: 10.1016/0016-7061(83)90029-0
- Contribution of organic matter and clay to soil cation-exchange capacity as affected
  by the pH of the saturating solution. Helling, Chesters, Corey (1964), Soil Science
  Society of America Proceedings 28, 517-520.
  DOI: 10.2136/sssaj1964.03615995002800040020x
- Predicting Cation-Exchange Capacity from Soil Physical and Chemical Properties.
  Manrique, Jones, Dyke (1991), Soil Science Society of America Journal 55, 787-794.
  DOI: 10.2136/sssaj1991.03615995005500030026x
- A Statistical Exploration of the Relationships of Soil Moisture Characteristics to
  the Physical Properties of Soils. Cosby, Hornberger, Clapp, Ginn (1984), Water
  Resources Research 20, 682-690. DOI: 10.1029/WR020i006p00682
- Singleton, McLeod, Percival (1989), Australian Journal of Soil Research 27, 67-77.
  DOI: 10.1071/SR9890067 (verbatim title to confirm from the old index)
- Solly et al. (2020), exchangeable cation partition over Swiss forest profiles.
  DOI: to confirm (verbatim title to be taken from the old index)
