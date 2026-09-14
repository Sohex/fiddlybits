+++
id = "REQ-BIO-012"
title = "Abiotic nutrient delivery is one element-mass ledger over declared control volumes in which every flux has exactly one source and one destination, deposition mass and never optical depth is the carrier, parent material is a finite stock, and particulate material is not a nutrient until something dissolves it"
old_path = ["/home/cfutro/git/vesper/biosphere/notes/abiotic-nutrient-ledger.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

A table of nutrient sources answers "what is there"; it cannot answer how
much of an element crossed into the pool a root can take from and where the
rest went. The predecessor built the ledger after finding that no artifact in
its tree carried mass from rock, dust or lightning to a root zone (measured on
the old world's pipeline at the archived commit):

- A phosphorus "budget" multiplied a concentration by a relative release
  factor and concentrated it geometrically over basin floors; every step was a
  defensible geomorphic hypothesis and none carried mass, so its output could
  not be added to, subtracted from or checked against anything. It never
  opened the dust-deposition artifact it claimed to consume.
- The ledger that replaced it: thirteen control volumes of four kinds
  (boundary, reservoir, terminal, interface), twenty-one directed terms, one
  identity per node per interval and one over the domain (mass held plus mass
  at terminals equals mass held at the start plus mass across boundaries).
  Element mass always, never compound mass; absolute kilograms per declared
  interval on absolute time, with a per-area rate converted to mass using the
  receiving area the term declares before anything is summed, which is what
  makes an area-basis mismatch fail rather than rescale. Seven reduced
  fixtures ran on every invocation, six built to be wrong in a named way
  (area-basis mismatch, dangling destination, terminal source, element change,
  stock below zero, negative transfer).
- Parent material is a finite stock that depletion decrements, so depletion is
  a result the ledger can produce; a "lithosphere" node exists only because the
  graph check said a reservoir with no inflow cannot be filled, which is the
  exhumation term. Regolith mineral stands between every particulate input and
  the root zone: measured dust was 2 to 4 percent water-soluble in phosphorus
  while the vendored model placed all deposited phosphorus straight into the
  labile-sorbed system. The soil solution is the only node a root takes from.
  An endorheic store has two outflows (deflation, burial) because a closed
  basin that only receives is the shape that makes retention look like
  fertility. Coastal export is terminal: "reached the ocean" is a boundary
  condition, not marine nutrition.
- No screen may be carried on an optical quantity: an optical depth folds in
  refractive index, size distribution and water uptake, and no elemental mass
  comes back out of it; the two live traps were a volcanic sulfate product
  built from a degassing inventory describing stratospheric aerosol while
  tephra is fragmentation that falls proximally, and a sea-salt product whose
  soil-facing output was optics.
- Lightning fixation needs total flash energy and a composition-dependent NO
  yield (Ardaseva et al. 2017 show N2/O2 and N2/CO2 cases produce different
  chemistry), not the ground-flash ignition field fire needs; the two are
  different reductions of one convective diagnostic. A uniform declared
  nitrogen deposition scalar split equally between NH4 and NO3 invented
  amount, chemistry, geography and time; lightning supplies oxidised
  nitrogen.
- Nutrients leached from cells entered no river, floodplain, lake, aquifer or
  ocean and could not return with baseflow or capillary rise; the water
  routing carried water only.
- The phosphorus weathering input was the same law the pedology model already
  ran (a lithology-resolved major-element release times runoff, Hartmann's
  relative phosphorus content), so supplying it was "give the model the field
  it wants" rather than adopting a scheme; the andic phosphate fixation was
  applied once, because the model's sorption isotherm already carries ordinary
  retention. The shipped per-cell sorption constants were one Earth soil
  order's fitted values applied planet-wide.
- Source materiality and non-nitrogen-phosphorus adequacy were screened with
  bounds and directions fixed before any magnitude was seen; potassium binds
  on crystalline lithologies; iron and the trace set refuse for want of a
  release table, and a refusal is a different statement from adequacy.

## Why it carries

B7 declares an explicit phosphorus weathering source and lightning nitrogen,
B8 runs kinetic mineral dissolution over the cell's exposure age with dust as
an in-line tracer deposited to soil, B5 routes water and river solutes, and B3
receives coastal export. Those are the ledger's terms; without the ledger they
are a table. The identity that every flux has one source and one destination
inside a declared node set is what A5's exchanges enforce for water and
energy, stated for elements; the carrier rule (mass, never optics) and the
particulate-to-solution rule are the two places an Earth model was found to
invent availability.

## What this system must do

1. One abiotic nutrient ledger per element (N, P, K, Ca, Mg, S, Fe and any
   trace element a configuration declares) over a declared graph of control
   volumes with kinds boundary, reservoir, terminal and interface; every term
   names one source and one destination inside the graph, its element, its
   phase, its area basis and its owner component; a term booked in a per-area
   rate is converted to mass on its declared receiving area before summation.
   The node and domain identities close to a floating-point-derived tolerance
   at every interval, with the six named-wrong fixtures run per commit.
2. Carriers are masses: deposition mass by element, size and phase from the
   atmosphere's tracers (B2, B8 dust); a screen or a term carried on an
   optical depth or extinction is refused by name.
3. Parent material is a finite stock decremented by weathering and refilled
   by exhumation from B1's rates; regolith mineral is the destination of every
   particulate input, with a separate soluble fraction per source
   (`Bracketed`); soil solution is the only node a root draws from; a term that
   delivers particulate material to solution is refused.
4. The phosphorus source is B8's kinetic dissolution over exposure age, with
   andic fixation applied exactly once between the weathering source and the
   sorption isotherm; sorption parameters are `Bracketed` on the cell's own
   root-zone stock, never a soil-order table.
5. Lightning nitrogen is derived from the convective lightning diagnostic
   (REQ-BIO-015) as flash count times energy per flash (`Bracketed`, dimension J
   per flash, between the breakdown-field-limited and the channel-length-limited
   ends, carrying its pressure scaling through the breakdown field of the
   declared gas at the declared pressure, with the Earth value an `EarthRatios`
   denominator) times a composition-aware yield (`Bracketed`, dimension mol N per
   J, with the declared atmosphere's N2, O2 and CO2), oxidised and
   deposited through the atmosphere's tracers with wet and dry deposition
   resolved; no uniform deposition scalar and no equal NH4:NO3 split.
6. Dissolved species leave the column into B5's routing and can return with
   capillary rise or baseflow; particulate nutrients follow B1's erosion and
   sediment; coastal export is a terminal node handed to B3 with species and
   phase and no claim about marine availability; endorheic stores carry
   deflation and burial outflows.
7. Source materiality and non-N-P adequacy are pre-registered screens with
   bounds and directions declared before any magnitude, returning adequate,
   not settled or refused per element and lithology; a refusal (no release
   table) is reported as such and never as adequacy; the declared model
   boundary states which elements the biosphere can actually limit on.

## Enforced by

- Type: a `Term` is constructed only with a source node, destination node,
  element, phase, area basis and owner; the graph constructor refuses a
  dangling destination, a terminal source and a reservoir with no outflow.
- Fixtures: the seven reduced ledgers per commit, six of which must fail with
  their named verdict.
- Ledgers: the domain identity at every exchange (A5); the C4 mutation run
  swaps an area basis and must be caught.
- Decision records for B7, B8 and B5.

## References

- Porder, S., Vitousek, P. M., Chadwick, O. A., Chamberlain, C. P. and Hilley,
  G. E. (2007). Uplift, Erosion, and Phosphorus Limitation in Terrestrial
  Ecosystems. Ecosystems 10, 159-171. DOI: 10.1007/s10021-006-9011-x. Why
  parent material must be a finite, renewed stock.
- Walker, T. W. and Syers, J. K. (1976). The fate of phosphorus during
  pedogenesis. Geoderma 15, 1-19. DOI: 10.1016/0016-7061(76)90066-5.
- Hartmann, J. and Moosdorf, N. (2011). Chemical weathering rates of
  silicate-dominated lithological classes and associated liberation rates of
  phosphorus on the Japanese Archipelago - Implications for global scale
  analysis. Chemical Geology 287, 125-157. DOI: to confirm.
- Hartmann, J., Moosdorf, N., Lauerwald, R., Hinderer, M. and West, A. J.
  (2014). Global chemical weathering and associated P-release - The role of
  lithology, temperature and soil properties. Chemical Geology 363, 145-163.
  DOI: to confirm.
- Meybeck, M. (1987). Global chemical weathering of surficial rocks estimated
  from river dissolved loads. American Journal of Science 287, 401-428.
  DOI: 10.2475/ajs.287.5.401. Concentration times runoff as the release form
  and the per-lithology table.
- Okin, G. S., Mahowald, N., Chadwick, O. A. and Artaxo, P. (2004). Impact of
  desert dust on the biogeochemistry of phosphorus in terrestrial ecosystems.
  Global Biogeochemical Cycles 18, GB2005. DOI: 10.1029/2003GB002145.
- Mahowald, N. et al. (2008). Global distribution of atmospheric phosphorus
  sources, concentrations and deposition rates, and anthropogenic impacts.
  Global Biogeochemical Cycles 22, GB4026. DOI: 10.1029/2008GB003240. Dust
  phosphate as one tenth of dust total phosphorus.
- Aciego, S. M. et al. (2017). Dust outpaces bedrock in nutrient supply to
  montane forest ecosystems. Nature Communications 8, 14800.
  DOI: 10.1038/ncomms14800.
- Chadwick, O. A., Derry, L. A., Vitousek, P. M., Huebert, B. J. and Hedin,
  L. O. (1999). Changing sources of nutrients during four million years of
  ecosystem development. Nature 397, 491-497. DOI: 10.1038/17276. Marine
  aerosol as the dominant base-cation source on old substrates and a
  negligible phosphorus source.
- Vitousek, P. M. and Sanford Jr, R. L. (1986). Nutrient Cycling in Moist
  Tropical Forest. Annual Review of Ecology and Systematics 17, 137-167.
  DOI: 10.1146/annurev.es.17.110186.001033. The upper-bound standing pool
  for the adequacy screen.
- Schumann, U. and Huntrieser, H. (2007). The global lightning-induced
  nitrogen oxides source. Atmospheric Chemistry and Physics 7, 3823-3907.
  DOI: 10.5194/acp-7-3823-2007.
- Ardaseva, A. et al. (2017). Lightning chemistry on Earth-like exoplanets.
  Monthly Notices of the Royal Astronomical Society 470, 187-196.
  DOI: to confirm. Composition-dependent NO yield.
- Cleveland, C. C. et al. (1999). Global patterns of terrestrial biological
  nitrogen (N2) fixation in natural ecosystems. Global Biogeochemical Cycles
  13, 623-645. DOI: 10.1029/1999GB900014. The biological fixation relation
  that must not be compensated by deposition.
- Wang, Y. P., Law, R. M. and Pak, B. (2010). A global model of carbon,
  nitrogen and phosphorus cycles for the terrestrial biosphere. Biogeosciences
  7, 2261-2282. DOI: 10.5194/bg-7-2261-2010. The soil-order sorption table
  that does not transfer.
- /home/cfutro/git/vesper/biosphere/notes/abiotic-nutrient-delivery-audit.md
  (the nine findings the ledger answers).
- /home/cfutro/git/vesper/biosphere/notes/soil-phosphorus-input-parameterisation.md
  (the weathering input derived from the pedology law; andic fixation applied
  once).
- /home/cfutro/git/vesper/biosphere/notes/cnp-fork-scoping.md (phosphorus is
  rock-derived and its supply is weathering).

## Amendments

- 2026-09-08: energy per flash named as a Bracketed quantity with its pressure
  scaling (audit row 17), from
  notes/findings/2026-09-08-implicit-earth-audit.md
