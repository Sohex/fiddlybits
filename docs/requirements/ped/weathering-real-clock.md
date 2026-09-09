+++
id = "REQ-PED-001"
title = "Weathering and regolith carry a real clock: kinetic dissolution integrated over exposure age, not an intensity that folds time away"
old_path = ["/home/cfutro/docs/world/pedology/README.md", "/home/cfutro/docs/world/pedology/notes/pedogenesis-value-provenance.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor computed a weathering INTENSITY in the Walker-Hays-Kasting form, a
power of runoff times an exponential of temperature normalised so that Earth's land
mean is 1, and said why: "an intensity rather than a rate, because soil age is not known
well enough on either world to carry explicitly". Its own known-gaps list names the
cost: "Time is not represented. Weathering intensity folds the time integral into its
normalisation, so a young volcanic surface and an ancient craton weather identically
under the same climate", and notes that the terrain generator carried exhumation data
that could have supported an age term. The consequences were measured repeatedly as
refusals: the extractable-oxide transfer of Chadwick et al. (2003) indexes on
substrate age (a soil younger than 20 ka holds its exchange properties high relative
to a 170 ka soil under the same 2500 mm of rain) and could not be used; the duricrust
model of Fenske et al. (2025) hardens a layer over the range of water-table fluctuation
across 1e5 years and was refused; desert pavement supply is exhaustible once bedrock
highs are buried (McFadden et al. 1987, about 0.4 Ma) and the rule could not see it;
relict groundwater and relict lakes (REQ-HYD-001, REQ-HYD-003) were out of reach; a
soil pH "fresh parent" state was declared not a state the model can be in.

Regolith depth was a saturating balance `maximum_depth * P / (P + E)` adopted after
the logarithmic steady state of Heimsath's exponential production function railed a
quarter of land on each clip (it needs production over erosion to span a factor of
1e4). Its level was set by three constants, each Bracketed from a measured
compilation rather than fitted: the maximum depth from Shangguan et al. (2017)
depth-to-bedrock statistics (world median 6.70 m, mean 13.09 m, bracketed between them
because an eroding profile sits below the asymptote and transported fill above it);
the dry-erosion baseline from Portenga and Bierman (2011) (arid basins 100 +/- 17
m/Myr against a global drainage-basin mean 218 +/- 35, ratio 0.459, `b = 0.85` in
`[0.49, 1.79]`; their compilation shows no significant bivariate correlation of
denudation with mean annual precipitation, so a weak moisture dependence is what the
data license, and the 0.15 previously carried suppressed dry denudation with nothing
behind it); and the erosion coefficient per unit relief, jointly constrained with the
asymptote by a bracket on the land-mean level that neither key's own bracket names, so
the pair is swept together. Measured 2026-08-17 on the predecessor's generated world
under its bootstrap climatology, the land-mean intensity was 0.380 while the intensity
of the land-mean climate was 0.572, because the law is concave in runoff on a skewed
distribution.

## Why it carries

The user's decision is that the terrain snapshot carries its own ages and rates so
that lithology, cover and soil age have a real clock (B1: exposure age, cumulative
denudation, current uplift and erosion rates on the surface clock). B8 follows:
prognostic regolith with `E` the terrain's own rate, and kinetic mineral dissolution
at laboratory rates integrated over the cell's exposure age rather than river-chemistry
fits. The old intensity and the old saturating depth were closures for a missing
clock; with the clock present they are replaced by integrals, and the refusals above
become computations. The generic lesson beneath them holds on any planet: a transfer
indexed on an axis the system does not carry cannot be derived, and a form that rails a
large share of its domain is the wrong form, not a wrong constant.

## What this system must do

- Regolith thickness per cell is prognostic on the surface clock:
  `dH/dt = P(H, climate, lithology) - E`, with `E` the terrain's erosion rate from B1 and
  `P` a soil-production function whose form is a `Closure` (its calibration climate is
  Earth's frost and root regime, and it stands for frost cracking, root wedging and
  chemical loosening until REQ-PED-006's freeze-thaw crossings and the vegetation's
  root state supply the rate) and whose constants are Sourced with the measured
  brackets above as their Bracket; the seed initialises `H` by integrating
  over the cell's exposure age under the seed's declared climate bracket, never from a
  steady-state closure. The compilation statistics (depth to bedrock, cosmogenic
  denudation) are Earth REPORT metrics of the resulting field, not its parameters.
- Mineral conversion and solute release are kinetic: per-mineral laboratory rate laws
  (Palandri and Kharaka 2004) applied to the rock's modal mineralogy over the wetted
  residence time, with the laboratory-to-field rate discrepancy and its decline with
  age (White and Brantley 2003) carried as a Bracketed, age-dependent factor rather
  than folded into a normalisation. The Walker-Hays-Kasting intensity survives only as
  an Earth REPORT metric, and the kinetic flux summed over exorheic land is the
  weathering term the carbon balance consumes (REQ-PED-011); no published
  runoff-temperature form enters that balance.
- Two cells differing only in exposure age under one climate must differ in regolith,
  texture and secondary minerals; this is a per-commit identity on the seed.
- Any law nonlinear in climate or lithology is evaluated on the resolved series and per
  rock (REQ-PED-002, REQ-PED-005); the mean of the law feeds the fluxes.
- No clip: the soil artifact reports the share of land at each bound of every form, and
  a share above a declared small fraction fails the report.
- Every rate or threshold in this record quoted per year or per million years carries a
  time-base class per REQ-BIO-001 item 6: `PhysicalKinetic`, stored per second and
  converted once; the same rule binds REQ-PED-009 and REQ-PED-011.
- Earth oracle: chronosequence sites of known lithology and age (bias, correlation and
  mafic-felsic divergence of texture; regolith thickness against depth-to-bedrock
  statistics as REPORT); the `age x rate` identity of the M1 gate is the same clock.

## Enforced by

B1 and B8 decision records; the M1 age-times-rate identity; M5 and M9 site oracles;
A3 dispositions (no constant in the weathering law is Tuned); the rail-share report.

## References

- A negative feedback mechanism for the long-term stabilization of Earth's surface
  temperature. Walker, Hays, Kasting (1981), Journal of Geophysical Research 86,
  9776-9782. DOI: 10.1029/JC086iC10p09776
- The soil production function and landscape equilibrium. Heimsath, Dietrich,
  Nishiizumi, Finkel (1997), Nature 388, 358-361. DOI: 10.1038/41056
- The effect of time on the weathering of silicate minerals: why do weathering rates
  differ in the laboratory and field? White, Brantley (2003), Chemical Geology 202,
  479-506. DOI: 10.1016/j.chemgeo.2003.03.001
- A compilation of rate parameters of water-mineral interaction kinetics for
  application to geochemical modeling. Palandri, Kharaka (2004), U.S. Geological Survey
  Open-File Report 2004-1068. Locator: USGS OFR 2004-1068 (DOI: 10.3133/ofr20041068,
  to confirm)
- Understanding Earth's eroding surface with 10Be. Portenga, Bierman (2011), GSA Today
  21(8), 4-10. DOI: 10.1130/G111A.1
- Mapping the global depth to bedrock for land surface modeling. Shangguan, Hengl,
  Mendes de Jesus, Yuan, Dai (2017), Journal of Advances in Modeling Earth Systems 9,
  65-88. DOI: 10.1002/2016MS000686
- The impact of climate on the biogeochemical functioning of volcanic soils. Chadwick,
  Gavenda, Kelly, Ziegler, Olson, Elliott, Hendricks (2003), Chemical Geology 202,
  195-223. DOI: to confirm (10.1016/j.chemgeo.2002.09.001 believed)
- Influences of eolian and pedogenic processes on the origin and evolution of desert
  pavements. McFadden, Wells, Jercinovich (1987), Geology 15, 504-508. DOI: to confirm

## Amendments

- 2026-09-08: soil-production function declared a Closure with its Earth calibration
  climate named (audit row 31), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: the kinetic flux named as the carbon balance's weathering term,
  published forms REPORT only (audit row 14), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: time-base classes of REQ-BIO-001 extended to pedology rates and
  thresholds (audit row 38), from notes/findings/2026-09-08-implicit-earth-audit.md
