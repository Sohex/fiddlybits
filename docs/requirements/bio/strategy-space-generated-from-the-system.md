+++
id = "REQ-BIO-006"
title = "The vegetation strategy space is generated from declared trait ranges with costs, filtered by the declared system under competition; no fixed plant functional type table, and Earth's trait covariance is a distance to report"
old_path = ["/home/cfutro/git/vesper/biosphere/notes/vesperian-polar-type.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

An Earth plant functional type table carries Earth's climate in its
covariance. The predecessor measured this on the old world's port of a
twelve-type Earth table at the archived commit:

- Cold tolerance and heat tolerance were anticorrelated across the table
  because they are anticorrelated in Earth's climate: every type with a 30 C
  photosynthetic optimum needed a coldest month above +15.5 C, except one
  grass row that spanned the gap by accident. Under a 32-degree obliquity the
  polar cap was a cold place receiving 390 W/m2 in its warmest month against
  the tropics' 212, with a coldest month of -68.75 C and a warmest of 31 C;
  ten of twelve types were at exactly zero cover there and the accidental
  row carried 0.0274 of 0.0300 total cover. Earth has no such place, so
  Earth's set had no type for it.
- The cap was not short of water in the mass-balance sense: it received
  77 mm per orbit and equally dry warm ground received 74 mm and carried seven
  times the cover. It was short of plants able to intercept water that arrived
  frozen and left as one fifteen-day melt pulse (83.5 percent of bare-soil
  evaporation in one interval); plants captured 4.7 percent of arriving water
  against 78.9 percent on the warm dry ground. Capture per unit leaf was
  already at the 72nd percentile of the planet's cells; what was short was
  leaf carbon in a self-limiting loop (standing carbon 0.0223 kgC/m2 against
  0.0100 of annual production).
- The trait Earth uses for a pulse at the head of a short season is a
  perennial storage organ that deploys leaf on the previous season's carbon, and
  the model had no plant carbon reserve at all; the parameter table could not
  express it.
- A type derived from the cap's measured pressures (leaf lifespan equal to the
  growing season, SLA from that through the leaf-economics regression, a
  photosynthetic plateau from the season's 25th to 95th percentile
  temperature, no cold limit) raised polar cover from 0.030 to 0.350, met its
  registered criterion, and took a fifth to a third of the TROPICAL cover as
  well: a plant with no weakness wins everywhere. The missing piece was the
  cost every shipped cold type paid, an establishment ceiling; with it derived
  from where the diagnosis held, native share equatorward of 45 degrees fell
  to 0.00 percent and the polar result stood. The criterion's own defect was
  recorded: it tested whether the traits moved polar cover and never whether
  the type was polar, so a second criterion outside the diagnosis region was
  registered for the next arm.
- The registry shape that worked elsewhere: a list naming every parameter a
  strategy must define to be valid, each value carrying its source inline,
  the sources listed at the top of the file (measured in
  /home/cfutro/git/vesper/notes/external-model-survey.md section 38a on
  ClimaLand's PFT registry).

## Why it carries

Earth's statistics need new biology, not new software (the plan's verdict):
a table sampled from one planet's flora carries that planet's climate in its
correlations, and no rescaling removes it. The JeDi approach samples
strategies from trait ranges and lets the declared climate and competition
select them, so the covariance is an outcome of the system rather than an
input; the cost of each trait is what makes the selection meaningful, and the
polar experiment is the measurement that a strategy without costs is not a
strategy. B7 adopts the trait-based family; this record states what the trait
space must be able to express and how a strategy-space result is judged.

## What this system must do

1. No fixed plant functional type table. A strategy is a point in a declared
   trait space (B7 lists the axes: LMA and lifespan, wood density, height
   allometry, rooting depth, phenology cues (photoperiod as a lit fraction of
   the rotation period), photosynthetic pathway (C4 as a CO2-concentrating
   mechanism, 0021), the marginal water cost of carbon (the stomatal slope is
   derived from it, 0018), nitrogen fixation with its N2 half-saturation
   pressure, bark thickness, frost tolerance with its carbon cost,
   storage-organ fraction, plus the pigment window of REQ-BIO-003 and the
   tissue tolerances of REQ-BIO-004). Strategies are sampled from the
   declared ranges and filtered by the tile's resolved climate under
   competition for light, water and nutrients.
2. Every trait range carries a disposition. Earth's observed trait envelope
   is a `Sourced` range; Earth's trait COVARIANCE is not imposed and is
   reported as a distance (C1 REPORT) when the Earth instance runs. A
   physiological trade-off that is a property of tissue rather than of climate
   (leaf lifespan against leaf mass per area and nitrogen, wood density against
   hydraulic vulnerability) is retained as a `Sourced` relation with a
   `Bracketed` scatter; a correlation that is a property of where Earth's
   plants live is not.
