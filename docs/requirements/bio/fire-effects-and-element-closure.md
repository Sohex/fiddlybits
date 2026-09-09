+++
id = "REQ-BIO-016"
title = "Fire effects move every element the burned pools carry with a declared partition, survival curves are declared model forms with their sources' domains, resprouting is a trait or an absence, and fire coefficients are named conversions rather than folded literals"
old_path = ["/home/cfutro/docs/world/biosphere/notes/fire-nitrogen-range.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The effects layer of a fire scheme is where combustion completeness, fire-line
intensity and mortality turn burned area into fluxes, and the predecessor's
audit of one such layer found defects that only element closure and source
reading could expose (measured on the old world's fork at the archived
commit):

- Neither fire path moved phosphorus: one transferred carbon and nitrogen at
  combustion with no phosphorus transfer, the other had its phosphorus block
  commented out with an unresolved note. A burn under phosphorus limitation
  would remove a pool's carbon and nitrogen and leave its phosphorus, breaking
  tissue stoichiometry, and the failure CLOSES (the phosphorus was never
  removed, so every budget balances), which is why no closure test could see
  it and the instrument had to be a refusal until the volatilised fraction was
  declared for live and litter pools.
- The rate-of-spread coefficient was declared as an "empirical value" and was
  Noble's unit conversion with a lost decimal, ten times the source; a
  separate error multiplied with it (fuel summed as carbon where the source's
  weight is dry matter, with no carbon-to-dry-matter factor); and a survival
  logistic carried the reciprocal of a fuel unit conversion and an intensity
  coefficient a decade low that was CANCELLING the spread error, so repairing
  either alone left the curve wrong by a decade. Two multiplying errors are
  never repaired with one combined factor, because a plausible product conceals
  both; the repair declared the source coefficient and each unit conversion as
  named quantities and multiplied them on the line.
- A combustion table indexed by intensity class was read at index -1 for the
  "not enough fuel to ignite" signal, aliasing the highest column of the row
  above: a patch with too little fuel to carry a fire combusted all of its
  litter and half its leaves. The sprouter column of the same table was
  unreachable and the three resprouter paths were dead because the model
  carried no resprouting trait anywhere; routing them would mean inventing
  the trait, a strategy-space decision, so they were left dormant with a gate
  holding the premise.
- Six survival curves carried six citations and four verdicts: one transcribed
  with two unit errors; one transcribed correctly and cited for three times
  what it supports (a surface-fire relation with no intensity term, given an
  intensity anchor, a floor and a ramp that were the code's own); one an
  approximation of a mixed model with the community-structure interaction
  dropped; two undocumented fits to papers containing no equation, one of
  which could not reach its own source's stated anchors (a mortality ceiling
  of 0.82 against measured mortality approaching 100 percent below 5 cm
  diameter). Fitted coefficients pass for sourced ones when a comment reads as
  a citation to an equation the paper does not contain.
- Two conservation bounds derived from the input side held on every one of
  2,026,101 gridcell-years and were adopted as acceptance criteria
  (REQ-BIO-013); an emission partition among four nitrogen species reproduced
  its declared proportions to five digits, which is the check that the
  partition and not the magnitude was in question.
- Fire on peatland was disabled outright, a safe dormant baseline and not a
  claim that peat cannot burn; smoke and pyrogenic carbon were a separate
  absorbing aerosol source from any biogenic organic aerosol.

## Why it carries

B7 runs CENTURY-style carbon-nitrogen-phosphorus and SPITFIRE fire, so every
burned pool carries three elements and water and the effects layer must move
all of them or refuse; A3's dispositions and Part G's read-versus-held
discipline are what turn "cited" into "sourced" for a survival curve; and the
resprouting decision is the strategy space's (REQ-BIO-006), not the fire
layer's. The two-error rule and the named-conversion rule are general
practice, recorded here where they were measured on a material term.

## What this system must do

1. Combustion moves every element and water the burned pools carry (carbon,
   nitrogen, phosphorus and any element the ledger declares) with an explicit
   partition per element among atmosphere (gas and particulate, entering B2's
   tracers), ash returned to the litter and mineral soil, and char; the
   partition is `Sourced` or `Bracketed` per element and the operator refuses
   to run an element with an undeclared partition. Combustion completeness by
   fuel class and the emission factors carry the O2 partial pressure and
   total pressure at which they were measured (0021 oxygen and pressure rule)
   and are `Bracketed` (dimensionless) away from it between the
   flaming-limited and the smouldering-limited ends. Tissue stoichiometry
   after a burn closes by construction.
2. Every fire coefficient is a named source quantity times named unit
   conversions on the line where it is used; a folded literal is refused, and
   a substituted corrected literal fails the restatement check against the
   source. Fuel is in the mass basis the spread and intensity relations were
   fitted in, with the carbon-to-dry-matter factor a trait.
3. Every survival or mortality curve is a declared model form carrying the
   domain of its source (fire type, intensity range, size class, region,
   atmospheric O2 partial pressure and total pressure); a relation cited to a
   paper containing no equation is a `Bracketed` model form, never `Sourced`;
   a relation extended beyond its source's variables is registered as the
   extension, not the source. A curve must reach its source's stated anchors
   or is refused.
4. Resprouting and bark thickness are strategy traits (REQ-BIO-006, B7) that
   the effects layer reads; where a configuration's strategy space declares no
   resprouting, the resprouter paths are a declared absence with their
   interface, never dead code.
5. Fuel class and mortality regime are selected by fuel and vegetation state
   (REQ-BIO-005); an out-of-range signal (no fuel) is honoured as no fire, never
   clamped to a class.
6. The input-side conservation bounds of REQ-BIO-013 (loss per interval below
   the stock; mean loss below mean supply at equilibrium, per element) are
   acceptance criteria on every accepted record; a fire operator that closes
   is necessary and not sufficient.
7. Peat fire and smoke are declared absences with interfaces until a
   configuration needs them; pyrogenic aerosol is a source distinct from the
   biogenic organic source (REQ-BIO-018).

## Enforced by

- Type: the combustion operator takes an element partition per declared
  element as a required keyword with no default; a `nothing` is a refusal.
- Ledgers: element closure per burn (C3); the input-side bounds registered in
  the oracle registry.
- Restatement checks: each named coefficient recomputed from its declared
  source quantity and conversions per commit; the C4 mutation run folds one
  and must be caught.
- Strategy registry: a resprouting trait declared anywhere arms the resprouter
  paths and their tests; declared nowhere, the paths are absent by construction.

## References

- Thonicke, K. et al. (2010). The influence of vegetation, fire spread and
  fire behaviour on biomass burning and trace gas emissions: results from a
  process-based model SPITFIRE. Biogeosciences 7, 1991-2011.
  DOI: 10.5194/bg-7-1991-2010. Combustion completeness by fuel class,
  fire-line intensity and mortality.
- Byram, G. M. (1959). Combustion of forest fuels. In: Davis, K. P. (ed.),
  Forest Fire: Control and Use, McGraw-Hill, New York, 61-89. Locator: book
  chapter, no DOI. Fire-line intensity.
- Noble, I. R., Gill, A. M. and Bary, G. A. V. (1980). McArthur's fire-danger
  meters expressed as equations. Australian Journal of Ecology 5, 201-203.
  DOI: to confirm. The rate-of-spread coefficient as a unit conversion.
- Kobziar, L., Moghaddas, J. and Stephens, S. L. (2006). Tree mortality
  patterns following prescribed fires in a mixed conifer forest. Canadian
  Journal of Forest Research 36, 3222-3238. DOI: to confirm. The survival
  logistic and its units.
- Delmas, R., Lacaux, J. P. and Brocard, D. (1995). Determination of biomass
  burning emission factors: Methods and results. Environmental Monitoring and
  Assessment 38, 181-204. DOI: 10.1007/BF00546762. The nitrogen species partition
  whose proportions were the check.
- Rabin, S. S. et al. (2017). The Fire Modeling Intercomparison Project
  (FireMIP), phase 1: experimental and analytical protocols with detailed model
  descriptions. Geoscientific Model Development 10, 1175-1197.
  DOI: 10.5194/gmd-10-1175-2017.
- /home/cfutro/docs/world/biosphere/notes/fire-model-audit.md findings 6, 10,
  11, 14 and 15.
- /home/cfutro/docs/world/biosphere/config/fire.yaml.

## Amendments

- 2026-09-08: combustion completeness and emission factors carry their
  measurement atmosphere and are Bracketed away from it; survival-curve
  domains include O2 and pressure (audit row 22), from
  notes/findings/2026-09-08-implicit-earth-audit.md
