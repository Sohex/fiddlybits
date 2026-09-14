+++
id = "REQ-PED-010"
title = "Phosphorus release is a lithology-class share of the major-element weathering flux, the root-zone stock is an upper bound, and the steps between release and root are declared"
old_path = ["/home/cfutro/git/vesper/pedology/README.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Hartmann et al. (2014) give phosphorus release as a fixed percentage, per lithological
class, of the fluvial export of Ca, Mg, Na, K and SiO2; the only piece the predecessor
lacked was an absolute major-element flux, and Meybeck (1987) Table 2C supplies the
per-lithology concentrations that runoff carries, the same table and model form the
silica and CO2 fluxes already used. Beside the release sits the root-zone stock:
parent content times bulk density times regolith depth cut at the rootable base, a
TOTAL and an upper bound rather than a labile pool. Two criteria were declared before
the run and reported: the land yield against Hartmann and Moosdorf (2011)'s Japanese
maximum, and the major-element rock content the two configured phosphorus rows imply,
which checks that the content row and the release row are still two different
quantities. An older rank arm (whether dry basin floors geometrically concentrate what
a catchment delivered) carries no mass and no time and is kept as a rank; it does not
read the dust-deposition field, so the aeolian return leg was a source-composition
hypothesis rather than a delivery. Registered as not carried by that pass: a regolith
production RATE, which needs a clock; a soil-shielding function, which Hartmann applies
and no source there supplied; sorption and retention beyond the andic fixation share.
Diatomite is not phosphorus-rich material (600 ppm against a land mean of 628; the
Bodele's export is a mass-flux result), and pavement is a phosphorus sink.

## Why it carries

B7 requires an explicit phosphorus weathering source in its C-N-P cycle; B8 carries
dust deposition reaching soil; B1's clock supplies the production rate that was
missing. Hartmann's law is dimensionally explicit (a share of a flux) and keyed on the
lithology registry (REQ-PED-004), so it transfers to any rock inventory. The
content-versus-release distinction and the stock-as-upper-bound rule are general.

## What this system must do

- Phosphorus release per fine cell is the Sourced class share (Hartmann et al. 2014)
  of the major-element release flux from kinetic weathering (REQ-PED-001), with
  Meybeck's rows as the Earth REPORT check.
- Soil shielding is a function of regolith thickness on the clock (Hartmann's form,
  Sourced, with disposition), not a declared absence.
- The mineral phosphorus stock is initialised from parent content and regolith
  thickness at the cell's exposure age; sorption and occlusion live in B7's pools with
  andic fixation from the andic fraction.
- Dust deposition delivers phosphorus by the source tile's composition; pavement is a
  sink.
- Criteria: land yield within Hartmann and Moosdorf's range as a FAIL bar on the Earth
  test instance only (tier 2) and a REPORT metric on every other configuration; the
  content-versus-release distinctness as a unit test; no rank statistic stands in for
  a flux.

## Enforced by

The element ledgers of M9; A3 dispositions; the lithology registry check; the oracle
registry entries above.

## References

- Global chemical weathering and associated P-release - The role of lithology,
  temperature and soil properties. Hartmann, Moosdorf, Lauerwald, Hinderer, West
  (2014), Chemical Geology 363, 145-163. DOI: 10.1016/j.chemgeo.2013.10.025
- Chemical weathering rates of silicate-dominated lithological classes and associated
  liberation rates of phosphorus on the Japanese Archipelago - Implications for global
  scale analysis. Hartmann, Moosdorf (2011), Chemical Geology 287, 125-157.
  DOI: 10.1016/j.chemgeo.2011.05.005
- Global chemical weathering of surficial rocks estimated from river dissolved loads.
  Meybeck (1987), American Journal of Science 287, 401-428. DOI: 10.2475/ajs.287.5.401
- Solid-phase phosphorus speciation in Saharan Bodele Depression dusts and source
  sediments. Hudson-Edwards, Bristow, Cibin, Mason, Peacock (2014), Chemical Geology
  384, 16-26. DOI: to confirm (10.1016/j.chemgeo.2014.06.014 believed)

## Amendments

- 2026-09-08: the phosphorus-yield FAIL bar scoped to the Earth test instance, REPORT
  elsewhere (audit row 6), from notes/findings/2026-09-08-implicit-earth-audit.md