3. Every trait carries its cost in the carbon, nutrient and water economy
   (REQ-BIO-007): frost tolerance costs carbon and hardening; a storage organ
   costs allocation and respiration; an establishment ceiling is a cost paid
   through thermal tolerance of the recruit. The constructor refuses a strategy
   space in which any tolerance has no cost coupling.
4. The storage-organ or reserve trait is expressible: a mass-conserving
   non-structural carbon and nutrient reserve that can fund canopy deployment
   before the season's assimilation and is drawn down by respiration and
   phenological pull.
5. Acclimation of photosynthetic and respiratory temperature responses to
   growth temperature is physiology with a bracketed memory time (REQ-BIO-007),
   so a strategy's heat and cold tolerances are not two fixed numbers copied
   from a climate.
6. A strategy-space result is judged on at least two registered criteria: one
   inside the region a strategy was derived for and one outside it (a strategy
   that wins everywhere has an undeclared free lunch). Judged on both ends of
   every bracket the derivation could not fix, and reported as the bracket.
7. Registry shape: every trait entry carries its source and its disposition
   inline; a strategy's trait vector is part of the run identity (A6); a
   strategy that changes a converted quantity's unit declares the unit at the
   entry (REQ-BIO-001).

## Enforced by

- Type: a `Strategy{FT}` struct with a disposition per trait; a constructor
  refusal for a tolerance with no cost coupling and for a range missing a
  disposition.
- Oracle: the Earth test instance's emergent biome and trait pattern against
  observed trait-climate relations as REPORT metrics; a sweep across rotation,
  obliquity, gravity and stellar type (M4b) must change the dominant strategy
  set; a "no free lunch" fixture: a strategy with all tolerances relaxed and no
  costs is refused by the constructor.
- Process: the two-criteria rule for any strategy-space experiment is a
  registered threshold before the experiment runs (C2).

## References

- Pavlick, R., Drewry, D. T., Bohn, K., Reu, B. and Kleidon, A. (2013). The
  Jena Diversity-Dynamic Global Vegetation Model (JeDi-DGVM): a diverse
  approach to representing terrestrial biogeography and biogeochemistry based
  on plant functional trade-offs. Biogeosciences 10, 4137-4177.
  DOI: 10.5194/bg-10-4137-2013. The strategy-sampling family B7 adopts.
- Scheiter, S., Langan, L. and Higgins, S. I. (2013). Next-generation dynamic
  global vegetation models: learning from community ecology. New Phytologist
  198, 957-969. DOI: 10.1111/nph.12210. Trait-based, trade-off-driven
  community assembly against fixed functional types.
- Reich, P. B., Walters, M. B. and Ellsworth, D. S. (1992). Leaf Life-Span in
  Relation to Leaf, Plant, and Stand Characteristics among Diverse Ecosystems.
  Ecological Monographs 62, 365-392. DOI: 10.2307/2937116. The leaf-economics
  trade-off retained as tissue physiology.
- Wright, I. J. et al. (2004). The worldwide leaf economics spectrum. Nature
  428, 821-827. DOI: 10.1038/nature02403. The Earth trait envelope as a
  `Sourced` range.
- Dietze, M. C. et al. (2014). Nonstructural Carbon in Woody Plants. Annual
  Review of Plant Biology 65, 667-687.
  DOI: 10.1146/annurev-arplant-050213-040054. The reserve pool the storage
  trait requires.
- Noy-Meir, I. (1973). Desert Ecosystems: Environment and Producers. Annual
  Review of Ecology and Systematics 4, 25-51.
  DOI: 10.1146/annurev.es.04.110173.000325. Transpiration as the captured
  share, and pulse regimes.
- Schwinning, S. and Sala, O. E. (2004). Hierarchy of responses to resource
  pulses in arid and semi-arid ecosystems. Oecologia 141, 211-220.
  DOI: 10.1007/s00442-004-1520-8. Pulse depth and the partition between
  evaporation and transpiration.
- Kattge, J. and Knorr, W. (2007). Temperature acclimation in a biochemical
  model of photosynthesis: a reanalysis of data from 36 species. Plant, Cell
  and Environment 30, 1176-1190. DOI: 10.1111/j.1365-3040.2007.01690.x.
  Acclimation as physiology replacing fixed thermal optima.
- /home/cfutro/git/vesper/notes/audits/lpj-pft-set-implicit-earth.md (the
  anticorrelated table).
- /home/cfutro/git/vesper/biosphere/notes/polar-cover-cold-filter-and-capture.md
  (capture against supply; the storage-organ diagnosis).
- /home/cfutro/git/vesper/biosphere/notes/underoccupied-niches.md (the
  planet-wide diagnostic).

## Amendments

- 2026-09-08: trait axes aligned with 0021: photoperiod as a fraction of the
  rotation, C4 mechanism, marginal water cost, N2 half-saturation (audit rows
  12, 15, 16, 25), from notes/findings/2026-09-08-implicit-earth-audit.md
