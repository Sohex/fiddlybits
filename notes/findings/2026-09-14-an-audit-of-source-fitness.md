# An audit of source fitness: every cited source judged against the use it anchors

Measured on 2026-09-14 from `main` at `625832c`, in the worktree of `fiddlybits-9j0`, with
`test/planets/` read from the open branch `fiddlybits-52v.4.5` (the only branch that carries it).
Sources were read from `references/text/<stem>/<NNNN>.txt` (the PDF page index) and, where a
text layer dropped a table, from the PDF page itself. Package locators were read in the installed
depot at the Manifest version or with `git show <commit>:<path>` at the commit a record names.

## The standard

A source fits a use only when the passage read supports exactly that use. "Cited and read" is not
enough, and a convention borrowed from another field is not a basis where a domain-specific or
data-derived one exists. The case that raised the row is on `fiddlybits-k6b`: Cohen (1988), a
behavioural-science effect-size convention, nearly anchored a hydrology oracle's correlation edge
that the data's own measurement uncertainties can set.

A not-fit verdict names one or more categories:

| category | what is wrong |
| --- | --- |
| C1 | a convention borrowed from another field stands for a physical or data-derived basis |
| C2 | the source does not state the value, law, table or equation the locator claims |
| C3 | the source's regime or validity range is exceeded |
| C4 | wrong edition, version, table, product release or dataset version |
| C5 | a secondary source, review or textbook stands for the primary the rule requires |
| C6 | an index row marked read does not name the passage the use rests on, or a held row is used as read |
| C7 | a bar rests on something decision 0025 does not accept as a bar's basis |
| C8 | an Earth value is a default or basis where the rules forbid it |

Other verdicts: FIT, and NOT VERIFIED where the source is not on disk and could not be fetched.

## How the audit was run

Fifteen scopes, each audited against its own sources:

- R1, R2, R3: `docs/oracles/registry.toml`, split at lines 1376 and 2112. Every anchor, every
  source a statistic or threshold names as its basis, every protocol declaration and the
  instrument.
- S: every `Sourced` locator and every source named in a comment in `src/` and `test/`.
- D1, D2: `docs/decisions/` 0001-0030 and 0031 onward, where a citation is the basis of a law,
  number, scheme or rule, amendments included.
- Q1 to Q5: `docs/requirements/` by area (atm and cry; bio; hyd and ocn; num, prov, sys and proc;
  ped and ter).
- I: `docs/imports/`.
- P: `docs/plans/`, where a passage gives a source as the basis of a number or law.
- X1, X2, X3: the rows of `docs/references/INDEX.md` marked read (lines 27-129, 130-400, 401 to
  the end), each row's named passage against its source and every citing use against what the row
  says was read.

The X scopes judge a row's coverage of its uses, so a citation can appear there and in its own
scope. Counts are per scope and are not summed across scopes. A background mention, a pointer to
another record, and a fixture identifier that claims no source are not counted.

## Counts

| scope | citations | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| R1 registry, tier 1 build to bio | 57 | 34 | 23 | 0 |
| R2 registry, fire to earth.fluxnet_gpp | 57 | 20 | 34 | 3 |
| R3 registry, earth.snow_cover_extent to the end | 68 | 37 | 29 | 2 |
| registry total | 182 | 91 | 86 | 5 |
| S src and test (with test/planets on 52v.4.5) | 43 | 21 | 22 | 0 |
| D1 decisions 0001-0030 | 91 | 74 | 12 | 5 |
| D2 decisions 0031 onward | 72 | 62 | 9 | 1 |
| decisions total | 163 | 136 | 21 | 6 |
| Q1 requirements atm, cry | 77 | 57 | 18 | 2 |
| Q2 requirements bio | 103 | 86 | 16 | 1 |
| Q3 requirements hyd, ocn | 81 | 65 | 16 | 0 |
| Q4 requirements num, prov, sys, proc | 165 | 156 | 6 | 3 |
| Q5 requirements ped, ter | 104 | 83 | 18 | 3 |
| requirements total | 530 | 447 | 74 | 9 |
| I imports | 140 | 134 | 6 | 0 |
| P plans | 19 | 5 | 14 | 0 |
| X1 INDEX read rows, lines 27-129 (rows and uses) | 108 | 90 | 18 | 0 |
| X2 INDEX read rows, lines 130-400 (rows and uses) | 121 | 106 | 15 | 0 |
| X3 INDEX read rows, line 401 on (rows and uses on main) | 88 | 67 | 16 | 5 |
| X3 uses on the 52v.4.5 branch | 6 | 1 | 5 | 0 |

In S, the seven Murray and Dermott passages of `src/Systems/gravity.jl` and the fifteen of
`src/Systems/figure.jl` are one row each (S8, S9); their passages are verified in X1.

What the counts say, without restating each case:

- The registry is where fitness fails most. Many tier-2 and tier-3 fail bars state a number with
  no basis decision 0025 accepts, or rest on an inter-model or observational spread. Many tier-1
  "published norms" or "published spreads" name a paper that publishes none. Of the registry's
  anchors, most sit on rows still marked held. `oracles.registry_wellformed` refuses a held anchor
  only on a registered entry (`src/Oracles/registry.jl`), and nothing is registered, so the check
  passes by design and the refusal comes at registration.
- The code is mostly fit on substance. Its failures are index bookkeeping (constants and schemes
  whose sources are held, not read), one misdescribed radius, one frame error in Earth()'s orbit
  and one convention sourced as a value.
- Decisions and requirements fail where a gloss says more than the passage (a law attributed to a
  paper that restates or omits it, a range quoted from a different quantity), and where a textbook
  or review stands for a primary.
- Imports are almost all fit; the five failures are record text against source or tree.

## Cases found in the code scope, in brief

The full table is S in the appendix. Four cases matter beyond bookkeeping:

- **Earth()'s longitude of periapsis is 180 degrees from the frame it is declared in** (S30).
  Standish and Williams Table 1 counts the heliocentric longitude of perihelion, 102.93768193 deg,
  from the J2000 equinox, where the Earth's own longitude at the March equinox is 180 deg. Decision
  0004 puts the planet's true longitude at the vernal equinox at `Omega_E`, and Earth() declares
  `Omega_E = 0`, so perihelion falls 103 deg after the vernal equinox, near the June solstice.
  Berger 1978 Appendix p.2366: "180 deg has to be added to the value numerically obtained" before
  lambda = nu + omega-tilde holds. Decision 0004 (The seasonal angles are Derived) says Berger's
  numerical form, with 180 subtracted, is `varpi - Omega_E`. It is the form with 180 added. Plan
  52v.5-time:215 repeats the identity without saying which. Consistent declarations are
  `Omega_E = pi` with the tabulated varpi, or `Omega_E = 0` with 282.93768193 deg.
- **Earth()'s "volumetric mean radius" is an arithmetic mean radius** (S2, S25). Archinal et al.
  2018 Table 4 gives Earth's equatorial radius 6378.1366, polar 6356.7519 and mean 6371.0084 km;
  p.35 says the Earth's mean radius, alone in the table, was computed from the other radii.
  (2a+b)/3 = 6371.00837 km matches it; the volume-equivalent (a^2 b)^(1/3) is 6371.00039 km, 8.0 m
  smaller. Decision 0005 names the mesh radius as the volumetric mean radius. Moritz 2000 p.131, a
  page already read for omega, prints GRS80's R3 = 6 371 000.7900 m, "radius of sphere of same
  volume".
- **Earth()'s Exner reference pressure cites the standard atmosphere** (S31). CODATA 2018 Table
  XXXI states 101 325 Pa as the standard atmosphere, a unit, and 100 000 Pa as the standard-state
  pressure; it states neither as an Exner reference, which decision 0013 and plan 52v.4 make a
  declared representation convention.
- **Salmon et al. 2011, Barnes et al. 2014 and 2020 and Whitehead 1998 are used as read and are
  held** (S12 to S21). Every passage was opened and supports its use; `src/Connectivity/terminals.jl`
  gives section 4 of Barnes 2014 as p.121, where it is printed on p.122.

## Fixed in this branch

Each is a citation or locator correction to a source already read, in a file no open branch edits.

| case | file | was | now | source and locator |
| --- | --- | --- | --- | --- |
| S22 | test/dispositions/fixtures.jl | default locator Archinal 2018 Table 1 on a value 1.0 | identifier "fixture", as test/system does | no source is claimed by a fixture |
| P3 | docs/plans/fiddlybits-52v.4-system.md:441 | Earth() "IAU and CODATA values" | names Prsa et al. 2016, CODATA 2018, Archinal et al. 2018, Moritz 2000, Standish and Williams | the locators the instance carries |
| X1 N4 | src/Orbit/kepler.jl:3-6 | "Markley equations 30 to 35" | equation 30 and the split of equation 33, with e_minus_sin for equation 34 | Markley 1995 pp.9-10, eqs. 30-35 |
| X3 6 | src/Reductions/error_bound.jl validity_limit; test/reductions/error_bound.jl:33 | "discussion following eq. 3.11" (section 3, compensated summation) | gamma_n = n u / (1 - n u), p.784 | Higham 1993 p.784, section 2 (read) |
| X1 N5 | src/Systems/gravity.jl, src/Systems/figure.jl, test/system/gravity.jl | Murray and Dermott (2000) | (1999) | copyright page: "First published 1999" |
| I 2 | docs/imports/rootsolvers-jl.md:72-77, B4 row | the `if` at test/runtests.jl:198 "has an empty body" | lines 198-202 skip with `continue`; B4 a clean negative | RootSolvers.jl at 7389b926, blame d0dfc16a (2026-06-28) |
| I 4, 5 | docs/imports/adapt.md, docs/imports/dynamicquantities.md | Version `to pin` | 4.7.0 and 1.13.0, the compat entries | Project.toml [compat] |
| Q3 H2 | docs/requirements/hyd/basin-fate-is-a-process.md | "intact-rock range (five orders, Stock and Montgomery)"; "about a factor of 4" | intact strength two orders by UCS (Zondervan); five orders is K across lithologies (Stock and Montgomery); four to fifteen by n | Zondervan 2020 p.6 Fig. 4d and p.11; Stock 1999 p.10 |
| Q4 N4, N5 | docs/requirements/sys/constants-have-five-dispositions.md; docs/requirements/proc/physics-is-not-a-knob-and-earth-is-a-distance.md | Kok et al. 2014 alone for the fragmentation size distribution | Kok 2011 eq. 6 added beside it | Kok et al. 2014 p.13031 "dust size distribution expression of Kok (2011b)"; Kok 2011 read for eq. 6 |
| Q4 N6 | docs/requirements/prov/restart-bitwise-state-only-refuses-on-moved-input.md | Baker et al. 2015 in References | removed; REQ-NUM-002 keeps it | no rule of REQ-PROV-001 rests on an ensemble test |
| X1 N8 | docs/requirements/ped/soil-ph-from-run-pco2.md | Helvaci 2019 listed, "held" | removed | the record takes nothing from it |
| Q5 NF-3 | docs/requirements/ped/phosphorus-lithology-release.md | Hartmann and Moosdorf 2011 DOI 10.1016/j.chemgeo.2011.05.005 | 10.1016/j.chemgeo.2010.12.004 | the paper's first page |
| Q5 NF-12 | docs/requirements/ter/lithology-class-denotes-a-rock.md | "about 4x" | four to fifteen times by the slope exponent | Zondervan 2020 p.6, Fig. 4d |
| Q5 NF-14 | docs/requirements/ter/snapshot-carries-ages-and-rates.md | Naldrett 2004, DOI to confirm | Naldrett 2010, abstract p.669 | Naldrett 2010 (read) |

## Not fit, and the row that carries each group

Every not-fit case is in the appendix with its evidence. The rows below were filed from this audit,
each linked discovered-from `fiddlybits-9j0`, each blocked by the open branch that edits its files.

| row | carries |
| --- | --- |
| fiddlybits-wvu | INDEX.md read status and anchors for passages this audit verified (Salmon 2011, FIPS 180-4, IEEE 754 clauses 5.4.2 and 3.6, Murray eq. 4.114, Archinal p.22 and Table 1 and p.9 fn 2, Standish EM Bary row, Berger eq. 2, Mason eq. 15, Mlawer pp.2551-2552, Fan 2013 p.940 and supplement Table S1, Heikes and Randall I and II, Thuburn, Wan, Prsa Table 1 GM rows, Winton, Roquet, Millero 2008), and anchor corrections for Kessler, Report-349, Kite, Zondervan, Moosdorf (X1, X2, X3, S, D2, I) |
| fiddlybits-f9g | sections cited and never read: Higham sections 1 and 3, IEEE 754 clauses 4, 6, 7, Braun and Willett section 4, Zaengl 2015 sections 2.1-2.2 and nesting, Murray chapter 2 and the tidal chapter, Berger eqs. 8-10, Yen eq. 37, IAPWS R10-06 sublimation, Textor emission, Shah Table 1, Millero 1995 eq. 90 (X1, X3, Q1, Q3, D1) |
| fiddlybits-iwq | dynamical-core registry entries whose anchors publish no norm, band or spread, and Gardner for Conde (R1 17, 18, 20, 30-36) |
| fiddlybits-5r5 | system and kernel registry entries: gas mixture anchors, Kahan for Higham, Markley equation text, Berger daily-form regime (R1 8, 11, 15; X1 N4; X3 3) |
| fiddlybits-n13 | tier-1 analytic entries of ocean, column, hydrology, surface physics, radiation and fire (R1 37-50; R2 1-8) |
| fiddlybits-te0 | tier-2 atmosphere, ocean, cryosphere and aerosol bars and product versions (R2 9-27; R3 cases 1-4, 9-11) |
| fiddlybits-pi4 | tier-2 land, hydrology and terrain bars, anchors and the ETOPO final paper (R2 28-57; R3 cases 5, 12-14; X2 NF13) |
| fiddlybits-2tq | tier-3 sweeps and protocols (R3 cases 6-8, 15-17; R1 35) |
| fiddlybits-5az | plans 52v.7 compensated_sum source and 52v.4 Salmon wording (P2, P11) |
| fiddlybits-tr8 | decision locators and primaries: 0008:163, 0015 Turcotte, 0020 Cuffey, 0041 Gardner, 0031 Harris and Durran, 0026 square root of N and Pincus 2015, INDEX rows for Iverson, Stein and Stein, Iversen and White (D1, D2, X3) |
| fiddlybits-b7w | atmosphere and cryosphere requirement citations (Q1 N1-N9, N11-N16; X3 1) |
| fiddlybits-3t6 | hydrology and ocean requirement citations (Q3 H11, H24, H28, O3, O7, O10, O12, O14, O18, O21, O33, O34) |
| fiddlybits-6u1 | system, numerics and provenance requirement citations (Q4 N1-N3, Roache 1994, uncited KOC scaling, stale identifiers) |
| fiddlybits-c25 | vegetation and biogeochemistry requirement citations (Q2 N1-N15; X2 NF12) |
| fiddlybits-1us | pedology and terrain requirement citations, the Paragas 2025 paper and the 2.74 factor, INDEX rows naming absent PDFs (Q5 NF-1, 2, 4-11, 13; X2 NF4, NF9) |
| fiddlybits-3iu | import records for Winton 2000 and Roquet et al. 2015a, the cuda.md and mesharrays locators (I 1, 3) |

Cases carried by rows that already existed, with a note appended to each on 2026-09-14:
`fiddlybits-52v.2.15` (Barnes and Whitehead read status and the p.121 locator), `fiddlybits-52v.4.5`
(Earth() cases S23-S31), `fiddlybits-52v.9.4` (Williamson publishes no norms), `fiddlybits-k6b`
(GLWD v2 is a maximum extent; HydroLAKES has no long-term mean; the 0.30 edge's basis),
`fiddlybits-52v.8.15` (no zonal-mean CERES uncertainty), `fiddlybits-52v.8.16` (Moat 2020 has no
overturning profile; NPP algorithm spread), `fiddlybits-52v.8.17` (AeroCom per-model residuals, Fig.
9), `fiddlybits-52v.8.19` (Sherwood 2020 is not AR6), `fiddlybits-52v.8.20` (per-basin
distributions; Flint's concavity), `fiddlybits-52v.6.36` (CF 1.13 locators verified).

## Cases for the user's decision

Each fix would change a registered bar, a constant's disposition, a decision's basis or a test
instance's declared value, so none was made or filed as settled.

1. Berger's longitude of perihelion and Earth()'s orbit (S30; P8): decision 0004's seasonal-angle
   sentence, plan 52v.5-time:215, and Earth()'s `Omega_E` or `longitude_of_periapsis` on
   52v.4.5.
2. Earth()'s radius (S2, S25; X1 N2): keep 6371008.4 m and call it the mean radius; declare the
   volumetric radius Derived from Table 4's a and b; or take GRS80's R3 from Moritz 2000 p.131.
   `EarthRatios.radius_unit` follows whichever is chosen.
3. Earth()'s Exner reference pressure (S31): the Sourced standard atmosphere, the 100 000 Pa
   standard-state pressure of the same table, or an Irreducible convention.
4. What decision 0025 accepts as a fail bar's basis (R3 10, 11; P12, P14-P18; Q3 H18, O3; R2
   37): an inter-model spread in tier 2 (earth.meridional_heat_transport,
   earth.global_surface_temperature, the AeroCom partners), an observational uncertainty or spread
   (CERES zonal, NPP algorithms, per-basin distributions, snow cover, denudation), and the
   predecessor's pre-registration (the 0.30 edge on k6b). As written, each is report.
5. The Reference-Composition anomaly tolerance (D1 2; Q3 O20): neither Millero et al. 2008 nor the
   TEOS-10 manual states one, so the fence of decisions 0004 and 0017 may become Bracketed.
6. Decision 0016's water-CO2 continuum (D1 6): Tran et al. 2018 is CO2 absorbing with H2O as
   perturber, 2400-2600 cm-1; the H2O continuum broadened by CO2 is another source.
7. Decision 0017's pure-water transport properties (D1 7): IAPWS-95 is thermodynamic only; the
   viscosity and conductivity releases are separate.
8. The fresh-snow density bracket of decision 0018 and REQ-ATM-010 (D1 8; Q1 N10): Anderson 1976
   eq. 4.22 is in wet-bulb temperature from LaChapelle's Alta plot, so the air-temperature end needs
   a source (Hedstrom and Pomeroy 1998, read, is a candidate).
9. The dust emission coefficient bracket of decision 0018 (D1 9): Kok et al. 2014 has one fit, not
   two populations.
10. The Bahr volume-area coefficient, Derived in decision 0020 and REQ-CRY-003 (D1 10; Q1 N17): Bahr
    et al. 1997 derives no coefficient and needs four closure exponents.
11. Bernacchi's conversion pressure in decision 0021 and REQ-BIO-007 (D1 12): the paper states none.
12. Decision 0031's basis for the rotating control forms (D2 N1; R1 49): Whitehead 1998 is a review;
    the primary is Whitehead, Leetmaa and Knox 1974, paywalled.
13. Conditional on readings filed as rows: decision 0041 if Gardner's SSP3(333)c coefficients
    disagree or the basis moves to Conde et al. 2017 (fiddlybits-tr8); decision 0015's "no CFL
    constraint" if Braun and Willett's qualifier applies, and decisions 0013 and 0016 if Zaengl
    2015 does not support F5 (fiddlybits-f9g); REQ-HYD-005's f_grad bracket end if argued from Niu
    2005 alone (fiddlybits-3t6); k_e's bracket ends if any were set from Moosdorf's 3.2
    (fiddlybits-1us).

## Fetches

One attempt each.

Failed, open access:

- "Mixed layer depth over the global ocean: An examination of profile data and a profile-based
  climatology", 10.1029/2004JC002378 (publisher challenge page).
- "An Updated Assessment of Near-Surface Temperature Change From 1850: The HadCRUT5 Data Set",
  10.1029/2019JD032361 (publisher challenge page).
- "A gridded global data set of soil, intact regolith, and sedimentary deposit thicknesses for
  regional and global land surface modeling", 10.1002/2015MS000526 (HTML returned).
- "An Idealized Comparison of One-Way and Two-Way Grid Nesting", 10.1175/2010MWR3080.1 (empty body).
- "Radiative flux and forcing parameterization error in aerosol-free clear skies",
  10.1002/2015GL064291 (HTTP 403).
- "GEOCARB II: a revised model of atmospheric CO2 over Phanerozoic time", 10.2475/ajs.294.1.56
  (a one-page file).

Fetched and read in the audit scratchpad, not ingested: Estilow et al. 2015
(10.5194/essd-7-137-2015), Moat et al. 2020 (10.5194/os-16-863-2020), Abramowitz et al. 2024
(10.5194/bg-21-5517-2024), Paragas et al. 2025 ("A New Spectral Library for Modeling the Surfaces
of Hot, Rocky Exoplanets", 10.3847/1538-4357/ada9eb), the TOML v1.0.0 specification.

Paywalled, for the user by verbatim title and identifier:

- "The pivot algorithm: A highly efficient Monte Carlo method for the self-avoiding walk",
  10.1007/BF01022990.
- "Perspective: A Method for Uniform Reporting of Grid Refinement Studies", 10.1115/1.2910291.
- "A theory of glacial quarrying for landscape evolution models", 10.1130/G33079.1 (INDEX says the
  PDF is on disk; it is not).
- "The impact of climate on the biogeochemical functioning of volcanic soils",
  10.1016/j.chemgeo.2002.09.001 (INDEX says held; not on disk).
- "A model for the global variation in oceanic depth and heat flow with lithospheric age",
  10.1038/359123a0.
- "Saltation threshold on Earth, Mars and Venus", 10.1111/j.1365-3091.1982.tb01713.x.
- "Rates of chemical denudation of silicate rocks in tropical catchments", 10.1038/274244a0.
- "Approximate Formula for the Thermal Conductivity of Gas Mixtures", 10.1063/1.1724352.
- "Biochemical Models of Leaf Photosynthesis", 10.1071/9780643103405 (already in REQUESTS.md).
- "Rotating hydraulics of strait and sill flows", Whitehead, Leetmaa and Knox 1974, Geophysical
  Fluid Dynamics 6, 101-125; identifier not confirmed.

## Appendix: every citation, by scope

The tables below are each scope's record as audited, with headings demoted and punctuation
reduced to ASCII. A "fix class" there is the auditor's proposal: (a) a citation or locator
correction to a read source, (b) work for a row, (d) the user's decision. The sections above
record what was fixed, filed and raised.

### R1: Registry, lines 1 to 1375


Audited on the worktree fiddlybits-9j0 at 625832c. Every anchor, and every source or finding a
statistic or threshold names as the basis of a number, a configuration or a bar. Exact identities
with anchors = [] and no cited basis are not counted. Protocol tables (end of file) are outside this
scope. Page numbers: "pdf N" is the page index under references/text/<stem>/NNNN.txt; printed pages
are given where the registry gives them.

#### Counts

| total citations | fit | not fit | not verified |
| --- | --- | --- | --- |
| 57 | 34 | 23 | 0 |

No entry in this range is registered (every registered_at is empty), so no fix below changes a
registered bar. Every fix that edits registry.toml touches a file edited by open branches
(fiddlybits-k6b, fiddlybits-52v.6.26, fiddlybits-52v.8.13) and, being a change to an entry's
anchors, statistic or threshold, merges registry-only.

#### Every citation

| # | where | use | source (INDEX file, status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | system.kepler_period anchors | Kepler period and anomaly identity | murray2000-solar-system-dynamics.pdf, read | Eq. (2.22) p.28 (INDEX) | FIT | Eq. (2.22) located pdf 42-43; INDEX row reads it for the two-body period |
| 2 | system.kepler_period threshold | stable residual and derivative, eqs 30-35; eqs 20-29 as control | markley1995-kepler-equation-solver.pdf, read | eqs 20-35 | FIT (note: not in anchors) | INDEX row: read for eqs 30-35; finding 2026-09-10-kepler-in-a-portable-kernel.md l.62-68: eq. 30 replaces 1 - e cos E, AstroLib implements 20-29 only |
| 3 | system.kepler_period threshold | 2 ulps of pi reachable only with Markley 30-35 | notes/findings/2026-09-10-kepler-in-a-portable-kernel.md | table l.124-133 | FIT | "bisection, stable residual ... 2 ulps", "Markley then two stable Newton steps ... 1 ulp"; naive residual 35.5 ulps |
| 4 | system.kepler_period statistic | log sampling of E below 45 deg above e = 0.75 | notes/findings/2026-09-10-sampling-the-kepler-hard-region.md | l.12, 38, 95 | FIT | "eccentricity above 0.75 and eccentric anomaly below 45 degrees"; "spaced logarithmically from 1e-8 to 45 degrees" |
| 5 | system.orbit_mean_insolation anchors | daily-insolation form at declared phases | berger1978-long-term-variations-daily-insolation.pdf, read | Appendix, eq. (10) | FIT | pdf 6: W = 86.4 S0/(pi rho^2) (H0 sin phi sin delta + cos phi cos delta sin H0), cos H0 = -tan phi tan delta, rho the normalised distance |
| 6 | system.gravity_and_figure anchors | centrifugal g(r, phi), Darwin-Radau figure | murray2000-solar-system-dynamics.pdf, read | Eqs. (4.95)-(4.112) pp.149-153 (INDEX) | FIT | Eq. (4.112) located pdf 167; INDEX row reads each relation named |
| 7 | system.gas_mixture_properties anchors | water-substance properties within stated uncertainty | wagner2002-iapws-formulation-1995-thermodynamic-properties-water.pdf, held | section 8, figs 6.1-6.4 | FIT (held) | pdf 3 contents: "8. Uncertainty of the IAPWS-95 Formulation"; pdf 4: percentage uncertainties in density, speed of sound, cp, vapour pressure |
| 8 | system.gas_mixture_properties anchors | viscosity and conductivity against tabulated values on Earth(), a CO2-bulk and an H2-He instance | lemmon2004-viscosity-thermal-conductivity-nitrogen-oxygen-argon-air.pdf, held | p.1 abstract, pdf 42 | NOT FIT (C3) | pdf 42: "uncertainties for the dilute gas are 2% for all four fluids" (N2, Ar, O2, air); no CO2, H2 or He equation. The CO2 and H2-He arms of the statistic have no anchor |
| 9 | system.gas_mixture_properties anchors | binary diffusivity within stated uncertainty | fuller1966-new-method-prediction-binary-gas-phase-diffusion.pdf, held | Table II-III, pdf 10 | FIT (held) | pdf 10: "present diffusion volume correlation with an average error of 4.3%"; H2 and He systems included (pdf 4 Table II note c) |
| 10 | system.gas_mixture_properties dataset_or_reference, datasets | pure-gas thermochemistry (cp, molar mass) | docs/inputs/data/burcat-ruscic-thermochemical.toml | BURCAT.THR | FIT | manifest: NASA 7-term polynomials, 3526 species, hashed |
| 11 | system.gas_mixture_properties statistic | "the Wilke and Blanc mixing rules" | wilke1950-viscosity-equation-gas-mixtures.pdf held; Blanc (1908) not in INDEX | none | NOT FIT (C6, basis named and not anchored) | anchors list carries neither; grep of INDEX for Blanc returns nothing |
| 12 | mesh.area_closure threshold | per-cell floor of one eps R^2, primal bar N eps R^2 | notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md | section "The area formula sets an absolute floor" | FIT | "one cell of a unit sphere carries an absolute error of about one epsilon under l'Huilier and about one eighth ... under the vector form"; "a sum over cells is bounded by the cell count times that absolute floor" |
| 13 | mesh.area_closure threshold | dual bar 6 N eps R^2 | notes/findings/2026-09-11-mesh-measure-floors-at-working-precision.md | section "The dual sum needs six times the primal's bar" | FIT | "the dual sum's bar is 6 N eps R^2"; level 0 dual residual 24 eps against N eps = 20; sixth piece as remainder makes the arm unable to fail |
| 14 | mesh.nesting_identity threshold | child-sum bar 8 eps R^2 per parent, radial defect 4 eps R | notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md | l.99-102; table l.36-41 | FIT (note) | nesting residual 1.2e-14 relative (level-2 parents, 320 cells, about 2.1 eps absolute) and 1.0e-10 (level 8, about 4.3 eps) under l'Huilier; projected max abs(1 - r) = 2.22e-16 (1 eps). Both bars sit above the measurement; the finding does not itself state the constants 8 and 4 |
| 15 | kernels.reduction_partition_independent anchors | residual within k N eps M, and compensated sum as positive control | kahan1965-pracniques-further-remarks-reducing-truncation.pdf, held | pdf 1 l.68-108 | NOT FIT (C2) | Kahan gives the compensated-summation trick (S2 = (S-T) + S2) and "a loss of almost log10 N significant decimals"; no bound of the form k N eps M. The bound is Higham 1993 eq. (2.6), p.784, read (INDEX l.624), not anchored |
| 16 | build.load_latency threshold | ceiling unset beyond A/A scatter | notes/findings/2026-09-11-load-latency-instrument.md | l.9-11, 47 | FIT | "fixes a bar only once the A/A scatter of the measurement is known ... This is that scatter, and two reasons the bar stays unset" |
| 17 | core.imex_convergence_order anchors | the tableau's designed order for SSP3(333)c | gardner2018-imex-runge-kutta-nonhydrostatic-atmospheric-models.pdf, held | pdf 5 l.6-8 | NOT FIT (C5) | "third-order strong stability preserving methods SSP3(333)b and SSP3(333)c from Conde et al. (2017)": Gardner restates a tableau whose primary, Conde et al. 2017, is not in INDEX |
| 18 | core.williamson_tc1 threshold and anchors | "published norms for the scheme class" | williamson1992-standard-test-set-numerical-approximations.pdf, held | pdf 8-9, 18 | NOT FIT (C2) | pdf 18 defines the error measures to be graphed; pdf 9: "we provide in a companion report solutions ... from a spectral transform approximation" and invites centres to submit results; no norm of any scheme class is published in the paper |
| 19 | core.williamson_tc2 anchors | steady geostrophic flow, no error growth | williamson1992, held | case 2, pdf 19 | FIT (held) | case 2 is the steady-state nonlinear geostrophic flow with an analytic solution; error measures l1, l2, linf of h and v (pdf 19 l.31) |
| 20 | core.williamson_tc5_tc6 threshold and anchors | "published band" of norms against reference solutions | williamson1992, held | pdf 24-25 | NOT FIT (C2) | case 5: "a reference solution will be provided by a high resolution spectral transform model integration ... Agreement must be found with at least one other high resolution solution"; case 6 likewise; no band is published |
| 21 | core.checkerboard_divergence_mode anchors, statistic, threshold | configuration, window and control | gassmann2011-inspection-hexagonal-triangular-c-grid.pdf, read | section 8 pp.2717-2719, fn 4, Table 1, Fig. 5 | FIT | pdf 12: r_d = sqrt(gH0)/f/d, "126 x 146 hexagonal gridpoints", dt* = 0.1/sqrt(1 + r_d^2) with footnote 4; pdf 13: h* = h_m + h_p exp(-((x-x_c)^2/(2.5a) + (y-y_c)^2/a)); pdf 14: r_d = 0.5, h_p = 5, a = 0.075, 50 time steps, V8 violations less than V4 |
| 22 | core.checkerboard_divergence_mode anchors, statistic | triangle divergence by Gauss theorem, first-order sign-changing error | wan2013-icon-1-2-hydrostatic-atmospheric.pdf, read | section 4.2 eqs (6), (7), (10), p.740 | FIT | pdf 6 l.73-177: eqs (6), (7), (10); "first-order error term changes sign" |
| 23 | core.checkerboard_divergence_mode anchors, statistic | f-sphere with constant f | thuburn2009-numerical-representation-geostrophic-modes-arbitrarily.pdf, read | section 4.3 p.8330 | FIT | pdf 2: "restrict attention to the case of constant Coriolis parameter f"; section 4.3 f-sphere |
| 24 | core.hollingsworth_check anchors, statistic, threshold | zonal balanced flow, parameters, power method, depth bracket, control | peixoto2018-numerical-instabilities-spherical-shallow-water.pdf, read | section 4 p.5; Fig. 3 p.7; pp.8-10; Table 1 p.15; App. B p.17 | FIT | pdf 5: u = u0 cos(phi), u0 = 2 pi a/12 days, g = 9.80616, Omega = 7.292e-5, eq. (7), 240 km; pdf 7 Fig. 3 depths to 0.001 m; pdf 9 non-depth-weighted TRSK; pdf 10 240/120/60/30 km; pdf 15 Table 1; pdf 17 power method. F_u and R_u values recomputed from these (3.899 at 10 m, R_u 2.206 at 240 km) |
| 25 | core.hollingsworth_check anchors, statistic | F_u and R_u definitions | bell2017-numerical-instabilities-vector-invariant-momentum.pdf, read | eqs (69)-(71) p.7 | FIT | pdf 7 l.108-168: eqs (69), (70), (71) and the factor of 2 in R_u |
| 26 | core.hollingsworth_check anchors, statistic | instability internal, absent in a one-level model | hollingsworth1983-internal-symmetric-computational-instability.pdf, read | section 1 p.417 | FIT | pdf 1: "the instability is purely internal and cannot occur in a one-level model" |
| 27 | core.hollingsworth_check anchors, statistic, threshold | growth rate from the power method; triangular C-grid among the least stable | lapolli2023-accuracy-and-stability-analysis-horizontal-discretizations.pdf, read | section 4.5.1 pp.31-32 | FIT | pdf 31: "nu = log lambda/Delta t"; abstract pdf 1 "C-grid ICON schemes are within the least stable"; pdf 32 ICON e-folding 0.1-0.2 days |
| 28 | core.fsphere_normal_modes anchors, statistic, threshold | configuration, mode counts, control | thuburn2009, read | section 4.4 p.8331, 4.5 p.8332, Figs 10-11 pp.8333-8334 | FIT | pdf 11: a = 6371220 m, f = 1.4584e-4, mean geopotential 1e5; pdf 14 Fig. 11: tangential velocity by projection gives non-stationary geostrophic modes |
| 29 | core.fsphere_normal_modes threshold | spurious zero-frequency mode at grid scale | gassmann2011, read | section 7.2 p.2717 | FIT | section 7.2 on the stationary mode from averaged divergence (pdf 15 l.17: "Divergence averaging ... gives rise to a stationary mode in wave dispersion") |
| 30 | core.jablonowski_williamson_steady threshold and anchors | "published bound" on l2 of surface pressure from the steady state over 30 days | jablonowski2006-baroclinic-instability-test-case-atmospheric.pdf, held | section 4, Figs 3-4 pp.15-16 | NOT FIT (C2) | the steady-state assessment is l2(u - u_bar) and l2(u_bar - u_bar(t=0)) of zonal wind (pdf 15-16, Figs 3-4); no surface-pressure norm and no bound for the steady state is published |
| 31 | core.jablonowski_williamson_wave threshold and anchors | "published multi-model range" of minimum surface pressure at day 9 and time of wave breaking | jablonowski2006, held | section 5, Figs 6-11, pp.18-25 | NOT FIT (C2) | published: snapshots at day 9 (Figs 6-7), l2 differences of surface pressure between cores and resolutions as the uncertainty of the reference solutions (pdf 16 l.170, Figs 10-11); breaking only qualitative ("around day 9", pdf 21, 29); no range of minimum surface pressure or breaking time; tables are resolutions, time steps and wall clock |
| 32 | core.held_suarez threshold and anchors | "published spread" of jet strength and latitude | held1994-proposal-intercomparison-dynamical-cores-atmospheric.pdf, held | pp.1828-1829, Fig. 2 | NOT FIT (C2) | two models (T63 spectral, G72 gridpoint), contour plots only; hemispheric difference as "a quick estimate of sampling error"; "should not be interpreted as implying that the true solution ... has been obtained ... sensitive to resolution and have not yet converged" (pdf 5); no stated spread |
| 33 | core.dcmip_small_planet anchors | "published norms for the small-planet tests" | wedi2009-framework-testing-global-non-hydrostatic.pdf, held | pdf 2, 10 | NOT FIT (C2) | a reduced-radius framework comparing IFS and EULAG (normalised drag histories, Fig. 9); no norms published for a test set |
| 34 | core.dcmip_small_planet anchors | same | ullrich2012-dynamical-core-model-intercomparison-project.pdf (DCMIP-2012 test case document v1.7), held | section 0.3 pdf 2-3; tests pdf 42-47 | NOT FIT (C2) | small-planet setup (radius / X, Omega X, pdf 3) and required output only (pdf 42, 46, 47); normalised error norms are defined for the tracer tests (pdf 15, 19, 25), and no values are published |
| 35 | core.held_suarez_rotation_scaling (tier 3) anchors | inter-model spread of Hadley edge and jet count against rotation rate in the Held-Suarez configuration | yang2019-simulations-water-vapor-clouds-rapidly.pdf, held | abstract, pdf 2 | NOT FIT (C3, and C2) | abstract: intercomparison of moist GCMs with radiation and clouds "on a rapidly rotating planet receiving a G-star" spectrum and "a tidally locked planet" with an M-star spectrum; pdf 2: 1-day rotation, and 60-day orbital and rotation period. Two configurations, full physics, no Held-Suarez forcing, no rotation sweep, no Hadley-edge statistic |
| 36 | core.hadley_small_rossby_limit dataset_or_reference ("Held and Hou scaling"), anchors = [] | Hadley edge against rotation within discretisation error, tier 1 | held1980-nonlinear-axially-symmetric-circulations.pdf, held, not anchored | abstract, section 4 | NOT FIT (C3; basis not anchored) | abstract: "axially symmetric circulations in a ... Boussinesq fluid ... sufficiently inviscid that the poleward flow ... is nearly angular momentum conserving"; section 4b the approximations' self-consistency. The statistic names no axisymmetric configuration; against a 3-D core with eddies the form is not an identity |
| 37 | column.richards_philip dataset_or_reference | Philip infiltration series, early-time exponent | not in INDEX | none | NOT FIT (C6, basis named and not indexed or read) | grep of INDEX and REQUESTS for Philip returns nothing; anchors = [] |
| 38 | column.richards_philip dataset_or_reference | Srivastava and Yeh transient solution | not in INDEX | none | NOT FIT (C6) | as above |
| 39 | column.richards_philip dataset_or_reference | Gardner steady evaporation | not in INDEX | none | NOT FIT (C6) | as above |
| 40 | hydro.groundwater_dupuit anchors | Dupuit-Forchheimer head between fixed heads | dupuit1863-etudes-theoriques-et-pratiques-sur.pdf, held (INDEX: second edition, 1863) | none | NOT FIT (C4, and C2) | the held scan is the first edition: title page pdf 5 "ETUDES THEORIQUES ET PRATIQUES SUR LE MOUVEMENT DES EAUX COURANTES", dated 1848 (pdf 7 l.29), without "dans les canaux decouverts et a travers les terrains permeables"; no page of 304 matches "permeable" (grep perm.able) and the only "filtration" hit (pdf 228) concerns seepage under a levee. The groundwater chapter is not in the held file |
| 41 | ocean.stommel_munk anchors | Stommel western boundary layer closed form | stommel1948-westward-intensification-wind-driven-ocean.pdf, held | pdf 3-4 | FIT (held) | pdf 3: closed-form stream function under boundary conditions (10), cases f = 0, constant, linear in latitude; pdf 4: western current "less than 100 km" wide with R = 0.02 |
| 42 | ocean.stommel_munk anchors | Munk lateral-friction boundary layer | munk1950-wind-driven-ocean-circulation.pdf, held | eq. (6) pdf 2; eq. (24) pdf 6 | FIT (held) | pdf 2 eq. (6): balance of lateral stress curl, planetary vorticity and wind-stress curl; pdf 6: width against A through eq. (24) |
| 43 | ocean.teos10_check_values dataset_or_reference, anchors, threshold | "published check values" and "the manual's stated check-value precision" | ioc2010-international-thermodynamic-equation-seawater-2010.pdf, held | Appendix M p.183 | NOT FIT (C2) | the only mention in the manual (pdf 183): "Numerical check values are provided with each of the routines in the library", referring to the SIA library, Feistel et al. (2010b) and Wright et al. (2010); the manual itself tabulates no check values and states no check-value precision |
| 44 | ocean.freezing_point_check_values anchors, threshold | freezing-temperature check values and precision | ioc2010, held | section 3.33, Table 3.42.1 | NOT FIT (C2) | section 3.33 defines the freezing temperature; Table 3.42.1 (pdf 76) lists selected values, not check values with a precision; the check values are the GSW library's (pdf 76 l.9-10 names gsw_ functions) |
| 45 | ocean.carbonate_check_values anchors | K1 and K2 formulation and its stated domain | lueker2000-ocean-pco2-calculated-dissolved-inorganic-carbon.pdf, held | abstract p.105 | FIT (held) | abstract: pK1 and pK2 as functions of T and S on the total scale; calculated fCO2 agrees "to 0.07 +/- 0.50% ... fCO2 up to 500 uatm" |
| 46 | ocean.carbonate_check_values dataset_or_reference, threshold | "reference values of the adopted carbonate-chemistry package" and "the package's stated reference precision" | no source anchored | none | NOT FIT (C2) | Lueker 2000 publishes no package reference points or precision; no anchor names the package's documentation |
| 47 | ocean.carbonate_check_values dataset_or_reference | Mucci 1983 stated domain | mucci1983-solubility-calcite-aragonite-seawater.pdf, held, not anchored | none | NOT FIT (C6, basis named and not anchored) | named in dataset_or_reference, absent from anchors |
| 48 | ocean.free_drift_closed_form anchors | quadratic air and water stress with turning angles in the momentum balance | hibler1979-dynamic-thermodynamic-sea-ice-model.pdf, held | eq. (2), p.818 (pdf 4) | FIT (held) | pdf 4: "air and water stress terms ... from simple nonlinear integral boundary-layer theories, assuming constant turning angles", C_a, C_w, rho_a, rho_w, phi, theta; the free-drift closed form is the balance with the internal stress dropped, derived from these terms |
| 49 | ocean.strait_control_identity anchors | closed-form rotating control; wide, narrow and f-to-zero limits | whitehead1998-topographic-control-oceanic-flows-deep.pdf, held (a review) | eqs (12)-(13), pdf 4-5 | NOT FIT (C5) | pdf 4: the zero potential vorticity solutions "[Whitehead et al., 1974]"; pdf 5 eq. (12) Q = g' h_u^2/(2f) and (13) connecting to f = 0. The law is anchored to the review; the primary, Whitehead, Leetmaa and Knox (1974), is not in INDEX |
| 50 | physics.monin_obukhov_neutral threshold | "published function to 1e-6" | none named; anchors = [] | none | NOT FIT (C2, basis unnamed) | no source named for the neutral drag function; INDEX holds Businger 1971 and Monin and Obukhov 1954, neither anchored |
| 51 | physics.water_roughness_identity anchors | Charnock form z0 = alpha u*^2/g | charnock1955-wind-stress-on-a-water-surface.pdf, held | Q.J. 81, p.639 (pdf 1) | FIT (held) | "the simplest non-dimensional relation between them, g z(0)/u*^2 = constant"; approximate constant 12.5 in the log form |
| 52 | cryo.halfar_dome anchors | similarity solution, 2-D | halfar1981-dynamics-ice-sheets.pdf, held | eqs (6)-(14), pdf 2 | FIT (held) | pdf 2: eqs (9)-(14), g(eta) = (1 - abs(eta)^((1+n)/n))^(n/(2n+1)), f(t) = (t/tau0)^(-1/(3n+2)) |
| 53 | cryo.halfar_dome anchors | similarity solution, 3-D | halfar1983-dynamics-ice-sheets-2.pdf, held | eqs (2), (3), (15), pdf 1 | FIT (held) | pdf 6: "a cylindrically symmetric similarity solution (2) (three-dimensional case)" |
| 54 | cryo.halfar_gravity_scaling anchors | t0 proportional to Gamma^-1 with Gamma = 2A(rho_i g)^n/(n+2) | halfar1981, held | eqs (2), (4), (5) | FIT (held, note) | pdf 2: length scale L = 1/(rho g) and time scale T = ((n+2)/2) A^n, so the dimensional t0 carries (rho g)^-n; the Gamma notation is not Halfar's and his A^n is the older rate parameter. The pressure-melting depth in the same statistic has no anchor |
| 55 | cryo.halfar_gravity_scaling anchors | same, 3-D | halfar1983, held | eqs (20), (28)-(29), pdf 2 | FIT (held) | pdf 2: t-hat carries (2 tau0/(rho g))^n and the factor (n+2) explicitly |
| 56 | cryo.volume_area_derived anchors | volume-area scaling from the flow law and the mass-balance closure; coefficient's gravity exponent | bahr1997-physical-basis-glacier-volume-area.pdf, held | eqs (3b), (4), (7), pdf 3; closures pdf 6 | FIT (held) | eq. (3b) [u_x] proportional to [A][rho]^n[g_x]^n[h]^(n+1)[F]^n; eq. (4) combines them with the mass balance; gamma = 1 + (1 + m + n(f+r))/((q+1)(n+2)) |
| 57 | bio.farquhar_aci anchors | A-Ci shape at the Rubisco/RuBP transition with temperature responses and O2 partial pressure | farquhar1980-biochemical-model-photosynthetic-co2-assimilation.pdf, held | abstract; eq. (36); Fig. 2 | FIT (held, note) | abstract: "dependence of net CO2 assimilation rate on p(CO2) and irradiance ... variation of compensation point with temperature and p(O2)"; eq. (36) j_max(T). "Digitised curves" names no figure |

#### Not fit, one section per case

##### 8. system.gas_mixture_properties: Lemmon and Jacobsen (2004) for the CO2 and H2-He instances
- Where: docs/oracles/registry.toml, system.gas_mixture_properties, anchors and statistic.
- Use: viscosity and conductivity checked against tabulated pure-gas and binary values on SyntheticNonEarth() (CO2 bulk) and SyntheticComposition2() (H2-He bulk).
- Source: Viscosity and Thermal Conductivity Equations for Nitrogen, Oxygen, Argon, and Air, 10.1023/B:IJOT.0000022327.04529.f3, held.
- Category: C3. The equations cover N2, O2, Ar and air only (pdf 42: "2% for all four fluids"). No anchor states the CO2, H2 or He transport properties the two synthetic arms are judged against.
- Fix class: b. Needs a read source for CO2 viscosity and conductivity, and for H2 and He, added to INDEX and anchored.

##### 11. system.gas_mixture_properties: Wilke and Blanc mixing rules not anchored
- Where: the same entry's statistic.
- Use: the mixture rules checked at unit mole fraction.
- Source: Wilke 1950 (10.1063/1.1747673, held, INDEX l.931) and Blanc (1908) (not in INDEX).
- Category: C6. The statistic names both rules, but neither is in anchors, and Blanc is not indexed.
- Fix class: b. Read Wilke 1950 for the rule and anchor it; index, read and anchor Blanc.

##### 15. kernels.reduction_partition_independent: Kahan (1965) anchors a bound it does not state
- Where: the entry's anchors and threshold ("the residual within k*N*eps*M").
- Use: the residual bound of a reduction, with compensated summation as a positive control.
- Source: Pracniques: further remarks on reducing truncation errors, 10.1145/363707.363723, held.
- Category: C2. Pdf 1 gives the compensated-sum program and a loss of "almost log10 N significant decimals", but no bound in k, N, eps and M. That bound is Higham (1993), The Accuracy of Floating Point Summation, 10.1137/0914050, read, eq. (2.6) with gamma_{n-1} from p.784 (INDEX l.624; notes/findings/2026-09-11-reduction-error-bound-derivation.md).
- Fix class: a. Add "The Accuracy of Floating Point Summation" to the entry's anchors and keep Kahan for the compensated sum. This is a registry.toml edit, and registry.toml is edited by open branches.

##### 17. core.imex_convergence_order: Gardner et al. (2018) stands in for the tableau's primary
- Where: the entry's anchors.
- Use: the designed order of the SSP3(333)c tableau.
- Source: Implicit-explicit (IMEX) Runge-Kutta methods for non-hydrostatic atmospheric models, 10.5194/gmd-11-1497-2018, held.
- Category: C5. Pdf 5: "third-order strong stability preserving methods SSP3(333)b and SSP3(333)c from Conde et al. (2017)". The tableau and its order are Conde et al.'s, and Conde et al. is not in INDEX.
- Fix class: b. Fetch, index and read Conde et al. (2017) for the SSP3(333)c tableau and its order, and anchor it beside Gardner.

##### 18 and 20. core.williamson_tc1 and core.williamson_tc5_tc6: norms the paper does not publish
- Where: the thresholds "provisional; published norms for the scheme class" and "provisional; published band"; the anchors.
- Use: the bar's basis.
- Source: A standard test set for numerical approximations to the shallow water equations in spherical geometry, 10.1016/0021-9991(92)90060-c, held.
- Category: C2. The paper defines the cases and the error measures (pdf 18, 19, 24, 25). It defers reference solutions for cases 5 and 6 to a companion report (pdf 9, 24-25) and publishes no norm of any scheme.
- Fix class: b. Find and read a publication that states norms for a comparable scheme class, such as Jakob-Chien, Hack and Williamson (1995) for the spectral reference, or a C-grid TRSK or ICON paper tabulating case 1, 5 and 6 errors. Anchor it and restate the threshold, registry-only. Where none states a residual for a comparable class, decision 0025 makes the metric REPORT.

##### 30. core.jablonowski_williamson_steady: no published bound on the statistic's quantity
- Where: statistic "l2 of surface pressure ... from the analytic steady state"; threshold "provisional; published bound".
- Source: A baroclinic instability test case for atmospheric model dynamical cores, 10.1256/qj.06.12, held.
- Category: C2. The steady-state assessment published is l2 of u - u_bar and of u_bar - u_bar(t=0) for zonal wind (pdf 15-16, Figs 3-4), with no bound. No surface-pressure steady-state norm is published.
- Fix class: b. Restate the statistic as the published zonal-wind norms, or give surface pressure a bar from another read source. Registry-only. REPORT where no residual exists.

##### 31. core.jablonowski_williamson_wave: no published range of minimum surface pressure or breaking time
- Where: statistic and threshold "published multi-model range".
- Source: as in 30.
- Category: C2. The paper publishes day-9 snapshots and l2 surface-pressure differences between cores and resolutions (the uncertainty of the reference solutions, pdf 16 l.170, Figs 10-11). Wave breaking appears only as "around day 9" (pdf 21, 29), and the tables are grids, time steps and wall clock.
- Fix class: b. Restate the statistic as the published l2 surface-pressure difference with the published uncertainty as the band, or anchor a source that tabulates minimum surface pressure across models, such as Ullrich et al. (2014) or DCMIP-2012 results. Registry-only.

##### 32. core.held_suarez: no stated spread in Held and Suarez (1994)
- Where: the threshold "provisional; published spread"; the anchors.
- Source: A Proposal for the Intercomparison of the Dynamical Cores of Atmospheric General Circulation Models, 10.1175/1520-0477(1994)075<1825:apftio>2.0.co;2, held.
- Category: C2. Two models are shown only as contour plots. The hemispheric difference is offered as "a quick estimate of sampling error", and the authors say the agreement "should not be interpreted as implying that the true solution ... has been obtained" and the models "have not yet converged" (pdf 5).
- Fix class: b. Anchor a multi-model Held-Suarez intercomparison that states jet strength and latitude with its spread, or make the entry REPORT. Registry-only.

##### 33 and 34. core.dcmip_small_planet: no published norms
- Where: the threshold "provisional; published norms"; anchors Wedi and Smolarkiewicz (2009), 10.1002/qj.377, held, and the DCMIP-2012 test case document v1.7, held.
- Category: C2. Wedi and Smolarkiewicz compare two models (normalised drag, Fig. 9). The DCMIP-2012 document specifies the small-planet setup and output (pdf 3, 42, 46-47) and defines norms only for tracer tests, with no values. The dataset_or_reference also says "DCMIP 2012/2016", while the anchor is the 2012 document only.
- Fix class: b. Anchor a publication of DCMIP small-planet results with norms, such as the DCMIP-2012 or DCMIP-2016 results papers (ullrich2017-dcmip2016-review is held), or make the entry REPORT. Registry-only.

##### 35. core.held_suarez_rotation_scaling (tier 3): Yang et al. (2019) is not a rotation-rate sweep of the Held-Suarez configuration
- Where: the anchors, with protocol = "held_suarez".
- Use: the inter-model spread of Hadley-cell edge and jet count against rotation rate.
- Source: Simulations of Water Vapor and Clouds on Rapidly Rotating and Tidally Locked Planets: A 3D Model Intercomparison, 10.3847/1538-4357/ab09f1, held.
- Category: C3, with C2. The paper intercompares moist GCMs with radiation and clouds in two configurations (a 1-day rotator under a G star, and a 60-day tidally locked planet under an M star; abstract, pdf 2). It uses no Held-Suarez forcing, no rotation sweep, and no Hadley-edge statistic.
- Fix class: b. Find a published multi-model rotation-rate sweep under Held-Suarez forcing. If none exists, decision 0025 leaves the tier-3 metric REPORT, which changes this unregistered entry's verdict_kind. Registry-only. Worth the user's attention, since it may remove a tier-3 bar.

##### 36. core.hadley_small_rossby_limit: Held and Hou (1980) is axisymmetric theory, named and not anchored
- Where: dataset_or_reference "analytic; Held and Hou scaling"; anchors = []; threshold "the analytic form within discretisation error".
- Source: Nonlinear Axially Symmetric Circulations in a Nearly Inviscid Atmosphere, 10.1175/1520-0469(1980)037<0515:NASCIA>2.0.CO;2, held.
- Category: C3, with the basis not anchored. The theory is for axially symmetric, nearly inviscid, angular-momentum-conserving flow (abstract; section 4b discusses the approximations). A tier-1 identity "within discretisation error" holds only for an axisymmetric configuration in that regime, and the statistic declares none. "The analytic form the published rotation-rate sweeps cite" names no equation.
- Fix class: b. Read Held and Hou and anchor the equation. Declare the axisymmetric configuration and the regime (thermal Rossby number, viscosity) in the statistic, or move the comparison out of tier 1. Registry-only.

##### 37 to 39. column.richards_philip: three analytic bases named and not indexed
- Where: dataset_or_reference (Philip infiltration series; Srivastava and Yeh transient solution; Gardner steady evaporation); anchors = [].
- Category: C6. None of the three is in INDEX or REQUESTS, and none is read.
- Fix class: b. Index and read the three primaries, anchor them with the equation used, and give the "2 percent" a basis or state it as a derived tolerance. Registry and INDEX.

##### 40. hydro.groundwater_dupuit: the held file is the wrong edition
- Where: the anchor "Etudes theoriques et pratiques sur le mouvement des eaux dans les canaux decouverts et a travers les terrains permeables (Google Books scan)".
- Source: INDEX dupuit1863-etudes-theoriques-et-pratiques-sur.pdf, held, "Second edition, Dunod, Paris (1863) ... (to confirm the ark against the 2nd edition)".
- Category: C4, with C2.
  - The scan's title page (pdf 5) reads "ETUDES THEORIQUES ET PRATIQUES SUR LE MOUVEMENT DES EAUX COURANTES", dated 1848 (pdf 7). That is the first edition.
  - No page matches "permeable".
  - The only "filtration" (pdf 228) is seepage under a levee.
  - The Dupuit groundwater treatment the entry rests on is not in the held file.
- Fix class: b. Fetch the 1863 second edition (open access, public domain; Gallica or Google Books), identify it by its title page, replace the held file, read the permeable-ground chapter, and anchor the equation. Correct the INDEX row. Anchor Forchheimer too if the Dupuit-Forchheimer form is his.

##### 43 and 44. ocean.teos10_check_values and ocean.freezing_point_check_values: the manual publishes no check values
- Where: the thresholds "the manual's stated check-value precision", the anchors, and dataset_or_reference "(published check values)".
- Source: The international thermodynamic equation of seawater - 2010, IOC Manuals and Guides No. 56, held.
- Category: C2. Pdf 183 (Appendix M): "Numerical check values are provided with each of the routines in the library", meaning the SIA library, with Feistel et al. (2010b) and Wright et al. (2010) cited. The manual's own tables (e.g. Table 3.42.1, pdf 76) are selected values with no precision stated.
- Fix class: b. Anchor the source that states the check values and their precision: the GSW toolbox check-value documentation (McDougall and Barker 2011, Getting started with TEOS-10 and the GSW Oceanographic Toolbox) or Wright et al. (2010) for the SIA library. Read it, and restate "manual" as that source. Registry and INDEX.

##### 46 and 47. ocean.carbonate_check_values: the package reference values and Mucci are not anchored
- Where: dataset_or_reference and threshold ("reference values of the adopted carbonate-chemistry package", "the package's stated reference precision", "Mucci 1983 stated domains").
- Category: C2 for the package values, since no anchor states them and Lueker 2000 does not. C6 for Mucci (held, named, not anchored).
- Fix class: b. Anchor the adopted package's published reference values and their precision, read. Read Mucci (1983) for its stated domain and anchor it.

##### 49. ocean.strait_control_identity: a review stands in for the primary
- Where: the anchors "Topographic control of oceanic flows in deep passages and straits" (Whitehead 1998, 10.1029/98rg01014, held, Reviews of Geophysics).
- Category: C5. Eqs (12)-(13) (pdf 5) are the zero-potential-vorticity solutions of "[Whitehead et al., 1974]" (pdf 4), and that primary is not in INDEX.
- Fix class: b. Index and read Whitehead, Leetmaa and Knox (1974) for the control forms and the limits, and anchor it. Keep Whitehead (1998) for the geometry of the limits if wanted.

##### 50. physics.monin_obukhov_neutral: "published function" names no source
- Where: the threshold "provisional; published function to 1e-6"; anchors = [].
- Category: C2. The basis is unnamed. INDEX holds Businger et al. (1971) and Monin and Obukhov (1954), held, and neither is anchored.
- Fix class: b. Name and read the source of the neutral log-law drag coefficient and anchor it, or state the check as the closed form C_D = (k/ln(z/z0))^2 with k anchored. Give the 1e-6 a derivation.

#### Observations, not verdicts

- Every registry anchor is a title with no locator. Where the statistic or threshold carries page and equation locators (core.checkerboard_divergence_mode, core.hollingsworth_check, core.fsphere_normal_modes), those locators check out. The others carry none.
- Anchors on held rows in this range: Gardner 2018, Williamson 1992, Jablonowski and Williamson 2006, Held and Suarez 1994, Wedi and Smolarkiewicz 2009, DCMIP-2012, Yang 2019, Dupuit, Stommel 1948, Munk 1950, IOC 2010, Lueker 2000, Hibler 1979, Whitehead 1998, Charnock 1955, Halfar 1981 and 1983, Bahr 1997, Farquhar 1980, Kahan 1965, Wagner and Pruss 2002, Lemmon and Jacobsen 2004, Fuller 1966. docs/references/README.md refuses an oracle bar whose reference is not read, so each must be read with a locator before its entry is registered.
- system.kepler_period rests on Markley eqs 30-35 in its threshold (read), but Markley is not in its anchors.
- Provisional tolerances with no stated basis: core.imex_convergence_order (0.2), core.mms_convergence_order (0.3), column.richards_philip (2 percent). None cites a source, so none is counted as a citation.
- cryo.halfar_gravity_scaling judges a pressure-melting depth against 1/(rho_i g) with no anchor for that form.

#### Fetch failures and paywalled sources

No fetch was attempted: every source this scope's anchors name is on disk. These primaries are missing, and fixes above need them; identifiers are from memory and are to be confirmed against Crossref before fetching:
- Implicit and implicit-explicit strong stability preserving Runge-Kutta methods with high linear order (Conde, Gottlieb, Grant, Shadid 2017), J. Sci. Comput. 73, 667-690, DOI 10.1007/s10915-017-0560-2 to confirm; an arXiv copy is believed to exist.
- Spectral transform solutions to the shallow water test set (Jakob-Chien, Hack, Williamson 1995), J. Comput. Phys. 119, 164-187, DOI 10.1006/jcph.1995.1125 to confirm.
- Rotating hydraulics of strait and sill flows (Whitehead, Leetmaa, Knox 1974), Geophys. Fluid Dyn. 6, 101-125, DOI 10.1080/03091927409365790 to confirm; likely paywalled.
- Etudes theoriques et pratiques sur le mouvement des eaux dans les canaux decouverts et a travers les terrains permeables, 2nd edition, Dunod, Paris 1863; public domain (Gallica or Google Books).
- Philip's infiltration series, Srivastava and Yeh's transient solution, Gardner's steady evaporation solution, and Blanc's mixture law: the exact papers are not identified in the registry; titles to be established before fetching.

### R2: Registry, lines 1376 to 2111


Entries from fire.rothermel_published_cases to earth.fluxnet_gpp. Exact identities with anchors = [] and no named source
(ped.hydraulic_frame_check, bio.two_rotation_frost_fixture, rad.blackbody_identities, rad.ktable_grid_extrapolation,
oracles.*, provenance.*, loop.*, repro.*) carry no citation and are not counted.

A citation here is: each anchor; each source named in dataset_or_reference or threshold that the entry rests on; each
stated or implied bar basis of a fail_bar entry; each datasets field (checked against its manifest).

#### Counts

- total citations: 57
- FIT: 20
- NOT FIT: 34 (of which 12 are fail_bar numbers with no stated basis at all, category C7)
- NOT VERIFIED: 3

Systemic, beside the per-citation verdicts: every one of the 32 anchors in this range resolves to an INDEX.md row with
status `held` (none `read`), including rows whose passage does fit. The statistic of oracles.registry_wellformed
(line 1531) says it checks "anchors that resolve to rows marked read in docs/references/INDEX.md", and
fiddlybits-52v.8.7 closed with that check reporting PASS on the tree. Either the check resolves titles without reading
status, or it is not run on these rows; the parent should verify (outside this scope: src/Oracles, test/oracles). If it
does not check status, that clause cannot fail as written (C6, systemic).

#### Every citation

| # | where | use | source (INDEX row, status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | fire.rothermel_published_cases anchors (l.1388); dataset_or_reference (l.1380) | published spread cases incl. a slope case, matched "to the source's stated precision"; fixture declares gravity, air density, O2 partial pressure "as the source's" | rothermel1972-mathematical-model-fire-spread-wildland-fuels.pdf, 10.2737/INT-RP-115, held | none | NOT FIT C2 | Wind and slope coefficients fitted to lab wind-tunnel and slope burns (pp. 21-24, PDF 0028-0031, Fig. 22 slope correlation); fuel-model predictions shown only as curves (Fig. 24-25, PDF 0044); tunnel "temperatures held between 85 and 90 F; relative humidities between 20 and 25 percent" (PDF 0028); no tabulated cases with a stated precision, and no gravity, air density, pressure or O2 level stated anywhere (text grep) |
| 2 | fire.oxygen_flammability_window anchors (l.1403), dataset_or_reference | lower edge of a Sourced flammability window "in O2 partial pressure" | belcher2010-baseline-intrinsic-flammability-earth-ecosystems.pdf, 10.1073/pnas.1011974107, held | none | NOT FIT C3 | "self-sustaining smoldering combustion does not occur below 16% O2" (p. 22449, PDF 0002); abstract: "suppressed below 18.5% O2, entirely switched off below 16% O2" (p. 22448); measured "in atmospheres of different oxygen concentrations" on peat smoldering: a percent concentration at ambient total pressure, not a partial pressure |
| 3 | fire.oxygen_flammability_window anchors (l.1403) | window edge(s) in O2 partial pressure; REQ-BIO-015 cites Watson for "the lower limit" | watson1978-methanogenesis-fires-regulation-atmospheric-oxygen.pdf, 10.1016/0303-2647(78)90012-6, held | none | NOT FIT C2, C3, C5 | Fig. 1 (PDF 0003): relative ignition probability vs "oxygen concentration" 20-35 percent, derived from minimum ignition energies "experimentally determined (Watson, 1978)" (a thesis) mapped through a fire-danger "ignition component" table; text: "At atmospheric levels between 25 and 35% the increasing probability of fire would be incompatible with the existence of land based vegetation". No lower limit stated; the upper statement is a 25-35 percent argument, in concentration at the present atmosphere; the experiments are reported secondhand from the thesis |
| 4 | rad.broadening_partner_identity anchors (l.1506) | HITRAN carries per-perturber (H2, He, CO2) widths for some absorbers | wilzewski2016-h2-he-co2-line-broadening-coefficients-part-1.pdf, 10.1016/j.jqsrt.2015.09.003, held (article-in-press proof) | none | FIT | Title and abstract (PDF 0001): "line-broadening coefficients, line shifts and temperature-dependence exponents of molecules of planetary interest broadened by H2, He, and CO2" for SO2, NH3, HF, HCl, OCS, C2H2. Supports the premise for those six molecules only |
| 5 | rad.broadening_partner_identity dataset_or_reference (l.1498) | "Tan et al. 2019" as second per-perturber source | not anchored; INDEX l.922 tan2022-h2-he-co2-pressure-induced-parameters-part-ii.pdf, 10.3847/1538-4365/ac83a6, held | none | NOT FIT C4 | INDEX row: "Tan et al. 2022, ApJS; the records cite it as JQSRT 2019, to be corrected". Tan 2022 PDF 0003: "Since the Wilzewski et al. (2016) effort was dubbed as Part I, the current paper has Part II added" |
| 6 | rad.grey_eddington dataset_or_reference (l.1441) | Eddington isothermal grey slab; Guillot two-band T(tau) | not anchored; INDEX l.607 guillot2010-radiative-equilibrium-irradiated-planetary-atmospheres.pdf, 10.1051/0004-6361/200913396, held | none | FIT (unanchored) | Abstract: "a simple analytical approach inspired by Eddington's approximation ... a relation between temperature and optical depth valid for plane-parallel static grey atmospheres ... parameterized as a function of mean visible and thermal opacities"; "the standard Eddington relation is recovered" (arXiv 1006.4702 p. 4). Passage fits; the entry has anchors = [] |
| 7 | rad.line_by_line_reference dataset_or_reference, threshold (l.1455, 1460) | RFMIP LBL fluxes; tolerance = "the reference's own stated accuracy" | not anchored; INDEX l.729 pincus2016-radiative-forcing-model-intercomparison-project.pdf, 10.5194/gmd-9-3447-2016, held | none | NOT FIT C2 | Protocol paper: "Reference calculations will be some combination of line-by-line modeling at reduced spectral resolution..." (PDF 0007); no stated accuracy of the reference fluxes anywhere (grep "accura" returns only aims). The threshold's basis is not stated by any indexed source |
| 8 | rad.band_albedo_broadband_check dataset_or_reference, threshold (l.1484, 1488) | "published surface reflectance spectra and their broadband values"; 0.01 | none named | none | NOT FIT C2 | No work identified for the spectra, their broadband values, or the 0.01 tolerance |
| 9 | earth.ceres_clear_sky_olr_zonal anchors (l.1768) | CERES EBAF Ed4.2 climatology | loeb2018-clouds-earth-s-radiant-energy.pdf, 10.1175/jcli-d-17-0208.1, held | none | NOT FIT C4 | Abstract (PDF 0001): "EBAF top-of-atmosphere (TOA), Edition 4.0 (Ed4.0), data product is described. EBAF Ed4.0 is an update to EBAF Ed2.8"; Ed4.2 not described; no manifest (datasets = []) |
| 10 | earth.ceres_clear_sky_olr_zonal anchors | ERA5 profiles driving the column offline | hersbach2020-era5-global-reanalysis.pdf, 10.1002/qj.3803, held | none | FIT | ERA5 described "spanning 1979 onwards" (PDF 0002) |
| 11 | earth.ceres_clear_sky_olr_zonal threshold (l.1764) | fail_bar 5 W m-2 | none | none | NOT FIT C7 | No basis stated; decision 0025: a FAIL bar only from a published model's own residual or a physical constraint, else REPORT |
| 12 | earth.ceres_toa_balance anchors (l.1783) | CERES EBAF Ed4.2 | loeb2018, held | none | NOT FIT C4 | as #9 |
| 13 | earth.ceres_toa_balance threshold (l.1779) | fail_bar 2 W m-2 | none | none | NOT FIT C7 | No basis stated. User decision 2026-09-14 (decision 0025 amendment) moves this entry to tier 1 as an energy-conservation criterion; carried by fiddlybits-52v.8.13 to 52v.8.23 |
| 14 | earth.ceres_global_means anchors (l.1798) | CERES EBAF Ed4.2 | loeb2018, held | none | NOT FIT C4 | as #9 |
| 15 | earth.ceres_cre_zonal anchors (l.1813) | CERES EBAF Ed4.2 | loeb2018, held | none | NOT FIT C4 | as #9 |
| 16 | earth.era5_zonal_temperature anchors (l.1830) | ERA5 1991-2020 monthly climatology | hersbach2020, held | none | FIT | as #10 |
| 17 | earth.era5_zonal_temperature threshold (l.1826) | fail_bar 4 K | none | none | NOT FIT C7 | No basis stated |
| 18 | earth.era5_jet_latitude anchors (l.1845) | ERA5 | hersbach2020, held | none | FIT | as #10 |
| 19 | earth.era5_jet_latitude threshold (l.1841) | fail_bar 5 degrees | none | none | NOT FIT C7 | No basis stated |
| 20 | earth.era5_hadley_edge anchors (l.1860) | ERA5 | hersbach2020, held | none | FIT | as #10 |
| 21 | earth.era5_hadley_edge threshold (l.1856) | fail_bar 4 degrees | none | none | NOT FIT C7 | No basis stated |
| 22 | earth.era5_structure_report anchors (l.1875) | ERA5 | hersbach2020, held | none | FIT | report entry; as #10 |
| 23 | earth.gpcp_global_mean anchors (l.1892), dataset_or_reference "GPCP v2.3 or v3.2" | GPCP product | adler2018-global-precipitation-climatology-project-gpcp.pdf, 10.3390/atmos9040138, held | none | NOT FIT C4 | Adler 2018 describes "the new Version 2.3" (PDF 0002, sec. 2 "Changes ... from V2.2 to V2.3"); V3.2 has no anchor and the entry leaves the version open |
| 24 | earth.gpcp_global_mean threshold (l.1888) | fail_bar 15 percent | none | none | NOT FIT C7 | No basis stated |
| 25 | earth.gpcp_zonal_rms anchors (l.1907) | GPCP (unversioned) | adler2018, held | none | FIT | V2.3 described (PDF 0002); note the version inherits #23's ambiguity |
| 26 | earth.gpcp_zonal_rms threshold (l.1903) | fail_bar 1.2 mm per 86400 s | none | none | NOT FIT C7 | No basis stated |
| 27 | earth.gpcp_land_ocean_split anchors (l.1922) | GPCP | adler2018, held | none | FIT | report entry |
| 28 | earth.land_pme_vs_runoff anchors (l.1937) | GRDC/Fekete global runoff composite | fekete2002-high-resolution-fields-global-runoff.pdf, 10.1029/1999GB001254, held (no extracted text; read by pdftotext) | none | FIT | Abstract p. 1: "The resulting composite runoff fields (UNH/GRDC Composite Runoff Fields V1.0) are released" |
| 29 | earth.land_pme_vs_runoff threshold (l.1933) | fail_bar 25 percent | none | none | NOT FIT C7 | No basis stated; Fekete Table 4 compares continental runoff estimates (Korzoun 1977, GRDC, this study), an observational spread, not a model residual |
| 30 | earth.hydrolakes_terminal_lakes anchors (l.1954) | HydroLAKES observed lake areas | messager2016-estimating-volume-age-water-stored.pdf, 10.1038/ncomms13603, held | none | FIT | "HydroLAKES ... contains the shoreline polygons of 1.43 million individual lakes and reservoirs" (PDF 0002) |
| 31 | earth.hydrolakes_terminal_lakes anchors | HydroBASINS catchments | lehner2013-global-river-hydrography-network-routing.pdf, 10.1002/hyp.9740, held | none | FIT (weak) | Table I (p. 2177, PDF 0007): HydroSHEDS layers "assigned to the river or sub-basin network at 15 arc-second", including "Sub-basin delineation". The name HydroBASINS does not occur in the text; the product's own documentation is not indexed |
| 32 | earth.hydrolakes_terminal_lakes anchors | observed terminal-lake area (main: "lake area"; k6b branch: "long-term mean lake area") | lehner_2025_mapping-the-world-s-inland-surface-waters-an-upgrade-to-the-global-lak.pdf, 10.5194/essd-17-2277-2025, held | none | NOT FIT C3 | "GLWD v2 represents maximum extents of wetland ecosystems as a static map over the broad contemporary period of 1984-2020" (PDF 0005); lakes were "extracted from the polygons of the HydroLAKES database" (PDF 0011). A maximum extent is not the equilibrium or long-term mean area the relation predicts, and its lake class is HydroLAKES again. The k6b branch keeps this anchor |
| 33 | earth.hydrolakes_terminal_lakes datasets (l.1947) | the held data the entry reads | docs/oracles/data/copernicus-dem-90m.toml | manifest | NOT FIT C2 | The manifest is the Copernicus DEM GLO-90 (four regions), not HydroLAKES, HydroBASINS or GLEV. Carried by fiddlybits-k6b (moves the DEM to earth.copernicus_dem_spill_cap, datasets = [] here) and fiddlybits-hpp (fetch HydroLAKES and HydroBASINS) |
| 34 | earth.hydrolakes_terminal_lakes dataset_or_reference "GLEV terminal-lake extract" (l.1945) | observation | not anchored, not in INDEX | none | NOT VERIFIED | No INDEX row, no manifest; the k6b branch drops GLEV |
| 35 | earth.hydrolakes_terminal_lakes threshold (l.1950) | median edge 0.60; abs(r) > 0.3 | none | none | NOT FIT C7 | No basis stated (0.60 is the predecessor's marginal edge; 0.3 was written at the founding). Carried by fiddlybits-k6b and the user decisions of 2026-09-14 recorded there (median 0.30 on the pre-registration; correlation edge option C with option B, derived from measurement uncertainty) |
| 36 | earth.fan_water_table anchors (l.1969) | "Fan et al. water table depth and bore compilation, with the published model's own residual statistics", on US (nwis-gw) and Australian (aus-groundwater) bores | fan_2007_incorporating-water-table-dynamics-in-climate-modeling-1-water-table-o.pdf, 10.1029/2006JD008111, held | none | NOT FIT C4 | Fan 2007 sec. 3.6 (PDF 0012-0013): continental-US 1.25 km model, 261,449 cells, residual histogram shifted 2 m, "12% ... within 1 m, 24% within 2 m, 44% within 5 m, 66% within 10 m": US only, no Australia. REQ-HYD-002 and the aus-groundwater manifest anchor cite Fan et al. 2013's Australia-and-Asia residuals (supplement S3.5, Fig. S11, PDF 0016 and 0031). Fan 2013 is `read` (INDEX l.387-388) but "for the method and the dataset", not the residual statistics |
| 37 | earth.fan_water_table threshold (l.1965) | fail_bar: "the published model's own residual bars, plus the skill requirement" | REQ-HYD-002 (docs/requirements/hyd/water-table-skill-oracle.md) | "What this system must do", "Why it carries" | NOT FIT C7 | REQ-HYD-002: "a published model's residual bars are REPORT metrics, not PASS bars, unless the observation set is the same"; FAIL only if residual SD >= observed SD or R^2 below the free-geography baseline; "REPORT for Fan et al. 2013's own residual statistics". The entry fails on residual bars from another model's observation set |
| 38 | earth.fan_water_table datasets (l.1962) | bore observations | docs/oracles/data/aus-groundwater.toml (BoM NGIS, 8 jurisdictions); nwis-gw.toml (USGS 72019, doi 10.5066/F7P55KJN) | manifests | FIT | Manifests name the observation sets REQ-HYD-002 scores, each naming earth.fan_water_table in oracles |
| 39 | earth.grdc_basin_discharge anchors (l.1984) | "GRDC long-term means, 20 largest basins" | fekete2002, held | none | NOT FIT C2 | Fekete 2002 builds composite runoff fields from GRDC interstation regions (abstract p. 1) and tabulates discharge by continent and receiving body (Table 3) and continental runoff (Table 4); it gives no long-term means for the 20 largest basins. The observation is the GRDC station archive, which has no INDEX row or manifest |
| 40 | earth.grdc_basin_discharge threshold (l.1980) | fail_bar median 0.2, bias 0.1 | none | none | NOT FIT C7 | No basis stated |
| 41 | earth.basalt_granite_clay_divergence anchors (l.2001) | "sign and magnitude of clay divergence between basalt and granite under one climate" | oyebanjo2021-clay-fractions-parent-rocks-limpopo.pdf, 10.1016/j.heliyon.2021.e07664, held (no extracted text; read by pdftotext) | none | NOT FIT C3, C2 | Table 1a (p. 3): basalt/Sibasa "Semi-Arid, dry hot (BSh)"; granite/Matoks "Warm temperate, winter dry, hot summer (CWa)": two climates, not one. Table 2 (p. 4) reports mineralogy of the clay fraction (kaolinite average 74.50 wt% basalt, 27.50 granite), not clay content or a clay divergence of the soil |
| 42 | earth.basalt_granite_clay_divergence threshold (l.1997) | fail_bar sign; magnitude within factor 2 | none | none | NOT FIT C7 | No basis stated for the factor 2 |
| 43 | earth.soilgrids_ph_by_zone anchors (l.2016) | SoilGrids 250 m pH | poggio2021-soilgrids-2-0-producing-soil.pdf, 10.5194/soil-7-217-2021, held | none | FIT | Abstract (PDF 0001): global predictions for "pH (water)" among the properties; report entry |
| 44 | earth.soilgrids_ph_by_zone anchors | GLiM lithology | hartmannmoosdorf2012-glim-lithological-map.pdf, 10.1029/2012GC004370, held | none | FIT | "The first level contains 16 lithological classes" (PDF 0001) |
| 45 | earth.soilgrids_ph_by_zone dataset_or_reference "Pelletier soil thickness" (l.2007) | regolith depth distribution | not anchored, not in INDEX | none | NOT VERIFIED | One fetch attempt of the open-access paper failed (publisher returned HTML) |
| 46 | earth.hartmann_phosphorus_yield anchors (l.2031) | "published per-class range" of P release; outside it fails on the Earth instance | hartmann2011-japan-silicate-weathering-phosphorus.pdf, 10.1016/j.chemgeo.2010.12.004, held | none | NOT FIT C3, C7 | Sec. 3.8 (p. 150-151, PDF 0027): P-release "calculated here assuming that P is released at the same rate as the bulk of rock-minerals is dissolved, as a first estimate"; "Results for the Japanese Archipelago cover the typical release-ranges of ~1 to 100 kg P km-2 a-1 reported in literature"; "The usage of an average geochemical composition per lithological class ... introduces uncertainty that cannot be quantified here". A regional model's first estimate for Japan, not an observed range and not a model residual |
| 47 | earth.hartmann_phosphorus_yield dataset_or_reference "Hartmann et al. 2014 global release" (l.2022) | global release per class | not anchored; INDEX l.392 hartmann2014-weathering-phosphorus-release.pdf, 10.1016/j.chemgeo.2013.10.025, held | none | NOT VERIFIED | Text grep: global P-release map (Fig. 6, PDF 0008) and "Chemical weathering rates and P-release for selected regions" (PDF 0009); a per-class range was not located; INDEX row: "its Table A1-2 is composition, not release" |
| 48 | earth.modis_albedo_by_class anchors (l.2048) | MCD43C3 v061 daily 0.05 degree black-sky and white-sky albedo | schaaf2002-first-operational-brdf-albedo-nadir.pdf, 10.1016/s0034-4257(02)00091-3, held | none | NOT FIT C4 | Schaaf 2002 describes the at-launch product: BRDF parameters for areas "viewed ... at least once over a 16-day period" (PDF 0004), "during a 16-day period, a full model inversion" (PDF 0003). The manifest (mcd43c3.toml) is V061 "Model Parameters Daily", doi 10.5067/MODIS/MCD43C3.061: a later collection with a daily retrieval the anchor does not describe |
| 49 | earth.modis_albedo_by_class anchors | MCD12C1 V061 land cover key | INDEX l.711 oracles/data/mcd12c1 (dataset), 10.5067/MODIS/MCD12C1.061, held | manifest | FIT | Manifest doi, V061 and window 2001-2020 match the INDEX title |
| 50 | earth.modis_albedo_by_class datasets (l.2041) | mcd43c3, mcd12c1 | manifests | manifest | FIT | Both manifests V061, both name the entry back |
| 51 | earth.modis_albedo_by_class threshold (l.2044) | fail_bar 0.03 per class mean | none | none | NOT FIT C7 | No basis stated |
| 52 | earth.modis_lai_seasonal anchors (l.2063) | MODIS MOD15 LAI | myneni2002-global-products-leaf-area-fpar-modis.pdf, 10.1016/S0034-4257(02)00074-3, held (read by pdftotext) | none | FIT | Title and algorithm description of the MODIS LAI/FPAR products; report entry, no version named. The future "ILAMB-class median bar" in the threshold names no source |
| 53 | earth.biome_kappa anchors (l.2078) | ESA CCI land cover product | bontemps2012-revisiting-land-cover-observation-climate-modeling.pdf, 10.5194/bg-9-2145-2012, held (read by pdftotext) | none | NOT FIT C2, C4 | Abstract p. 2145: "consultation mechanisms were established with the climate modeling community to identify its specific requirements ... Decoupling the stable and dynamic components ... were proposed": a requirements paper that precedes the CCI land cover maps; it does not describe the product or a version the entry reads |
| 54 | earth.plumber2_sites anchors (l.2093) | PLUMBER2 site data | ukkola2022-flux-tower-dataset-land-model-evaluation.pdf, 10.5194/essd-14-449-2022, held (read by pdftotext) | none | FIT | Abstract: "the resultant 170-site globally distributed flux tower dataset specifically designed for use in land modelling. The dataset underpins the second phase of ... PLUMBER" |
| 55 | earth.plumber2_sites threshold (l.2089) | fail_bar "the PLUMBER2 median model" | ukkola2022 (anchor) | none | NOT FIT C2 | The dataset paper reports no model results. The MIP results paper (Abramowitz et al. 2024, fetched) ranks each model against empirical benchmark models ("each LM was ranked against benchmark models from best to worst-performing"); a "median model" is not located in either text |
| 56 | earth.fluxnet_gpp anchors (l.2108) | FLUXNET site GPP | pastorello2020-fluxnet2015-dataset-oneflux-processing-pipeline.pdf, 10.1038/s41597-020-0534-3, held | none | FIT | "GPP_NT_VUT_REF and GPP_DT_VUT_REF for GPP" (PDF 0014); report entry |
| 57 | earth.fluxnet_gpp dataset_or_reference "global GPP, NPP and soil carbon compilations" (l.2099) | global totals | none named | none | NOT FIT C2 | No work identified for the global-totals constituent |

#### NOT FIT cases

##### 1. fire.rothermel_published_cases: Rothermel 1972
- Use: published spread cases, a slope case among them, matched to "the source's stated precision"; the fixture declares gravity, air density and O2 partial pressure "as the source's".
- Category: C2.
- Wrong: the report carries fitted coefficients and graphical predictions with no stated precision. It states none of gravity, air density, pressure or O2 level, so the fixture's declared values cannot be "the source's"; they would be Earth values supplied silently, which borders on C8.
- Evidence: PDF 0028-0031 (Evaluation of wind and slope coefficients, Fig. 22); PDF 0044 (Fig. 24-25); tunnel conditions only temperature and humidity (PDF 0028).
- Fix class (b). Read the source for tabulated cases, or name a source with tabulated cases and their precision (for example Albini 1976, which the requirement cites). State the laboratory conditions from a source that gives them. Registry-only row; REQ-BIO-015 wording is outside this scope.

##### 2. fire.oxygen_flammability_window: Belcher et al. 2010
- Use: window edge in O2 partial pressure, for any declared total pressure.
- Category: C3.
- Wrong: the thresholds are O2 concentrations in percent, from smoldering peat at ambient laboratory pressure. Nothing in the paper says the limit is a partial-pressure limit independent of total pressure and diluent.
- Evidence: p. 22448 abstract; p. 22449 (PDF 0002), "does not occur below 16% O2".
- Fix class (b). Find and read a source on how flammability limits depend on total pressure and diluent; restate the window variable as the source measured it, with its regime declared. Registry text change, registry-only. If REQ-BIO-015's "evaluated on the declared O2 partial pressure and total pressure" is kept, it needs that source.

##### 3. fire.oxygen_flammability_window: Watson et al. 1978
- Use: the window's lower limit (REQ-BIO-015 l.219), as a window edge in O2 partial pressure.
- Categories: C2, C3, C5.
- Wrong:
  - No lower limit is stated; Fig. 1 starts at 20 percent.
  - The upper statement is an argument over 25-35 percent concentration.
  - The measurements are Watson's thesis (the primary), reported here through an ignition-component mapping.
- Evidence: PDF 0003, Fig. 1 caption and text.
- Fix class (b). Drop Watson as the lower-limit source; Belcher 2010 carries the lower limit. For an upper limit, fetch or request the primary. INDEX says decision 0021 also cites Watson; that is the decisions scope's to check.

##### 5. rad.broadening_partner_identity: "Tan et al. 2019"
- Category: C4.
- Wrong: the held work is Tan et al. 2022, ApJS, 10.3847/1538-4365/ac83a6. INDEX l.922 already records the mis-citation.
- Fix class (a) for the text: "Tan et al. 2019" to "Tan et al. 2022". Adding it as an anchor needs a read, so that part is (b).
- registry.toml is edited by open branches k6b, 52v.6.26 and 52v.8.13.

##### 7. rad.line_by_line_reference: RFMIP, "the reference's own stated accuracy"
- Category: C2.
- Wrong: the protocol paper states no accuracy for the line-by-line reference, and the entry has no anchor.
- Evidence: Pincus 2016, PDF 0007.
- Fix class (b). Anchor Pincus 2016 for the profiles. The line-by-line results with their stated accuracy are in the RFMIP benchmark paper, which is not held; its title and identifier need confirming before fetch (it is believed to be Pincus et al. 2020, JGR Atmospheres, "Benchmark calculations of radiative forcing by greenhouse gases", open access).

##### 8. rad.band_albedo_broadband_check: unnamed published spectra, 0.01
- Category: C2.
- Fix class (b). Name the spectra and their published broadband values; the INDEX radiation section holds candidate spectral libraries. Derive or source the tolerance.

##### 9, 12, 14, 15. earth.ceres_*: CERES EBAF Ed4.2 against the Ed4.0 paper
- Category: C4.
- Evidence: Loeb 2018 abstract, "Edition 4.0 (Ed4.0)".
- Fix class (b). Pin one edition for all four entries, and anchor the matching product document (the CERES EBAF Ed4.2 data quality summary, NASA LaRC, open access) or declare Ed4.0. This touches dataset_or_reference and anchors only.

##### 11, 17, 19, 21, 24, 26, 29, 40, 42, 51. Tier-2 fail_bar numbers with no stated basis
Entries: ceres_clear_sky_olr_zonal 5 W m-2, era5_zonal_temperature 4 K, era5_jet_latitude 5 degrees, era5_hadley_edge 4 degrees, gpcp_global_mean 15 percent, gpcp_zonal_rms 1.2 mm per 86400 s, land_pme_vs_runoff 25 percent, grdc_basin_discharge 0.2 and 0.1, basalt_granite_clay_divergence factor 2, modis_albedo_by_class 0.03.
- Category: C7. Decision 0025 takes a FAIL bar only from a published model's own residual or a physical constraint, "Where no comparable published residual exists, the metric is REPORT"; each entry is marked "provisional" and none has a registered_at.
- Fix class (b). One registry-only row: for each entry, find and read a published model residual of comparable class and state it as the basis with bar_half_width and observation_uncertainty, or restate the entry as report per the rule.
- None is registered, so no registered bar moves. The rule decides report where no residual exists; the verdict_kind changes are listed below for the user's view.

##### 13. earth.ceres_toa_balance: 2 W m-2
- Category: C7.
- Already carried: the user decision of 2026-09-14 moves it to tier 1 as an energy-conservation criterion (fiddlybits-52v.8.13 to 52v.8.23). The tier-1 tolerance then needs its derivation stated.

##### 23. earth.gpcp_global_mean: "GPCP v2.3 or v3.2"
- Category: C4.
- Fix class (b). Pin one version. For V3.2, fetch and read its paper (the GPCP V3.2 description, Huffman et al. 2023, J. Hydrometeorology; identifier to confirm) and anchor it; otherwise drop "or v3.2". Applies to all three gpcp entries.

##### 32. earth.hydrolakes_terminal_lakes: GLWD v2 as the observed lake area
- Category: C3.
- Evidence: Lehner 2025, PDF 0005 ("maximum extents ... static map over 1984-2020") and PDF 0011 (lakes taken from HydroLAKES).
- Still present on the fiddlybits-k6b branch, now under a "long-term mean lake area" statistic.
- Fix class (b), inside k6b's boundary (registry.toml): drop the GLWD v2 anchor from the equilibrium entry, or state the use it fits. Raise on k6b before it merges.

##### 33, 35. earth.hydrolakes_terminal_lakes: datasets = copernicus-dem-90m; bars 0.60 and 0.3
- Categories: C2 (dataset) and C7 (bars).
- Carried by fiddlybits-k6b (split, datasets moved, median 0.30 on the pre-registration with its uncertainty argument), fiddlybits-hpp (HydroLAKES and HydroBASINS data) and fiddlybits-xh8 (spill-cap uncertainty). The correlation edge is carried by the user's decision of 2026-09-14 recorded on k6b.
- Note for the parent: on k6b the median edge's basis is the predecessor's pre-registration, not a published model residual or a physical constraint. Whether a pre-registration is an accepted basis under decision 0025 is a question the user's k6b decision already settled in shape (option a); it is recorded here, not re-raised.

##### 36. earth.fan_water_table: Fan 2007 anchor
- Category: C4. The residuals are continental US only; the Australian arm's bars are Fan 2013 (REQ-HYD-002; supplement S3.5, Fig. S11).
- Fix class (b). Anchor Fan et al. 2013 and its supplement, already `read` for method and dataset, and extend that read to S3.5 and Fig. S11 (figure values are not in the text layer). Keep Fan 2007 only for the US arm, if the entry reports US residuals.

##### 37. earth.fan_water_table: residual bars as fail_bar
- Category: C7. REQ-HYD-002 makes Fan's residual statistics REPORT and the FAIL skill-based (residual SD against observed SD; R^2 against the free-geography baseline computed in the same run).
- Fix class (b), registry-only, following decision 0053. Split into a skill fail_bar entry, whose bar is a physical-skill criterion from the same run, and a report entry for Fan 2013's residuals. Unregistered, so no registered bar changes.

##### 39. earth.grdc_basin_discharge: Fekete 2002 for GRDC long-term basin means
- Category: C2.
- Fix class (b). Anchor the GRDC station archive (a dataset manifest and INDEX row) and name the 20 basins. Fekete 2002 stays for the runoff composite.

##### 41. earth.basalt_granite_clay_divergence: Oyebanjo 2021
- Categories: C3 and C2. The two climates differ (BSh against CWa, Table 1a), and the paper reports clay-fraction mineralogy (Table 2), not clay divergence.
- Fix class (b). Find a same-climate basalt and granite soil pair with clay contents (a toposequence or chronosequence study), or restate the statistic as what Oyebanjo measures, with its climates declared.

##### 46. earth.hartmann_phosphorus_yield: Hartmann 2011 per-class range
- Categories: C3 and C7. A Japanese-Archipelago first estimate from a linear runoff model is used as a global fail range.
- Evidence: sec. 3.8, PDF 0027.
- Fix class (b). Report against Hartmann et al. 2014's global estimate, after reading it for a per-class quantity, or find an observed per-class release range with its uncertainty. A fail_bar needs a model residual.

##### 48. earth.modis_albedo_by_class: Schaaf 2002 for MCD43C3 V061 daily
- Category: C4.
- Fix class (b). Fetch and read the V006/V061 algorithm documentation, which is open access: the MCD43 user guide, and Wang et al. 2018, Remote Sensing of Environment, "Capturing rapid land surface dynamics with Collection V006 MODIS BRDF/NBAR/Albedo (MCD43) products" (identifier to confirm). Anchor it beside Schaaf 2002.

##### 53. earth.biome_kappa: Bontemps 2012 for the ESA CCI land cover product
- Categories: C2 and C4.
- Fix class (b). Fetch the ESA CCI Land Cover Product User Guide for the version read (open access), anchor it and pin the version; keep Bontemps 2012 only for the requirements framing, if that is used.

##### 55. earth.plumber2_sites: "the PLUMBER2 median model"
- Category: C2. The anchor is the dataset paper.
- Fix class (b). Anchor Abramowitz et al. 2024, fetched to the scratchpad, not yet ingested. Restate the bar as the benchmark that paper defines, since a median model is not located, and check it against decision 0025.

##### 57. earth.fluxnet_gpp: "global GPP, NPP and soil carbon compilations"
- Category: C2.
- Fix class (b). Name and anchor the compilations, or remove the constituent. Report entry.

#### Cases for the user's decision (class d)

None strictly: no entry in this range is registered, no constant or test instance is touched, and no decision's basis
rests on a registry line here. The parent may still want the user to see two things:
- applying decision 0025's rule to the twelve basis-less fail_bar numbers turns each into a report entry unless a
  published residual is found (a verdict_kind change on ten entries);
- the fire window's variable (partial pressure against concentration at stated total pressure) is REQ-BIO-015's
  wording, and changing it changes what the fire refusal reads.

#### Open-branch conflicts

- registry.toml: fiddlybits-k6b rewrites earth.hydrolakes_terminal_lakes, adds earth.copernicus_dem_spill_cap and
  adds the Lehner and Doll 2004 anchor. Its diff covers #33 to #35 and leaves #32 (GLWD v2) in place.
- registry.toml is also edited by fiddlybits-52v.6.26 and 52v.8.13, so no registry fix can land from this branch.
- No other file in this scope is edited by an open branch. REQ-HYD-002 and REQ-BIO-015 are not edited by an open
  branch; REQ-HYD-001 is edited by k6b.

#### Fetches

- Pelletier et al. 2016, "A gridded global data set of soil, intact regolith, and sedimentary deposit thicknesses for
  regional and global land surface modeling", 10.1002/2015MS000526 (open access, JAMES). One attempt through the
  publisher's pdfdirect URL returned HTML, so the fetch failed.
- Abramowitz et al. 2024, "On the predictability of turbulent fluxes from land: PLUMBER2 MIP experimental description
  and preliminary results", Biogeosciences 21, 5517, 10.5194/bg-21-5517-2024. Fetched to
  scratchpad/audit/fetch-R2/abramowitz2024.pdf; not ingested.
- Guillot 2010, arXiv 1006.4702, fetched to scratchpad; not needed, since the INDEX row is held on disk.
- No paywalled source was needed in this range.

### R3: Registry, line 2112 to the end


Scope: earth.snow_cover_extent to earth.ecs_report, terrain.*, sweep.*, the nine [[protocol]]
entries and the [[instrument]] ulp_ensemble. The three tier-1 entries in the range
(terrain.endorheic_share_nonzero, terrain.age_rate_identity, terrain.drainage_isotropy) carry
no anchor and no cited basis, so they contribute no citation.

#### Counts

| kind | total | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| anchors | 40 | 25 | 13 | 2 |
| stated bar bases (fail_bar thresholds) | 15 | 2 | 13 | 0 |
| dataset manifests against their anchors | 3 | 3 | 0 | 0 |
| protocol declarations (sources for the declared system) | 9 | 6 | 3 | 0 |
| instrument basis | 1 | 1 | 0 | 0 |
| total | 68 | 37 | 29 | 2 |

The 29 not-fit verdicts fall into 17 cases (section 3). No entry in this range is registered
(every registered_at is empty), so no case changes a registered bar. No case changes a
constant's disposition or a test instance's declared value. Cases 10 and 11 turn on how
decision 0025 is read, which is a question for the user (see there).

INDEX status, recorded and not scored as a fitness verdict: of the 40 anchors, only Wang 2018,
Portenga 2011, Kok 2010 and Kok 2014 are `read`; every other anchor row is `held`, so every
fail_bar entry here would be refused at registration on its anchors' status alone (README,
"A Sourced parameter or an oracle bar whose reference is not read is refused"). Kok 2010 and
Kok 2014 are read for a different use than the one they anchor here (cases 2 and 3, C6).

File state: registry.toml is edited by open branches fiddlybits-k6b, fiddlybits-52v.6.26 and
fiddlybits-52v.8.13 (and rows 52v.8.14 to 52v.8.23 carry tier-2 form work); INDEX.md by k6b.
Every fix below touches registry.toml and most touch INDEX.md, so none can be made in the
9j0 branch. A threshold change merges registry-only.

#### 2. Every citation

Text pages are `references/text/<stem>/<NNNN>.txt` (PDF page index). F = fetched copy in
scratchpad/audit/fetch-R3/.

##### Anchors

| # | where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | earth.snow_cover_extent anchors | NH snow cover extent product | estilow2015 (held; not on disk) | whole paper | FIT | F estilow2015.txt: describes the NOAA NH SCE CDR, Version 1, doi 10.7289/V5N014G9 (Data set availability) |
| A2 | earth.sea_ice_extent anchors | extent per hemisphere | Sea Ice Index v4, 10.7265/a98x-0f50 (held, dataset) | manifest seaice-index-v4 | FIT | manifest title "Sea Ice Index, Version 4", doi matches anchor; extent csv per hemisphere held |
| A3 | earth.rgi_glacier_area anchors | glacier area outside ice sheets | RGI v7, 10.5067/f6jmovy5navz (held, dataset) | manifest rgi-v7 | FIT | manifest doi and version 7.0 match; G glacier product held |
| A4 | earth.woa_sst_zonal anchors | source of the zonal-mean SST residual statistic the bar is drawn from | griffies2016 OMIP protocol (held) | whole paper | NOT FIT C2 | OMIP protocol paper; grep of all 66 pages for residual/SST bias finds only "residual mean" transport and spin-up "residual drift" (0008, 0034, 0037); no zonal SST residual statistic |
| A5 | earth.woa_salinity_sections anchors | salinity sections (report) | reagan2024 WOA23 Vol 2 (held) | volume | FIT | WOA23 Volume 2: Salinity, the climatology the statistic reads |
| A6 | earth.mld_by_basin anchors | MLD climatology and its density-threshold definition | deboyermontegut2004 (held; not on disk) | whole paper | NOT VERIFIED | one fetch returned a 5587-byte HTML challenge page, not the PDF |
| A7 | earth.meridional_heat_transport anchors | observed MHT and its uncertainty | trenberth2001 (held) | abstract | FIT | 0001 l.16-18: poleward atmospheric transport peaks at 5.0 +/- 0.14 PW at 43N; variability mostly under 0.15 PW |
| A8 | earth.amoc_strength anchors | RAPID overturning strength (report) | moat2020 (held; not on disk) | Results | FIT | F moat2020.txt: 26N overturning 17.8 +/- 1.4 Sv (mean +/- standard error), 10-day binned error +/- 1.5 Sv |
| A9 | earth.marine_npp anchors | observational range of global marine NPP (report) | behrenfeld1997 (held) | abstract; Table 2 | FIT (note) | 0001 l.45: global PP 43.5 Pg C/yr (VGPM); 0015 Table 2: global annual PP by VGPM and LPCM. Note: a range of satellite-algorithm estimates, not a compilation of observations |
| A10 | earth.dust_aod anchors | global dust AOD 0.02 to 0.04 | kok_2010 scaling theory (read, for emitted PSD eq. 6) | whole paper | NOT FIT C2, C6 | no global dust AOD value anywhere; 0005 l.80-83 mentions AOD only as what GCM schemes are tuned against |
| A11 | earth.dust_emission anchors | a compilation's range of global dust emission | kok_2014 Part 1 (read, for eqs. 18a, 18b) | whole paper | NOT FIT C2, C6 | "compilation" is of quality-controlled vertical dust flux point measurements (0001 l.41-42, 0002 l.22, 0013 l.20); no global emission total or range |
| A12 | earth.global_surface_temperature anchors | observed GMST reference | morice2021 HadCRUT5 (held; not on disk) | whole paper | NOT VERIFIED | one fetch returned a 5587-byte HTML challenge page |
| A13 | earth.ecs_report anchors | "IPCC AR6 likely range for ECS" (dataset_or_reference) | sherwood2020 (held) | abstract; section 1 | NOT FIT C2 | 0002 l.29 and 0005 l.10-11: Sherwood's Bayesian 66% range is 2.6-3.9 K (ECS 2.6-4.1 K, 0099 l.9-10); the anchor is not AR6 and does not state AR6's range; AR6 WG1 ch. 7 has no INDEX row |
| A14 | terrain.hypsometry_scale_matched anchors | ETOPO 2022 paper | macferrin2024 ESSD preprint 10.5194/essd-2024-250 (held) | preprint | NOT FIT C4 | Crossref for 10.5194/essd-2024-250: is-preprint-of 10.5194/essd-17-1835-2025; the final paper exists and is not the one anchored |
| A15 | terrain.hypsometry_profile anchors | same | same | same | NOT FIT C4 | same |
| A16 | terrain.channel_concavity anchors (1) | observed concavity values | flint1974 (held) | p. 969-970, Fig. 1 | FIT | 0001 l.7: order data give -0.63, link slope exponents -0.60; 0002 l.33: range -0.11 to -2.30 (Fig. 1a) |
| A17 | terrain.channel_concavity anchors (2) | ETOPO 2022 paper | macferrin2024 preprint | preprint | NOT FIT C4 | as A14 |
| A18 | terrain.drainage_density anchors | HydroSHEDS network product | lehner2013 (held) | sections 2-3 | FIT | 0003, 0009: HydroSHEDS derived river reaches and sub-basins from the DEM (500 m sub-basins, average 130 km2, 0009 l.52-55) |
| A19 | terrain.endorheic_share anchors (1) | Earth's endorheic share (report) | wang2018 (read) | p. 1, p. 3 | FIT | 0001 l.32: endorheic basins cover one-fifth of Earth's land; 0003 l.102: 31.8 million km2 |
| A20 | terrain.endorheic_share anchors (2) | HydroSHEDS basins | lehner2013 (held) | as A18 | FIT | as A18 |
| A21 | terrain.denudation_vs_relief anchors (1) | cosmogenic denudation database | codilean2018 OCTOPUS (held) | Fig. 7 | FIT | 0011 l.5: global CRN data set, average basin slope against recalculated rates |
| A22 | terrain.denudation_vs_relief anchors (2) | 10Be rates with slope as regressor | portenga2011 (read) | p. 4, p. 6 | FIT | 0003 l.3: basin rates explained by environmental parameters (R2 = 0.60), mean basin slope most important; 0006 l.70-96 |
| A23 | terrain.hypsometric_integral_distribution anchors (1) | ETOPO 2022 paper | macferrin2024 preprint | preprint | NOT FIT C4 | as A14 |
| A24 | terrain.hypsometric_integral_distribution anchors (2) | catchments | lehner2013 (held) | as A18 | FIT | as A18 |
| A25 | terrain.hack_exponent anchors (1) | length-area relation form (report) | hack1957 (held) | abstract p. 1; p. 59-60 | FIT (note) | 0005 l.11 and 0024 l.5: length proportional to the 0.6 power of drainage area; 0024 l.7: 0.7 in Arizona and the Black Hills, "valid only for the region under discussion". The Earth value is drawn from HydroSHEDS, so the regional exponent is not used as a value |
| A26 | terrain.hack_exponent anchors (2) | HydroSHEDS | lehner2013 (held) | as A18 | FIT | as A18 |
| A27 | sweep.aquaplanet_ape anchors (1) | APE control multi-model results | blackburn2013 (held) | sections 2-3, Tables 2, 5 | FIT | 0006 l.153: 16 participating models (Table 2); 0003 l.12-16: wide range, single or double ITCZ; 0016 l.23: Table 5 mid-latitude maxima |
| A28 | sweep.aquaplanet_ape anchors (2) | APE atlas, multi-model spread | williamson2012 atlas (held) | Table 2.1 and atlas | FIT | 532 pages of per-model diagnostics; 0031 Table 2.1 recommended constants |
| A29 | sweep.rotation_rate anchors | Hadley edge against rotation rate | kaspi2015 (held) | abstract; section 2 | FIT (content) | 0001 l.26: an idealized moist GCM swept over rotation, gravity, radius and flux; bar basis judged at B13 |
| A30 | sweep.rotation_rate_jets_and_contrast anchors | jets and contrast against rotation (report) | kaspi2015 (held) | same | FIT | same sweep |
| A31 | sweep.obliquity anchors (1) | gradient reversal at high obliquity | ferreira2014 (held) | abstract; p. 2 | FIT (content) | 0001 l.36: at high obliquity temperature gradients are reversed; 0002 l.97: one coupled GCM; bar basis at B14 |
| A32 | sweep.obliquity anchors (2) | high-obliquity habitability | colose2019 (held) | abstract | FIT (content) | 0001 l.27: ROCKE-3D simulations at low and high obliquity, various fluxes and CO2 |
| A33 | sweep.gravity anchors (1) | gravity sweep at fixed column mass | thomson2019 (held) | section 2, p. 3-7 | FIT | 0003 l.97-99: scaling g and surface pressure together keeps atmospheric mass; 0007 l.24, 46: experiments set gamma = alpha, constant atmospheric mass |
| A34 | sweep.gravity anchors (2) | published gravity sweep | yang2019 (held) | section 2 | NOT FIT C2 | 0002 l.71: "Earth's radius and gravity for all simulations"; the paper intercompares rapidly rotating and tidally locked cases, gravity is never varied |
| A35 | sweep.stellar_type_aquaplanet anchors (1) | THAI protocol | fauchez2020 (held) | Table 1, section 3.1 | FIT | 0003 Table 1; 0004 l.17-24: Hab1 1 bar N2 + 400 ppm CO2, Hab2 1 bar CO2; four GCMs (0003) |
| A36 | sweep.stellar_type_aquaplanet anchors (2) | THAI four-model global-mean Ts and OLR | fauchez2022 THAI III (held) | whole paper | NOT FIT C2 | THAI III is simulated spectra; no global-mean Ts or OLR table (grep of 17 pages finds none). Ts per GCM is THAI II (sergeev2022, held) Table 4, 0006; OLR there only as maps, Figures 1 and 13 |
| A37 | sweep.stellar_type_day_night_contrast anchors (1) | THAI protocol | fauchez2020 (held) | as A35 | FIT | as A35 |
| A38 | sweep.stellar_type_day_night_contrast anchors (2) | day-night contrast across THAI models | fauchez2022 THAI III (held) | whole paper | NOT FIT C2 | the day/night surface results are in THAI II (sergeev2022 0009 l.84: dayside mean surface temperature ranges across models) |
| A39 | sweep.stellar_type_ice_albedo anchors (1) | ice-albedo feedback weakening with a redder star | fauchez2020 (held) | Table 1 | NOT FIT C2, C3 | one star (2600 K BT-Settl, Table 1, 0003 l.85) and one synchronous planet; no stellar-type variation to state a direction |
| A40 | sweep.stellar_type_ice_albedo anchors (2) | same | fauchez2022 (held) | whole paper | NOT FIT C2, C3 | same; the Shields et al. and Godolt et al. works the entry names have no INDEX row |

##### Stated bar bases (fail_bar)

| # | entry | stated basis | verdict | evidence |
| --- | --- | --- | --- | --- |
| B1 | earth.snow_cover_extent | "mean within 20 percent, amplitude within 30 percent" | NOT FIT C7 | no basis stated; the anchor's only uncertainty is observational: F estilow2015.txt, Discussion: Brown and Robinson (2011) 95% CI of March-April continental SCE +/-3-5% |
| B2 | earth.sea_ice_extent | residual of a named published sea-ice intercomparison, refused if narrower than the index uncertainty | FIT (deferred) | a residual is an accepted basis (decision 0025); the intercomparison is not yet named or anchored |
| B3 | earth.woa_sst_zonal | zonal-mean SST residual of a named published model or intercomparison (OMIP) | NOT FIT C2 | the only anchor (A4) is the OMIP protocol, which carries no residual |
| B4 | earth.meridional_heat_transport | inter-model spread of a named intercomparison at the peak | NOT FIT C7 | decision 0025 section Tier 2: a FAIL bar is "a published model's own residual statistics or ... a physical constraint"; an inter-model spread is the tier-3 basis; no intercomparison anchored |
| B5 | earth.dust_aod | "outside 0.02 to 0.04 fails" (Ridley et al.; Kok et al.) | NOT FIT C2, C7 | A10: Kok 2010 states no AOD; Ridley et al. and Kok et al. (2017) have no INDEX row; an observational constraint range is not a model residual |
| B6 | earth.dust_emission | "inside the compilation's range" | NOT FIT C2, C7 | A11: the Kok 2014 compilation is site vertical fluxes, not a global emission range; an observational range is not a residual |
| B7 | earth.global_surface_temperature | "outside 286 to 290 K fails (roughly the CMIP5 inter-model spread)" | NOT FIT C7 | "roughly" is not a sourced number; no CMIP5 source anchored (the anchor is an observational dataset); an inter-model spread is not a tier-2 residual (as B4) |
| B8 | terrain.hypsometry_scale_matched | "within 0.5x to 2x of Earth's" | NOT FIT C7 | no basis stated; the anchor (ETOPO paper) gives no residual |
| B9 | terrain.channel_concavity | "outside 0.35 to 0.6 fails" | NOT FIT C2, C7 | Flint 1974 gives means -0.60 and -0.63 and a range -0.11 to -2.30 (0001 l.7, 0002 l.33); 0.35-0.6 is not stated, and Flint's own mean sits at the upper edge; observational spread, not a residual |
| B10 | terrain.drainage_density | "outside 0.5x to 2x fails" | NOT FIT C7 | no basis stated; Lehner and Grill 2013 gives no drainage density statistic (grep of 16 pages) |
| B11 | terrain.denudation_vs_relief | "outside the interquartile band fails" | NOT FIT C7 | the band is the observational spread of the OCTOPUS / Portenga compilations (A21, A22), not a published model's residual |
| B12 | sweep.aquaplanet_ape | APE ensemble range on four scalar metrics | FIT (note) | tier 3 inter-model range of the 16 APE models (A27). Note: the statistic lists ITCZ structure, which is not a scalar, beside the "four scalar metrics"; Table 5 covers 11 of 16 models |
| B13 | sweep.rotation_rate | exponent within the published inter-model disagreement | NOT FIT C7 | the only anchor is one idealized GCM (kaspi2015 0001 l.26); no inter-model spread exists in it; Merlis and Schneider, named in dataset_or_reference, has no INDEX row |
| B14 | sweep.obliquity | within the published spread | NOT FIT C7 | both anchors are single-model studies (Ferreira 2014: one coupled GCM, 0002 l.97; Colose 2019: ROCKE-3D) on different base systems; a spread across studies with different systems is not an inter-model spread on one protocol |
| B15 | sweep.stellar_type_aquaplanet | THAI four-model range on global-mean Ts and OLR | NOT FIT C2 | A36: THAI III does not carry it; THAI II Table 4 carries Ts, OLR only as maps |

##### Dataset manifests against anchors

| # | manifest | verdict | evidence |
| --- | --- | --- | --- |
| D1 | seaice-index-v4 (earth.sea_ice_extent) | FIT | doi 10.7265/a98x-0f50, Version 4, supersedes v3 as the anchor says |
| D2 | rgi-v7 (earth.rgi_glacier_area) | FIT | doi 10.5067/f6jmovy5navz, RGI 7.0 |
| D3 | etopo2022 (four terrain entries) | FIT (dataset) | doi 10.25921/fd45-gt74, 15 arc-second v1; its `paper` key names the preprint, the C4 of case 5 |

##### Protocols

| # | protocol | verdict | evidence |
| --- | --- | --- | --- |
| P1 | jablonowski_williamson | FIT | jablonowski2006 0005 l.17, 32-33, 73: a = 6.371229e6 m, Rd = 287.0, g = 9.80616, Omega = 7.29212e-5 (surface pressure not located by the page grep) |
| P2 | held_suarez | FIT | held1994 0002 l.31-33: p0 = 1000 mb, kappa = 2/7, cp = 1004, Omega = 7.292e-5, g = 9.8, a_e = 6.371e6 m; R = kappa cp; 0003 l.7 lists what must be specified |
| P3 | dcmip_small_planet | FIT | ullrich2012 section 4.1, 0040 l.41-46: a = aref/X and Omega = Omega_ref X from the case's reference values; the Earth base is the case's own definition, not a filled-in default |
| P4 | ape | NOT FIT C2 | declares every field "from the APE protocol paper" including a spectrum. APE prescribes solar constant 1365 W/m2, AMIP II ozone, CO2 348 ppmv (blackburn2013 section 2.2, 0004 l.88-92) and recommends geophysical constants in the APE atlas Table 2.1 (williamson2012 0031: a = 6371.0 km, g = 9.79764, Rd = 287.04). It prescribes no stellar spectrum, and Neale and Hoskins (2000), the proposal, gives only the SST profiles (neale2000 0002) |
| P5 | rotation_rate_sweep | FIT | kaspi2015 section 2 (0003): the reference simulation of the swept model, Earth-like forcing (0003 l.133-136) |
| P6 | obliquity_sweep | NOT FIT C7 | "each published study's base system": the two anchored studies use different models and systems (A31, A32), so no one protocol system with a shared spread exists (same case as B14) |
| P7 | gravity_sweep | FIT | thomson2019 0007 l.24, 46: gamma = alpha, constant atmospheric mass |
| P8 | thai | FIT | fauchez2020 Table 1 (0003): 2600 K BT-Settl, rotation 6.1 d, radius 0.910 R_E, gravity 0.930 g_E (from Grimm et al. 2018); 0004: Hab1/Hab2 compositions, 100 m slab ocean |
| P9 | stellar_type_equal_instellation | NOT FIT C2 (no source indexed) | Shields et al. and Godolt et al. have no INDEX row (grep for Shields, Godolt, "effect of host star spectral", "3D climate modeling of Earth-like" finds none), and no entry naming this protocol anchors them |

##### Instrument

| # | instrument | verdict | evidence |
| --- | --- | --- | --- |
| I1 | ulp_ensemble | FIT | notes/findings/2026-09-11-ulp-ensemble-member-count.md l.126-146 and table l.227-232: 766 members, miss rate 3.9032401194668553e-3, confidence reciprocal 20 Bracketed in [5, 1000] with the measured shortfall at each edge; decision 0052 l.11-29: the miss rate is a probability over the seeded draw; notes/findings/2026-09-12-ulp-ensemble-amplitude-and-injection-step.md: operator one norm and injection step; parameters equal src/Backends/certify.jl. Note: 1/20 coincides with the conventional 0.05 significance level, but the finding argues it as Bracketed from a measured sweep and does not rest it on that convention, so it is not C1 |

#### 3. Not-fit cases

1. **earth.woa_sst_zonal: OMIP protocol anchored as the source of a residual (A4, B3).** C2. Griffies et al. 2016 is the OMIP experimental and diagnostic protocol and carries no zonal-mean SST residual. The WOA observation itself is not anchored either, although locarnini2024 (WOA23 Vol. 1: Temperature) is indexed, held. Fix (b): anchor a published OMIP evaluation with SST residuals, for example Tsujino et al. 2020, GMD 13, 3643 (open access; no INDEX row, unverified here), read the table of zonal SST bias, and add WOA23 Vol. 1. Boundary: registry.toml, INDEX.md.
2. **earth.dust_aod: Kok 2010 anchors a global dust AOD it never states (A10, B5).** C2, C6 (read for the emitted PSD, eq. 6), C7 (an observational constraint range as a fail bar). 0005 l.80-83 mentions AOD only as the GCM tuning target. Fix (b): index and read Ridley et al. 2016 (ACP, open access) and Kok et al. 2017 for the AOD constraint; then either state a bar from a model residual or make the entry report. Boundary: registry.toml, INDEX.md.
3. **earth.dust_emission: the Kok 2014 compilation is point fluxes, not a global range (A11, B6).** C2, C6 (read for eqs. 18a and 18b), C7. 0001 l.41-42: "a compilation of quality-controlled vertical dust flux measurements". Fix (b): a source with a global emission range and a residual basis, or report. Boundary: registry.toml, INDEX.md.
4. **earth.ecs_report: the entry names the AR6 likely range and anchors Sherwood 2020 (A13).** C2. Sherwood's 66% range is 2.6-3.9 K (0002 l.29), not AR6's. Fix (b): either reword dataset_or_reference to Sherwood's Baseline 66% range with its locator (Sherwood is held, not read), or index and anchor AR6 WG1 chapter 7. This rides the tier-3 move the user decided on 2026-09-14 (rows 52v.8.13 to 52v.8.23).
5. **Four terrain entries anchor the ETOPO 2022 ESSD preprint (A14, A15, A17, A23).** C4. Crossref says 10.5194/essd-2024-250 is-preprint-of 10.5194/essd-17-1835-2025. The manifest's `paper` key names the same preprint. Fix (b): fetch the final paper (Copernicus, open access), index it, re-anchor the four entries, and correct the manifest's `paper` key. Boundary: registry.toml, INDEX.md, docs/oracles/data/etopo2022.toml.
6. **sweep.gravity: Yang et al. 2019 is not a gravity sweep (A34).** C2. 0002 l.71: "Earth's radius and gravity for all simulations". Fix (b): drop the anchor, or replace it with a gravity sweep; kaspi2015 varies gravity (0002 l.82) and is held. Report entry, so no bar moves. Boundary: registry.toml.
7. **THAI III anchored for Hab1/Hab2 global-mean Ts, OLR and day-night contrast (A36, A38, B15).** C2. THAI III is spectra. THAI II (sergeev2022, held) Table 4 gives Ts per GCM, and 0009 l.84 the dayside ranges; OLR appears only as maps (Figures 1, 13). Fix (b): re-anchor to THAI II, read Table 4, and find a tabulated global-mean OLR (or drop OLR from the statistic, which changes an unregistered threshold). Boundary: registry.toml, INDEX.md.
8. **sweep.stellar_type_ice_albedo and protocol stellar_type_equal_instellation: the named sources are not indexed, and THAI stands in (A39, A40, P9).** C2, C3. THAI is one M-dwarf spectrum on one synchronous planet, and cannot state a direction across stellar types. Fix (b): index and read Shields et al. (2013) and Godolt et al. (2015) for the direction and their equal-instellation base systems; anchor them. Boundary: registry.toml, INDEX.md.
9. **earth.snow_cover_extent bar 20/30 percent (B1).** C7: no stated basis. The anchor's uncertainty (95% CI +/-3-5% in March-April) is observational. Fix (b): a published model residual on NH SCE, or report. Boundary: registry.toml.
10. **earth.meridional_heat_transport bar from an inter-model spread in tier 2 (B4).** C7 as decision 0025 reads: a tier-2 FAIL bar comes from "a published model's own residual statistics or ... a physical constraint". Fix (b), plus a question for the user: is an inter-model spread admissible as a tier-2 FAIL bar? If yes, decision 0025's basis changes, which is the user's decision.
11. **earth.global_surface_temperature bar 286 to 290 K, "roughly the CMIP5 inter-model spread" (B7).** C7: unsourced ("roughly"), no CMIP5 source anchored, and the same tier-2 reading as case 10. Fix (b), and the same user question.
12. **Ratio bars 0.5x to 2x on terrain.hypsometry_scale_matched and terrain.drainage_density (B8, B10).** C7: no basis stated, and neither anchor gives a residual. Fix (b): a residual-based bar, or report. Boundary: registry.toml.
13. **terrain.channel_concavity bar 0.35 to 0.6 (B9).** C2 and C7: Flint 1974 gives means of -0.60 and -0.63 with a range of -0.11 to -2.30 (p. 969-970, Fig. 1). The bar's range is not in the source, and Flint's mean sits at its upper edge. Fix (b). Boundary: registry.toml.
14. **terrain.denudation_vs_relief interquartile band (B11).** C7: an observational spread, not a model residual. Fix (b): report, or a residual of a published denudation model. Boundary: registry.toml.
15. **sweep.rotation_rate: "published inter-model disagreement" from one model (B13).** C7: Kaspi and Showman 2015 is one idealized GCM, and Merlis and Schneider is not indexed. Fix (b): index a second published sweep with a comparable protocol, or report. Boundary: registry.toml, INDEX.md.
16. **sweep.obliquity and protocol obliquity_sweep: a spread across single-model studies on different systems (B14, P6).** C7. Ferreira 2014 is one coupled GCM on an aquaplanet; Colose 2019 is ROCKE-3D with land and various fluxes. Fix (b): name one protocol with more than one model, or make the entry report. Boundary: registry.toml.
17. **Protocol ape declares a spectrum and sources everything to "the APE protocol paper" (P4).** C2. The solar constant, ozone and CO2 are in Blackburn 2013 section 2.2. The geophysical constants are the atlas's Table 2.1 recommendations (a = 6371.0 km, g = 9.79764, Rd = 287.04), not Earth's IAU values and not Neale and Hoskins 2000. No spectrum is prescribed. Fix (b): name the two locators, and remove the spectrum from the declaration or declare it by another disposition, so that no Earth solar spectrum is filled in (the C8 risk). Both sources are held, not read. Boundary: registry.toml, INDEX.md.

#### 4. Fetch failures and paywalled

One attempt each, curl with a browser user agent. Both returned a 5587-byte HTML challenge page from agupubs.onlinelibrary.wiley.com instead of the PDF:

- "Mixed layer depth over the global ocean: An examination of profile data and a profile-based climatology", doi 10.1029/2004JC002378 (AGU, free to read).
- "An Updated Assessment of Near-Surface Temperature Change From 1850: The HadCRUT5 Data Set", doi 10.1029/2019JD032361 (open access, CC BY).

Fetched and read in scratchpad (not ingested): Estilow et al. 2015 (ESSD, 10.5194/essd-7-137-2015) and Moat et al. 2020 (Ocean Science, 10.5194/os-16-863-2020).

Not indexed, needed by the fixes (identifiers as recalled, unverified): Tsujino et al. 2020 OMIP evaluation (GMD 13, 3643); Ridley et al. 2016 dust AOD constraint (ACP); Kok et al. 2017 (Nature Geoscience, likely paywalled); Shields et al. 2013 (Astrobiology); Godolt et al. 2015 (A&A); Merlis and Schneider 2010 (JAMES); IPCC AR6 WG1 chapter 7; the final ETOPO 2022 paper, 10.5194/essd-17-1835-2025 (confirmed via Crossref).

### S: src and test


Counted: every `Locator(identifier = ...)` naming a work, and every comment in src/ and test/
that names a work as the source of a law, scheme, constant or equation a function carries.
Not counted as citations: the `"fixture"` identifiers of test/system/fixtures.jl (lines 116,
196, 215) and test/system/refusals.jl (lines 92, 318), which claim no source; the lint
fixtures and test/lint/runtests.jl, which exercise the lint on the Moritz DOI string; and
test/system/earth_ratios.jl:21, which asserts the locator src/EarthRatios carries.

test/planets/ exists only on the open branch fiddlybits-52v.4.5; its locators are audited
from `git show fiddlybits-52v.4.5:test/planets/...` and nothing there is edited here.

#### Verdicts

| # | where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | src/EarthRatios/EarthRatios.jl:20-25 `gravity_unit` | Earth gravity unit 9.80665 m s^-2 | cgpm1901 (read) | Declaration 2, p.70 | fit | p.70: "3 Le nombre adopte dans le Service international des Poids et Mesures pour la valeur de l'acceleration normale de la pesanteur est 980,665 cm/sec^2", the declaration "adoptee a l'unanimite" |
| S2 | src/EarthRatios/EarthRatios.jl:27-38 `radius_unit` | Earth radius unit, docstring "Earth's volumetric mean radius, matching the mean-radius convention decision 0005 uses" | archinal2018 (read) | Table 4, Earth mean radius row | NOT FIT (C2) | Table 4 p.28: Earth equatorial 6378.1366, polar 6356.7519, mean 6371.0084 km; p.35: "Aside from the Earth, the mean radii shown in Tables 4, 5, and 6 are from the original authors and have not been computed from the other radii by the Working Group"; (2a+b)/3 = 6371.00837 km, (a^2 b)^(1/3) = 6371.00039 km. The value is the arithmetic mean radius, not the volumetric one decision 0005 (Consequences) names |
| S3 | src/EarthRatios/EarthRatios.jl:40-51 `solar_constant_unit` | solar constant unit 1361 W m^-2 | prsa2016 (read) | Table 1, nominal TSI | fit | p.3 Table 1: nominal TSI "= 1361 W m-2"; p.3 text: the mean TSI "at a distance of 1 au" |
| S4 | src/EarthRatios/EarthRatios.jl:53-63 `pressure_unit` | pressure unit 101325 Pa | tiesinga2021 (read) | Table XXXI, standard atmosphere | fit | Table XXXI (continued), p. 033105-51: "standard atmosphere ... 101 325 Pa exact" |
| S5 | src/EarthRatios/EarthRatios.jl:65-76 `rotation_rate_unit` | rotation-rate unit 7.292115e-5 rad/s | moritz2000 (read) | p.131, Defining Constants (exact) | fit | p.131: "Defining Constants (exact) ... omega = 7 292 115 x 10^-11 rad s^-1" |
| S6 | src/Systems/constants.jl:19-22 `gravitational_constant` | G = 6.67430e-11 | tiesinga2021 (read) | Table XXX, p. 033105-45 | fit | Table XXX, p. 033105-45: "G 6.674 30(15) x 10^-11" |
| S7 | src/Systems/constants.jl:32-46 `stefan_boltzmann_constant` | sigma from (pi^2/60)k^4/(hbar^3 c^2) with exact k, h, c | tiesinga2021 (read) | Table XXX, p. 033105-45 | fit | Table XXX, p. 033105-45 lists "Stefan-Boltzmann constant (pi^2/60)k^4/hbar^3c^2" and the exact h and k in the same table |
| S8 | src/Systems/gravity.jl (7 citations: p.24 below Eq. 2.5; Eq. 2.25 p.29; Eqs. 4.95-4.97 pp.149-150; Eq. 2.22 p.28) | two-body period, mean motion, centrifugal potential and acceleration | murray2000 (read) | as named | fit | verified in X1 rows 32 and 34: pp.24, 28-29, 149-150 carry each relation, and the INDEX row names each as read |
| S9 | src/Systems/figure.jl (15 citations: Eqs. 4.101-4.103, 4.109, 4.112, 4.113, 4.118, 4.119, Fig. 4.9) | Darwin-Radau flattening and its admitted range | murray2000 (read) | as named | fit | verified in X1 rows 32 and 33: pp.150-154 carry Eqs. 4.101-4.119 and Fig. 4.9, and the inversion follows from Eq. 4.112 |
| S10 | test/system/gravity.jl:88-90 | the figure arm checks Eqs. (4.112) and (4.114), p.153, and Eq. (4.110), p.152 | murray2000 (read) | Eqs. (4.112), (4.114), (4.110) | NOT FIT (C6) | Eq. (4.114) is printed on p.153 (text 0167.txt line 51), but the INDEX row's read anchors name Eqs. (4.95)-(4.97), (4.99), (4.101)-(4.103), (4.109), (4.110), (4.112), (4.113), (4.118), (4.119), Fig. 4.9, (2.22), (2.25) and p.24, not (4.114) |
| S11 | src/Reductions/error_bound.jl:50 | roundoff bound of a fixed-order sum | higham1993 (read) | eq. 2.6 | fit | p.784 (text 0003.txt): "(2.6) \|E_n\| <= gamma_{n-1} sum \|x_i\| = (n-1)u sum \|x_i\| + O(u^2)" |
| S12 | src/Provenance/rng.jl:26-31 `PHILOX4X64_M0/M1` | Philox-4x64 multipliers | salmon2011 (HELD) | p.7 | NOT FIT (C6) | p.7: "4x64, 0xCA5A826395121157 and 0xD2E7470EE14C6C93": the passage states the values, but the INDEX row is held, not read |
| S13 | src/Provenance/rng.jl:37-43 `PHILOX4X64_W0/W1` | Weyl round-key increments | salmon2011 (HELD) | p.6, eq. 6 | NOT FIT (C6) | p.6: "the constants 0xBB67AE8584CAA73B (sqrt(3)-1) and 0x9E3779B97F4A7C15 (the golden ratio)"; row held |
| S14 | src/Provenance/rng.jl:48-52 `PHILOX4X64_ROUNDS` | ten rounds | salmon2011 (HELD) | p.8, Table 2 | NOT FIT (C6) | p.8 Table 2 lists "Philox4x64-7" and "Philox4x64-10", minimal rounds for Crush-resistance and extra rounds for safety margin; row held |
| S15 | src/Provenance/rng.jl:76-80 `philox4x64_round` | the multiply-based S-box and the N=4 swap | salmon2011 (HELD) | p.7, footnote 10 | NOT FIT (C6) | p.7 footnote 10: "For Philox-4xW, the permutation consists of swapping..."; row held |
| S16 | src/Connectivity/gates.jl:2-7 | gate flux at the control section: saddle point between basins (p.423), sill depth (p.424), exit-channel lip (eqs. 7-11, p.426), flux through a rectangular opening (eqs. 12-13, p.427) | whitehead1998 (HELD) | pp.423-427, eqs. 7-13 | NOT FIT (C6) | p.423 abstract: "Saddle points between neighboring deep ocean basins are the sites of unidirectional flow from one basin to the next"; p.426 eqs. (7), (11); p.427 eq. (12) Q = g' h_u^2/(2f) for L > (2 g' h_u / f^2)^(1/2) and eq. (13) otherwise; the passages state what is cited, but the INDEX row is held |
| S17 | src/Connectivity/gates.jl:7-8 and src/Connectivity/terminals.jl:2-4 | the priority flood | barnes2014 (HELD) | Algorithm 1, p.119 | NOT FIT (C6) | p.119: "Algorithm 1. PRIORITY-FLOOD"; row held |
| S18 | src/Connectivity/terminals.jl:4 | the label carried with the flood | barnes2014 (HELD) | section 7.3 and Algorithm 5, pp.125-126 | NOT FIT (C6) | p.125: "7.3. Watershed labeling ... Algorithm 5. IMPROVED PRIORITY-FLOOD+WATERSHED LABELS"; row held |
| S19 | src/Connectivity/terminals.jl:5 | the total order of the queue | barnes2014 (HELD) | section 4, p.121 | NOT FIT (C6, and C2 locator) | "4. Ordering" is printed on p.122 (text 0006.txt; 0005.txt carries the folio 121 and ends inside section 3.3); p.122: "A total order produces a predictable, reproducible result"; row held |
| S20 | src/Connectivity/terminals.jl:5-6 | seeding from every local minimum | barnes2014 (HELD) | section 3.1, p.119 | NOT FIT (C6) | p.119: "Beucher and Meyer (1992) present a similar O(n) algorithm. Each local minima is assigned a unique label. The terrain is then flooded upwards from its lowest points"; row held |
| S21 | src/Connectivity/gates.jl:9-11 | one gate per pair of bodies, as one outlet per pair of depressions | barnes2020 (HELD) | section 3.3, p.438 | NOT FIT (C6) | section 3.3 runs from p.435 to p.438 (3.4 begins on p.438); p.438: "the two is the outlet cell ... hashed using the labels of the depressions that are joined by an outlet ... only the location of the lowest outlet is" kept; row held |
| S22 | test/dispositions/fixtures.jl:9 | the default `locator()` of every constructor test, on a value 1.0 | archinal2018 (read) | Table 1 | NOT FIT (C2), FIXED | Archinal Table 1 gives the pole and rotation of the Sun and planets, not a dimensionless 1.0; the fixture now carries `identifier = "fixture"`, `table = "fixture table"`, the convention test/system/fixtures.jl uses |
| S23 | test/planets/earth.jl:24 (branch 52v.4.5) | Sun mass = (GM)N_sun / G | prsa2016 (read) | Table 1, nominal solar mass parameter | fit | p.3 Table 1: "1.3271244x10^20 m3 s-2"; p.3 Resolution item 5: SI masses "expressed in terms of (GM)object/G, where the estimate of the Newtonian constant G should be specified"; p.4: the nominal value "is based on the best available measurement (Petit & Luzum 2010) but rounded to the precision to which both TCB and TDB values agree" |
| S24 | test/planets/earth.jl:48 (branch 52v.4.5) | Earth mass = (GM)N_E / G | prsa2016 (read) | Table 1, nominal terrestrial mass parameter | fit | p.3 Table 1: "3.986004x10^14 m3 s-2"; p.4: "adopted from the geocentric gravitational constant from the IAU 2009 system of astronomical constants (Luzum et al. 2011), but rounded" |
| S25 | test/planets/earth.jl:54 (branch 52v.4.5) | `DeclaredBulk(volumetric_mean_radius = 6_371_008.4)` | archinal2018 (read) | Table 4, Earth mean radius row | NOT FIT (C2) | as S2: the Table 4 Earth mean radius is (2a+b)/3 of the same table's radii to its last digit, 8 m above the volumetric radius; the field is the volumetric mean radius (src/Systems/planet.jl:28-33; decision 0005, Consequences). Moritz 2000 p.131 (read row, the same page read for omega) prints "R3 = 6 371 000.7900 m, radius of sphere of same volume" for GRS80, and "R1 = (2a+b)/3 = 6 371 008.7714 m" beside it |
| S26 | test/planets/earth.jl:58 (branch 52v.4.5) | sidereal rotation period 2 pi / omega | moritz2000 (read) | p.131 | fit | as S5 |
| S27 | test/planets/earth.jl:92 (branch 52v.4.5) | semi-major axis 1.00000261 au | standish1992 (read) | Table 1, EM Bary row | fit | Table 1, "Keplerian elements and their rates, with respect to the mean ecliptic and equinox of J2000, valid for the time-interval 1800 AD - 2050 AD": "EM Bary 1.00000261 0.01671123 -0.00001531 100.46457166 102.93768193 0.0" |
| S28 | test/planets/earth.jl:92-95 (branch 52v.4.5) | the au conversion 149597870700 m "of Prsa et al. (2016)" | prsa2016 (read) | none named beyond the paper | NOT FIT (C5) | p.3: "Resolution B2 of the XXVIII General Assembly of the IAU in 2012 defined the astronomical unit to be a nominal unit of length equal to 149,597,870,700 m": Prsa restates IAU 2012 Resolution B2, the primary, which is not indexed |
| S29 | test/planets/earth.jl:98 (branch 52v.4.5) | eccentricity 0.01671123 | standish1992 (read) | Table 1, EM Bary row | fit | as S27 |
| S30 | test/planets/earth.jl:108-111 with :65 (branch 52v.4.5) | longitude of periapsis 102.93768193 deg beside `equator_ascending_node_longitude = 0` | standish1992 (read) | Table 1, EM Bary row | NOT FIT (C3, frame) | Table 1 counts the heliocentric longitude of perihelion from the J2000 equinox, the direction of the Sun seen from the Earth at the March equinox, so the Earth's own longitude at that equinox is 180 deg in the table's frame. Decision 0004 (The spin axis) puts the planet's true longitude at the vernal equinox at `Omega_E`, and Earth() declares 0. The pair places perihelion 102.9 deg after the vernal equinox, near the June solstice; Berger 1978 Appendix p.2366: "180 deg has to be added to the value numerically obtained" before lambda = nu + omega-tilde holds. Consistent pairs are Omega_E = pi with the tabulated varpi, or Omega_E = 0 with varpi = 282.93768193 deg. The same misreading is in decision 0004 (The seasonal angles are Derived) and docs/plans/fiddlybits-52v.5-time.md:215, carried in D1 and P |
| S31 | test/planets/earth.jl:164 (branch 52v.4.5) | `Numerics(exner_reference_pressure = 101325 Pa)` | tiesinga2021 (read) | Table XXXI, standard atmosphere | NOT FIT (C2) | Table XXXI (continued), p. 033105-51 states 101 325 Pa as the standard atmosphere, a unit of pressure, and 100 000 Pa as the standard-state pressure in the row above; it states neither as the reference pressure of the Exner function, which decision 0013 and docs/plans/fiddlybits-52v.4-system.md (The struct) make a declared convention of the representation. The passage supports the number, not its use |
| S32 | test/planets/synthetic_non_earth.jl:102 (branch 52v.4.5) | liquid-water n and k at 0.5, 0.6, 0.7, 1.0, 1.6, 2.0 um for a normal-incidence reflectance | hale1973 (read) | Table 1 | fit | p.557 Table I: 0.500 um k 1.00e-9 n 1.335; 0.600 1.09e-8 1.332; 0.700 3.35e-8 1.331; 1.0 2.89e-6 1.327; 1.6 8.55e-5 1.317; 2.0 1.1e-3 1.306, each equal to the declared values |
| S33 | src/Orbit/kepler.jl:3-4 | "the residual and the derivative are Markley equations 30 to 35" | markley1995 (read) | eqs. 30-35 | NOT FIT (C2), FIXED | pp.9-10: eq. 30 the derivative; eq. 33 the Pade approximant of the split (1-e)E + eE^3 num/den for e > 0.5 and E < 1 rad; eq. 34 its coefficients; eq. 35 the second derivative. The code uses eq. 30 and the split with its own E - sin E series and no eq. 34, 35 or range switch; the comment now says so |
| S34 | src/Orbit/kepler.jl:87, :115 | Markley's closed form, eqs. 20, 5, 9, 10, 14, 15 and corrections 21-29 | markley1995 (read) | those equations | fit | X1 row 19: the INDEX row is read for the algorithm |
| S35 | test/orbit/runtests.jl:47 | unrefined closed form, eqs. 20-29 | markley1995 (read) | eqs. 20-29 | fit | as S34 |
| S36 | src/Reductions/error_bound.jl:34-41 `validity_limit` | "Higham's n * u <= 1 (1993, discussion following eq. 3.11)" | higham1993 (read, section 2) | discussion after eq. 3.11 | NOT FIT (C6, C2), FIXED | text 0009: "As long as nu <= 1, the constant in this bound is independent of n", section 3 and about compensated summation; the condition on gamma is its definition gamma_n = nu/(1 - nu), text 0002 (p.784), in the read section 2; the docstring now cites p.784 |
| S37 | test/reductions/error_bound.jl:33 | testset name citing the same discussion | higham1993 (read) | as S36 | NOT FIT (C6), FIXED | as S36 |
| S38 | src/Reductions/error_bound.jl:20-30 `ERROR_BOUND_ULP_MARGIN` | a correctly rounded Float64 product lies within half an ulp under round-to-nearest | ieee2019 (read for clause 5.4.1 only) | none | NOT FIT (C6) | rests on clause 4 rounding attributes, which the row does not name as read (X3 case 11); carried by the unread-sections row |
| S39 | test/reductions/fixtures.jl:29 | magnitude an upper bound on sum abs(x_i) | higham1993 (read) | eq. 2.6 | fit | text 0003 (2.6) |
| S40 | src/Systems/gravity.jl, src/Systems/figure.jl, test/system/gravity.jl | "Murray and Dermott (2000)" | murray2000 (read) | year | NOT FIT (C4), FIXED | copyright page text 0004: "First published 1999 / Reprinted 2001, 2004, 2005, 2006, 2008"; now (1999) |
| S41 | test/backends/transcendentals.jl:222-225 | fma correctly rounded, required of fusedMultiplyAdd | ieee2019 (read) | clause 5.4.1 | fit | text 0034 |
| S42 | src/Provenance/key.jl:220, :596 | the value's IEEE 754 bit pattern as canonical bytes | ieee2019 (read) | none | fit | names the binary encoding; no number or law drawn |
| S43 | test/system/earth_ratios.jl:5-21 | the rotation-rate value and its locator | moritz2000 (read) | p.131 | fit | text 0004: omega = 7 292 115 x 10^-11 rad s^-1 |

#### Counts

| total | fit | not fit | not verified |
| --- | --- | --- | --- |
| 43 | 21 | 22 | 0 |

Not fit: S2, S10, S12-S21, S22, S25, S28, S30, S31, S33, S36, S37, S38, S40. Fixed in this branch: S22, S33, S36, S37, S40. S2 and S25 (the radius), S30 (the periapsis frame) and S31 (the Exner reference) are for the user. S10 and S12-S21 are index bookkeeping (the index row and fiddlybits-52v.2.15), with the p.121 locator of S19 carried there; S28 is noted on fiddlybits-52v.4.5; S38 is carried by the unread-sections row.

### D1: Decisions 0001 to 0030


Worktree /home/cfutro/git/fiddlybits/.beads/worktrees/fiddlybits-9j0 at 625832c. Read-only.

#### Counting rule

In scope: a citation the decision body (or an amendment, or a References entry annotated with
the use it anchors) uses as the basis of a law, number, scheme, rule or disposition. Out of
scope and not counted: References-list entries the body never attributes a claim to (background),
pointers to findings, decisions or predecessor archive files. Each source is counted once per
file per distinct use. Page numbers below are printed pages where the text layer shows them;
"text NNNN" is the page file under references/text/<stem>/.

#### Counts

| file | citations | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| 0001, 0002, 0003, 0006, 0007, 0009, 0012, 0014, 0024, 0025, 0028, 0030 | 0 | 0 | 0 | 0 |
| 0004 | 13 | 11 | 2 | 0 |
| 0005 | 9 | 9 | 0 | 0 |
| 0008 | 5 | 3 | 2 | 0 |
| 0010 | 1 | 1 | 0 | 0 |
| 0011 | 1 | 1 | 0 | 0 |
| 0013 | 2 | 2 | 0 | 0 |
| 0015 | 11 | 8 | 1 | 2 |
| 0016 | 8 | 7 | 1 | 0 |
| 0017 | 10 | 9 | 1 | 0 |
| 0018 | 6 | 3 | 2 | 1 |
| 0019 | 3 | 3 | 0 | 0 |
| 0020 | 3 | 1 | 2 | 0 |
| 0021 | 3 | 1 | 1 | 1 |
| 0022 | 1 | 1 | 0 | 0 |
| 0023 | 1 | 1 | 0 | 0 |
| 0026 | 10 | 9 | 0 | 1 |
| 0027 | 1 | 1 | 0 | 0 |
| 0029 | 3 | 3 | 0 | 0 |
| **total** | **91** | **74** | **12** | **5** |

No file in this scope is edited by an open branch. REQ-SYS-102 (docs/requirements/sys/) is not
either. docs/references/INDEX.md is (fiddlybits-k6b).

#### Every citation

| # | where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 0004:120 | positive pole is the pole by the right-hand rule | archinal2018 (read) | p. 22 | FIT | p. 22: "The rotation pole for a body is chosen to be the one following the right-hand rule. This rotation pole is called the positive pole" |
| 2 | 0004:190-194 | lambda0 Irreducible on a body with no observable surface features | archinal2018 (read) | p. 6 | FIT | p. 6: "For planets or satellites with no accurately observable fixed surface features, the expression for W defines the prime meridian" |
| 3 | 0004:204-207 | catalogued body's lambda0 Sourced as W at standard epoch plus rate in days | archinal2018 (read) | Table 1, p. 8 | FIT | p. 8 Table 1 header: "d = Interval in days from the standard epoch", W = W0 + rate d |
| 4 | 0004:241-243 | IAU W measured easterly from node Q at alpha0 + 90 | archinal2018 (read) | p. 6 | FIT | p. 6: "the node Q is defined as the node at alpha0 + 90 ... W, the angle measured easterly along the body's equator from the Q to B" |
| 5 | 0004:322-326 | alternative: north pole by invariable plane, sense from W, some planets with decreasing W | archinal2018 (read) | p. 6; Table 1 p. 8 | FIT | p. 6: "north pole is that pole ... on the north side of the invariable plane ... if W decreases with time, the rotation is said to be retrograde"; p. 8: Venus "W = 160.20 - 1.4813688d" |
| 6 | 0004:237-254 | element set, omega = varpi - Omega, M = L - varpi, R_z(-Omega) R_x(-I) R_z(-omega), x toward equinox | standish1992 html (read) | section Formulae for using the Keplerian elements | FIT | page: "omega = varpi - Omega ; M = L - varpi + bT^2 + c cos(fT) + s sin(fT)"; "r_ecl = R_z(-Omega) R_x(-I) R_z(-omega) r'" "with the x-axis aligned toward the equinox" (the b, c, s, f terms apply only to the outer-planet rows) |
| 7 | 0004:374-376 | alternative: JPL origin is mean ecliptic and equinox of J2000 | standish1992 html (read) | Table 1 heading | FIT | "Keplerian elements and their rates, with respect to the mean ecliptic and equinox of J2000, valid for the time-interval 1800 AD - 2050 AD" |
| 8 | 0004:256-262 | mean position: mean anomaly of a mean earth, lambda_m = M + varpi | berger1978 (read) | Appendix | FIT | p. 2366 Appendix: "M mean anomaly: positional angle of a 'mean' earth rotating around the sun with a constant angular speed ... counted ... from the perihelion"; "lambda_m = M + varpi" |
| 9 | 0004:279-286 | seasonal angles: 180 degrees subtracted, lambda = nu + varpi, sin delta = sin eps sin lambda | berger1978 (read) | Fig. 1 caption; Appendix | FIT | p. 2362 Fig. 1 caption: "For any numerical value of varpi, 180 degrees is subtracted for a practical purpose because observations are made from the earth, and the sun is considered as revolving around the earth"; Appendix p. 2366: "lambda = nu + varpi"; p. 2367: "sin delta = sin eps sin lambda" |
| 10 | 0004:407-411 | alternative: precessional parameter e sin varpi | berger1978 (read) | eq. 2 | FIT | p. 2362: "e sin varpi = sum P_i sin(alpha_i t + zeta_i), (2)"; Table 2 "Precessional parameter" |
| 11 | 0004:453-455 | orbital-element set and hydrostatic figure | Murray and Dermott, murray2000 (read) | "locator in decision 0032" | NOT FIT, C2 | 0032:67-69 gives no locator, only "(tidal torques, rotation and obliquity evolution; the formulation the declared-absence interfaces are shaped by)" |
| 12 | 0004:456-457 | Reference Composition and "the anomaly tolerance the solute inventory's fence is stated against" | millero2008 (held) | none | NOT FIT, C2 | Millero 2008 states the Reference Composition and that anomalies "can be specified accurately relative to" it (text 0005); no tolerance is stated in Millero 2008 or in the TEOS-10 manual (ioc2010, grep "tolerance", "negligible") |
| 13 | 0004:458-459 | names the lithosphere quantities terrain derives | turcotte2014 (held) | none | FIT | naming only, no value or law taken; see #40 for the Sourced use in 0015 |
| 14 | 0005:160-163 | a grid not symmetric across the equator evolves a symmetric state asymmetric | heikes1995 part I (held) | p. 1864 | FIT (note) | p. 1864: "The resulting spherical geodesic grid is not symmetric across the equator ... In Masuda's numerical results, initial conditions that are symmetric across the equator slowly evolve to a state that is asymmetric ... presumably as a result of the flow interacting with the grid" (a report of Masuda and Ohnishi 1987) |
| 15 | 0005:163 | a symmetric grid keeps the response symmetric | heikes1995 part I (held) | p. 1874 | FIT | p. 1874: "while Masuda's fields develop wavenumber 1 patterns that are antisymmetric across the equator, the twig height field remains symmetric across the equator because of the symmetry of the grid" |
| 16 | 0005:219-221 | alternative: twisted icosahedron, southern faces turned a fifth of a turn | heikes1995 part I (held) | p. 1864 | FIT | p. 1864: "By simply rotating all the faces of Fig. 1c in the Southern Hemisphere through pi/5 rad, we obtain a polyhedron that is symmetric ... the twisted icosahedron" |
| 17 | 0005:222-224 | the run grid repositions each level's new points to minimise an error measure | heikes1995 part II (held) | p. 1885 | FIT | p. 1885: "Those grid points that are members of resolution q = 1 but not of q = 0 are allowed to position themselves to minimize R(1)" |
| 18 | 0005:174-176 | vertex-at-pole orientation imprints wavenumber five | wan2013 (read) | p. 747 | FIT | p. 747: "near the pentagon points (cf. Sect. 3), resulting in wavenumber 5 patterns near 26.6 N/S" |
| 19 | 0005:214-215 | ICON grid places a vertex at each pole | wan2013 (read) | p. 738 | FIT | p. 738: "two of the twelve vertices coinciding with the North and South Poles" |
| 20 | 0005:205-207 | alternative: IAU north pole by the invariable plane | archinal2018 (read) | p. 6 | FIT | as #5 |
| 21 | 0005:211-212 | positive pole is IAU convention for dwarf planets, minor planets, satellites, comets | archinal2018 (read) | p. 22 | FIT (note) | p. 22 gives the right-hand-rule positive pole for small bodies; the enumerated classes are on p. 23 ("For dwarf planets, minor planets, their satellites, and comets increasing longitude should always follow the right-hand rule") |
| 22 | 0005:212-213 | the report notes planetary systems could follow it | archinal2018 (read) | p. 39 | FIT (note) | p. 39: a request for input on exoplanets: "such coordinate systems could follow a right-hand rule, similar to that recommended here for dwarf planets" |
| 23 | 0008:177-185 | Kepler solve: residual (1 - e)E + e(E - sin E) - M and derivative 1 - e + 2e sin^2(E/2) | markley1995 (read) | eqs. 30 to 35 | FIT | eq. 30: "f'(E) = 1 - e + 2e sin^2(E/2)"; eq. 31 "f(E) = M*(e,E) - M"; eq. 32-33 M* as E - e sin E or "(1 - e)E + eE^3 numerator/denominator"; eq. 35 "f''(E) = E - M*(e,E)". The series through E^15 and two Newton steps are the project's own, as 0008 says |
| 24 | 0008:169 | W0 at a named epoch, W varying from it | archinal2018 (read) | p. 6 | FIT | p. 6: "W0 is the value of W at J2000.0 (or occasionally ... some other specified epoch)"; "W varies nearly linearly with time" |
| 25 | 0008:121-125, 170 | mean longitude among the elements, M = L - varpi, rates per century from J2000.0 | standish1992 html (read) | Formulae section; Table 1 heading | FIT | as #6, #7; "T, the number of centuries past J2000.0" |
| 26 | 0008:163-166 | instantaneous insolation geometry; secular expansions declared absent | berger1978 (read) | "locator in REQ-SYS-102" | NOT FIT, C2 | REQ-SYS-102 References (one-clock-no-day-unit-no-fixed-calendar.md:113-118) carries no locator and marks the DOI "(to confirm)" |
| 27 | 0008:167-168 | Kepler's equation and element conventions | Murray and Dermott, murray2000 (read) | "locator in decision 0032" | NOT FIT, C2 | as #11; the INDEX read row's locators cover Sect. 4.6 and Eqs. 2.22, 2.25 only, not Kepler's equation |
| 28 | 0010:107, 201 | counter-based generator keyed on seed and identity | salmon2011 (held) | none | FIT | abstract: "counter-based PRNGs are ideally suited to modern multicore CPUs, GPUs" |
| 29 | 0011:35, 80 | compensated summation for accumulated reservoirs | kahan1965 (held) | none | FIT | text 0001: Kahan's remedy for rounding in running sums, "simulate [double precision] ... by a method far simpler than Wolfe's" |
| 30 | 0013:35-37 | operational triangle core suppresses the checkerboard divergence mode by a divergence-averaging filter | wan2013 (read); zangl2015 (read) | none | FIT (note) | Wan p. 741: "divergence operator on the triangular C-grid ... inherently produces gridscale checkerboard error"; "we rely instead on a carefully chosen numerical diffusion to suppress the checkerboard noise"; Zaengl p. 565: "a five-point velocity averaging operator needed to obtain a nearly second-order accurate discretization of divergence" and Eq. 26 fourth-order divergence damping. "Filter" is loose wording for these |
| 31 | 0013:38-41 | Hollingsworth instability from the kinetic-energy gradient and vorticity-flux terms; energy-consistent remedy | hollingsworth1983 (read) | none | FIT | p. 427: "the instability can only be controlled by a redefinition of the finite difference form for grad K. The conservation properties of the EE scheme can be retained and the instability removed" |
| 32 | 0015:39 | theta Bracketed between shear-stress and unit-stream-power derivations under the width exponent | whipple1999 (held) | none | FIT | p. 17663: "Shear stress epsilon = k_b tau_b^a (2a)"; "Unit stream power epsilon = k_b (tau_b V)^a (2b)", coupled with channel-width relations (p. 17664) |
| 33 | 0015:40 | deposition term G q_s / A | yuan2019 (held) | none | FIT | author manuscript text 0006: "G is a dimensionless deposition coefficient, which is a function of the sediment concentration ratio in transport, the settling velocity of sediment, and the mean precipitation rate" |
| 34 | 0015:40 | G is a settling velocity over a runoff rate | davy2009 (held) | none | FIT | para. [27]: deposition term in the net settling velocity v_s over unit discharge; Yuan text 0006: "G/p is identical to Theta as defined in Davy and Lague" |
| 35 | 0015:40 | Sourced settling law with g, rho_w, mu | ferguson2004 (held) | none | FIT | p. 933 title and scope: one equation spanning viscous-drag and inertial settling |
| 36 | 0015:42 | Earth soil-creep diffusivity as the reported distance | roering1999 (held) | none | FIT | p. 854: K_lin linear diffusivity (L^2/T) and the nonlinear transport law |
| 37 | 0015:44 | velocity limb carries gravity only through u_b | herman2015 (held) | none | FIT | p. 193: erosion rate "proportional to the ice-sliding velocity squared" |
| 38 | 0015:44 | abrasion end: erosion proportional to normal contact force times sliding | hallet1979 (held) | none | FIT | text 0002: "The rate of abrasion depends primarily on the effective force with which individual fragments are pressed against the bed, the flux of fragments" |
| 39 | 0015:44 | quarrying end | iverson_2012 (held per INDEX) | none | NOT VERIFIED | file absent from references/pdf and references/text although INDEX:454 says "PDF on disk"; OpenAlex: closed access |
| 40 | 0015:45-46 | half-space cooling forms, flexural rigidity, E and nu Sourced | turcotte2014 (held) | none | NOT FIT, C5 | a textbook stands for the primary sources of Sourced forms and material constants (decision 0030: a textbook table is not a sourced value); the row is held, not read |
| 41 | 0015:46 | GDH1 plate-cooling fit as a tier-2 REPORT | Stein and Stein 1992 (no INDEX row) | none | NOT VERIFIED | not held; paywalled (Nature) |
| 42 | 0015:47 | threshold-channel relation carrying g | parker1978 (held) | none | FIT | p. 130, section 3 "Threshold theory of stable canals", with "g is the acceleration due to gravity" |
| 43 | 0016:55-57 | HITEMP or ExoMol where the temperature bracket exceeds HITRAN completeness | rothman2010, tennyson2016 (held) | none | FIT | titles: "HITEMP, the high-temperature molecular spectroscopic database"; "The ExoMol database: Molecular line lists for exoplanet and other hot atmospheres" |
| 44 | 0016:59-61 | per-perturber widths (H2, He, CO2) | wilzewski2016, tan2022 (held) | none | FIT | titles: "H2, He, and CO2 line-broadening coefficients ... for the HITRAN database"; "H2, He, and CO2 Pressure-induced Parameters for the HITRAN Database. II" |
| 45 | 0016:65-67 | MT_CKD carries water self and water-air foreign continuum for the atmosphere it was built for | mlawer2012 (read) | none | FIT | abstract p. 2520: water vapour continuum "important contributor to the Earth's radiative" balance; INDEX read row section 3 and Table 3 |
| 46 | 0016:67-68 | the water-CO2 continuum is a separate Sourced item | tran2018 (held) | none | NOT FIT, C2 | abstract: "The continuum absorption by CO2 due to the presence of water vapor was determined by subtracting ... the self- and CO2-continua of water vapor"; 2400-2600 cm-1 only; text 0007 takes the CO2-continuum of H2O from "Ma and Tipping, 1992; Pollack et al., 1993" |
| 47 | 0016:70-71 | far-wing sub-Lorentzian shape of a CO2-dominated bulk | perrin1989 (held) | none | FIT (note) | abstract: chi factors "in the 193-773 K range for both CO2-CO2 and CO2-N2", 4.3 um band, 2100-2600 cm-1; the validity range is not recorded in 0016 |
| 48 | 0016:71-73 | collision-induced absorption per bulk-gas pair from HITRAN CIA | karman2019 (held) | none | FIT | title: "Update of the HITRAN collision-induced absorption section" |
| 49 | 0016:128-130 | z0 = alpha u*^2 / g | charnock1955 (held) | none | FIT (note) | summary: "the simplest non-dimensional relation between them, g z(0)/u*^2 = constant". The bracket mechanisms in the same parenthesis are not Charnock's |
| 50 | 0016:134-136 | scalar roughness in roughness Reynolds number, Prandtl and Schmidt numbers | brutsaert1975 (held) | none | FIT | p. 543: molecular diffusion in the interfacial sublayer joined to surface-sublayer similarity |
| 51 | 0017:26-31 | GM kappa as Rossby radius squared over Eady growth time | visbeck1997 (held) | none | FIT | p. 383: "Stone (1972) ... suggests that the length scale of baroclinic eddies - the Rossby radius of deformation - is the appropriate eddy transfer scale"; "f/sqrt(Ri) is a measure of the growth rate of an Eady wave"; alpha "a constant of proportionality" |
| 52 | 0017:52-53 | interior diffusivity's wind and tide mechanisms and its leverage on overturning | munk1998 (held) | none | FIT | p. 1977: "The winds and tides are the only possible source of mechanical energy to drive the interior mixing"; overturning "would not exist without" it |
| 53 | 0017:66-70 | TEOS-10 saline part fitted to the Reference Composition; Absolute Salinity defined against it | millero2008 (held) | none | FIT | p. 50 abstract: S_R defined on the Reference Composition, "as a reference for natural seawater composition anomalies" |
| 54 | 0017:61-65 | pure-water limb IAPWS-95 Sourced for density, viscosity, thermal conductivity, heat capacity | wagner2002 (held; no References entry in 0017) | none | NOT FIT, C2 | Wagner and Pruss 2002 is "The IAPWS Formulation 1995 for the Thermodynamic Properties of Ordinary Water Substance"; none of "viscos", "conductiv", "transport" occurs in its 149 pages |
| 55 | 0017:99-101 | Wanninkhof 2014 fitted at Earth air density, calibrated on the radiocarbon inventory | wanninkhof2014 (held) | none | FIT | p. 351: "the globally integrated bomb-14CO2 flux into the ocean remains unchanged ... using revised global ocean 14C inventories" |
| 56 | 0017:135-138 | dissipation derived by internal-tide conversion, local efficiency and decay scale Bracketed; altimetry the Earth comparison | laurent2002 (held); egbert2000 (held) | none | FIT | abstract: "a parameterization for internal wave energy flux ... We assume that 30 +/- 10% ... dissipates ... near the site of generation ... modeled to decay away from topography" |
| 57 | 0017:161-164 | Winton three-layer with brine-pocket heat capacity and conductivity | winton2000 (held) | none | FIT | p. 525: "the brine content of the upper ice is represented with a variable heat capacity" |
| 58 | 0017:173-175 | Hibler lead-closing thickness | hibler1979 (held) | none | FIT | p. 820 eq. 16: "h_0 a fixed demarcation thickness between thin and thick ice (0.5 m ...)" |
| 59 | 0017:178-179 | Maykut and Perovich lateral-melt fit with Arctic provenance | maykut1987 (held) | none | FIT | p. 7033: lateral melting on floe edges and its model |
| 60 | 0017:120-124 | strait exchange by rotating hydraulic control | whitehead1998 (held) | none | FIT | p. 424: "theoretical studies of the critical control problem for rotating fluids" |
| 61 | 0018:48 | fresh-snow density Bracketed from "the source fit in air temperature (Anderson 1976)" | anderson1976 (held) | none | NOT FIT, C2 | text 0075-0076: "density of new snow is based on a plot ... for Alta, Utah [LaChapelle (1969)] ... rho_ns = 0.05 + 0.0017 (T_w - 258.16)^1.5 (4.22)", "T_w = wet-bulb temperature" |
| 62 | 0018:55 | threshold carrying g, particle density and air density | shao2000 (read) | none | FIT | p. 22437: u*t with "sigma_p is particle to air density ratio, and g is acceleration due to gravity" |
| 63 | 0018:55 | Earth fit reported against | Iversen and White 1982 (no INDEX row) | none | NOT VERIFIED | not held; paywalled; its title covers "Earth, Mars and Venus", so "the Earth fit" needs the passage |
| 64 | 0018:52 | published lake diffusivity's square root of the sine of latitude | hostetler1990 (held) | none | FIT | p. 2604 eq. 7: "k* = 6.6 (sin phi)^(1/2) U_2^-1.84" |
| 65 | 0018:33-38 | orographic precipitation conversion and fallout time scales | smith2004 (held) | none | FIT | p. 1378: "equations for advection, conversion, and fallout of condensed water" |
| 66 | 0018:55 | emission coefficient Bracketed "between the two published fitting populations" | kok_2014 (read) | none | NOT FIT, C2 | p. 13033: "We obtain Ce = 2.0 +/- 0.3 and Cd0 = (4.4 +/- 0.5) x 10^-5 from least" squares over one compilation; no two fitting populations found |
| 67 | 0019:43-48 | permeability by hydrolithology, spread, depth of validity | gleeson_2011 (read) | none | FIT | p. 2: "Only hydrogeologic units that occur at shallow depths (<100 m) are" used; Table 1 |
| 68 | 0019:61-65, 148 | Darcy-Weisbach velocity with g explicit | henderson1966 (held) | none | FIT | text 0058 eq. (4-8): "C = sqrt(8g/f)" |
| 69 | 0019:15-19 | depression hierarchy and fill-spill-merge | barnes2020, barnes2021 (held) | none | FIT | titles: "Part 1: The depression hierarchy"; "Part 3: Fill-Spill-Merge: flow routing in depression hierarchies" |
| 70 | 0020:25-33 | Bahr exponent from Glen's n and mass-balance exponent; coefficient by the same argument; both Derived | bahr1997 (held) | none | NOT FIT, C2 | p. 20357: "gamma is fixed for any choice of the scaling exponents q, r, f, m, and n"; p. 20358: "four closure choices must be made, one for each of the scaling exponents related to glacier width (q), slope (r), side drag (f), and mass balance (m)". No coefficient is derived; c_m and c_0 "are constants for any one glacier" (p. 20359) |
| 71 | 0020:21 | Halfar similarity solution as the right answer | halfar1983 (held) | none | FIT | p. 6043: "a cylindrically symmetric similarity solution" |
| 72 | 0020:51, 128 | Glen's A(T) and n Sourced (material) | cuffey2010 (held) | none | NOT FIT, C5 | textbook for Sourced material constants; primary glen1955 is held; the row is held, not read |
| 73 | 0021:88-91 | Bernacchi mole-fraction constants converted "at their calibration pressure" | bernacchi2001 (held) | none | NOT FIT, C2 | p. 253 notation gives Kc, Ko, Gamma* in umol mol-1; site "Urbana, IL" (p. 254); no measurement pressure stated (only vapour pressure deficit in kPa, text 0003) |
| 74 | 0021:92-93 | C4 as a CO2-concentrating form | von Caemmerer 2000 (requested) | none | NOT VERIFIED | not held; paywalled book |
| 75 | 0021:42 | Farquhar-von Caemmerer-Berry photosynthesis | farquhar1980 (held) | none | FIT | title: "A biochemical model of photosynthetic CO2 assimilation in leaves of C3 species" |
| 76 | 0022:12-18, 100 | production decaying with thickness | heimsath_1997 (read) | none | FIT | p. 359: "the hypothesis that soil production rates decline with increasing soil thickness" |
| 77 | 0023:57-59, 123 | slow-pool accelerator invalid for peat and inert permafrost carbon | willeit_2016 (held) | none | FIT | p. 3819: slow processes "such as accumulation of carbon in peatlands, inert carbon locked in perennially frozen ground" |
| 78 | 0026:53-55 | cosine bell, steady geostrophic flow, isolated mountain, Rossby-Haurwitz | williamson1992 (held) | none | FIT | sect. 3.1 "Advection of Cosine Bell over the Pole", 3.5 "Zonal Flow Over an Isolated Mountain", 3.6 "Rossby-Haurwitz Wave" |
| 79 | 0026:56-57 | baroclinic steady state and wave | jablonowski2006 (held) | none | FIT | abstract: "a steady-state solution ... Then an overlaid perturbation is introduced which triggers the growth of a baroclinic disturbance" |
| 80 | 0026:58 | idealised Held-Suarez forcing | held1994 (held) | none | FIT | p. 1826: "simple Newtonian relaxation of the temperature field ... and Rayleigh damping of low-level winds" |
| 81 | 0026:63-65 | Hollingsworth check | hollingsworth1983 (read) | none | FIT | as #31 |
| 82 | 0026:129-133 | published profile set with line-by-line clear-sky fluxes, "one composition at one gravity" | Pincus et al. 2015 (no INDEX row) | none | NOT VERIFIED | not held; one fetch of the Wiley OA copy returned HTTP 403. OpenAlex abstract: reference fluxes "under present-day conditions and forcing ... from quadrupled concentrations of carbon dioxide", which is two compositions |
| 83 | 0026:127-128 | two-band analytic temperature profile | guillot2010 (held) | none | FIT | abstract: "parameterized as a function of mean visible and thermal opacities" |
| 84 | 0026:92 | shallow-ice similarity dome | halfar1983 (held) | none | FIT | as #71 |
| 85 | 0026:72 | mixed-form discretisation exact to roundoff | celia1990 (held) | none | FIT | p. 1483: "A General Mass-Conservative Numerical Solution"; the mixed form contrasted with the h-based form |
| 86 | 0026:14-24 | manufactured-solution rule | roache2002 (held) | none | FIT | title: "Code Verification by the Method of Manufactured Solutions" |
| 87 | 0026:89 | Rothermel's published cases including a slope case | rothermel1972 (held) | none | FIT | contents: "Effect of Wind and Slope", "Slope Coefficient ... 24" |
| 88 | 0027:21-28, 62 | mutation testing as a measure of test adequacy | demillo1978 (held) | none | FIT | p. 36: "Test data that leaves no live mutants ... is adequate" |
| 89 | 0029:55, 115 | counter-based generator | salmon2011 (held) | none | FIT | as #28 |
| 90 | 0029:11-13, 117 | fixed-order pairwise summation | higham1993 (read) | none | FIT | p. 788: "pairwise summation ... repeated recursively"; bound (3.6) proportional to log2 n |
| 91 | 0029:51-52, 119 | compensated summation | kahan1965 (held) | none | FIT | as #29 |

#### Not fit

1. **0004:453-455, Murray and Dermott, "locator in decision 0032".** Use: the orbital-element set and
   the hydrostatic figure. C2: decision 0032:67-69 names topics, not a table, equation or page. The
   INDEX read row (murray2000) carries Sect. 4.6, Eqs. 4.101 to 4.113, pp. 150-153 for the figure.
   Fix (a): cite that locator for the figure; the element set is already carried by Standish (read,
   #6). Decision text only; not edited by an open branch.
2. **0004:456-457, Millero et al. 2008, "the anomaly tolerance".** C2: neither Millero 2008 nor the
   TEOS-10 manual (ioc2010, held) states a tolerance; Millero says only that anomalies "can be
   specified accurately relative to" the Reference Composition (text 0005). 0017:73-74 and
   0004:95-97 make seawater thermodynamics Irreducible inside that tolerance, so the fence has no
   read basis. Fix (b) and (d): read a source that quantifies the error of the Reference-Composition
   functions under composition anomalies (TEOS-10 manual section 2.5 and its appendix on anomalies,
   or McDougall et al. 2012), register the tolerance, and amend 0004 and 0017. It changes a
   decision's stated basis.
3. **0008:163-166, Berger 1978, "locator in REQ-SYS-102".** C2: REQ-SYS-102's entry carries no
   locator and marks its DOI "(to confirm)". Fix (a): point to decision 0004's Berger locators
   (Fig. 1 caption, eq. 2, Appendix), verified here (#8 to #10).
4. **0008:167-168, Murray and Dermott, "locator in decision 0032".** Use: Kepler's equation and the
   element conventions. C2, as #1. Fix (a): Kepler's equation and its solve are carried by Markley
   1995 (read, #23) and the Standish Formulae section (read, #25); drop the pointer or add a read
   Murray locator (b).
5. **0015:45-46, Turcotte and Schubert 2014.** Use: half-space cooling forms, flexural rigidity, E and
   nu, all `Sourced`. C5: a textbook stands for the primary sources, and the row is held. Fix (b):
   read the forms at a named equation (in the book, with the primary it attributes them to) and the
   material constants from a primary compilation; a row.
6. **0016:67-68, Tran et al. 2018 as "the water-CO2 continuum".** C2: the paper measures the CO2
   continuum induced by H2O in 2400 to 2600 cm-1. It subtracts the H2O continuum broadened by CO2,
   taken from Ma and Tipping (1992) and Pollack et al. (1993) (text 0007). Read in parallel with
   "MT_CKD carries the water self-continuum and the water-air foreign continuum", 0016 means water
   absorbing with CO2 as perturber, which Tran 2018 does not provide. Fix (d) with (b): name both
   pairs (CO2 absorber with H2O perturber: Tran 2018 with its range; H2O absorber with CO2 perturber:
   a read source such as Ma and Tipping 1992), each with its range. It changes a decision's basis.
7. **0017:61-65, IAPWS-95 for viscosity and thermal conductivity.** C2: IAPWS-95 (Wagner and Pruss
   2002, held) covers thermodynamic properties only; no occurrence of viscosity, conductivity or
   transport in 149 pages. 0017 has no References entry for it. The transport properties are separate
   IAPWS releases (viscosity 2008, thermal conductivity 2011), not indexed. Fix (d) with (b): fetch
   and read those releases (open access from iapws.org) and name them in 0017; 0015, 0019 and 0026
   read viscosity through this door. It changes a decision's basis.
8. **0018:48, Anderson 1976, "the source fit in air temperature".** C2: Anderson's Eq. (4.22) is in
   wet-bulb temperature T_w, from LaChapelle's (1969) Alta, Utah plot (text 0075-0076). So the
   "wet-bulb form" end is Anderson itself, and the air-temperature form is some later adaptation not
   cited. A C5 aspect too: Anderson re-fits LaChapelle's data. Fix (d): re-argue both bracket ends of
   fresh-snow density with read sources (REQ-ATM-010 carries the same bracket, outside this scope).
   It changes the basis of a Bracketed constant's ends.
9. **0018:55, Kok et al. 2014, "the two published fitting populations".** C2: Part 1 gives one
   least-squares fit, Cd0 = (4.4 +/- 0.5) x 10^-5 and Ce = 2.0 +/- 0.3 (p. 13033); no two fitting
   populations found. Fix (d) with (b): state the bracket ends from the read uncertainty, or name the
   two populations with a locator. It changes a Bracketed constant's basis.
10. **0020:25-33, Bahr et al. 1997.** C2: the exponent depends on four closure exponents, for width
    (q), slope (r), side drag (f) and mass balance (m), plus n (pp. 20357-20358), not on n and m
    alone. The paper derives no coefficient: its scaling gives proportionality only, and the
    mass-balance constants are per glacier (p. 20359). So the `Derived` disposition of the
    volume-area coefficient has no read basis. Fix (d): a disposition decision.
11. **0020:51, 128, Cuffey and Paterson 2010 for Glen's A(T) and n.** C5: a textbook table for
    `Sourced` material constants; the primary glen1955 is held; the row is held. Fix (b): read Glen
    1955 for n and the primary compilation behind A(T), and anchor them; a row.
12. **0021:88-91, Bernacchi et al. 2001, "at their calibration pressure".** C2: the constants are
    mole fractions (umol mol-1), and no measurement pressure is stated; the site is Urbana, Illinois.
    Converting at a "calibration pressure" needs a value the source does not give. Fix (d): the
    conversion pressure becomes Bracketed, or derived from a separately read site elevation, rather
    than read from Bernacchi (REQ-BIO-007 carries the same, outside this scope). It changes a
    disposition and a decision's basis.

#### For the user's decision (class d)

#2 (Reference-Composition anomaly tolerance, 0004 and 0017), #6 (water-CO2 continuum pair, 0016),
#7 (IAPWS-95 standing for the transport properties, 0017), #8 (fresh-snow density bracket ends,
0018), #9 (dust emission coefficient bracket, 0018), #10 (Bahr coefficient Derived, 0020),
#12 (Bernacchi conversion pressure, 0021).

Fix-class (a), citation or locator only, with the correct source already read: #1, #3, #4.
Fix-class (b), rows: #5, #11 (and the (b) halves of #2, #6, #7, #9).

#### Fetch failures and paywalled sources

- Pincus, R., et al. "Radiative flux and forcing parameterization error in aerosol-free clear skies."
  Geophysical Research Letters 42 (2015). DOI 10.1002/2015GL064291. Open access (hybrid); one fetch of
  https://agupubs.onlinelibrary.wiley.com/doi/pdfdirect/10.1002/2015GL064291 returned HTTP 403.
- "A theory of glacial quarrying for landscape evolution models", Iverson 2012, Geology 40. DOI
  10.1130/G33079.1. Closed access (OpenAlex). INDEX:454 claims the PDF is on disk; it is not.
- "A model for the global variation in oceanic depth and heat flow with lithospheric age", Stein and
  Stein 1992, Nature 359. DOI 10.1038/359123a0. Paywalled; no INDEX row.
- "Saltation threshold on Earth, Mars and Venus", Iversen and White 1982, Sedimentology 29. DOI
  10.1111/j.1365-3091.1982.tb01713.x. Paywalled; no INDEX row.
- "Biochemical Models of Leaf Photosynthesis", von Caemmerer 2000, CSIRO Publishing. DOI
  10.1071/9780643103405. Paywalled; INDEX requested.

#### Adjacent observations (not citations in scope; for the parent)

- The DOIs in the decisions differ from INDEX for two works: Williamson et al. 1992 (0013, 0026:
  10.1016/S0021-9991(05)80016-6; INDEX 10.1016/0021-9991(92)90060-c) and White and Bromley 1995
  (0013: 10.1002/qj.49712152202; INDEX 10.1256/smsqj.52207). Both are probably alias DOIs; confirm.
- References in 0001 to 0030 with no INDEX row, against decision 0030's lint consequence: Stein and
  Stein 1992, Iversen and White 1982, Pincus 2015, Raupach 1994, Monteith 1977, Bohren and Huffman
  1983.
- Heikes and Randall Parts I and II are INDEX `held`, anchored REQ-TER-011 only. Decision 0005
  cites pp. 1864, 1874 and 1885 as the basis of its orientation choice, and those passages were
  verified here, so the rows can move to `read` anchored to 0005 (INDEX.md is edited by
  fiddlybits-k6b).
- 0026:113-114: "a pairwise-summed ledger may use the square root of N" is uncited. Higham 1993
  (read, cited by 0029) bounds pairwise summation by a factor of log2 n (eq. 3.6), not sqrt(N).
- Standish 1992 is a JPL web page reformatting Standish and Williams. It fits for definitions. For
  numeric `Sourced` values (test/planets on fiddlybits-52v.4.5) it is a reformat standing for the
  primary: a C5 question for the code scope.
- Perrin and Hartmann 1989 (#47): the chi factors hold for the 4.3 um band at 193 to 773 K. 0016
  requires ranges for continua; the far-wing item should record this one too.

### D2: Decisions 0031 onward


Worktree tree at 625832c. Every citation a decision uses as the basis of a law, number,
scheme or rule, including amendments. Background mentions, pointers to other decisions,
plans, rows and findings not cited for a number are not counted.

#### Counts

| file | citations | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| 0031 | 5 | 0 | 4 | 1 |
| 0032 | 0 (three references, background only: no law or number taken) | - | - | - |
| 0033 | 0 (five references, background only) | - | - | - |
| 0034, 0035, 0037, 0038, 0039, 0040, 0042, 0043, 0046, 0047, 0048, 0049, 0050, 0051, 0053, 0054, 0057, 0060 | 0 (no external source used as a basis; findings cited state no number in the decision's text) | - | - | - |
| 0036 | 2 | 2 | 0 | 0 |
| 0041 | 2 | 1 | 1 | 0 |
| 0044 | 2 | 2 | 0 | 0 |
| 0045 | 1 | 0 | 1 | 0 |
| 0052 | 5 | 3 | 2 | 0 |
| 0055 | 3 | 3 | 0 | 0 |
| 0056 | 1 | 0 | 1 | 0 |
| 0058 | 3 | 3 | 0 | 0 |
| 0059 | 48 | 48 | 0 | 0 |
| **total** | **72** | **62** | **9** | **1** |

Of the 9 not-fit cases, 4 are index bookkeeping only: the passage read supports the use,
and the gap is that INDEX.md does not record the read.

#### Every citation

Text pages are `references/text/<stem>/<NNNN>.txt` in the main checkout; printed pages are
given where the journal paginates.

| # | where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 0031:41 (Layer 2) | the non-rotating critical-flow limit is the f-to-zero case of the same control forms | Whitehead 1998, 10.1029/98RG01014 (held) | none given | NOT FIT: C6, C5 | p.427 (text 0005): "(13) is familiar to hydraulic engineers in the limit of f = 0 ... As f is increased from 0, it smoothly connects the nonrotating result to equation (12)". Content supports the use; row held; the forms are credited to Whitehead, Leetmaa and Knox 1974 (p.426, text 0004) |
| 2 | 0031:96-97 (Alternatives) | upstream height above sill depth sets a passage's transport | Whitehead 1998 (held) | p. 427, eqs. 12-13 | NOT FIT: C6, C5 | p.427 (0005): eq. (12) Q = g' h_u^2/2f, eq. (13) in h_u, the "upstream fluid surface height above sill depth h_u". Content fits; row held; review stands in for the 1974 primary |
| 3 | 0031:120-122 (Consequences) | the control forms treat one passage; boundaries with many gaps are outside the review | Whitehead 1998 (held) | p. 424 | NOT FIT: C6 | p.424 (0002): "A particular case in which there are boundaries with many gaps ... will not be reviewed here". Content fits; row held |
| 4 | 0031:114-116 (Consequences; amendment 2026-09-13) | one gate per body pair, as one lowest outlet per depression pair | Barnes, Callaghan and Wickert 2020, 10.5194/esurf-8-431-2020 (held) | section 3.3, p. 438 | NOT FIT: C6 | p.438 (0008): "If any entry for an outlet is already present, only the outlet of lower elevation is retained ... only the location of the lowest outlet is recorded". Content fits; row held |
| 5 | 0031:66-70, 150-152 | fluid refinement boundaries graded, since an abrupt 2:1 step reflects waves | Harris and Durran 2010, 10.1175/2010MWR3080.1 (not in INDEX, REQUESTS or design-citations) | none | NOT VERIFIED | not on disk; one fetch attempt returned an empty body |
| 6 | 0036:14-17 | TOML has one float syntax and one integer syntax; dates are TOML dates | TOML v1.0.0 spec, https://toml.io/en/v1.0.0 (web spec, not indexed) | none | FIT | fetched: "Integers are whole numbers"; "A float consists of an integer part ... followed by a fractional part and/or an exponent part"; Offset Date-Time section |
| 7 | 0036:23-28 | YAML 1.1 reads 5.0e4 and 1e+10 as strings (rejects YAML) | predecessor CLAUDE.md, cited as a predecessor record | conventions | FIT | /home/cfutro/git/vesper/CLAUDE.md:123-124: "1.1 wants a sign in the exponent and a point in the mantissa, so 5.0e4 and 1e+10 are STRINGS". The relocation amendment is present. The YAML 1.1 spec itself is not cited; the decision cites what the predecessor recorded |
| 8 | 0041:34-40, 125-131 | the SSP333 tableau (SSP3(333)c) of the fast tier | Gardner et al. 2018, 10.5194/gmd-11-1497-2018 (held) | none (the tableau table is named but not located) | NOT FIT: C6, C5 | the decision states "Held, not yet read" and status is proposed. p.1501 (0005): "SSP3(333)b and SSP3(333)c from Conde et al. (2017)"; the tableau's primary is not indexed. The properties the decision states (third order, three implicit stages, singly diagonally implicit at the default parameter) are not tied to any page |
| 9 | 0041:39-46, 132-137 | ARS343 comparison arm, coefficients checked | Ascher, Ruuth and Spiteri 1997 (read) | section 2.7 | FIT | text 0008: "2.7. L-stable, three-stage, third-order DIRK (3, 4, 3)"; INDEX row names the same section |
| 10 | 0044:53, 427-433 | fma is the single correctly rounded fused operation | IEEE Std 754-2019 (read) | clause 5.4.1, formatOf-fusedMultiplyAdd | FIT | text 0034: "computes (x x y) + z as if with unbounded range and precision, rounding only once to the destination format ... differs from a multiplication operation followed by an addition operation" |
| 11 | 0044:434-436 | the bound Reductions.error_bound carries | Higham 1993, 10.1137/0914050 (read) | (2.6) per INDEX | FIT | text 0003: "(2.6) \|E_n\| <= gamma_{n-1} sum \|x_i\|"; gamma_n defined on text 0002 (p.784) |
| 12 | 0045:36-47, 118-120 | a Float32 round trip of a value that survives is exact at every wider format | IEEE Std 754-2019 (read) | clause 5.4.2 | NOT FIT: C6 (bookkeeping) | text 0035: "Conversion to a format with the same radix but wider precision and range is always exact"; a narrower conversion "shall be rounded". Content fits; the INDEX anchors column names clause 5.4.1 only |
| 13 | 0052:20-29, 111-112 | the key is the SHA-256 digest; "fixed by its standard" | FIPS 180-4, 10.6028/NIST.FIPS.180-4 (held) | none | NOT FIT: C6 (bookkeeping) | section 6.2 SHA-256 (text 0027) defines the digest. The decision itself says FIPS does not state the uniformity property it assumes, and the suite checks it. Row held |
| 14 | 0052:66-71, 113-116 | the Philox generator named in a rejected alternative | Salmon et al. 2011, 10.1145/2063384.2063405 (held) | section 4.3 | NOT FIT: C6 (bookkeeping) | text 0007: "4.3 The Philox PRNG". Content fits; row held |
| 15 | 0052:74-76 | the Random stdlib may change the stream a seed produces between Julia versions | Julia Random stdlib documentation (not indexed) | none | FIT | /usr/share/julia/stdlib/v1.12/Random/docs/src/index.md:349-352, "# Reproducibility ... a minor release of Julia" may change the stream |
| 16 | 0052:57-62 | the prefix reaches one residue class on the level-5 mesh case and only even positions on the stand-in | notes/findings/2026-09-13-the-bit-reversed-prefix-perturbs-one-residue-class.md | "What each member set reaches" | FIT | finding lines 26-46: the prefix identity, the two cases, and the residue table |
| 17 | 0052:117-118 | the member count rule and its with-replacement bound | notes/findings/2026-09-11-ulp-ensemble-member-count.md | section "The member count" | FIT | finding line 105 heading, 229 row |
| 18 | 0055:22-29, 186-187 | the card checks the index against the length only, with no lower bound | CUDACore 6.3.1 src/device/array.jl | arrayref, arrayset | FIT | lines 85 and 130: "@boundscheck index <= length(A) \|\| Base.throw_boundserror(A, index)" |
| 19 | 0055:187 | a bounds error is a reported kernel exception | CUDACore 6.3.1 src/device/quirks.jl | throw_boundserror | FIT | lines 51-53, a @device_override of Base.throw_boundserror |
| 20 | 0055:188 | inbounds=true on a kernel | KernelAbstractions 0.9.42 src/macros.jl | inbounds=true | FIT | lines 13, 43, 49, 101: force_inbounds passed through transform_cpu! and transform_gpu! |
| 21 | 0058:138-139 | the CPU launch splits blocks across threads | KernelAbstractions 0.9.42 src/cpu.jl | __run, __thread_run | FIT | lines 98 and 129 |
| 22 | 0058:21, 139-140 | the CUDA launch of cld(n, w) blocks and the dynamic path | CUDACore 6.3.1 src/CUDAKernels.jl | cld, launch_configuration | FIT | lines 130-136 |
| 23 | 0058:23, 141-142 | the occupancy API and warpsize | CUDACore 6.3.1 lib/cudadrv/occupancy.jl, devices.jl | warpsize | FIT | devices.jl:174 `warpsize(dev::CuDevice) = attribute(dev, DEVICE_ATTRIBUTE_WARP_SIZE)`; occupancy.jl present |
| 24 | 0056:37-43, 110-116 | a product of two binary32 values needs at most 48 bits, exact in binary64 | IEEE Std 754-2019 (read) | clause 3.6, Table 3.5, row p | NOT FIT: C6 (bookkeeping) | text 0024: Table 3.5, "p, precision in bits", 24 for binary32 and 53 for binary64. Content fits; the INDEX anchors column names clause 5.4.1 only |
| 25 | 0059:25-28 | the checkerboard mode is pronounced where the deformation radius is comparable to the spacing | Gassmann 2011 (read) | section 8, p.2719; section 9, p.2720 | FIT | p.2719 (0014): r_d = 0.5 "to mimic ... small equivalent depths", checkerboard "clearly developed"; p.2720: "visible especially for modes of small equivalent depths" |
| 26 | 0059:27-28 | faint in the standard barotropic suite | Wan et al. 2013 (read) | section 4.3, p.741 | FIT | p.741 (0007): noise "less apparent in the barotropic tests ... significantly affects three-dimensional baroclinic simulations". Supports the barotropic-versus-baroclinic half; the deformation-radius half is Gassmann's |
| 27 | 0059:28-30, 239-241 | an averaged divergence hides the mode, which returns under nonlinearity | Gassmann 2011 (read) | section 7.2, p.2717 | FIT | p.2717 (0012): "the related problem is only veiled, and will reappear"; p.2720: "veils the checkerboard pattern in linear runs" |
| 28 | 0059:73-76 | a four-point reconstruction gives a stronger pattern than an eight-point one | Gassmann 2011 (read) | section 7.2, p.2716; section 8 with Figs. 5, 6, pp.2718-2720 | FIT | p.2719: "more pronounced with the V4 vector reconstruction, whereas it is mitigated with the V8"; p.2720: "The V4 version exhibits a more intense checkerboard" |
| 29 | 0059:78-79 | the alternative reconstruction from the edge inner product | Gassmann 2011 (read) | section 6, pp.2713-2714 | FIT | p.2713 (0008): "access to an inner product operator at grid edges ... Here we exploit both" |
| 30 | 0059:115-118 | an averaged divergence couples each triangle only to its own orientation, giving zero-frequency shortest waves | Gassmann 2011 (read) | section 7.2, p.2717 | FIT | p.2717 (0012): "solely from either upper tip or lower tip triangles ... introduces again stationary frequencies of the shortest resolvable waves" |
| 31 | 0059:80-82 | RBF reconstruction carries a kernel and shape parameter, and energy is not conserved | Wan et al. 2013 (read) | sections 5.2, 5.9, pp.743-744 | FIT | p.743 (0009): "inverse multi-quadric kernel ... shape parameter"; p.744 (0010): "do not guarantee energy conservation ... partly due to the tangential wind reconstruction using the RBFs" |
| 32 | 0059:96-101 | one ring gives a second-order divergence on a regular grid; a wider stencil breaks tracer-air-mass consistency | Wan et al. 2013 (read) | section 4.3, p.741 | FIT | p.741 (0007): "four-cell stencil ... second-order divergence operator on a regular grid"; "will destroy the tracer-and-airmass consistency" |
| 33 | 0059:126-128 | the vector biharmonic cancels part of the first-order divergence error | Wan et al. 2013 (read) | section 4.3, eqs. (16)-(19), p.742 | FIT | p.742 (0008): an additional effect removes "(to some extent) the leading error in divergence" |
| 34 | 0059:128-129 | the dissipation damps the flow along with the mode | Wan et al. 2013 (read) | section 8, p.757 | FIT | p.757 (0023): "a rather strong damping of the flow" |
| 35 | 0059:132-133, 234-238 | the eq. (20) coefficient removes the error in one step and gives up a physical choice | Wan et al. 2013 (read) | eq. (20), section 4.3, p.742 | FIT | p.742 (0008): "no longer the freedom to choose the magnitude of the hyperdiffusion by physical arguments"; p.757: "removed after each time step" |
| 36 | 0059:193-194 | a single triangle's divergence is first order | Wan et al. 2013 (read) | section 4.2, eq. (10), p.740 | FIT | p.740 (0006): "a first-order approximation ... the first-order error term changes sign" |
| 37 | 0059:92-96 | velocity averaging keeps each edge flux single-valued and local mass conserved | Zaengl et al. 2015 (read) | section 2.3, p.565; Appendix A2, p.575 | FIT | p.565 (0003): velocity-averaging operator; p.566 (0004): "local mass conservation to machine" precision; p.575 A2 contrasts it with "a posteriori averaging to the divergence (which compromises local mass conservation ...)" |
| 38 | 0059:96-97 | tracer transport takes the core's time-averaged mass fluxes | Zaengl et al. 2015 (read) | section 2.4, p.566 | FIT | p.566 (0004): "Mass-consistent transport is achieved by passing time-averaged air-mass fluxes" |
| 39 | 0059:101-105 | weights from conditions (A1)-(A3), reconciled by an empirical relaxation | Zaengl et al. 2015 (read) | Appendix A1, p.575 | FIT | p.575 (0013): (A1), (A2), (A3) and "an empirical iterative relaxation-diffusion approach", "empirically determined relaxation coefficient" |
| 40 | 0059:107-108, 239-240 | averaging the computed divergence gives up local mass conservation and tracer-mass consistency | Zaengl et al. 2015 (read) | Appendix A, p.575 | FIT | p.575: averaging the locally computed divergence "compromises local mass conservation and tracer-mass continuity" |
| 41 | 0059:225-227 | the operational core pairs the velocity average with fourth-order divergence damping | Zaengl et al. 2015 (read) | section 2.5, p.568 | FIT | p.567 (0005), eq. (26): "Fd(v) ... fourth-order divergence damping term"; p.568 (0006) continues. INDEX gives pp.567-568; the locator's p.568 alone is within that span |
| 42 | 0059:108-109 | filtering the divergence breaks continuity | Wolfram and Fringer 2013 (read) | section 3.1, pp.67-68 | FIT | text 0005: "Direct application of the filter to the horizontal divergence field violates continuity" |
| 43 | 0059:109-112 | the implicit elliptic filter removes energy and adds a curl-of-vorticity term | Wolfram and Fringer 2013 (read) | section 3.5, p.71; section 4.1, eq. (18), p.72 | FIT | text 0008: "implicit filtering removes energy by smoothing the velocity field"; text 0009, eq. (18): the nu_G curl(omega k) term |
| 44 | 0059:129-130, 133-135 | added diffusion has not in general mitigated the mode; anisotropic in common implementations | Wolfram and Fringer 2013 (read) | section 2.1, p.65 | FIT | text 0002: "increased diffusion does not in general mitigate the problem ... common implementations of the diffusion operator are anisotropic" |
| 45 | 0059:135-136 | second-order diffusion lowers the effective Reynolds number | Wolfram and Fringer 2013 (read) | section 3.3, p.68 | FIT | text 0006: first-order filters add numerical diffusion, where second-order ones are hyperviscous, allowing "control to prevent artificial Reynolds number reduction" |
| 46 | 0059:136-138 | the filter one order above hyperviscous was oscillatory | Wolfram and Fringer 2013 (read) | section 3.3, eq. (11), p.69; 5.4.1, p.76; 6, p.77 | FIT | text 0006, eq. (11); text 0013: "The third-order filters IE3 and IN3 are oscillatory"; text 0014, conclusions |
| 47 | 0059:46-49 | geostrophic and inertia-gravity mode counts equal the vorticity and the mass-plus-divergence degrees of freedom | Thuburn et al. 2009 (read) | section 4.5, p.8332 | FIT | p.8332 (0012): "642 are geostrophic modes and 2558 are inertia-gravity modes, consistent with the numbers of vorticity, mass and divergence degrees of freedom" |
| 48 | 0059:67-69 | the tangential velocity as the weighted sum of eq. (33) | Thuburn et al. 2009 (read) | eq. (33), p.8327 | FIT | text 0008: "the explicit expression (33) for the weights derived in Section 2"; p.8334: "weights given explicitly by (33)" |
| 49 | 0059:69-71 | zero-frequency geostrophic modes on the triangular geodesic grid; Coriolis terms do no work | Thuburn et al. 2009 (read) | section 4.5, Fig. 10, pp.8331-8333; section 3, eq. (39), p.8328 | FIT | p.8332: normal modes on the triangular grid, Fig. 10; p.8328, eq. (39): w_ee' + w_e'e = 0 in section 3, Energy conservation |
| 50 | 0059:83-84 | a projection reconstruction's geostrophic modes are not stationary | Thuburn et al. 2009 (read) | Fig. 11, p.8334 | FIT | p.8334 (0014): "Fig. 11 ... a scheme that constructs edge tangential velocities by projection" |
| 51 | 0059:88-90 | stationary geostrophic modes are the prerequisite for Rossby modes | Thuburn et al. 2009 (read) | section 5, p.8334 | FIT | p.8334: "Stationarity of geostrophic modes for constant f is a pre-requisite for good Rossby mode behaviour" |
| 52 | 0059:197-200 | a vorticity-divergence form with dual-cell vorticity is equivalent to the velocity C-grid | Thuburn et al. 2009 (read) | section 4.6, footnote 2, p.8332 | FIT | p.8332, footnote 2: such a formulation "would be equivalent ... to the standard velocity C-grid formulation" |
| 53 | 0059:33-35 | the instability is internal and absent from a one-level model | Hollingsworth et al. 1983 (read) | section 1, p.417; section 5, pp.422-423 | FIT | p.417 (0001): "purely internal"; pp.422-423 (0006-0007): "a one-level model shows that the scheme is stable in all circumstances" |
| 54 | 0059:35 | the growth rate scales as f u / c | Hollingsworth et al. 1983 (read) | eq. (7), p.424 | FIT | p.424 (0008): "sigma_r ~ f u-bar / 8c (7)" |
| 55 | 0059:150-153 | the remedy: kinetic energy on the vorticity-flux stencil | Hollingsworth et al. 1983 (read) | section 8, p.427 | FIT | p.427 (0011): the instability "removed by" redefining the finite-difference form of grad K |
| 56 | 0059:164-165 | under dissipation the jets still lost energy | Hollingsworth et al. 1983 (read) | section 3, p.418 | FIT | p.418 (0002): "When internal dissipation was included ... the loss of energy in the longer waves still occurred" |
| 57 | 0059:35-37 | a shallow-water model shows the instability at the small equivalent depth of an internal mode | Bell et al. 2017 (read) | abstract and section 1 | FIT | abstract (0001): analysis "by separation of variables into vertical normal modes and a linearized form of the shallow-water equations"; smallest equivalent depths derived |
| 58 | 0059:155-157, 223-224 | a kinetic energy that makes the stability matrix Hermitian is stable to all perturbations | Bell et al. 2017 (read) | abstract and section 6 | FIT | abstract: "shown to have Hermitian stability matrices and hence to be stable to all perturbations"; text 0007, "neutrally stable to all linear perturbations" |
| 59 | 0059:36-37, 40-42 | the zonal balanced flow at small equivalent depth | Peixoto et al. 2018 (read) | sections 1 and 4 | FIT | text 0005: "a zonal balanced flow test case that mimics small equivalent depth behaviours" |
| 60 | 0059:37-39 | too slow to be seen at the standard suite's depth | Peixoto et al. 2018 (read) | section 5.1, p.6 | FIT | text 0006: at the depths of the "standard shallow water test cases ... the growth rate is so small that one would not observe instabilities even in long runs" |
| 61 | 0059:161-163 | the best blend moves with depth | Peixoto et al. 2018 (read) | section 5.1, p.8 | FIT | text 0008: at 0.01 m the optimal alpha differs from 0.75; "alpha = 0.625 is optimal for very small equivalent depths" |
| 62 | 0059:163-164, 219-220 | more accurate operators did not stabilise | Peixoto et al. 2018 (read) | section 5.1, p.8; section 7, p.15 | FIT | text 0008: the consistent scheme of Peixoto (2016) investigated; the section 7 summary |
| 63 | 0059:165-167 | depth weighting stabilises one scheme and destabilises another | Peixoto et al. 2018 (read) | section 7, p.15 | FIT | text 0015: "depth weighting of vorticity or Coriolis terms, whose effects can be either stabilizing or destabilizing" |
| 64 | 0059:39-40 | the operational triangle C-grid is among the least stable in the test | Lapolli et al. 2023 (read) | section 4.5.1, p.32 | FIT | text 0032: ICON's slower stabilisation attributed to "the reconstruction of the velocity vector field for both Coriolis and Kinetic energy terms in ICON". Preprint, as the decision states |
| 65 | 0059:150-153 | the blended kinetic energy | Gassmann 2013 (read) | section 3.3, eq. (27) | FIT | text 0006, eq. (27); text 0009: "the kinetic energy is fixed from Eq. (27)" |
| 66 | 0059:157-159 | the least-squares blend, which differs between Coriolis stencils | Gassmann 2013 (read) | Appendix B, eqs. (B11), (B20), (B21) | FIT | text 0023: (B11), (B20), (B21), "the least squares method"; the Coriolis stencil discussion |
| 67 | 0059:172-173 | a density-weighted mass matrix, the layer depth in shallow water | Korn 2026, arXiv:2605.16554v3 (read) | section 1, p.4 | FIT | p.4: "the density-weighted mass matrix M1rho = P^T diag(rho) P yields exact total-energy conservation for shallow water equations" (the shallow-water result is credited there to Korn-Linardakis [33]) |
| 68 | 0059:174-176 | linear stability about constant-flow stratified states | Korn 2026 (read) | Theorem 2.6, p.8; Corollary 5.20, p.32 | FIT | p.8: "Theorem 2.6 (Energetic linear stability and the Hollingsworth question)"; p.32: "Corollary 5.20 (DW immunity to Hollingsworth-type instability) ... constant-flow stratified equilibria" |
| 69 | 0059:176-178 | its cost is a Kelvin defect at the convergence order | Korn 2026 (read) | abstract, p.1 | FIT | abstract: "at the cost of an O(h^r*) Kelvin defect matching the convergence rate" |
| 70 | 0059:217-218 | every density-independent form keeps an energy residual | Korn 2026 (read) | Theorem 4.6, p.16 | FIT | p.16: "Theorem 4.6 (Generalised no-go theorem for discrete energy conservation)", kinetic energy of density-independent form |
| 71 | 0059:200-202 | Z-grid dispersion stays well behaved at small deformation radius against spacing, where the C-grid's does not | Randall 1994 (read) | section 3 and Fig. 2, pp.1374-1376 | FIT | p.1376 (0006): "Whereas the C grid behaves very badly for lambda/d = 0.1, the dispersion relation obtained with the Z grid is qualitatively insensitive to the value of lambda/d" |
| 72 | 0059:202-203 | that analysis is linear; nonlinear terms left open | Randall 1994 (read) | section 4, p.1376 | FIT | p.1376, section 4: "such models are nonlinear ... The present paper has discussed only some of the linear aspects" |

Not counted as a basis: Pratt and Whitehead 2008 (0031), which the decision says is not held
and does not carry the forms; the predecessor audit paths in 0031 and 0035; Murray and
Dermott 1999, Laskar et al. 1993 and Egbert and Ray 2000 in 0032; the Griewank, Lea, Wang and
Moses references in 0033. None of them is cited for a law, number or scheme the record adopts.

#### Not-fit cases

##### N1. Whitehead 1998 anchors three passages of decision 0031 from a held row, and is a review standing in for the control-flux primary (citations 1-3)

- **Where:** docs/decisions/0031-small-feature-strategy.md.
  - Layer 2 (line 41).
  - Alternatives (lines 96-98).
  - Consequences (lines 120-122).
  - The amendment of 2026-09-13 names pp. 424 and 427 as anchors.
- **Use:**
  - the rotating hydraulic-control transport forms, eqs. 12-13, in the upstream height above sill depth;
  - their non-rotating limit as the f-to-zero case;
  - the one-passage scope of those forms.
- **Source:** Whitehead, J. A., "Topographic control of oceanic flows in deep passages and straits", 10.1029/98RG01014. INDEX status: held.
- **Category:** C6, the anchor is cited as if read from a held row; for citations 1 and 2, also C5.
- **What is wrong:**
  - The passages support the uses; each was read here at the pages the decision gives.
  - INDEX still marks the row held with no locator, so a law the design adopts rests on an unread row.
  - The decision calls it a review, and the forms it takes are credited in that review to Whitehead, Leetmaa and Knox 1974.
- **Evidence:**
  - p.427 (text 0005): eqs. (12) and (13) in h_u, "upstream fluid surface height above sill depth", and "(13) ... in the limit of f = 0 ... smoothly connects the nonrotating result to equation (12)".
  - p.424 (text 0002): "boundaries with many gaps ... will not be reviewed here".
  - p.426 (text 0004): "This problem has very simple algebraic solutions that illustrate the flows in the channel [Whitehead et al., 1974]".
- **Fix class: (b).**
  - Mark the INDEX row read, naming p.424 and p.427 eqs. (12)-(13) with the use in 0031.
  - Decide whether the review suffices for REQ-OCN-002's control forms, or whether Whitehead, Leetmaa and Knox 1974 is indexed and read. That paper is "Rotating hydraulics of strait and sill flows", Geophys. Fluid Dyn. 6, 101-125, 1974, a Taylor and Francis journal, likely paywalled; its DOI was not confirmed here.
  - The INDEX edit waits on fiddlybits-k6b, which edits INDEX.md.
  - Replacing the review with the 1974 paper as the cited basis of decision 0031 would change a decision's basis: **(d) if the primary is required.**

##### N2. Barnes, Callaghan and Wickert 2020, a held row, anchors the one-gate-per-body-pair rule (citation 4)

- **Where:** decision 0031, Consequences (lines 114-119), from the amendment of 2026-09-13.
- **Use:** as one lowest outlet is kept per pair of depressions, one gate is kept per pair of bodies.
- **Source:** 10.5194/esurf-8-431-2020. INDEX status: held, anchor "B5 depression hierarchy", no locator.
- **Category:** C6.
- **Evidence:** p.438 (text 0008): "If any entry for an outlet is already present, only the outlet of lower elevation is retained. Two depressions may share a border across multiple cells ... but only the location of the lowest outlet is recorded". The content supports the analogy the decision draws.
- **Fix class: (b).** Mark the INDEX row read with section 3.3, p.438, for decision 0031. Bookkeeping only; INDEX.md is edited by fiddlybits-k6b.

##### N3. Gardner et al. 2018, held and unread, carries the fast tier's SSP3(333)c tableau, and is not the tableau's primary (citation 8)

- **Where:** decision 0041, condition 3 (lines 34-40) and References (lines 125-131). Status is proposed.
- **Use:** the named tableau, SSP333 / SSP3(333)c, and its stated properties:
  - third order;
  - three implicit stages;
  - singly diagonally implicit at the default parameter;
  - the SSP constraint by default.
- **Source:** Gardner, Guerra, Hamon, Reynolds, Ullrich and Woodward, "Implicit-explicit (IMEX) Runge-Kutta methods for non-hydrostatic atmospheric models", 10.5194/gmd-11-1497-2018. INDEX status: held.
- **Category:** C6 and C5.
- **What is wrong:**
  - The record says the source is held and not yet read, and that it does not move to accepted until the tableau table has been read against the package's coefficients.
  - Gardner et al. compile SSP3(333)b and SSP3(333)c from Conde et al. (2017), which is not indexed.
  - The stated properties are not tied to a page.
- **Evidence:** p.1501 (text 0005): "SSP3(333)b and SSP3(333)c from Conde et al. (2017)". The tableau names are listed in text 0009 and the results tables in texts 0016 and 0017.
- **Fix class: (b).**
  - Read Gardner et al.'s tableau for SSP3(333)c and, since it is a compilation, the Conde et al. 2017 primary.
  - Open access on arXiv, unconfirmed here, is "Implicit and implicit-explicit strong stability preserving Runge-Kutta methods with high linear order", Conde, Gottlieb, Grant and Shadid, J. Sci. Comput. 73 (2017).
  - Check the coefficients and properties against ClimaTimeSteppers' SSP333, as was done for ARS343.
  - Boundary: docs/references/INDEX.md (held on k6b), docs/decisions/0041 by amendment, a finding.
  - Acceptance: the tableau is located by table and page, coefficients agree, and the INDEX row is read with its locator.
- **(d) if** the coefficients disagree, or if the decision's cited basis moves from Gardner to Conde et al.

##### N4. IEEE 754-2019 is marked read for clause 5.4.1 only, but decisions 0045 and 0056 rest on clauses 5.4.2 and 3.6 (citations 12 and 24)

- **Where:** decision 0045 References (lines 118-120), clause 2 of its rule; decision 0056 (lines 37-43, 110-116).
- **Use:**
  - 0045: a value that survives the Float32 round trip is exact at every wider format.
  - 0056: the exact product of two binary32 values fits binary64.
- **Source:** IEEE Std 754-2019, 10.1109/IEEESTD.2019.8766229. INDEX status: read, anchors naming REQ-NUM-001, REQ-NUM-003 and decision 0044 clause 5.4.1 only.
- **Category:** C6, bookkeeping only; the source supports both uses.
- **Evidence:**
  - Text 0035, clause 5.4.2 formatOf-convertFormat: "Conversion to a format with the same radix but wider precision and range is always exact"; a conversion to a narrower precision "shall be rounded".
  - Text 0024, clause 3.6, Table 3.5, row "p, precision in bits": binary32 24, binary64 53.
- **Fix class: (b).** Add both locators to the INDEX row's anchors column. INDEX.md is edited by fiddlybits-k6b.

##### N5. FIPS 180-4 and Salmon et al. 2011, both held, are cited in decision 0052 (citations 13 and 14)

- **Where:** decision 0052:
  - the key paragraph (line 26) and References (line 111), for FIPS 180-4;
  - the second alternative (lines 66-71) and References (lines 113-116), for Salmon et al.
- **Use:**
  - FIPS 180-4: SHA-256 as the digest, fixed by its standard. The decision is explicit that the standard does not state the uniformity property it assumes.
  - Salmon et al.: naming the Philox generator of a rejected alternative.
- **Source:** 10.6028/NIST.FIPS.180-4 (held); 10.1145/2063384.2063405 (held).
- **Category:** C6, bookkeeping only.
- **Evidence:** FIPS 180-4, section 6.2, "SHA-256" (text 0027); Salmon et al., section 4.3, "The Philox PRNG" (text 0007).
- **Fix class: (b).** Mark both rows read with those locators, naming decision 0052. INDEX.md is edited by fiddlybits-k6b.

#### Not verified

- **Harris and Durran 2010, decision 0031.** The basis of "Fluid refinement boundaries are graded, not abrupt" is cited only in References, as "On wave reflection at nested-grid boundaries and graded transitions".
  - Verbatim title: "An Idealized Comparison of One-Way and Two-Way Grid Nesting".
  - Identifier: 10.1175/2010MWR3080.1 (Monthly Weather Review 138, 2010).
  - It has no INDEX, REQUESTS or design-citations row.
  - One fetch attempt (journals.ametsoc.org downloadpdf) returned an empty body.
  - AMS journals are usually free after their embargo, so it is likely open access, but that is not confirmed.
  - Whether it covers graded transitions, rather than one-way against two-way nesting only, is unknown.
  - Suggested fix (b): index it, fetch it, read it for the reflection at a refinement step, and record the locator; or name the source that does carry graded transitions.

#### Fetch failures and paywalled

- **Fetch failed:** "An Idealized Comparison of One-Way and Two-Way Grid Nesting", Harris, L. M., and D. R. Durran, 10.1175/2010MWR3080.1. The one curl attempt returned an empty file.
- **Fetched and read:** TOML v1.0.0 specification, https://toml.io/en/v1.0.0, saved at scratchpad/audit/fetch-D2/toml-v1.0.0.html.
- **Likely paywalled, not fetched,** named in N1 for the user's decision on primaries: "Rotating hydraulics of strait and sill flows", Whitehead, J. A., A. Leetmaa, and R. A. Knox, Geophys. Fluid Dyn. 6, 101-125, 1974. The DOI was not confirmed.
- **Named in N3, not fetched:** "Implicit and implicit-explicit strong stability preserving Runge-Kutta methods with high linear order", Conde, S., S. Gottlieb, Z. J. Grant, and J. N. Shadid, J. Sci. Comput. 73 (2017). The identifier and open-access copy were not confirmed.

#### Open branches

- No file in this scope is edited by an open branch.
- Every fix above touches docs/references/INDEX.md, which fiddlybits-k6b edits, or amends a decision record.

### Q1: Requirements, atm and cry


Worktree: /home/cfutro/git/fiddlybits/.beads/worktrees/fiddlybits-9j0 (main at 625832c). No file in this scope is edited by an open branch.

Scope rule applied: a citation is audited as a basis when it anchors a law, scheme, number, range, bar or rule the record states (in "What this system must do", or a published fact the record quotes as true). A citation that only names the model or dataset a predecessor finding was measured on, or carries no stated use, is listed as CONTEXT and not counted. Predecessor numbers the record uses as a rule were checked in /home/cfutro/git/vesper/notes/audits/.

Locators "text p.N" are the page index under /home/cfutro/git/fiddlybits/references/text/<stem>/NNNN.txt; "p. NNNN" is a printed page read from the PDF.

#### Counts

| scope | in scope | fit | not fit | not verified | context (not counted) |
| --- | --- | --- | --- | --- | --- |
| atm (17 files) | 63 | 49 | 12 | 2 | 23 |
| cry (4 files) | 14 | 8 | 6 | 0 | 9 |
| total | 77 | 57 | 18 | 2 | 32 |

Per file (in scope: fit / not fit / not verified; context):

| file | id | fit | not fit | NV | context |
| --- | --- | --- | --- | --- | --- |
| atm/absent-physics-is-a-declared-absence-priced-first.md | REQ-ATM-013 | 1 | 0 | 0 | 2 |
| atm/aerosol-activation-closes-the-aerosol-cloud-chain.md | REQ-ATM-005 | 2 | 2 | 0 | 0 |
| atm/aerosol-tracers-one-particle-description-and-physical-sinks.md | REQ-ATM-006 | 6 | 2 | 0 | 1 |
| atm/cloud-condensate-prognostic-with-explicit-effective-radius.md | REQ-ATM-004 | 4 | 1 | 0 | 2 |
| atm/convergence-verdict-resolves-its-own-threshold.md | REQ-ATM-015 | 3 | 0 | 1 | 0 |
| atm/dust-emission-drag-partition-over-measured-roughness.md | REQ-ATM-007 | 4 | 0 | 0 | 3 |
| atm/error-budget-coefficients-measured-and-residual-amplification-stated.md | REQ-ATM-016 | 2 | 0 | 0 | 0 |
| atm/gas-mixture-properties-derived-from-composition.md | REQ-ATM-017 | 7 | 3 | 1 | 0 |
| atm/lakes-with-phase-change-and-open-water-evaporation.md | REQ-ATM-012 | 2 | 0 | 0 | 0 |
| atm/radiation-spectrally-resolved-from-declared-spectrum-and-composition.md | REQ-ATM-003 | 2 | 0 | 0 | 4 |
| atm/sensitivity-bracketed-between-converged-points-in-regime.md | REQ-ATM-014 | 1 | 0 | 0 | 1 |
| atm/snow-albedo-grain-impurity-and-zenith-per-band.md | REQ-ATM-011 | 5 | 1 | 0 | 2 |
| atm/snow-and-ice-material-properties-follow-density-and-temperature.md | REQ-ATM-010 | 5 | 1 | 0 | 4 |
| atm/soil-thermal-properties-from-moisture-and-texture.md | REQ-ATM-009 | 1 | 1 | 0 | 1 |
| atm/stellar-spectrum-flux-conserved-and-oracled.md | REQ-ATM-001 | 0 | 0 | 0 | 1 |
| atm/surface-longwave-emissivity-per-class-and-partition-ledger.md | REQ-ATM-008 | 1 | 0 | 0 | 1 |
| atm/surface-optics-integrated-against-the-declared-spectrum.md | REQ-ATM-002 | 3 | 1 | 0 | 1 |
| cry/gravity-powers-in-ice-flow.md | REQ-CRY-002 | 3 | 3 | 0 | 1 |
| cry/ice-and-snow-albedo-per-band.md | REQ-CRY-004 | 0 | 1 | 0 | 4 |
| cry/ice-placement-is-derived.md | REQ-CRY-003 | 1 | 1 | 0 | 2 |
| cry/shallow-ice-solver.md | REQ-CRY-001 | 4 | 1 | 0 | 2 |

(ATM-015 counts the predecessor "a third of the threshold" rule as fit and the "twenty memory times" rule as not verified; ATM-016 counts the predecessor "three times the scatter" rule as fit.)

#### Every citation

| # | where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | ATM-013 References | trace-gas absence priced from | Rugheimer 2013, 10.1089/ast.2012.0888 (held) | none | CONTEXT | predecessor pricing |
| 2 | ATM-013 References | high-clay exclusion turned values into brackets | Saxton and Rawls 2006, 10.2136/sssaj2005.0117 (held) | none | FIT | text p.2: "Excluded were those with bulk density <1.0 and >1.8 g cm-3, OM >8% (w) and clay >60% (w)" |
| 3 | ATM-013 References | the pricing method model | Twomey 1977 (held) | none | CONTEXT | |
| 4 | ATM-005 item 3; References | activation scheme, and "the fit functions of the size-distribution width were validated over one atmosphere's updraught, pressure and temperature range, which is in the registry" | Abdul-Razzak and Ghan 2000, 10.1029/1999JD901161 (held) | none | NOT FIT (C2) | text p.3: f_i(sigma) "altered from that listed in part 1 ... retuning"; p. 6842: evaluated against simulations over updraft 0.01 to 10 m/s, number, size, composition, "errors ... seldom exceed 10% for the wide range of conditions investigated"; no pressure or temperature range stated |
| 5 | ATM-005 item 1; References | hygroscopicity per species | Petters and Kreidenweis 2007, 10.5194/acp-7-1961-2007 (held) | none | FIT | text p.4: "Table 1 lists the values of kappa ... for individual components" |
| 6 | ATM-005 References | "The A(1-A) sensitivity the closed form reproduced" | Twomey 1977, 10.1175/1520-0469(1977)034<1149:TIOPOT>2.0.CO;2 (held) | none | NOT FIT (C2) | text p.3 (p. 1151): only the sign condition dS/dx > 0 and numerically computed trajectories (Fig. 3); no A(1-A) form anywhere in the four pages |
| 7 | ATM-005 item 1; References | correction for pre-existing liquid and ice | Korolev and Mazin 2003 (held) | none | FIT | text p.12: "secondary activation of droplets may occur if u_z > u*_z, where u*_z is the threshold velocity required for activation of interstitial CCN"; text p.8: activation of liquid droplets in ice clouds |
| 8 | ATM-006 item 2; References | settling velocity from a drag balance with tabulated CD | Parmentier et al. 2013 (held) | Appendix A | FIT | text p.20-21: "Appendix A: Departure from the Cunningham [velocity]", A.3 comparison |
| 9 | ATM-006 References | a sink stated as a rate with an explicit timescale | Steinrueck et al. 2021, 10.1093/mnras/stab1053 (held) | none | FIT | text p.4: "L = -chi/tau_loss for p > p_deep", "tau_loss = 10^3 s and p_deep = 100 mbar" |
| 10 | ATM-006 item 4; References | per-whitecap production spectrum Bracketed between the cold/fresh and warm/saline ends of "the seawater temperature and salinity dependence its source carries" | Grythe et al. 2014, 10.5194/acp-14-1277-2014 (read) | none | NOT FIT (C2) | text p.9: G13T is "a modified SH98 source function" in 10 m wind; text p.10: temperature weighting T_W(T) (eq. A7), "without accounting for temperature ... G13"; salinity appears only as a symbol in the generic form (text p.3) and a qualitative section (text p.5); no salinity dependence in any fitted function |
| 11 | ATM-006 item 6; References | AeroCom spread as the Earth REPORT bar | Textor et al. 2006 (read) | none | FIT | text p.1: "model diversities for sources and sinks, burdens ..."; INDEX anchor: burdens and lifetimes with diversity |
| 12 | ATM-006 References | emitted dust size distribution | Kok 2011, 10.1073/pnas.1014798108 (read; file kok_2010) | none | FIT | text p.3 eq. (6) |
| 13 | ATM-006 item 2; References | aerosol dry-deposition surface resistance, Bracketed, "with the surface set it was fitted on (Wesely 1989)" | Wesely 1989, 10.1016/0004-6981(89)90153-4 (held) | none | NOT FIT (C3) | title and every running head: "Surface resistances to gaseous dry deposition" (text p.1, 3, 5, 7); the scheme is for gases (SO2, O3, NOx, HNO3); particles are not parameterised |
| 14 | ATM-006 item 2; References | scavenging coefficient's dependence on the raindrop spectrum | Slinn 1984, DOE/TIC-27601 ch. 11 (held) | none | FIT | text p.14 Fig. 11.10 raindrop distributions for convective storms and Marshall-Palmer; text p.16 Fig. 11.15 scavenging rates for a frontal rain spectrum |
| 15 | ATM-006 item 4; References | whitecap fraction form and per-whitecap production | Monahan et al. 1986, 10.1007/978-94-009-4668-2_16 (held) | none | FIT | text p.174 eq. (2) W(U) = 3.84e-6 U^3.41; text p.175 eq. (3) dF0/dr = 1.088e-6 U^3.41 dE/dr (production per whitecap dE/dr). Carries no temperature or salinity term (see row 10) |
| 16 | ATM-006 References | passive volcanic flux the sulfate bound was scaled from | Carn et al. 2017 (held) | none | CONTEXT | predecessor bound |
| 17 | ATM-004 References | CCM3 profile hl = 700 ln(1+PW), rho_l0 = 0.21 g/m3 | Kiehl et al. 1998 (held) | Eqs. 3, 4, 12-15 | FIT | text p.2: "reference value r_l0 is equal to 0.21 g m-3"; text p.3: "a = 700 m and b = 1 m2 kg-1" |
| 18 | ATM-004 References | CCM2 provenance of the reference density | Kiehl et al. 1996, 10.5065/D6FF3Q99 (held) | Eqs. 4.a.11-4.a.14 | FIT | text p.56: "As in the CCM2 ... reference value rho_l^0 is equal to 0.21 g m-3" |
| 19 | ATM-004 References | fitted range 10 to 10,000 g/m2 and the buried effective radius | Stephens 1978 (held) | Eqs. (7), (10a), (10b) | FIT | text p.2 tau_N in W and r_e; text p.3 Figs. 1a-b liquid water path axis 10 to 10000 g m-2 |
| 20 | ATM-004 References; What is true | "Tables 1(a)-(c) and the thin-cloud exclusion"; "the regime the fit's own revision excludes by name" | Stephens et al. 1984 (held) | Tables 1(a)-(c) | NOT FIT (C2, minor) | pp. 687-689: Table 1 tabulated from tau_N = 1 to 500, Figs. 1-2 over W = 10 to 10,000 g m-2; no exclusion of thin cloud is stated by name; text p.4 has none either |
| 21 | ATM-004 References | scheme linear in water path with explicit r_e | Slingo 1989 (held) | none | FIT | text p.2 eq. (1) tau_i = LWP (a_i + b_i/r_e) |
| 22 | ATM-004 References | observable the bracket was taken from | Lloyd et al. 2018 (held) | none | CONTEXT | predecessor bracket |
| 23 | ATM-004 References | no use stated | Covert et al. 2022 (held) | none | CONTEXT | |
| 24 | ATM-015 items 1, 4; References | initial monotone sequence estimator; batch means | Geyer 1992 (held) | none | FIT | text p.5: "initial monotone sequence estimator"; text p.4: "method of batch means" |
| 25 | ATM-015 item 1; References | effective sample size for a climate mean | Zwiers and von Storch 1995 (held) | none | FIT | text p.3 section 2c "The equivalent sample size" |
| 26 | ATM-015 item 2 | window so the SE is at most a third of the threshold | predecessor flux-slope-bracket.md | lines 63, 107, 165 | FIT | "The resolving bar is a standard error of at most a third of the threshold" |
| 27 | ATM-015 item 4 | batch means over a span of at least twenty memory times | predecessor audit (not named) | none | NOT VERIFIED | not found in flux-slope-bracket.md or any file under vesper/notes or vesper/docs; not stated by Geyer 1992 |
| 28 | ATM-007 item 1; References | Kok scaling; standardized threshold normalised to reference air density | Kok et al. 2014 (read) | none | FIT | text p.4: u*st "the value of u*t at standard atmospheric density at sea level (rho_a0 = 1.225 kg m-3)" |
| 29 | ATM-007 item 1; References | threshold law with cohesion term | Shao and Lu 2000 (read) | none | FIT | text p.4 eq. (22) u*t^2 = f(Re)(sigma_p g d + gamma/(rho d)) |
| 30 | ATM-007 items 1, 4; What is true | drag partition and its validity (about 20 per cent above feff 0.2) | Marticorena and Bergametti 1995 (read) | none | FIT | p. 16420 eq. (20); "difference between the efficient fractions computed when using X = 10 cm and the mean efficient fractions are of the order of 20% for feff higher than 0.2" |
| 31 | ATM-007 item 2; References | aerodynamic z0 over named playa, fan, interdune surfaces | Greeley et al. 1997 (held) | Table 2 | FIT | text p.11 "Table 2. Comparison of Radar-Derived and Field-Measured z0 Values"; field z0 "derived from wind velocity profiles measured with vertical arrays of anemometers". Only the field column is aerodynamic |
| 32 | ATM-007 References | no use stated | MacKinnon et al. 2004 (held) | none | CONTEXT | |
| 33 | ATM-007 References | cautions tested and not transferred | Menut et al. 2013 (held) | none | CONTEXT | |
| 34 | ATM-007 References | within-box spread for the tabulation bias | Prigent et al. 2005 (held) | none | CONTEXT | scatterometer-derived; not used for class values |
| 35 | ATM-016 References | P and E scale below the Clausius-Clapeyron rate | Held and Soden 2006 (held) | none | FIT | text p.1 "about 7% for each 1-K"; text p.3 global precipitation "2% K-1 (with a median value of 1.7% K-1)" |
| 36 | ATM-016 item 6 | an arm is bought when its separation clears three times the scatter | predecessor albedo-attenuation.md | lines 70-72 | FIT | "The bar was fixed before the numbers at three times that quadrature sum" |
| 37 | ATM-017 item 3; References | latent heat of vaporisation; saturation vapour pressure over liquid | Wagner and Pruss 2002 (held) | none | FIT | text p.11: "Correlation equations for the properties vapor pressure, saturation densities, specific enthalpy ..." |
| 38 | ATM-017 item 3; References | sublimation enthalpy and vapour pressure over ice | IAPWS R10-06(2009) (read) | none | FIT | text p.2 property table: "Specific sublimation enthalpy", "Sublimation pressure"; text p.8: "consistent computation of the melting-pressure and sublimation-pressure curves ... valid down to 130 K" |
| 39 | ATM-017 item 3; References | surface tension of the condensable in T | IAPWS R1-76(2014) (held) | none | FIT | text p.3: "valid between the triple point (0.01 C) and ... Tc", extrapolated "to temperatures as low as -25 C" |
| 40 | ATM-017 item 2; References | per-gas cp, h, s polynomials | McBride et al. 2002 via docs/inputs/data/nasa-cea-thermo.toml | manifest | FIT | manifest papers: "mcbride2002 NASA/TP-2002-211556 (the coefficients and their form)"; trans.inp carries viscosity and conductivity |
| 41 | ATM-017 References | second thermochemical source | Goos, Burcat, Ruscic via burcat-ruscic-thermochemical.toml | manifest | FIT | manifest title and printed edition match |
| 42 | ATM-017 items 2, 6; References | N2, O2, Ar, air viscosity and conductivity; air values | Lemmon and Jacobsen 2004 (held) | none | FIT | text p.1: equations for nitrogen, oxygen, argon and air, "uncertainties ... generally within 2%" |
| 43 | ATM-017 item 2; References | "the mixing rule for viscosity and conductivity" (Wilke) | Wilke 1950, 10.1063/1.1747673 (held) | none | NOT FIT (C2) | title and abstract (text p.2): "a general equation for viscosity as a function of molecular weights and viscosities of the pure components"; conductivity is not treated |
| 44 | ATM-017 items 2, 6; References | kinetic-theory viscosity, conductivity, diffusivity, mean free path | Chapman and Cowling 1970 (held) | none | FIT | text p.111 section 5.21 "The mean free path" |
| 45 | ATM-017 item 2; References | "Chapman-Enskog with the Fuller-Schettler-Giddings volumes, Sourced per pair" | Fuller, Schettler, Giddings 1966, 10.1021/ie50677a007 (held) | none | NOT FIT (C2, C4) | text p.3-4: the method "starts with the Stefan-Maxwell hard sphere model"; eq. (4) D_AB = 1.00e-3 T^1.75 (1/M_A + 1/M_B)^1/2 / (P[(Sum v_A)^1/3 + (Sum v_B)^1/3]^2) with Table I volumes is FSG's own correlation, not Chapman-Enskog. Poling 2001 text p.644: Sum v "atomic diffusion volumes in Table 11-1 (Fuller et al. 1969)", the revised set |
| 46 | ATM-017 item 2 | Blanc's law for the diffusivity in the mixture | none cited | none | NOT FIT (C2) | the law is named with no source anywhere in the record |
| 47 | ATM-017 item 6; References | tabulated pure-gas and binary values for the CO2 and H2-He oracle instances | Poling et al. 2001 (held, compilation) | none | NOT VERIFIED | tables are OCR markers; no H2-He binary row located; text p.644 "Eqs. (11-4.2) and (11-4.3) should not be used for hydrogen or helium"; text p.586 "(10-5.2) to (10-5.4) should not be used ... for hydrogen or helium" |
| 48 | ATM-012 References | 1-D eddy-diffusion lake thermal model with ice | Hostetler and Bartlein 1990 (held) | none | FIT | text p.1 "eddy diffusion model for simulating the seasonal variation in lake temperature and evaporation"; text p.3 "method for estimating ice in the eddy diffusion model" |
| 49 | ATM-012 References | lake tile inside a land column | Subin et al. 2012 (held) | none | FIT | text p.1: lake, ice, snow and sediment physics in CESM1's land model |
| 50 | ATM-003 item 1; References | line data; per-perturber widths | Gordon et al. 2022 HITRAN2020 (held) | none | FIT | text p.37 "H2-, He- and CO2-broadening parameters"; text p.25 broadening by H2O |
| 51 | ATM-003 item 1; References | continuum; foreign continuum for an air bulk | Mlawer et al. 2012 (read) | section 3, Table 3 | FIT | text p.2 self and foreign continuum definitions; INDEX anchor |
| 52 | ATM-003 References | SOCRATES pipeline shape | Edwards and Slingo 1996 (held) | none | CONTEXT | |
| 53 | ATM-003 References | fitted scheme the cost was measured on | Lacis and Hansen 1974 (held) | none | CONTEXT | |
| 54 | ATM-003 References | O(NLEV^2) broadband longwave | Sasamori 1968 (held) | none | CONTEXT | |
| 55 | ATM-003 References | trace-gas abundances priced from | Rugheimer et al. 2013 (held) | none | CONTEXT | |
| 56 | ATM-014 References | no use stated | Budyko 1969 (held) | none | CONTEXT | |
| 57 | ATM-014 References | sensitivity a function of the ice edge, discontinuous across the transition | North 1975 (held) | none | FIT | text p.3 ice edge x_s "a multiple-valued function" of Q; text p.5 Table 1 and sensitivity coefficient Q dT0/dQ |
| 58 | ATM-011 What is true; References | quadratic in log radius, zenith form, dust exponent | Dang et al. 2015 (read) | Eqs. (5), (7), Tables 1, 3 | FIT | text p.5 eq. (5) r' = r(1 + a Delta mu)^2; text p.8 eq. (7) H = (C/C0)(r/r0)^s |
| 59 | ATM-011 item 5; References | published two-stream pure-snow albedo | Wiscombe and Warren 1980 I (held) | none | FIT | text p.1 "delta-Eddington approximation ... together with Mie theory" |
| 60 | ATM-011 References | no use stated | Warren and Wiscombe 1980 II (held) | none | CONTEXT | |
| 61 | ATM-011 item 1; References | ice optical constants | Warren and Brandt 2008 (held) | none | FIT | text p.1 compiled complex refractive index of ice Ih |
| 62 | ATM-011 item 2; References | grain-growth rate constants with their fitted temperature and gradient range | Flanner and Zender 2006 (held) | none | FIT | text p.9 para 48: best-fit tau and kappa "over the domain ... T 273 K, 0 dT/dz 300 K m-1, and 50 rho_s 400 kg m-3" |
| 63 | ATM-011 References | SNICAR structure | Flanner et al. 2007 (held) | none | CONTEXT | |
| 64 | ATM-011 References | zenith-angle effective-radius form Dang eq. (5) follows | Marshall 1986 (held) | none | FIT (note) | p. 218-219 Table 2(c): effective zenith cosine mu = d mu_d + (1-d) mu_0, mu_d = 0.65; grain radius and zenith angle "parameterized as one value, an effective grain size". The explicit form r' = r(1 + a Delta mu)^2 is Dang eq. (5), which Dang attributes to Marshall [1989] |
| 65 | ATM-011 item 3; What is true | direct-beam escape function K(mu0) = (3/7)(1 + 2 mu0) | none cited | none | NOT FIT (C2) | no reference in the record states it; not in Wiscombe and Warren 1980, Warren 1982 or Dang 2015 (grep); the predecessor snow-albedo-zenith.md calls it "the asymptotic result of radiative transfer" and cites nothing |
| 66 | ATM-010 item 1; References | specific heat and melting enthalpy of ice | IAPWS R10-06(2009) (read) | Eq. (1), Tables 2, 6 | FIT | INDEX anchor; text p.2 property table |
| 67 | ATM-010 References | no use stated | Feistel and Wagner 2006 (held) | none | CONTEXT | |
| 68 | ATM-010 item 1; References | fast-kinetics conductivity arm | Fourteau et al. 2021 (read) | Eq. (18) | FIT | text p.4 "The fast kinetics case"; INDEX anchor eq. 18 |
| 69 | ATM-010 item 1; References | slow-kinetics conductivity arm | Calonne et al. 2011 (read) | Eq. (12) | FIT | text p.4 eq. (12) k_eff = 2.5e-6 rho^2 - 1.23e-4 rho + 0.024; Fourteau 2021 text p.3 names Calonne et al. (2011) as the slow-kinetics case |
| 70 | ATM-010 item 3; References | pure-ice exponential and Maxwell-Schwerdtfeger bubble term | Yen 1981 (read) | Eqs. (33), (37), (70)-(72) | FIT | text p.22 eq. (33) lambda_i = 9.828 exp(-0.0057 T); text p.24 eq. (37) lambda_ia = 2 rho_s/(3 rho_i - rho_s) lambda_i (Schwerdtfeger) |
| 71 | ATM-010 References | read and not adopted | Sturm et al. 1997 (held) | none | CONTEXT | |
| 72 | ATM-010 References | no use stated | Riche and Schneebeli 2013 (held) | none | CONTEXT | |
| 73 | ATM-010 References | no use stated | Fukusako 1990 (read) | none | CONTEXT | |
| 74 | ATM-010 item 4; References | fresh-snow density fit "in air temperature (Anderson 1976), with its site and temperature range" | Anderson 1976, NOAA TR NWS 19 (held) | none | NOT FIT (C2, C5) | text p.75 eq. (4.22): rho_ns = 0.05 + 0.0017 (T_w - 258.16)^1.5 with T_w "wet-bulb temperature"; "based on a plot of new snow density versus temperature for Alta, Utah [LaChapelle (1969)]" |
| 75 | ATM-010 item 4; References | compaction scheme and its viscosity constants | Willeit and Ganopolski 2016 (held) | Eqs. (46)-(48) | FIT | text p.13 eq. (46); text p.5, 8-9 snow viscosity parameters |
| 76 | ATM-009 item 1; References | Johansen's interpolation "read from the monograph rather than a restatement" | Farouki 1981 CRREL Monograph 81-1 (read) | Section 7.11, Table 24 | NOT FIT (C5) | text p.127: "Table 24. Method for calculating thermal conductivity of mineral soils (after Johansen 1975)"; the monograph restates Johansen (1975), and INDEX records two misprints in Table 24 corrected from the body |
| 77 | ATM-009 item 1; References | organic-fraction blending | Lawrence and Slater 2008 (held; file lawrence_2007) | none | FIT | text p.4 organic fraction per layer; text p.6 conductivity against soil carbon fraction |
| 78 | ATM-009 References | CLM5 column structure | Lawrence et al. 2019 (held) | none | CONTEXT | |
| 79 | ATM-001 References | BT-Settl grid the finding was measured on | Allard et al. 2012 (held) | none | CONTEXT | |
| 80 | ATM-008 item 1; References | hemispherical spectra in the thermal window | Meerdink et al. 2019 (held) | none | FIT | text p.6: "Nicolet measurements are directional hemispherical with a directional light source and integrating sphere" |
| 81 | ATM-008 References | no use stated | Baldridge et al. 2009 (held) | none | CONTEXT | |
| 82 | ATM-002 item 1; References | reflectance spectra per class | Meerdink et al. 2019 (held) | none | FIT | as row 80 |
| 83 | ATM-002 References | no use stated | Baldridge et al. 2009 (held) | none | CONTEXT | |
| 84 | ATM-002 item 3; References | spectrum-free optical constants; measurement temperature | Hale and Querry 1973 (read) | Table I | FIT | text p.1: "Extinction coefficients k(lambda) for water at 25 C" |
| 85 | ATM-002 References | fitted absorptances as fractions of solar flux | Lacis and Hansen 1974 (held) | none | FIT | text p.5: "the fraction of the incident solar flux that is absorbed" |
| 86 | ATM-002 References | "Vegetation reflectance as a function of the host spectrum" | Kiang et al. 2007b, 10.1089/ast.2006.0108 (read) | none | NOT FIT (C2) | abstract (text p.2-3): predicts that "pigments on planets around F2V stars may peak in absorbance in the blue, K2V in the red ..." for photosynthesis "that has evolved with a different parent star"; not a reflectance of a given canopy under a changed spectrum |
| 87 | CRY-002 item 1; References | Glen's power-law creep | Glen 1955 (held) | none | FIT | text p.11 power law between stress and strain rate; text p.12 exponent 3.2 |
| 88 | CRY-002 What is true, item 2; References | sliding C tau_b^p / N^q with p = 3, q = 2 (Weertman sliding), bracket ends where water pressure lowers N | Weertman 1957 (held) | none | NOT FIT (C2) | text p.6 eq. (5): sliding velocity = (2BCD/3H rho)^1/2 (tau/2)^((1+n)/2) (L'/L)^(1+n); no effective pressure, and the stress exponent is (1+n)/2 (2 at n = 3) |
| 89 | CRY-002 References | the shallow-ice formulation | Greve 2005 lecture notes (held) | none | NOT FIT (C5) | lecture notes standing in for the primary SIA derivation; the record says they replace the Greve and Blatter monograph |
| 90 | CRY-002 References | enthalpy formulation | Aschwanden et al. 2012 (held) | none | FIT | text p.1 enthalpy as the single variable for cold and temperate ice |
| 91 | CRY-002 What is true, item 5; References | Clausius-Clapeyron gradient per pascal | Cuffey and Paterson 2010 (held, textbook) | none | NOT FIT (C5) | text p.419 section 9.4.1: eq. (9.9) B = 7.42e-8 K Pa-1 (pure), eq. (9.10) B = 9.8e-8 K Pa-1 "or 8.7e-4 K m-1 of ice" (air-saturated); a textbook value with no primary named for B in the passage |
| 92 | CRY-002 References | no use stated | Bueler and Brown 2009 (held) | none | CONTEXT | |
| 93 | CRY-002 Enforced by; References | similarity timescale's dependence on Gamma "and hence on g^3" | Halfar 1983 (held) | none | FIT (note) | text p.2 eqs. (28)-(29): t-hat proportional to (2 tau_0 R-hat/(rho g H-hat^2))^n; g^-n generally, g^3 only at n = 3 (the record's amendment already says g^-n) |
| 94 | CRY-004 References | no use stated | Warren 1982 (held) | none | CONTEXT | |
| 95 | CRY-004 References | no use stated | Wiscombe and Warren 1980 I (held) | none | CONTEXT | |
| 96 | CRY-004 References | no use stated | Flanner and Zender 2006 (held) | none | CONTEXT | |
| 97 | CRY-004 References | no use stated | Grenfell and Maykut 1977 (held) | none | CONTEXT | text p.1 spectral albedos of sea ice, snow and puddles |
| 98 | CRY-004 item 3; References | "the broadband glacier ice albedo datum the two-band anchoring reproduces", anchored "under the spectrum the datum was measured under" | Cuffey and Paterson 2010 (held, textbook) | none | NOT FIT (C5, C2) | text p.159 Table 5.2 "Characteristic values for snow and ice albedo, from a literature review by S.J. Marshall": recommended/min/max, "Clean ice 0.35 0.30 0.46", "Blue ice 0.64". A review's recommended value with no measurement spectrum; the What is true value "about 0.5 from Paterson" is not the held edition's |
| 99 | CRY-003 References | mass balance and ELA background | Cuffey and Paterson 2010 ch. 4-5 (held) | ch. 4, 5 | CONTEXT | |
| 100 | CRY-003 References | no use stated | Hock 2005 (held) | none | CONTEXT | |
| 101 | CRY-003 item 3; References | volume-area exponent AND coefficient "Derived from Glen's n, the solver's Gamma and the column's own mass-balance gradient by Bahr's dimensional argument" | Bahr et al. 1997 (held) | none | NOT FIT (C2) | text p.3: [V] proportional to [S]^gamma; theta from scaling "for some constants r, f, and m"; text p.4: "four closure choices must be made" (width q, slope r, side drag f, mass balance m); text p.6 exponent 1.36 reproduced only under closures; no coefficient is derived |
| 102 | CRY-003 Enforced by; References | accumulation-temperature at the ELA, Earth REPORT | Ohmura et al. 1992 (held) | none | FIT | text p.1 abstract: temperature, precipitation and radiation at equilibrium lines of 70 glaciers |
| 103 | CRY-001 References | Halfar dome | Halfar 1981 (held) | none | CONTEXT (note) | text p.3 eq. (25) t proportional to R^(3n+2): the two-dimensional solution (Halfar 1983 text p.6 names it so); the radial 1/18 is in 1983 |
| 104 | CRY-001 What is true, Oracles; References | R(t) = R0 (t/t0)^(1/18) | Halfar 1983 (held) | none | FIT | text p.1: half-widths "power functions of the time t with power exponent 1/(5n+3)" for the cylindrically symmetric case, 1/18 at n = 3 |
| 105 | CRY-001 Oracles; References | non-radially-symmetric exact solution with compensatory accumulation | Bueler et al. 2005 (held) | none | FIT (note) | text p.4: "compensatory accumulation functions can be defined to create essentially any profile we choose"; the published test E is sliding in sectors on the radial Bodvarsson-Vialov profile, so a non-radial surface slope has to be constructed by the method |
| 106 | CRY-001 References | no use stated | Bueler and Brown 2009 (held) | none | CONTEXT | |
| 107 | CRY-001 item 3; References | margin as a complementarity condition | Jouvet and Bueler 2012 (held) | none | FIT (bibliographic fix) | text p.1: "obstacle problem ... written as a variational inequality subject to the positive-ice-thickness constraint". Record's title and "DOI: to confirm" differ from INDEX (10.1137/110856654, "Steady, shallow ice sheets as obstacle problems") |
| 108 | CRY-001 item 7; References | Glen's law | Glen 1955 (held) | none | FIT | as row 87 |
| 109 | CRY-001 References | shallow-ice formulation | Greve 2005 lecture notes (held) | none | NOT FIT (C5) | as row 89 |

#### Not-fit cases

##### N1. REQ-ATM-005 item 3: Abdul-Razzak and Ghan 2000, the fit's validated range
- Where: docs/requirements/atm/aerosol-activation-closes-the-aerosol-cloud-chain.md, item 3 and References.
- Use: the activation scheme, and the rule that "the fit functions of the size-distribution width were validated over one atmosphere's updraught, pressure and temperature range, which is in the registry".
- Category: C2. What is wrong: the cited Part 2 retunes f_i(sigma) from Part 1 and evaluates the scheme over updraft (0.01 to 10 m/s), number, mode radius and soluble fraction; it states no pressure or temperature range, so the registered range cannot be filled from it.
- Evidence: text p.3, "the function f_i(sigma) has been altered from that listed in part 1"; p. 6842, "Errors in the number fraction activated seldom exceed 10% for the wide range of conditions investigated".
- Fix class: (b). Read Part 1 (Abdul-Razzak, Ghan and Rivera-Carpio 1998, JGR 103(D6), 6123-6131; identifier to confirm, AGU content older than 24 months is free to read) for the simulation conditions, and state the range with both locators.

##### N2. REQ-ATM-005 References: Twomey 1977, "the A(1-A) sensitivity"
- Where: same file, References.
- Use: gloss attributing the closed-form A(1-A) sensitivity to Twomey 1977.
- Category: C2. The 1977 paper gives only the sign condition on dS/dx and numerically computed albedo trajectories.
- Evidence: text p.3 (p. 1151), "increasing pollution will increase the albedo if dS/dx is positive"; Fig. 3 numerical trajectories; no A(1-A) expression in the four pages.
- Fix class: (b). The closed form dA/dlnN = A(1-A)/3 is usually cited to Twomey (1991) or Platnick and Twomey (1994), neither held. Either re-gloss Twomey 1977 to the qualitative result, or fetch and read the paper that states the form. No bar or disposition rests on it.

##### N3. REQ-ATM-006 item 4: Grythe 2014 with Monahan 1986, the temperature and salinity bracket
- Where: docs/requirements/atm/aerosol-tracers-one-particle-description-and-physical-sinks.md, item 4.
- Use: a per-whitecap production spectrum, Bracketed between "the cold, fresh end and the warm, saline end of the seawater temperature and salinity dependence its source carries".
- Category: C2. Monahan 1986's per-whitecap dE/dr has no temperature or salinity term. Grythe 2014's G13T is a 10 m wind source function, not a per-whitecap one, with a temperature weighting only. Neither source carries a salinity dependence.
- Evidence: Monahan text p.175 eq. (3); Grythe text p.9 ("a modified SH98 source function ... G13T"), text p.10 (T_W(T), eq. A7; "without accounting for temperature ... G13"); salinity only as a symbol in the generic form (text p.3) and a qualitative section (text p.5).
- Fix class: (b). Either source a laboratory salinity dependence of bubble-mediated production (to be identified and read), or remove the salinity arm and state the bracket on the temperature dependence only. The bracket mechanisms change; the disposition stays Bracketed.

##### N4. REQ-ATM-006 item 2: Wesely 1989 for aerosol dry deposition
- Where: same file, item 2 and References.
- Use: the surface resistance of aerosol dry deposition per surface class, Bracketed "with the surface set it was fitted on (Wesely 1989)".
- Category: C3. Wesely 1989 parameterises surface resistances for gases (SO2, O3, NOx, HNO3), not particles.
- Evidence: title and running heads, "Surface resistances to gaseous dry deposition" (text p.1, 3, 5, 7).
- Fix class: (b). Read a size-resolved particle dry-deposition scheme (for example Zhang et al. 2001, Atmos. Environ. 35, 549-560; identifier to confirm, likely paywalled) and re-anchor the bracket and its fitted surface set.

##### N5. REQ-ATM-004 References: Stephens et al. 1984, "the thin-cloud exclusion"
- Where: docs/requirements/atm/cloud-condensate-prognostic-with-explicit-effective-radius.md, What is true ("the regime the fit's own revision excludes by name") and References.
- Category: C2, minor. The revision names no exclusion. Its tables start at tau_N = 1, and its figures cover W = 10 to 10,000 g m-2.
- Evidence: pp. 687-689, Table 1(a)-(c) and Figs. 1-2; nothing in text p.4.
- Fix class: (a). Re-gloss the reference to the tabulated domain (Table 1, tau_N 1 to 500; Figs. 1-2, W 10 to 10,000 g m-2) and change "excludes by name" to "does not tabulate". No bar or disposition rests on it.

##### N6. REQ-ATM-017 item 2: Wilke 1950 for conductivity
- Where: docs/requirements/atm/gas-mixture-properties-derived-from-composition.md, item 2 and References ("The mixing rule for viscosity and conductivity").
- Category: C2. Wilke 1950 gives a viscosity mixing rule only.
- Evidence: text p.2, abstract: "a general equation for viscosity as a function of molecular weights and viscosities of the pure components".
- Fix class: (b). The conductivity rule is the Wassiljewa form with the Mason and Saxena modification: Mason and Saxena 1958, "Approximate Formula for the Thermal Conductivity of Gas Mixtures", Phys. Fluids 1, 361, 10.1063/1.1724352 (AIP, paywalled). Poling 2001, held, restates it as a compilation. Name the conductivity rule and its source.

##### N7. REQ-ATM-017 item 2: "Chapman-Enskog with the Fuller-Schettler-Giddings volumes"
- Where: same file, item 2 and References.
- Category: C2 and C4.
  - C2: the FSG volumes are parameters of FSG's own empirical eq. (4), built on the Stefan-Maxwell hard-sphere form. They are not inputs to the Chapman-Enskog relation, so the named hybrid is stated by neither source.
  - C4: the volumes in current use are the revised set of Fuller, Ensley and Giddings (1969).
- Evidence:
  - Fuller 1966 text p.3: "starts with the Stefan-Maxwell hard sphere model"; text p.4, eq. (4) and Table I.
  - Poling 2001 text p.644: "Sum v ... atomic diffusion volumes in Table 11-1 (Fuller et al. 1969)"; "Eqs. (11-4.2) and (11-4.3) should not be used for hydrogen or helium".
- Fix class: (b). Choose one relation:
  - Chapman-Enskog, with Lennard-Jones parameters and collision integrals: Chapman and Cowling 1970, held, with a sourced parameter table;
  - or the FSG correlation, with the 1969 volumes: Fuller, Ensley and Giddings 1969, J. Phys. Chem. 73, 3679; identifier to confirm; ACS, paywalled.

  Either way, state the relation's validity for H2 and He, since the H2-He oracle instance runs on it.

##### N8. REQ-ATM-017 item 2: Blanc's law uncited
- Category: C2 (a law stated with no source). Fix class: (b). Cite and read a source for Blanc's law for diffusion in a multicomponent mixture.

##### N9. REQ-ATM-011 item 3: the direct-beam escape function
- Where: docs/requirements/atm/snow-albedo-grain-impurity-and-zenith-per-band.md, What is true and item 3.
- Use: alpha(mu0) = alpha_diffuse^K(mu0), with K(mu0) = (3/7)(1 + 2 mu0), applied per band to the direct fraction.
- Category: C2 (a law with no source). None of the record's references states it. The predecessor note gives no citation.
- Evidence: grep of Wiscombe and Warren 1980, Warren 1982 and Dang 2015 finds no escape-function form; vesper/notes/audits/snow-albedo-zenith.md says only "the asymptotic result of radiative transfer".
- Fix class: (b). Cite and read the asymptotic radiative-transfer source of the escape function for a semi-infinite weakly absorbing medium (for example Kokhanovsky and Zege 2004, "Scattering optics of snow", Appl. Opt. 43, 1589; identifier to confirm, paywalled). Add it to the References with a locator.

##### N10. REQ-ATM-010 item 4: Anderson 1976, fresh-snow density "in air temperature"
- Where: docs/requirements/atm/snow-and-ice-material-properties-follow-density-and-temperature.md, item 4 and References.
- Use: Bracketed between "the source fit in air temperature (Anderson 1976), with its site and temperature range, and a wet-bulb form".
- Category: C2 and C5.
  - C2: Anderson's relation is in wet-bulb temperature, not air temperature.
  - C5: it is Anderson's fit to LaChapelle's (1969) Alta, Utah plot.
- Evidence: text p.75, eq. (4.22), rho_ns = 0.05 + 0.0017 (T_w - 258.16)^1.5, with T_w the "wet-bulb temperature"; "based on a plot of new snow density versus temperature for Alta, Utah [LaChapelle (1969)]".
- Fix class: (a), where the arm is re-attributed.
  - The air-temperature arm is Hedstrom and Pomeroy 1998, eqs. 11 to 13. Its INDEX row is read, and its anchor names "the fresh-snow density relation".
  - Anderson 1976 eq. (4.22) is the wet-bulb arm, with LaChapelle 1969 named as its data.
  - The bracket's two arms and their mechanisms keep the disposition Bracketed.
  - The record says "as decision 0018 states", so decision 0018 needs the same check. It is outside this scope.

##### N11. REQ-ATM-009 item 1: Farouki 1981 standing in for Johansen 1975
- Where: docs/requirements/atm/soil-thermal-properties-from-moisture-and-texture.md, What is true ("read from the monograph rather than a restatement") and References.
- Category: C5. The CRREL monograph restates Johansen (1975), and INDEX records two misprints in its Table 24.
- Evidence: text p.127, "Table 24. Method for calculating thermal conductivity of mineral soils (after Johansen 1975)".
- Fix class: (b). Read Johansen's primary: the thesis, or its CRREL draft translation (1977), which is likely open on DTIC; identifier to confirm. Re-anchor the relation and the texture branches to it, and keep Farouki as the reading aid.

##### N12. REQ-ATM-002 References: Kiang et al. 2007b gloss
- Where: docs/requirements/atm/surface-optics-integrated-against-the-declared-spectrum.md, References ("Vegetation reflectance as a function of the host spectrum").
- Category: C2. The paper predicts the absorbance peaks of photosynthetic pigments evolved under other hosts. It gives no reflectance for a given canopy under a changed illumination.
- Evidence: abstract (text p.2-3): photosynthesis "that has evolved with a different parent star"; "pigments on planets around F2V stars may peak in absorbance in the blue, K2V in the red".
- Fix class: (a). Re-gloss to its read anchor (pigment peaks shift with stellar type, and the oxygenic window is the cap). That supports item 6, not item 1.

##### N13. REQ-CRY-002: Weertman 1957 for an effective-pressure sliding law
- Where: docs/requirements/cry/gravity-powers-in-ice-flow.md, What is true ("Weertman sliding C tau_b^p / N^q with p = 3 and q = 2"), the sliding-law item, and References.
- Category: C2. Weertman 1957 derives a hard-bed sliding velocity proportional to tau^((1+n)/2), with no effective pressure N, and with a stress exponent of 2 at n = 3.
- Evidence: text p.6, eq. (5), sliding velocity = (2BCD/3H rho)^1/2 (tau/2)^((1+n)/2) (L'/L)^(1+n).
- Fix class: (b). The tau^p N^-q form with field-fitted exponents comes from later empirical work, for example Budd, Keage and Blundy 1979, J. Glaciol. 23(89), 157-170 (identifier to confirm; Cambridge, likely open). Cite and read it for the law and the bracket ends. Keep Weertman 1957 for the hard-bed mechanism.

##### N14. REQ-CRY-002 and N18. REQ-CRY-001: Greve 2005 lecture notes for the shallow-ice formulation
- Where: docs/requirements/cry/gravity-powers-in-ice-flow.md References; docs/requirements/cry/shallow-ice-solver.md References.
- Category: C5. Lecture notes stand in for the primary derivation of the shallow-ice equations.
- Fix class: (b). Read and anchor to a peer-reviewed statement of the equations. Bueler et al. 2005 eqs. (1)-(2) is held, not read, and is already cited in REQ-CRY-001. Hutter 1983 is the monograph. One row covers both records.

##### N15. REQ-CRY-002: Cuffey and Paterson 2010 for the Clausius-Clapeyron gradient per pascal
- Where: docs/requirements/cry/gravity-powers-in-ice-flow.md, What is true (8.7e-4 K per metre of ice), the pressure-melting item, and References.
- Category: C5. A textbook value, given in two forms (pure ice and air-saturated), with no primary named for B in the passage.
- Evidence: text p.419, section 9.4.1, eqs. (9.9)-(9.10): "B = 7.42 x 10-8 K Pa-1"; "B = 9.8 x 10-8 K Pa-1 or 8.7 x 10-4 K m-1 of ice".
- Fix class: (b).
  - Derive dT_m/dP for pure ice from the Clausius-Clapeyron relation, using IAPWS R10-06 (read) and IAPWS-95 (Wagner and Pruss 2002, held). IAPWS R10-06 text p.8 states it computes the melting-pressure curve consistently.
  - The air-saturated increment needs its own primary.
  - Which of the two slopes the model uses is a declaration to record.

##### N16. REQ-CRY-004: Cuffey and Paterson Table 5.2 as the broadband ice albedo datum
- Where: docs/requirements/cry/ice-and-snow-albedo-per-band.md, the anchoring item and References.
- Use: the broadband datum the band pair reproduces "under the spectrum the datum was measured under".
- Category: C5 and C2.
  - C5: the table is a literature review's recommended, minimum and maximum values.
  - C2: a review value has no measurement spectrum to anchor under.
  - The What is true value, "about 0.5 from Paterson", is not the held edition's value for clean ice.
- Evidence: text p.159, "Table 5.2: Characteristic values for snow and ice albedo, from a literature review by S.J. Marshall", "Clean ice 0.35 0.30 0.46", "Blue ice 0.64 0.60 0.65".
- Fix class: (b). Anchor to a primary measured broadband or spectral ice albedo with its illumination stated. Grenfell and Maykut 1977 (held) measured spectral albedos for sea ice. A glacier-ice radiometer record is also possible.

##### N17. REQ-CRY-003: Bahr et al. 1997, a Derived coefficient
- Where: docs/requirements/cry/ice-placement-is-derived.md, the sub-grid glacier item and References.
- Use: "exponent and coefficient are `Derived` from Glen's `n`, the solver's `Gamma` and the column's own mass-balance gradient by Bahr's dimensional argument".
- Category: C2. Bahr's scaling analysis gives proportionalities only, and its exponent needs four closure exponents: width q, slope r, side drag f and mass balance m. No coefficient is derived, and Gamma does not enter.
- Evidence: text p.3, "for some constants r, f, and m"; text p.4, "four closure choices must be made, one for each of the scaling exponents related to glacier width (q), slope (r), side drag (f), and mass balance (m)"; text p.6, 1.36 reproduced under chosen closures.
- Fix class: (d), USER DECISION. Correcting this changes the declared disposition of the volume-area coefficient, and of the exponent's closure inputs, away from Derived. The options are Bracketed or Closure, or a derivation from a source that does give the coefficient.

#### Bibliographic corrections, use fit (fix class (a), INDEX already carries the confirmed identifier)

Where each record says "to confirm", INDEX already carries the confirmed identifier:
- Jouvet and Bueler 2012: title "Steady, shallow ice sheets as obstacle problems: well-posedness and finite element approximation", 10.1137/110856654 (REQ-CRY-001).
- Weertman 1957: 10.3189/s0022143000024709 (REQ-CRY-002).
- Grenfell and Maykut 1977: 10.3189/S0022143000021122 (REQ-CRY-004).
- Ohmura et al. 1992: 10.3189/S0022143000002276 (REQ-CRY-003).
- Cuffey and Paterson 2010: ISBN 978-0-12-369461-4 (REQ-CRY-002 and REQ-CRY-004).
- Abdul-Razzak and Ghan 2000, Twomey 1977, Korolev and Mazin 2003, Wiscombe and Warren 1980 I and II, Warren and Brandt 2008, Geyer 1992, Zwiers and von Storch 1995, Held and Soden 2006, Hostetler and Bartlein 1990, Subin et al. 2012, Gordon et al. 2022, Edwards and Slingo 1996, Sasamori 1968, Budyko 1969, North 1975, Slingo 1989, Allard et al. 2012, Lawrence et al. 2019: INDEX rows carry the identifier.

Halfar 1983's gloss says "g^3" and the amendment says g^-n. The source gives (rho g)^-n, so the gloss could say g^-n.

#### Observations outside the verdicts

- Most sources these records use as a basis are `held`, not `read`, in INDEX. Among them are Korolev, Parmentier, Steinrueck, Wesely, Slinn, Monahan, Kiehl, the Stephens papers, Slingo, Geyer, Zwiers, Held, Wagner, IAPWS 2014, Lemmon, Wilke, Chapman, Fuller, Poling, Hostetler, Subin, HITRAN2020, North, Wiscombe and Warren, Warren and Brandt, Flanner and Zender, Marshall, Glen, Weertman, Greve, Aschwanden, Cuffey, Halfar, Bueler, Jouvet, Bahr, Ohmura, Saxton, Petters and Abdul-Razzak. The records do not claim these are read. Any `Sourced` constant later built from them will be refused by lint_sourced until the row is marked read.
- Decision 0018: REQ-ATM-010 says the fresh-snow density bracket is "as decision 0018 states". If decision 0018 also attributes an air-temperature fit to Anderson 1976, it carries N10. That is outside this scope.
- Poling 2001 limits the Chapman-Enskog estimation equations for H2 and He (text p.644). This bears on the hydrogen-helium oracle instance of REQ-ATM-017 item 6, whichever diffusivity relation N7 settles on.

#### Fetch failures and paywalled sources

No source cited in this scope was missing from disk, so no fetch was attempted. The candidates for replacement, none held and every identifier to confirm before a request, are:
- Mason, E. A., Saxena, S. C. (1958). "Approximate Formula for the Thermal Conductivity of Gas Mixtures". Phys. Fluids 1, 361. 10.1063/1.1724352. Paywalled (AIP).
- Fuller, E. N., Ensley, K., Giddings, J. C. (1969). "Diffusion of halogenated hydrocarbons in helium. The effect of structure on collision cross sections". J. Phys. Chem. 73(11), 3679-3685. Identifier to confirm. Paywalled (ACS).
- Kokhanovsky, A. A., Zege, E. P. (2004). "Scattering optics of snow". Appl. Opt. 43(7), 1589-1602. Identifier to confirm. Paywalled (Optica).
- Zhang, L., Gong, S., Padro, J., Barrie, L. (2001). "A size-segregated particle dry deposition scheme for an atmospheric aerosol module". Atmos. Environ. 35(3), 549-560. Identifier to confirm. Paywalled.
- Abdul-Razzak, H., Ghan, S. J., Rivera-Carpio, C. (1998). "A parameterization of aerosol activation: 1. Single aerosol type". J. Geophys. Res. 103(D6), 6123-6131. Identifier to confirm. Likely free to read (AGU).
- Budd, W. F., Keage, P. L., Blundy, N. A. (1979). "Empirical studies of ice sliding". J. Glaciol. 23(89), 157-170. Identifier to confirm. Likely open (Cambridge).
- Johansen, O. (1975/1977). "Thermal conductivity of soils", CRREL Draft Translation 637. Identifier to confirm. Likely open (DTIC).
- Platnick, S., Twomey, S. (1994). "Determining the susceptibility of cloud albedo to changes in droplet concentration with the Advanced Very High Resolution Radiometer". J. Appl. Meteor. 33, 334-347. Identifier to confirm. Likely open (AMS).

### Q2: Requirements, bio


Worktree read: /home/cfutro/git/fiddlybits/.beads/worktrees/fiddlybits-9j0 at 625832c. Source text read under
/home/cfutro/git/fiddlybits/references/text/<stem>/<NNNN>.txt (NNNN is the PDF page index).

Inclusion rule. A citation is counted when it is the stated basis of a law, equation form, number, bracket end,
validity range, bar or rule the record states, including a predecessor note cited as the basis of a number or bar.
Architecture or background references (for example Clark 2015, Best 2011, Essery 2003, Scheiter 2013, Chen 2010,
Rabin 2017, Hantson 2016, Saunois 2020, Kirkby 2016, Gordon 2016, Carslaw 2013, Tsigaridis 2014, Cotrufo 2013,
Lehmann and Kleber 2015, Koven 2013, McGroddy 2004, Cleveland and Liptzin 2007, Dantas de Paula 2025,
Walker and Syers 1976, Okin 2004, Aciego 2017, Chadwick 1999, Cleveland 1999, Moorcroft 2001, Fisher 2018,
Smith 2001, Pacala 1993, Hickler 2012, Gerten 2004, Dietze 2014, Franklin 2012, Noy-Meir 1973,
Schwinning and Sala 2004, Christoffersen 2016, Bonan 2014, Givnish 2014, Anderegg 2016, Schaphoff 2018,
Bondeau 2007, Follows 2007, Cheung 2010, Fischer 2021, Wania 2009a/b and 2010, Spahni 2011, Rosentreter 2021,
Parton 1987, Pilegaard 2013) are not counted.

INDEX status is recorded, but a `held` status is not itself a not-fit verdict for a requirement record: the
read-status rule binds `Sourced` values and registry bars.

#### Counts

Total citations in scope: 103. FIT 86. NOT FIT 16. NOT VERIFIED 1 (source not held).

| file | record | total | fit | not fit | not verified |
| --- | --- | --- | --- | --- | --- |
| abiotic-nutrient-ledger.md | REQ-BIO-012 | 9 | 9 | 0 | 0 |
| bioclimatic-limits-are-tissue-thresholds.md | REQ-BIO-004 | 5 | 4 | 1 | 0 |
| closure-ledgers-span-the-inventory.md | REQ-BIO-013 | 1 | 1 | 0 | 0 |
| decomposition-stoichiometry-and-mineral-controls.md | REQ-BIO-010 | 7 | 7 | 0 | 0 |
| demography-disturbance-dispersal.md | REQ-BIO-009 | 1 | 1 | 0 | 0 |
| equilibrium-acceptance-drift-bound.md | REQ-BIO-014 | 5 | 4 | 1 | 0 |
| fire-effects-and-element-closure.md | REQ-BIO-016 | 5 | 5 | 0 | 0 |
| fire-ignition-and-drivers.md | REQ-BIO-015 | 16 | 12 | 4 | 0 |
| forcing-contract.md | REQ-BIO-002 | 2 | 2 | 0 | 0 |
| hydraulics-and-allometry-under-gravity.md | REQ-BIO-008 | 4 | 4 | 0 | 0 |
| managed-biosphere-potential-mode-interfaces.md | REQ-BIO-020 | 3 | 2 | 1 | 0 |
| photon-currency-and-canopy-optics.md | REQ-BIO-003 | 7 | 4 | 3 | 0 |
| physiology-on-the-planets-own-day.md | REQ-BIO-007 | 11 | 8 | 2 | 1 |
| seasonal-phase-and-latitude.md | REQ-BIO-005 | 2 | 1 | 1 | 0 |
| soil-nitrogen-gas-operator.md | REQ-BIO-011 | 7 | 7 | 0 | 0 |
| strategy-space-generated-from-the-system.md | REQ-BIO-006 | 4 | 4 | 0 | 0 |
| time-base-classes.md | REQ-BIO-001 | 4 | 3 | 1 | 0 |
| vegetation-interface-with-the-land-column.md | REQ-BIO-019 | 1 | 1 | 0 | 0 |
| volatile-organic-source-and-aerosol-precursors.md | REQ-BIO-018 | 5 | 4 | 1 | 0 |
| wetlands-peat-methane.md | REQ-BIO-017 | 4 | 3 | 1 | 0 |

No open branch edits any file under docs/requirements/bio/. Several fixes also want an INDEX.md status or anchor
edit, and INDEX.md is edited by fiddlybits-k6b.

#### Every citation

| # | where | use | source (INDEX file, status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | abiotic-nutrient-ledger.md:50-56,179-181 | composition-dependent NO yield, basis of the item 5 yield bracket | ardaseva_2017_lightning-chemistry-on-earth-like-exoplanets, held | abstract | FIT | p1: lightning chemistry in a CO2/N2 dominated atmosphere against Earth-like N2/O2 |
| 2 | abiotic-nutrient-ledger.md:60-62,153-156 | concentration times runoff release form, per-lithology table | meybeck1987-global-chemical-weathering, held | Table 2 | FIT | p7 specific runoff per watershed; p8 Table 2 per-lithology concentrations (cells stripped from text layer; values not re-read) |
| 3 | abiotic-nutrient-ledger.md:60-62,145-148 | lithology-resolved P liberation with runoff (relative P content) | hartmann2011-japan-silicate-weathering-phosphorus, held | abstract | FIT | p1: P-release per lithological class in dependence of runoff, "due to differences of applied P-content in rocks". Record says "DOI: to confirm" |
| 4 | abiotic-nutrient-ledger.md:149-152 | same, global | hartmann2014-weathering-phosphorus-release, held | title, abstract | FIT | p1 "Global chemical weathering and associated P-release - The role of lithology". Record says "DOI: to confirm" while INDEX carries 10.1016/j.chemgeo.2013.10.025 |
| 5 | abiotic-nutrient-ledger.md:160-163 | dust phosphate one tenth of dust total P | mahowald2008-global-phosphorus-deposition, held | p7 | FIT | p7: "we assume that mineral aerosols are 10% soluble P (PO4)", from Baker et al. 2006 Saharan average 10% (the measurement primary is Baker 2006) |
| 6 | abiotic-nutrient-ledger.md:172-175 | upper-bound standing pool for the adequacy screen | vitousek1986-nutrient-cycling-moist-tropical-forest, held | Table 2 | FIT | p5 Table 2 "Above-ground biomass and nutrient content in a variety of moist tropical forests" |
| 7 | abiotic-nutrient-ledger.md:106-114,176-178 | Earth lightning NOx per flash behind the item 5 brackets | schumann_2007_the-global-lightning-induced-nitrogen-oxides-source, held | abstract | FIT | p1: 15e25 molecules per flash, 250 mol NOx, uncertainty factor 0.13 to 2.7 |
| 8 | abiotic-nutrient-ledger.md:97-98,139-142 | parent material a finite, renewed stock | porder_2007_uplift-erosion-and-phosphorus-limitation-in-terrestrial-ecosystems, held | abstract | FIT | p1: soils weathering in place with no renewal against uplift renewal |
| 9 | abiotic-nutrient-ledger.md:104-105,186-189 | soil-order sorption table does not transfer | wang2010-cnp-terrestrial-biosphere, held | p2, p5 | FIT | p2 "estimates of P for different soil orders"; p5 labile and sorbed P by the Langmuir form |
| 10 | bioclimatic-limits-are-tissue-thresholds.md:20-26,102-105 | hardened frost resistance by tissue, roots the exception | larcher_2005_climatic-constraints-drive-the-evolution-of-low-temperature-resistance, read | Table 1 | FIT | p3 Table 1, boreal and alpine conifers: -40 to < -70 (leaf, bud, twig, stem), roots -20 to -30 |
| 11 | bioclimatic-limits-are-tissue-thresholds.md:22-24 | soil at 20 cm between 0 and -7 C while air below -20 C | larcher_2005 (same), read | Fig. 8 | FIT | p10 Fig. 8 caption: soil at 20 cm 0 to -3 and -3 to -7 C, frost events below -20 C; "After Bertrand et al. (1997)", young Acer saccharum (a reproduced figure from one experiment; narrative use) |
| 12 | bioclimatic-limits-are-tissue-thresholds.md:24-26,106-108 | deep supercooling caps near -30 to -50 C, then freezing tolerance | sakai1987-frost-survival-of-plants, held | Sect. 4.2.2 | FIT | p87: -40 C isotherm the borderline for deep-supercooling xylem; ray parenchyma survived -40 to -45 but not -50; boreal Salix, Populus, Betula no LTE, survive -70 by extracellular freezing |
| 13 | bioclimatic-limits-are-tissue-thresholds.md:31-34,109-112 | 0.07 m snow buys 0.5 to 1.4 K ground warming | zhang2005-seasonal-snow-cover-and-the-ground-thermal-regime, held | Sect. 3.3 | NOT FIT (C5, C3) | p7: Yershov 1998 "an increase in snow thickness by 5 to 15 cm leads to a 1C increase in mean annual ground temperature"; Kudryavtsev: thin high-albedo snow cools the surface |
| 14 | bioclimatic-limits-are-tissue-thresholds.md:11-14,113-116 | LPJ limits are monthly means on 20-year running means | sitch2003, held | p4 | FIT | p4: "limits are applied to 20-year running means" |
| 15 | closure-ledgers-span-the-inventory.md:48-54,114-115 | input-side stock and rate bounds | /home/cfutro/git/vesper/biosphere/notes/fire-nitrogen-range.md (predecessor) | Bound 1, Bound 2 | FIT | note lines 37-49: stock bound and rate bound derived from the input side; identities, no fire model or Earth comparison |
| 16 | decomposition-stoichiometry-and-mineral-controls.md:17-27,139-142 | N ramps on three soil pools; text low ends 3 and 7 | parton1993-century-soil-organic-matter, read | Fig. 4(a), p. 7 text | FIT | p7: C:N "vary within the ranges 3-15, 12-20, and 7-10, respectively, for active, slow and passive SOM (Figure 4)". Figure-digitised 2.14, 3.17 and the 0.002 break not checkable from text |
| 17 | decomposition-stoichiometry-and-mineral-controls.md:108-111,135-138 | P ramps (Fig. 3), receiving-pool convention, K3 occlusion | parton1988-century-c-n-p-s-grassland-model, read | Fig. 3; P submodel figure; p. 117 | FIT | PDF p7 Fig. 3 C:P of passive, slow, active against labile P; p5 flow SECONDARY P to OCCLUDED P labelled K3 Mt |
| 18 | decomposition-stoichiometry-and-mineral-controls.md:17-19,148-151 | the documentation miscites the ramps to ForCent 2010 | smith_2014_implications-of-incorporating-n-cycling-and-n-limitations-on-primary-p, held | p3, Appendix C | FIT | p3: SOM decomposition of 11 compartments "by Parton et al. (2010)"; Appendix C named for C:N |
| 19 | decomposition-stoichiometry-and-mineral-controls.md:35-38,160-164 | decomposer C:P homeostasis, slope 0.015, P 0.118, n 405 | mooshammer_2014_stoichiometric-imbalances-between-terrestrial-decomposer-communities-a, held | Table 2 | FIT | p4 Table 2: "Mic C:P = 66.5 + 0.015 x soil C:P", n 405, P 0.118 |
| 20 | decomposition-stoichiometry-and-mineral-controls.md:31-33,171-174 | Hedley-labile P is not plant-available P | yang2011-hedley-phosphorus-pedogenesis, held | abstract | FIT | p1: "labile P measured by Hedley fractionation method should not be defined as plant available P". The 6.6 to 11.3 factor is not attributed to it |
| 21 | decomposition-stoichiometry-and-mineral-controls.md:103-104,152-155 | soil-order-fitted Langmuir parameters | wang2010-cnp-terrestrial-biosphere, held | p5 | FIT | p5 Langmuir sorption; p2 soil orders |
| 22 | decomposition-stoichiometry-and-mineral-controls.md:190-193 | explicit-microbial model form as a bracket arm | wieder2013, held | p1 | FIT | p1: a model that explicitly represents microbial mechanisms of soil C |
| 23 | demography-disturbance-dispersal.md:46-49,92-95,122-124 | mortality submodel a model-form bracket | bugmann_2019_tree-mortality-submodels-drive-simulated-longterm-forest-dynamics-asse, held | abstract | FIT | p1: DVMs matched data irrespective of mortality submodel, yet submodels performing similarly diverged under scenarios |
| 24 | equilibrium-acceptance-drift-bound.md:42-44,146-149 | the windowed IAT estimator and its window; tau at the upper end of the window | (requested) The pivot algorithm..., 10.1007/BF01022990, requested | sect. 2.2 (per predecessor code) | NOT FIT (C2); source not held | carried reducer is Geyer's initial monotone positive sequence (vesper lib/autocorrelation.py integrated_time docstring); Madras-Sokal supplies only the error tau*sqrt(2(2M+1)/n), which Sokal 1997 eq. (3.19) p14 also states |
| 25 | equilibrium-acceptance-drift-bound.md:40-44,150-153 | effective sample size under autocorrelation | sokal1997-monte-carlo-methods-statistical-mechanics, held | p7, eq. (3.19) p14, p15 | FIT | p7: variance of the mean is 2 tau_int larger, n/(2 tau_int) effective samples; p14 eq. (3.19); predecessor tau = 1 + 2 sum rho = 2 tau_int, so m/tau is consistent |
| 26 | equilibrium-acceptance-drift-bound.md:42,154-156 | Welch degrees of freedom on the halves | welch1947-generalization-of-students-problem, held | eq. (24) | FIT | p4 eq. (24): effective degrees of freedom f = (a f1 + b f2)^2/(a^2 f1 + b^2 f2) |
| 27 | equilibrium-acceptance-drift-bound.md:36-39,157-160 | equivalence-test direction | schuirmann1987-two-one-sided-tests-procedure, held | abstract | FIT | p1: two one-sided tests on interval hypotheses against the power approach; used for the direction only, no bioequivalence margin or level borrowed |
| 28 | equilibrium-acceptance-drift-bound.md:46-48,161-164 | intersection-union needs no multiplicity correction | berger1996-bioequivalence-intersection-union-tests, held | p6 | FIT | p6: "no need for multiplicity adjustment"; the IUT with R the intersection of the Ri is a size-alpha test |
| 29 | fire-effects-and-element-closure.md:126-130 | combustion completeness by fuel class, fireline intensity, mortality | thonicke_2010_the-influence-of-vegetation-fire-spread-and-fire-behaviour-on-biomass, read | process structure | FIT | INDEX read for the SPITFIRE structure and its PFT fuel and combustion parameters; p5 parameter tables |
| 30 | fire-effects-and-element-closure.md:131-133 | fireline intensity | byram1959-combustion-of-forest-fuels, held | p. 93 of PDF | FIT | p93: "rate of heat release per unit time per unit length of fire front... the product of the available fuel, the heat yield, and the forward rate of spread" |
| 31 | fire-effects-and-element-closure.md:25-27,134-136 | rate-of-spread coefficient a unit conversion | noble_1980_mcarthurs-fire-danger-meters-expressed-as-equations, held | equations p2 | FIT | p2: R = 0.13 F (grassland), R = 0.0012 F W (forest) |
| 32 | fire-effects-and-element-closure.md:28-31,137-140 | survival logistic and its units | kobziar_2006_tree-mortality-patterns-following-prescribed-fires-in-a-mixed-conif, held | "Mortality modeling using logistic regression" | FIT | p8: species-specific logistic regressions with fireline intensity; coefficient tables not in the text layer, values not re-read |
| 33 | fire-effects-and-element-closure.md:55-57,141-144 | nitrogen species partition | delmas1995-determination-biomass-burning-emission-factors, held | fuel N partitioning figure | FIT | p13: NOx 21%, NH3 23%, N2O 0.76%, HCN 0.25%, CH3CN 0.70%, ash 11%, undetected 43% (savanna, Kapalga) |
| 34 | fire-ignition-and-drivers.md:32-35,161-164 | SPITFIRE's 20 percent CG and 4 percent ignition efficiency | thonicke_2010 (same), read | p. 6 | FIT | p6: "0.20 of these are cloud-to-ground flashes (CG) and ... their efficiency in starting fires ... is 0.04 (Latham and Williams, 2001...)" |
| 35 | fire-ignition-and-drivers.md:27-31,98-106,165-168 | Rothermel spread with slope; slope factor in tan(slope) alone, wind factor empirical | rothermel1972-mathematical-model-fire-spread-wildland-fuels, held | slope and wind factors | FIT | p31 "Slope factor, tan"; p34 "tan phi, slope, vertical rise/horizontal distance" |
| 36 | fire-ignition-and-drivers.md:169-172 | count-to-area seam | li_2012_a-process-based-fire-parameterization-of-intermediate-complexity-in-a, held | sect. 2.2 | FIT | p7: burned area of a fire with average fire duration tau |
| 37 | fire-ignition-and-drivers.md:54-56,169-172 | one-day duration anchored to a diurnal drying cycle | li_2012 (same), held | sect. 2.2 | NOT FIT (C2) | p7: "Giglio et al. (2006) reported that 2001-2004 mean persistence of most fires in the world was around 1 day... average fire duration is simply taken to be 1 day" |
| 38 | fire-ignition-and-drivers.md:35-37,173-176 | every CG strike ignites; the wet-lightning result | mangeon_2016_inferno-a-fire-and-emissions-scheme-for-the-uk-met-office-s-unified-mo, held | sect. 2.1, p10 | FIT | p2: mode 2 "each strike is assumed to start a fire"; p10: lightning appears to ignite fires more frequently in wet environments |
| 39 | fire-ignition-and-drivers.md:16-21,177-180 | burned-area regression on population | knorr_2014_impact-of-human-population-density-on-fire-frequency-at-the-global-sca, held | p3 | FIT | p3: population density term 1 - e^-x with x linear in density |
| 40 | fire-ignition-and-drivers.md:38-40,181-184 | CAPE x P validated on spatial averages | romps2014, romps2014-projected-lightning-supplement, held | p4, supplement p3 | FIT | p4: "A spatially resolved evaluation of Eq. 1 is not attempted"; supplement: CONUS-mean precipitation and CG rate |
| 41 | fire-ignition-and-drivers.md:42-46,185-188 | cloud-ice flux proxy, normalised to a global flash rate | finney_2014_using-cloud-ice-flux-to-parametrise-large-scale-lightning, held | p3 | FIT | p3: models scaled to the same global annual flash rate |
| 42 | fire-ignition-and-drivers.md:189-192 | cloud-top-height alternative | price_1992_a-simple-lightning-parameterization-for-calculating-global-lightning-d, held | abstract | FIT | p1: convective cloud top height the parameter variable |
| 43 | fire-ignition-and-drivers.md:189-192 | the cloud-to-ground fraction | price_1992 (same), held | none | NOT FIT (C2) | no CG fraction in the text; "cloud-to-ground" appears only in a reference title (p15) |
| 44 | fire-ignition-and-drivers.md:59-67,200-204 | states no minimum burned fraction | thonicke2001, held | eq. (9) | FIT | p6 eq. (9) A(s) with no floor; the only "minimum" (p3) is a fuel threshold |
| 45 | fire-ignition-and-drivers.md:51-54,205-207 | drought index coefficient on mean annual rainfall | keetch1968-a-drought-index-for-forest-fire-control, held | Tables 1-2, p11 | FIT | p6-p7 drought factor tables by mean annual rainfall; p11 table choice by station rainfall |
| 46 | fire-ignition-and-drivers.md:104-107,210-213 | flame-tilt relation at one end of the Froude scaling | albini1976-estimating-wildfire-behavior-and-effects, held | none | NOT FIT (C2) | INT-30 carries nomographs from Rothermel, flame length and effective windspeed; flames tilting appears only qualitatively (p88); no flame-tilt relation |
| 47 | fire-ignition-and-drivers.md:104-107,214-216 | flame-tilt relation at the other end | nelson2002-effective-wind-speed-models-fire-spread, held | eqs. (3)-(7) | FIT | p4-5: spread direction from Ua/Ub; buoyant velocity from buoyancy flux with g (eq. 7) |
| 48 | fire-ignition-and-drivers.md:133-136,217-220 | the lower limit of the oxygen flammability window | watson1978-methanogenesis-fires-regulation-atmospheric-oxygen, held | Fig. 1, p3 | NOT FIT (C2) | p3: "In 25% oxygen, vegetable matter at the fibre saturation point has a significant probability of ignition", the upper limit; no lower propagation limit |
| 49 | fire-ignition-and-drivers.md:133-136,221-225 | the window's measured limits | belcher2010-baseline-intrinsic-flammability-earth-ecosystems, held | abstract, p4 | FIT | p1: "greatly suppressed below 18.5% O2, entirely switched off below 16% O2"; p4 minimum 16% |
| 50 | forcing-contract.md:52-55,137-140 | chronology: generator conditioned on wet or dry state | richardson_1981_stochastic-simulation-of-daily-precipitation-temperature-and-solar-rad, held | Fig. 1 | FIT | p2 Fig. 1: "conditioned on the wet or dry status of the day" |
| 51 | forcing-contract.md:58-62,154-156 | replay bars at one fifth of the smallest effect | /home/cfutro/git/vesper/biosphere/notes/forcing-replay-preregistration.md (predecessor) | "The thresholds" | FIT | note lines 64-74: rule argued (cannot change sign or ranking; smaller would fall below patch sampling), smallest effect measured on the model (4.8% NPP concavity); not a borrowed convention |
| 52 | hydraulics-and-allometry-under-gravity.md:23-26,120-122 | self-loaded buckling proportional to (E/(rho g))^(1/3) d^(2/3) | mcmahon_1973_size-and-shape-in-biology, read | eqs. (1)-(3) | FIT | p1: "rho is the weight per unit volume"; Greenhill l_cr = 0.792 (E/rho)^(1/3) d^(2/3) |
| 53 | hydraulics-and-allometry-under-gravity.md:32-36,123-125 | D proportional to H^1.5, structural biomass to H^4 | king_2005_linking-tree-form-allocation-and-growth-with-an-allometrically-explici, held | Assumptions, p4 | FIT | p4: "stem biomass S proportional to H Db^2 ... and S proportional to H^4"; p1 Db proportional to H^1.5 against buckling |
| 54 | hydraulics-and-allometry-under-gravity.md:23-24,126-128 | hydraulic ceiling measured | koch2004-the-limits-to-tree-height, held | p3 | FIT | p3: "maximum height of redwood at our study site ... is 122 to 130 m" |
| 55 | hydraulics-and-allometry-under-gravity.md:45-48,146-148 | Earth root profile a Sourced envelope | jackson_1996_a-global-analysis-of-root-distributions-for-terrestrial-biomes, read | Table 1 | FIT | p3 Table 1 beta per biome, Y = 1 - beta^d |
| 56 | managed-biosphere-potential-mode-interfaces.md:67-72,121-123 | trophic transfer efficiency bracket | pauly1995-primary-production-required-sustain-global-fisheries, held | Fig. 2 | FIT | p3 Fig. 2: transfer efficiencies from 140 estimates in 48 trophic models |
| 57 | managed-biosphere-potential-mode-interfaces.md:124-125 | same | ryther1969-photosynthesis-and-fish-production-in-the-sea, held | "Efficiency" | FIT | p3 "Efficiency" section, food chains of three to four trophic levels |
| 58 | managed-biosphere-potential-mode-interfaces.md:72-76,130-133 | suitability from temperature, depth and exposure | gentry2017-mapping-global-potential-marine-aquaculture, held | Methods | NOT FIT (C2, partial) | p1-2: thermal thresholds from 30 years of SST, depth over 200 m excluded, low dissolved oxygen, human-use exclusions; no wave or wind exposure criterion |
| 59 | photon-currency-and-canopy-optics.md:32-35,85-89,112-113,120-123 | the solar control against the standard quantum conversion | mccree1971-action-spectrum-absorptance-quantum-yield-photosynthesis (McCree 1972, Agric. Meteorol. 9), held | none | NOT FIT (C2, C4) | p1: action spectrum, absorptance, quantum yield of 22 crop species; no photons-per-joule conversion for sunlight in the text; p23 neither irradiance nor absorbed quanta a perfect measure |
| 60 | photon-currency-and-canopy-optics.md:92-94 | measured leaf absorptance of Earth pigments (bracket end) | mccree1971 (same), held | Fig. 2, Tables III-VIII | FIT | p7 absorptance measurements; p19 means of absorptance for all species |
| 61 | photon-currency-and-canopy-optics.md:36-38,128-132 | peaks K2V 675, 711, 746; Sun 644, 672 nm | lehmer2021-peak-absorbance-wavelength, read | Table 1 | FIT | p7 Table 1: G2V 644, 672; K2V 675, 711, 746 |
| 62 | photon-currency-and-canopy-optics.md:41-43,133-135 | 745 nm PSI and 727 nm PSII donors | nurnberg2018-photochemistry-beyond-the-red-limit, read | p1 | FIT | p1: PSI and PSII "use chlorophyll f at 745 nm and chlorophyll f (or d) at 727 nm" |
| 63 | photon-currency-and-canopy-optics.md:43-45,80-83,124-127 | the oxygenic constraint; outer limit near 800 nm | kiang2007b-photosynthesis-signatures-ii, read | abstract, p32 | NOT FIT (C2, C6) | p3: multi-photosystem series "could allow for oxygenic photosystems at longer wavelengths. A wavelength of 1.1 um is a possible upper cut-off ... this cut-off is not strict"; p32 PAR 0.4-0.7 (0.400-0.730) um with limited photosynthesis to 1.1 um; no 800 nm cap |
| 64 | photon-currency-and-canopy-optics.md:48-51,139-142 | two-stream on omega = alpha + tau | sellers1985-canopy-reflectance-photosynthesis-transpiration, held | Table 2, p4 | FIT | p6 Table 2 "omega is the scattering coefficient"; p4 leaves reflect and transmit; the explicit sum not in the extracted text |
| 65 | photon-currency-and-canopy-optics.md:52-55,143-147 | per-class leaf reflectance and transmittance table | lawrence2019-community-land-model-version-5, held | none | NOT FIT (C2, C4) | 85 pages; no "reflectance" or "transmittance" anywhere in the text layer; the PFT optical table lives in the CLM5 Technical Description |
| 66 | physiology-on-the-planets-own-day.md:71,139-141 | Farquhar-family assimilation | farquhar1980-biochemical-model-photosynthetic-co2-assimilation, held | whole | FIT | p1 title and abstract |
| 67 | physiology-on-the-planets-own-day.md:71-83,142-145 | temperature functions; constants in mole fraction | bernacchi2001-improved-temperature-response-functions-models, held | notation, p2 | FIT | p1 notation Kc, Ko, G* in umol mol-1; p2 G* from in vivo measurement (measurement O2 and pressure not located in text) |
| 68 | physiology-on-the-planets-own-day.md:86-89,146-148 | Medlyn relation, slope from marginal water cost | medlyn2011-reconciling-optimal-empirical-approaches-modelling, held | eqs. (4)-(12) | FIT | p3 lambda "the marginal water cost of carbon gain"; p4 eq. (12) g1 proportional to sqrt(Gamma* lambda) |
| 69 | physiology-on-the-planets-own-day.md:94-96,149-151 | Vcmax, Jmax acclimation to growth temperature | kattge2007-temperature-acclimation-biochemical-model-photosynthesis, held | eq. (3) | FIT | p2: xi = ai + bi x tgrowth; tgrowth "the average of day and night temperature from the preceding month" |
| 70 | physiology-on-the-planets-own-day.md:94-96,152-154 | respiratory temperature response form (Atkin et al. 2014 form) | atkin2014-leaf-respiration, held | none | NOT FIT (C5, C2) | p1-3: New Phytologist Forum report of the 8th New Phytologist Workshop; describes JULES Q10 2.0 and others' acclimation approaches; states no form |
| 71 | physiology-on-the-planets-own-day.md:29-31,155-158 | 7-day end of the acclimation memory bracket | gifford2003-plant-respiration, held | p12 | NOT FIT (C5) | p12: respiration "seems to readily acclimate to a temperature change ... even within as little as a week (Gifford 1995)"; a review restating a completion time, not an e-folding time |
| 72 | physiology-on-the-planets-own-day.md:29-32,159-163 | 30-day memory for respiration | thum2019-quincy-supplement, read | Table S1 | FIT | p33 Table S1: maintenance respiration acclimation 30 days (eq. S23); photosynthetic optimum 7 days |
| 73 | physiology-on-the-planets-own-day.md:14-22,164-166 | daily integral: sinusoidal daylight, respiration over 24 - daylength | haxeltine1996-light-use-efficiency, held | eqn 5, eqn A1 | FIT | p4 eqn 5 "A_nd = A_n(I_a) t_d - a(24 - t_d) A_max"; p12 eqn A1 sinusoidal irradiance |
| 74 | physiology-on-the-planets-own-day.md:37-43,170-174 | tissue proportions measured as means | friend1997-hybrid-v3-biosphere-model, held | p. 26 | FIT | p26: foliage to sapwood plus bark C:N "mean of 0.145 across 9 species"; foliage to fine root 0.86 from Pinus radiata seedlings |
| 75 | physiology-on-the-planets-own-day.md:117-119,179-182 | joint N and P control of Vcmax | walker2014-leaf-photosynthetic-traits, held | abstract | FIT | p1: Vcmax and Jmax against leaf N, leaf P and SLA |
| 76 | physiology-on-the-planets-own-day.md:84-86,183-185 | C4 concentrating form | (requested) Biochemical Models of Leaf Photosynthesis, 10.1071/9780643103405, requested | none | NOT VERIFIED | not held; paywalled monograph listed in REQUESTS.md |
| 77 | seasonal-phase-and-latitude.md:90-93 | the phenology formulation carrying the ordinal dates | sitch2003, held | phenology | NOT FIT (C2) | p4 summergreen and raingreen phenology; no ordinal reset dates anywhere in the text (no January, July or day-of-year dates) |
| 78 | seasonal-phase-and-latitude.md:23-25,94-98 | FATES as the model whose resets were found | koven2020-benchmarking-fates-barro-colorado-island, held | identification | FIT | the paper identifies the model; the day 270 and 181 resets are attributed in the record to the survey, section 54 |
| 79 | soil-nitrogen-gas-operator.md:18-24,117-120 | DyN tables 5, 8, 9, 10, 11 | xuri2008-terrestrial-nitrogen-cycle-dgvm, held | Tables 5, 8-11 | FIT | p6 Table 5, p8 Tables 8 and 9, p9 Tables 10 and 11 |
| 80 | soil-nitrogen-gas-operator.md:121-125 | substrate definition, Michaelis-Menten constants | li1992-a-model-of-nitrous-oxide-evolution-from-soil, held | notation | FIT | p16: K35 nitrification rate; half-saturation values of soluble C and of NO3, NO2, N2O |
| 81 | soil-nitrogen-gas-operator.md:38-42,126-129 | incubation N2 share | weier1993-denitrification-n2-n2o-ratio, held | Tables 4-5 | FIT | p5 Tables 4 and 5 N2/N2O ratios by WFPS, C, NO3; the interquartile union 0.333-0.938 is a predecessor computation |
| 82 | soil-nitrogen-gas-operator.md:25-27,130-133 | WFPS axis | linn1984-water-filled-pore-space-co2-n2o, held | abstract | FIT | p1: percent water-filled pore space closely related to microbial activity |
| 83 | soil-nitrogen-gas-operator.md:32-35,134-137 | primary nitrification-moisture measurement | greaves1920-influence-of-moisture-on-bacterial-activities, held | p. 14-15 of PDF | FIT | p14: above 60 per cent a rapid decrease, "All soils ceased to nitrify when saturated"; p15 checked at 16.5 per cent |
| 84 | soil-nitrogen-gas-operator.md:33-37,138-140 | water-potential measurement of the rising limb | stark1995-mechanisms-for-soil-moisture-effects-on-nitrifying-bacteria, held | abstract | FIT | p1: substrate limitation and dehydration at different water potentials |
| 85 | soil-nitrogen-gas-operator.md:35-37,141-145 | pore space to pressure retention closure | cosby_1984, read | regressions | FIT | INDEX read for the texture regressions of retention |
| 86 | strategy-space-generated-from-the-system.md:59-62,125-129 | strategy sampling from trait ranges | pavlick2013-jena-diversity-dynamic-global-vegetation, held | abstract | FIT | p1: randomly generated plant growth strategies defined by functional trade-offs |
| 87 | strategy-space-generated-from-the-system.md:83-86,134-137 | leaf-lifespan trade-off | reich1992-leaf-lifespan, held | whole | FIT | p1 title and scope |
| 88 | strategy-space-generated-from-the-system.md:80-82,138-140 | Earth trait envelope as a Sourced range | wright2004-worldwide-leaf-economics-spectrum, held | abstract | FIT | p1: the worldwide leaf economics spectrum |
| 89 | strategy-space-generated-from-the-system.md:97-100,153-156 | acclimation as physiology | kattge2007 (same), held | eq. (3) | FIT | as row 69 |
| 90 | time-base-classes.md:76-80,130-133 | daily integral's 24-hour assumption | haxeltine1996 (same), held | eqn 5 | FIT | p4 eqn 5, respiration over 24 - t_d |
| 91 | time-base-classes.md:35-38,134-138 | Eq. 9 burned fraction per year, argument scale-invariant | thonicke2001, held | eq. (9) | FIT | p6 eq. (9) A(s) on fire season length s; p7 validity statement for functions (4) and (9) |
| 92 | time-base-classes.md:46-48,78-79,139-142 | one-day fire duration anchored to a diurnal cycle | li_2012, held | sect. 2.2 | NOT FIT (C2) | as row 37 |
| 93 | time-base-classes.md:143-146 | per-year mortality and turnover conventions | sitch2003, held | parameter table | FIT | p6: asymptotic maximum mortality rate, turnover times, turnover applied annually |
| 94 | vegetation-interface-with-the-land-column.md:78-79,135-137 | Medlyn stomatal conductance | medlyn2011, held | eq. (12) | FIT | as row 68 |
| 95 | volatile-organic-source-and-aerosol-precursors.md:34-37,126-129 | aggregation moves capacity about 50 percent isoprene, 40 percent monoterpene, opposite directions; bracket floors | schurgers2011-species-composition-bvoc, held | p7 paras 24-25 | NOT FIT (C2, minor) | p7 para 25: "variations of the apparent PFT emission capacities up to 50% for isoprene and 40% for monoterpenes" over time slices; opposite directions are para 24's Holocene trend (isoprene down more than 30%, monoterpenes up more than 50%) |
| 96 | volatile-organic-source-and-aerosol-precursors.md:34-37,130-133 | the global emissions framework, standard conditions | guenther2012-megan21, held | p3, p5-6 | FIT | p3 emission factor at standard conditions; p5-6 standard PPFD and leaf temperature |
| 97 | volatile-organic-source-and-aerosol-precursors.md:30-33,118-121 | capacities at 370 ppm CO2, 30 C, 1000 umol | arneth2007-process-based-isoprene, held | p9 | FIT | p9: "under standard conditions (1000 umol m-2 s-1, T = 30 C, CO2 = 370 ppm)"; the 12 h daylight not located |
| 98 | volatile-organic-source-and-aerosol-precursors.md:82-84,122-125 | storage as a trait | schurgers2009-process-based-monoterpene, held | abstract | FIT | p1: production combined with release from storage organs |
| 99 | volatile-organic-source-and-aerosol-precursors.md:55-58,94-97,134-136 | SOA optics from scattering to weakly absorbing | shrivastava2017-secondary-organic-aerosol, held | p35 | FIT | p35: absorptive properties of brown carbon complex and variable with chemistry and ageing |
| 100 | wetlands-peat-methane.md:20-22,158-160 | extent spread 8.6 to 26.9 million km2, a factor near four; bracket floors | melton_2013_wetchimp, held | Table 2 | NOT FIT (C2) | p8 Table 2, mean annual maximum extent 1993-2004: CLM4Me 8.8, DLEM 7.1, IAP-RAS 20.3, LPJ-Berna 81.7 (7.9 note b), LPJ-WHyMe 2.7 (note c), LPJ-WSL 9.0, ORCHIDEE 8.6, SDGVM 26.9, UVic-ESCM 16.3 |
| 101 | wetlands-peat-methane.md:98-101,153-156 | peat stock as an integral over a history | kleinen_2012_dynamic-wetland-extent-peat-accumulation, held | abstract | FIT | p1: peat accumulation over the Holocene |
| 102 | wetlands-peat-methane.md:48-51,161-165 | equifinality among production, oxidation, transport over eleven parameters | kallingal_2024_lpj-guess-methane-mcmc, held | p6, p17 | FIT | p6: "we chose 11 of them for the optimisation"; p17 equifinality |
| 103 | wetlands-peat-methane.md:96-97,166-168 | dry-soil sink | curry_2007_soil-methane-consumption, held | abstract | FIT | p1: diffusion-reaction solution for soil uptake |

#### Not-fit cases

##### N1. REQ-BIO-004, Zhang 2005 via Yershov 1998 (row 13)
- **Where and use:** bioclimatic-limits-are-tissue-thresholds.md:31-34. The claim is that a 0.07 m snowpack buys 0.5 to 1.4 K of ground warming, attributed to "Yershov 1998 as reviewed by Zhang 2005".
- **Category:** C5 (a review stands in for the primary) and C3 (a regime is exceeded).
- **What is wrong:** Zhang restates Yershov's mean rate, 1 C of mean annual ground warming per 5 to 15 cm of added snow. The 0.5 to 1.4 K is that rate scaled linearly to 7 cm. That pack is thin, and the same section (Kudryavtsev) says thin high-albedo snow cools the surface, with insulation peaking near 40 cm.
- **Evidence:** zhang2005, p7, section 3.3, paragraphs 26-27.
- **Fix class:** (a).
- **Proposed fix:** restate the passage as "Zhang (2005) section 3.3 restates Yershov's (1998) rate of about 1 C per 5 to 15 cm; scaled to 0.07 m it gives 0.5 to 1.4 K, outside the thin-snow regime where the same section reports cooling". No constant rests on it. Marking Zhang read in INDEX.md touches a file fiddlybits-k6b edits.

##### N2. REQ-BIO-014, Madras and Sokal 1988 (row 24)
- **Where and use:** equilibrium-acceptance-drift-bound.md:42-44 and 146-149. The record cites "the windowed integrated autocorrelation time estimator and its window" and "memory time at the upper end of its Madras-Sokal window".
- **Category:** C2 (the cited source does not state the estimator used). The source is also not held.
- **What is wrong:** the carried reducer (vesper lib/autocorrelation.py `integrated_time`) uses Geyer's initial monotone positive sequence, truncating on pair sums. Madras-Sokal 1988 section 2.2 supplies only the error formula tau*sqrt(2(2M+1)/n), per the code's docstring. That formula is also Sokal 1997 eq. (3.19), p14, which is held.
- **Fix class:** (b).
- **Proposed row:** name Geyer's estimator with its primary source (fetch, read and index it) and cite Sokal 1997 eq. (3.19), p14, for the interval, marking it read. Madras-Sokal stays requested or is dropped.
  - **Boundary:** REQ-BIO-014 and INDEX.md.
  - **Acceptance:** each named estimator and interval resolves to a read row with a locator.

##### N3. REQ-BIO-015 and REQ-BIO-001, Li et al. 2012 duration (rows 37, 92)
- **Where and use:** fire-ignition-and-drivers.md:54-56 and time-base-classes.md:46-48, 78-79 and 139-142. The one-day fire duration is said to be "anchored to a diurnal drying cycle". REQ-BIO-001 uses it as a canonical `BiologicallyEntrained` example.
- **Category:** C2.
- **What is wrong:** Li 2012 takes 1 day from observed fire persistence (MODIS, Giglio et al. 2006) and from CTEM-FIRE practice. It makes no diurnal-cycle argument.
- **Evidence:** li_2012, p7, section 2.2.
- **Fix class:** (b).
- **Proposed row:** re-source or re-argue the class of the one-day duration (observed persistence is an absolute-time statistic), and correct both records.
  - **Boundary:** REQ-BIO-001 and REQ-BIO-015 only.
  - **Acceptance:** the class assignment cites a read passage.
- **Scope of the fix:** decision 0026's rotation-invariance oracle reads the classes but does not cite Li 2012, and no registry entry does. It is not class (d).

##### N4. REQ-BIO-015, Price and Rind 1992 as the CG-fraction source (row 43)
- **Where and use:** fire-ignition-and-drivers.md:189-192, "the cloud-top-height alternative and the cloud-to-ground fraction".
- **Category:** C2.
- **What is wrong:** the 1992 paper parameterises total flash frequency on cloud-top height and has no CG fraction. "cloud-to-ground" occurs only in a reference title.
- **Evidence:** price_1992, p1 abstract; p15 references.
- **Fix class:** (b).
- **Proposed row:** fetch and read Price and Rind (1993), "What determines the cloud-to-ground lightning fraction in thunderstorms?", Geophysical Research Letters 20 (identifier to confirm; not in INDEX). Otherwise restrict the annotation to the cloud-top-height alternative.
  - **Boundary:** REQ-BIO-015 and INDEX.md.

##### N5. REQ-BIO-015, Albini 1976 INT-30 as a flame-tilt relation (row 46)
- **Where and use:** fire-ignition-and-drivers.md:104-107 and 210-213. It is named as one end of the `Bracketed` Froude scaling.
- **Category:** C2 (the wrong work is cited).
- **What is wrong:** GTR INT-30 has no flame-tilt relation. The Albini (1976) flame-tilt treatment that Nelson 2002 cites is an unpublished note, "Combining wind and slope effects on spread rate" (Nelson 2002, p3 and reference list p9).
- **Evidence:** albini1976, text grep over all pages (tilt appears only qualitatively, p88); nelson2002, p3.
- **Fix class:** (b).
- **Proposed row:** replace this end of the bracket with a published, readable flame-tilt relation carrying a Froude number, fetched and read, and correct REQ-BIO-015 and decision 0021's reference if it names Albini.
  - **Boundary:** REQ-BIO-015, INDEX.md, and 0021 only if needed.
- **Scope of the fix:** a bracket end in a requirement, not a registered disposition.

##### N6. REQ-BIO-015, Watson et al. 1978 as the lower limit (row 48)
- **Where and use:** fire-ignition-and-drivers.md:133-136 and 217-220. The annotation reads "The lower limit of the oxygen flammability window".
- **Category:** C2.
- **What is wrong:** Watson 1978 gives the upper limit: at 25 percent O2, fuel at fibre saturation ignites, and 25 to 35 percent is incompatible with land vegetation. The lower limit is Belcher 2010's 16 percent O2.
- **Evidence:** watson1978, p3 and Fig. 1; belcher2010, p1 abstract and p4.
- **Fix class:** (a).
- **Proposed fix:** swap the annotations. Watson 1978 carries the upper limit (p3); Belcher 2010 carries the lower limit (abstract, and p4 "minimum ... 16%"). Mark both read with those locators (INDEX.md is edited by k6b).
- **Scope of the fix:** `fire.oxygen_flammability_window` names both sources without assigning edges, and its threshold text does not change. Decision 0021 names only a `Sourced` window. It is not class (d).

##### N7. REQ-BIO-020, Gentry et al. 2017 on exposure (row 58)
- **Where and use:** managed-biosphere-potential-mode-interfaces.md:130-133, "Suitability from temperature, depth and exposure".
- **Category:** C2 (partial).
- **What is wrong:** Gentry's criteria are thermal thresholds, depth, dissolved oxygen, chlorophyll for bivalves, and human-use exclusions. There is no exposure criterion.
- **Evidence:** gentry2017, p1-2.
- **Fix class:** (a).
- **Proposed fix:** drop "exposure" from the annotation, or attribute exposure to Kapetsky and Aguilar-Manjarrez 2007 (held) once read.

##### N8. REQ-BIO-003, McCree 1972a as the standard solar quantum conversion (row 59)
- **Where and use:** photon-currency-and-canopy-optics.md:32-35, 85-89, 112-113 and 120-123. This covers the solar control against "the standard quantum conversion", and the Earth instance reproducing it "as a PASS metric".
- **Category:** C2 and C4 (the wrong paper of the pair).
- **What is wrong:** Agric. Meteorol. 9, 191-216 gives action spectra, absorptance and quantum yield. It has no photons-per-joule factor for sunlight. The 4.57 umol/J solar figure is commonly traced to McCree (1972), "Test of current definitions of photosynthetically active radiation against leaf photosynthesis data", Agric. Meteorol. 10 (identifier to confirm; not indexed).
- **Evidence:** mccree1971, p1 abstract; p23 conclusions; no conversion factor in the text.
- **Fix class:** (b).
- **Proposed row:** fetch and read the second McCree paper, or restate the control as an identity from a declared solar spectrum (item 3 already derives it), and correct the annotation.
  - **Boundary:** REQ-BIO-003 and INDEX.md.
- **Scope of the fix:** no registry entry names McCree or 4.57, so it is not class (d) today. It would become class (d) if a registered PASS bar is later built on this value.

##### N9. REQ-BIO-003, Kiang et al. 2007b on the oxygenic outer limit (row 63)
- **Where and use:** photon-currency-and-canopy-optics.md:43-45, 80-83 and 124-127. "Oxygenic photosynthesis is capped near 800 nm on known biochemistry"; the photochemical outer limit is a bracket end in item 2; Kiang is annotated "the oxygenic constraint".
- **Category:** C2. It is also C6: INDEX marks Kiang read for "the oxygenic window is the honest cap".
- **What is wrong:** Kiang states no 800 nm cap. It says multi-photosystem series could allow oxygenic photosynthesis at longer wavelengths, and that 1.1 um is a possible but not strict electronic cut-off.
- **Evidence:** kiang2007b, p3 abstract; p32.
- **Fix class:** (b).
- **Proposed row:**
  - Source the outer limit on a read passage: Nurnberg 2018's demonstrated 745 nm is the longest demonstrated donor, and any cap beyond it needs its own source. Alternatively, state Kiang's 1.1 um non-strict cut-off.
  - Correct the INDEX anchor.
  - **Boundary:** REQ-BIO-003 and INDEX.md.

##### N10. REQ-BIO-003, Lawrence et al. 2019 as the leaf optics table (row 65)
- **Where and use:** photon-currency-and-canopy-optics.md:52-55 and 143-147, "The per-class leaf reflectance and transmittance table that supplied the sign test".
- **Category:** C2 and C4 (the wrong document of the release).
- **What is wrong:** the JAMES description paper has no leaf optical property table. The PFT reflectance and transmittance table is in the CLM5 Technical Description, which is not indexed. The sign measurement itself is the predecessor survey's, section 38.
- **Evidence:** lawrence2019, text grep over all 85 pages finds neither "reflectance" nor "transmittance".
- **Fix class:** (b).
- **Proposed row:** fetch and read the CLM5 Technical Description (open access from NCAR, identifier to confirm), cite its table with a locator, and correct REQ-BIO-003.
  - **Boundary:** REQ-BIO-003 and INDEX.md.

##### N11. REQ-BIO-007, Atkin et al. 2014 as a respiration form (row 70)
- **Where and use:** physiology-on-the-planets-own-day.md:94-96 and 152-154, "respiratory (Atkin et al. 2014 form) temperature responses acclimate".
- **Category:** C5 and C2.
- **What is wrong:** the paper is a New Phytologist Forum meeting report. It surveys approaches (JULES Q10 2.0; acclimation schemes of Atkin et al. 2008, Smith and Dukes, Vanderwel; the O'Sullivan et al. 2013 data set) and gives no form.
- **Evidence:** atkin2014, p1 and p3.
- **Fix class:** (b).
- **Proposed row:** identify, fetch and read the primary acclimated respiration form (candidates to confirm: Atkin et al. 2008; Heskel et al. 2016), and correct REQ-BIO-007 and the INDEX anchor.
  - **Boundary:** REQ-BIO-007 and INDEX.md.

##### N12. REQ-BIO-007, Gifford 2003 as the 7-day bracket end (row 71)
- **Where and use:** physiology-on-the-planets-own-day.md:29-31 and 155-158. The memory e-folding time is bracketed 7 to 30 days, and the 7-day end is sourced to Gifford 2003.
- **Category:** C5.
- **What is wrong:**
  - Gifford 2003 is a review. The primary it cites is Gifford (1995).
  - The review's "within as little as a week" is a time to acclimate, not an e-folding time.
  - The 7 days in the QUINCY supplement belong to the photosynthetic optimum, not respiration.
- **Evidence:** gifford2003, p12; thum2019-quincy-supplement, p33, Table S1.
- **Fix class:** (b).
- **Proposed row:** fetch and read Gifford (1995), Global Change Biology 1 (title and identifier to confirm), or another primary that states a respiration acclimation timescale convertible to an e-folding time. Restate the lower end.
  - **Boundary:** REQ-BIO-007 and INDEX.md.
- **Scope of the fix:** a requirement's bracket, not a coded disposition.

##### N13. REQ-BIO-005, Sitch 2003 as the ordinal-date formulation (row 77)
- **Where and use:** seasonal-phase-and-latitude.md:90-93, "The phenology formulation carrying the ordinal dates".
- **Category:** C2.
- **What is wrong:** the paper describes summergreen and raingreen phenology with no ordinal reset dates. The 15 January and 15 July dates are the ported code's.
- **Evidence:** sitch2003, p4; text grep over all pages.
- **Fix class:** (a).
- **Proposed fix:** reword the annotation to the LPJ phenology formulation, and attribute the ordinal dates to the port's code as measured in the predecessor audit named in "What is true".

##### N14. REQ-BIO-018, Schurgers et al. 2011 aggregation figures (row 95)
- **Where and use:** volatile-organic-source-and-aerosol-precursors.md:34-37 and 126-129. The record says species aggregation moves apparent capacity "about 50 percent for isoprene and 40 percent for monoterpenes in opposite directions", and that this sets bracket floors.
- **Category:** C2 (minor).
- **What is wrong:** paragraph 25 gives "up to" 50 and 40 percent variation with changing species abundance across time slices. The opposite directions are paragraph 24's Holocene trend, isoprene down more than 30 percent and monoterpenes up more than 50 percent. The record merges the two statements and reads maxima as typical magnitudes.
- **Evidence:** schurgers2011, p7, paragraphs 24-25.
- **Fix class:** (a).
- **Proposed fix:** restate with the locator; mark read.

##### N15. REQ-BIO-017, Melton et al. 2013 wetland extent spread (row 100)
- **Where and use:** wetlands-peat-methane.md:20-22 and 158-160, "a factor near four (8.6 to 26.9 million km2 sharing forcing)". This spread sets bracket floors.
- **Category:** C2.
- **What is wrong:** Table 2 lists DLEM at 7.1, below the stated lower end of 8.6. LPJ-WHyMe (2.7, note c) and LPJ-Berna (81.7, or 7.9 under note b) need their notes read. 26.9/8.6 is 3.1; "near four" matches 26.9/7.1 = 3.8. The same range is repeated in the INDEX anchor.
- **Evidence:** melton_2013_wetchimp, p8, Table 2.
- **Fix class:** (b).
- **Proposed row:** read Table 2 with notes b and c from the scan, state the model range and which models it excludes and why, and correct REQ-BIO-017 and the INDEX anchor.
  - **Boundary:** REQ-BIO-017 and INDEX.md.
- **Scope of the fix:** no registry entry names WETCHIMP or 26.9, so it is not class (d).

(N3 counts twice, rows 37 and 92, so the 15 sections cover 16 not-fit citations.)

#### Cases for the user (class d)

None. No not-fit case in this scope changes a registered bar, a coded disposition, a decision's basis, or a test instance's declared value. Four cases sit next to such things:
- `fire.oxygen_flammability_window` is unregistered and its text is unchanged by the N6 fix.
- The McCree conversion (N8) would become class (d) if it is registered as a PASS bar.
- The Li 2012 class (N3) feeds decision 0026's invariance oracle, which does not cite Li.
- Albini (N5) is a bracket end named in the decision 0021 prose.

#### Observations outside the citation count

- **REQ-BIO-014:** the declared test size of 0.05 and the "0.05 K bar" in the consumer chain (line 60) have no stated basis. Neither is a citation, but both are declared values a reader could take as conventions.
- **Record identifiers:** REQ-BIO-012 gives "DOI: to confirm" for Hartmann 2011 and Hartmann 2014 while INDEX carries the 2014 DOI. Other records carry "to confirm" identifiers for held sources: Larcher, Sakai, King, Givnish, Kobziar, Noble, Thonicke 2001, Essery, Smith 2001, Pacala, Hickler, Sokal, Ardaseva.
- **Values not re-read:** Kobziar's coefficients, Meybeck's and Vitousek's table cells, and the Parton figure-digitised values sit in tables or figures missing from the text layer, so they were not re-read.

#### Fetch failures and paywalled sources

- **Madras-Sokal:** "The pivot algorithm: A highly efficient Monte Carlo method for the self-avoiding walk", Madras and Sokal, J. Stat. Phys. 50, 109-186 (1988), DOI 10.1007/BF01022990. Unpaywall reports `is_oa` false (one attempt), so it was not fetched. It is paywalled.
- **von Caemmerer:** "Biochemical Models of Leaf Photosynthesis", von Caemmerer (2000), CSIRO Publishing, DOI 10.1071/9780643103405, ISBN 978-0-643-06379-2. It is already in REQUESTS.md and is paywalled.
- **Suggested replacements, not held and not indexed.** None was fetched here, and each identifier needs confirming:
  - McCree (1972), "Test of current definitions of photosynthetically active radiation against leaf photosynthesis data", Agric. Meteorol. 10;
  - Price and Rind (1993), "What determines the cloud-to-ground lightning fraction in thunderstorms?", Geophys. Res. Lett. 20;
  - Gifford (1995), Global Change Biology 1;
  - Geyer's initial positive sequence estimator paper;
  - the CLM5 Technical Description;
  - a primary acclimated leaf respiration form;
  - a published flame-tilt relation with a Froude number.

### Q3: Requirements, hyd and ocn


Audited on the worktree at 625832c (main). In scope: every citation used as the basis of a law,
number, scheme, threshold, validity range or rule the record states, whether in the body or in a
References parenthetical that names what the source supplies. A reference with no claim in the
record resting on it is listed as excluded with the reason, and is not counted. Page numbers "p.N"
are the PDF page index of references/text/<stem>/000N.txt unless "printed p." is given.

#### Counts

| scope | citations | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| hyd (12 files) | 38 | 32 | 6 | 0 |
| ocn (12 files) | 43 | 33 | 10 | 0 |
| total | 81 | 65 | 16 | 0 |

Per file (citations / not fit):
- hyd/basin-fate-is-a-process.md (REQ-HYD-008): 5 / 1
- hyd/depressions-are-nodes-no-catalogue-floor.md (REQ-HYD-006): 2 / 0
- hyd/groundwater-sinks-baselevels-exchange.md (REQ-HYD-003): 6 / 1
- hyd/lake-equilibrium-earth-oracle.md (REQ-HYD-001): 5 / 2
- hyd/lake-storage-closed-form-periodic.md (REQ-HYD-011): 1 / 0
- hyd/lake-tile-thermal-column.md (REQ-HYD-010): 3 / 0
- hyd/land-water-ledger.md (REQ-HYD-012): 0 / 0 (no external source claimed; the record says so)
- hyd/subgrid-statistic-rule.md (REQ-HYD-005): 8 / 2
- hyd/water-balance-decides-basin-fate.md (REQ-HYD-007): 3 / 0
- hyd/water-table-complementarity-identities.md (REQ-HYD-004): 3 / 0
- hyd/water-table-skill-oracle.md (REQ-HYD-002): 2 / 0
- hyd/wetness-partition-one-cut.md (REQ-HYD-009): 0 / 0 (references carry no claim)
- ocn/bathymetry-distribution-and-connectivity-graph.md (REQ-OCN-009): 2 / 0
- ocn/coupled-equilibrium-exit-axes.md (REQ-OCN-005): 4 / 1
- ocn/coupling-contract.md (REQ-OCN-004): 3 / 1
- ocn/crossing-acceptance-and-coastal-cells.md (REQ-OCN-010): 3 / 2
- ocn/cross-pass-forcing-trap.md (REQ-OCN-006): 3 / 1
- ocn/depth-to-pressure-through-declared-gravity.md (REQ-OCN-003): 8 / 3
- ocn/marine-trait-community.md (REQ-OCN-008): 3 / 0
- ocn/open-water-albedo.md (REQ-OCN-012): 6 / 0
- ocn/rotation-never-fails-open.md (REQ-OCN-002): 1 / 1
- ocn/scales-are-system-fields.md (REQ-OCN-001): 1 / 1
- ocn/sea-ice-dynamics-class.md (REQ-OCN-011): 6 / 0
- ocn/three-questions-and-marine-climate-pathways.md (REQ-OCN-007): 3 / 0

Open branches: of the files in this scope only hyd/lake-equilibrium-earth-oracle.md is edited by an
open branch (fiddlybits-k6b). Every other file here is free to edit.

#### Every citation

##### hyd

| # | where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| H1 | basin-fate-is-a-process.md:49 | the expressed erodibility contrast across a mountain belt, about a factor of 4, is the one entering k_e | zondervan2020-rock-strength-fluvial-erodibility.pdf (read) | Conclusions | FIT | p.11: contrasts in fluvial erodibility "between a factor of 4 calculated through ksn and two orders of magnitude calculated through UCS" |
| H2 | basin-fate-is-a-process.md:50 | "the intact-rock range (five orders, Stock and Montgomery)" | stock1999-stream-power-erodibility-lithology.pdf (read) | none given | NOT FIT C2 | p.10 and p.9: the five orders are the stream-power K from river profiles, 1e-7 to 1e-2 m^0.2/yr, mudstones to granitoids, not intact-rock strength; the intact-strength range is Zondervan's two orders by UCS (p.11) |
| H3 | basin-fate-is-a-process.md:89-90, 114 | steady relief, and so sill slope, scales as g^(-1/n) through K = rho_w g k_e | whipple1999-dynamics-stream-power-river-incision.pdf (held) | eq. 20 and following | FIT | p.6 eq. (20): equilibrium gradient goes as N_E^(1/n); "Equilibrium fluvial relief ... scale[s] precisely with the stream gradient" (eq. 22); N_E carries K, so relief goes as K^(-1/n) |
| H4 | basin-fate-is-a-process.md:40-41, 124 | HydroLAKES fields for the Earth REPORT metric: mean depth, pour point | messager2016-estimating-volume-age-water-stored.pdf (held) | Discussion | FIT | p.7 l.76: every polygon carries "surface area, perimeter, mean depth, volume and residence time" and is linked "via its pour point" to HydroSHEDS |
| H5 | basin-fate-is-a-process.md:41, 127 | HydroBASINS level-5 basins for the same metric | lehner2013-global-river-hydrography-network-routing.pdf (held) | basin subdivision | FIT | p.9 l.38: "A total of 12 levels of basin subdivisions", Pfafstetter coding (p.7 l.45) |
| H6 | depressions-are-nodes-no-catalogue-floor.md:45, 83 | routing on a depression hierarchy | barnes2020-computing-water-flow-through-complex.pdf (held) | abstract | FIT | p.1 l.22-25: "the depression hierarchy - that captures the full topologic and topographic complexity of depressions" |
| H7 | depressions-are-nodes-no-catalogue-floor.md:45, 86 | fill-spill-merge on that hierarchy | barnes2021-computing-water-flow-through-complex.pdf (held) | abstract | FIT | p.1 l.26-28: the Fill-Spill-Merge algorithm; depressions "fill ... and spill into their neighbors. If both ... fill, they merge" |
| H8 | groundwater-sinks-baselevels-exchange.md:11-13 | catchment budget dS/dt = P - ET - Qr - Qg, dropping Qg the common assumption | fan_2019_are-catchments-leaky.pdf (held) | eq. 1 | FIT | p.1 l.45-50: "dS/dt = P - ET - Qr - Qg ... A common assumption is that the Qg term is negligible" |
| H9 | groundwater-sinks-baselevels-exchange.md:13-15 | leaky-catchment conditions: small, steep regional gradient, deep permeable substrate, dry climate | fan_2019 (held) | abstract | FIT | p.1 l.26-30: "small catchment size, positioned at either the high or low end of a steep regional topographic and climatic gradient, underlain by deep permeable substrates ... and in drier climate" |
| H10 | groundwater-sinks-baselevels-exchange.md:27-29, 75 | ET decays exponentially with water-table depth, beating the linear form of MODFLOW's EVT; the form Sourced from Shah | shah_2007_extinction-depth-and-evapotranspiration-from-ground-water-under-select.pdf (held) | abstract; p.335 exponential fit | FIT | p.1 l.14-15: "better simulated by an exponential decay function than the commonly used linear decay"; l.47-48 early MODFLOW "assumed that GWET decays linearly"; p.7 l.5-9 the exponential model after transition depth d' |
| H11 | groundwater-sinks-baselevels-exchange.md:29, 79 | "extinction depths 0.18 to 1.86 m", and Shah's extinction depths as the reported Earth distance | shah_2007 (held) | none given | NOT FIT C2 | p.7 (printed p.335): "The transition depth ranged from 18 cm for bare sand to a maximum of 186 cm"; Table 1 (printed p.334) gives extinction depths 50 to 820 cm |
| H12 | groundwater-sinks-baselevels-exchange.md:48-52, 84-86 | permeability per class: Table 1 geometric means keyed on Durr classes, sigma 1.5 to 2.5 orders, scale-independent 5 to 100 km except carbonate, evaporite unassigned | gleeson_2011_mapping-permeability-over-the-surface-of-the-earth.pdf (read) | Table 1, para 7-8 | FIT | printed p.3 Table 1 (global map): sigma 2.0, 2.5, 1.5, 1.5, 1.8; "not assigned: WB, IG, EV"; para 8: "not scale dependent in this range [5-100 km] for all hydrolithologies except carbonates" |
| H13 | groundwater-sinks-baselevels-exchange.md:49, 116 | the Durr et al. lithologic classes the table keys on | durr2005-lithologic-composition-continental-surfaces.pdf (held) | abstract | FIT | p.1 l.14: "15 rock types"; class list in Gleeson Table 1 footnote b |
| H14 | lake-equilibrium-earth-oracle.md:21, 69, 85 | HydroLAKES v1.0 as the observed lake areas, under the rule "use long-term mean lake areas, never a single year" | messager2016 (held) | Methods | NOT FIT C3 | p.8 l.7-11: HydroLAKES compiled from "several near-global and regional data sets ... foremost the SRTM Water Body Data ... and CanVec", resolution "cannot be strictly defined"; p.6 l.9: remote sensing "a snapshot of surface water on Earth at a given time"; no temporal averaging of areas is stated |
| H15 | lake-equilibrium-earth-oracle.md:21, 88 | HydroBASINS level 5 join | lehner2013 (held) | basin levels | FIT | p.9 l.38 as H5 |
| H16 | lake-equilibrium-earth-oracle.md:41-42, 90 | present-day terminal lakes are shrunken, so a full-to-spill comparison is a category error | wang2018-endorheic-water-storage.pdf (read) | introduction | FIT (note) | p.1 l.43-44: "storage declines ... in desiccating lakes (for example, the Aral Sea and Great Salt Lake)"; note: the INDEX row is read for a different passage (one-fifth endorheic), and "mostly" is not quantified by the source |
| H17 | lake-equilibrium-earth-oracle.md:36, 66, 92 | Copernicus DEM for area at spill and capacity | esa2022-copernicus-dem-product-handbook.pdf (held on main; read on fiddlybits-k6b) | product record | FIT (note) | identifier "to confirm" on main; fiddlybits-k6b sets DOI 10.5270/ESA-c5d3d65 and the handbook locators (issue 5.0 p.10; sec 2.1, Table 12) |
| H18 | lake-equilibrium-earth-oracle.md:17-20, 58-60 | the failing edge on the median, basis the predecessor's pre-registration (0.30, 0.60) | predecessor record /home/cfutro/git/vesper/hydrography/notes/lake-solver-validation.md | 2026-08-17 registration | NOT FIT C7 | decision 0025: "A FAIL bar is taken from a published model's own residual ... never from a number chosen to be reachable. Where no comparable published residual exists, the metric is REPORT"; a factor of two chosen before data is neither a published residual nor a physical constraint |
| H19 | lake-storage-closed-form-periodic.md:36, 85, 96 | a stiff reference integrator for the C3 oracle | hairer1996-solving-ordinary-differential-equations-ii.pdf (held) | RADAU5 | FIT | RADAU5 described (text pages 0019, 0021) |
| H20 | lake-tile-thermal-column.md:15-17 | lake energy balance against bare soil: several kelvin seasonally for large or deep lakes, and different evaporation | gmd-15-4275-2022.pdf, Bernus and Ottle 2022 (held) | sec 4, Fig. 10 | FIT | p.13 l.26-40 (printed p.4287): deep lakes cooler in spring by "5-6 and 3-4 C"; global evaporation "1.07 with lakes and 0.82 mm d-1 without lakes" |
| H21 | lake-tile-thermal-column.md:17-19 | salinity as a cause of lake-temperature error through albedo and evaporation | Bernus and Ottle 2022 (held) | discussion | FIT | p.16 l.20-24: three of the worst lakes "are saline lakes ... Salinity impacts surface albedo and evaporation" |
| H22 | lake-tile-thermal-column.md:40 | the gap-fraction form of forest snow masking | essery2013.pdf (held) | eq. for fg | FIT | p.2 l.6-9: "fg is the canopy gap fraction ... calculates the gap fraction as fg = exp(-...)" |
| H23 | subgrid-statistic-rule.md:27-29 | SIMTOP f_sat = f_sat_max exp(-f_grad z), f_sat_max the share whose index exceeds the cell mean | niu2005-simple-topmodel-runoff-parameterization-simtop.pdf (held) | eq. 11, sec 2 | FIT (note) | p.4 l.37: "Fmax is the percent of pixels in a grid cell ... whose topographic indexes are larger than or equal to the grid cell mean"; the record's AREA weighting is its own stated adaptation to unequal cells |
| H24 | subgrid-statistic-rule.md:35-36, 80-81 | f_grad bracket ends are "the two published conventions", differing by a factor of two | niu2005 (held) | p.4 | NOT FIT C5 | p.4 l.37: Cs = 0.5 is Niu 2005's; the Cs = 1.0 form is "used by Niu and Yang [2003]", whose paper is not cited or held; one bracket end rests on a secondhand citation |
| H25 | subgrid-statistic-rule.md:29-34, 106 | the topographic index and its cell mean | beven1979-physically-variable-contributing-area-model.pdf (held) | eq. 7-8 | FIT | p.8 l.27-33: lambda = (1/A) integral ln(a/tan beta) dA'; saturation where ln(a/tan beta) exceeds the threshold |
| H26 | subgrid-statistic-rule.md:17-18, 112 | Fan's exponential transmissivity, inadmissible at mesh spacing | fan_2007_incorporating-water-table-dynamics-in-climate-modeling-1-water-table-o.pdf (held) | eq. 7, Fig. 6d | FIT | p.9: K = K0 exp(-z'/f); p.11 eq. (7) f = a/(1 + b beta) |
| H27 | subgrid-statistic-rule.md:13-16, 123 | a convex or concave form carries a mean-state correction | jensen1906-sur-les-fonctions-convexes.pdf (held) | sec I | FIT (note) | p.1: "Des fonctions convexes et concaves"; the second-order expansion itself is Taylor's, not Jensen's, and needs no source |
| H28 | subgrid-statistic-rule.md:50, 117-119 | "GLWD v2" as existing support; reference given is Lehner and Doll (2004) | lehner2004-global-database-lakes-reservoirs-wetlands.pdf (held) | none | NOT FIT C4 | Lehner and Doll 2004 is GLWD-1 (its section 3.1 names GLWD-1); GLWD v2 is lehner_2025_mapping-the-world-s-inland-surface-waters-an-upgrade-to-the-global-lak.pdf, INDEX row "Mapping the world's inland surface waters: an upgrade to the Global Lakes and Wetlands Database (GLWD v2)", 10.5194/essd-17-2277-2025 (held) |
| H29 | subgrid-statistic-rule.md:50, 115 | Tootchi et al. 2019 as existing areal support | tootchi_2019_multi-source-global-wetland-maps (held) | title | FIT | a multi-source global wetland map, as the title states; no number taken |
| H30 | subgrid-statistic-rule.md:50, 121 | WAD2M as existing areal support | zhang_2021_development-of-the-global-dataset-of-wetland-area-and-dynamics (held) | title | FIT | the WAD2M dataset paper; no number taken |
| H31 | water-balance-decides-basin-fate.md:83, 125 | water roughness in Charnock's form with g explicit | charnock1955-wind-stress-on-a-water-surface.pdf (held) | p.639 | FIT | p.1 l.25-27: u/u* = (1/k) log(g z / u*^2) + constant, "approximate value of the constant is 12.5" |
| H32 | water-balance-decides-basin-fate.md:88-89, 119 | a combination (Penman-type) form with a psychrometric constant | penman1948-natural-evaporation-open-water-bare-soil-grass.pdf (held) | eq. 16 | FIT | p.7 l.35: E = (H Delta + E_a gamma)/(Delta + gamma); p.6 l.25 gamma the wet-and-dry-bulb constant |
| H33 | water-balance-decides-basin-fate.md:72, 99, 123 | Jensen error of a rectified nonlinear scheme evaluated on a mean | jensen1906 (held) | sec I | FIT | as H27; the inequality is exactly the use |
| H34 | water-table-complementarity-identities.md:15-18 | T = A exp(h/f), f reaching 0.95 m on steep bedrock | fan_2007 (held) | eq. 7, para 31 | FIT (note) | p.11 l.13: bedrock a = 20 m, b = 125, "f = 1 m at or above beta = 0.16"; 20/(1 + 125 x 0.16) = 0.95 m is the formula at the cap, which the paper rounds to 1 m |
| H35 | water-table-complementarity-identities.md:55-59, 101 | the dry-cell outflow failure of adjacent-head face conductance, upstream weighting prescribed | niswonger_2011_modflow-nwt-a-newton-formulation-for-modflow-2005.pdf (held) | UPW Package; Fig. 2 | FIT | p.14 l.20-26: UPW "differs from the approaches ... in which heads in two adjacent cells are used to calculate the intercell horizontal conductance"; p.17 Fig. 2 "Water flowing out of an active, yet dry cell" |
| H36 | water-table-complementarity-identities.md:11-13, 105 | box-constrained LCP with SPD matrix, unique solution | cottle2009-the-linear-complementarity-problem.pdf (held) | sec 3.3; Prop. 1.4.6 | FIT | p.56: "the class of matrices M for which (q, M) has a unique solution for all q ... defined and analyzed in Section 3.3"; SPD is in that class |
| H37 | water-table-skill-oracle.md:15-18, 77 | 24.56 m and 8.92 m are Fan et al. 2013's Australia-and-Asia residual figures under the worse forcing | fan_2013_supplementary-materials.pdf (read) | S3.5, Fig. S11 table | FIT | p.16 l.31-33: Australia and Asia, "Doll-Fiedler 8.92 m lower"; p.38 table: means -5.08, -8.92, st. dev. 20.85, 24.56 |
| H38 | water-table-skill-oracle.md:12-14, 100 | Gleeson 2011 class means (GLHYMPS Australian percentiles equal them) | gleeson_2011 (read) | Table 1 | FIT | printed p.3 Table 1 geometric means per class |

Excluded (no claim in the record rests on them): Braun and Willett 2013 (HYD-008, HYD-006; the
incision law is defined in decision 0015, not here); Barnes et al. 2014 (HYD-006); Fan et al. 2013
main paper (HYD-003); Barnes et al. 2021 (HYD-011); Mironov 2008, Hostetler and Bartlein 1990,
Subin et al. 2012 (HYD-010); Brutsaert 1982 (HYD-007); Gleeson et al. 2011 (HYD-004); Berghuijs et
al. 2022, ETOPO 2022, USGS NWIS (HYD-002: inputs of the predecessor's run); Messager et al. 2016 and
Lehner and Doll 2004 (HYD-009).

##### ocn

| # | where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | bathymetry-distribution-and-connectivity-graph.md:66-75, 110-116 | rotating hydraulic control of strait transport, width against the Rossby radius, the non-rotating limit | whitehead1998-topographic-control-oceanic-flows-deep.pdf (held) | sec 1-3, eqs. 12-13 | FIT | p.1 l.21: "critical control of a nonrotating fluid"; p.11 l.7: R = 4 km against an 80 km gap, "the rapidly rotating formula equation (12) is used"; p.12 l.7: R wider than L, "equation (13) is used" |
| O2 | bathymetry-distribution-and-connectivity-graph.md:55, 121 | partial bottom cells | adcroft1997-representation-topography-shaved-cells-height.pdf (held) | abstract | FIT | p.1 l.13-16: "shaved cells" and "partial step" representations |
| O3 | coupled-equilibrium-exit-axes.md:94-96 | "The Earth oracle for the transport partition and its uncertainty, the bar for a distance report" | trenberth2001-estimates-meridional-atmosphere-ocean-heat.pdf (held) | none | NOT FIT C7 | an observational estimate: p.1 l.60 "uncertainties in the atmospheric heat transports are substantial because of lack of observations over the oceans"; decision 0025 takes a FAIL bar from a published model's residual or a physical constraint, and cross-pass-forcing-trap.md:77-78 names a bar from published inter-model spread for the same metric |
| O4 | coupled-equilibrium-exit-axes.md:101, 103-105 | autocorrelation-corrected standard errors via the equivalent sample size | zwiers1995-taking-serial-correlation-account-tests.pdf (held) | abstract | FIT | p.1 l.15: "scale the t statistic by a factor that depends upon the equivalent sample size n_e" |
| O5 | coupled-equilibrium-exit-axes.md:106 | the same, von Storch and Zwiers 1999 | vonstorch1999-statistical-analysis-in-climate-research.pdf (held) | equivalent sample size | FIT | text pages 0126-0127: equivalent sample size |
| O6 | coupled-equilibrium-exit-axes.md:106 | the same, Sokal 1997 | sokal1997-monte-carlo-methods-statistical-mechanics.pdf (held) | integrated autocorrelation time | FIT | text pages 0007, 0013: integrated autocorrelation time |
| O7 | coupling-contract.md:12-23, 123-127 | the hand-over rule "taken from" Holden et al. 2016: temperature-dependent terms recomputed live, transfer coefficients and downward fields replayed, "evaporation is deliberately not recomputed, for moisture conservation, with rescaling precipitation and runoff considered and rejected" | holden_2016_plasimgenie-v1-0-a-new-intermediate-complexity-aogcm.pdf (held) | sec 3.1-3.3 | NOT FIT C2 | p.4 l.90-110: GOLDSTEIN SST prescribed to PLASIM's slab, fluxes computed in PLASIM (supports the live half); p.4 l.145-147: "PLASIM transfer coefficients are used in the calculation of sensible heat and sublimation", so the moisture flux over ice is recomputed; neither "evaporation deliberately not recomputed" nor rejected rescaling of precipitation and runoff appears |
| O8 | coupling-contract.md:71-81, 128 | classical bulk polynomials in wind speed at a reference height, and the fixed salinity reduction factor | large2009-global-climatology-interannually-varying-air-sea-flux.pdf (held) | eq. 4; Appendix Fig. 15 | FIT | p.4 l.13-15: q_sat = 0.98 ..., "the factor 0.98 applies only over sea-water"; p.22 Fig. 15: "neutral, 10 m transfer coefficients as a function of 10-m neutral wind speed" |
| O9 | coupling-contract.md:77, 140 | roughness length in gravity (Charnock) | charnock1955 (held) | p.639 | FIT | as H31 |
| O10 | crossing-acceptance-and-coastal-cells.md:100-103 | "Conservative remapping and its normalisation options" | jones1999-conservative-remapping-schemes-spherical-coordinates.pdf (held) | eqs. 8-10; sec 2f | NOT FIT C2 | printed p.2205 eqs. (8)-(10): weights normalised by the destination area A_k only; printed p.2207 sec 2f computes the participating fraction for masks; normalisation by covered area as an option, or as a property of the field, is not stated |
| O11 | crossing-acceptance-and-coastal-cells.md:104-107 | consistency and conservation are separate properties of a linear map | ullrich2015-arbitrary-order-conservative-consistent-remapping-i.pdf (held) | abstract; sec 1 | FIT | p.3 l.10: "accurate, conservative, consistent and monotone operators"; p.5 l.83: an approach conserving "led to a loss of consistency of the remapping operator" |
| O12 | crossing-acceptance-and-coastal-cells.md:108-111 | "Analytic fields on the sphere with known integrals" for the known-integral identity | williamson1992-standard-test-set-numerical-approximations.pdf (held) | none | NOT FIT C2 | p.8 l.3-7: a suite of shallow-water test cases with analytic solutions or reference runs; p.25 l.13: invariants normalised by their initial values; no field with an exact integral under a mesh's quadrature is given; the identity the record uses (3 sin^2(lat) - 1, low-order harmonics integrating to zero) is a mathematical identity |
| O13 | cross-pass-forcing-trap.md:79-82 | total transport set by the radiative constraint, the partition not | stone1978-constraints-dynamical-transports-energy-spherical-planet.pdf (held) | abstract | FIT | p.1 l.13: magnitude "determined primarily by the solar constant, the size of the earth, the tilt ... and the hemispheric mean albedo ... insensitive to the structure and dynamics of the atmosphere-ocean system" |
| O14 | cross-pass-forcing-trap.md:86-90 | "The geared coupling whose limit is the offline iteration" | holden_2016 (held) | none | NOT FIT C2 | p.4 l.113-116: a 45 min PLASIM step and a 12 h GOLDSTEIN step with inputs "averaged over the previous 16 PLASIM time steps", a synchronous coupling; no geared or asynchronous coupling or stored seasonal cycle appears (search for gear, asynchron, replay, seasonal cycle over the text returns none); the geared-coupling statement is the predecessor survey's section 59 |
| O15 | cross-pass-forcing-trap.md:18-22, 91-95 | an intermediate model's atmospheric transport is parameterised by amplitude, width, linear term and advection scalings | edwards2005-goldstein-transport-parameter-sensitivity.pdf (held) | sec 2, Table 1 | FIT | p.3 l.9-21: beta_T, beta_q "allow for a linear scaling of the advective transport term"; kappa_T "a simple exponential function with specified magnitude, slope and width"; p.5 parameter ranges |
| O16 | depth-to-pressure-through-declared-gravity.md:58-72, 111 | TEOS-10 saline part for the Reference Composition only, pure-water part separate | ioc2010-international-thermodynamic-equation-seawater-2010.pdf (held) | sec 2.4-2.6 | FIT | p.21 l.38-43: "For seawater of Reference Composition, Reference Salinity gives our current best estimate of Absolute Salinity ... When composition anomalies are present, no single measure ... can fully"; p.27 l.31-39 pure-water description IAPWS-95 and IAPWS-09 |
| O17 | depth-to-pressure-through-declared-gravity.md:58-61, 115 | a polynomial approximation to TEOS-10 with a declared validity domain and pressure ceiling | roquet2015-accurate-polynomial-expressions-density-specific.pdf (held) | sec 1; Fig. on p.3 | FIT | p.1 l.74: "accuracy over the whole oceanographic range of (SA, Theta, p) values"; p.3 figure pressure axis to 8000 dbar |
| O18 | depth-to-pressure-through-declared-gravity.md:119-124 | Zeebe and Wolf-Gladrow chapter 1 "carries the pressure dependence of the carbonate equilibrium constants" | zeebe2001-co2-in-seawater-chapter-1-equilibrium.pdf (held, chapter 1 only) | none | NOT FIT C5 | p.26 l.13 table footnote: "Pressure correction from Millero (1995)"; p.39 l.9: "Pressure correction after Millero (1995). See Appendix A.10 for formulas"; the formulas are in an appendix not held, and the primary is Millero 1995 |
| O19 | depth-to-pressure-through-declared-gravity.md:123-128 | Millero 1995 gives the pressure dependence directly | millero1995-thermodynamics-carbon-dioxide-system-oceans.pdf (held) | "Effect of Pressure on the Thermodynamic Constants", eq. 90 | FIT | p.15 l.161-185: ln(K_P/K_0) = -(Delta V/RT) P + (0.5 Delta kappa/RT) P^2, P in bars |
| O20 | depth-to-pressure-through-declared-gravity.md:65, 129-133 | the composition TEOS-10 is fitted to "and the anomaly tolerance the fence is stated against" | millero2008-composition-standard-seawater-reference-composition-salinity.pdf (held) | abstract; sec 7 | NOT FIT C2 | p.1 l.21-23 defines the Reference Composition and S_R "as a reference for natural seawater composition anomalies"; sec 7 (p.19-20) describes anomalies and a possible correction table; no tolerance is stated (search for tolerance returns none) |
| O21 | depth-to-pressure-through-declared-gravity.md:79-82, 134-137 | K1 and K2 "and their stated (S, T) domain" | lueker2000-ocean-pco2-calculated-dissolved-inorganic-carbon.pdf (held) | abstract; Table 1 | NOT FIT C2 | p.1 abstract: pK1, pK2 "as a function of seawater temperature and salinity", applicability stated only as fCO2 "up to 500 uatm"; printed p.108 Table 1 temperatures 2, 13, 25, 35 C and Fig. 1 salinities are the refitted data's span, not a stated domain |
| O22 | depth-to-pressure-through-declared-gravity.md:79-82, 138-141 | calcite and aragonite solubility and their stated domain | mucci1983-solubility-calcite-aragonite-seawater.pdf (held) | abstract | FIT | p.1 l.8: "over a wide range of salinity (5-44 per mil) and temperature (5-40) at 1 atm total pressure" |
| O23 | depth-to-pressure-through-declared-gravity.md:84-86, 142-144 | CO2 solubility in a reference-pressure form | weiss1974-carbon-dioxide-water-seawater-solubility.pdf (held) | eq. 2; Bunsen definition | FIT | p.3 l.5-9: P "the total pressure at the liquid-gas interface"; Bunsen coefficient "when the total pressure and the fugacity are both 1 atm" |
| O24 | marine-trait-community.md:13-15, 137 | ECOGEM's allometric coefficients are Earth laboratory-culture fits | ward2012-size-structured-food-web-model.pdf (held) | Table of allometric parameters | FIT | p.4 l.169 "allometric relationships defined by Hansen et al. (1997)"; p.5 l.132-137 sources Tang 1995 and Hansen et al. 1997, "typical experimental estimates" |
| O25 | marine-trait-community.md:87-91, 147 | per-band attenuation from pure-water, pigment and particle properties | morel2001-bio-optical-properties-oceanic-waters-reappraisal.pdf (held) | abstract | FIT | p.1 l.12: K_d(lambda) and R(lambda) modelled from [Chl] with "pure water absorption coefficients and particle scattering and absorption coefficients" |
| O26 | marine-trait-community.md:93-98, 150 | export as a size-dependent settling speed rather than an e-folding length | kriest2008-particulate-organic-matter-sinking-large-scale-models.pdf (held) | sec 2-3 | FIT (note) | p.3 l.89 and p.8 l.7-41: power-law size spectra and size-dependent sinking speed, density exponent zeta = 1.62 for marine snow; note: the gravity exponents (g^1 Stokes, g^0.5 to g^0.67 aggregates) in the record's body (l.39) are not in this source and carry no citation |
| O27 | open-water-albedo.md:53-55, 82 | Cox-Munk slope law fitted in wind speed at Earth air density and gravity | cox1954-roughness-sea-surface-sun-glitter.pdf (held) | abstract | FIT | p.1 l.13: "mean square slope ... increases linearly with the wind speed"; p.2 l.19 anemometers at 41 ft on the Reverie |
| O28 | open-water-albedo.md:53-55, 87 | Monahan whitecap power law in wind speed | monahan1980-optimal-power-law-oceanic-whitecap-coverage.pdf (held) | Fig. 2-3 | FIT | p.5 l.3: "fraction W ... versus the 10 m elevation wind speed U", optimal power-law W(U) |
| O29 | open-water-albedo.md:91-93, 235 | observational zenith and cloudiness dependence as an Earth oracle | payne1972-albedo-of-the-sea-surface.pdf (held) | abstract | FIT | p.1 l.11: albedo "expressed in terms of ... sun altitude and atmospheric transmittance (T)" |
| O30 | open-water-albedo.md:94-97, 202-211 | decomposition into direct, diffuse, foam and water-leaving terms | jin2004-parameterization-of-ocean-surface-albedo.pdf (held) | sec 2-3 | FIT | p.1 l.88-93 direct and diffuse albedo against SZA and chlorophyll; p.3 l.39-43 the empirical foam correction |
| O31 | open-water-albedo.md:98-100, 225-226 | pure-water absorption 380-700 nm | pope1997-absorption-spectrum-pure-water-ii.pdf (held) | abstract | FIT | p.1 l.5: "Definitive data on the absorption spectrum of pure water from 380 to 700 nm" |
| O32 | open-water-albedo.md:101-103, 217-220 | the water-leaving term as a function of pigment | morel2001 (held) | abstract | FIT | p.1 l.12: R(lambda) "predicted as a function of [Chl]" |
| O33 | rotation-never-fails-open.md:83-86 | Hadley cell width as a function of rotation rate; "the reason cell count is an outcome" | held1980-nonlinear-axially-symmetric-circulations.pdf (held) | sec 2, Fig. 2 | NOT FIT C2 | p.1 l.15: the theory "predicts the width of the Hadley cell" (width half supported; p.6 Fig. 2 R = gH Delta_H/(Omega^2 a^2), y_H = (5R/3)^(1/2)); an axisymmetric single-cell theory, it says nothing on the number of cells |
| O34 | scales-are-system-fields.md:85-88 | Edwards and Marsh 2005 as "the source of the non-dimensional formulation the finding was measured on" | edwards2005 (held) | none | NOT FIT C5 | p.2 l.74-75: the ocean model is that "used by Edwards and Shepherd (2002) ... for which the principal governing equations are given by Edwards et al. (1998)"; no non-dimensional scaling is stated in Edwards and Marsh 2005 |
| O35 | sea-ice-dynamics-class.md:96, 132 | Winton three-layer thermodynamics | winton2000-reformulated-three-layer-sea-ice.pdf (held) | sec 2, Table 1 | FIT (note) | the three-layer scheme; note Table 1 (p.3) uses a fixed seawater freezing temperature -1.8 C and p.3 l.109 "the ice conductivity is assumed to be constant", both of which the record replaces by its own rule |
| O36 | sea-ice-dynamics-class.md:82-86, 135 | lead-closing thickness of the Hibler law, the free-drift limit | hibler1979-dynamic-thermodynamic-sea-ice-model.pdf (held) | eq. 16; sec 5 | FIT | p.6 l.23-25: S_A with "h_0 a fixed demarcation thickness between thin and thick ice (0.5 m ...)"; p.20 l.11: negligible viscosity "yield[s] free drift conditions" |
| O37 | sea-ice-dynamics-class.md:32-36, 102-106, 142-145 | brine-volume dependence of density, heat capacity and conductivity | bitz1999-energy-conserving-thermodynamic-model-sea-ice.pdf (held) | sec 2 | FIT (note) | p.2 l.5-17 heat capacity from brine pockets; p.3 l.29-33 k = k_o + beta S/T, beta 0.117 "following Untersteiner [1964]" (the brine-conductivity fit's primary is Untersteiner 1964) |
| O38 | sea-ice-dynamics-class.md:96-98, 146-149 | freezing temperature as a function of salinity and pressure | ioc2010 (held) | sec 3.33 | FIT | freezing-temperature section 3.33 (text p.25 l.67; p.6 and p.15 contents) |
| O39 | sea-ice-dynamics-class.md:74-76, 150-152 | basal exchange in the ice-ocean friction velocity and the departure from freezing | mcphee1992-turbulent-heat-flux-upper-ocean-under-sea-ice.pdf (held) | abstract | FIT | p.1 l.7: "heat flux increases with both temperature elevation above freezing and with friction velocity at the interface" |
| O40 | sea-ice-dynamics-class.md:86-92, 153-156 | the lateral-melt fit with Arctic provenance and its floe-size argument | maykut1987-role-shortwave-radiation-summer-decay-sea-ice.pdf (held) | abstract; sec 4 | FIT | p.1 l.11: boundary-layer coefficients "obtained from field measurements in ... the Greenland Sea during the 1984 Marginal Ice Zone Experiment and ... Mould Bay"; p.9 l.25-27 lead perimeter and area-to-perimeter ratio |
| O41 | three-questions-and-marine-climate-pathways.md:34-37, 95-97 | pigment-dependent subsurface heating pathway | morel1994-heating-rate-upper-ocean-bio-optical-state.pdf (held) | abstract | FIT | p.1 l.11: heating "strongly influenced by the abundance of phytoplankton as depicted by the chlorophyll concentration" |
| O42 | three-questions-and-marine-climate-pathways.md:37-38, 98-100 | biogenic sulfur to cloud droplets pathway | charlson1987-oceanic-phytoplankton-atmospheric-sulphur-cloud-albedo.pdf (held) | abstract | FIT | p.1 l.11: CCN over oceans "appears to be dimethylsulphide, which is produced by planktonic algae" |
| O43 | three-questions-and-marine-climate-pathways.md:39-41, 101-103 | the ocean carbon pathway and element budgets | sarmiento2006-ocean-biogeochemical-dynamics.pdf (held) | "The Biological Pumps" | FIT | text page 0008 l.99 contents "The Biological Pumps"; a textbook used for a pathway, not for a number |

Excluded: Pratt and Whitehead 2008 (not held; the record says it does not rest on it), Adcroft
2013, Ringler et al. 2013 (REQ-OCN-009 precedents); Bryan 1984, Griffies et al. 2016 (REQ-OCN-005
background); Griffies et al. 2016 and Winton 2000 in REQ-OCN-004 (Winton counted in REQ-OCN-011);
Held 2001 (REQ-OCN-006); Follows et al. 2007, Ward et al. 2018, Litchman and Klausmeier 2008,
Redfield 1958 (REQ-OCN-008 framing); Vallis 2017 (REQ-OCN-001, REQ-OCN-002); Hunke and Dukowicz
1997 (REQ-OCN-011, a scheme the predecessor priced and this record does not adopt); Follows et al.
2007 (REQ-OCN-007).

#### Not-fit cases

##### H2. Stock and Montgomery's five orders mislabelled as the intact-rock range
- Where: docs/requirements/hyd/basin-fate-is-a-process.md:48-50 (REQ-HYD-008).
- Use: the contrast between the expressed erodibility contrast (Zondervan) and "the intact-rock range (five orders, Stock and Montgomery)".
- Source: Stock and Montgomery 1999, 10.1029/98JB02139, read.
- Category: C2.
- What is wrong: Stock and Montgomery's five orders are stream-power K values inferred from river profiles, which are themselves an expressed erodibility, not intact-rock strength. The intact-strength contrast that sits against Zondervan's factor of 4 is Zondervan's own two orders by UCS.
- Evidence: Stock 1999 p.10 l.17 (printed p.4991): K "would then vary over 5 orders of magnitude between mudstones and volcanoclastic rocks ... and granitoids and metasediments"; Zondervan 2020 p.11 Conclusions: "between a factor of 4 calculated through ksn and two orders of magnitude calculated through UCS".
- Fix class (a): text correction in REQ-HYD-008. Change it to "not the intact-strength contrast (two orders by UCS, Zondervan et al. 2020, Conclusions) nor the cross-region K range (five orders, Stock and Montgomery 1999, p. 4991)". Both sources are read. The file is not on an open branch. Whether decision 0015's k_e bracket repeats the mislabel belongs to the decisions scope.

##### H11. Shah et al.: transition depths quoted as extinction depths
- Where: docs/requirements/hyd/groundwater-sinks-baselevels-exchange.md:29, and 79-81 ("Shah et al.'s extinction depths are the reported Earth distance").
- Use: the range of extinction depths as a fact, and the extinction depths as the reported distance.
- Source: Shah, Nachabe, Ross 2007, 10.1111/j.1745-6584.2007.00302.x, held.
- Category: C2.
- What is wrong: 0.18 to 1.86 m is the range of the transition depth d', after which ET decays exponentially. The extinction depths are Table 1, 0.50 to 8.20 m, over twelve soils and three covers.
- Evidence: p.7 l.9 (printed p.335): "The transition depth ranged from 18 cm for bare sand to a maximum of 186 cm for clay with forested land cover"; Table 1 (printed p.334), "Extinction Depths for Different Soil Land Covers": sand bare soil 50 cm up to clay forest 820 cm.
- Fix class (b): correct the numbers in REQ-HYD-003. Mark Shah 2007 read in INDEX.md for Table 1 and the exponential form (p.335, Table 2), since the record takes both as the reported distance and the Sourced form. INDEX.md is on fiddlybits-k6b, so the index edit waits for it to merge.

##### H14. HydroLAKES does not supply long-term mean lake areas
- Where: docs/requirements/hyd/lake-equilibrium-earth-oracle.md:21, 69, 85 (REQ-HYD-001). This file is on fiddlybits-k6b.
- Use: the observation for the equilibrium relation, under the record's own rule "use long-term mean lake areas, never a single year".
- Source: Messager et al. 2016 (HydroLAKES v1.0), 10.1038/ncomms13603, held.
- Category: C3. The product cannot supply the quantity the rule requires.
- What is wrong: HydroLAKES polygons are a compilation of source maps and SRTM water bodies of mixed scale and epoch, with no temporal averaging. The rule and the named dataset disagree.
- Evidence: p.8 l.7 (Methods, "HydroLAKES polygon layer"): "compiling, correcting and unifying several near-global and regional data sets ... foremost the SRTM Water Body Data ... and CanVec"; l.11: "the resulting resolution ... cannot be strictly defined"; p.6 l.9: remote sensing data "mostly represent a snapshot of surface water on Earth at a given time".
- Fix class (b). Name a product with a stated temporal basis for lake area, for example a multi-temporal surface-water occurrence product, or GLWD v2, whose INDEX row says it "scores a long-term maximum extent" (maximum, not mean), and read it. Otherwise restate the rule as the product allows. This overlaps fiddlybits-k6b, whose notes already say the uncertainty of a long-term mean terminal-lake area is unquantified by any read source, and fiddlybits-hpp, which fetches HydroLAKES. It belongs with those rows. Changing the entry's dataset changes no registered bar, since the entry is unregistered.

##### H18. Terminal-lake median edge rests on a pre-registration, not a basis decision 0025 accepts
- Where: docs/requirements/hyd/lake-equilibrium-earth-oracle.md:17-20, 58-60 (main), and the same on fiddlybits-k6b ("its median edge is the pre-registered 0.30, a factor of two").
- Use: the failing edge on the median for earth.hydrolakes_terminal_lakes.
- Source: the predecessor's pre-registration of 2026-08-17 (/home/cfutro/git/vesper/hydrography/notes/lake-solver-validation.md).
- Category: C7.
- What is wrong: decision 0025 accepts a FAIL bar only from a published model's own residual or a physical constraint. Otherwise the metric is REPORT. A factor of two fixed before data is neither; the registry README's verdict table says the same.
- Evidence: docs/decisions/0025-three-oracle-tiers.md, Tier 2: "A FAIL bar is taken from a published model's own residual ... never from a number chosen to be reachable. Where no comparable published residual exists, the metric is REPORT."
- Fix class (d), USER DECISION. The user chose option (a), 0.30 on the pre-registration basis, on fiddlybits-k6b on 2026-09-14. That choice and decision 0025's bar-basis rule do not agree as written. Resolving it changes either the entry's verdict_kind or bar (unregistered) or decision 0025's basis.

##### H24. One f_grad bracket end is a secondhand citation
- Where: docs/requirements/hyd/subgrid-statistic-rule.md:35-36, 80-81 (REQ-HYD-005).
- Use: f_grad is Bracketed between "the two published conventions", which differ by a factor of two.
- Source: Niu et al. 2005, 10.1029/2005JD006111, held. The second convention is from Niu and Yang 2003, cited only through Niu 2005.
- Category: C5.
- What is wrong: Niu 2005 states its own Cs = 0.5 form and attributes the Cs = 1.0 form to Niu and Yang [2003]. That paper is neither in the references nor in INDEX.md.
- Evidence: Niu 2005 p.4 l.37: "without C_s (or C_s = 1.0), the F_max e^(-f z) curve, used by Niu and Yang [2003], underestimates the fractional saturated area"; reference list p.15: "Niu, G.-Y., and Z.-L. Yang (2003), The Versatile Integrator of Surface and Atmosphere processes (VISA) Part II: Evaluation of three topography-based runoff schemes, Global Planet. Change, 38, 191-208."
- Fix class (b): confirm the identifier, request the paper (Elsevier, likely paywalled), read it for the Cs = 1.0 form, and add it to REQ-HYD-005's references. Alternatively, argue the bracket end from Niu 2005's own statement that the Cs = 1.0 curve underestimates. Doing so moves that end's basis from a second published convention to Niu 2005's Figure 1b comparison, which changes a declared Bracketed argument. Raise it with the planner.

##### H28. GLWD v2 named, GLWD-1 cited
- Where: docs/requirements/hyd/subgrid-statistic-rule.md:50, 117-119 (REQ-HYD-005).
- Use: GLWD v2 named among the existing areal supports.
- Source cited: Lehner and Doll 2004, 10.1016/j.jhydrol.2004.03.028, held.
- Category: C4.
- What is wrong: Lehner and Doll 2004 is GLWD-1. GLWD v2 is Lehner et al. 2025, which is already indexed (held).
- Evidence: Lehner and Doll 2004 section 3.1 is the GLWD-1 validation (as read on fiddlybits-k6b). INDEX.md row: "Mapping the world's inland surface waters: an upgrade to the Global Lakes and Wetlands Database (GLWD v2)", 10.5194/essd-17-2277-2025, anchor "GLWD v2, 33 classes at 15 arcsec as percent of cell".
- Fix class (a): replace the Lehner and Doll 2004 reference in REQ-HYD-005 with Lehner et al. 2025. No number is taken from it. In the same edit, add a reference for GIEMS-MC, named at l.50 with no reference: INDEX.md holds "The GIEMS-MethaneCentric database: a dynamic and comprehensive global product of methane-emitting aquatic areas" (bernard_2025..., held).

##### O3. Trenberth and Caron 2001 named as the bar for a distance report
- Where: docs/requirements/ocn/coupled-equilibrium-exit-axes.md:94-96 (REQ-OCN-005).
- Use: "The Earth oracle for the transport partition and its uncertainty, the bar for a distance report."
- Source: Trenberth and Caron 2001, held, "DOI: to confirm".
- Category: C7.
- What is wrong: an observational estimate's uncertainty is named as the bar. Decision 0025 takes a FAIL bar from a published model's residual or a physical constraint, and otherwise the metric is REPORT. A sister record gives a different basis for the same metric: cross-pass-forcing-trap.md:77-78, "the Earth transport partition as a distance report with a bar from published inter-model spread". The two records disagree.
- Evidence: Trenberth and Caron 2001 p.1 l.60: "uncertainties in the atmospheric heat transports are substantial because of lack of observations over the oceans". Decision 0025 as quoted in H18.
- Fix class (b): restate REQ-OCN-005's parenthetical as the observation a REPORT distance is taken from, and make REQ-OCN-006 agree, in the files of this scope. Check the registry entry earth.meridional_heat_transport against the result in the registry scope. registry.toml is on open branches.

##### O7. Holden et al. 2016 credited with clauses it does not state
- Where: docs/requirements/ocn/coupling-contract.md:12-23 (REQ-OCN-004).
- Use: the hand-over rule "taken from a working synchronous coupling (Holden et al. 2016)", including "evaporation is deliberately not recomputed, for moisture conservation, with rescaling precipitation and runoff considered and rejected".
- Source: Holden et al. 2016, 10.5194/gmd-9-3347-2016, held.
- Category: C2.
- What is wrong: Holden supports the live half. PLASIM computes fluxes against the GOLDSTEIN SST it is handed, and the sea-ice surface fluxes are recomputed with PLASIM's transfer coefficients. But the sublimation (moisture) flux over ice is recomputed there too, and neither the non-recomputed evaporation nor the rejected rescaling appears. Those clauses are the predecessor's own declaration (transport_loop.yaml, which the record already names).
- Evidence: p.4 l.90-110: "prescribing the slab ocean with GOLDSTEIN distributions of sea surface temperature ... Surface wind stress, net energy and net moisture fluxes are supplied from PLASIM"; l.145-147: "PLASIM transfer coefficients are used in the calculation of sensible heat and sublimation during the Newton-Raphson step".
- Fix class (a): text correction in REQ-OCN-004. Attribute the live-recompute and replayed-coefficient rule to Holden et al. 2016 sec 3.1-3.3, and the evaporation and rescaling clauses to the predecessor's transport_loop.yaml. No new source needed.

##### O10. Jones 1999: "normalisation options" not stated
- Where: docs/requirements/ocn/crossing-acceptance-and-coastal-cells.md:100-103 (REQ-OCN-010).
- Use: "Conservative remapping and its normalisation options."
- Source: Jones 1999, held, "DOI: to confirm".
- Category: C2.
- What is wrong: the paper normalises its weights by the destination cell area and computes a participating fraction for mask conflicts. It presents neither normalisation by covered area as an option nor normalisation as a property of the field. The record's rule (destination area for a total, covered area for a density) is the predecessor contract, section 5c.
- Evidence: printed p.2205 eqs. (8)-(10), w_1nk = (1/A_k) integral over A_nk of dA; printed p.2207 sec 2f, "the fraction of a grid cell participating in a remapping is also computed".
- Fix class (a): narrow the parenthetical to "first- and second-order conservative remapping weights (eqs. 8-10) and the participating fraction (sec 2f)", leaving the normalisation rule with the contract the record cites.

##### O12. Williamson et al. 1992 does not give fields with known integrals
- Where: docs/requirements/ocn/crossing-acceptance-and-coastal-cells.md:108-111 (REQ-OCN-010).
- Use: "Analytic fields on the sphere with known integrals", the basis of the known-integral identity.
- Source: Williamson et al. 1992, held.
- Category: C2.
- What is wrong: the paper is a shallow-water test suite with analytic solutions or reference solutions, and invariants normalised by initial values. It gives no field whose exact integral under a mesh's quadrature is known. The identity the record uses, low-order spherical harmonics such as 3 sin^2(lat) - 1 integrating to zero, is a mathematical identity and needs no citation.
- Evidence: p.8 l.3-7, "a suite of seven test cases ... Several analytic treatments included"; p.25 l.13, "normalized global invariants".
- Fix class (a): drop the parenthetical's claim, or restate Williamson 1992 as analytic test fields for operator checks. State the harmonic integral as an identity.

##### O14. Holden et al. 2016 is not a geared coupling
- Where: docs/requirements/ocn/cross-pass-forcing-trap.md:86-90 (REQ-OCN-006).
- Use: "The geared coupling whose limit is the offline iteration."
- Source: Holden et al. 2016, held.
- Category: C2.
- What is wrong: Holden describes a synchronous coupling, a 45-minute atmosphere step and a 12-hour ocean step, with inputs averaged over the previous 16 atmosphere steps. It has no gearing, no asynchronous segments and no stored seasonal cycle. The geared-coupling statement is the predecessor survey's section 59, already cited in the body.
- Evidence: p.4 l.113-116, "a PLASIM time step of 45 min and a GOLDSTEIN time step of 12 h, with coupling inputs averaged over the previous 16 PLASIM time steps". Searching the whole text for gear, asynchron, replay and seasonal cycle returns nothing.
- Fix class (a): replace the parenthetical with "a synchronous coupling with differential time stepping (sec 3.2)", or remove Holden from this record's references.

##### O18. Zeebe and Wolf-Gladrow chapter 1 defers the pressure dependence
- Where: docs/requirements/ocn/depth-to-pressure-through-declared-gravity.md:119-124 (REQ-OCN-003).
- Use: chapter 1 "carries the pressure dependence of the carbonate equilibrium constants".
- Source: Zeebe and Wolf-Gladrow 2001, chapter 1 only, held.
- Category: C5. A textbook chapter is cited where the primary it defers to is held.
- What is wrong: chapter 1's tables take the pressure correction from Millero (1995) and point to Appendix A.10 for the formulas, which is not held.
- Evidence: p.26 l.13 footnote, "Pressure correction from Millero (1995)"; p.39 l.9, "Pressure correction after Millero (1995). See Appendix A.10 for formulas"; Millero 1995 p.15, "Effect of Pressure on the Thermodynamic Constants", eq. (90).
- Fix class (a): cite Millero 1995 eq. (90) and its Delta V and Delta kappa fits as the pressure dependence, and keep Zeebe chapter 1 only for the 1-atm constants. Millero 1995 is held; the record already says it "gives the same pressure dependence directly". Mark it read in INDEX.md when a value is taken from it (INDEX.md is on fiddlybits-k6b).

##### O20. Millero et al. 2008 states no anomaly tolerance
- Where: docs/requirements/ocn/depth-to-pressure-through-declared-gravity.md:65, 129-133 (REQ-OCN-003).
- Use: "The composition TEOS-10 is fitted to and the anomaly tolerance the fence is stated against."
- Source: Millero et al. 2008, 10.1016/j.dsr.2007.10.001, held.
- Category: C2 (half the use).
- What is wrong: the paper defines the Reference Composition and S_R, and discusses local composition anomalies and a possible correction table. It states no tolerance. The fence the record requires, Irreducible inside and refused beyond, has a tolerance with no cited basis.
- Evidence: p.1 l.21-23 (abstract), S_R "as a reference for natural seawater composition anomalies"; sec 7, "Local anomalies of seawater composition" (p.19-20); a search for tolerance returns nothing.
- Fix class (b): narrow the parenthetical to the Reference Composition, and source the tolerance where it is declared (decision 0017 or 0022 on the seawater-properties door, in the decisions scope), for example from IOC 2010 section 2.5. If no read source gives one, it becomes Bracketed, which may change a declared disposition. Raise it with the planner.

##### O21. Lueker et al. 2000 states no (S, T) domain
- Where: docs/requirements/ocn/depth-to-pressure-through-declared-gravity.md:79-82, 134-137 (REQ-OCN-003).
- Use: "The dissociation constants and their stated (S, T) domain."
- Source: Lueker et al. 2000, 10.1016/S0304-4203(00)00022-0, held.
- Category: C2.
- What is wrong: the paper refits Mehrbach et al. (1973) and states applicability only in fCO2 (up to 500 uatm). The (S, T) span is implicit in the refitted data, not stated as a validity domain.
- Evidence: abstract p.1, "as a function of seawater temperature and salinity", fCO2 values that "agree ... up to 500 uatm"; printed p.108 Table 1, fit temperatures 2.00, 13.00, 25.00 and 35.00 C; Fig. 1 salinity axis.
- Fix class (a): restate as "the (S, T) span of the Mehrbach et al. data it refits (Table 1, Fig. 1)", declared as the domain by this record rather than stated by the source.

##### O33. Held and Hou 1980: width supported, cell count not
- Where: docs/requirements/ocn/rotation-never-fails-open.md:83-86 (REQ-OCN-002).
- Use: "Hadley cell width as a function of rotation rate; the reason cell count is an outcome."
- Source: Held and Hou 1980, held, "DOI: to confirm".
- Category: C2 (half the use).
- What is wrong: this axisymmetric theory predicts the width of one Hadley cell in terms of rotation. It says nothing about how many cells form.
- Evidence: p.1 l.15, "The theory predicts the width of the Hadley cell"; p.6 Fig. 2, R = gH Delta_H/(Omega^2 a^2) against y_H, with (5R/3)^(1/2).
- Fix class (a): narrow the parenthetical to the width. The rule "no structural assumption about the number of cells" needs no source to forbid an assumption.

##### O34. Edwards and Marsh 2005 is not where the non-dimensional formulation is given
- Where: docs/requirements/ocn/scales-are-system-fields.md:85-88 (REQ-OCN-001).
- Use: "The source of the non-dimensional formulation the finding was measured on."
- Source: Edwards and Marsh 2005, 10.1007/s00382-004-0508-8, held.
- Category: C5.
- What is wrong: Edwards and Marsh 2005 describes the model version and its parameter sensitivity, and defers the governing equations to earlier papers.
- Evidence: p.2 l.74-75, the ocean model "used by Edwards and Shepherd (2002) ... for which the principal governing equations are given by Edwards et al. (1998)". Reference list p.18: "Edwards NR, Willmott AJ, Killworth PD (1998) On the role of topography and wind stress on the stability of the thermohaline circulation. J Phys Oceanogr 28:756-778".
- Fix class (a) or (b). (a): restate the parenthetical as "the model version the finding was measured on". (b): if the non-dimensional scales are ever cited, identify and read Edwards, Willmott and Killworth (1998), which is not in INDEX.md.

#### Observations, not counted as citations

- REQ-HYD-002 (water-table-skill-oracle.md:75-79) sets its FAIL bars as a no-skill baseline: residual sd at or above observed sd, and R^2 below the free-geography baseline computed in the same run. It keeps Fan et al. 2013's residuals as REPORT. That is neither a published residual nor a physical constraint in decision 0025's words, though the first clause is close to an identity (a constant predictor's residual sd equals the observed sd). It belongs to the registry scope, entry earth.fan_water_table.
- REQ-OCN-008 body l.39: the settling-regime gravity exponents (g^1 Stokes, g^0.5 to g^0.67 aggregates) carry no citation. They are Bracketed ends, so they need mechanisms rather than a locator, but none is named.
- REQ-HYD-005 l.50: GIEMS-MC is named with no reference (see H28).
- Several "DOI: to confirm" identifiers remain in these records (Zondervan 2020, Trenberth and Caron 2001, Jones 1999, Held and Hou 1980, Monahan 1980, Payne 1972, Jin 2004, Morel and Antoine 1994, Bryan 1984, Held 2001, Adcroft 1997, WAD2M, Berghuijs 2022, ETOPO 2022). This is identifier hygiene, not fitness.
- fiddlybits-k6b's diff to lake-equilibrium-earth-oracle.md already makes three changes:
  - splits the oracle into earth.hydrolakes_terminal_lakes and earth.copernicus_dem_spill_cap, each stating its edge basis;
  - fixes the Copernicus DEM DOI and adds the handbook locators;
  - adds Lehner and Doll 2004, section 3.1, as a reference.

  It does not touch H14 (long-term mean areas from HydroLAKES) or H18 (the C7 conflict of the pre-registered edge).

#### Fetch failures and paywalled sources

No fetch was attempted. Every source judged was on disk. Sources needed for fixes but not held:
- "The Versatile Integrator of Surface and Atmosphere processes (VISA) Part II: Evaluation of three topography-based runoff schemes", Niu and Yang (2003), Global Planetary Change 38, 191-208. Identifier as given in Niu et al. 2005's reference list; no DOI confirmed. Elsevier, likely paywalled.
- "On the role of topography and wind stress on the stability of the thermohaline circulation", Edwards, Willmott, Killworth (1998), Journal of Physical Oceanography 28, 756-778. No DOI confirmed; confirm before requesting. Needed only if fix O34 takes route (b).

### Q4: Requirements, num, prov, sys and proc


Audited on the worktree at 625832c (fiddlybits-9j0). Read-only. No file in this scope is
edited by an open branch (the only requirement file an open branch edits is
docs/requirements/hyd/lake-equilibrium-earth-oracle.md, on fiddlybits-k6b).

What was counted: every entry of a record's References list that is a source (published
or predecessor), every old_path entry (the basis of "What is true"), and every inline
citation of a named source or predecessor finding that a number or rule rests on; one
row per source per record. Not counted: "Plan decisions ..." and "Related: REQ-..."
pointers, and the Clausius-Clapeyron style physics stated without a citation.
Predecessor sources were checked for existence at the path given, the named section,
and a distinctive number of the record located in the cited set. Published sources were
opened in references/text (PDF page index p.NNNN) and the passage matched to the use.

#### Counts

| scope | citations | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| num (8 records) | 50 (31 published, 19 predecessor) | 47 | 0 | 3 |
| prov (3 records) | 19 (9 published, 10 predecessor) | 18 | 1 | 0 |
| sys (13 records) | 63 (29 published, 34 predecessor) | 59 | 4 | 0 |
| proc (11 records) | 33 (2 published, 31 predecessor) | 32 | 1 | 0 |
| README.md, not-carried.md | 0 (no sourced rule; not-carried.md records dispositions, and its Stephens (1978) mention is context for a not-carried decision) | 0 | 0 | 0 |
| total | 165 | 156 | 6 | 3 |

#### Every citation

Verdict key: FIT; NF-Cn (not fit, category n); NV (not verified). "pred" = predecessor
archive /home/cfutro/git/vesper. Status = docs/references/INDEX.md status.

##### num/boundary-arithmetic-guarded-at-definition.md (REQ-NUM-003): 5

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | masked-lane faults, 56 intrinsics, 345 divisions, 53 locals | pred notes/audits/masked-where-blocks.md | whole | FIT | exists; "345" and "53 automatics" at :222, :237 |
| :4 old_path | uninitialised reads, NaN poison gate | pred notes/audits/uninitialised-reads-and-implicit-save.md | whole | FIT | exists; SAVEd locals and never-assigned locals at :104, :146 |
| :92 | trap/NaN semantics behind items 1-3 | IEEE 754-2019, 10.1109/IEEESTD.2019.8766229 (read) | none | FIT | p.0035 invalid operation signalled for signaling NaN operands; p.0025 signaling vs quiet NaN. Note: INDEX read anchor names only clause 5.4.1 (decision 0044), not these clauses |
| :93 | floating-point exceptions background | Goldberg 1991, 10.1145/103162.103163 (held) | none | FIT | p.0001 key words: exception, NaN, rounding error, ulps |
| :94 | traps and exceptional values | Muller et al. 2018 handbook (held) | none | FIT | p.0044 "A trap is a transfer of control to a special handler routine"; beside the primary IEEE 754 |

##### num/checks-can-fail-and-forward-full-configuration.md (REQ-NUM-008): 3

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | three check shapes, clay bias +0.062 to +0.004 | pred notes/audits/checks-that-forward-too-few-arguments.md | whole | FIT | exists; "0.062" located |
| :69 | item 2, every check has a mutation it catches | DeMillo et al. 1978, 10.1109/C-M.1978.218136 (held) | none | FIT | p.0007 "The coupling effect shows itself in two ways" |
| :70 | mutation testing method | Jia and Harman 2011, 10.1109/TSE.2010.62 (held) | none | FIT | survey of mutation testing (p.0002); beside the primary DeMillo 1978 |

##### num/closure-tolerance-from-floating-point.md (REQ-NUM-004): 4

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | 99.885 per cent inside quantisation bound, lag-1 -0.40 | pred notes/audits/closure-tolerance-under-written-precision.md | whole | FIT | exists; "99.885" located |
| :74 | item 2, tolerance from a summation error bound | Higham 1993, 10.1137/0914050 (read) | none | FIT | p.0002-0004 recursive summation bound (2.6)/(2.8); INDEX read for that bound |
| :75 | compensated summation accumulators | Kahan 1965, 10.1145/363707.363723 (held) | none | FIT | p.0001 "cascaded accumulators to evaluate a sum ... when N is large" |
| :76 | floating-point background | Goldberg 1991 (held) | none | FIT | p.0001 rounding error in ulps and relative error |

##### num/cost-measured-with-known-scatter.md (REQ-NUM-006): 4

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | postprocessor 304 s of 385 s | pred notes/audits/pyburn-postprocessing-cost.md | whole | FIT | exists; "304" located |
| :4 old_path | flag verdicts, 5 to 21 per cent contamination | pred notes/audits/model-build-flags.md | whole | FIT | exists; per-cent scatter figures located |
| :82 | item 1, measurement bias needs paired interleaved arms | Mytkowicz et al. 2009, 10.1145/1508244.1508275 (held) | none | FIT | p.0001 "This phenomenon is called measurement bias ... significant and commonplace" |
| :83 | item 1, scatter and intervals reported | Hoefler and Belli 2015, 10.1145/2807591.2807644 (held) | none | FIT | p.0006 "present a single value with a confidence interval" |

##### num/dead-code-measured-and-removed.md (REQ-NUM-007): 4

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | 167 of 368 keys with no writer | pred notes/audits/dead-code-and-unreachable-paths.md | whole | FIT | exists; "167" located |
| :70 | item 6, mutation run reports uncovered code | DeMillo et al. 1978 (held) | none | FIT | as above |
| :71 | same | Jia and Harman 2011 (held) | none | FIT | as above |
| :72 | item 1, coverage job | Ivankovic et al. 2019 (held) | "DOI: to confirm" | FIT | p.0009 "Code Coverage at Google". Hygiene: INDEX carries 10.1145/3338906.3340459 |

##### num/precision-is-a-type-parameter.md (REQ-NUM-001): 8

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | stagnation thresholds 1.16 W/m2, 0.077 K arm difference | pred notes/audits/single-precision-spin-up.md | whole | FIT | exists; "1.16" and "0.077 K" (:174) located |
| :4 old_path | precision flag fall-through | pred notes/audits/compiled-precision.md | whole | FIT | exists (the flag narrative; the sigma figures sit in the sibling old_path above) |
| :97 | stagnation below half an ulp (round to nearest) | IEEE 754-2019 (read) | none | FIT | p.0028 "roundTiesToEven, the floating-point number nearest to the infinitely precise result". INDEX read anchor names clause 5.4.1 only |
| :98 | ulp background | Goldberg 1991 (held) | none | FIT | p.0001 ulps |
| :99 | item 2, Float64 accumulators / summation error | Higham 1993 (read) | none | FIT | as above |
| :100 | item 2, compensated summation | Kahan 1965 (held) | none | FIT | as above |
| :101 | item 5, autocorrelation-corrected standard error | Madras and Sokal 1988, 10.1007/BF01022990 (requested) | section 2.2 | NV | not on disk; Unpaywall is_oa false (paywalled). INDEX row: old project declared it unavailable |
| :102 | item 5, chaotic arms decorrelate, only climate compared | Lorenz 1963 (held) | none | FIT | p.0002 deterministic nonperiodic flow of forced dissipative systems |

##### num/resolution-ladder-three-quantities.md (REQ-NUM-005): 11

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | -1.59 K step halving, three timesteps | pred notes/audits/resolution-ladder.md | whole | FIT | exists; "1.59" located |
| :4 old_path | route cost 28x | pred notes/audits/resolution-ladder-wall-clock.md | whole | FIT | exists; "28" and "22.5" located |
| :4 old_path | resolution divergence, silent resolution dependence | pred notes/audits/resolution-divergence.md | whole | FIT | exists (the 22.5 per cent ice figure is in the sibling wall-clock audit, same old_path) |
| :45 | run length as a floor | pred lib/run_lengths.py | module | FIT | exists |
| :46 | integrated autocorrelation time | pred lib/autocorrelation.py | module | FIT | exists |
| :122 | item 1, stability ceiling from the scheme's bound | Courant, Friedrichs, Lewy 1928 (held) | none | FIT | p.0002 convergence of difference schemes depends on the grid for hyperbolic initial-value problems |
| :123 | items 2 and 5, convergence verification across levels | Roache 1998, 10.2514/2.457 (held) | none | FIT | p.0003 "discretization errors in a grid convergence test" |
| :124 | grid refinement reporting | Roache 1994, "Perspective: A Method for Uniform Reporting of Grid Refinement Studies" (not in INDEX) | "DOI: to confirm" | NV | not held, not in INDEX or REQUESTS; DOI 10.1115/1.2910291 (Unpaywall is_oa false, paywalled) |
| :125 | item 6, initial monotone sequence estimator | Geyer 1992, 10.1214/ss/1177011137 (held) | none | FIT | p.0005 "The initial monotone sequence estimator ... reducing the estimated Gamma_i to the minimum of the preceding ones" |
| :126 | item 6, corrected standard error | Madras and Sokal 1988 (requested) | none | NV | as above |
| :127 | item 6, equivalent sample size | von Storch and Zwiers 1999 (held) | none | FIT | p.0125 "The equivalent sample size n'X is defined as ..."; textbook beside the primaries Geyer and Madras-Sokal |

##### num/thread-invariance-and-backend-agreement.md (REQ-NUM-002): 11

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | 83 of 199 records, 3.7e-10 | pred notes/audits/model-reproducibility.md | whole | FIT | exists; "3.7" located |
| :4 old_path | 66 static locals, seven of eight threads | pred notes/audits/implicit-save-under-threads.md | whole | FIT | exists; "66" located |
| :4 old_path | 928 write sites, thirteen reachable | pred notes/audits/shared-diagnostics-unit-under-threads.md | whole | FIT | exists; "928" located |
| :39 | streams keyed on physical identity | pred lib/stochastic_seeds.py | module | FIT | exists |
| :43 | 60 of 64 rows corrupted | pred notes/audits/nlowio-collective-deadlock.md | whole | FIT | exists |
| :98 | item 5, counter-based generator | Salmon et al. 2011, 10.1145/2063384.2063405 (held) | none | FIT | p.0010 "Counter-based PRNGs easily accomodate seeds" |
| :99 | item 6, ensemble-derived tolerance | Baker et al. 2015, 10.5194/gmd-8-2829-2015 (held) | none | FIT | p.0004 ensemble from "random perturbation of the initial atmospheric temperature field of O(10^-14)" |
| :100 | item 1, partition-independent summation | Demmel and Nguyen 2013 (held) | "DOI: to confirm" | FIT | p.0001 reproducible summation. Hygiene: INDEX 10.1109/ARITH.2013.9 |
| :101 | item 6, bit-reproducible portable code | Arteaga et al. 2014 (held) | "DOI: to confirm" | FIT | p.0003 "portable reproducible functions". Hygiene: INDEX 10.1109/IPDPS.2014.127 |
| :102 | item 1, fixed-order reductions | Higham 1993 (read) | none | FIT | as above |
| :103 | round-off grows per run in a chaotic flow | Lorenz 1963 (held) | none | FIT | as above |

##### prov/artifacts-write-once-outside-the-checkout.md (REQ-PROV-003): 5

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | thirteen PDFs, 21 files, 84 worktrees | pred notes/audits/worktree-stranded-payload.md | whole | FIT | exists; counts located |
| :4 old_path | 594 files, 11.6 GB | pred notes/audits/worktree-write-through.md | whole | FIT | exists; "11.6" located |
| :74 | content-addressed keys | FIPS PUB 180-4, 10.6028/NIST.FIPS.180-4 (held) | none | FIT | p.0007 SHA-256, section 6.2 |
| :75 | hash trees under content addressing | Merkle 1988 (held) | "DOI: to confirm" | FIT | p.0005 "an infinite tree of one-time signatures". Hygiene: INDEX 10.1007/3-540-48184-2_32 |
| :76 | store format | Zarr v3 core specification (held, html) | URL | FIT | references/pdf/zarr-v3-core-specification.html carries attributes and chunk key definitions |

##### prov/restart-bitwise-state-only-refuses-on-moved-input.md (REQ-PROV-001): 6

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | leapfrog level overwritten on restart | pred notes/audits/absent-restart-records.md | whole | FIT | exists |
| :4 old_path | 1.19 K, 1341 Pa, 60 of 222 records | pred notes/audits/ecological-stream-restart-continuity.md | whole | FIT | exists; "1341" located here |
| :4 old_path | 8192 values of which 8190 buffer | pred notes/audits/zsolars-restart-overread.md | whole | FIT | exists; "8192" located |
| :94 | (no rule of the record named) | Baker et al. 2015 (held) | none | NF-C2 | see N6 |
| :95 | checkpoint key composition | FIPS PUB 180-4 (held) | none | FIT | as above |
| :96 | self-describing arrays | Zarr v3 (held) | URL | FIT | as above |

##### prov/run-identity-content-addressed-append-only.md (REQ-PROV-002): 8

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | forty unrecorded run ids, 297.8 GB | pred notes/audits/run-identity.md | whole | FIT | exists; "297.8" located |
| :4 old_path | sixteen of sixty cells re-derived | pred notes/audits/executable-provenance-at-the-consumer.md | whole | FIT | exists; "sixty" located |
| :4 old_path | resolution 170 built the coarsest rung | pred notes/audits/model-build-driver.md | whole | FIT | exists; "170" located |
| :45 | provenance lessons | pred lib/provenance.py | module | FIT | exists |
| :46 | builds reference | pred docs/src/reference/builds.md | whole | FIT | exists |
| :100 | artifact key hash | FIPS PUB 180-4 (held) | none | FIT | as above |
| :101 | item 3, tree hash of the loaded package | Merkle 1988 (held) | "DOI: to confirm" | FIT | as above; same hygiene |
| :102 | artifact format | Zarr v3 (held) | URL | FIT | as above |

##### sys/closure-scales-with-spacing-no-grid-unit-thresholds.md (REQ-SYS-104): 5

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | storm diagnostic 30 cells, 256 steps | pred notes/audits/dormant-exoplasim-modules.md | sections 2, 3 | FIT | exists; "256" located |
| :26 | rcrit 0.85, 1/(1-rcrit)^2 = 44 | pred notes/audits/model-earth-centrism.md finding 8 | finding 8 | FIT | :490-494 `rcrit(:)=MAX(0.85,...)`, a function of grid-box area |
| :33 | re-evaporation 43 per cent step | pred notes/audits/opaque-constants.md finding 13 | finding 13 | FIT | exists |
| :97 | the critical-humidity form encodes sub-grid variance | Sundqvist 1978, 10.1002/qj.49710444110 (held) | "(to confirm)" | FIT | p.0002 "A threshold relative humidity at which condensation starts is considered, hence allowing for sub-grid-scale cloud cover"; eq. (8) U = (1-a)U_s + aU_0 p.0003. Hygiene: DOI confirmed in INDEX |
| :101 | sub-grid diffusivity as a law in grid spacing and strain | Smagorinsky 1963 (held) | "(to confirm)" | FIT | p.0007 eq. (4.22) lateral stresses (k_H Delta)^2 m^3 ... with |D| of (4.23)-(4.24), k_H about 0.28. Hygiene: DOI confirmed in INDEX |

##### sys/constants-have-five-dispositions.md (REQ-SYS-001): 10

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :120 | nineteen rows, 14.6 K, 1.699x | pred notes/audits/tuned-values.md | whole | FIT | exists; "14.6" located; "The five papers" section at :1534 |
| :121 | the no-tuned-values rule | pred docs/src/practice/conventions.md "No tuned values" | section | FIT | heading at :26 |
| :122 | tuned / opaque / implicit-Earth | pred docs/src/reference/vocabulary.md | entries | FIT | :166, :183 |
| :50 | roughness derived from slope | Mason 1988, 10.1002/qj.49711448007 (read) | inline | FIT | p.0001 area-average z0 is the one that gives the correct mean stress; p.0004 blending height eq. (14) |
| :123 | "a scheme chosen for one fewer unconstrained coefficient" | Kok et al. 2014, 10.5194/acp-14-13023-2014 (read) | none | NF-C5 | see N4 |
| :124, :54 | re-evaporation into a form P^0.578, g^-0.289 | Kessler 1969, 10.1007/978-1-935704-36-2 (read) | none | NF-C2 (partial) | see N3 |
| :125 | a fitted set that does not transfer on its authority | Louis 1979, 10.1007/BF00117978 (held) | none | FIT | p.0006 "Hence we chose b = 2b' = 9.4" |
| :126 | a scaling that transfers where the value does not | Blackadar 1962 (read) | none | FIT | p.0005 eq. (25) lambda = 0.00027 G/f |
| :127 | orographic drag from slope | Wood and Mason 1993 (read) | none | FIT | p.0027 eq. (33) effective roughness from C_a |
| :128 | same | Beljaars, Brown and Wood 2004 (read) | none | FIT | INDEX read row eq. 6 Ca = 2 alpha beta Cmd theta^2; p.0002 turbulent orographic form drag |

##### sys/declared-value-status-decays-with-its-artifact.md (REQ-SYS-003): 1

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :75 | four atomic statuses, decay rule | pred config/planet.yaml | header lines 1-31 | FIT | header lines 6-31 state DETERMINED, DECLARED, PROVISIONAL, DERIVED and "it decays in one direction only" |

##### sys/dependency-graph-is-complete-and-measured.md (REQ-SYS-008): 2

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :64 | missing loop edge, 64 per cent understated literal | pred notes/audits/pipeline-bookkeeping.md | whole | FIT | exists; "64" located |
| :65 | a marker names a location, not an effect | pred docs/src/practice/conventions.md "The issue tracker" | section | FIT | heading at :169 |

##### sys/derived-quantities-have-a-path-back.md (REQ-SYS-002): 3

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :107 | sixty-four instances, 202.0 vs 159.7 | pred notes/audits/frozen-derived-quantities.md | whole | FIT | exists; "159.7" located |
| :108 | "The corollary: a field update has to be able to carry" | pred docs/src/pipeline/loops.md | section | FIT | heading at :254 |
| :109 | four modules computing at call time | pred lib/sensitivity.py, lapse.py, stellar.py, orbit.py | docstrings | FIT | all exist |

##### sys/dormant-parameterisations-are-armed-explicitly.md (REQ-SYS-004): 2

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :68 | inert knobs, 1.583/1.178/0.8548/0.8878 | pred notes/audits/tuned-values.md sections 18, 19 | sections | FIT | sections at :1251, :1313; "1.583" located |
| :69 | "A tuning that no run reaches is a trap" | pred docs/src/practice/conventions.md | bold paragraph | FIT | :61 |

##### sys/earth-calibrated-schemes-re-derive-what-was-held-fixed.md (REQ-SYS-005): 11

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :123 | five findings, weight 1.346 | pred notes/audits/physics-review.md | whole | FIT | exists; "1.346" located |
| :124 | the reference-level pair | pred notes/audits/missed-couplings.md finding 2 | finding 2 | FIT | heading at :83 |
| :125 | identity 0.517 and the grid defect | pred lib/stellar.py | docstring | FIT | :35 "The two checks that can fail"; :76 SOLAR_PARTITION = 0.517 |
| :126, :21 | absorptances are fractions of total incident solar flux | Lacis and Hansen 1974 (held) | none | FIT | p.0006 "the fraction of the total solar flux absorbed in the l th layer"; p.0009 eq. (21) "fits Yamamoto's absorption curve within <~1%" |
| :127, :26 | Yamamoto weighted the laboratory absorptions with the solar flux | Yamamoto 1962 (held) | none | FIT | p.0001 abstract "Based mainly on Howard, Burch and Williams' laboratory absorption data"; Lacis p.0009 "Yamamoto (1962) weighted these absorptivities with the solar flux and summed them" |
| :128, :25 | laboratory band absorptions | Howard, Burch and Williams 1956, JOSA 46 242 (held) | none | FIT | p.0004 empirical relations for absorption by water vapor; Lacis cites "Howard, J. N., D. E. Burch and D. Williams, 1956 ... Parts I-V, J. Opt. Soc. Amer., 46" (p.0016). Yamamoto himself cites the 1955 AFCRC report of the same measurements (p.0007) |
| :129 | ozone re-weighted for the declared star | Segura et al. 2003 (held, identifier unverified) | "DOI: to confirm" | FIT | p.0001 ozone and surface UV for planets around G2V, F2V, K2V stars; the predecessor measured ozone_uv_weight from it (physics-review.md :33) |
| :130, :15 | a saltation standardisation correcting for air density only | Kok et al. 2014 (read) | none | FIT | p.0004 "standardized threshold friction velocity (u*st) as the value of u*t at standard atmospheric density at sea level (rho_a0 = 1.225 kg m-3)" |
| :131 | stability correction is an omission when absent | Monin and Obukhov 1954 (held) | "Locator: to confirm" | FIT | p.0003 profiles "regularly deviate from the logarithmic law during stratification"; p.0012 L. Hygiene: INDEX gives ADS 1954TrGeo..24..163M |
| :132 | stability functions | Louis 1979 (held) | none | FIT | as above |
| :133 | open-water evaporation formula | Penman 1948 (held) | "DOI: to confirm" | FIT | p.0002 aerodynamic and energy-balance approaches to evaporation. Hygiene: INDEX 10.1098/rspa.1948.0037 |

##### sys/exchanges-have-one-owner-per-flux-and-carry-their-fraction.md (REQ-SYS-009): 3

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :84 | sections 1, 2, 5, 55, 59 | pred notes/external-model-survey.md | sections | FIT | headings :101, :119, :596, :5011, :5536; 59f text :5643-5656 states the replay rule |
| :85 | "the flux hand-over rule, section 59f" | Holden et al. 2016, 10.5194/gmd-9-3347-2016 (held) | section 59f | NF-C2 | see N1 |
| :86 | DSTAREA/FRACAREA normalisation | ESMF source tree (held, commit d8cb7c6c) | "pinned identifier: to confirm" | FIT | FRACAREA documented in references/esmf/src/Infrastructure/Regrid/doc/Regrid_options.tex and Regrid_implnotes.tex. Hygiene: INDEX pins the commit |

##### sys/loops-read-the-most-determined-input-and-antitone-maps-bracket.md (REQ-SYS-007): 2

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :85 | the invariant and the antitone bracket | pred docs/src/pipeline/loops.md | whole | FIT | exists, section 3 onward |
| :86 | bracketed vs marginal vs disputed | pred docs/src/reference/vocabulary.md | entries | FIT | :144-159 |

##### sys/one-clock-no-day-unit-no-fixed-calendar.md (REQ-SYS-102): 5

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | day_24hr, calendar workaround | pred exoplasim/notes/parameter-decisions.md | "Non-Earth rotation/calendar workaround" | FIT | :78-82 |
| :19-37 | 1.25x damping, 5760 vs 5850 steps, phase 0.799 | pred notes/audits/model-earth-centrism.md findings 2, 18, 20, 23 | findings | FIT | :830 "360*16 = 5760 steps", :854 "phase 0.799" |
| :20, :44 | findings 2, NSTPW | pred notes/audits/opaque-constants.md | findings | FIT | exists |
| :40 | per-orbit closure computed per Earth year | pred notes/audits/inherited-earth-constants.md finding 6 | finding 6 | FIT | exists |
| :113 | declination and instellation from orbital elements | Berger 1978 (read) | "(to confirm)" | FIT | p.0003 section 3 "Annual variation of daily insolation"; INDEX read row for the orbital-phase conventions. Hygiene: DOI confirmed in INDEX |

##### sys/one-declaration-per-quantity.md (REQ-SYS-103): 8

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | 23,000x damping, two flux-to-kelvin copies | pred notes/audits/opaque-constants.md | findings 1, 3, 5, 11, 19, 20 | FIT | exists; "23" located |
| :20 | aerosol radius declared twice | pred notes/audits/aerosol-particle-radius.md | whole | FIT | exists |
| :22 | sea-water constants in two modules | pred notes/audits/model-earth-centrism.md finding 10 | finding | FIT | exists |
| :27 | two snow conductivity relations | pred notes/audits/cryosphere-material-properties.md | whole | FIT | exists |
| :101 | specific heat correlation evaluated at 276.49 K above its range | Fukusako 1990 (read) | none | FIT | p.0004 eq. (2) C_pi = 0.185 + 0.689e-2 T, "273 K >= T >= 90 K" |
| :105 | the one declaration for ice Ih | IAPWS R10-06(2009) (read) | release | FIT | p.0004 Gibbs energy g(T, p) equation of state |
| :109 | a snow conductivity relation | Sturm et al. 1997 (held) | none | FIT | p.0010 eq. (4) superimposed on all data; Table 3 regressions p.0007 |
| :111 | the other snow conductivity relation | Fourteau et al. 2021 (read) | none | FIT | p.0010 second-order polynomial fits, eq. (18) |

##### sys/silent-earth-defaults-unrepresentable.md (REQ-SYS-101): 7

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4 old_path | 29 findings, 1.44x, 700 m, 9.3 per cent | pred notes/audits/model-earth-centrism.md | findings | FIT | :248 "(7645464/6371000)^2 = 1.4401"; :322 "clwhsc held at CCM3's 700 m"; :655 0.0016 |
| :35, :51 | lapse rate, perihelion default | pred notes/audits/inherited-earth-constants.md findings 3, 4 | findings | FIT | exists |
| :36, :45 | lapse rate, t0 = 250 K | pred notes/audits/opaque-constants.md findings 3, 11, 12 | findings | FIT | exists |
| :138 | free-convection coefficient folds (g/theta)^(1/3) at Earth gravity | Miller, Beljaars, Palmer 1992 (held) | "(to confirm)" | FIT | p.0007 eq. (8) E/rho = 0.17 {g kappa^2/(theta_v nu)}^(1/3) ...; p.0009 eq. (9) C_R = 0.0016/(C_QN |U_1|)(theta_vs - theta_vl)^(1/3). Hygiene: DOI confirmed in INDEX |
| :143 | "Eq. 4, the 700 m liquid-water scale height" | Kiehl et al. 1998 (held) | Eq. 4 | NF-C2 | see N2 |
| :148 | the stability functions | Louis 1979 (held) | none | FIT | as above |
| :152 | gravity explicit in the water-surface roughness | Charnock 1955 (held) | "(to confirm)" | FIT | p.0001 "g z(0)/u*^2 = constant". Hygiene: DOI confirmed in INDEX |

##### sys/the-land-column-carries-every-process-that-moves-land-water.md (REQ-SYS-006): 4

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :89 | findings 1 and 4, 816.4/690.0/126.4 mm | pred notes/audits/missed-couplings.md | findings 1, 4 | FIT | headings :25, :169; "126.4" located |
| :90 | "That coupling is radiative and aerodynamic, and it is not hydrological" | pred docs/src/pipeline/loops.md | sentence | FIT | :95 |
| :91 | where the Lapides figure was taken from | pred pedology/README.md | :482-491 | FIT | "Lapides et al. (Biogeosciences 2024) ... raising annual transpiration by a median of 100-150 mm" |
| :24, :91 | median transpiration increase 100 to 150 mm | Lapides et al. 2024 (held) | "Verbatim title and DOI: to confirm" | FIT | p.0011 "T is enhanced across CONUS relative to the default model ... with a median increase of 100-150 mm annually". Hygiene: the paper is now held; title "Inclusion of bedrock vadose zone in dynamic global vegetation models is key for simulating vegetation structure and function", 10.5194/bg-21-1801-2024 |

##### proc/a-check-has-a-right-answer-and-refuses-rather-than-backfills.md (REQ-PROC-003): 4

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :76 | thresholds before results, 0.05 K | pred docs/src/practice/conventions.md | whole | FIT | exists; "0.05" located |
| :77 | "the two checks that can fail" | pred lib/lapse.py, lib/stellar.py | docstrings | FIT | lapse.py :39, stellar.py :35; 0.517 at stellar.py :76 |
| :78 | ESMF about 1e-9 relative, unmapped refused | pred notes/external-model-survey.md section 55 | section | FIT | :5011; "1e-9 relative" at :5026 |
| :79 | "A judgment made while a class is absent is not a judgment" | pred docs/src/reference/design-intent.md | bullet | FIT | :28 |

##### proc/a-session-ends-completed-or-blocked.md (REQ-PROC-009): 1

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :71 | working agreements | pred docs/src/practice/working-agreements.md | whole | FIT | exists; "completed" rule located |

##### proc/findings-decisions-tasks-and-acceptances-kept-apart.md (REQ-PROC-002): 2

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :64 | six reviews, acceptances | pred notes/audits/docs-restructure-audit.md | whole | FIT | exists; "acceptance" located |
| :65 | "The issue tracker" | pred docs/src/practice/conventions.md | section | FIT | :169 |

##### proc/import-review-runs-the-checklist-and-costs-the-fork.md (REQ-PROC-008): 4

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :120 | tiers A to D, clean negatives | pred notes/external-tree-checklist.md | whole | FIT | exists; "clean negative" located |
| :121 | sections 5, 55e | pred notes/external-model-survey.md | sections | FIT | :596, :5098 |
| :122 | "Before recording another limitation, check it" | pred notes/orchestration-frameworks.md | section | FIT | :219 |
| :123 | "cost the fork, then decide on the physics" | pred docs/src/reference/design-intent.md | sentence | FIT | :24 |

##### proc/individually-converged-is-not-jointly-converged.md (REQ-PROC-007): 2

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :61 | the finalizer | pred docs/src/pipeline/loops.md "The finalizer: individually converged is not jointly converged" | section | FIT | :306 |
| :62 | loop exit predicates | pred notes/audits/loop-exit-predicates.md | whole | FIT | exists |

##### proc/loop-exits-declared-before-the-loop-runs-with-an-instrument.md (REQ-PROC-006): 2

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :83 | six findings on exits | pred notes/audits/loop-exit-predicates.md | whole | FIT | exists |
| :84 | Cylc, AiiDA gate | pred notes/orchestration-frameworks.md | sections | FIT | :103, :166 |

##### proc/no-current-values-in-prose.md (REQ-PROC-001): 4

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :65 | fifty-one failed summaries | pred notes/audits/derived-structure-audit.md | whole | FIT | exists; "fifty-one" located |
| :66 | "Documents and numbers" | pred docs/src/practice/conventions.md | section | FIT | :94 |
| :67 | tier 5 | pred notes/audits/frozen-derived-quantities.md | tier 5 | FIT | :501 |
| :68 | finding 3, hand-edited generator output | pred notes/audits/missed-couplings.md | finding 3 | FIT | :129 |

##### proc/one-quantity-one-name.md (REQ-PROC-010): 2

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :65 | vocabulary | pred docs/src/reference/vocabulary.md | whole | FIT | exists |
| :66 | "An undocumented component is not complete"; "Prose registers" | pred docs/src/practice/conventions.md | bullet, section | FIT | :135, :240 |

##### proc/physics-is-not-a-knob-and-earth-is-a-distance.md (REQ-PROC-004): 6

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :76 | "No tuned values", roughness 0.18 to 0.34 | pred docs/src/practice/conventions.md | section | FIT | :26; Kok choice at :75-80 |
| :77 | "implicit-Earth" | pred docs/src/reference/vocabulary.md | entry | FIT | :183 |
| :78 | sections 59b, 59d, 59e | pred notes/external-model-survey.md | sections | FIT | :5559, :5611, :5627 |
| :79 | section 19, calibration subsystem | pred notes/audits/tuned-values.md | section 19 | FIT | :1313 |
| :80 | moisture flux adjustment 0 to 0.32 Sv; wind-stress scaling tuned over a 50-member ensemble | Holden et al. 2016 (held) | none | FIT | p.0007 Table 1 "Atlantic-Pacific moisture flux adjustment ... 0 to 0.32" and "Wind-stress scaling"; p.0001 "a subjective tuning of the model with a 50-member ensemble of 1000-year simulations" |
| :81, :33 | a dust scheme chosen for deriving its size distribution from fragmentation physics | Kok et al. 2014 (read) | none | NF-C5 | see N5 |

##### proc/price-in-the-currency-of-the-decision-between-converged-points.md (REQ-PROC-005): 4

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :81 | 291.9 K extrapolated vs 287.47 K; 8.6x price | pred docs/src/reference/design-intent.md | whole | FIT | exists; "291.9" located |
| :82 | finding 1, runoff amplification | pred notes/audits/missed-couplings.md | finding 1 | FIT | :25 |
| :83 | three sensitivities differing by 2.2 | pred lib/sensitivity.py | docstring | FIT | exists |
| :84 | section 2 cost table with its error | pred notes/external-model-survey.md | section 2 | FIT | :119, 2a at :137 |

##### proc/undefined-durations-and-population-density-calibration.md (REQ-PROC-011): 2

| where | use | source (status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| :4, :68 | no time axis, 300 times away | pred docs/src/reference/no-time-axis.md | whole | FIT | exists; "300" located |
| :69 | section 5, the size floor | pred notes/audits/tuned-values.md | section 5 | FIT | :325 "The carve incision coefficient, and the size floor that sets its target" |

#### Not fit, one section per case

##### N1. REQ-SYS-009 cites Holden et al. (2016) for the flux hand-over rule

- Where: docs/requirements/sys/exchanges-have-one-owner-per-flux-and-carry-their-fraction.md :85 (and the rule at :23-30).
- Use: the contract that a replayed forcing recomputes the receiver-state-dependent terms (saturation humidity and latent heat, net longwave, sensible heat) live, and hands evaporation over.
- Source: Holden et al. 2016, PLASIM-GENIE v1.0, 10.5194/gmd-9-3347-2016 (held).
- Category: C2, the source does not state the rule claimed.
- What is wrong: the paper describes the synchronous PLASIM-GENIE coupling, its surface flux routine and a 50-member tuning ensemble; it contains no passage on geared or replayed forcing, recomputed terms or the moisture hand-over (grep of all 15 pages for gear, seasonal cycle, replay, stored, recompute: no hit on the rule). The predecessor survey that the record carries names where the rule came from: section 59 was "Read 2026-08-24: Holden et al. (2016), the PLASIM-GENIE paper, against `vendor/cgenie/genie-plasim`" (survey :5538-5539), and 59f says "The source comment says why: naive replay of net heat flux severs the negative feedback" (:5650). The rule is a code comment in the vendored genie-plasim tree, not a statement of the paper.
- Evidence: Holden 2016 p.0004 :138 "outgoing radiative fluxes, and sensible and latent heat fluxes are dependent upon the surface temperature" (synchronous coupling only); survey 59f :5643-5656.
- Fix class: (b). Cite the genie-plasim source file and comment by a pinned identifier (it is in the predecessor's vendor tree, not held here), or state the rule on the survey's authority as a predecessor finding and keep Holden only for the coupled model's description. Boundary: docs/requirements/sys/exchanges-have-one-owner-per-flux-and-carry-their-fraction.md, and docs/references/INDEX.md if the source file is carried as a held row (INDEX is edited by fiddlybits-k6b). Acceptance: the hand-over rule's citation names a source whose located passage states it. No user decision.

##### N2. REQ-SYS-101 describes Kiehl et al. (1998) Eq. 4 as "the 700 m liquid-water scale height"

- Where: docs/requirements/sys/silent-earth-defaults-unrepresentable.md :143-147.
- Use: an example of a length in Earth metres folded into a parameterisation.
- Source: Kiehl et al. 1998, CCM3, 10.1175/1520-0442(1998)011<1131:TNCFAR>2.0.CO;2 (held).
- Category: C2, the source does not state the value as the locator describes it.
- What is wrong: Eq. 4 is not a fixed 700 m scale height. It diagnoses the liquid water scale height locally from precipitable water, h_l = a ln(1.0 + (b/g) integral from p_T to p_s of q dp), "where the parameters have been empirically determined to be a = 700 m and b = 1 m2 kg-1". The 700 m is a fitted coefficient, and g appears explicitly in the precipitable-water term. The lesson (an empirically fitted length in metres) is supported; the description of what the number is, is not.
- Evidence: Kiehl 1998 p.0003 (journal p.1133), Eq. (4) and the sentence after it.
- Fix class: (a), a wording and locator correction from a passage read here: "Eq. 4, h_l = a ln(1 + (b/g) PW), with a = 700 m and b = 1 m2 kg-1 empirically determined". The INDEX row stays held (a requirement's References list does not claim read). Boundary: docs/requirements/sys/silent-earth-defaults-unrepresentable.md. No user decision.

##### N3. REQ-SYS-001 derives the gravity exponent of rain re-evaporation "from Kessler (1969)"

- Where: docs/requirements/sys/constants-have-five-dispositions.md :53-56 and :124.
- Use: the re-evaporation fraction derived into a form proportional to the timestep, to precipitation to the 0.578 power, and to gravity to the -0.289 power.
- Source: Kessler 1969, 10.1007/978-1-935704-36-2 (read).
- Category: C2 (partial). The precipitation exponent is in the source; the gravity exponent is not.
- What is wrong: P^0.578 follows from Kessler's eq. (8.13), R = 138 N0^(-1/8) M^(9/8), with the evaporation term k3 N0^(7/20) m M^(13/20) of eq. (8.30)/(8.31): 0.65/1.125 = 0.578. Gravity does not appear in Kessler's fall speed. Eq. (7.1) is V ~ -K (rho0/rho)^(1/2) D^(1/2) with "K = 130 ... reproduces the experimental data obtained by Gunn and Kinzer (1949) at sea level", an empirical coefficient, and eq. (8.11) V0 = -38.3 N0^(-1/8) M^(1/8) exp(kz/2) carries no g. The -0.289 exponent needs K proportional to g^(1/2), a drag-balance argument the predecessor supplied (tuned-values.md, "The five papers": "carrying ga^(-0.289)") and Kessler does not state. The INDEX row's anchor "both with explicit gravity dependence through terminal speed (section 8, table 4)" makes the same claim of the source, which is an INDEX-scope C6 case for the fork auditing INDEX rows (INDEX is edited by fiddlybits-k6b).
- Evidence: Kessler p.0031 eq. (7.1) and following sentence; p.0039 eqs. (8.11), (8.13); p.0041 eq. (8.30).
- Fix class: (b). Read a primary for the gravity dependence of raindrop terminal velocity (the drag balance behind K), or attribute the g^(1/2) scaling to the predecessor's derivation and cite Kessler for the precipitation exponent only. No constant in src/ carries this form, so no disposition changes. Boundary: docs/requirements/sys/constants-have-five-dispositions.md, docs/references/INDEX.md (Kessler row anchor; after k6b merges). Acceptance: each exponent names the source and equation it rests on. No user decision.

##### N4 and N5. Kok et al. (2014) cited for a size distribution derived from fragmentation physics

- Where: N4 docs/requirements/sys/constants-have-five-dispositions.md :123 "(a scheme chosen for one fewer unconstrained coefficient)"; N5 docs/requirements/proc/physics-is-not-a-knob-and-earth-is-a-distance.md :33-35 and :81 "a dust scheme was chosen at the point of choice for deriving its size distribution from fragmentation physics rather than fitting it".
- Use: the reason the scheme carries one fewer unconstrained coefficient is that its emitted size distribution is derived from brittle fragmentation, not fitted.
- Source: Kok et al. 2014, ACP 14, 13023, 10.5194/acp-14-13023-2014 (read, eqs. 18a, 18b).
- Category: C5, a paper that adopts a result standing in for the primary that states it.
- What is wrong: Kok 2014 takes the emitted size distribution from an earlier paper: "dust size distribution expression of Kok (2011b)" (p.0009 :70), with Kok 2011b listed as "Kok, J. F.: A scaling theory for the size distribution of emitted dust ..." (p.0017 :71). The derivation from fragmentation is stated in Kok (2011) PNAS. The predecessor's own wording ties the choice to that derivation (conventions.md :75-78: "K14 derives the emitted size distribution from fragmentation physics rather than fitting it, so it carries one fewer unconstrained knob").
- Evidence: Kok 2014 p.0009 :70 and p.0017 :71; INDEX row for kok_2010_a-scaling-theory-for-the-size-distribution-of-emitted-dust-aerosols-su.pdf, read, "emitted volume size distribution from fragmentation (eq. 6)".
- Fix class: (a). The correct source is already read. Cite Kok (2011), "A scaling theory for the size distribution of emitted dust aerosols suggests climate models underestimate the size of the global dust cycle", 10.1073/pnas.1014798108, eq. 6, for the fragmentation-derived size distribution, beside Kok 2014 as the scheme chosen. Boundary: the two requirement files above; no open branch edits either. No user decision.

##### N6. REQ-PROV-001 cites Baker et al. (2015) and no rule of the record rests on it

- Where: docs/requirements/prov/restart-bitwise-state-only-refuses-on-moved-input.md :94.
- Use: none named. The record's rules are bitwise segment continuity, a byte-identical zero-step round trip, state-only checkpoints and refusal on a moved hash.
- Source: Baker et al. 2015, pyCECT, 10.5194/gmd-8-2829-2015 (held).
- Category: C2, the source does not support the rules it is listed under.
- What is wrong: Baker 2015 is a statistical ensemble consistency test for when bitwise identity is not available ("simulations that differ only in a random perturbation of the initial atmospheric temperature field of O(10^-14)", p.0004). REQ-PROV-001 requires bitwise equality and never an ensemble test. The citation fits REQ-NUM-002 item 6, where the same paper is listed, and not here.
- Evidence: Baker 2015 p.0004 :18-26; REQ-PROV-001 items 1-6.
- Fix class: (a). Remove the entry from REQ-PROV-001; REQ-NUM-002 keeps it. Boundary: docs/requirements/prov/restart-bitwise-state-only-refuses-on-moved-input.md. No user decision.

#### Not verified

- REQ-NUM-001 :101 and REQ-NUM-005 :126: Madras and Sokal 1988, section 2.2, for the autocorrelation-corrected standard error. INDEX status requested; not on disk; Unpaywall is_oa false.
- REQ-NUM-005 :124: Roache 1994. Not held and absent from INDEX and REQUESTS: a cited source with no index row. The row's DOI is "to confirm"; Crossref/Unpaywall resolves 10.1115/1.2910291 to that title, is_oa false. Fix class (b): add it to REQUESTS (paywalled) or drop it; boundary docs/requirements/num/resolution-ladder-three-quantities.md and docs/references/REQUESTS.md.

#### Hygiene, fit on substance (fix class (a), locator corrections; no read needed)

Records in scope still say "to confirm" for identifiers INDEX has since resolved:
REQ-NUM-007 Ivankovic 2019 (10.1145/3338906.3340459); REQ-NUM-002 Demmel and Nguyen 2013
(10.1109/ARITH.2013.9) and Arteaga 2014 (10.1109/IPDPS.2014.127); REQ-PROV-002 and
REQ-PROV-003 Merkle (10.1007/3-540-48184-2_32); REQ-SYS-104 Sundqvist 1978 and
Smagorinsky 1963; REQ-SYS-102 Berger 1978; REQ-SYS-005 Monin and Obukhov 1954 (ADS
1954TrGeo..24..163M) and Penman 1948 (10.1098/rspa.1948.0037); REQ-SYS-101 Miller 1992
and Charnock 1955; REQ-SYS-009 ESMF (commit d8cb7c6c83b3154eeeaadede4676397904916293);
REQ-SYS-006 Lapides 2024 (now held: verbatim title above, 10.5194/bg-21-1801-2024, p.0011).
REQ-SYS-005 Segura 2003 remains "to confirm" in INDEX as well.

Observations outside the citation count:
- REQ-SYS-001 :57-59 states a law with no source: "(1 - rcrit) scales as the grid spacing to the one third by the Kolmogorov-Obukhov-Corrsin argument". It is the predecessor's derivation (tuned-values.md :960-964) with no primary named. It is not a basis of anything in src/. It needs a read primary (Obukhov 1949 / Corrsin 1951 for the scalar variance spectrum) or attribution to the predecessor; fix class (b).
- IEEE 754-2019 is marked read in INDEX for clause 5.4.1 only (decision 0044), and REQ-NUM-001 and REQ-NUM-003 in its anchors rest on the rounding (4.3.1) and exception (7.2, 6.2) clauses. The source states them (p.0028, p.0035); the INDEX anchor does not name them. This is an INDEX-scope C6 note for the INDEX fork (INDEX is edited by fiddlybits-k6b).
- Kessler 1969's INDEX anchor claims an explicit gravity dependence the text does not carry (N3). Same INDEX-scope note.

#### User decisions

None in this scope. No fix above changes a registered bar, a constant's disposition, a
decision's basis or a test instance's declared value.

#### Fetch failures and paywalled sources

- "The pivot algorithm: A highly efficient Monte Carlo method for the self-avoiding walk", Madras and Sokal, J. Stat. Phys. 50 (1988), 10.1007/BF01022990. Paywalled (Unpaywall is_oa false); already requested in INDEX.
- "Perspective: A Method for Uniform Reporting of Grid Refinement Studies", Roache, J. Fluids Eng. 116(3) (1994), 10.1115/1.2910291. Paywalled (Unpaywall is_oa false); not in INDEX or REQUESTS.

### Q5: Requirements, ped and ter


Worktree /home/cfutro/git/fiddlybits/.beads/worktrees/fiddlybits-9j0 at 625832c. Read-only audit.
Scope rule applied: a citation is counted where it is the basis of a law, number, scheme,
threshold, bar or validity range the record states. References listed with no such use in
the body (tile-design background, verification-method background, spectral libraries whose
numbers the predecessor derived) are listed per file as excluded and not counted.
Page numbers are PDF page indices of references/text/<stem>/<NNNN>.txt unless a printed
page is named.

#### Counts

| scope | citations | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| docs/requirements/ped/ (11 files) | 55 | 43 | 10 | 2 |
| docs/requirements/ter/ (18 files) | 49 | 40 | 8 | 1 |
| total | 104 | 83 | 18 | 3 |

Per file:

| file | id | cited | fit | not fit | not verified |
| --- | --- | --- | --- | --- | --- |
| ped/brine-divide-per-basin.md | REQ-PED-008 | 3 | 3 | 0 | 0 |
| ped/carbon-thermostat-outgassing-bracket.md | REQ-PED-011 | 3 | 2 | 0 | 1 |
| ped/land-column-hydraulic-contract.md | REQ-PED-007 | 3 | 2 | 1 | 0 |
| ped/lithology-registry-one-reading.md | REQ-PED-004 | 5 | 5 | 0 | 0 |
| ped/per-rock-then-average.md | REQ-PED-002 | 2 | 2 | 0 | 0 |
| ped/phosphorus-lithology-release.md | REQ-PED-010 | 5 | 3 | 2 | 0 |
| ped/runoff-is-the-closed-balance.md | REQ-PED-005 | 4 | 1 | 3 | 0 |
| ped/soil-ph-from-run-pco2.md | REQ-PED-003 | 7 | 6 | 1 | 0 |
| ped/surface-classes-two-axes.md | REQ-PED-009 | 7 | 5 | 2 | 0 |
| ped/texture-mineral-inventory-earth-score.md | REQ-PED-006 | 7 | 6 | 1 | 0 |
| ped/weathering-real-clock.md | REQ-PED-001 | 9 | 8 | 0 | 1 |
| ter/closure-ledgers-at-every-conversion.md | REQ-TER-003 | 2 | 2 | 0 | 0 |
| ter/conventions-by-name-index-not-coordinate.md | REQ-TER-010 | 2 | 1 | 1 | 0 |
| ter/distribution-quantiles-as-semantics.md | REQ-TER-009 | 1 | 1 | 0 | 0 |
| ter/field-semantics-declared-on-the-field.md | REQ-TER-001 | 1 | 1 | 0 | 0 |
| ter/finite-output-is-not-acceptance.md | REQ-TER-006 | 1 | 1 | 0 | 0 |
| ter/gravity-enters-through-the-law.md | REQ-TER-013 | 11 | 9 | 1 | 1 |
| ter/guard-is-not-a-physical-ceiling.md | REQ-TER-014 | 1 | 1 | 0 | 0 |
| ter/ice-that-erodes-is-a-climate-outcome.md | REQ-TER-017 | 2 | 2 | 0 | 0 |
| ter/lithology-class-denotes-a-rock.md | REQ-TER-015 | 6 | 3 | 3 | 0 |
| ter/mesh-carries-both-dual-measures.md | REQ-TER-011 | 2 | 2 | 0 | 0 |
| ter/nonlinear-order-in-space.md | REQ-TER-007 | 5 | 5 | 0 | 0 |
| ter/nonlinear-order-in-time.md | REQ-TER-008 | 4 | 3 | 1 | 0 |
| ter/snapshot-carries-ages-and-rates.md | REQ-TER-018 | 3 | 2 | 1 | 0 |
| ter/terrain-level-by-measured-information-floor.md | REQ-TER-016 | 5 | 5 | 0 | 0 |
| ter/support-identity-is-versioned.md | REQ-TER-002 | 3 | 2 | 1 | 0 |
| ter/tests-that-can-fail.md | REQ-TER-004 | 0 | 0 | 0 | 0 |
| ter/inventories-of-loss.md | REQ-TER-005 | 0 | 0 | 0 | 0 |
| ter/land-fraction-is-real-never-binarised.md | REQ-TER-012 | 0 | 0 | 0 | 0 |

No file in this scope is edited by an open branch (k6b edits only hyd/lake-equilibrium-earth-oracle.md
among requirements). Fixes that would also touch docs/references/INDEX.md are blocked while
fiddlybits-k6b is open.

#### Every citation

| # | where | use | source (INDEX row, status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | PED-008 l.11-14 | five solute behaviours under evaporative concentration | eugster1979 (INDEX 76, read) | pp.6-7, Fig. 3 | FIT | p.6: "we can predict five basic types of behavior"; types I, IIa/b, III, IV, V as the record lists |
| 2 | PED-008 l.14-17 | chemical divide: calcite removes Ca and CO3 in equal proportion, fixed early | MSA_SP3_273-290 Hardie and Eugster 1970 (INDEX 78, held) | pp.5, 7 | FIT | p.5: "Ca2+ and CO3 2- must be lost from solution in equal molar proportions"; p.7: trend "determined at a very early stage ... by calcite precipitation" |
| 3 | PED-008 l.17-22, 58-60 | Table 2C Ca, HCO3, SO4 per lithology; Ca/HCO3 0.11 peridotite to 0.80 carbonate, evaporites 1.50 and 3.25; temperate-stream release | meybeck1987 (INDEX 80, held) | Table 2C, printed p.409 (PDF p.9) | FIT | Table 2C "Representative analyses used in the Temperate Stream Model" (ueq/l): peridotite Ca 50 / HCO3 450; carbonate 2560/3195; gypsum evaporite 6500/2000; halite evaporite 3000/2000; every silicate row below 1 |
| 4 | PED-011 l.33-37 | segment-scale ridge CO2 flux varies >3 orders, >2 orders per length; per-length flux cannot falsify pCO2 | levoyer2019 (INDEX 92, held) | pp.2, 19 | FIT | p.2: "segment-scale CO2 fluxes vary by more than three orders of magnitude"; p.19: "normalized by ridge length, vary by a factor of >100" |
| 5 | PED-011 l.37-39 | ridge, arc, plume fluxes from melt emplacement; most arc carbon slab-derived | marty1998 (INDEX 91, held) | p.1 | FIT | p.1: arc flux "with approx. 80% of carbon being derived from the subducting plate" |
| 6 | PED-011 l.27-30 | three published weathering schemes each separate into a runoff power and a temperature exponential | not named; references list Walker 1981, Berner 1983, Amiotte Suchet 2003 | none | NOT VERIFIED | the record does not name the three schemes, so no passage can be opened for the claim; WHAK checked consistent (linear in runoff times an exponential in T, walker1981 pp.2-3); Berner 1983 temperature law not located |
| 7 | PED-007 l.19-22, 70-73 | Clapp-Hornberger retention closure on Cosby Table 4, Sourced; within-class spread | cosby_1984 (INDEX 230, read) | Table 4, p.5; eq. 1, p.2 | FIT | p.2 eq. (1) psi = psi_s (theta/theta_s)^b fitted per sample; Table 4 regressions on "the Means and Standard Deviations of the Parameters" |
| 8 | PED-007 l.28-31 | "L = 1 m reproduces Cosby's own field-capacity suction of 100 cm of water", which licenses stating field capacity as a length | cosby_1984 (INDEX 230, read) | none given | NOT FIT (C2) | see NF-1 |
| 9 | PED-007 l.21 | retention family (power curve, Brooks-Corey family) | clapp1978 (INDEX 550, held) | pp.2-3 | FIT | p.2-3: "modified power curve for psi", b per texture class; cosby p.2 relates the power form to Brooks and Corey with zero residual |
| 10 | PED-004 l.19-23 | permeability keyed on Durr classes; evaporite in "not assigned" | gleeson_2011 (INDEX 129, read) | Table 1, p.3 | FIT | Table 1: "not assigned ... WB, IG, EV" (EV = evaporites, footnote b) |
| 11 | PED-004 l.23-24 | carbonate permeability increases with scale through karst, one-signed underestimate | gleeson_2011 (INDEX 129, read) | p.3 para [8] | FIT (note) | "carbonates ... where permeability increases with scale, possibly due to karst [Halihan et al.] or sampling bias"; direction supported, mechanism hedged in the source |
| 12 | PED-004 l.20, 48 | Durr et al. 2005 class vocabulary | durr2005 (INDEX 568, held) | p.1; Gleeson Table 1 fn b | FIT | class list AD, DS, EV, LO, SU, SC, SM, SS, MT, PA, PB, VA, VB, PR, CL |
| 13 | PED-004 l.21 | Hartmann 2014 phosphorus keyed per lithological class | hartmann2014 (INDEX 392, held) | section 2.3, p.3 | FIT | "geochemical data per lithological class ... F_P = b_relative P-content * F_Si+cations" |
| 14 | PED-004 l.31-33 | carbonate endmember excluded: Ca + Mg 1740 against HCO3 1730 ueq/l | meybeck1987 (INDEX 80, held) | Table 2C, printed p.409 | FIT | row "misc. metamorphic": Ca 1375, Mg 365, HCO3 1730 |
| 15 | PED-002 l.26-27 | permeability classes log-normal; geometric mean is the class statistic | gleeson_2011 (INDEX 129, read) | p.3 para [7] | FIT | log k "generally normally distributed"; "we adopt the geometric mean as the best estimate of regional-scale permeability" |
| 16 | PED-002 l.31 | Jensen's inequality at a reduction | jensen1906 (INDEX 639, held) | p.1 | FIT | section I "Des fonctions convexes et concaves"; the inequality between convex function and mean |
| 17 | PED-010 l.11-13, 40-41 | P release a fixed class share of the Ca, Mg, Na, K, SiO2 export | hartmann2014 (INDEX 392, held) | section 2.3, p.3 | FIT | "release of P ... proportional to the release of SiO2 and cations ... based on the average geochemical composition of the lithological classes"; F_P formula |
| 18 | PED-010 l.43-44 | soil shielding "a function of regolith thickness on the clock (Hartmann's form, Sourced)" | hartmann2014 (INDEX 392, held) | section 3.2, p.6 | NOT FIT (C2) | see NF-2 |
| 19 | PED-010 l.14-15, 41-42 | Table 2C per-lithology concentrations as release and REPORT check | meybeck1987 (INDEX 80, held) | Table 2C | FIT | as row 3 |
| 20 | PED-010 l.18-19, 50-52 | land yield within Hartmann and Moosdorf (2011)'s Japanese maximum as a FAIL bar on Earth | hartmann2011 (INDEX 393, held) | abstract p.1 | NOT FIT (C4, C7, C3) | see NF-3 |
| 21 | PED-010 l.27-28 | diatomite is not P-rich (600 ppm) | hudsonedwards2014 (INDEX 334, held) | Table 1, p.4 | FIT (note) | total P of Bodele sediments and dusts 420 to 970 ppm, most near 600; the land mean 628 is the predecessor's, not this source's |
| 22 | PED-005 l.12-13 | Walker-Hays-Kasting law defined on river runoff | walker1981 (INDEX 84, held) | pp.2-3 | FIT | p.2: silicate weathering "increases markedly with increase in either runoff" (Meybeck classes); p.3: concentration shows "no obvious dependence on runoff" |
| 23 | PED-005 l.13 | "its 0.65 exponent" (WHAK's) | walker1981 (INDEX 84, held) | none | NOT FIT (C2) | see NF-4 |
| 24 | PED-005 l.13-14, 72-73 | 0.65 traces to Dunne (1978), fitted against runoff | dunne1978 "Field studies of hillslope flow processes" (INDEX 566, held) | none | NOT FIT (C4) | see NF-4 |
| 25 | PED-005 l.13-14, 74-76 | 0.65 traces to Peters (1984), fitted against runoff | peters1984 (INDEX 727, held) | pp.18, 22-23, 30 | NOT FIT (C2) | see NF-4 |
| 26 | PED-003 l.11-17, 97-98 | bimodal subsoil pH 8.2 and 5.1, n 20,000 of 60,291, 42% explained, wettest quartile 2.6 times; Earth REPORT metrics | slessarev2016 (INDEX 75, read) | pp.1-2 | FIT | p.1 l.20-21 "n = 20,000 ... 60,291"; l.53-54 "pH of 8.2 ... on average 5.1"; p.2 l.41 "explain 42%"; l.77 "2.6 times more likely to have a pH value > 6.5" |
| 27 | PED-003 l.26-36, 81-87 | calcite end from the printed equation, validated at 3.45e-4 atm and 25 C to 8.2 | slessarev2016 (INDEX 75, read) | Methods eq. (6), p.5 | FIT | eq. (6) printed; "We solved this equation for H+ at 25 C and a pCO2 of 3.45 x 10-4 atm" |
| 28 | PED-003 l.28-31 | the pre-1977 pH 8.3 remark carries no pressure | slessarev2016 (INDEX 75, read) | Methods p.5 | FIT | "the expected pH is 8.3 before 1977"; no pCO2 given for it |
| 29 | PED-003 l.38-42 | gibbsite end fixed by an empirical exchange ratio of Earth's soils | slessarev2016 (INDEX 75, read) | Methods, Gibbsite buffer, p.5 | FIT | pH "depends on the ratio of AlX to other exchangeable cations (CaX) ... must be estimated empirically" |
| 30 | PED-003 l.44-45 | supply u: Table 2C bicarbonate per rock relative to carbonate rock | meybeck1987 (INDEX 80, held) | Table 2C | FIT | HCO3 column per rock, carbonate 3195 ueq/l |
| 31 | PED-003 l.45-48, 90-91 | GEM-CO2 alkalinity yields "independently" agree; supply "Sourced from two independent compilations" | amiottesuchet1995 (INDEX 81, held) | p.2 | NOT FIT (C2) | see NF-5 |
| 32 | PED-003 l.120-124, 82-84 | carbonate constants with their fitted temperature range (Zeebe and Wolf-Gladrow ch.1, Millero 1995) | zeebe2001 (INDEX 825, held); millero1995 (INDEX 690, held) | Millero pp.1, 15 | FIT (note) | Millero p.1: equations over "0 to 45 C" and "salinity (0 to 45)"; p.15: they reduce to "the pure water values when the salinity approaches zero", so the dilute regime is covered; both held, so no constant can be Sourced from them until read |
| 33 | PED-009 l.22-25 | pavement clasts stay at the surface; dust accretes beneath | wells1995 (INDEX 446, held) | abstract p.2 | FIT | "pavement clasts are continuously maintained at the land surface in response to deposition ... of windblown dust"; "stone pavements are born at the surface" |
| 34 | PED-009 l.25-28 | clast source at bedrock highs; supply stops when highs are buried; high loess rates bury the pavement | mcfadden1987 (INDEX 487, held) | pp.1, 3 | FIT | p.1: clasts from "mechanically weathered basaltic bedrock derived from topographic highs"; p.3: "high rates of loess deposition precluded development of a soil, and the preexisting pavement was buried" |
| 35 | PED-009 l.30-34 | Sahara in the highest modern flux bin with no loess; deposition threshold 50 g/m2/yr Bracketed 10 to 200 read off one figure | muhs2013 (INDEX 447, held) | Fig. 44, printed p.40 | NOT FIT (C5) | see NF-6 |
| 36 | PED-009 l.35 | climate gives no silcrete threshold | fenske_2025 (INDEX 83, held) | p.2 | FIT | silcretes "hypothesized to form in arid but also humid silica-rich environments" |
| 37 | PED-009 l.36-38 | silcrete types pan margin, drainage line, groundwater, pedogenic | ullyott2016 (INDEX 448, held) | abstract p.1 | FIT | "reviews the properties of pedogenic, groundwater, drainage-line and pan/lacustrine silcretes" |
| 38 | PED-009 l.38-40, 104-105 | gypcrete window: under about 250 mm/yr with potential evaporation above precipitation in every month | watson1983 vol.1 thesis (INDEX 82, held) | vol.1 p.19 | NOT FIT (C4) | numbers supported; reference names a different work; see NF-7 |
| 39 | PED-009 l.40-41 | calcrete window two-sided | alonsozarza2003 (INDEX 449, held) | pp.1, 9 | FIT | p.1: calcretes "commonly form in semi-arid climates. Arid climates are also suitable"; p.9: "Very arid or very humid" settings unsuitable |
| 40 | PED-006 l.41-43 | "the effect of time is subordinate to these factors" | parfitt_2009 (INDEX 488, held) | p.6 | FIT | verbatim at p.6 l.22 |
| 41 | PED-006 l.43-45 | allophane content 0.22 kg/kg, up to 0.35, Table III | parfitt1983 (INDEX 441, held) | Table III, printed p.49 | FIT (note) | Mairoa allophane in soil 5, 15, 26, 26, 25, 25, 35 %; mean about 22, max 35; the 0.02 lower end is not from this table |
| 42 | PED-006 l.45-47 | Singleton refuses content in the transition window; drainage class alone changes content by an order of magnitude | singleton1989 (INDEX 444, held) | Fig. p.6, p.9 | FIT | well-drained Horotiu allophane 60 to 80 % of clay; Bruntwood falls from 40 to 3.5 to 0 across the gleyed transition; p.9 colour-wetness control |
| 43 | PED-006 l.47-48 | CEC additive in clay and organic C, coefficients linear in pH | helling1964 (INDEX 442, held) | Fig. 3, p.3 | FIT | "Y_organic C = -59 + 51X (r = 0.985), Y_clay = 30 + 4.4X (r = 0.979)", X = pH |
| 44 | PED-006 l.49-51 | clay CEC level 8.4 to 63 cmol(+)/kg clay over nine orders and 37,921 pedons | manrique1991 (INDEX 443, held) | Tables 2, 4, 5, printed pp.788-792 | FIT (note) | Table 5 Model 4 CLAY coefficients 0.084 (Oxisols) to 0.634 (Vertisols); nine orders in Table 2; 37,921 is n of Model 1 (Table 4, abstract), observations rather than pedons |
| 45 | PED-006 l.51-52 | polyvalent share from Solly et al. 2020 | solly_2020 (INDEX 445, held) | abstract p.1 | FIT | "83% of subsoil CEC eff. originates from exchangeable calcium ... exchangeable aluminum contributes between 21 and 44%"; the lower-bound declaration is the record's own |
| 46 | PED-006 l.89-91 | SoilGrids at type localities with "bias and correlation as bars" | poggio2021 (INDEX 732, held) | p.6 l.25, p.8 Table 4 | NOT FIT (C7) | see NF-8 |
| 47 | PED-001 l.11-14, 76-77 | WHAK intensity: a power of runoff times an exponential of temperature; REPORT only | walker1981 (INDEX 84, held) | pp.2-3 | FIT | linear in runoff times P^0.3 times exp in T; "a power of runoff" holds at power 1 |
| 48 | PED-001 l.19-21 | Chadwick 2003 extractable-oxide transfer indexed on substrate age (<20 ka vs 170 ka, 2500 mm) | chadwick_2003 (INDEX 486, held) | none | NOT VERIFIED | no PDF under references/pdf (only chadwick1999); INDEX row names a file that is not on disk; Unpaywall is_oa false; paywalled |
| 49 | PED-001 l.21-23 | Fenske duricrust hardens over the water-table fluctuation range | fenske_2025 (INDEX 83, held) | abstract p.1 | FIT (note) | "formation of a hardened layer at a rate set by a characteristic timescale, tau, and over a depth set by the range of fluctuations in the water table, lambda"; the "1e5 years" figure was not located |
| 50 | PED-001 l.23-24 | pavement supply exhaustible, about 0.4 Ma | mcfadden1987 (INDEX 487, held) | p.2 | FIT (note) | "the source area for basalt clasts is significantly reduced on flows older than 0.4 Ma (Wells et al., 1985)"; the number is McFadden quoting Wells et al. 1985 |
| 51 | PED-001 l.28-31, 63-68 | exponential soil production function, a Closure with Earth's frost and root regime named | heimsath_1997 (INDEX 71, read) | p.3 | FIT | "An exponential decline of soil production with increasing soil depth ... freeze-thaw ... biogenic disturbance" |
| 52 | PED-001 l.32-34 | depth-to-bedrock world median 6.70 m, mean 13.09 m | shangguan2017 (INDEX 72, read) | Table 1, p.23 | FIT | World absolute DTB: mean 1,309.3 cm, median 670 cm |
| 53 | PED-001 l.35-40 | arid basins 100 +/- 17 m/Myr vs global basin mean 218 +/- 35; no significant correlation with MAP | portenga2011 (INDEX 390, read) | p.5 | FIT | "218 +/- 35 m Myr-1 (n = 1149)"; "Arid region drainage basins erode most slowly (100 +/- 17.3 m Myr-1; n = 229)"; "no significant bivariate correlation between basin erosion rates and ... MAP" |
| 54 | PED-001 l.72-74 | per-mineral laboratory rate laws | palandri2004 (INDEX 716, held) | contents pp.4-5 | FIT | section 2.1 Rate Equations; per-mineral tables of dissolution rate constants and reaction orders |
| 55 | PED-001 l.74-76 | laboratory-to-field discrepancy declining with age | white2003 (INDEX 809, held) | abstract p.1 | FIT | "correlation between decreasing reaction rates of silicate minerals and increasing duration of chemical weathering ... for both experimental and field conditions" |
| 56 | TER-003 l.50-51, 72-74 | ledger tolerance derived from FP type and summation order | higham1993 (INDEX 624, read) | section 2 | FIT | INDEX row read for the recursive, pairwise and compensated summation bounds; title and section match |
| 57 | TER-003 l.53-54, 70-71 | compensated summation for FP64 accumulators | kahan1965 (INDEX 644, held) | p.1 | FIT | "Further remarks on reducing truncation errors" on Wolfe's cascaded accumulators for S = sum y_i |
| 58 | TER-010 l.65-68, 87-89 | CF vocabulary for axes, bounds, CRS | eaton2025 CF 1.13 (INDEX 571, held) | contents p.4 | FIT | sections 5 Coordinate Systems and 7.1.1 Bounds |
| 59 | TER-010 l.90-93 | Hortal and Simmons: "why two grids that agree on every derived number can still be two conventions" | hortal1991 (INDEX 628, held) | pp.1-2 | NOT FIT (C2) | see NF-9 |
| 60 | TER-009 l.76-78 | Jensen: no moment answers a threshold share | jensen1906 (INDEX 639, held) | p.1 | FIT | as row 16 |
| 61 | TER-001 l.85-88 | intersection-area weight and which area it divides by | jones1999 (INDEX 642, held) | p.2 | FIT | the three first- and second-order remapping weights carry 1/A_k, the destination cell area |
| 62 | TER-006 l.68-71 | the argument for fixing the criterion before the result | nosek2018 (INDEX 706, held) | p.1 | FIT | prediction versus postdiction; hindsight bias makes a result "seem" predicted; an epistemic rule with no physical basis to prefer, so not C1 |
| 63 | TER-013 l.60, 97-100, 113-116 | stream-power law; steady-state slope as (U/K)^(1/n), so relief as g^(-1/n) with K ~ rho g | whipple1999 (INDEX 807, held) | eq. (20), p.6 | FIT | "S* = N_E^(1/n) U*^(1/n) x*^(-hm/n)" |
| 64 | TER-013 l.17-18, 117-120 | n = 1 is the implicit solver's form | braun2013 (INDEX 533, read) | p.5 | FIT | "For n = 1, each of these equations is linear"; Newton-Raphson otherwise |
| 65 | TER-013 l.71-72 | sediment continuity with deposition (Yuan et al. 2019 form) | yuan2019 (INDEX 822, held) | p.1 | FIT | stream power law "taking into account sediment deposition" |
| 66 | TER-013 l.76-78, 125-128 | Airy compensation of the orogen's uplift | airy1855 (INDEX 504, held) | pp.1-2 | FIT | hard crust over a denser substratum with mountains compensated below |
| 67 | TER-013 l.73-75, 129-130 | flexural isostasy | turcotte2014 Geodynamics 3rd ed. (INDEX 788, held) | chapter 3 | NOT FIT (C5) | see NF-10 |
| 68 | TER-013 l.82-84, 131-132 | Culmann limit H_c ~ 1/(rho g) | schmidt1995 (INDEX 763 held; also INDEX 117 requested) | eq. (1), p.1 | FIT (note) | Culmann eq. 1 with cohesion c, unit weight gamma, friction angle phi; INDEX carries the work twice (117 requested, 763 held) |
| 69 | TER-013 l.133-135 | Culmann height with rho g explicit | montgomery2001 (INDEX 68, read) | eq. 7 | FIT | INDEX read row: Culmann maximum stable hillslope height with rho g explicit (eq. 7) |
| 70 | TER-013 l.85-87, 136-137 | Glen's flow law, (rho g)^n explicit | glen1955 (INDEX 601, held) | p.2 | FIT | power-law creep of polycrystalline ice under 1 to 10 bar |
| 71 | TER-013 l.87, 138-139 | Weertman sliding law | weertman1957 (INDEX 805, held) | p.2 | FIT | model for the sliding velocity of a glacier over its bed |
| 72 | TER-013 l.88-89, 142-143 | abrasion end of r (no effective-pressure dependence) | hallet1979 (INDEX 900, held) | p.2 | FIT | "The effective force of contact is then independent of basal pressure and, hence, of the glacier thickness" |
| 73 | TER-013 l.89, 140-141 | quarrying end of r | iverson_2012 (INDEX 454, held) | none | NOT VERIFIED | INDEX says "PDF on disk"; no such PDF under references/pdf; Unpaywall is_oa false; paywalled |
| 74 | TER-014 l.57-59, 75-77 | the relief ceiling that is physical | schmidt1995 (INDEX 763, held) | eq. (1), p.1 | FIT | as row 68 |
| 75 | TER-017 l.84-85 | Glen's law in the shallow-ice solve | glen1955 (INDEX 601, held) | p.2 | FIT | as row 70 |
| 76 | TER-017 l.79, 86-87 | Halfar dome (C3) | halfar1983 (INDEX 611, held) | printed p.6043 | FIT | "cylindrically symmetric similarity solution" of the ice-sheet equation under Glen's flow law |
| 77 | TER-015 l.28-30 | "a published global index of 3.2x" as the rock erodibility spread | moosdorf2018 (INDEX 60, read) | abstract p.1 | NOT FIT (C3) | see NF-11 |
| 78 | TER-015 l.29-31, 87-88 | fluvially expressed contrast within one belt of about 4x | zondervan2020 (INDEX 62, read) | section 4.1, p.6; abstract p.1 | NOT FIT (C2) | see NF-12 |
| 79 | TER-015 l.39-41, 141-147 | the only broadband per-rock table is a relative albedo on fine powders | Carmichael vol. I, Hunt ch.3 Table 9 (INDEX 178, held); logan1973 (INDEX 179, held) | Table 9; Logan pp.2, 15 | FIT (note) | Table 9 column "Albedo (0.3-2.5 um)"; Logan p.15: reflectance "integrated over the entire 0.35- to 2.5-u wavelength range, and relative albedos were obtained" on the emission samples, p.2 "0-74 u"; the MgO standard and the 1.13 reading were not located |
| 80 | TER-015 l.41-44 | powder-over-slab factor median 2.74, range 2.19 to 5.11 | poseidon Paragas2025-P25 data (INDEX 169, read) | data files | NOT FIT (C2) | see NF-13 |
| 81 | TER-015 l.14-15, 81-82, 169-171 | evaporite class written by the Hardie-Eugster divide | MSA_SP3_273-290 (INDEX 78, held) | pp.5, 7 | FIT | as row 2 |
| 82 | TER-015 l.51-53 | field crusts 0.18 to 0.65 | kampf2005 (INDEX 261, held) | p.7 | FIT (note) | "Salt crusts with the highest albedos (0.44-0.66) ... More rugged crusts in the nucleus ... (0.18-0.25)"; upper end 0.66 in the source |
| 83 | TER-011 l.43-46, 78-82 | the Voronoi-Delaunay pair a C-grid needs: dual edges perpendicular to primal edges | ringler2010 (INDEX 745, held) | p.3 | FIT | edges defining mass cells and vorticity cells "are perpendicular at their intersection" |
| 84 | TER-011 l.28-30, 86-89 | two-point flux needs faces orthogonal to the generator line | eymard2000 (INDEX 578, held) | admissible mesh (iv), p.48 | FIT | the line D_KL through x_K and x_L is required orthogonal to the edge sigma = K\|L |
| 85 | TER-007 l.89-91 | Jensen at a spatial reduction | jensen1906 (INDEX 639, held) | p.1 | FIT | as row 16 |
| 86 | TER-007 l.22-24, 71, 92-94 | reduce in the exchange coefficient at the blending height | mason1988 (INDEX 145, read) | abstract p.1; p.4 | FIT | best area average z0 "would produce the correct spatial average value of the surface stress"; blending height l_b defined p.4 |
| 87 | TER-007 l.69, 98-100 | orographic drag from exact slope statistics that do not converge with resolution | beljaars2004 (INDEX 147, read) | pp.1-2 | FIT | stress "formulated in terms of a slope parameter"; slope variance "not necessarily converge asymptotically for infinitely fine orographic resolution" |
| 88 | TER-007 l.37-39, 101-103 | drag partition affine in ln z0 (the affine case) | marticorena_1995 (INDEX 216, read) | eq. (20), p.6 | FIT | f_eff = 1 - ln(Z0/z0s) / ln(0.35 (10/z0s)^0.8), affine in ln Z0 |
| 89 | TER-007 l.24-30, 104-111 | concave mixing of dry and wet albedo through a two-flux form | sadeghi2015 (INDEX 253, read) | section 2.1, p.2 | FIT | "model ... based on the Kubelka and Munk (1931) theory of reflectance", 350 to 2500 nm |
| 90 | TER-008 l.11-14, 80-82 | Penman combination evaluated on annual-mean air | penman1948 (INDEX 726, held) | pp.2, 7 | FIT | aerodynamic and energy-balance approaches combined, eliminating surface temperature |
| 91 | TER-008 l.14-15, 83-86 | weathering intensity exp(T) Q^beta, the exponential the measurement was taken on | walker1981 (INDEX 84, held) | pp.2-3 | FIT | exponential temperature dependence of weathering |
| 92 | TER-008 l.17-19 | 1.008 "two orders inside the law's own published uncertainty" | walker1981 (INDEX 84, held) | none | NOT FIT (C2) | see NF-4 |
| 93 | TER-008 l.77-79 | Jensen in time | jensen1906 (INDEX 639, held) | p.1 | FIT | as row 16 |
| 94 | TER-018 l.24-25, 101-104 | Earth standing-lake density from HydroLAKES | messager2016 (INDEX 688, held) | p.2 | FIT | "a new global data set - termed HydroLAKES ... 1.43 million individual lakes and reservoirs" at least 10 ha |
| 95 | TER-018 l.24-25, 105-107 | HydroBASINS sub-basins | lehner2013 (INDEX 669, held) | p.3 | FIT | HydroSHEDS-derived "sub-basin polygons" |
| 96 | TER-018 l.19-20, 108-110 | an absolute-age deposit class at 2.7 to 1.9 Ga | naldrett2004 (INDEX 701, held) | p.21 Table 1.2 | NOT FIT (C4) | see NF-14 |
| 97 | TER-016 l.65-67, 108-109 | the variogram as the information floor | matheron1963 (INDEX 681, held) | p.5 | FIT | "a simple mathematical tool: the variogram" |
| 98 | TER-016 l.37-39, 110-113 | self-affine topography: a gradient depends on its sampling interval | dodds2000 (INDEX 565, held) | p.5 | FIT | self-affine definition, b^-a f(bx), holding in a statistical sense; slope then scales with baseline |
| 99 | TER-016 l.32, 114-116 | the concavity relation | flint1974 (INDEX 587, held) | abstract p.1 | FIT | channel gradient "in terms of either area or discharge in the form of a power function" |
| 100 | TER-016 l.39-40, 117-120 | topographic index and the length it carries | beven1979 (INDEX 525, held) | p.8; Fig. 4 | FIT | a = "area drained per unit contour length"; log_e(a/tan beta) |
| 101 | TER-016 l.44-46, 125-126 | measured escarpment anchor on the Copernicus DEM | esa2022 handbook (INDEX 576, held); copernicus-dem-90m (INDEX 709) | predecessor analysis | FIT (note) | /home/cfutro/git/vesper/notes/audits/orogen-resolution.md l.262-268: analysis/escarpment_relief_anchor.py on the Copernicus DEM, Great Escarpment; the record's "DOI: to confirm" is resolved in INDEX as 10.5270/ESA-c5d3d65 |
| 102 | TER-002 l.11-15, 86-87 | sha256 digest | nist2015 FIPS 180-4 (INDEX 703, held) | title | FIT | Secure Hash Standard defines SHA-256 |
| 103 | TER-002 l.88-91 | "Gaussian rows are quadrature abscissae, not cell centres" | hortal1991 (INDEX 628, held) | pp.1-2 | NOT FIT (C2) | see NF-9 |
| 104 | TER-002 l.63-66, 92-94 | declared-geometry vocabulary of an export (version to pin) | eaton2025 CF 1.13 (INDEX 571, held) | contents p.4 | FIT | as row 58; the record defers the version pin to export design |

Excluded as background or listed without a use in the body (not counted): PED-008 Deocampo 2014,
Pitzer 1973; PED-011 Krissansen-Totton 2017, Amiotte Suchet 2003 beyond row 6; PED-007 van
Genuchten 1980, Saxton and Rawls 2006, Brooks and Corey 1964, Rempe and Dietrich 2018; PED-004
GLiM 2012 (vocabulary pointer); PED-005 Berner 1983; PED-003 Amiotte Suchet 2003, Stumm and Morgan
(named not held, "nothing here is taken from it"), and Helvaci 2019 (Turkish borate deposits,
listed in a soil-pH record with no use: a stray reference); PED-006 Cosby 1984; TER-003 Jones 1999;
TER-009 Koster 1992, Avissar 1989, Lawrence 2019; TER-004 Roache 1998, Salari and Knupp 2000 (no
INDEX row), Oberkampf and Roy 2010; TER-005 Jones 1999, Barnes 2020; TER-006 Oberkampf and Roy;
TER-011 Augenbaum 1985, Heikes 1995, Wan 2013; TER-012 Koster, Avissar, Lawrence, Best 2011;
TER-014 Jensen, Fritsch 1980; TER-015 Hartmann and Moosdorf 2012, Stock 1999, Sklar 2001, Bursztyn
2015, Portenga 2011, Hu 2012, Meerdink 2019, Kokaly 2017, Post 2000, Henderson-Sellers 1983, Daly
1966 (no number in the body); TER-017 Braun 1999, Egholm 2009; TER-018 Braun and Willett, Whipple
and Tucker, Barnes 2021; TER-016 Barnes 2020; TER-007 Wood and Mason 1993.

#### Not-fit cases

##### NF-1 Cosby does not state a field-capacity suction (PED-007)

- Where: docs/requirements/ped/land-column-hydraulic-contract.md l.28-31 ("`L = 1 m` reproduces
  Cosby's own field-capacity suction of 100 cm of water under Earth gravity, which is what licenses
  stating it as a length").
- Use: the basis of field capacity as a drainage equilibrium over a length L with L = 1 m.
- Source: Cosby et al. 1984, doi 10.1029/WR020i006p00682, INDEX 230 read (Table 4).
- Category: C2.
- What is wrong: Cosby defines no field capacity. The data are retention points at five tensions;
  0.1 bar (about 102 cm of water) is the wettest measured point, not a field capacity the paper
  names. The record's licence for stating field capacity as a length rests on a statement the
  source does not make.
- Evidence: cosby_1984 p.2: "moisture retention on a weight-weight basis determined at 0.1, 0.3,
  0.6, 3.0, and 15.0 bars"; "All matric potentials were converted to centimeters of water." No
  occurrence of "field capacity" in the text corpus of the paper.
- Fix class: (b). Read a primary that defines the field-capacity suction or the drainage criterion
  and restate the Bracketed drainage length's central value and ends from it; the record's frame
  check survives unchanged. Boundary: docs/requirements/ped/land-column-hydraulic-contract.md,
  docs/references/INDEX.md (a new row for the source). Acceptance: the field-capacity suction is
  quoted from a read source with its locator, and the L bracket ends are argued from it.

##### NF-2 Hartmann's soil shielding is a per-soil-class factor, not a function of thickness (PED-010)

- Where: docs/requirements/ped/phosphorus-lithology-release.md l.43-44 ("Soil shielding is a
  function of regolith thickness on the clock (Hartmann's form, Sourced, with disposition)").
- Use: the form of the shielding term the P release uses, claimed Sourced from Hartmann et al. 2014.
- Source: Hartmann et al. 2014, doi 10.1016/j.chemgeo.2013.10.025, INDEX 392 held.
- Category: C2.
- What is wrong: Hartmann's term is an average shielding factor assigned per FAO soil class, chosen
  precisely because soil depth data were missing; it is not a function of regolith thickness, so
  "Hartmann's form" cannot be Sourced as one.
- Evidence: hartmann2014 section 3.2, p.6: "sophisticated global datasets on soil depth and exact
  soil properties are missing. Thus, an average soil shielding factor was estimated for the
  following soil types from the FAO soil classification system (Fig. 4)" (Ferralsols, Acrisols,
  Nitisols, Lixisols, Histosols, Gleysols); eq. (3) carries F_S(soil properties).
- Fix class: (b). Either Source a thickness-dependent shielding law from a read primary, or state
  the term as a Closure or Bracketed factor with Hartmann's per-class values as its Earth reading.
  Boundary: docs/requirements/ped/phosphorus-lithology-release.md. Acceptance: the shielding
  form's disposition matches what the cited passage states.

##### NF-3 The Japanese maximum: wrong DOI, and not a bar basis decision 0025 accepts (PED-010)

- Where: docs/requirements/ped/phosphorus-lithology-release.md l.18-19, 50-52 and the reference at
  l.65-68.
- Use: "land yield within Hartmann and Moosdorf's range as a FAIL bar on the Earth test instance".
- Source: Hartmann and Moosdorf 2011, INDEX 393 held, doi 10.1016/j.chemgeo.2010.12.004.
- Categories: C4 (identifier), C7 (bar basis), C3 (regime).
- What is wrong: (1) the record gives DOI 10.1016/j.chemgeo.2011.05.005; the paper's own first
  page and INDEX give 10.1016/j.chemgeo.2010.12.004. (2) The range is an observed spread of
  catchment P release on one archipelago, not a published model's residual or a physical
  constraint, which is what decision 0025 accepts for a FAIL bar. (3) It is the range of a
  humid, volcanic, tectonically active region used as the bound on a global land yield.
- Evidence: hartmann2011 p.1: "doi:10.1016/j.chemgeo.2010.12.004"; abstract: "Phosphorus release
  from rocks due to chemical weathering is estimated to be between 1 kg P km-2 a-1 and 390 kg P
  km-2 a-1."
- Fix class: DOI (a), a citation correction against INDEX 393. Bar basis (b): the registry entry
  earth.hartmann_phosphorus_yield must state an admissible basis or be REPORT; registry.toml is
  edited by fiddlybits-k6b, 52v.6.26 and 52v.8.13, and its audit is another scope. The entry is
  unregistered, so no registered bar changes.

##### NF-4 The 0.65 runoff exponent: misattributed to WHAK, cited to the wrong Dunne (1978), and Peters fitted precipitation (PED-005; TER-008)

- Where: docs/requirements/ped/runoff-is-the-closed-balance.md l.12-14 and references l.66-76;
  docs/requirements/ter/nonlinear-order-in-time.md l.17-19 ("two orders inside the law's own
  published uncertainty") and reference l.83-86.
- Use: that the weathering law's runoff exponent 0.65 is WHAK's and was fitted against runoff by
  Dunne (1978) and Peters (1984); that the law has a published uncertainty.
- Sources: Walker, Hays, Kasting 1981 (INDEX 84 held); Dunne 1978 as held, "Field studies of
  hillslope flow processes" in Kirkby (ed.) Hillslope Hydrology (INDEX 566 held); Peters 1984
  USGS WSP 2228 (INDEX 727 held).
- Categories: C2 (WHAK, Peters, TER-008), C4 (Dunne: wrong work).
- What is wrong: WHAK carries no 0.65 and no uncertainty; its law is linear in runoff because it
  takes concentration as independent of runoff. The held Dunne 1978 is a hillslope flow chapter
  with no solute or denudation fit; the fit the exponent came through is a different Dunne 1978
  paper. Peters' regressions are on annual precipitation, not runoff. The predecessor's own
  corrected note says the 0.65 is Berner (1994) GEOCARB II combining Dunne's Kenyan fit with
  Peters, and that the scatter usable as the law's uncertainty is Dunne's caption S_y.x = 0.13 log
  units; neither Berner 1994 nor that Dunne paper is cited or held.
- Evidence: walker1981 p.3: concentrations "show no obvious dependence on runoff"; no "0.65" in
  the text. dunne1978 text corpus: no dissolved, solute or chemical-denudation passage; the chapter
  covers hillslope moisture, pipes and tracers (pp.70, 117). peters1984 p.18: "slopes associated
  with annual precipitation ... exponents of the back-transformed equations ... greater than
  1.0"; p.30: "yield of all constituents is an exponential function of precipitation quantity".
  /home/cfutro/git/vesper/pedology/config/pedogenesis.yaml l.33-60: "WHAK does NOT cite Dunne ...
  0.65 appears nowhere in it. WHAK's law is LINEAR in runoff"; "0.65 is Berner (1994), GEOCARB
  II, Am. J. Sci. 294(1), 56-91, doi 10.2475/ajs.294.1.56, which does cite Dunne"; "S_y.x = 0.13
  log units".
- Fix class: (b). Fetch and read Berner 1994 (open access) and Dunne 1978 Nature (paywalled),
  replace the attributions in REQ-PED-005 and REQ-TER-008, and name the uncertainty's source.
  Boundary: the two requirement files, docs/references/INDEX.md (rows for Berner 1994 and Dunne
  1978 Nature; the held hillslope chapter's anchor corrected). Acceptance: every sentence carrying
  0.65 or the law's uncertainty cites a read passage that states it.

##### NF-5 GEM-CO2 is not independent of Meybeck's Table 2C (PED-003)

- Where: docs/requirements/ped/soil-ph-from-run-pco2.md l.44-48 ("Meybeck (1987) Table 2C ... and
  independently GEM-CO2's alkalinity yields, agree to better than a factor of two") and l.90-91
  ("Sourced from two independent compilations").
- Use: two independent compilations as the basis of the base-cation supply u.
- Sources: Meybeck 1987 (INDEX 80 held); Amiotte Suchet and Probst 1995 GEM-CO2 (INDEX 81 held,
  doi 10.3402/tellusb.v47i1-2.16047; the record says "DOI: to confirm").
- Category: C2.
- What is wrong: GEM-CO2's lithology relationships are fitted on Meybeck's French monolithologic
  basins, and Meybeck's Temperate Stream Model representative analyses (Table 2C) are based on
  French streams from the same body of data. Agreement between them is agreement of one dataset
  with itself under two reductions, not an independent confirmation.
- Evidence: amiottesuchet1995 p.2: "The relationships between F_CO2 and Q were calculated using
  the data published by Meybeck (1986) concerning runoff and concentrations of the major dissolved
  elements for 232 French monolithologic drainage basins"; meybeck1987 printed p.412: "The
  proposed representative analyses are based on French streams"; p.414: the French cation
  proportion "has been preferred here ... retained in the TSM (table 2C)".
- Fix class: (b). Find a genuinely independent per-lithology alkalinity compilation (not built on
  Meybeck 1986) or restate the Sourcing as one compilation with two reductions, and complete the
  GEM-CO2 DOI from INDEX 81. Boundary: docs/requirements/ped/soil-ph-from-run-pco2.md. Acceptance:
  the record's independence claim is either supported by two sources whose data do not overlap,
  or withdrawn.

##### NF-6 The loess deposition threshold rests on a review's redrawing of a model flux (PED-009)

- Where: docs/requirements/ped/surface-classes-two-axes.md l.30-34 and reference l.99-100.
- Use: "the Sahara sits in the highest modern flux bin" and the deposition threshold 50 g/m2/yr,
  Bracketed 10 to 200, "read off one figure's before-and-after at one place".
- Source: Muhs 2013, doi 10.1016/j.aeolia.2012.08.001, INDEX 447 held.
- Category: C5.
- What is wrong: the flux bins are not measurements in Muhs; Fig. 44 is a model-derived dust flux
  redrawn from Mahowald et al. (2006). The threshold therefore stands on a secondary rendering of a
  model field, read by eye, where the use calls for measured accumulation or deposition rates. The
  qualitative trapping claim is supported.
- Evidence: muhs2013 printed p.40, Fig. 44 caption: "Model-derived global dust flux for (a) modern
  climatic conditions, and (b) during the last glacial period ... Redrawn from Mahowald et al.
  (2006)"; bins "<1 ... 100-200", axis "Model-derived flux, g/m2/yr". p.6 l.78: "there is little
  loess that accumulates in non-glacial settings, such as desert regions".
- Fix class: (b). Read Mahowald et al. 2006 for the modelled fluxes, or anchor the bracket on
  measured loess mass accumulation rates. Boundary: docs/requirements/ped/surface-classes-two-axes.md,
  docs/references/INDEX.md. Acceptance: each end of the deposition bracket is quoted from a read
  primary with its locator.

##### NF-7 Watson (1983) cited as a journal article; the held work is the thesis (PED-009)

- Where: docs/requirements/ped/surface-classes-two-axes.md l.104-105 ("Gypsum crusts in deserts.
  Watson (1983), Journal of Arid Environments 6, 3-14. DOI: to confirm").
- Use: the gypcrete climatic window.
- Source held: Watson 1983, "The origin, nature and distribution of gypsum crusts in deserts",
  D.Phil. thesis, doi 10.5287/ora-wv9z40k84, INDEX 82 held (two volumes).
- Category: C4.
- What is wrong: the reference names a different work from the one held and INDEX-listed; the
  window's numbers are verified in the thesis, not in the cited article.
- Evidence: watson1983-gypsum-crusts-deserts-vol1 p.19: gypsum crusts "are limited to areas with
  generally less than 250 mm of rainfall annually and where potential evaporation exceeds actual
  precipitation throughout the year on a monthly basis".
- Fix class: (a) in substance, a citation correction to the held thesis with locator vol. 1 p.19;
  the INDEX row is held, not read, so its status and anchor change waits for docs/references/INDEX.md
  to be free of fiddlybits-k6b.

##### NF-8 SoilGrids bias and correlation named as bars with no basis (PED-006)

- Where: docs/requirements/ped/texture-mineral-inventory-earth-score.md l.89-91 ("bias and
  correlation as bars").
- Use: a FAIL bar on the texture site oracle.
- Source: Poggio et al. 2021 SoilGrids 2.0, doi 10.5194/soil-7-217-2021, INDEX 732 held.
- Category: C7.
- What is wrong: the record states bars and gives no basis; the source supplies cross-validation
  RMSE and MEC of SoilGrids' own predictions, which describe the observation product's uncertainty,
  not a comparable published model's residual that decision 0025 requires for a FAIL bar.
- Evidence: poggio2021 p.6 l.25 and p.8 Table 4: cross-validation "root mean squared error (RMSE)
  and model efficiency coefficient (MEC)".
- Fix class: (b). The oracle entry that carries this site score states an admissible bar basis or
  is REPORT, with SoilGrids' RMSE as its observation_uncertainty. Boundary: the requirement file
  and the registry entry (registry in another scope; unregistered, so no registered bar changes).

##### NF-9 Hortal and Simmons (1991) do not state what REQ-TER-002 and REQ-TER-010 cite them for

- Where: docs/requirements/ter/support-identity-is-versioned.md l.88-91 ("Gaussian rows are
  quadrature abscissae, not cell centres"); docs/requirements/ter/conventions-by-name-index-not-coordinate.md
  l.90-93 ("Why two grids that agree on every derived number can still be two conventions").
- Source: Hortal and Simmons 1991, doi 10.1175/1520-0493(1991)119<1057:UORGGI>2.0.CO;2, INDEX 628 held.
- Category: C2.
- What is wrong: the paper is about reducing the number of points on Gaussian latitudes near the
  poles and its effect on accuracy and stability; it does not state that Gaussian rows are
  quadrature abscissae rather than cell centres, nor the conventions argument.
- Evidence: hortal1991 abstract p.1: the Gaussian grid "is reduced as the poles are approached"
  with savings "in excess of one-third"; p.2: the reduced grid's points "form a subset of the
  points of the standard Gaussian grid"; no occurrence of "quadrature" anywhere in the text corpus
  of the paper. No INDEX row names Gauss-Legendre quadrature.
- Fix class: (b). Cite a read source that states Gaussian latitudes are Gauss-Legendre quadrature
  nodes with weights (a spectral-transform primary), and drop Hortal from REQ-TER-010 or restate
  what it supports. Boundary: the two requirement files, docs/references/INDEX.md. Acceptance: each
  sentence cites a passage that states it.

##### NF-10 A textbook stands for the flexural-isostasy law (REQ-TER-013)

- Where: docs/requirements/ter/gravity-enters-through-the-law.md l.73-75, 129-130.
- Use: "Flexural isostasy from the densities and the crustal thickness ... Bracketed", anchored to
  Turcotte and Schubert (2014) "Flexural isostasy".
- Source: Turcotte and Schubert, Geodynamics third edition, doi 10.1017/CBO9780511843877, INDEX 788 held.
- Category: C5.
- What is wrong: a textbook chapter stands for the plate-flexure law, where the project's rule
  anchors every law to a read primary; no primary for thin-plate flexure of the lithosphere is cited.
- Evidence: turcotte2014 p.7 contents: "3 Elasticity and Flexure ... Two-Dimensional Bending or
  Flexure of Plates".
- Fix class: (b). Anchor the flexure equation and the elastic-thickness relation to a read primary,
  or record the textbook section as the accepted derivation with its locator. Boundary:
  docs/requirements/ter/gravity-enters-through-the-law.md, docs/references/INDEX.md.

##### NF-11 Moosdorf's 3.2 is unconsolidated sediment on a hillslope index, not a rock erodibility spread (REQ-TER-015)

- Where: docs/requirements/ter/lithology-class-denotes-a-rock.md l.28-30 ("14x from quartzite to
  salt against a published global index of 3.2x").
- Use: the published spread the predecessor's rock erodibility contrast is judged too wide against,
  and (INDEX 60 anchor) "k_e bracketed from expressed lithology contrast ... (1.0 to 3.2)".
- Source: Moosdorf, Cohen, von Hagke 2018, doi 10.1016/j.apgeog.2018.10.010, INDEX 60 read.
- Category: C3.
- What is wrong: the 3.2 end is the class of unconsolidated sediments, not a rock; among
  consolidated classes the index spans 1.0 to 1.5. The index is built from hillslope gradients
  relative to acid plutonics, a sediment-production potential, not a fluvial bedrock erodibility,
  so it is a different regime from the incision law's k_e contrast.
- Evidence: moosdorf2018 abstract p.1: "based on the relative hillslope compared to that of acid
  plutonic rocks"; "1.0 for acid plutonic rocks, metamorphic rocks, and carbonate sedimentary rocks,
  1.1 for acid volcanic rocks, 1.2 for mixed sedimentary rocks; medium erodibility - 1.5 for basic
  plutonic rocks and siliciclastic rocks of all grain sizes, 1.4 for basic volcanic rocks; high
  erodibility - 3.2 for unconsolidated sediments".
- Fix class: (b). Restate the comparison with the consolidated-rock range and name the index's
  regime, or drop it from the k_e bracket argument; the INDEX 60 anchor needs the same correction.
  Boundary: the requirement file, docs/references/INDEX.md (blocked by fiddlybits-k6b). A change to
  the k_e Bracketed ends, if any has been declared from this reading, is a disposition question for
  the user.

##### NF-12 Zondervan's ksn contrast is 4 to 15 depending on n, not about 4 (REQ-TER-015)

- Where: docs/requirements/ter/lithology-class-denotes-a-rock.md l.29-31 ("a fluvially expressed
  contrast within one mountain belt of about 4x").
- Use: the expressed contrast the erodibility bracket is drawn from.
- Source: Zondervan et al. 2020, doi 10.1016/j.epsl.2020.116221, INDEX 62 read.
- Category: C2.
- What is wrong: the paper gives the ksn-based normalised K contrast as four to fifteen, the ends
  set by the slope exponent; "about 4x" is the n = 1 end only, while REQ-TER-013 sweeps n. The
  UCS-based contrast is up to two orders of magnitude.
- Evidence: zondervan2020 section 4.1, p.6: "Fluvial erodibility K values ... vary by a factor of
  four to fifteen (Fig. 4d) ... depending whether n = 2 or n = 1"; crystalline basement "about four
  to fifteen times less erodible"; abstract p.1: "up to two orders of magnitude".
- Fix class: (a), a number correction against the read source (state 4 to 15 with its n
  dependence) in the requirement; the INDEX 62 anchor carries "about a factor 4 by ksn" and needs
  the same correction once INDEX.md is free.

##### NF-13 The powder-over-slab factor 2.74 is not reproduced from the held Paragas data (REQ-TER-015)

- Where: docs/requirements/ter/lithology-class-denotes-a-rock.md l.41-44 ("a powder-over-slab
  factor of median 2.74, range 2.19 to 5.11").
- Use: the rule that powder ratios never cross the felsic-mafic contrast, and the slab floor.
- Source: POSEIDON Paragas2025-P25 reflectance files, INDEX 169 read ("median 2.74").
- Category: C2 (value not reproducible under a stated reduction).
- What is wrong: the reduction behind 2.74 is not recorded, and the plain reductions of the held
  data do not give it.
- Evidence: 9 rocks with both slab and powder files under
  /home/cfutro/git/fiddlybits/references/poseidon_surface_albedo/Paragas2025-P25/. Ratio of mean
  powder to mean slab reflectance over 0.4-2.5 um: median 2.26, range 1.76 to 4.16; over 0.4-1.0
  um: 2.28, 1.70 to 4.09; per-wavelength ratio, median over wavelengths: 2.28, 1.70 to 4.41.
- Fix class: (b). Record the reduction (band, weighting, rock set) that yields the factor, or
  recompute and restate it with its reduction; the INDEX 169 anchor follows. Boundary: the
  requirement file, a finding under notes/findings/, docs/references/INDEX.md.

##### NF-14 Naldrett (2004) cited for the 2.7 to 1.9 Ga class; the read source is Naldrett (2010) (REQ-TER-018)

- Where: docs/requirements/ter/snapshot-carries-ages-and-rates.md l.19-20 and reference l.108-110.
- Use: "a control keyed on an absolute age (a deposit class at 2.7 to 1.9 Ga)".
- Source cited: Naldrett 2004, Magmatic Sulfide Deposits, INDEX 701 held. Read source: Naldrett
  2010, doi 10.2113/gsecongeo.105.3.669, INDEX 100 read.
- Category: C4.
- What is wrong: the age range is stated in Naldrett 2010's abstract; it was not located in the
  2004 book, which classifies the komatiite-related class (NC-1) without that range in the passages
  read.
- Evidence: naldrett2010 abstract p.1 (printed p.669): "the komatiite-related class ranges from 2.7
  to 1.9 Ga in age"; naldrett2004 p.21: "Class NC-1 (Chap. 3) comprises those related to komatiitic
  magmatism"; no "1.9" in the book's text corpus.
- Fix class: (a). Replace the reference with Naldrett 2010, abstract p.669 (INDEX 100, read).

#### Other observations in scope (no verdict change)

- INDEX rows that name a PDF not on disk: chadwick_2003 (INDEX 486, "held") and iverson_2012
  (INDEX 454, "PDF on disk"). Neither file exists under references/pdf. For the INDEX scope.
- INDEX carries Schmidt and Montgomery 1995 twice: row 117 "requested" and row 763 "held". For the
  INDEX scope.
- INDEX 178 (Hunt Table 9) gives the albedo band as 0.35 to 2.5 um; the table header reads
  0.3-2.5 um and Logan's measurement 0.35-2.5 um.
- Reference completeness: REQ-PED-003 gives GEM-CO2 "DOI: to confirm" (INDEX 81 has it);
  REQ-TER-016 gives the Copernicus DEM "DOI: to confirm" (INDEX 576 has 10.5270/ESA-c5d3d65);
  REQ-PED-001 gives Chadwick 2003 "to confirm" (INDEX 486 has 10.1016/j.chemgeo.2002.09.001).
- REQ-PED-003 lists Helvaci 2019 (Turkish borate deposits) with no use in the record.

#### Fetches and paywalled sources

- Fetch attempted once: Berner, R. A. (1994), "GEOCARB II: a revised model of atmospheric CO2 over
  Phanerozoic time", American Journal of Science 294(1), 56-91, doi 10.2475/ajs.294.1.56 (Unpaywall
  is_oa true, https://ajs.scholasticahq.com/article/60629.pdf). The download returned a one-page
  PDF with no text for 0.65, Dunne or Peters: fetch failed. Saved at
  scratchpad/audit/fetch-Q5/berner1994.pdf.
- Paywalled (Unpaywall is_oa false), for the user:
  - "Rates of chemical denudation of silicate rocks in tropical catchments", Dunne, T. (1978),
    Nature 274, 244-246, doi 10.1038/274244a0.
  - "The impact of climate on the biogeochemical functioning of volcanic soils", Chadwick et al.
    (2003), Chemical Geology 202, 195-223, doi 10.1016/j.chemgeo.2002.09.001 (INDEX says held; not
    on disk).
  - "A theory of glacial quarrying for landscape evolution models", Iverson, N. R. (2012), Geology
    40(8), 679-682, doi 10.1130/G33079.1 (INDEX says held; not on disk).
- Not fetched, needed by NF-6: Mahowald et al. (2006), the model dust flux Muhs Fig. 44 redraws
  (verbatim title and identifier to be confirmed before a fetch).

### I: Imports


Audited on the worktree at 625832c (main). Read-only.

#### What was counted

A citation here is any locator a record uses to anchor a claim about what a dependency
carries or does, or a law, constant or scheme it says the package carries:

- a package source locator with a file and a line or line range (checked in the installed
  source at the Manifest version for adopted packages, or with `git show <commit>:<path>` at
  the commit the record names for surveyed trees);
- a version, commit or pin statement (checked against the tree's Project.toml at that commit,
  or Project.toml [compat] and Manifest.toml for adopted packages);
- a paper or dataset the record cites, or an attribution the record says the package makes
  (checked in the held text under references/text/, and in the package docstring at the commit).

A cuda.md bullet carrying several line ranges on one claim is one row; the row's line ranges
were each opened (about 110 line ranges in cuda.md). A bare file path with no line, used only
to say where a behaviour was read, is not counted. Internal pointers (decisions, findings,
tests) are not sources and are not counted.

#### Counts

| file | citations | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| README.md | 1 | 1 | 0 | 0 |
| acceleratedkernels-jl.md | 1 | 1 | 0 | 0 |
| adapt.md | 1 | 0 | 1 | 0 |
| astrolib-jl.md | 5 | 5 | 0 | 0 |
| bracketingnonlinearsolve-jl.md | 4 | 4 | 0 | 0 |
| cgdycore-jl.md | 11 | 11 | 0 | 0 |
| clima-organisation-sweep.md | 1 | 1 | 0 | 0 |
| clima-output-and-tooling.md | 1 | 1 | 0 | 0 |
| climacomms-jl.md | 1 | 1 | 0 | 0 |
| climacore-jl.md | 1 | 1 | 0 | 0 |
| climacoupler-jl.md | 1 | 1 | 0 | 0 |
| climaland-jl.md | 2 | 2 | 0 | 0 |
| climaocean-jl.md | 2 | 2 | 0 | 0 |
| climaparams-jl.md | 1 | 1 | 0 | 0 |
| climaseaice-jl.md | 3 | 2 | 1 | 0 |
| climatimesteppers-jl.md | 2 | 2 | 0 | 0 |
| cloudmicrophysics-jl.md | 2 | 2 | 0 | 0 |
| combinatorialspaces-jl.md | 1 | 1 | 0 | 0 |
| cuda.md | 34 | 34 | 0 | 0 |
| dimensionaldata-jl.md | 1 | 1 | 0 | 0 |
| doublefloats-jl.md | 1 | 1 | 0 | 0 |
| dynamicquantities.md | 1 | 0 | 1 | 0 |
| exit-criteria-instruments.md | 1 | 1 | 0 | 0 |
| fastpower-jl.md | 1 | 1 | 0 | 0 |
| insolation-jl.md | 3 | 3 | 0 | 0 |
| jet-jl.md | 1 | 1 | 0 | 0 |
| julia-1.12.md | 1 | 1 | 0 | 0 |
| kernelabstractions.md | 5 | 5 | 0 | 0 |
| mesharrays-and-climatemodels.md | 1 | 1 | 0 | 0 |
| ncdatasets.md | 1 | 1 | 0 | 0 |
| oceananigans-jl.md | 1 | 1 | 0 | 0 |
| precompiletools.md | 1 | 1 | 0 | 0 |
| rootsolvers-jl.md | 8 | 6 | 2 | 0 |
| rrtmgp-jl.md | 5 | 5 | 0 | 0 |
| seawaterpolynomials-jl.md | 17 | 16 | 1 | 0 |
| sha-uuids.md | 1 | 1 | 0 | 0 |
| speedyweather-reference-arm.md | 1 | 1 | 0 | 0 |
| staticarrays-jl.md | 1 | 1 | 0 | 0 |
| structarrays-jl.md | 1 | 1 | 0 | 0 |
| surfacefluxes-jl.md | 7 | 7 | 0 | 0 |
| thermodynamics-jl.md | 3 | 3 | 0 | 0 |
| zarr.md | 2 | 2 | 0 | 0 |
| **total** | **140** | **134** | **6** | **0** |

The 6 not-fit sites are 5 cases (rootsolvers-jl.md states one false claim at two sites).
None is in a file an open branch edits except as noted: cuda.md and zarr.md are edited by
fiddlybits-52v.6.26, and every citation in them is fit.

#### Every citation

| where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| README.md:25 | the review checklist carried from the predecessor | /home/cfutro/git/vesper/notes/external-tree-checklist.md (archive, not INDEX) | path | FIT | file exists, 204 lines; rows A1, A3, D4 read at lines 60, 62, 100 match the items the record carries |
| acceleratedkernels-jl.md:16 | version read | AcceleratedKernels.jl tree | 0.4.3 at 0287c81c | FIT | commit exists; Project.toml version 0.4.3 |
| adapt.md:14 | version | Project.toml, Manifest.toml | "Version. `to pin`" | NOT FIT (C4, stale) | Project.toml [compat] Adapt = "4.7.0", Manifest 4.7.0; the convention in precompiletools.md, jet-jl.md, ncdatasets.md calls a compat entry "pinned" |
| astrolib-jl.md:24-25 | AstroLib's kepler_solver implements Markley 1995, cited in its docstring | markley1995-kepler-equation-solver.pdf (read), 10.1007/BF00691917 | docstring | FIT | src/kepler_solver.jl@288bcfd lines 78-80 cite Markley (1995) CMDA with the DOI |
| astrolib-jl.md:26-29 | starting value from eqs 20, 5, 9, 10, 14, 15; corrections 21-29 | Markley 1995 (read) | eq numbers | FIT | kepler_solver.jl@288bcfd comments "equation (20)", "(5)", "(9)", "(10)", "(14)", "(15)", then (26)&(27), (21), (25), (22), (23), (24)&(28), "equation 29"; the eqs are numbered so in the held text pp. 6-8 |
| astrolib-jl.md:19-21, 141 | eqs 30-35 on the paper's last pages make it accurate near e = 1; AstroLib omits them | Markley 1995 (read) | eqs 30-35 | FIT | held text p. 9: "(25) is replaced by ... (30)", "replace equation (21) by f(E)=M*(e,E)-M (31)", Pade approximant (33); p. 10 "(35) ... over the entire range of eccentricity"; p. 11 is the reference list; kepler_solver.jl carries no eq 30-35 |
| astrolib-jl.md:11-12 | read at | AstroLib.jl tree | 288bcfd, "the tree's own" version | FIT | commit exists; Project.toml 0.4.5 |
| astrolib-jl.md:150-152 | reference entry, read, held path | Markley 1995 (read) | INDEX row | FIT | INDEX.md line 29, status read, anchors the algorithm and eqs 30-35. Note: the held copy is the NASA technical report (text p. 1 "N95-27767 ... Goddard"), which the INDEX row discloses; the eq numbers the package takes from the CMDA article agree with it |
| bracketingnonlinearsolve-jl.md:12 | version read | NonlinearSolve.jl tree | 1.12.6 at 0dccd34d | FIT | lib/BracketingNonlinearSolve/Project.toml version 1.12.6 at that commit |
| bracketingnonlinearsolve-jl.md:33 | the non-straddling-bracket message | tree | bisection.jl:45 | FIT | line 44 `if sign(fl) == sign(fr)`, line 45 `@SciMLMessage(` |
| bracketingnonlinearsolve-jl.md:33 | same in ITP | tree | itp.jl:82 | FIT | line 81 `if sign(fl) == sign(fr)`, line 82 `@SciMLMessage(` |
| bracketingnonlinearsolve-jl.md:6, 54 | ITP is Oliveira and Takahashi's, the docstring cites the DOI | tree docstring | itp.jl | FIT | itp.jl lines 10-11: "(https://doi.org/10.1145/3423597) by I. F. D. Oliveira and R. H. C. Takahashi" |
| cgdycore-jl.md:17 | version read | CGDycore.jl tree | 0.1.0 at 9dfd007f | FIT | Project.toml 0.1.0 |
| cgdycore-jl.md:106 | second copy of the Earth block in PhysParameters | tree | src/DyCore/GlobalVariables.jl:220 | FIT | line 220 `function PhysParameters{FT}(;ScaleFactor=FT(1))`, 221 `RadEarth::FT = 6.37122e+6`, 222 `Grav::FT = 9.80616` |
| cgdycore-jl.md:115 | RadEarth unscaled | tree | line 221 | FIT | as above |
| cgdycore-jl.md:115 | ScaleFactor applied to Omega only | tree | line 239 | FIT | line 239 `Omega::FT = 2 * pi / 24.0 / 3600.0 * ScaleFactor` |
| cgdycore-jl.md:108 | third copy | tree | src/Examples/parameters.jl 94, 398 | FIT | line 94 `RadEarth::FT = 6.37122e+6`, line 398 `RadEarth = 6.37122e+6` |
| cgdycore-jl.md:113 | help text | tree | src/Parameters/parse_commandline.jl:401 | FIT | line 401 `help = "ScaleFactor for EarthRadius"` |
| cgdycore-jl.md:117 | driver builds Phys | tree | Examples/DriverCG.jl:189 | FIT | line 189 `Phys = DyCore.PhysParameters{FTB}(;ScaleFactor)` |
| cgdycore-jl.md:119-126, 264 | driver scales a local radius; RadEarth read at 318 | tree | DriverCG.jl, "129 lines later", :318 | FIT (note) | lines 316-319: `if RadEarth == 0.0` / `RadEarth = Phys.RadEarth` / `if ScaleFactor != 0.0` / `RadEarth = RadEarth / ScaleFactor`; the read of Phys.RadEarth is line 317, one line above the locator |
| cgdycore-jl.md:129, 264 | gravitation reads the unscaled radius | tree | src/Sources/gravitation.jl:91 | FIT | line 91 `...;RadEarth=P.RadEarth)` |
| cgdycore-jl.md:260 | 6371e3 literal | tree | src/IMEXRosenbrock/HeVi.jl:57 | FIT | line 57 `create_node(6371e3, 0.0, z)` |
| cgdycore-jl.md:153 | the only day is a Held-Suarez relaxation | tree | src/Sources/forcing.jl | FIT | lines 4, 13-14: `day_to_sec = 86400.0`, `ka = 1.0 / (40.0 * day_to_sec)`, `ks = 1.0 / (4.0 * day_to_sec)` |
| clima-organisation-sweep.md:100 | SeawaterPolynomials version | tree | 0.3.10 | FIT | Project.toml 0.3.10 at 18f3797f |
| clima-output-and-tooling.md:150-152 | versions on main | ClimaDiagnostics, ClimaAnalysis, ClimaUtilities trees | 0.3.9, 0.5.23, 0.1.32 | FIT | HEAD Project.toml 0.3.9, 0.5.23, 0.1.32 (no commit named) |
| climacomms-jl.md:93-95 | version read | ClimaComms.jl | 5e2d0328, 0.6.11 | FIT | commit exists; 0.6.11 |
| climacore-jl.md:142-143 | version read | ClimaCore.jl | 25f0906c, v0.16.1 | FIT | commit exists, tag v0.16.1 points at it, 0.16.1 |
| climacoupler-jl.md:128 | version on main | ClimaCoupler.jl | 0.2.3 | FIT | HEAD 0.2.3 (no commit named) |
| climaland-jl.md:128-129 | version read | ClimaLand.jl | c865270a, 1.12.1 | FIT | 1.12.1 |
| climaland-jl.md:83-87 | Earth pedotransfer maps loaded by name | tree | src/standalone/Soil/spatially_varying_parameters.jl | FIT | line 93 "van Genuchten data product from Gupta et al 2020", 142 `vGalpha_map_gupta_etal2020`, 236 `rosetta_soil_vangenuchten_parameters`, 360 "based on SoilGrids", 13 `clm_soil_albedo_parameters` |
| climaocean-jl.md:87-88 | version read | ClimaOcean.jl | 940e5515, 0.10.0 | FIT | 0.10.0 |
| climaocean-jl.md:73 | KPP parameter file's first line | tree | src/OMIPConfigurations/KPP/kpp_parameters.jl:1 | FIT | "# KPP parameters with calibrated Large 1994 / MITgcm defaults." |
| climaparams-jl.md:10, 189 | version read | ClimaParams.jl | 300c657a, 1.1.9 | FIT | 1.1.9 |
| climaseaice-jl.md:120-121 | version read | ClimaSeaIce.jl | 5a5b97fa, 0.5.8 | FIT | 0.5.8 |
| climaseaice-jl.md:76-78 | concentration rule cites Hibler 1979 | tree | slab_sea_ice_thermodynamics.jl | FIT | line 9 "introduced by [Hibler 1979]", line 14 the reference; thermodynamic_time_step.jl:357 "following Hibler (1979)" |
| climaseaice-jl.md:52-67 | what the Winton three-layer scheme carries: the liquidus inside the upper layer's heat capacity and inside the conductivity, so brine pockets conduct differently as the ice warms | winton2000-reformulated-three-layer-sea-ice.pdf (held), 10.1175/1520-0426(2000)017<0525:ARTLSI>2.0.CO;2 | "Winton's whole contribution" | NOT FIT (C2) | Winton 2000 p. 3 (text 0003.txt lines 108-111): "As in the Semtner model, the ice conductivity is assumed to be constant rather than a function of temperature and salinity, as it is in more sophisticated models (Maykut and Untersteiner 1971; Bitz and Lipscomb 1999)"; Table 1 lists sea-ice conductivity 2.03 W m-1 C-1. The heat-capacity half is supported (abstract, p. 1: "the brine content of the upper ice is represented with a variable heat capacity") |
| climatimesteppers-jl.md:147-149 | version read | ClimaTimeSteppers.jl | 2c9d9b9f, 0.10.7 | FIT | 0.10.7 |
| climatimesteppers-jl.md:88-90 | SSP33ShuOsher, Wicker-Skamarock steppers carried | tree | src | FIT | explicit_tableaus.jl:2 exports `SSP22Heuns, SSP33ShuOsher, RK4`; ClimaTimeSteppers.jl:210 includes `solvers/wickerskamarock.jl` |
| cloudmicrophysics-jl.md:123-124 | version read | CloudMicrophysics.jl | 62003325, 0.39 | FIT | 0.39 |
| cloudmicrophysics-jl.md:61, 71 | Chen 2022 fall speeds and Seifert-Beheng scheme carried | tree | src | FIT | Common.jl:23 `export Chen2022_vel_coeffs`; BulkMicrophysicsTendencies.jl:79, 825 "Seifert-Beheng 2006" |
| combinatorialspaces-jl.md:17 | version read | CombinatorialSpaces.jl | 6ed8acf4, 0.10.1 | FIT | 0.10.1 |
| cuda.md:26-28 | versions | Manifest.toml | CUDA 6.3.1, CUDACore 6.3.1, GPUCompiler 2.6.0, Julia 1.12.7 | FIT | Manifest CUDA 6.3.1, CUDACore 6.3.1, GPUCompiler 2.6.0; julia 1.12.7; installed CUDACore/9QPrM, GPUCompiler/wym4d, GPUToolbox/9Elch 3.0.0 |
| cuda.md:44-46 | KA launch calls kernel_compile | CUDACore src/CUDAKernels.jl | 111-127 | FIT | line 111 `function (obj::KA.Kernel{CUDABackend})`, 125 `kernel_call`, 126 `kernel_compile(call; always_inline=..., maxthreads)` |
| cuda.md:47-51 | kernel_compile to cufunction to compile_or_lookup | CUDACore src/compiler/execution.jl | 145-148, 65-66, 675-681 | FIT (note) | 145-148 `kernel_compile(call::KernelCall)` builds tt; 65-66 `kernel_compile(::LLVMBackend, ...) = cufunction`; 675-681 cufunction builds `CompilerJob(source, config)`; the `compile_or_lookup(job)` call is line 683, two lines past the range |
| cuda.md:52-57 | compile_or_lookup, compile, _compiler_config | CUDACore src/compiler/compilation.jl | 572-575, 378-383, 237-317, 317 | FIT | 572 function, 575 `compiled = compile(job)`; 382 `invoke_frozen(GPUCompiler.compile, :asm, job)`; 237 `_compiler_config(dev; kernel=true, ..., kwargs...)`; 317 `CompilerConfig(target, params; kernel, name, always_inline)` |
| cuda.md:58-61 | validate defaults and the non-toplevel copy | GPUCompiler src/interface.jl | 173-179, 203-211 | FIT | 174-179 signature `toplevel=true ... validate=toplevel`; 206-210 `if !toplevel ... validate = false` |
| cuda.md:62-66 | check_method, check_invocation, check_ir | GPUCompiler src/driver.jl | 64-73, 422-426 | FIT | 64 compile_unhooked; 70 `check_method(job)`, 71 `job.config.validate && check_invocation(job)`; 422-424 inside emit_llvm (lines 176-446): `if job.config.toplevel && job.config.validate` / `check_ir(job, ir, relocations)` |
| cuda.md:67-75 | what check_ir records | GPUCompiler src/validation.jl | 165-173, 175-184, 186-196, 224-358, 133, 255-267, 268-285, 286-296, 314-328 | FIT | 133 `DYNAMIC_CALL = "dynamic function invocation"`; 165-173 throws InvalidIRError; 175-184 loop over functions; 186-196 over CallInst; 224 CallInst check; 255 `tojlinvoke`; 268 `jl_invoke`/`ijl_invoke`; 286 `jl_apply_generic`; 314-328 libjulia symbol pushes RUNTIME_FUNCTION |
| cuda.md:84-88 | lower_throw! erases throw arguments, not the computing call | GPUCompiler src/irgen.jl | 166-230, 205-218 | FIT (note) | 166 function lower_throw!; 206-219 the HACK loop erasing unused call args; function ends 231 |
| cuda.md:91-93 | non-bits kernel argument refused | GPUCompiler src/validation.jl | 75-115, 103-111 | FIT | 75 check_invocation; 103-111 `if !isbitstype(dt) throw(KernelError(...))` |
| cuda.md:97-103 | union splitting limits | Compiler/src/abstractinterpretation.jl | 342-349, 352-353, 385-397 | FIT | 342 find_method_matches; 352-353 `1 < unionsplitcost(...) <= max_union_splitting`; 385 find_simple_method_matches, `FailedMethodMatch("Too many methods matched")` |
| cuda.md:104-107 | GPUCompiler leaves inference limits default | GPUCompiler src/interface.jl | 615-621, 629-630 | FIT | 615-621 `CC.InferenceParams()` on 1.12; 629-630 `CC.OptimizationParams(; compilesig_invokes=false)` |
| cuda.md:111-113 | box lowered to gc_pool_alloc, a device malloc | GPUCompiler src/optim.jl, src/runtime.jl | 556, 190-199 | FIT | optim.jl 556 `call!(builder, Runtime.get(:gc_pool_alloc), [sz])`; runtime.jl 190-197 `gc_pool_alloc` calls `malloc(sz)` |
| cuda.md:115-116 | check_invocation requires a dispatch tuple | GPUCompiler src/validation.jl | 80 | FIT | line 80 `Base.isdispatchtuple(tt) || error(...)` |
| cuda.md:135-140 | compile_hook is a ScopedValue called per job; cached launch takes the compile path when hooked | GPUCompiler src/GPUCompiler.jl, src/driver.jl; CUDACore compilation.jl | 49-66, 66, 57-60, 574 | FIT | GPUCompiler.jl 66 `const compile_hook = ScopedValue{...}(nothing)`; driver.jl 58-59 `if compile_hook[] !== nothing; Base.invokelatest(compile_hook[], job)`; compilation.jl 574 `... || GPUCompiler.compile_hook[] !== nothing` |
| cuda.md:141-147 | get_interpreter, cache_owner, code_typed, code_typed_by_type | GPUCompiler interface.jl, reflection.jl; base reflection.jl | 380-387, 438, 199-212, 293-325 | FIT | interface.jl 380-387 GPUInterpreter(...owner=cache_owner(job), inf_params, opt_params, always_inline); 438 `cache_owner(job) = job.config.cache_owner`; reflection.jl 199-212 `Base.code_typed_by_type(sig; interp, kwargs...)`; base reflection.jl 293 `optimize::Bool=true`, `typeinf_code` |
| cuda.md:148-150 | code_llvm of a job | GPUCompiler src/reflection.jl, src/optim.jl | 263-280, 556 | FIT | 263 `code_llvm(io, job; ... dump_module ...)`; optim.jl 556 as above |
| cuda.md:151-159 | what code_warntype highlights | stdlib InteractiveUtils codeview.jl; Compiler ssair/show.jl; base runtime_internals.jl | 30-43, 37, 896-903, 164-171, 918-921 | FIT | codeview.jl 37 `!Base.isdispatchelem(type) || type == Core.Box`; show.jl 164-171 should_print_ssa_type excluding the listed nodes; 896-903 stmts_used; runtime_internals.jl 918-921 isdispatchelem |
| cuda.md:160-163 | CPU specializations | base runtime_internals.jl | 1661 | FIT | line 1661 `specializations(m::Method) = MethodSpecializations(...)` |
| cuda.md:192-195 | pointer copy queued with async | CUDACore lib/cudadrv/memory.jl | 417-430 | FIT | 418-430 `unsafe_copyto!(dst::Ptr, src::CuPtr, N; stream=stream(), async=false)` calls `cuMemcpyDtoHAsync_v2` then `async || synchronize(stream)` |
| cuda.md:196-202 | Base.copyto! into Array synchronizes | CUDACore src/array.jl | 610-627, 557-569, 617, 620, 593-595, 613-616 | FIT | 557 copyto!(dest::Array, ...) calls unsafe_copyto!; 610 unsafe_copyto!(dest::Array, doffs, src::DenseCuArray...); 617 `synchronize(src)`; 620 `async=false`; 593-595 and 613-616 the unpinned-memory comments |
| cuda.md:203-205 | stream() is task-local | CUDACore lib/cudadrv/state.jl | 289-298 | FIT | 289 `@inline function stream(state=task_local_state!())`, creates on first use |
| cuda.md:206-210 | launches on stream() | CUDACore src/compiler/execution.jl; src/CUDAKernels.jl | 411-416, 111-127 | FIT | 411-416 managed_kernel_launch `target_stream = haskey(kwargs, :stream) ? kwargs[:stream] : stream()`, `with_managed` |
| cuda.md:211-218 | pointer conversion takes ownership | CUDACore src/array.jl, src/memory.jl | 417-426, 467-468, 650-660, 597-648, 631-634 | FIT | array.jl 417 pointer, 467 unsafe_convert; memory.jl 650 `Base.convert(::Type{CuPtr{T}}, managed::Managed)` calls take_ownership!; 597 take_ownership!; 631-633 `if managed.stream != stream; maybe_synchronize(managed); managed.stream = stream`; maybe_synchronize (586-592) tests `managed.synchronizing && (dirty || captured)` |
| cuda.md:219-221 | pool_free against the owning stream | CUDACore src/memory.jl | 770-800 | FIT | 775 pool_free; `_pool_free(mem, managed.stream)` |
| cuda.md:225-231 | pin, __pin, register, __unpin, unregister | CUDACore lib/cudadrv/memory.jl | 683-707, 734-757, 171-177, 172, 702-704, 758-775, 184-186 | FIT | 683 pin; 701 `__pin(ptr, sizeof(a))`; 702-704 finalizer `__unpin`; 734 __pin calls `register(HostMemory, ptr, sz)` on first count; 171-172 register throws ArgumentError on empty range; 758 __unpin calls unregister at zero; 184-186 unregister `cuMemHostUnregister` |
| cuda.md:232-234 | is_pinned | CUDACore lib/cudadrv/memory.jl | 858-871 | FIT | POINTER_ATTRIBUTE_MEMORY_TYPE; ERROR_INVALID_VALUE gives false; CU_MEMORYTYPE_HOST gives true |
| cuda.md:235-237 | finalize runs finalizers now | base gcutils.jl | 102 | FIT | line 102 `finalize(@nospecialize(o)) = ccall(:jl_finalize_th, ...)` |
| cuda.md:241-242 | record on task stream | CUDACore lib/cudadrv/events.jl | 45-46 | FIT | `record(e::CuEvent, stream::CuStream=stream()) = cuEventRecord(e, stream)` |
| cuda.md:243-251 | event synchronize path | CUDACore lib/cudadrv/synchronization.jl | 217-229, 77-97, 158-183, 113-156, 3-4 | FIT | 3-4 preference default true; 77-97 spins < 256 with pause below 32, so 32 pauses then 224 yields; 217-229 event form; 158-183 nonblocking_synchronize `put!(chan, val)` |
| cuda.md:252-259 | stream form checks exceptions, event form and wait do not | synchronization.jl, CUDAKernels.jl, array.jl, memory.jl, events.jl | 201-215, 214, 28, 494, 580-584, 78-79 | FIT | 214 `check_exceptions()`; event form 217-229 has none; CUDAKernels.jl 28 `KA.synchronize(::CUDABackend) = synchronize()`; array.jl 494 `synchronize(x::CuArray)`; memory.jl 580-584 `synchronize(managed.stream)`; events.jl 78-79 `cuStreamWaitEvent` |
| cuda.md:263-265 | device throw sets status and exits | CUDACore src/device/runtime.jl | 190-207, 200, 204 | FIT | 200 `info.status = 1`; 204 `exit()` |
| cuda.md:266-271 | exception record per context, cleared by first check | CUDACore src/compiler/exceptions.jl | 16-26, 29-43, 34, 38 | FIT (note) | 16 `const exception_infos = Dict{CuContext, HostMemory}()`; 29 check_exceptions; 34 `unsafe_store!(exception_info, ExceptionInfo_st())`; 38 `throw(KernelException(dev))`; function ends 42 |
| cuda.md:272-284 | API errors of the wait | CUDACore lib/cudadrv/libcuda.jl; GPUToolbox src/ccalls.jl; memory.jl; error.jl; synchronization.jl | 5463-5466, 19-45, 34-40, 26-32, 413, 32, 158-183, 179 | FIT (note) | libcuda.jl 5463 `@checked function cuStreamSynchronize`; ccalls.jl 19-45 `@checked` wraps the body in `check() do`; `check` (34-40) and `throw_api_error` (26-32) are in CUDACore lib/cudadrv/libcuda.jl, which the bullet names first, not in ccalls.jl, which the sentence names last; memory.jl 413 `struct OutOfGPUMemoryError`; error.jl 32 `struct CuError`; synchronization.jl 179 `throw_api_error(res)` |
| cuda.md:285-286 | showerror methods | exceptions.jl, error.jl, memory.jl | 9-11, 74-81, 442 | FIT | exceptions.jl 9 showerror(KernelException); error.jl 74 showerror(CuError); memory.jl 442 showerror(OutOfGPUMemoryError) |
| dimensionaldata-jl.md:14 | version read | DimensionalData.jl | 66659c52, 0.30.2 | FIT | 0.30.2 |
| doublefloats-jl.md:12 | version read | DoubleFloats.jl | 9b37877d, 1.11.2 | FIT | 1.11.2 |
| dynamicquantities.md:18 | version | Project.toml, Manifest.toml | "Version. `to pin`" | NOT FIT (C4, stale) | [compat] DynamicQuantities = "1.13.0", Manifest 1.13.0 |
| exit-criteria-instruments.md:15-18 | read at | JuliaDynamics trees | aa249d70, 2ac1e839, 35e234b8 | FIT | all three commits exist, dated 2026-07-15, 2026-08-12, 2025-05-21 as stated |
| fastpower-jl.md:11 | version read | FastPower.jl | 674cbaaa, 1.5.0 | FIT | 1.5.0 |
| insolation-jl.md:101-102 | version on main | Insolation.jl | 1.2.1 | FIT | HEAD 1.2.1 (no commit named) |
| insolation-jl.md:35-40 | Laskar (2004) splines opt-in behind milankovitch = true, error if not preloaded | tree | src/Insolation.jl, src/InsolationCalc.jl | FIT | Insolation.jl:79 `artifact"laskar2004", "INSOL.LA2004.BTL.csv"`; InsolationCalc.jl:312-322 get_orbital_parameters `if milankovitch ... if isnothing(orbital_data)` |
| insolation-jl.md:40-41, 94-95 | the package documents the splines as Earth-only | tree docstring | src/Insolation.jl:44-45 | FIT | "The Laskar et al. (2004) solution describes the orbital history of **Earth**" |
| jet-jl.md:39 | version pinned in compat | Project.toml | 0.12.1 | FIT | [compat] JET = "0.12.1", test target |
| julia-1.12.md:3, 23 | runtime version and compat | Project.toml | 1.12 series, 1.12.7 | FIT | [compat] julia = "1.12"; `julia --version` 1.12.7 |
| kernelabstractions.md:24 | version | Manifest.toml | 0.9.42 | FIT | Manifest and compat 0.9.42; installed scVtc 0.9.42 |
| kernelabstractions.md:41-45 | one body written twice; constructor picks by isgpu | KA src/macros.jl | 13-79, 54-72, 57-58, 61 | FIT | 13 `function __kernel`; 54 `constructors = quote`; 57 `if $isgpu(dev)`; 58 gpu construct; 61 `construct(dev, sz, range, $cpu_name)`; 72 end quote; 79 end function |
| kernelabstractions.md:48-51 | CUDA call method is CUDACore's | CUDACore src/CUDAKernels.jl | 111-127 | FIT | as in cuda.md |
| kernelabstractions.md:56-60 | CPU backend runs the call with no validation | KA src/cpu.jl | 39-48, 98-127, 129-150, 147 | FIT | 39 `(obj::Kernel{CPU})(args...)` calls __run; 98 __run; 129 __thread_run; 147 `obj.f(ctx, args...)` |
| kernelabstractions.md:70-73 | Kernel holds f | KA src/KernelAbstractions.jl | 706-709 | FIT | 706 `struct Kernel{Backend, WorkgroupSize, NDRange, Fun}`, 707 backend, 708 `f::Fun`, 709 end |
| mesharrays-and-climatemodels.md:12-16 | read at | JuliaClimate, gaelforget trees | f812fc9, 9105671, 7b3b51e5, 4c3ab9b1 | FIT (note) | MeshArrays.jl f812fc9 (JuliaClimate) and 9105671 (gaelforget) exist; ClimateModels.jl 7b3b51e5 and CyclicArrays.jl 4c3ab9b1 exist only under /home/cfutro/git/gaelforget/, which the record does not name for them |
| ncdatasets.md:18 | version pinned | Project.toml | 0.14.15 | FIT | [compat] 0.14.15 |
| oceananigans-jl.md:139 | version read | Oceananigans.jl | 31d9b76a, 0.112.0 | FIT | 0.112.0 |
| precompiletools.md:24 | version pinned | Project.toml | 1.3.4 | FIT | [compat] 1.3.4 |
| rootsolvers-jl.md:15-17 | version read | RootSolvers.jl | 7389b926, 1.1.0 | FIT | 1.1.0 |
| rootsolvers-jl.md:36 | isbits result | tree | test/test_fval_inputs.jl:82 | FIT | line 82 `@test isbits(sol)` |
| rootsolvers-jl.md:37 | zero allocation | tree | test/test_fval_inputs.jl:205 | FIT | line 205 `@test fval_alloc_measure(f_alloc, M, soltype) == 0` |
| rootsolvers-jl.md:38 | zero-allocation assertion across methods | tree | test/runtests.jl:158 | FIT | lines 158-165 `@test (@allocated find_zero_wrapper(...)) == 0` |
| rootsolvers-jl.md:72-77 | "a skip that does not skip": the `if` after the comment has an empty body | tree | test/runtests.jl:198 | NOT FIT (C2) | at 7389b926, lines 198-202: `if !(ArrayType <: Array) && is_newton_ad && problem.name == "trigonometric function"` / `continue` / `end`; blame dates lines 187-202 to d0dfc16a (2026-06-28), before the read commit |
| rootsolvers-jl.md:252 | checklist B4 row restates it | tree | test/runtests.jl:198 | NOT FIT (C2) | same passage |
| rootsolvers-jl.md:146 | ForwardDiff use: base_type | tree | line 84 | FIT | src/RootSolvers.jl:84 `base_type(::Type{FT}) where {T, FT <: ForwardDiff.Dual{<:Any, T}}` |
| rootsolvers-jl.md:147 | ForwardDiff use: value_deriv | tree | line 1947 | FIT | src/RootSolvers.jl:1947 `function value_deriv(f, x::FT)` |
| rrtmgp-jl.md:214-216 | version read | RRTMGP.jl | f174987d, 1.0.0 | FIT | 1.0.0 |
| rrtmgp-jl.md:216 | shipped data RRTMGP data 1.9 | tree | Artifacts.toml, src/RRTMGP.jl | FIT | Artifacts.toml `rrtmgp-data/archive/refs/tags/v1.9`; RRTMGP.jl:4 `joinpath(artifact"rrtmgp-data", "rrtmgp-data-1.9")` |
| rrtmgp-jl.md:153-154 | shortwave two-stream is Zdunkowski PIFM with Meador and Weaver direct beam | tree | src/rte/shortwave_2stream.jl, src/Numerics.jl | FIT | shortwave_2stream.jl:191 `# Zdunkowski Practical Improved Flux Method "PIFM"`; Numerics.jl:43 "(Meador & Weaver 1980, Eqs 14-15)" |
| rrtmgp-jl.md:155 | longwave diffusivity secant 1.66, Fu et al. | tree | src/rte/longwave_2stream.jl | FIT | line 164 `lw_diff_sec = FT(1.66) # Fu et al. 1997 diffusivity secant` |
| rrtmgp-jl.md:139-143 | gray front door defaults and fitted optical-thickness types | tree | src/api/standalone.jl, src/optics/AtmosphericStates.jl | FIT | standalone.jl:171-175 `optical_thickness = GrayOpticalThicknessOGorman2008(FT)`, `toa_flux = FT(1361)`; AtmosphericStates.jl:18-19 both types exported |
| seawaterpolynomials-jl.md:16-18 | version read | SeawaterPolynomials.jl | 18f3797f, 0.3.10 | FIT | 0.3.10 |
| seawaterpolynomials-jl.md:6 | the TEOS-10 half is a 55-term fit translated from polyTEOS10.py | tree | src/TEOS10.jl | FIT | header comment "translated into Julia from .../polyTEOS10.py"; docstring "A 55-term polynomial approximation to the TEOS-10 standard" |
| seawaterpolynomials-jl.md:40-46 | salinity coordinate with dS = 32, S_au = 40 * 35.16504 / 35 | tree | src/TEOS10.jl | FIT | lines 74 `const S_au = 40 * 35.16504 / 35`, 77 `const dS = 32.0` |
| seawaterpolynomials-jl.md:51-54 | 35.16504 is the defining number of Millero et al. (2008) | millero2008-composition-standard-seawater-reference-composition-salinity.pdf (held), 10.1016/j.dsr.2007.10.001 | none given | FIT (note) | text p. 13, Table 4 Sum row, w_i column 35.16504, and "The sum of this column is the special Reference Salinity corresponding to S = 35, S_R^35, which is exactly" 35.16504 g/kg. Millero names it the Reference Salinity of S = 35 seawater; the record's "Reference-Composition Absolute Salinity" is the TEOS-10 name for the same number. INDEX status held |
| seawaterpolynomials-jl.md:55-57 | reference heat capacity fixed to the composition | tree | src/TEOS10.jl:32 | FIT | `const teos10_reference_heat_capacity = 3991.86795711963` |
| seawaterpolynomials-jl.md:60-61 | docstring: sets optimized for the 'current' ocean | tree | src/SecondOrderSeawaterPolynomials.jl | FIT | lines 164, 177, 190, 205, 219: "optimized for the 'current' oceanic temperature and salinity distribution" |
| seawaterpolynomials-jl.md:62-70 | cost function and climatology of the fit: RMS error on climatological horizontal density gradients, PHC3.0 of Steele et al. (2001), WOA refined in the Arctic, remapped onto ORCA2 | roquet2015a-defining-simplified-realistic-equation-state-seawater.pdf (held), 10.1175/JPO-D-15-0080.1 | p. 2568 | FIT | text 0005.txt lines 80-95: "Defining the cost function based on horizontal density gradients"; "Polar Science Center Hydrographic Climatology (PHC3.0 ...; Steele et al. 2001), a product obtained by refining the World Ocean Atlas ... in the Arctic region. Climatological fields were remapped on an approximately 2 degree ... ORCA2 mesh" |
| seawaterpolynomials-jl.md:77-78 | all seven :SecondOrder coefficients match the 2order row of Table 3 | Roquet 2015a (held) | Table 3, p. 2569 | FIT | PDF p. 6 Table 3 2order: R010 1.82e-2, R100 8.078e-1, R020 -4.937e-3, R011 -2.4677e-5, R200 -1.115e-4, R101 -8.241e-6, R110 -2.446e-3; SecondOrderSeawaterPolynomials.jl@18f3797f SecondOrderRoquetSeawaterPolynomial carries the same seven |
| seawaterpolynomials-jl.md:78-80 | the five sets :Linear, :Cabbeling, :CabbelingThermobaricity, :Freezing, :SecondOrder "are that table's five rows" (under "The transcription is faithful, checked against the source") | Roquet 2015a (held) | Table 3, p. 2569 | NOT FIT (C2) | Table 3 freez row: R010 -4.91e-2, R100 7.718e-1, R020 -5.539e-3, R011 -3.4977e-5. The package's FreezingRoquetSeawaterPolynomial carries R020 = -5.027e-3 and R011 = -2.5681e-5, which are the cab-therm row's values. Lin, cab and cab-therm match |
| seawaterpolynomials-jl.md:80-83 | :SimplestRealistic is the paper's eq (17) | Roquet 2015a (held) | eq (17), p. 2576 | FIT | text 0013.txt lines 14-30: "we propose the following equation of state as the simplest, yet 'realistic,' for seawater: ... (17)"; package docstring "(see equation (17))" |
| seawaterpolynomials-jl.md:85-90 | "simply impossible to obtain a realistic thermohaline circulation from a linear EOS"; four coefficients suffice | Roquet 2015a (held) | conclusions, p. 2578 | FIT | text 0015.txt lines 30-40: "it is simply impossible to obtain a realistic thermohaline circulation from a linear EOS ... an EOS as simple as the one proposed in Eq. (17) suffices" |
| seawaterpolynomials-jl.md:138-139 | TEOS-10 reference density 1020 is the value Roquet used when fitting | roquet2015-accurate-polynomial-expressions-density-specific.pdf (held), 10.1016/j.ocemod.2015.04.002 | p. 2 | FIT | text 0002.txt: "we simply used z = -p x 1 m/dbar for the polynomial fits, equivalent to using a value rho0 1020 kg m-3 for the conversion"; TEOS10.jl:52-60 docstring |
| seawaterpolynomials-jl.md:145-147 | docstring quotes Roquet: the rho0 choice "varies significantly among OGCMs, as it is a matter of personal preference" | Roquet 2015 (held) | text p. 9 | FIT | text 0009.txt lines 144-145: "yet it varies significantly among OGCMs, as it is a matter of personal preference"; TEOS10.jl:64 |
| seawaterpolynomials-jl.md:213-216 | TEOS-10 checked against Roquet's check values at CT 10 C, SA 30 g/kg, 1000 m, 1027.45140 kg/m3 | Roquet 2015 (held) | text p. 11 | FIT | text 0011.txt lines 49-50: "Check values for SA = 30 g/kg, CT = 10 C, Z = -1000 m: ... rho = 1027.45140 kg m-3"; test/runtests.jl:77 |
| seawaterpolynomials-jl.md:293-296 | Roquet 2015 is the source of the 55-term fit | Roquet 2015 (held) | reference entry | FIT | text 0010.txt:49 "model density is obtained from a 55-term polynomial expression"; 0012.txt:36 "this equation of state needs 55 terms" |
| seawaterpolynomials-jl.md:297-302 | Roquet 2015a: Table 3 at p. 2569, eq (17) in the discussion | Roquet 2015a (held) | reference entry | FIT | Table 3 on printed p. 2569; eq (17) on p. 2576 |
| seawaterpolynomials-jl.md:304 | the fence in decision 0017 rests on Millero 2008, held | Millero 2008 (held) | reference entry | FIT | INDEX.md line 910, status held, anchors 0017; the record says held, not read |
| sha-uuids.md:20 | stdlib versions | Manifest.toml | stdlib on 1.12 | FIT | SHA 0.7.0, UUIDs 1.11.0 stdlib entries |
| speedyweather-reference-arm.md:27 | not pinned | none | "to pin" | FIT | no SpeedyWeather entry in Project.toml or Manifest.toml; nothing claimed read |
| staticarrays-jl.md:13 | version read | StaticArrays.jl | 8935f709, 1.9.20 | FIT | 1.9.20; Manifest and compat 1.9.20 |
| structarrays-jl.md:15 | version read | StructArrays.jl | 54d75457, 0.7.3 | FIT | 0.7.3 |
| surfacefluxes-jl.md:109-110 | version read | SurfaceFluxes.jl | 0d22849b, 1.2.1 | FIT | 1.2.1 |
| surfacefluxes-jl.md:20-29 | Psi is the layer-averaged integral of Nishizawa and Kitamura 2018; the package corrects Eq. A5's denominator | tree | src/UniversalFunctions.jl | FIT | lines 12, 68 "follows Nishizawa & Kitamura (2018)"; 216-219 "Derivation follows Nishizawa & Kitamura (2018, Eq. A5), but corrects ... Eq. A5 in the paper uses a hardcoded denominator of `12 zeta`" |
| surfacefluxes-jl.md:37-39 | variance coefficients of Panofsky, Wyngaard and Tan as bare literals | tree | src/UniversalFunctions.jl | FIT | line 15 "from Panofsky et al. (1977), Wyngaard et al. (1971), and Tan et al. (2018)"; 448, 469 |
| surfacefluxes-jl.md:41-42 | Raupach canopy roughness | tree | src/roughness_lengths.jl, SurfaceFluxes.jl:60 | FIT | `RaupachRoughnessParams` |
| surfacefluxes-jl.md:47-53 | smooth limit 0.11 (Smith 1988) plus Charnock rough limit | tree | src/roughness_lengths.jl | FIT | line 131 "(Smith 1988) and a rough flow limit (Charnock 1955)"; 178-180 `z0_smooth = FT(0.11) * kinematic_visc / u_safe` |
| surfacefluxes-jl.md:53-55 | ten-metre wind against a bare FT(10) | tree | src/roughness_lengths.jl:174 | FIT | `mag_u_10 = (u / kappa) * log(FT(10) / z0_proxy)` |
| surfacefluxes-jl.md:56-57 | scalar roughness is a fit to COARE and HEXOS data, min(1.1e-4, 5.5e-5 Re^-0.6) | tree | src/roughness_lengths.jl | FIT | lines 191-196 docstring "an empirical fit to COARE and HEXOS data"; line 235 `z0s = min(FT(1.1e-4), FT(5.5e-5) * Re_star^FT(-0.6))` |
| thermodynamics-jl.md:11, 216 | version read | Thermodynamics.jl | 9f68819e, 1.3.0 | FIT | 1.3.0 |
| thermodynamics-jl.md:114 | modified parameter set varies T_0 | tree | test/correctness.jl line 420 | FIT | 417-420 `T_0_new = TP.T_0(param_set) + FT(10)`, `param_set_new = ...(; nt_new...)` |
| thermodynamics-jl.md:114-115 | modified parameter set varies T_0 and latent heats along Kirchhoff lines | tree | test/physical_properties.jl line 251 | FIT | 251-255 `shifted = TP.ThermodynamicsParameters{FT}(; ... T_0 = ... + delta, LH_v0 = ... + (cp_v - cp_l) * delta, LH_s0 = ... + (cp_v - cp_i) * delta` |
| zarr.md:24 | version pinned | Project.toml | 0.10.2 | FIT | [compat] Zarr = "0.10.2", Manifest 0.10.2 |
| zarr.md:21 | absent chunk with no fill value raises ArgumentError | Zarr src/ZArray.jl | uncompress_raw!, 358-360 | FIT | 357 function uncompress_raw!; 358 `if curchunk === nothing`; 359 `if isnothing(z.metadata.fill_value)`; 360 `throw(ArgumentError("The array $z got missing chunks and no fill_value"))` |

#### Not-fit cases

##### 1. climaseaice-jl.md:52-67, Winton 2000 said to put the liquidus inside the conductivity

- Use: the record's comparison of ClimaSeaIce with "the Winton three-layer scheme decision 0017
  names": "Winton's whole contribution is that the liquidus appears *inside* the upper layer's
  heat capacity and inside the conductivity, so that brine pockets store latent heat and conduct
  differently as the ice warms".
- Source: Winton (2000), "A Reformulated Three-Layer Sea Ice Model",
  10.1175/1520-0426(2000)017<0525:ARTLSI>2.0.CO;2, INDEX.md line 816, status held.
- Category: C2, the source does not state the scheme claimed.
- What is wrong: Winton 2000 carries the brine content in a variable heat capacity only; the
  conductivity is constant. A temperature- and salinity-dependent conductivity is Bitz and
  Lipscomb (1999) and Maykut and Untersteiner (1971), which Winton names as the more
  sophisticated alternative.
- Evidence: p. 3 (text 0003.txt lines 108-111): "As in the Semtner model, the ice conductivity is
  assumed to be constant rather than a function of temperature and salinity, as it is in more
  sophisticated models (Maykut and Untersteiner 1971; Bitz and Lipscomb 1999)"; Table 1, sea-ice
  thermal conductivity 2.03 W m-1 C-1. Abstract, p. 1: "the brine content of the upper ice is
  represented with a variable heat capacity".
- Fix class: (a) for the record: rewrite the sentence to the heat-capacity half, citing Winton
  2000 p. 3 and Table 1 (held on disk; INDEX status held, so a read mark would come with it).
  The same paragraph says decision 0017 "requires the brine-conductivity coefficient to be
  Bracketed"; if decision 0017 or REQ-OCN-003 attributes a brine-dependent conductivity to
  Winton 2000, that is a decision-basis case for the decisions scope (d), not this file. No open
  branch edits climaseaice-jl.md.

##### 2. rootsolvers-jl.md:72-77 and :252, a skip "that does not skip"

- Use: evidence for checklist item B4 (comment against value): "at `test/runtests.jl:198` there is
  a skip that does not skip ... and the `if` that follows has an empty body. Whatever the history,
  the code does not perform the skip the comment describes." The B4 row at line 252 repeats it.
- Source: RootSolvers.jl at the commit the record names, 7389b926dd93bad4d872f4b50a1e49208167fa3f.
- Category: C2, the locator's passage does not state what is claimed.
- What is wrong: the `if` at line 198 has a body, `continue`, which performs the skip.
- Evidence: `git show 7389b926:test/runtests.jl` lines 198-202:
  `if !(ArrayType <: Array) && is_newton_ad && problem.name == "trigonometric function"` /
  `continue` / `end`. `git blame` dates lines 187-202 to d0dfc16a, 2026-06-28, before the commit's
  date of 2026-09-01, so the body was present when the record says it read the tree.
- Fix class: (a): strike the paragraph and change the B4 row to a clean negative for that site
  (the comment matches the code). No bar, disposition or decision rests on it. No open branch edits
  rootsolvers-jl.md.

##### 3. seawaterpolynomials-jl.md:76-80, the five coefficient sets said to be Table 3's five rows

- Use: "The transcription is faithful, checked against the source ... the five sets `:Linear`,
  `:Cabbeling`, `:CabbelingThermobaricity`, `:Freezing` and `:SecondOrder` are that table's five
  rows."
- Source: Roquet, Madec, Brodeau, Nycander (2015), "Defining a Simplified Yet 'Realistic'
  Equation of State for Seawater", 10.1175/JPO-D-15-0080.1, INDEX.md line 752, status held; Table 3,
  p. 2569.
- Category: C2.
- What is wrong: the package's `:Freezing` set is not the freez row. Its R020 and R011 are the
  cab-therm row's values. The record's check covers the 2order row term by term and asserts the rest.
- Evidence: Table 3 (PDF p. 6): freez R010 -4.91e-2, R100 7.718e-1, R020 -5.539e-3, R011
  -3.4977e-5; cab-therm R020 -5.027e-3, R011 -2.5681e-5. SecondOrderSeawaterPolynomials.jl at
  18f3797f, FreezingRoquetSeawaterPolynomial: R010 -0.491e-1, R100 7.718e-1, R020 -5.027e-3,
  R011 -2.5681e-5.
- Fix class: (a) for the record: state that `:Freezing` transposes the cab-therm R020 and R011, and
  that the other four sets match, citing Table 3 p. 2569 (held on disk; INDEX status held). It
  touches no bar or disposition: nothing adopts the package. It is also an upstream transcription
  defect in SeawaterPolynomials.jl, worth recording as a negative in the checklist B4 row. No open
  branch edits seawaterpolynomials-jl.md.

##### 4. adapt.md:14, version `to pin`

- Use: the record's version statement for an adopted dependency.
- Source: Project.toml [compat] `Adapt = "4.7.0"`, Manifest.toml 4.7.0.
- Category: C4 (version statement stale against the tree).
- Evidence: the compat entry exists; precompiletools.md, jet-jl.md and ncdatasets.md call the same
  form "pinned in Project.toml compat".
- Fix class: (a): "4.7.0, pinned in `Project.toml` compat". No open branch edits adapt.md.

##### 5. dynamicquantities.md:18, version `to pin`

- As case 4: Project.toml [compat] `DynamicQuantities = "1.13.0"`, Manifest 1.13.0.
- Category: C4. Fix class: (a): "1.13.0, pinned in `Project.toml` compat". The same line carries
  "Licence. Apache-2.0 `to verify`", which is outside a source-fitness audit. No open branch edits
  dynamicquantities.md.

#### Notes that are not not-fit verdicts

- Line locators one or two lines off, each with the described code adjacent and no ambiguity about
  what is meant: cgdycore-jl.md:264 (`DriverCG.jl:318`, the read is 317); cuda.md:49 (cufunction
  675-681, the `compile_or_lookup` call is 683); cuda.md:86 (lower_throw! argument erasure 205-218,
  the loop is 206-219); cuda.md:268 (check_exceptions 29-43, ends 42).
- cuda.md:273-276 names GPUToolbox `src/ccalls.jl` and then gives `check`, lines 34-40, and
  `throw_api_error`, lines 26-32; both definitions are in CUDACore `lib/cudadrv/libcuda.jl` at those
  lines. The bullet opens with libcuda.jl, so the lines resolve, but naming the file for the two
  ranges would remove the ambiguity. cuda.md is edited by fiddlybits-52v.6.26.
- mesharrays-and-climatemodels.md:14-16 gives commits for ClimateModels.jl and CyclicArrays.jl
  without a location; both exist only under /home/cfutro/git/gaelforget/.
- INDEX status lag, not a fitness failure: seawaterpolynomials-jl.md opens and uses Roquet 2015
  (text pp. 2, 9, 10-12), Roquet 2015a (Table 3, eq 17, pp. 2568, 2578) and Millero 2008 (p. 13),
  and climaseaice-jl.md uses Winton 2000; all four INDEX rows are held. No Sourced value or bar in
  this scope rests on them.
- Records naming a version on `main` with no commit (insolation-jl.md, climacoupler-jl.md,
  clima-output-and-tooling.md) match their trees' HEAD today; a later pull would silently move what
  "read against main" means.
- The markley1995 held copy is the NASA Goddard report version (N95-27767), not the CMDA version of
  record the DOI names; the INDEX row discloses it (INDEX scope).

#### Open branch fiddlybits-52v.6.26 (not audited here)

`git diff main...fiddlybits-52v.6.26 -- docs/imports/` adds to cuda.md a section "A kernel the host
releases with a write to host memory" with CUDACore `src/array.jl` locators 304-330, 399-426 and
590-608, and to zarr.md two table rows with locators in Zarr.jl 0.10.2 (`src/Compressors/blosc.jl`
49-65, `src/ZArray.jl` 336, 383-386, 440, 484-492, `src/pipeline.jl` 1-8,
`src/Compressors/Compressors.jl` 29, 33-37, `src/Storage/Storage.jl` 84, 258-286), Blosc.jl 0.7.3
(`src/Blosc.jl` 14, 37-40, 74-98, 109-119) and Blosc_jll 1.21.7+0 `include/blosc.h` (32-37, 120-124,
159-161, 225-230). These are on the branch, not main, and were not opened; that branch's review
carries them.

#### Fetch failures and paywalled sources

None. Every source in this scope was on disk (references/text, references/pdf, the depot, or a
local git tree).

### P: Plans


Audited tree: worktree fiddlybits-9j0 at 625832c (main). Every file under docs/plans/ was
swept by grep for author-year citations, table/equation/section/page locators, DOIs,
named schemes and source words (published, paper, held, read by the row), and every
hit that gives a source as the basis for a number, law, scheme, tolerance or bar was
opened at the source. Background mentions (a phenomenon named, IEEE bit patterns,
Philox named without a claim) are not counted.

`git diff main...fiddlybits-k6b -- docs/plans/` adds one classification line
(`earth.copernicus_dem_spill_cap | pattern`) to fiddlybits-52v.8-oracles.md; it names no
source and changes no count.

#### Counts

| file | citations | fit | not fit | not verified |
| --- | --- | --- | --- | --- |
| clima-survey.md | 0 | 0 | 0 | 0 |
| fiddlybits-52v.1-skeleton.md | 0 | 0 | 0 | 0 |
| fiddlybits-52v.2-mesh.md | 0 | 0 | 0 | 0 |
| fiddlybits-52v.3-fields.md | 1 | 0 | 1 | 0 |
| fiddlybits-52v.4-system.md | 2 | 0 | 2 | 0 |
| fiddlybits-52v.5-time.md | 6 | 5 | 1 | 0 |
| fiddlybits-52v.6-provenance.md | 1 | 0 | 1 | 0 |
| fiddlybits-52v.7-kernels.md | 1 | 0 | 1 | 0 |
| fiddlybits-52v.8-oracles.md | 7 | 0 | 7 | 0 |
| fiddlybits-52v.9-dycore.md | 1 | 0 | 1 | 0 |
| fiddlybits-52v.11-coupling.md | 0 | 0 | 0 | 0 |
| README.md, TEMPLATE.md | 0 | 0 | 0 | 0 |
| **total** | **19** | **5** | **14** | **0** |

The seven in 52v.8-oracles.md are the partner-bar sources of the table "The partners to
create": four name a source (CERES EBAF paper, Moat 2020, Huneeus 2011 twice) and three
name only the kind of source for a `fail_bar` partner (a satellite NPP algorithm
intercomparison, and published per-basin distributions of concavity and of drainage
density); the kind is itself a basis and is judged against decision 0025. Two more rows
of that table (`terrain.endorheic_share_by_latitude`, `terrain.hack_exponent_by_basin`,
kind "either") and "the climate-sensitivity assessment" (line 350) name neither a source
nor a bar kind that can be judged, and are not counted.

#### Every citation

| # | where | use | source (INDEX file, status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | 52v.3-fields.md:461 | the ledger residual of a crossing or time reduction is at most gamma_D * M, D the rounded operations per term | higham1993-accuracy-floating-point-summation.pdf, read (anchor: "Read section 2 in full", (2.6), gamma_k p. 784) | eq. 1.2, with 2.2 and 3.3 | NOT FIT (C6, minor) | (1.2) `fl(x op y) = (x op y)(1 + delta), abs(delta) <= u` (text p. 0002); (2.2) the product expansion of recursive summation (text p. 0002); (3.3) `S_n_hat - S_n = sum T_k_hat delta_k/(1 + delta_k)` for any summation tree (section 3, text p. 0005). The passages support the use; the INDEX anchor names section 2 only, and eq. 3.3 is in section 3. |
| P2 | 52v.4-system.md:245-246 | the argument that a root seed is Irreducible: Philox output is a pseudo-random function of its key, so no seed is better than another | salmon2011-parallel-random-numbers-easy-1.pdf, held | none (author-year) | NOT FIT (C6) | Abstract, p. 1: "independent, keyed transformations of counters produce a large alternative class of PRNGs with excellent statistical properties (long period, no discernable structure or correlation) ... All our PRNGs pass rigorous statistical tests (including TestU01's BigCrush) and produce at least 2^64 unique parallel streams". Content supports the use (statistical quality per key; the paper claims Crush-resistance, not a pseudo-random function in the cryptographic sense). The row is held, and the plan cites it with no locator. |
| P3 | 52v.4-system.md:441 | `Earth()` declares "IAU and CODATA values with Sourced locators" | the instance's locators (test/planets/earth.jl on branch fiddlybits-52v.4.5): Prsa 2016 (IAU B3), Tiesinga 2021 (CODATA 2018), Archinal 2018 (IAU WGCCRE), Moritz 2000 (GRS80, IUGG), Standish and Williams 1992 (JPL) | none | NOT FIT (C2, minor) | The rotation period is from GRS80's defining angular velocity (Moritz 2000 p. 131, an IUGG constant) and the semi-major axis, eccentricity and longitude of periapsis from the JPL element table (Standish page, Table 1, EM Bary row); neither is an IAU or CODATA value. |
| P4 | 52v.5-time.md:95, 103-105, 127 | Markley's closed form as the starting value of the Kepler solve, then two Newton steps | markley1995-kepler-equation-solver.pdf, read | none (the scheme) | FIT | text p. 0001 and p. 0007: "Our starting formula is given by the solution of the cubic", non-iterative; the Newton steps are the project's, measured in its finding, and not attributed to Markley. |
| P5 | 52v.5-time.md:109-112 | the region the paper names, which the Kepler oracle samples (e > 0.75, E < 45 degrees) | markley1995, read | "the region the paper names" | FIT | text p. 0008: error contours "are in the region e > 0.75 and E < 45 deg"; text p. 0002: "critical region with e near unity and M near zero". |
| P6 | 52v.5-time.md:208-211 | the component form of Standish and Williams, R_z(Omega) R_x(i) R_z(omega) applied to the in-plane position with its first axis at periapsis | standish1992-approximate-positions-of-the-planets.html, read | section "Formulae for using the Keplerian elements" | FIT | The page writes `r_ecl = R_z(-Omega) R_x(-I) R_z(-omega) r'` as frame rotations, "applied using the corresponding vector rotation", with x_ecl = (cos w cos O - sin w sin O cos I) x' + (-sin w cos O - cos w sin O cos I) y', z_ecl = (sin w sin I) x' + (cos w sin I) y'. Multiplying out the active right-handed turns R_z(Omega) R_x(i) R_z(omega) gives the same components. |
| P7 | 52v.5-time.md:213-214 | the primary's true longitude from the vernal equinox, seen from the planet, is true_longitude - Omega_E (the lambda Berger's seasonal angles read) | berger1978-long-term-variations-daily-insolation.pdf, read | none (Berger 1978) | FIT | Appendix, text p. 0005: lambda "counted counterclockwise from the vernal equinox ... lambda = nu + omega-tilde"; text p. 0006: "The declination is related to the true longitude of the sun by sin(delta) = sin(epsilon) sin(lambda)". With decision 0004's gamma = -N, the direction to the primary measured from gamma is theta - Omega_E. |
| P8 | 52v.5-time.md:215 | "Berger's longitude of perihelion is longitude_of_periapsis - equator_ascending_node_longitude" | berger1978, read | none | NOT FIT (C2) | Berger names two values 180 degrees apart. Fig. 1 caption, text p. 0001: "For any numerical value of omega-tilde, 180 deg is subtracted"; eq. (6), text p. 0003: omega-tilde = pi + psi, the numerical form. Appendix, text p. 0005: in lambda = nu + omega-tilde "180 deg has to be added to the value numerically obtained through (6)". With P7's lambda = theta - Omega_E and theta = varpi + nu, only the 180-added value equals varpi - Omega_E. The plan does not say which. Decision 0004, The seasonal angles are Derived, which the plan implements, says the numerical form, and that reading is 180 degrees off (see Outside this scope). |
| P9 | 52v.5-time.md:29-31, 288 | Berger's daily-insolation form as the second arm of `system.orbit_mean_insolation` | berger1978, read (anchor: Fig. 1 caption and "the Appendix definitions") | none | FIT (note) | Appendix "Daily Insolation Formulas", eqs. (8) to (10), text pp. 0005-0006: W = 86.4 S0/(pi rho^2) (H0 sin phi sin delta + cos phi cos delta sin H0). The formulas sit in the Appendix the row reads; the anchor names the definitions and not eqs. (8) to (10). |
| P10 | 52v.6-provenance.md:271-275 | the NetCDF export declares a CF mesh topology variable (CF incorporates UGRID 1.0), each field's `mesh` and `location`, and 0-based connectivity with `start_index` | eaton2025-cf-metadata-conventions-1-13.pdf, held | section 1.6 p. 15; section 5.9 and Example 5.21 pp. 75-76; Table K.1 pp. 249-250 | NOT FIT (C6) | p. 15 (text 0023): "Only version 1.0 of the UGRID conventions is allowed"; p. 75 (text 0083): "A data or domain variable may use one of a mesh topology variable's domains by referencing the mesh topology variable with the mesh attribute; along with ... the location attribute", Example 5.21; p. 250 (text 0258), Table K.1: `location`, `mesh`, `start_index` "connectivity indices are 0-based by default". The passages support the use exactly. The row is held, not read. fiddlybits-52v.6.36 (open) carries the eaton2025 INDEX row in its boundary. |
| P11 | 52v.7-kernels.md:177 | `compensated_sum(xs)`, "Kahan, FP64 accumulator regardless of eltype" | kahan1965-pracniques-further-remarks-reducing-truncation.pdf, held | none | NOT FIT (C2, C6) | Kahan 1965, Comm. ACM Pracniques, text p. 0001: `S2 = S2 + YI; T = S + S2; S2 = (S-T) + S2; S = T`: the correction is fed back into the next term by a fast two-sum that is exact only when the running sum dominates, on machines "which normalize floating-point sums before rounding". src/Reductions/compensated.jl implements a different algorithm: Knuth's branch-free TwoSum on every term, the errors accumulated in a separate recursive sum and added once at the end. Higham 1993 section 3 (text p. 0009) separates these as two versions with different bounds, (3.10) and (3.12). The implemented one is not stated by Kahan 1965, and the row is held. |
| P12 | 52v.8-oracles.md:317, 348-349, 414 | `earth.ceres_toa_zonal` `fail_bar`, its bar "the CERES EBAF zonal-mean uncertainty, from the EBAF data-product paper" | loeb2018-clouds-earth-s-radiant-energy.pdf, held | "zonal-mean uncertainty" | NOT FIT (C2, C7) | Loeb et al. 2018 states uncertainty for 1 deg x 1 deg regional monthly TOA fluxes (abstract, text p. 0001: "The overall uncertainty in 1 x 1 latitude-longitude regional monthly all-sky TOA flux ..."; Table 8, text p. 0021) and for global means; "zonal" appears only for averaging cloud properties (text p. 0011). It states no zonal-mean uncertainty. Separately, an observational uncertainty is not a FAIL basis: a FAIL bar comes from "a published model's own residual, or a physical constraint" (docs/oracles/README.md, Verdicts; decision 0025). |
| P13 | 52v.8-oracles.md:318, 357, 415 | `earth.amoc_overturning_profile`: the vertical profile of overturning at 26 N, its depth of maximum and deep return transport, against RAPID, source "Moat et al. 2020" | moat2020-pending-recovery-amoc-26n.pdf, held | none | NOT FIT (C2) | Moat et al. 2020 (Ocean Sci. 16, 863-874) reports the AMOC strength and its component transports (Gulf Stream, Ekman, upper mid-ocean, UNADW, LNADW) as time series, with 10-day error +/-1.5 Sv and standard errors (Fig. 3, section 3). It shows no overturning streamfunction profile and no depth of maximum, and says "investigations into the depth distribution and zonal distribution of changes at 26 N ... are pending" (section 5). Only the deep-layer transports are there. |
| P14 | 52v.8-oracles.md:319, 358, 415 | `earth.marine_npp_zonal` `fail_bar`, its bar "a published intercomparison of satellite NPP algorithms, whose spread is the bar" | source not named (to be fetched by 52v.8.16) | none | NOT FIT (C7, basis kind) | A spread among satellite retrieval algorithms is the uncertainty of the observation, not a published model's residual or a physical constraint (docs/oracles/README.md, Verdicts). |
| P15 | 52v.8-oracles.md:320, 359, 416 | `earth.dust_aod_by_region` `fail_bar`, its bar "the regional inter-model spread of AeroCom phase I, Huneeus et al. 2011" | huneeus2011-global-dust-model-intercomparison-aerocom.pdf, held | none | NOT FIT (C7) | For a tier-2 FAIL bar an inter-model spread is a tier-3 basis, not a model residual. The same paper publishes per-model residuals against AERONET, grouped by region: Fig. 9 caption, p. 7798 (text 0018): "Root mean square error (RMS), bias, ratio of modeled and observed standard deviation (sigma) and correlation (R) are indicated for each model"; text p. 0017: MNB between -0.44 and 0.27, NRMS between 0.3 and 0.6. That basis is admissible and read by the same row. |
| P16 | 52v.8-oracles.md:321, 359, 416 | `earth.dust_emission_by_region` `fail_bar`, "the same paper's regional spread of emission" | huneeus2011, held | none | NOT FIT (C7) | Table 5, p. 7808 (text 0028): "Yearly emission fluxes [Tg yr-1] for regions illustrated in Fig. 2", model by model. Emission is not observed. Over- and under-estimates are inferred from AOD and Angstrom exponent at stations (text p. 0027), so the only spread is inter-model, and there is no residual against an observation. |
| P17 | 52v.8-oracles.md:322, 360, 419 | `terrain.channel_concavity_by_basin` `fail_bar` on "a published per-basin distribution of concavity (found by the row)" | source not named | none | NOT FIT (C7, basis kind) | An observed per-basin distribution is the spread of Earth's basins, not a model residual or physical constraint (docs/oracles/README.md, Verdicts). |
| P18 | 52v.8-oracles.md:323, 360, 419 | `terrain.drainage_density_by_basin` `fail_bar` on "a published per-basin distribution of drainage density (found by the row)" | source not named | none | NOT FIT (C7, basis kind) | as P17 |
| P19 | 52v.9-dycore.md:110-113, 175 | "Each case runs at Earth parameters ... The published error norms are the bar on the Earth arm only"; 52v.9.4 acceptance: "the four Williamson cases pass at Earth parameters against the published norms" | williamson1992-standard-test-set-numerical-approximations.pdf, held | none | NOT FIT (C2, C3, C6) | Williamson et al. 1992 publishes no norms to pass. Error measures are graphs of l1, l2 and linf against time (e.g. text p. 0019). For cases 5 and 6 the reference is a high-resolution spectral run "in a companion report" (text p. 0009, p. 0024). Tests are "necessary conditions only, i.e. any scheme must do well in these tests compared to currently acceptable schemes" (text p. 0016). The cases fix their own constants, a = 6.37122e6 m, Omega = 7.292e-5 s^-1, g = 9.80616 m s^-2, eqs. (72) to (74) (text p. 0017), not Earth()'s declared values. A norm from Earth() is therefore not on the published configuration. The row is held. Wan 2013 (read) does not supply norms either: text p. 0011, the shallow-water tests 5 and 6 "can be found in Wan (2009), and are not repeated here". |

#### Not fit, one section each

##### P1 Higham 1993 eq. 3.3 outside the read section
- Where: docs/plans/fiddlybits-52v.3-fields.md:461. Use: the model and error expressions behind the ledger tolerance `gamma_D * M`.
- Category: C6, minor. The passage supports the use; what is missing is the INDEX anchor. It names "section 2 in full", and eq. (3.3) is section 3's general expression for any summation order (text p. 0005).
- Fix class (a), INDEX only: add eq. (1.2) and eq. (3.3), section 3, to the higham1993 row's anchors. docs/references/INDEX.md is edited by fiddlybits-k6b, so this waits or joins a row that edits INDEX.

##### P2 Salmon et al. 2011 held, cited as the argument's basis
- Where: docs/plans/fiddlybits-52v.4-system.md:245. Use: the Irreducible argument for `root_seed`.
- Category: C6. The content supports it: abstract, p. 1, keyed counter transformations with no discernable structure or correlation, passing BigCrush, with at least 2^64 streams. The row is held and the plan gives no locator. "Pseudo-random function" is a cryptographic term the paper does not claim for Philox; it claims Crush-resistance.
- Fix class (a): mark the salmon2011 INDEX row read with locator "abstract, p. 1" (INDEX edited by k6b). In the plan, "a keyed bijection of a counter whose streams pass BigCrush (abstract, p. 1)" in place of "a pseudo-random function of its key". The plan file is not edited by any open branch.

##### P3 Earth() described as IAU and CODATA values
- Where: docs/plans/fiddlybits-52v.4-system.md:441.
- Category: C2, minor. Two of the named classes do not cover the values: the rotation is GRS80 (Moritz 2000, p. 131) and the orbit is the JPL table (Standish and Williams, Table 1).
- Fix class (a): the sentence names the five read sources the instance uses (Prsa et al. 2016, CODATA 2018, Archinal et al. 2018, Moritz 2000, Standish and Williams). No open branch edits the plan file.

##### P8 Berger's longitude of perihelion, 180 degrees ambiguous
- Where: docs/plans/fiddlybits-52v.5-time.md:215. Use: the seasonal angles' identity.
- Category: C2. Berger states two values 180 degrees apart. The Fig. 1 caption and eq. (6) give the numerical form with 180 subtracted; the Appendix says 180 "has to be added" before lambda = nu + omega-tilde. The plan's identity holds only for the Appendix value, and the plan does not say which.
- Fix class (d), because it reaches a decision's basis and a test instance's declared value. Decision 0004 (The seasonal angles are Derived) says the numerical form equals `varpi - Omega_E`, and Earth() on fiddlybits-52v.4.5 declares Standish's varpi with Omega_E = 0 on that reading. The plan sentence changes with decision 0004 once the user rules. See Outside this scope.

##### P10 CF 1.13 held
- Where: docs/plans/fiddlybits-52v.6-provenance.md:271-275.
- Category: C6. Every locator was read here and supports the use exactly: p. 15, pp. 75-76, and Table K.1 pp. 249-250 with start_index 0-based by default. The INDEX row is held.
- Fix class (a), carried by fiddlybits-52v.6.36, open, whose boundary includes the eaton2025 row of INDEX.md: mark read with these locators.

##### P11 compensated_sum is not Kahan 1965's algorithm
- Where: docs/plans/fiddlybits-52v.7-kernels.md:177. Code: src/Reductions/compensated.jl, where the docstring names Knuth's TwoSum.
- Category: C2 and C6.
  - Kahan 1965 (text p. 0001) feeds a fast-two-sum correction back into the next term, exact only when the running sum dominates.
  - The code applies branch-free TwoSum to every term, accumulates the errors separately and adds them once (the Pichat and Neumaier form, as in Ogita, Rump and Oishi's Sum2).
  - Higham 1993 section 3 (text p. 0009) describes the accumulate-apart version with bound (3.12) "provided nu <= 0.1", but builds its correction from (3.9), which assumes abs(a) >= abs(b). So no read source states the exact algorithm.
  - The kahan1965 row is held.
- Fix class (b). A row reads a source that states TwoSum with separately accumulated errors and names it in the plan, with its bound and validity range. Candidates:
  - Higham 1993 section 3, on disk and read for section 2 only; the refs [21] and [32] it cites for this version;
  - Ogita, Rump and Oishi 2005, "Accurate Sum and Dot Product", SIAM J. Sci. Comput. 26(6), 1955-1988, DOI 10.1137/030601818 to confirm against Crossref; not held;
  - gao2026-dekker-floating-point-number-system-and.pdf, held.
- Boundary: docs/plans/fiddlybits-52v.7-kernels.md, docs/references/INDEX.md. Acceptance: the plan names a read source whose stated algorithm is the one in src/Reductions/compensated.jl, with its bound's locator.

##### P12 CERES EBAF zonal-mean uncertainty as a FAIL bar
- Where: docs/plans/fiddlybits-52v.8-oracles.md:317, decision 5 at 348-349, and the 52v.8.15 acceptance at 414.
- Category: C2 and C7.
  - Loeb et al. 2018 states regional 1x1 monthly uncertainties (Table 8) and global-mean uncertainties, not a zonal-mean one.
  - An observational uncertainty is not a basis for a FAIL bar.
- Fix class (d): the partner, its kind and its source were decided by the user on 2026-09-14 (decision 5). Options for the user:
  1. keep `fail_bar` on a published model's own zonal-mean residual against EBAF;
  2. make the partner `report`, which rule 1 allows for a report scalar;
  3. derive a zonal-mean uncertainty from Table 8 with a stated spatial correlation, which is still not a FAIL basis.
- The plan file is edited by fiddlybits-k6b.

##### P13 Moat et al. 2020 does not give the overturning profile
- Where: docs/plans/fiddlybits-52v.8-oracles.md:318, 357, 415.
- Category: C2. The paper gives component transport time series and says the depth distribution is pending (section 5). It has no profile and no depth of maximum.
- Fix class (b): 52v.8.16 names a RAPID source that states the overturning streamfunction profile at 26 N with its uncertainty; the source is to be identified by that row, not guessed here. The plan sentence changes with it; the file is edited by k6b.
- Not a registered bar: the entry does not yet exist.

##### P14 NPP algorithm spread as a FAIL bar
- Category: C7, basis kind. Fix class (d), the user's decision 8 of 2026-09-14.
- Options: `report` (rule 1 allows it for the report scalar `earth.marine_npp`), or a published ocean-biogeochemistry model's own residual against the satellite products.

##### P15 AeroCom inter-model spread as a tier-2 FAIL bar (AOD)
- Category: C7. Fix class (d), decision 8.
- The same paper publishes per-model residuals against AERONET grouped by region (Fig. 9 caption, p. 7798), which is an admissible basis. The fix is to replace "inter-model spread" with those residuals, since the scalar `earth.dust_aod` is `fail_bar` and needs a `fail_bar` partner.

##### P16 AeroCom regional emission spread as a FAIL bar
- Category: C7. Emission is unobserved, and Table 5 (p. 7808) gives only an inter-model spread.
- Fix class (d), decision 8. Rule 1 forces a `fail_bar` partner because `earth.dust_emission` is `fail_bar`, so the options are:
  - the scalar itself moves to `report` or tier 3, which changes a registered-kind choice;
  - a residual-based source is found.

##### P17, P18 observed per-basin distributions as FAIL bars
- Category: C7, basis kind. Fix class (d), decision 8.
- Options: the partners' bars come from a published landscape-evolution or drainage-extraction model's own residual against the distribution, or the partner is `report`. That requires the scalars to be `report`, which changes `terrain.channel_concavity` and `terrain.drainage_density` from `fail_bar`.

##### P19 Williamson norms and "Earth parameters"
- Where: docs/plans/fiddlybits-52v.9-dycore.md:110-113, and the 52v.9.4 acceptance at 175. The registry's core.williamson_tc1 ("published norms for the scheme class") and tc5_tc6 ("published band") are in scope R.
- Category: C2, C3 and C6.
  - Williamson 1992 publishes no norms and gives the case constants (72) to (74).
  - A bar applies to the published configuration, not to Earth().
  - The row is held.
- Fix class (b). A row does three things:
  - marks Williamson 1992 read for eqs. (72) to (74) and the error measures (82) to (84), (98);
  - finds and reads a published triangle C-grid (or scheme-class) model's own TC1, TC5 and TC6 norms, or else states that none exists, making the entries `report`;
  - rewrites the plan's "Earth parameters" as the Williamson constants set.
- Boundary: docs/plans/fiddlybits-52v.9-dycore.md, docs/references/INDEX.md; registry thresholds in a separate registry-only row. None of the entries is registered, so no registered bar changes.

#### Outside this scope, found while reading (for the parent)

The same 180-degree error appears in decision 0004 and in Earth() on fiddlybits-52v.4.5. Fix class (d): it reaches both a decision's basis and a test instance's declared value.

**Decision 0004** (section The seasonal angles are Derived, docs/decisions/0004, around lines 279-285) says Berger's longitude of perihelion "in his numerical form with 180 degrees subtracted ... is `varpi - Omega_E`. It satisfies his `lambda = nu + varpi-tilde`". Berger's Appendix (text p. 0005) says the numerical value from (6) must have 180 degrees added before it satisfies lambda = nu + omega-tilde. So `varpi - Omega_E` is the 180-added value.

**Earth()** (test/planets/earth.jl on fiddlybits-52v.4.5) declares `equator_ascending_node_longitude = 0` and `longitude_of_periapsis = 102.93768193 deg` from Standish Table 1.
- Standish measures varpi from the equinox direction, which decision 0004 lines 138-141 define as gamma = -N, the planet-to-primary direction at the vernal equinox. Gamma sits at Omega_E + 180 deg in the root frame, and "the planet's true longitude at the vernal equinox is Omega_E".
- The declared periapsis therefore sits 103 degrees after the vernal equinox, near the June solstice, which is Earth's aphelion date. The value consistent with Standish is 282.94 deg with Omega_E = 0.
- The instance's own irreducible argument, "declaring the node at zero places the vernal equinox there", shows the frame is the decision's.
- Scope D and the code scope carry these.

#### Fetch failures and paywalled sources

None attempted: every cited source was on disk. Two further sources were named as candidates for fixes and not fetched:
- **P11:** "Accurate Sum and Dot Product", Ogita, Rump and Oishi 2005, SIAM J. Sci. Comput. 26(6), DOI 10.1137/030601818 (to confirm).
- **P13:** a RAPID paper stating the 26 N overturning streamfunction profile, identifier to be found by 52v.8.16.

#### Open-branch notes

- docs/plans/fiddlybits-52v.8-oracles.md is edited by fiddlybits-k6b (P12 to P18).
- docs/references/INDEX.md is edited by fiddlybits-k6b (P1, P2, P10, P11, P19 index edits).
- No open branch edits the other plan files (52v.3-fields, 52v.4-system, 52v.5-time, 52v.6-provenance, 52v.7-kernels, 52v.9-dycore): fiddlybits-41t and fiddlybits-52v.4.16 have empty diffs against main, and 52v.4.5, 52v.6.26 and k6b touch no other plan file.

### X1: INDEX read rows, lines 27 to 129


Scope: the 44 rows marked `read` in docs/references/INDEX.md lines 27-129 (worktree at 625832c), each row's anchor passage, and every use in src/, test/, docs/oracles/registry.toml, docs/decisions, docs/requirements, docs/plans, docs/imports that cites the source; test/planets read from branch fiddlybits-52v.4.5 (not on main). Notes/findings were grepped but are out of scope. Page numbers: "tN" is references/text/<stem>/000N.txt; printed pages are given where they differ.

#### Counts

- Rows audited: 44. Rows with at least one not-fit citation: 7 (archinal2018, markley1995, standish1992, murray2000, Report-349, kite2009, helvaci2019).
- Citations (row anchors plus citing uses): 108. Fit: 90. Not fit: 18. Not verified: 0.
- Every source was on disk (text or PDF); no fetch was needed.

Per row (citations / not fit): archinal2018 14/6; cgpm1901 2/0; markley1995 8/3; standish1992 8/1; murray2000 8/5; moritz2000 5/0; ascher1997 3/0; rastetter1992 1/0; Report-349 1/1; moosdorf2018 2/0; stock1999 3/0; zondervan2020 3/0; montgomery2001 2/0; daly1966 2/0; heimsath1997 3/0; shangguan2017 2/0; wolff-boenisch2004 1/0; slessarev2016 4/0; eugster1979 2/0; deocampo2014 2/0; kite2009 1/1; the 21 prospectivity rows (sillitoe2010, groves1998, shirey2013, hannington2014, cooke2005, naldrett2010, arai2015, price1997, retallack2010, butt2013, sillitoe2005, freyssinet2005, reich2009, reich2015, slingerland1986, knight1999, risacher2009, risacher2003, munk2016, bradley2013, helvaci2019) 23/1; cordonnier2019 1/0; gleeson2011 7/0.

#### Every citation

| # | where | use | source (INDEX status) | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | INDEX.md:27 anchors | three IAU conventions "all three are what the System struct will adopt"; Table 4 Earth mean radius | archinal2018 (read) | p.6; Table 4 | NOT FIT C6 | p.6 (t6) and Table 4 (t28) exist, but decisions 0004 (322-333, "Lost") and 0005 (205-210, "Lost") rejected the north-pole-by-invariable-plane rule; the adopted positive pole is p.22's right-hand rule, which the row does not name |
| 2 | src/EarthRatios/EarthRatios.jl:33-38 | radius_unit value 6371008.4 m | archinal2018 (read) | Table 4, Earth mean radius row | FIT | t28: "Earth 6371.0084b +/- 0.0001" in Mean radius (km); footnote (b) "for comparison only", which suits a report denominator |
| 3 | src/EarthRatios/EarthRatios.jl:30 | docstring "Earth's volumetric mean radius" | archinal2018 (read) | Table 4 | NOT FIT C2 | Archinal does not say the value is volumetric; t36: "mean radius cannot be consistently derived from triaxial semi-axes values alone, since different authors have used different formulae". From Table 4's own axes (6378.1366, 6356.7519 km), (2a+b)/3 = 6371.00837 km, which matches; the volume-equivalent (a^2 b)^(1/3) = 6371.00039 km, 8.0 m smaller |
| 4 | test/planets/earth.jl:52-54 (branch 52v.4.5) | Earth() `volumetric_mean_radius` Sourced 6371008.4 m | archinal2018 (read) | "Table 4, Earth mean radius row: 6371.0084 km" | NOT FIT C2 | same as #3: a declared test-instance value under a field named volumetric, anchored to a value the source neither calls volumetric nor computes as one |
| 5 | test/planets/earth.jl:71 (branch) | Irreducible argument: Archinal excludes an Earth prime meridian (p.9, fn 2) | archinal2018 (read) | p.9 footnote 2 | NOT FIT C6 | passage exists and supports the use (t9 l.60-64: users "should refer to the International Earth Rotation and Reference Systems Service"), but the row does not name p.9 as read |
| 6 | decisions/0004:120, 0004:460 | positive pole by the right-hand rule, p.22 | archinal2018 (read) | p.22 | NOT FIT C6 | t22 l.23: "The rotation pole for a body is chosen to be the one following the right-hand rule. This rotation pole is called the positive pole". Supports the definition; the IAU scopes it to small bodies ("different from the definition for the planets"), and decision 0005 records the planet convention as the rejected alternative. Row does not name p.22 |
| 7 | decisions/0004:192 | W defines the prime meridian where no fixed features exist, p.6 | archinal2018 (read) | p.6 | FIT | t6: "For planets or satellites with no accurately observable fixed surface features, the expression for W defines the prime meridian" |
| 8 | decisions/0004:207, 0004:326, 0004:460 | Table 1 p.8: W at standard epoch plus rate in days; some planets with decreasing W | archinal2018 (read) | Table 1, p.8 | NOT FIT C6 | passage exists (t8: "d = Interval in days from the standard epoch"; Venus "W = 160.20 - 1.4813688d"; t9 Uranus "W = 203.81 - 501.1600928d") but the row does not name Table 1 |
| 9 | decisions/0004:243 | node Q at alpha0 + 90, W measured easterly from Q, p.6 | archinal2018 (read) | p.6 | FIT | t6: "the node Q is defined as the node at alpha0 + 90 ... W, the angle measured easterly along the body's equator from the Q to B" |
| 10 | decisions/0004:325 | prograde or retrograde as W increases or decreases, p.6 | archinal2018 (read) | p.6 | FIT | t6: "If W increases with time, the planet has a direct (or prograde) rotation ... retrograde" |
| 11 | decisions/0004:342 | W measured from the node of the body's equator, p.6 | archinal2018 (read) | p.6 | FIT | t6, as #9 |
| 12 | decisions/0005:206 | IAU north pole by invariable plane (rejected alternative), p.6 | archinal2018 (read) | p.6 | FIT | t6: "The north pole is that pole of rotation that lies on the north side of the invariable plane" |
| 13 | decisions/0008:169 | W0 as W at a named epoch, p.6 | archinal2018 (read) | p.6 | FIT | t6: "W0 is the value of W at J2000.0 (or occasionally ... some other specified epoch)" |
| 14 | test/dispositions/fixtures.jl:9 | fixture locator default (no value taken) | archinal2018 (read) | "Table 1" | FIT | a constructor fixture; no content of the source is used |
| 15 | INDEX.md:28 anchors | gn = 980.665 cm/s^2, Declaration 2, p.70 | cgpm1901 (read) | p.70 | FIT | t70 (header "70"): "Le nombre adopte ... pour la valeur de l'acceleration normale de la pesanteur est 980,665 cm/sec^2"; "adoptee a l'unanimite" |
| 16 | src/EarthRatios/EarthRatios.jl:20-25 | gravity_unit 9.80665 | cgpm1901 (read) | Declaration 2, p.70 | FIT | as #15 |
| 17 | INDEX.md:29 anchors | closed-form Kepler solver; eqs 30-35 residual and derivative forms | markley1995 (read) | eqs 30-35 | FIT | t9-t10: eq 30 derivative with 2e sin^2(E/2); eqs 31-33 f(E) = M*(e,E) - M, M* = (1-e)E + eE^3 num/den for e > 0.5 and E < 1 rad; eq 34 Pade coefficients; eq 35 f'' |
| 18 | src/Orbit/kepler.jl:4 (and :71) | "the residual and the derivative are Markley equations 30 to 35" | markley1995 (read) | eqs 30-35 | NOT FIT C2 (minor) | implementation (kepler.jl:44-66): residual (1-e)E + e(E - sin E) - M with E - sin E by a series through E^15 below 0.5 rad at every e. That is the split of eq 33, but eq 34's Pade approximant, eq 33's domain (e > 0.5, E < 1 rad) and eq 35's second derivative are not used; eq 30 matches (kepler.jl:71) |
| 19 | src/Orbit/kepler.jl:87, :115 | Markley start, eqs 20, 5, 9, 10, 14, 15 | markley1995 (read) | those eqs | FIT | read for the algorithm (row) |
| 20 | test/orbit/runtests.jl:47 | unrefined closed form, eqs 20-29 | markley1995 (read) | eqs 20-29 | FIT | as #19 |
| 21 | docs/imports/astrolib-jl.md:9-27, 150 | AstroLib implements Markley eqs 20, 5, 9, 10, 14, 15 and corrections 21-29 | markley1995 (read) | eqs | FIT | as #19 |
| 22 | decisions/0008:177-180 | residual and derivative "which are Markley equations 30 to 35", series for E - sin E | markley1995 (read) | eqs 30-35 | NOT FIT C2 (minor) | as #18; the amendment does name the series, but the range still claims eqs 34-35 |
| 23 | docs/oracles/registry.toml:142 (system.kepler_period threshold) | "reachable only with the residual and derivative of Markley equations 30 to 35" | markley1995 (read) | eqs 30-35 | NOT FIT C2 (minor) | as #18 |
| 24 | docs/plans/fiddlybits-52v.5-time.md:95-127 | Markley closed form as starting value | markley1995 (read) | closed form | FIT | as #19 |
| 25 | INDEX.md:30 anchors | element set, omega = varpi - Omega, M = L - varpi, R_z(-Omega)R_x(-I)R_z(-omega) by components, Table 1 heading | standish1992 (read) | Formulae section; Table 1 heading | FIT | html: "omega = varpi - Omega ; M = L - varpi + bT^2 ..."; "r_ecl = R_z(-Omega) R_x(-I) R_z(-omega) r'", components written out; "Table 1 ... with respect to the mean ecliptic and equinox of J2000, valid for the time-interval 1800 AD - 2050 AD" |
| 26 | decisions/0004:240 | node of the JPL rotation, Formulae section | standish1992 (read) | Formulae | FIT | as #25 |
| 27 | decisions/0004:375 | vernal equinox origin of the JPL elements, Table 1 heading | standish1992 (read) | Table 1 heading | FIT | as #25 |
| 28 | decisions/0004:461 | reference bullet | standish1992 (read) | Formulae; Table 1 heading | FIT | as #25 |
| 29 | decisions/0008:123, 0008:170 | tabulated mean longitude converts through a Kepler solve | standish1992 (read) | Table 1; Formulae | FIT | Formulae section lists L as a tabulated element and derives M = L - varpi before the Kepler solve |
| 30 | docs/plans/fiddlybits-52v.5-time.md:209 | component form R_z(Omega)R_x(i)R_z(omega) applied to the in-plane position | standish1992 (read) | Formulae | FIT | "applied using the corresponding vector rotation", with the component matrix shown |
| 31 | test/planets/earth.jl:92, 98, 111 (branch) | Earth() a = 1.00000261 au, e = 0.01671123, long.peri 102.93768193 deg, EM Bary row | standish1992 (read) | Table 1, EM Bary row | NOT FIT C6 | values present in Table 1 ("EM Bary 1.00000261 0.01671123 -0.00001531 100.46457166 102.93768193 0.0"), but the row names only the Formulae section and Table 1's heading as read |
| 32 | INDEX.md:39 anchors | Darwin-Radau, q, f, C, Fig 4.9, eqs 4.95-4.97, 4.99, 4.101-4.103, 4.109, 4.110, 4.118-4.119, 2.22, 2.25, p.24 | murray2000 (read) | as listed | FIT | t167 (p.153): eq 4.112 "(C/mR^2) = (2/3)[1 - (2/5)(5q/2f - 1)^(1/2)]", "The underlying assumption is that the object concerned is in hydrostatic equilibrium", eq 4.113; t163-t168 (pp.149-154) carry 4.95-4.119 and Fig 4.9; t42-t43 (pp.28-29) carry 2.22 and 2.25 |
| 33 | src/Systems/figure.jl:5-177 | flattening from Darwin-Radau solved for f, q, C range, extreme q | murray2000 (read) | eqs 4.101-4.103, 4.112, 4.113, Fig 4.9 | FIT | as #32; the inversion f = (5q/2)/(1 + (25/4)(1 - 3C/2)^2) follows from 4.112 algebraically |
| 34 | src/Systems/gravity.jl:4-96 | mu = G(m1+m2) p.24, 2.22, 2.25, 4.95-4.97 | murray2000 (read) | as listed | FIT | as #32 |
| 35 | test/system/gravity.jl:88-90 | figure arm: eqs 4.112 and 4.114, p.153; 4.110 and p.151 | murray2000 (read) | eq 4.114 | NOT FIT C6 (minor) | t167: eq 4.114 "J2/f = -3/10 + 5/2 C - 15/8 C^2" exists on p.153, but the row does not name 4.114 |
| 36 | src/Systems/figure.jl:5, gravity.jl:4, test/system/gravity.jl:88 | "Murray and Dermott (2000)" | murray2000 (read) | edition year | NOT FIT C4 (minor) | t4 (copyright page): "First published 1999 / Reprinted 2001, 2004, 2005, 2006, 2008"; decisions 0004, 0008 and 0032 say 1999. The held copy is a reprint of the 1999 edition; no 2000 edition exists |
| 37 | decisions/0032:68-70 | tidal torques, rotation and obliquity evolution; the formulation declared-absence interfaces are shaped by | murray2000 (read) | none given | NOT FIT C6 | the row's read passages are sections 2 and 4.5-4.6 relations; tidal torques and spin evolution (chapter 5) are not named as read, and the bullet gives no locator |
| 38 | decisions/0004:453 | "the orbital-element set and the hydrostatic figure" (locator in 0032) | murray2000 (read) | "locator in decision 0032" | NOT FIT C6 | hydrostatic figure is inside the read passages; the orbital-element set (chapter 2 elements) is not named as read, and 0032 carries no locator to defer to |
| 39 | decisions/0008:167 | "Kepler's equation and the orbital-element conventions" (locator in 0032) | murray2000 (read) | "locator in decision 0032" | NOT FIT C6 | Kepler's equation and the element conventions of chapter 2 beyond eqs 2.22 and 2.25 are not named as read; 0032 gives no locator |
| 40 | INDEX.md:40 anchors | omega = 7292115e-11 rad/s, p.131 Defining Constants (exact); Resolution No 7 p.128 | moritz2000 (read) | p.131 | FIT | t4 (header 131): "Defining Constants (exact) ... x = 7 292 115 x 10^-11 rad s^-1"; t1 (p.128) "RESOLUTION N 7" |
| 41 | src/EarthRatios/EarthRatios.jl:71-76 | rotation_rate_unit | moritz2000 (read) | p.131 | FIT | as #40 |
| 42 | test/system/earth_ratios.jl:5-21 | test of the value and locator | moritz2000 (read) | p.131 | FIT | as #40 |
| 43 | test/lint/runtests.jl:131-185 | lint positive controls on the DOI string | moritz2000 (read) | DOI | FIT | uses the identifier only |
| 44 | test/planets/earth.jl:57-62 (branch) | sidereal period 2 pi / omega | moritz2000 (read) | p.131 | FIT | as #40; the inversion is stated in the locator |
| 45 | INDEX.md:47 anchors | ARS (3,4,3) section 2.7 | ascher1997 (read) | section 2.7 | FIT | t8 l.79: "2.7. L-stable, three-stage, third-order DIRK (3, 4, 3)"; t9 gamma 0.4358665215 |
| 46 | decisions/0041:41 | ARS343 coefficients checked against section 2.7 | ascher1997 (read) | section 2.7 | FIT | as #45 |
| 47 | decisions/0041:132-137 | reference bullet | ascher1997 (read) | section 2.7 | FIT | as #45 |
| 48 | INDEX.md:48 anchors | aggregation error grows with curvature and variance; covariance for multivariate | rastetter1992 (read) | argument | FIT | t4: "The discrepancy between f(xbar) and fbar is the aggregation error"; t11 moment expansion with variances and covariance sigma_xy |
| 49 | INDEX.md:51 anchors | Table 4.1 damping times across seven truncations, "a constant eddy velocity of 12.6 to 17.5 m/s" | Report-349 (read) | Table 4.1 | NOT FIT C2 | PDF p.30 (t36) Table 4.1: tau0 = 6, 12, 9, 7, 5, 3, 2 h for T21, T31, T42, T63, T85, T106, T159. With length pi a/n0, T31-T159 give 14.9, 14.7, 12.6, 13.1, 17.5, 17.5 m/s, while T21 gives 44.1 m/s. Any length choice leaves T21 a factor of about 3 above the other six, so the range holds for six truncations, not seven |
| 50 | INDEX.md:60 anchors | EI per GLiM class relative to acid plutonic, 1.0 to 3.2 | moosdorf2018 (read) | table | FIT | t8: "the erodibility of rocks relative to acid plutonics (granite) varies by a factor of 3.2"; t4 EI normalised to acid plutonics |
| 51 | requirements/ter/lithology-class-denotes-a-rock.md:121 | reference for erodibility contrast | moosdorf2018 (read) | - | FIT | as #50 |
| 52 | INDEX.md:61 anchors | K by lithology spanning five orders | stock1999 (read) | values | FIT | t9: "K varies from 10^-7 to 10^-2 m^0.2/yr in a manner consistent with a primary dependence on lithology"; t10 "5 orders of magnitude" |
| 53 | requirements/hyd/basin-fate-is-a-process.md:50 | intact-rock range five orders (Stock and Montgomery) | stock1999 (read) | - | FIT | as #52 |
| 54 | requirements/ter/lithology-class-denotes-a-rock.md:129 | reference | stock1999 (read) | - | FIT | as #52 |
| 55 | INDEX.md:62 anchors | expressed contrast about factor 4 by ksn against two orders in intact strength | zondervan2020 (read) | factor | FIT | t11 l.19-20: "between a factor of 4 calculated through ksn and two orders of magnitude calculated through UCS" |
| 56 | requirements/hyd/basin-fate-is-a-process.md:49 | "about a factor of 4, Zondervan et al." | zondervan2020 (read) | - | FIT | as #55 (t6 l.70 gives "four to fifteen" for the red beds, so 4 is the lower end of the ksn range). The reference at :122 still reads "DOI: to confirm (10.1016/j.epsl.2020.116221 believed)"; INDEX confirms it |
| 57 | requirements/ter/lithology-class-denotes-a-rock.md:124 | reference | zondervan2020 (read) | - | FIT | as #55 |
| 58 | INDEX.md:68 anchors | Culmann maximum stable height with rho g explicit, eq 7 | montgomery2001 (read) | eq 7 | FIT | t7 l.19-23: "Culmann's two dimensional, limit equilibrium slope stability model ... Hc = 4C sin(theta) cos(phi) / rho g [1 - cos(theta - phi)] (7)" |
| 59 | requirements/ter/gravity-enters-through-the-law.md:82, 133 | Culmann-type H_c ~ 1/(rho g) with Sourced strength | montgomery2001 (read) | eq 7 | FIT | as #58 |
| 60 | INDEX.md:69 anchors | bulk-density tables 4-1 and 4-5 | daly1966 (read) | tables 4-1, 4-5 | FIT | t2 "TABLE 4-1. AVERAGE DENSITIES OF HOLOCRYSTALLINE IGNEOUS ROCKS"; t8 "TABLE 4-5. AVERAGE DENSITIES OF METAMORPHIC ROCKS" |
| 61 | requirements/ter/lithology-class-denotes-a-rock.md:76, 172 | Sourced density per class | daly1966 (read) | - | FIT | as #60; the reference still says "DOI: to confirm", which is stale against the INDEX row |
| 62 | INDEX.md:71 anchors | exponential soil production function, e-folding depth, frost mechanism named | heimsath1997 (read) | law | FIT | t4 Fig 3: "-(de/dt) = (77 +/- 9)e^((-0.023 +/- 0.003)h)"; t3 l.9 names "freeze-thaw" and "biogenic disturbance" |
| 63 | decisions/0022:100 | reference for regolith production | heimsath1997 (read) | - | FIT | as #62 |
| 64 | requirements/ped/weathering-real-clock.md:29, 104 | Heimsath's exponential production function | heimsath1997 (read) | - | FIT | as #62 |
| 65 | INDEX.md:72 anchors | global depth-to-bedrock statistics, Table 1 | shangguan2017 (read) | Table 1 | FIT | t23 Table 1 (cm): World absolute DTB mean 1,309.3, median 670 |
| 66 | requirements/ped/weathering-real-clock.md:32, 116 | world median 6.70 m, mean 13.09 m | shangguan2017 (read) | Table 1 | FIT | as #65 |
| 67 | INDEX.md:73 anchors | glass rate against silica, grain lifetimes, field-to-laboratory factor | wolff-boenisch2004 (read) | rates | FIT | t1: rates "vary exponentially with the silica content"; t12 l.81-99: 1 mm basaltic glass lifetime 500 yr, and Ruxton (1988) andesite in the field "approximately 20 times smaller than that estimated from rates measured in this study", Rowe and Brantley (1993) aquifer "50 times greater" |
| 68 | INDEX.md:75 anchors | calcite-buffer quartic, Methods eq 6 at stated pCO2; gibbsite buffer; water-balance threshold | slessarev2016 (read) | Methods eq 6 | FIT | t5 l.53-66: "(6) ... We solved this equation for H+ at 25 C and a pCO2 of 3.45 x 10^-4 atm ... (that is, the expected pH is 8.3 before 1977)"; t5 l.75-81 gibbsite pH 5.1 |
| 69 | requirements/ped/soil-ph-from-run-pco2.md:11-16 | 20,000 of 60,291; modes 8.2 and 5.1; 42 percent; 2.6 times | slessarev2016 (read) | text | FIT | t1 l.20-21; t2 l.34-42 ("explain 42%"), l.77 ("2.6 times") |
| 70 | requirements/ped/soil-ph-from-run-pco2.md:26-30 | calcite end validated at 3.45e-4 atm against 8.2; 8.3 remark carries no pressure | slessarev2016 (read) | Methods eq 6 | FIT | as #68 |
| 71 | requirements/ped/soil-ph-from-run-pco2.md:98, 120 | REPORT against the resampled distribution; buffer equilibria from Slessarev | slessarev2016 (read) | - | FIT | as #68-69 |
| 72 | INDEX.md:76 anchors | five solute behaviour types | eugster1979 (read) | scheme | FIT | t6 "GENERAL SOLUTE BEHAVIOR"; t7 type III gradual removal, conservative elements; t11 "type IV trend" |
| 73 | requirements/ped/brine-divide-per-basin.md:11 | five behaviours under evaporative concentration | eugster1979 (read) | - | FIT | as #72 |
| 74 | INDEX.md:77 anchors | chemical divide at calcite and the Spencer triangle | deocampo2014 (read) | construction | FIT | t11 l.65-80: "simple chemical divides", "Ca Spencer Triangle" and CaCO3 precipitation pathways |
| 75 | requirements/ped/brine-divide-per-basin.md:86 | reference | deocampo2014 (read) | - | FIT | as #74; the DOI there still reads "to confirm ... believed" |
| 76 | INDEX.md:85 anchors | volcanism per unit mass rises monotonically with mass under plate tectonics, "bounding the exponent at 1.0 to 1.34" | kite2009 (read) | bracket | NOT FIT C3 | t16: "Rate per unit mass increases monotonically with increasing mass, for all times. Per unit mass, rates of volcanism vary only by a factor of three on planets < 3 Gyr old and > 1 M_E, but a stronger mass dependence develops for older planets (Figure 15)". The paper states no exponent; 1.34 is 1 + ln3/ln25 over 1-25 M_E, and the source confines the factor of three to planets under 3 Gyr. The row states the bracket without that age condition, and the passage says it is exceeded for older planets |
| 77 | INDEX.md:93 | porphyry plutons at 5-15 km paleodepth; epithermal < 1 km | sillitoe2010 (read) | depths | FIT | t1 l.12 "at paleodepths of 5 to 15 km"; t15 l.5 "shallow-level (<1 km paleodepth) counterparts" |
| 78 | decisions/0022:110 (overlay, 0022:47) | reference for age-controlled prospectivity overlay | sillitoe2010 (read) | - | FIT | as #77 |
| 79 | INDEX.md:94 | epizonal, mesozonal, hypozonal classes | groves1998 (read) | classes | FIT | t1 l.32: "epizonal (<6 km), mesozonal (6-12 km) and hypozonal (>12 km) classes" |
| 80 | decisions/0022:111 | reference for overlay | groves1998 (read) | - | FIT | as #79 |
| 81 | INDEX.md:95 | cold cratonic keel below about 140 km | shirey2013 (read) | requirement | FIT | t9 l.48 ">140 km"; t2 l.94-95 "only the cratonic lithospheric keel is cold enough" |
| 82 | INDEX.md:96 | VMS settings | hannington2014 (read) | settings | FIT | t3 l.36, l.60: arcs, back-arc spreading centers, mid-ocean ridges, Cyprus-type |
| 83 | INDEX.md:97 | Cu-Mo in compressive thickened-crust arcs versus Au-rich in island arcs | cooke2005 (read) | split | FIT | t1 l.22 "Compressive tectonic environments, thickened continental crust"; t6 l.29 "high concentration of large gold-rich porphyry deposits in the southwest Pacific" |
| 84 | INDEX.md:100 | komatiite class 2.7 to 1.9 Ga | naldrett2010 (read) | classification | FIT | t1 l.13: "the komatiite-related class ranges from 2.7 to 1.9 Ga in age" |
| 85 | INDEX.md:101 | podiform chromitite in Moho transition zone and mantle section | arai2015 (read) | placement | FIT | t6 l.21-25 |
| 86 | INDEX.md:102 | bauxite thresholds on gridded climate | price1997 (read) | thresholds | FIT | t4 l.11: "precipitation is greater than 1200 mm per year and 6 or fewer months receive less than 60 mm" |
| 87 | INDEX.md:103 | looser Oxisol thresholds | retallack2010 (read) | thresholds | FIT | t8 l.129-130: "1,100 mm mean annual precipitation", "17 C mean annual temperature" |
| 88 | INDEX.md:104 | Ni laterite criteria | butt2013 (read) | criteria | FIT | t3 l.56 olivine-rich ultramafic; t4 l.43 "rainfall exceeds 1000 mm/y"; t3 l.162 erosion |
| 89 | INDEX.md:105 | no wet rainfall bound; erosion balancing water-table descent | sillitoe2005 (read) | rule | FIT | t14: "supergene profiles should develop effectively under all climatic extremes"; "the average erosion rate must be in overall balance with the rate of water table descent" |
| 90 | INDEX.md:106 | two-sided relief criterion | freyssinet2005 (read) | criterion | FIT | t15 l.11: "Moderate relief. The rate of weathering ... must exceed the rate of surface lowering" |
| 91 | INDEX.md:107 | enrichment stops below about 1-4 mm/yr, ran above 10 mm/yr | reich2009 (read) | numbers | FIT | t7 l.10 ">10 mm/year precipitation"; l.31 "< 1-4 mm/year" |
| 92 | INDEX.md:108 | vadose oxidation, enrichment below the water table | reich2015 (read) | structure | FIT | t2 l.14; t3 l.90-91 |
| 93 | INDEX.md:109 | sourced negative: placer discharge and gradient criteria unestablished | slingerland1986 (read) | negative | FIT | t31 (p.143): "additional work is needed to determine the optimal regional sediment and water yields and fluid energy slopes for placer development" |
| 94 | INDEX.md:110 | gold flattened rather than lost with distance | knight1999 (read) | result | FIT | t4, t6: flatness and roundness trends with transport distance |
| 95 | INDEX.md:112 | Li and B from volcanic rock alteration, not hydrothermal | risacher2009 (read) | finding | FIT | t17: "hydrothermal alteration is not specifically responsible for the high content of Li and B in waters and brines of Andean salars" |
| 96 | INDEX.md:113 | sulfate-rich versus calcium-rich classification | risacher2003 (read) | classification | FIT | t1 l.33 "sulfate-rich or calcium-rich, near-neutral brines" |
| 97 | INDEX.md:114 | six characteristics; intracratonic negative | munk2016 (read) | characteristics | FIT | t2 l.42 "share six"; l.84 "not been reported from intracratonic basins" |
| 98 | INDEX.md:115 | closed basin the single most important factor | bradley2013 (read) | rule | FIT | t7 l.2 "The single most important factor ... is whether or not the basin is closed" |
| 99 | INDEX.md:116 | rhyolitic volcanic source, B-As-F-Li | helvaci2019 (read) | split | FIT | t1 l.23 "sourced from andesitic to rhyolitic volcanics"; t15-t16 rhyolites |
| 100 | requirements/ped/soil-ph-from-run-pco2.md:125-126 | reference bullet "Turkish Borate Deposits ... Identifier confirmed in the references index (INDEX.md, held)" | helvaci2019 (read) | none | NOT FIT C6 | REQ-PED-003 (soil pH) takes nothing from Helvaci: no body text cites it, and the bullet records the source as "held" while INDEX marks it read for the prospectivity overlay |
| 101 | INDEX.md:125 anchors | basin graph, passes, external basin, minimum spanning tree, section 2.2 p.552; receivers updated only, p.550, 2.3 p.554 | cordonnier2019 (read) | section 2.2 | FIT | t4 (p.552) sections 2.1-2.2: passes minimise max(z_n1, z_n2); "a virtual basin (let us call it external basin) to which we link all the boundary basins"; minimum spanning tree; t6 (p.554) 2.3 receiver update |
| 102 | INDEX.md:129 anchors | geometric-mean log k per hydrolithology with sigma and n (Table 1); scale-independent 5-100 km; evaporite unassigned | gleeson2011 (read) | Table 1 | FIT | t3 Table 1 "logk mgeo is the geometric mean logarithmic permeability; s is the standard deviation; n is the number"; "not assigned"; t3 l.238-239 "(5-100 km in length) and are not scale dependent ... except carbonates" |
| 103 | decisions/0019:43-44, 144 | transmissivity from permeability by hydrolithology, spread Bracketed | gleeson2011 (read) | Table 1 | FIT | as #102 |
| 104 | requirements/hyd/groundwater-sinks-baselevels-exchange.md:48-51, 113 | Table 1 class means, sigma 1.5-2.5 orders, scale range, carbonate, evaporite | gleeson2011 (read) | Table 1 | FIT | as #102 |
| 105 | requirements/hyd/water-table-complementarity-identities.md:103 | reference | gleeson2011 (read) | - | FIT | as #102 |
| 106 | requirements/hyd/water-table-skill-oracle.md:13, 100 | GLHYMPS percentiles equal Gleeson class means (a predecessor measurement) | gleeson2011 (read) | Table 1 | FIT | class means from Table 1; the equality is the predecessor's measurement, not the paper's claim |
| 107 | requirements/ped/lithology-registry-one-reading.md:20-23, 76 | keyed on Durr classes; evaporite "not assigned"; carbonate one-signed | gleeson2011 (read) | Table 1 | FIT | as #102; t3 l.191 Durr et al. (2005) classes |
| 108 | requirements/ped/per-rock-then-average.md:27, 67 | the class statistic that transfers is the geometric mean | gleeson2011 (read) | p.2 | FIT | t2 l.16-21: "effective (larger-scale) permeability is often considered to be best represented by the geometric mean ... We adopt the geometric mean of permeability values as the best estimate of regional-scale permeability" |

#### Not-fit cases

##### N1. The Archinal row states adopted uses that were rejected, and omits the passages actually used (#1, #5, #6, #8)
- Where: docs/references/INDEX.md:27; uses at decisions/0004:120, 207, 326, 460, and test/planets/earth.jl:71 on branch fiddlybits-52v.4.5.
- Use: the row says it was read for the north pole by the invariable plane, the prime meridian W for featureless bodies, and prograde or retrograde from dW/dt, "all three are what the System struct will adopt". The tree uses p.22 (the positive pole by the right-hand rule), Table 1 p.8 (W0 plus a rate, decreasing W) and p.9 footnote 2 (Earth excluded).
- Source: Archinal et al. 2018, 10.1007/s10569-017-9805-5.
- Category: C6.
- What is wrong: decisions 0004 (Alternatives, "Obliquity to the pole on the orbit normal's side ... Lost") and 0005 ("The spin axis as the pole on the orbit normal's side ... Lost") rejected the invariable-plane north pole. The positive pole the System adopts is p.22's right-hand rule, and p.22, Table 1 and p.9 fn 2 are not named as read.
- Evidence: every passage exists and supports its use. t22 l.23: "The rotation pole for a body is chosen to be the one following the right-hand rule"; t8 "W = 160.20 - 1.4813688d" (Venus); t9 l.60-64 IERS footnote.
- Fix class: (a) in substance, since the passages are on disk and verified here. The fix rewrites the row's anchors: p.6 as the rejected north-pole alternative plus the adopted prime-meridian and sense definitions, p.22, Table 1 p.8, p.9 fn 2 and Table 4. INDEX.md is edited by open branch fiddlybits-k6b, so the edit waits for k6b or goes in a row. Boundary: docs/references/INDEX.md, the archinal2018 row. Acceptance: lint_sourced passes, and every Archinal page cited in src/, test/ and docs/decisions is named in the row.

##### N2. 6371.0084 km is not a volumetric mean radius (#3, #4)
- Where: src/EarthRatios/EarthRatios.jl:30 (docstring); test/planets/earth.jl:10 and :52-54 on branch fiddlybits-52v.4.5 (`DeclaredBulk(volumetric_mean_radius = Sourced(6_371_008.4, ...))`).
- Use: Archinal Table 4's Earth mean radius, declared as the volumetric mean radius that decision 0005:242 names as the mesh radius.
- Source: Archinal et al. 2018, Table 4 (t28).
- Category: C2.
- What is wrong: the source does not state that its Earth mean radius is volumetric. It says the mean radius "cannot be consistently derived from triaxial semi-axes values alone, since different authors have used different formulae" (t36), and marks the Earth values "for comparison only" (Table 4 footnote b). From Table 4's own equatorial and polar radii:

  | radius | formula | value (km) |
  | --- | --- | --- |
  | arithmetic mean | (2a+b)/3 | 6371.00837, matching the tabulated 6371.0084 |
  | authalic | - | 6371.00678 |
  | volume-equivalent | (a^2 b)^(1/3) | 6371.00039 |

  The declared value is therefore the arithmetic mean radius, 8.0 m (1.3e-6 relative) above the volumetric one.
- Fix class: (d), USER DECISION. The Earth() declared value is a test instance's declared value on an open branch, and changing it to a volumetric radius Derived from Table 4's a and b would also change its disposition.
- Options for the user:
  - Keep 6371008.4 m, and have the field's locator and the EarthRatios docstring say "mean radius (Table 4)", accepting an 8 m difference from the field's definition.
  - Declare the Earth radius Derived from Table 4's equatorial and polar radii by (a^2 b)^(1/3). That changes Earth()'s value and disposition, and radius_unit's value.
  - Find a read source that states a volumetric Earth radius.
- The EarthRatios docstring wording alone is a (a) correction in src/EarthRatios/EarthRatios.jl, which no open branch edits.

##### N3. Standish Table 1 values used beyond the passage named as read (#31)
- Where: test/planets/earth.jl:92, 98, 111 (branch fiddlybits-52v.4.5).
- Use: Earth() semi-major axis, eccentricity and longitude of periapsis from Table 1's EM Bary row.
- Source: standish1992 (JPL approx_pos page).
- Category: C6.
- What is wrong: the row names the Formulae section and Table 1's heading only.
- Evidence: the values are present, "EM Bary 1.00000261 0.01671123 -0.00001531 100.46457166 102.93768193 0.0"; the table is valid 1800-2050 against the mean ecliptic and equinox of J2000.
- Fix class: (a), adding "Table 1, EM Bary row: a, e, long.peri." to the row's anchors. INDEX.md is edited by k6b.

##### N4. Markley "equations 30 to 35" names equations the implementation does not use (#18, #22, #23)
- Where: src/Orbit/kepler.jl:4; decisions/0008:177-180 (amendment); docs/oracles/registry.toml:142 (system.kepler_period threshold).
- Use: the residual and derivative cited as Markley equations 30 to 35.
- Source: Markley 1995, 10.1007/BF00691917, t9-t10.
- Category: C2 (minor).
- What is wrong: Markley's eq 33 defines M* = (1-e)E + eE^3 num/den only for e > 0.5 and E < 1 rad, and eq 34 gives the Pade coefficients of num and den. Eq 35 is the second derivative. The implementation uses eq 30's derivative and eq 33's split (1-e)E + e(E - sin E), but evaluates E - sin E by its own series through E^15 below 0.5 rad at every eccentricity (kepler.jl:44-66). It does not use eq 34 or eq 35.
- Fix class:
  - (a) for the kepler.jl comment: "Markley equations 30 to 33, with E - sin E by a series in place of equation 34".
  - For decision 0008's amendment text: the parent judges; this is wording, not the decision's basis.
  - For registry.toml:142: the threshold text of an unregistered tier-1 entry, in a file edited by open branches. It merges registry-only, and a threshold edit together with src/ is forbidden, so it is listed for the parent.

##### N5. Murray and Dermott: uses beyond the passages read, and a wrong year (#35, #36, #37, #38, #39)
- Where:
  - test/system/gravity.jl:89: eq 4.114, not named in the row.
  - src/Systems/figure.jl:5, gravity.jl:4, test/system/gravity.jl:88: "(2000)".
  - decisions/0032:68-70: tidal torques, rotation and obliquity evolution.
  - decisions/0004:453 and 0008:167: "orbital-element set" and "Kepler's equation and the orbital-element conventions", both "locator in decision 0032", which carries no locator.
- Source: Murray and Dermott, Solar System Dynamics, 10.1017/CBO9781139174817.
- Categories: C6 (#35, #37-#39); C4 (#36).
- Evidence:
  - The row names eqs 2.22, 2.25, p.24, 4.95-4.119 and Fig 4.9.
  - Eq 4.114 is on p.153 (t167): "J2/f = -3/10 + (5/2)C - (15/8)C^2".
  - Copyright page (t4): "First published 1999 / Reprinted 2001, ... 2008".
- Fix class:
  - (a) for the year label in src/Systems/figure.jl, src/Systems/gravity.jl and test/system/gravity.jl (no open branch edits them).
  - (a) for adding eq 4.114 to the row, once INDEX.md is free.
  - (b) for the decision citations: read chapter 2's element definitions and Kepler's equation, and the tidal chapter, then give each a locator in decision 0032 and name them in the row. Otherwise reword those references as background not read, which the parent should treat as touching a decision's References, not its basis.

##### N6. The ECHAM5 anchor's "constant eddy velocity across seven truncations" fails for T21 (#49)
- Where: docs/references/INDEX.md:51.
- Use: Table 4.1 read as an advective time giving 12.6 to 17.5 m/s across seven truncations, the form a Closure is declared in.
- Source: Report-349, 10.17617/2.995269, PDF p.30.
- Category: C2.
- Evidence: Table 4.1 gives tau0 = 6, 12, 9, 7, 5, 3, 2 h for T21, T31, T42, T63, T85, T106, T159. With L = pi a/n0 the velocities are 44.1, 14.9, 14.7, 12.6, 13.1, 17.5, 17.5 m/s. The stated range covers six truncations. T21 is about three times higher under any length choice (a/n0 gives 14.0 against 4.0-5.6).
- Fix class: (b). Correct the anchor to six truncations with T21 named as the outlier, or state the length convention and the exception. Nothing in src/, test/, the registry, decisions or plans cites this row today. INDEX.md is edited by k6b.

##### N7. Kite 2009's exponent bracket stated without the age range the source confines it to (#76)
- Where: docs/references/INDEX.md:85.
- Use: B8 outgassing mass-scaling bracket, exponent 1.0 to 1.34.
- Source: Kite et al. 2009, 10.1088/0004-637X/700/2/1732, t16 (arXiv v2 p.16).
- Category: C3.
- Evidence: "Per unit mass, rates of volcanism vary only by a factor of three on planets < 3 Gyr old and > 1 M_E, but a stronger mass dependence develops for older planets (Figure 15)". No exponent is printed. 1.34 = 1 + ln3/ln25 over 1-25 M_E.
- What is wrong: the bracket holds only for planets under 3 Gyr, and the same passage says the upper end is exceeded for older planets. A generic builder with a declared age would carry it outside its range.
- Fix class: (b). State the age condition and the derivation in the anchor, or derive an age-dependent bracket from Fig 15 (t46). No use in the tree yet.

##### N8. Helvaci 2019 cited in the soil-pH record, which takes nothing from it, with a stale status (#100)
- Where: docs/requirements/ped/soil-ph-from-run-pco2.md:125-126.
- Use: none. The bullet reads "Identifier confirmed in the references index (INDEX.md, held)".
- Source: Helvaci 2019, 10.1007/978-3-030-02950-0_11 (INDEX: read, for the borate prospectivity overlay).
- Category: C6.
- What is wrong: a leftover of the citation pass. The record's body never cites it, and the status it states contradicts the INDEX row.
- Fix class: (a). Remove the bullet, or move it to a record that uses the borate rule. The file is not edited by any open branch.

#### Remarks, not counted as not fit

- Reference bullets whose identifier notes are stale against INDEX, which confirms each DOI:
  - requirements/hyd/basin-fate-is-a-process.md:122 (Zondervan, "to confirm ... believed");
  - requirements/ter/lithology-class-denotes-a-rock.md:172 (Daly, "DOI: to confirm");
  - requirements/ped/brine-divide-per-basin.md:86 (Deocampo, "to confirm ... believed").
- Decision 0004 adopts Archinal p.22's right-hand-rule positive pole, which the IAU scopes to small bodies. The intent is declared, since 0005 records the planet convention as the lost alternative, so it is not C3.
- Earth() takes Standish's EM-barycentre elements, fit over 1800-2050 against the J2000 ecliptic, for an orbit declared against `:invariable_plane` with zero inclination. That frame choice is argued in the instance's Irreducible text. It belongs to the code-scope audit, not to this row.

#### Fetch failures and paywalled sources

None. Every source in scope was on disk under /home/cfutro/git/fiddlybits/references/.

### X2: INDEX read rows, lines 130 to 400


Worktree audited: /home/cfutro/git/fiddlybits/.beads/worktrees/fiddlybits-9j0 at 625832c, plus
test/planets on branch fiddlybits-52v.4.5 (the only branch carrying test/planets).
Source text: /home/cfutro/git/fiddlybits/references/text/<stem>/<NNNN>.txt (PDF page index), PDFs
opened by eye where the text layer stripped a table (Hale 1973 p.557, Larcher 2005 p.191, Fan 2013
supplement Table S1 p.37).

#### Counts

- Rows in scope (read, lines 130-400): 48. Row verdicts: 43 fit, 5 not fit, 0 not verified.
- Citing uses found (src, test incl. branch test/planets, registry anchors by title, decisions,
  requirements, plans, imports): 73. Use-coverage verdicts: 63 fit, 10 not fit, 0 not verified.
- Total verdicts: 121; fit 106; not fit 15; not verified 0.
- No use in docs/plans or docs/imports cites any of these 48 rows.

#### Every row and every use

Verdict key: FIT; NF-Cn (not fit, category n). "Row" is the INDEX row's own anchor against its
passage; a use line is judged on whether it falls inside what the row read.

| # | where | use | source (INDEX status) | locator | verdict | evidence |
|---|---|---|---|---|---|---|
| 1 | INDEX.md:143 row | mixing length l = kz/(1+kz/lambda), lambda = 0.00027 G/f; coefficient a one-site fit | blackadar1962 (read) | eq. 24, 25 | FIT | p.5 (pdf 0005): eq. (24), eq. (25) lambda = 0.00027 G/f; "fits the values computed from the Leipzig profile" |
| 2 | requirements/sys/constants-have-five-dispositions.md:126 | a scaling that transfers where the value does not | blackadar1962 | ref list | FIT | as row |
| 3 | INDEX.md:145 row | areal z0 from averaging drag coefficients at the blending height | mason1988 (read) | eq. 14 | NF-C2 | pdf 0004: eq. (14) is the blending height l_b only; the averaging operator 1/ln^2(l_b/z0eff) = sum f_i/ln^2(l_b/z0i) is eq. (15) |
| 4 | requirements/sys/constants-have-five-dispositions.md:50 | orographic roughness derived "through ... Mason (1988)" | mason1988 | body | FIT | the operator exists in the read paper (eq. 15, pdf 0004); only the row's locator is short |
| 5 | requirements/ter/nonlinear-order-in-space.md:92-94 | "The blending height" | mason1988 | ref list | FIT | eq. (14) |
| 6 | INDEX.md:146 row | effective drag = hill pressure drag + skin friction; constant at two closures | wood1993 (read) | eq. 33 | FIT | pdf 0027 eq. (33) 1/log^2(Zm/Z0eff) = Ca/kappa^2 + 1/log^2(Zm/Z0); pdf 0028: 5.9 theta^2 mixing-length, 3.4 theta^2 second-order closure |
| 7 | requirements/sys/constants-have-five-dispositions.md:49,127 | orographic roughness derivation | wood1993 | ref list | FIT | as row |
| 8 | requirements/ter/nonlinear-order-in-space.md:95-97 | reference | wood1993 | ref list, "DOI: to confirm" | FIT (note) | content fit; the DOI 10.1002/qj.49711951402 is confirmed in INDEX and could replace "to confirm" |
| 9 | INDEX.md:147 row | Ca = 2 alpha beta Cmd theta^2 (eq. 6), eqs. 4-5; slope variance non-convergence | beljaars2004 (read) | eq. 4-6 | FIT | pdf 0007 eqs. (4),(5),(6); pdf 0002 l.37: slope variance "not necessarily converge asymptotically for infinitely fine orographic resolution" |
| 10 | requirements/sys/constants-have-five-dispositions.md:50,128 | orographic roughness derivation | beljaars2004 | ref list | FIT | as row |
| 11 | requirements/ter/nonlinear-order-in-space.md:98-100 | reference | beljaars2004 | ref list | FIT | as row |
| 12 | INDEX.md:148 row | z0 = 0.5 h s/S, orographic example, limit | lettau1969 (read) | eq. 1 | FIT | p.2: eq. (1); Colorado example h* = 1000 m, z0 = 12.5 m; limit when s/S approaches unity. No uses |
| 13 | INDEX.md:150 row | rain evaporation (Marshall-Palmer) and mean volume-weighted fallspeed, "both with explicit gravity dependence through terminal speed" | kessler1969 (read) | section 8, table 4 | NF-C2 | pdf 0038-0039: V0 = -38.3 N0^-1/8 M^1/8 exp(kz/2) (8.11), footnote 5 coefficient 38.8 for the volume-weighted fallspeed, (8.12c) terminal speed 130 D^1/2: empirical in D, no g anywhere in section 8 |
| 14 | requirements/sys/constants-have-five-dispositions.md:54,124 | re-evaporation form "carrying gravity to the -0.289 power", derived from Kessler | kessler1969 | body | NF-C6 | the gravity exponent needs a terminal-velocity law with g; Kessler's is an Earth-air fit with none |
| 15 | INDEX.md:158 row | continuum formalism (section 3); one-signed upward uncertainty in NIR windows "(Table 3 scale factors)" | mlawer2012 (read) | section 3, Table 3 | NF-C2 | pdf 0033: Table 3 is "MT_CKD_2.5 H2O self-continuum scaling factors relative to MT_CKD_1.0" at 2050-3150 cm-1, an adopted revision, not an uncertainty; the upward NIR-window evidence is p.2551-2552 text: lab values 2-4x (2400-2640, 6140 cm-1), 6-12x (4600 cm-1), "All studies consistently point to the need for greater absorption than in MT_CKD_1.0" |
| 16 | decisions/0016-atmosphere-physics-scope.md:65,200 | MT_CKD carries water self and water-air foreign continuum over its range | mlawer2012 | body | FIT | section 3 formulation (pdf 0010 on) |
| 17 | requirements/atm/radiation-spectrally-resolved-...md:67,114 | foreign continuum carries a nitrogen-oxygen bulk | mlawer2012 | body | FIT | section 3 |
| 18 | INDEX.md:160 row | CIRC Phase I LBL cases; under-absorption of coarser codes | oreopoulos2012 (read) | whole | FIT | pdf 0007: "near-universal underestimate of absorption"; pdf 0005 l.229. No uses |
| 19 | INDEX.md:167 row | liquid-water n, k 0.2-200 um | hale_1973 (read) | Table I | FIT | p.557 Table I "Optical Constants of Water", 0.200 to 200 um |
| 20 | requirements/atm/surface-optics-integrated-...md:102-105 | spectrum-free quantity for cloud co-albedo | hale_1973 | ref list | FIT | Table I |
| 21 | test/planets/synthetic_non_earth.jl:80-105 (branch fiddlybits-52v.4.5) | Sourced moon reflectance from n, k at 0.5, 0.6, 0.7, 1.0, 1.6, 2.0 um | hale_1973 | "Table 1, p. 557" | FIT | p.557 Table I: 0.500 1.00e-9 1.335; 0.600 1.09e-8 1.332; 0.700 3.35e-8 1.331; 1.0 2.89e-6 1.327; 1.6 8.55e-5 1.317; 2.0 1.1e-3 1.306; all six match. Paper numbers it Table I, not 1 (trivial) |
| 22 | INDEX.md:169 row | slab/crushed/powder of same rocks, solid-to-powder ratio median 2.74 | poseidon_surface_albedo/Paragas2025-P25 (read; title not recorded, identifier unverified) | Figure 3 data | NF-C2 | no paper was held; fetched now (open access). The paper, "A New Spectral Library for Modeling the Surfaces of Hot, Rocky Exoplanets", 10.3847/1538-4357/ada9eb, has slab/crushed/powder textures (abstract; section 2) but no 2.74 and no median ratio (full-text grep); the number is computed from the 31 redistributed data files and stands on no read passage |
| 23 | requirements/ter/lithology-class-denotes-a-rock.md:41-42,148 | powder-over-slab factor median 2.74, range 2.19-5.11; ref "The POSEIDON surface albedo database: slab, crushed and powder reflectance of the same rocks" | Paragas 2025 | ref list, "Verbatim title and DOI: to confirm" | NF-C6 (and wrong title) | the cited title does not exist; the real title and DOI are above; the numbers are a derived measurement with no finding recording the computation |
| 24 | INDEX.md:196 row | dust SW refractive indices (Table 4), iron dependence | dibiagio2019 (read) | Table 4 | FIT | pdf 0016: "Table 4. Real (n) and imaginary (k) parts of the refractive index estimated for the 19 analyzed dust samples". No uses |
| 25 | INDEX.md:197 row | LW index; k pinned below 6 um | dibiagio2017 (read) | whole | FIT | pdf 0009: "Below 6 um, k(lambda) was then fixed to the value obtained at 6 um". No uses |
| 26 | INDEX.md:204 row | sea-spray source function eq. 7, Monahan eq. A2, Table 2 production | grythe2014 (read) | eq. 7, A2, Table 2 | FIT | pdf 0010 eq. (7); pdf 0017 (A2); pdf 0009 Table 2 with annual production |
| 27 | decisions/0022-pedology-aeolian-minerals-carbon.md:109 | sea-salt tracer | grythe2014 | ref list | FIT | as row |
| 28 | requirements/atm/aerosol-tracers-...md:91,119 | per-whitecap production spectrum (Monahan; Grythe) | grythe2014 | body | FIT | eq. A2 |
| 29 | INDEX.md:211 row | Kok emission scheme eq. 18a, 18b | kok_2014 (read) | eq. 18a/b | FIT | pdf 0007 (18a), (18b) |
| 30 | decisions/0018-one-land-column.md:119 | dust emission on bare tiles | kok_2014 | ref list | FIT | eq. 18 |
| 31 | decisions/0022-pedology-aeolian-minerals-carbon.md:108 | dust emission | kok_2014 | ref list | FIT | eq. 18 |
| 32 | requirements/atm/dust-emission-drag-partition-...md:59-67,104 | Kok scaling, fitted coefficients Bracketed | kok_2014 | body | FIT | eq. 18, fitted coefficients (pdf 0011 fit of 18b) |
| 33 | requirements/proc/physics-is-not-a-knob-and-earth-is-a-distance.md:81 | reference | kok_2014 | ref list | FIT | as row |
| 34 | requirements/sys/constants-have-five-dispositions.md:123 | a scheme chosen for one fewer unconstrained coefficient | kok_2014 | ref list | FIT | eq. 18 |
| 35 | requirements/sys/earth-calibrated-schemes-re-derive-what-was-held-fixed.md:130 | reference | kok_2014 | ref list | FIT | as row |
| 36 | registry.toml earth.dust_emission anchors | bar "inside the compilation's range" of global dust emission | kok_2014 | anchor by title | NF-C6 (C2) | the paper was read for eq. 18; a full-text grep finds no global emission total or compilation range (no Tg/yr figure); the bar's range has no read source |
| 37 | INDEX.md:212 row | emitted volume size distribution eq. 6 | kok_2010 (read) | eq. 6 | FIT | pdf 0009: "emitted clay fraction of 4.4 +/- 1.0 % predicted from Eq. (6)" |
| 38 | decisions/0022-pedology-aeolian-minerals-carbon.md:107 | dust size distribution | kok_2010 | ref list | FIT | eq. 6 |
| 39 | requirements/atm/aerosol-tracers-...md:126-130 | emitted size distribution the particle description rests on | kok_2010 | ref list | FIT | eq. 6 |
| 40 | registry.toml earth.dust_aod anchors | bar "outside 0.02 to 0.04 fails" on global dust AOD | kok_2010 | anchor by title | NF-C6 (C2) | pdf 0004-0005 mention AOD only as a tuning target of GCMs ("tuned to best match ... dust aerosol optical depth"); no AOD value or range 0.02-0.04 appears |
| 41 | INDEX.md:213 row | interparticle forces comparable to gravity at threshold minimum, fourth-root gravity scaling; Mars | kok2012 (read) | section 2.1 | FIT (note) | pdf 0007-0008: interparticle forces 2.1.1.2; eq. (2.8) u*ft = AN sqrt((rho_p-rho_a)/rho_a g Dp + gamma/(rho_a Dp)); Table 3 Earth, Mars, Venus, Titan. The g^1/4 at the minimum is derived from (2.8), not stated. No uses |
| 42 | INDEX.md:214 row | u*t^2 = f(Re)(sigma_p g d + gamma/(rho d)) eq. 22, minimum, g^1/4 | shao2000 (read) | eq. 22 | FIT (note) | pdf 0004 eq. (22); pdf 0005 eq. (23) A_N. The g^1/4 scaling and the eq. 22 minimum are derivations from (22); the stated 75 um minimum (pdf 0003) is for the Greeley-Iversen eq. (16) |
| 43 | decisions/0018-one-land-column.md:55,120 | threshold carrying g, particle and air density | shao2000 | body | FIT | eq. 22 |
| 44 | requirements/atm/dust-emission-drag-partition-...md:69,105 | threshold law; cohesion term Bracketed | shao2000 | body | FIT | eq. 22, gamma term |
| 45 | INDEX.md:215 row | soil-moisture threshold correction eq. 14, 15 | fecan_1999 (read) | eq. 14, 15 | FIT | pdf 0006 (14) w' = 0.0014 clay^2 + 0.17 clay; pdf 0007 (15) |
| 46 | decisions/0018-one-land-column.md:122 | reference | fecan_1999 | ref list | FIT | as row |
| 47 | INDEX.md:216 row | drag partition between bed and roughness elements | marticorena_1995 (read) | section 2.2.2 | FIT (note) | pdf 0004 "2.2.2. Parameterization of the drag partition", Marshall (1971) form. The "caution ... never grid-scale orographic variance" is the project's own note, not the paper's |
| 48 | decisions/0018-one-land-column.md:123 | reference | marticorena_1995 | ref list | FIT | as row |
| 49 | requirements/atm/dust-emission-drag-partition-...md:108 | "The drag partition" | marticorena_1995 | ref list | FIT | section 2.2.2 |
| 50 | requirements/ter/nonlinear-order-in-space.md:101-103 | "The affine case" | marticorena_1995 | ref list | FIT | section 2.2.2 |
| 51 | INDEX.md:230 row | texture regressions, within-class variance | cosby_1984 (read) | Tables 3-5 | FIT | pdf 0004 "TABLE 3. Means and Standard Deviations ... in Each Textural Class"; pdf 0006 Table 4 MLR, Table 5 univariate |
| 52 | requirements/bio/soil-nitrogen-gas-operator.md:36,141 | retention closure turning pore space into pressure | cosby_1984 | body | FIT | Table 4 |
| 53 | requirements/ped/texture-mineral-inventory-earth-score.md:117 | reference | cosby_1984 | ref list | FIT | as row |
| 54 | requirements/ped/land-column-hydraulic-contract.md:13-49,81,105 | "L = 1 m reproduces Cosby's own field-capacity suction of 100 cm of water"; Clapp-Hornberger on Table 4; within-class spread; Ks as velocity | cosby_1984 | body | NF-C6 (C2) | Table 4 and Table 3 uses fit; full-text grep for capacity, wilting, 1/3 bar, 33 kPa, 100 cm: no hit. Cosby 1984 states no field capacity, so the claim that licenses stating field capacity as a length has no read source |
| 55 | INDEX.md:233 row | Johansen method, section 7.11, Table 24 | farouki1981 (read) | 7.11, Table 24 | FIT | pdf 0126 "7.11 JOHANSEN'S METHOD"; pdf 0127 "Table 24. Method for calculating thermal conductivity of mineral soils (after Johansen 1975)" |
| 56 | requirements/atm/soil-thermal-properties-...md:16,86 | Johansen interpolation, dry conductivity from bulk density | farouki1981 | body | FIT | as row |
| 57 | INDEX.md:242 row | L* = S_bar LAI, S_bar = S(0.27 + 46/rho_s) | hedstrom1998 (read) | eq. 11-13 | FIT | pdf 0009: "L* = S LAI", "S = S(0.27 ..." (equation numbers lost in OCR). No uses |
| 58 | INDEX.md:247 row | fast-kinetics k as quadratic in ice fraction at five temperatures | fourteau_2021 (read) | eq. 18 | FIT | pdf 0010 eq. (18), T = 223, 248, 263, 268, 273 K |
| 59 | requirements/atm/snow-and-ice-material-properties-...md:120-123 | adopted fast-kinetics arm | fourteau_2021 | eq. 18 | FIT | eq. 18 |
| 60 | requirements/sys/one-declaration-per-quantity.md:111-114 | the two relations | fourteau_2021 | ref list | FIT | eq. 18 |
| 61 | INDEX.md:248 row | slow-kinetics quadratic in density, residual SD | calonne2011 (read) | eq. 12 | FIT | pdf 0004 (12) keff = 2.5e-6 rho^2 - 1.23e-4 rho + 0.024; residual SD 0.025 W/m/K |
| 62 | requirements/atm/snow-and-ice-material-properties-...md:124-127 | slow-kinetics arm | calonne2011 | eq. 12 | FIT | eq. 12 |
| 63 | INDEX.md:249 row | snow albedo vs grain, dust, BC; zenith eq. 5, exponent eq. 7 | dang2015 (read) | eq. 5, 7 | FIT | pdf 0005 (5) r' = r(1 + a dmu)^2, Table 1 broadband pure snow; pdf 0008 (7); pdf 0011 Table 3 |
| 64 | requirements/atm/snow-albedo-grain-impurity-...md:102-105 | eqs. 5, 7, Tables 1, 3 | dang2015 | eqs, tables | FIT | Tables 1 and 3 are the broadband and impurity forms the row names in substance |
| 65 | INDEX.md:250 row | Cp ice 90-273 K eq. 2 | fukusako1990 (read) | eq. 2 | FIT | pdf 0004 (2) Cpi = 0.185 + 0.689e-2 T, 273 K >= T >= 90 K |
| 66 | requirements/atm/snow-and-ice-material-properties-...md:26-30,137 | correlation evaluated above its range | fukusako1990 | body | FIT | range of eq. 2 |
| 67 | requirements/sys/one-declaration-per-quantity.md:101-104 | value at 276.49 K above stated range | fukusako1990 | ref list | FIT | eq. 2 range |
| 68 | INDEX.md:251 row | wet-from-dry reflectance eqs. 1, 7, 9-11 | lekner1988 (read) | eqs. | FIT | pdf 0001 (1); pdf 0002 (9), (10). No uses |
| 69 | INDEX.md:252 row | similarity scaling, asymmetry ratio 0.23, eqs. 2, 4, 5 | twomey1986 (read) | eqs. 2, 4, 5 | FIT (note) | pdf 0003 (2); pdf 0004: ratio r in Eq. (5) "the value 0.23" for n = 1.5 grains in water at visible wavelengths, a worked example not a constant. No uses |
| 70 | INDEX.md:253 row | Kubelka-Munk two-flux, eqs. 13, 18, 19 | sadeghi2015 (read) | eqs. | FIT | pdf 0004 (13), (18); pdf 0006 (19) Fresnel |
| 71 | requirements/ter/nonlinear-order-in-space.md:104-111 | "The concave mixing"; restates Kubelka-Munk | sadeghi2015 | ref list | FIT | eq. 13 |
| 72 | INDEX.md:254 row | single-valued relation top 0.2 cm, thin controlling layer | idso1975 (read) | Figs. 5-7 | FIT (note) | pdf 0004 Fig. 5 layers 0-0.2 to 0-10 cm, consistent across seasons except July deeper than 2 cm; pdf 0005 surface extrapolation "completely linear over a water content range from 0 to 0.18". "Thinner than 2 mm" is a reading of the figures. No uses |
| 73 | INDEX.md:255 row | optical path length in water at saturation 0.06-0.07 cm | nolet2014 (read) | p.5 | FIT | pdf 0005: "water (d) is at its maximum, between 0.06-0.07 cm". No uses |
| 74 | INDEX.md:270 row | sea-ice conductivity eqs. 70-72; pure ice eq. 33 | yen1981 (read) | eqs. 33, 70-72 | FIT | pdf 0022 (33) lambda_i = 9.828 exp(-0.0057 T); pdf 0029 (70) bubbly ice; pdf 0030 (71) sea ice, (72) brine |
| 75 | requirements/atm/snow-and-ice-material-properties-...md:127-129 | "Eqs. (33), (37), (70)-(72), Figures 22 and 23" | yen1981 | ref list | NF-C6 | eq. (37) (pdf 0024, lambda_ia = 2 rho_s/(3 rho_i - rho_s) lambda_i) and Figures 22-23 exist but the row names only eqs. 33, 70-72 as read |
| 76 | INDEX.md:280 row | ice Ih Gibbs function eq. 1, Table 2, Table 6; to 210 MPa | iapws_2009 (read) | eq. 1, Tables 2, 6 | FIT | pdf 0002-0003 Table 2 coefficients; pdf 0008 "0 K <= T <= 273.16 K and 0 <= p <= 210 MPa"; pdf 0012 Table 6 test values |
| 77 | requirements/atm/snow-and-ice-material-properties-...md:31,74,115-117 | specific heat and melting enthalpy; eq. 1, Tables 2, 6 | iapws_2009 | eq. 1, Tables 2, 6 | FIT | as row |
| 78 | requirements/sys/one-declaration-per-quantity.md:105-108 | the one declaration | iapws_2009 | ref list | FIT | as row |
| 79 | requirements/atm/gas-mixture-properties-derived-from-composition.md:91,133-135 | "Sublimation enthalpy and vapour pressure over ice" | iapws_2009 | ref list | NF-C6 | the release supports it only jointly with the vapour-phase formulation (pdf 0008: "consistent computation of the melting-pressure and sublimation-pressure curves"); the row names melting enthalpy and specific heat, not the sublimation curve, and that section is not named read |
| 80 | INDEX.md:289 row | pigment peaks shift with stellar type; oxygenic window as cap | kiang2007b (read) | abstract | FIT | pdf 0003: F2V blue, K2V red-orange, M NIR bands; "A wavelength of 1.1 um is a possible upper cut-off" |
| 81 | requirements/atm/surface-optics-integrated-...md:111-114 | vegetation reflectance vs host spectrum | kiang2007b | ref list | FIT | abstract |
| 82 | requirements/bio/photon-currency-and-canopy-optics.md:42-45,124-126 | "oxygenic photosynthesis is capped near 800 nm on known biochemistry"; "the oxygenic constraint" | kiang2007b | body | NF-C6 (C2) | pdf 0003: "multi-photosystem series ... could allow for oxygenic photosystems at longer wavelengths. A wavelength of 1.1 um is a possible upper cut-off"; no 800 nm cap in Kiang; Nurnberg 2018 p.1212 says chl f absorbs above 760 nm and PSII runs at 727 nm, also no 800 nm cap |
| 83 | INDEX.md:291 row | peak absorbance per stellar type, Table 1 | lehmer2021 (read) | Table 1 | FIT | pdf 0007 Table 1: G2V 644, 672; K2V 675, 711, 746 |
| 84 | decisions/0021-trait-based-vegetation.md:145 | pigment window | lehmer2021 | ref list | FIT | Table 1 |
| 85 | requirements/bio/photon-currency-and-canopy-optics.md:37,128 | K2V 675, 711, 746 vs Sun 644, 672 | lehmer2021 | body | FIT | Table 1 exactly |
| 86 | INDEX.md:292 row | growth power net of apparatus cost, chlorophyll a for the Sun | marosvolgyi2010 (read) | whole | FIT (note) | pdf 0001 abstract: "energy cost of the photosynthetic apparatus ... red absorption band ... optimized to provide maximum growth power"; the word self-shading does not appear (the stacked transmitted-power model of Fig. 1 carries it). No uses |
| 87 | INDEX.md:294 row | 745 nm PSI, 727 nm PSII donors; energy headroom confining far-red to shade | nurnberg2018 (read) | p.1212 | FIT | pdf 0003: primary donors A-1A/A-1B "are chl f in FRL PSI, absorbing at ~745 nm"; PSII "~727 nm"; "~110 meV ... energy headroom"; "restricted to rare, deep-shade" |
| 88 | requirements/bio/photon-currency-and-canopy-optics.md:42,133 | 745 nm PSI, 727 nm PSII | nurnberg2018 | body | FIT | as row |
| 89 | INDEX.md:296 row | hardened frost resistance by tissue, Table 1 | larcher_2005 (read) | Table 1 | FIT | p.191 Table 1 boreal conifers: leaves -40 to <-70, buds -40 to <-70, twigs and stems -50 to <-70, roots -20 to -30 |
| 90 | requirements/bio/bioclimatic-limits-are-tissue-thresholds.md:20,102 | -40 to below -70 C above ground, -20 to -30 C roots | larcher_2005 | body | FIT | Table 1 |
| 91 | INDEX.md:305 row | memory timescales Table S1 (30, 7, 2 days), eq. S23 | thum2019-quincy-supplement (read) | Table S1 | FIT | pdf 0033 Table S1: photosynthesis optimum 7 days, maintenance respiration 30 days, frost state (S23) 2 days |
| 92 | requirements/bio/physiology-on-the-planets-own-day.md:31,159 | 30-day respiration memory | thum2019 supplement | body | FIT | Table S1 |
| 93 | INDEX.md:306 row | Y = 1 - beta^d, biome beta | jackson_1996 (read) | eq., Table 1 | FIT | pdf 0002 Y = 1 - beta^d; pdf 0003 Table 1 beta by biome |
| 94 | requirements/bio/hydraulics-and-allometry-under-gravity.md:46,146 | Earth root profile as envelope | jackson_1996 | body | FIT | Table 1 |
| 95 | INDEX.md:307 row | critical height ~ (E/(rho g))^1/3 d^2/3 | mcmahon_1973 (read) | eq. 1 | FIT | pdf 0001 (1) l_cr = 0.851 (E/rho)^1/3 d^2/3 with rho "the weight per unit volume" |
| 96 | requirements/bio/hydraulics-and-allometry-under-gravity.md:120 | elastic similarity, self-weight buckling | mcmahon_1973 | ref list | FIT | eq. 1 |
| 97 | INDEX.md:315 row | P submodel: C:P vs labile P (Fig. 3), labile-P definition, K1-K4 (p.117) | parton1988 (read) | Fig. 3, p.117 | FIT | pdf 0007 (p.115) Fig. 3 and labile P "defined as orthophosphate"; pdf 0009 (p.117) K1-K4 flows |
| 98 | requirements/bio/decomposition-stoichiometry-...md:28-31,110,135-137 | Fig. 3 ramps; "page 115 the receiving pool convention"; p.117 rate constants, K3 occlusion | parton1988 | body | FIT (note) | Fig. 3 and K3 (pdf 0005 flow K3 Mt to occluded P) fit; the new-SOM C:P convention sentence is on p.116 (pdf 0008), one page after the stated p.115 |
| 99 | INDEX.md:316 row | pools, texture stabilisation, C:N ramps Fig. 4 | parton1993 (read) | Fig. 4 | FIT | pdf 0007 Fig. 4 "Variation in C:N ratios of (a) the active, slow and passive SOM pools as a function of the mineral N pool" |
| 100 | requirements/bio/decomposition-stoichiometry-...md:20,139-142 | Fig. 4(a) ramps three pools | parton1993 | body | FIT | Fig. 4(a) |
| 101 | INDEX.md:353 row | SPITFIRE structure and Earth-imported assumptions (20 percent CG, 4 percent ignition) | thonicke_2010 (read) | whole | FIT (note) | pdf 0006: "Latham and Williams (2001) indicated that 0.20 of these are cloud-to-ground flashes (CG) and that their efficiency in starting fires ... is 0.04". Thonicke is primary for what SPITFIRE assumes and secondary for the numbers themselves |
| 102 | decisions/0021-trait-based-vegetation.md:143 | SPITFIRE | thonicke_2010 | ref list | FIT | as row |
| 103 | requirements/bio/fire-effects-and-element-closure.md:64,126-129 | combustion completeness, intensity, mortality | thonicke_2010 | ref list | FIT | process structure |
| 104 | requirements/bio/fire-ignition-and-drivers.md:27,33-35,161 | SPITFIRE assumes 20 percent CG and 4 percent efficiency as Earth priors | thonicke_2010 | body | FIT | pdf 0006 as row |
| 105 | INDEX.md:387 row | equilibrium model; 1,603,781 wells "with its stated valley and oasis sampling bias" | fan_2013 main (read) | whole | NF-C2 | p.940 (pdf 0002): "The 2- to 7-m peak reflects sampling bias; observations are made for resource monitoring where humans settle (excluding large swamps and deserts) and where the water table is lowered by pumping or drainage"; valleys and oases appear (p.941) as groundwater-fed ecosystems, not as a sampling bias |
| 106 | decisions/0019-hydrology-and-carve-as-process.md:145 | reference | fan_2013 | ref list | FIT | method |
| 107 | requirements/hyd/groundwater-sinks-baselevels-exchange.md:108 | reference | fan_2013 | ref list | FIT | method |
| 108 | requirements/hyd/subgrid-statistic-rule.md:109 | reference | fan_2013 | ref list | FIT | method |
| 109 | requirements/hyd/water-table-skill-oracle.md:17,77,98 | predecessor PASS edges 24.56 m SD and 8.92 m mean as Fan's own Australia-and-Asia residuals under the worse recharge; REPORT for Fan's residuals | fan_2013 main | body | FIT | the numbers are in the supplement (row 113), not the main paper; the main-paper citation carries the method |
| 110 | INDEX.md:388 row | Database S1 and its mirror | fan_2013_supplementary (read) | Database S1 | FIT | pdf 0044 "Database S1. Water table observations from wells" |
| 111 | decisions/0019-...md:145 (same DOI) | reference | fan_2013 supplement | ref list | FIT | as row |
| 112 | requirements/hyd/groundwater-sinks-...md:108; subgrid-statistic-rule.md:109 (same DOI) | reference | fan_2013 supplement | ref list | FIT | (counted once for the two files) |
| 113 | requirements/hyd/water-table-skill-oracle.md:17 (same DOI) | 24.56 m and 8.92 m | fan_2013 supplement | none named | NF-C6 | the values are correct: Table S1 (supplement p.37), Australia and Asia, Doll-Fiedler recharge: mean -8.92 m, St. dev. 24.56 m (CLM: -5.08, 20.85); section S3.5 (supplement pdf 0016) "Doll-Fiedler 8.92 m lower". The row names only Database S1 as read |
| 114 | INDEX.md:389 row | Earth one-fifth endorheic, 31.8 million km2 | wang2018 (read) | p.927 | FIT | pdf 0001 "cover one-fifth of the Earth's land"; pdf 0003 "(23.2 out of 31.8 million km2)" |
| 115 | registry.toml terrain.endorheic_share anchors | report on internally drained share | wang2018 | anchor by title | FIT | report entry, the share is stated |
| 116 | requirements/hyd/lake-equilibrium-earth-oracle.md:90 | reference | wang2018 | ref list | FIT | as row |
| 117 | INDEX.md:390 row | 1599 10Be rates; slope dominant regressor; no relief regression | portenga2011 (read) | results | FIT | pdf 0002 "(n = 1599)"; pdf 0005 basins 218 +/- 35 (n = 1149), "basin slope is the most significant regressor" |
| 118 | requirements/ped/weathering-real-clock.md:35,112 | arid basins 100 +/- 17, global 218 +/- 35 | portenga2011 | body | FIT | pdf 0005 "Arid region drainage basins erode most slowly (100 +/- 17.3 m Myr-1; n = 229)"; "218 +/- 35 m Myr-1 (n = 1149)" |
| 119 | requirements/ter/lithology-class-denotes-a-rock.md:139 | reference | portenga2011 | ref list | FIT | as row |
| 120 | registry.toml terrain.denudation_vs_relief anchors | FAIL outside the compilation's interquartile band of basin denudation at a given mean slope | portenga2011 | anchor by title | NF-C6 (C2, C7) | the paper gives means +/- SE and medians by category (Figs. 3-4) and a multiple regression with slope most significant (pdf 0003 R2 = 0.60); no slope-conditioned interquartile band is stated, and an observed spread is not a published model's residual (decision 0025) |
| 121 | test/lint/runtests.jl:154 | QUINCY title as a lint fixture string | thum2019 | none | not a citation | listed for completeness, not counted |

Row 121 is not counted; rows 1-120 plus the one-count merge noted in row 112 give the 121 verdicts
of the counts (43 row-level fit + 5 row-level not fit + 63 use fit + 10 use not fit).

#### Not-fit cases

##### NF1. Mason 1988 row locator (INDEX.md:145)
- Use: B2 areal roughness operator and blending height. Category C2.
- Wrong: the averaging operator is attributed to eq. 14; eq. 14 is the blending height l_b.
- Evidence: mason1988 pdf 0004 (QJRMS 114, p.402): eq. (14) l_b ln^2(l_b/z0) ~ 2 kappa^2 L_c;
  eq. (15) 1/ln^2(l_b/z0eff) = f1/ln^2(l_b/z01) + f2/ln^2(l_b/z02); pdf 0006: eq. (15) "can be used
  to combine various areas of differing z_o".
- Fix class (a): anchor reads eqs. 14 (height) and 15 (operator), same read paper. INDEX.md is edited
  by open branch fiddlybits-k6b.

##### NF2. Kessler 1969 row and its use (INDEX.md:150; requirements/sys/constants-have-five-dispositions.md:54)
- Use: single-moment rain evaporation and fallspeed "with explicit gravity dependence through
  terminal speed"; REQ narrative derives a form "carrying gravity to the -0.289 power". C2 (row),
  C6 (use).
- Wrong: Kessler's fallspeed is an Earth-air empirical fit in drop diameter or content with no g.
- Evidence: pdf 0038 (8.11) V0 = -38.3 N0^-1/8 M^1/8 exp(kz/2); footnote 5 coefficient 38.8 for the
  mean volume-weighted fallspeed; pdf 0039 (8.12c) terminal speed 130 D^1/2 exp(kz/2).
- Fix class (b): the gravity exponent needs a read terminal-velocity law carrying g (a drag-balance
  source) or the anchor and the requirement say the gravity dependence is not Kessler's. Boundary:
  docs/references/INDEX.md (k6b edits it), docs/requirements/sys/constants-have-five-dispositions.md.
  Acceptance: the anchor states only what section 8 holds; the -0.289 exponent names a read source
  with locator or is removed; lint_sourced passes.

##### NF3. Mlawer 2012 row locator (INDEX.md:158)
- Use: B2 continuum bracket, "one-signed upward uncertainty in near-infrared windows (Table 3 scale
  factors)". C2.
- Wrong: Table 3 is MT_CKD_2.5's adopted self-continuum revision relative to 1.0 at 2050-3150 cm-1,
  not an uncertainty, and not the 4600 or 6140 cm-1 near-infrared windows.
- Evidence: pdf 0033 (p.2552) Table 3 caption and wavenumbers; pdf 0032 (p.2551): Burch and Alt 2-4x
  at 2400-2640 cm-1, Bicknell et al. 6-12x at 4600 cm-1 and 2-4x at 6140 cm-1, Fulghum and Tilleman
  factor 2-3 at 9466 cm-1; p.2552: "All studies consistently point to the need for greater
  absorption than in MT_CKD_1.0."
- Fix class (a): anchor names p.2551-2552 text for the upward bracket and Table 3 as the v2.5 revision;
  same read paper. INDEX.md edited by k6b.

##### NF4. Paragas 2025 row and REQ-TER use (INDEX.md:169; requirements/ter/lithology-class-denotes-a-rock.md:41-42,148)
- Use: powder-over-slab factor median 2.74, range 2.19-5.11. C2 (row), C6 plus a nonexistent title
  (use).
- Wrong: the row is read for a number no source states; the paper was never held; the requirement
  cites a title that does not exist.
- Evidence: fetched open access (one attempt, succeeded) to
  scratchpad/audit/fetch-X2/paragas2025.pdf: "A New Spectral Library for Modeling the Surfaces of
  Hot, Rocky Exoplanets", ApJ 981:130 (2025), 10.3847/1538-4357/ada9eb. Abstract: "varying textures
  (solid slab, coarsely crushed, and fine powder)". Full-text grep: no "2.74", no median ratio. The
  POSEIDON readme names the source as "Paragas 2025 (P25) - From Figure 3". The factor is computed from
  the 31 redistributed files under references/poseidon_surface_albedo/Paragas2025-P25/.
- Fix class (b) for the number, (a) for the citation. Row: ingest the PDF under references/pdf
  (main checkout), correct the INDEX row's title and identifier, record the ratio's computation from
  the P25 files as a finding and point the anchor and REQ-TER-? at it; correct the reference entry in
  lithology-class-denotes-a-rock.md. Boundary: docs/references/INDEX.md (k6b), references/pdf
  payload, notes/findings/<new>, docs/requirements/ter/lithology-class-denotes-a-rock.md.
  Acceptance: the reference carries the verbatim title and DOI; 2.74 and 2.19-5.11 reproduce from the
  hashed data by a finding's recorded computation, or the requirement drops them.

##### NF5. Fan et al. 2013 main row wording (INDEX.md:387)
- Use: M2 water-table skill bars, "compilation ... with its stated valley and oasis sampling bias". C2.
- Wrong: the stated bias is toward settled, pumped, drained sites excluding swamps and deserts.
- Evidence: p.940 (pdf 0002): "The 2- to 7-m peak reflects sampling bias; observations are made for
  resource monitoring where humans settle (excluding large swamps and deserts) and where the water
  table is lowered by pumping or drainage (figs. S1 and S2)."
- Fix class (a): anchor wording from p.940, same read paper. INDEX.md edited by k6b.

##### NF6. Fan et al. 2013 supplement coverage (INDEX.md:388; requirements/hyd/water-table-skill-oracle.md:17)
- Use: the predecessor's PASS edges 24.56 m and 8.92 m. C6.
- Wrong: the values are right but come from Table S1 and section S3.5, which the row does not name
  as read (it names Database S1).
- Evidence: supplement p.37 Table S1, Australia and Asia, Doll-Fiedler: mean -8.92, St. dev. 24.56
  (CLM -5.08, 20.85); pdf 0016 section S3.5.
- Fix class (a): anchor adds Table S1 (p.37) and S3.5; passage verified here. INDEX.md edited by k6b.

##### NF7. Kok et al. 2014 as anchor of earth.dust_emission (registry.toml)
- Use: FAIL bar "inside the compilation's range" of global dust emission. C6 (C2).
- Wrong: the row read eq. 18a/b; the paper states no global emission compilation or range.
- Evidence: kok_2014 full-text grep for Tg, Tg/yr, global emission totals: none; "global" occurs only
  for data availability and model use (pdf 0002, 0003, 0009, 0013).
- Fix class (b): name and read the compilation the bar rests on and state whether it is a model
  residual, a model spread or an observational range under decision 0025. Registry-only merge
  (registry.toml edited by k6b, 52v.6.26, 52v.8.13). Entry unregistered, so no registered bar moves.

##### NF8. Kok 2010 (PNAS) as anchor of earth.dust_aod (registry.toml)
- Use: FAIL bar "outside 0.02 to 0.04 fails" on global dust AOD. C6 (C2).
- Wrong: Kok 2010 states no dust AOD value or range.
- Evidence: pdf 0004-0005: AOD appears only as what GCM emission schemes "are tuned to best match";
  no 0.02, 0.03 or 0.04 in the text.
- Fix class (b): the entry's dataset_or_reference names Ridley et al.; the anchor must be the read
  source of the range, judged under decision 0025. Registry-only merge; entry unregistered.

##### NF9. Cosby et al. 1984 in REQ land-column-hydraulic-contract (requirements/ped/land-column-hydraulic-contract.md:29)
- Use: "L = 1 m reproduces Cosby's own field-capacity suction of 100 cm of water under Earth gravity,
  which is what licenses stating it as a length". C6 (C2).
- Wrong: Cosby 1984 defines no field capacity.
- Evidence: full-text grep of cosby_1984 for capacity, wilting, 1/3 bar, 33 kPa, 100 cm: no hit. The
  paper's content is Tables 3-5 (class means and SDs, MLR and univariate regressions).
- Fix class (b): find and read the source of the 100 cm field-capacity convention (the predecessor's
  vegetation model or its cited standard), or restate the licence. Boundary:
  docs/requirements/ped/land-column-hydraulic-contract.md, docs/references/INDEX.md (k6b) if a source
  is added. Acceptance: the 100 cm figure cites a read passage with locator or is removed.

##### NF10. Yen 1981 in REQ snow-and-ice (requirements/atm/snow-and-ice-material-properties-follow-density-and-temperature.md:127-129)
- Use: "Eqs. (33), (37), (70)-(72), Figures 22 and 23". C6.
- Wrong: eq. 37 and Figures 22-23 are not named in the row's read anchors.
- Evidence: pdf 0024 (37) lambda_ia = 2 rho_s/(3 rho_i - rho_s) lambda_i; pdf 0030 Figure 22 bubbly
  ice; INDEX.md:270 names eqs. 70-72 and 33 only.
- Fix class (b): read eq. 37 and Figures 22-23 for the use and extend the anchor, or drop them from
  the requirement. Boundary: INDEX.md (k6b), that requirement file.

##### NF11. IAPWS R10-06(2009) in REQ gas-mixture (requirements/atm/gas-mixture-properties-derived-from-composition.md:133-135)
- Use: "Sublimation enthalpy and vapour pressure over ice". C6.
- Wrong: the row is read for eq. 1, Tables 2 and 6, melting enthalpy and specific heat; the
  sublimation curve needs the release's section on consistent computation with the fluid-phase
  formulation, not named as read.
- Evidence: iapws_2009 pdf 0008: "consistent computation of the melting-pressure and
  sublimation-pressure curves"; INDEX.md:280 anchors.
- Fix class (b): read that section (and whatever it names for the vapour side) and extend the anchor,
  or cite the IAPWS document that states the sublimation curve after reading it. Boundary: INDEX.md
  (k6b), that requirement file.

##### NF12. Kiang et al. 2007b in REQ photon-currency (requirements/bio/photon-currency-and-canopy-optics.md:42-45)
- Use: "oxygenic photosynthesis is capped near 800 nm on known biochemistry", cited to Kiang as "the
  oxygenic constraint". C6 (C2).
- Wrong: no read source states an 800 nm cap; Kiang puts the possible cut-off at 1.1 um and allows
  longer-wavelength oxygenic multi-photosystem series.
- Evidence: kiang2007b pdf 0003 abstract: "Longer-wavelength, multi-photosystem series would reduce the
  quantum yield but could allow for oxygenic photosystems at longer wavelengths. A wavelength of
  1.1 um is a possible upper cut-off for electronic transitions"; nurnberg2018 pdf 0003: "Chl f can
  absorb at >760 nm, yet the wavelength used to drive photochemistry in the FRL PSII is ~727 nm".
- Fix class (b): either state the cap as Kiang's and Nurnberg's passages give it, or read a source for
  800 nm. Boundary: that requirement file, INDEX.md (k6b) if a source is added.

##### NF13. Portenga and Bierman 2011 as anchor of terrain.denudation_vs_relief (registry.toml)
- Use: FAIL "outside the interquartile band" of basin denudation at a given mean slope. C6 (C2, C7).
- Wrong: no slope-conditioned interquartile band is stated; and an observed spread is not a published
  model residual, which decision 0025 requires of a FAIL bar.
- Evidence: portenga2011 pdf 0005: basins 218 +/- 35 m/Myr (n = 1149), median 54; "basin slope is
  the most significant regressor"; pdf 0003: R2 = 0.60 multiple regression; Figs. 3-4 box plots by
  rock type, climate and tectonics, not by slope.
- Fix class (b): registry-only row: derive the band from the held compilation data under a stated
  model-residual basis, or make the entry report. Entry unregistered; registry.toml edited by open
  branches.

(NF2 and NF4 each count one row-level and one use-level not-fit; total not-fit verdicts 15.)

#### Notes, fit but worth carrying

- Kok 2012 (INDEX.md:213) and Shao and Lu 2000 (INDEX.md:214): the g^1/4 scaling at the threshold
  minimum is derived from Kok eq. 2.8 / Shao eq. 22, not stated; Shao's stated 75 um minimum is for
  the Greeley-Iversen eq. 16. Anchors could say "derived here".
- Twomey 1986: 0.23 is the worked example for n = 1.5 grains in water at visible wavelengths; any use
  as a constant would be a regime extension.
- Thonicke 2010: 0.20 cloud-to-ground and 0.04 ignition efficiency are Latham and Williams (2001)
  numbers carried by SPITFIRE; a Sourced value of either should cite the primary.
- Marticorena 1995: the "never grid-scale orographic variance" caution is the project's, not the
  paper's.
- Parton 1988 in REQ decomposition: the new-SOM C:P convention sentence runs onto p.116.
- requirements/ter/nonlinear-order-in-space.md:97: Wood and Mason 1993 "DOI: to confirm" although
  INDEX carries 10.1002/qj.49711951402 (a citation correction, file not edited by an open branch).
- test/planets/synthetic_non_earth.jl (branch 52v.4.5): all six Hale and Querry values match Table I
  p.557; the locator says "Table 1" for Table I.

#### Fetches and paywalled sources

- Fetched (one attempt, succeeded, open access): Paragas et al. 2025, "A New Spectral Library for
  Modeling the Surfaces of Hot, Rocky Exoplanets", 10.3847/1538-4357/ada9eb, at
  /tmp/claude-1000/-home-cfutro-git-fiddlybits/6de64ff3-bd74-4fb4-be9a-b55a52420847/scratchpad/audit/fetch-X2/paragas2025.pdf
  (not ingested).
- Fetch failures: none. Paywalled sources needed: none in this scope.

### X3: INDEX read rows, line 401 onward


Worktree: /home/cfutro/git/fiddlybits/.beads/worktrees/fiddlybits-9j0 (main at 625832c).
Sources read from /home/cfutro/git/fiddlybits/references/text/<stem>/<NNNN>.txt (NNNN is the
PDF page index; printed page given where the text carries it or the offset is fixed).

Rows in scope (status read, line >= 401): 403, 519, 520, 533, 594, 595, 624, 627, 634, 725,
734, 738, 782, 784, 799, 823, 836, 837, 878, 881. No other row at or after line 401 has status
read (the table at 942-962 states nothing there is read).

#### Counts

| item | total | fit | not fit | not verified (use not stated) |
| --- | --- | --- | --- | --- |
| rows: named passage exists and supports the row's stated use | 20 | 20 | 0 | 0 |
| citing uses on main (src, test, registry, decisions, requirements, plans, imports) | 68 | 47 | 16 | 5 |
| all in scope on main | 88 | 67 | 16 | 5 |
| citing uses on open branch fiddlybits-52v.4.5 (test/planets/earth.jl, not on main) | 6 | 1 | 5 | 0 |

A use is counted once per citing document and passage (a registry entry, a decision, a
requirement, a plan section, a src or test file). "Not verified" is a reference-list entry with
no locator whose use the citing record does not state, so no passage can be matched to it.

Per row (main): Textor 2/1/1/0; Bell 2/2/0/0; Berger 7/4/3/0; Braun 5/2/2/1; Gassmann 2011
3/3/0/0; Gassmann 2013 2/2/0/0; Higham 10/5/3/2; Hollingsworth 4/4/0/0; IEEE 754 8/3/4/1;
Peixoto 2/2/0/0; Prsa 1/1/0/0 (branch 5/0/5); Randall 1/1/0/0; Thuburn 3/3/0/0; CODATA 4/4/0/0
(branch 1/1/0); Wan 6/5/0/1; Zaengl 4/1/3/0; Lapolli 2/2/0/0; Korn 1/1/0/0; Jain 0; Wolfram 1/1/0/0
(uses/fit/not fit/not verified).

#### Every citation

##### Row-level verdicts

| row (line) | source, status | passage the row names | verdict | evidence |
| --- | --- | --- | --- | --- |
| 403 | textor2006-aerocom-aerosol-lifecycles.pdf, read | AeroCom burdens and lifetimes with diversity (SS 7.5 Tg at 54 percent, DU 19.2, SO4 2.0) | FIT | PDF 0011: "The burdens of DU and SS are 19.2 Tg (delta=40%) and 7.5 Tg (delta=54%)... The burdens of SO4 and POM are similar with 2 Tg (delta=25%)"; lifetimes in Table 10 (PDF 0023), text PDF 0013 |
| 519 | bell2017-numerical-instabilities-vector-invariant-momentum.pdf, read | abstract, s.1, s.6; eqs 69-71 p.7; s.4.7 pp.9-11; s.5 | FIT | eqs (69)-(71) on PDF 0007; "4.7." PDF 0009; Hermitian stability matrices in abstract PDF 0001 l.26 and s.6 PDF 0013 |
| 520 | berger1978-long-term-variations-daily-insolation.pdf, read | Fig. 1 caption; Appendix definitions | FIT | PDF 0001 Fig. 1: "varpi-tilde is the longitude of the perihelion relatively to the moving vernal equinox... 180 deg is subtracted... the sun is considered as revolving around the earth"; PDF 0005 Appendix: nu, M counted from perihelion, lambda = nu + varpi-tilde, lambda_m = M + varpi-tilde; PDF 0006: sin(delta) = sin(epsilon) sin(lambda), rho = (1 - e^2)/(1 + e cos nu) |
| 533 | braun2013-very-efficient-o-n-implicit.pdf, read | receiver/donor arrays p.171, stack eq 12 p.172, accumulation p.173, local minima pp.174-175; implicit update stated not read | FIT (honest) | donors PDF 0002; eq (12) PDF 0003; accumulation PDF 0004; "6. Local minima" PDF 0005-0006 |
| 594 | gassmann2011-inspection-hexagonal-triangular-c-grid.pdf, read | read whole; eq 15 p.2711; s.6; s.7.2; s.8-9 Figs 5-6 | FIT | eq (15) PDF 0006; r_d = 0.5 "to mimic ... small equivalent depths" PDF 0014 (p.2719); Figs 5, 6; "9. Conclusion" PDF 0015 (p.2720) |
| 595 | gassmann2013-global-hexagonal-c-grid-non.pdf, read | s.3.3 eq 27, eq 46, s.6.3, App. B eqs B11, B20, B21 | FIT | "3.3. Definition of the discrete Hamiltonian" and (27) PDF 0006; (46) PDF 0008; "6.3." PDF 0014; (B11), (B20) PDF 0023 |
| 624 | higham1993-accuracy-floating-point-summation.pdf, read | section 2 in full; eq 2.6; gamma_k from p.784 | FIT | PDF 0002 (p.784): prod(1 + delta_i) = 1 + theta_n, |theta_n| <= nu/(1 - nu) = gamma_n; PDF 0003 (p.785): "(2.6) |E_n| <= gamma_{n-1} sum|x_i|" |
| 627 | hollingsworth1983-internal-symmetric-computational-instability.pdf, read | read whole; s.1 p.417, s.3 p.418, s.5 pp.422-424 eq 7, s.8 p.427 | FIT | "1. INTRODUCTION" PDF 0001; "3. SYMPTOMS" PDF 0002; "5. A SIMPLIFIED ANALYSIS FOR THE INTERNAL MODES" PDF 0006; "sigma_r ~ f u-bar/8c (7)" PDF 0008; "8. MODIFICATION OF THE grad K TERM" PDF 0011 |
| 634 | ieee2019-standard-floating-point-arithmetic-754.pdf, read | clause 5.4.1, formatOf-fusedMultiplyAdd | FIT | PDF 0034: "fusedMultiplyAdd(x, y, z) computes (x * y) + z as if with unbounded range and precision, rounding only once to the destination format" |
| 725 | peixoto2018-numerical-instabilities-spherical-shallow-water.pdf, read | ss.1-2.2, 4, 5.1, 5.3, 7, Table 1, App. B | FIT | "4. Test case" PDF 0005 with g = 9.80616, Omega = 7.292e-5; 240 km, e-folding PDF 0010; Table 1 PDF 0015; power method App. B PDF 0017 |
| 734 | prsa2016-nominal-values-selected-solar-planetary.pdf, read | Table 1 nominal TSI 1361 W/m^2 | FIT | PDF 0003 Table 1: "1 S_N = 1361 W m-2" |
| 738 | randall1994-geostrophic-adjustment-finite-difference-shallow.pdf, read | read whole; s.3 and Fig. 2 pp.1374-1376; s.4 p.1376 | FIT | "3. The Z grid" PDF 0004; "FIG. 2. Dispersion relations" PDF 0005; "4. Conclusions" PDF 0006 |
| 782 | thuburn2009-numerical-representation-geostrophic-modes-arbitrarily.pdf, read | read whole; eq 33, eq 39, s.4.5, Figs 10-11, s.4.6 fn 2 | FIT | (39) PDF 0008 ("Using the explicit expression (33)"); 4.5 PDF 0011 (p.8331); Fig. 10 PDF 0013 (p.8333); Fig. 11 PDF 0014 |
| 784 | tiesinga2021-codata-recommended-values-fundamental-physical.pdf, read | Table XXXI standard atmosphere; Table XXX p.033105-45 G and sigma with k, h, c | FIT | PDF 0052 "TABLE XXXI. (Continued.)" standard atmosphere 101 325 Pa exact; PDF 0046 "TABLE XXX", footer "50, 033105-45": G 6.674 30(15) x 10^-11, sigma (pi^2/60)k^4/hbar^3 c^2 5.670 374 419 x 10^-8, k 1.380 649, h 6.626 070 15, c 299 792 458 |
| 799 | wan2013-icon-1-2-hydrostatic-atmospheric.pdf, read | read whole; s.4.2 eqs 7, 10 p.740; s.4.3 eqs 16-20; ss.5.2, 5.9; s.8 | FIT | (6), (7), (10) PDF 0006 (p.740); (16)-(20) PDF 0008 (p.742) |
| 823 | zangl2015-icon-icosahedral-non-hydrostatic-modelling.pdf, read | pp.563-568, 574-575: s.2.3, s.2.4, eq 32, s.2.5, App. A; states "Not read for the general formulation or nesting" | FIT (honest) | (32) PDF 0005 (p.567); "Appendix A: Second-order accurate divergence on a triangular" with (A1)-(A3) PDF 0013 (p.575) |
| 836 | lapolli2023-accuracy-and-stability-analysis-horizontal-discretizations.pdf, read | pp.1-3, 11, 24, 31-33; s.4.5.1 p.32; preprint | FIT | abstract PDF 0001 l.26 "C-grid ICON schemes are within the least stable"; "4.5.1. 2D stability Analysis" PDF 0031 |
| 837 | korn2026-theorem-and-its-resolution-for-the.pdf, read | v3 pp.1, 3-5, 8, 16, 29, 32; Thm 2.6, Thm 4.6, Cor 5.20; preprint | FIT | Thm 2.6 PDF 0008; Thm 4.6 PDF 0016; Cor 5.20 PDF 0032; O(h^r) Kelvin defect abstract PDF 0001 l.18 |
| 878 | jain2024-fastflow-gpu-acceleration-flow-and-depression.pdf, read | Algorithms 1-6, log2(n) rounds, ping-pong, single receiver | FIT | Algorithm 1 with "for i <- 1 to log2(|T|)" PDF 0005; Algorithms 2-5 PDF 0007-0008; Algorithm 6 PDF 0009 |
| 881 | wolfram2013-mitigating-horizontal-divergence-checker-board.pdf, read | read whole; ss.2.1, 3.1, 3.5, 4.1 eq 18, 5.4.1, 6 | FIT | 2.1 PDF 0002 (p.65); 3.1 PDF 0004 (p.67); 3.5 PDF 0006; 4.1 PDF 0008 (p.71); (18) PDF 0009 (p.72); 5.4.1 PDF 0012; "6. Conclusions" PDF 0014 (p.77) |

Row notes (not failures):
- 823 (Zaengl): the anchors column gives the row's purposes as "the general formulation the
  hydrostatic solver is a limit of; ICON grid nesting" and then says neither was read. Honest,
  but the uses below lean on exactly those parts.
- 533 (Braun): the purpose is "implicit O(n) stream-power solver, the terrain reference" and
  the implicit update is not read. Honest; uses below lean on it.
- 624 (Higham): the purpose names "recursive, pairwise and compensated summation"; only section
  2 (recursive) is read.
- 878 (Jain): the anchors column names decisions 0015 and 0019; neither cites the source (grep
  for Jain and FastFlow in both returns nothing). Its only use is
  notes/findings/2026-09-13-fastflow-tree-contraction-reads-no-coordinates-and-its-fixed-round-count-leaves-trees-unfinished.md.
  docs/references/recent-implementation-literature.md l.151 still says "DOI: to confirm".
- 734 (Prsa): the title cell carries stray footnote marks ("IAU 2015 RESOLUTION B3 * dagger").
- 782 (Thuburn) and 799 (Wan): read whole, but the anchors column names only the decision 0059
  passages; the registry's Thuburn s.4.3 p.8330 and s.4.4 p.8331, and decision 0005's Wan pp.738
  and 747, are not named there.

##### Citing uses

| where | use | source | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| docs/requirements/atm/aerosol-tracers-one-particle-description-and-physical-sinks.md l.40 | predecessor burden inside the AeroCom spread | Textor 2006, read | none | FIT | burden diversity PDF 0011 |
| same file l.99-100, l.123-125 | "emission, burden and lifetime per species against the AeroCom spread as REPORT rows"; reference: "The inter-model spread that is the Earth bar" | Textor 2006, read | none | NOT FIT (C6; C7 note) | row read for burdens and lifetimes only; emission diversity not named. "is the Earth bar" contradicts item 6 (REPORT) and decision 0025 (tier-2 bar from a model's own residual) |
| docs/decisions/0004-foundational-free-parameters.md l.255-261 | root origin: mean anomaly and lambda_m | Berger 1978, read | Appendix | FIT | PDF 0005 Appendix |
| same l.280-285 | seasonal angles: sin(delta) = sin(eps) sin(lambda); 180 deg rule | Berger 1978 | Appendix; Fig. 1 caption | FIT | PDF 0006 l.13; PDF 0001 Fig. 1 |
| same l.407-411 and l.462 | the precessional parameter e sin(varpi-tilde) | Berger 1978 | eq. 2 | NOT FIT (C6) | eq (2) exists, PDF 0001 l.20 "e sin varpi-tilde = sum P_i sin(alpha_i t + zeta_i)", but the row does not name eq. 2 |
| docs/decisions/0008-one-clock-si-seconds.md l.29, l.163-166 | long-term expansions a declared absence; instantaneous geometry used | Berger 1978 | none (points to REQ-SYS-102) | FIT | Appendix is the instantaneous form |
| docs/requirements/sys/one-clock-no-day-unit-no-fixed-calendar.md l.113-119 | declination and instellation as pure functions of orbital phase | Berger 1978 | none | FIT | Appendix; the DOI is marked "(to confirm)" though INDEX carries it |
| docs/oracles/registry.toml system.orbit_mean_insolation (l.185, anchors l.191) | instantaneous geometry against "the daily-insolation form of Berger (1978)" on every system.* instance | Berger 1978 | none | NOT FIT (C6, C3) | Appendix eqs (8)-(10) PDF 0005-0006 not named by the row; PDF 0006: "All the angles which locate the earth on its orbit are taken as being constant over the whole day" and "the factor 86.4 provides W in kJ m-2 day-1"; PDF 0005: T "tropical year of 365.2422 mean solar days" |
| docs/plans/fiddlybits-52v.5-time.md l.29-30, l.288 | the same daily-insolation oracle arm | Berger 1978 | none | NOT FIT (C6, C3) | as above |
| docs/plans/fiddlybits-52v.5-time.md l.212-215 | seasonal angles Derived; Berger's longitude of perihelion | Berger 1978 | none | FIT | Fig. 1 caption, Appendix |
| docs/decisions/0015-terrain-snapshot-two-clocks.md l.78, l.83, ref l.128 | "implicit incision has no CFL constraint"; the implicit incision's steepest receiver | Braun and Willett 2013, read | none | NOT FIT (C6) | the row states the implicit update is not read; the scheme is s.4, PDF 0004 l.35 to PDF 0005 l.27, which adds: "our method is not fully implicit (with respect to drainage area)" |
| docs/requirements/ter/gravity-enters-through-the-law.md l.16, ref l.117 | "slope exponent n = 1 (the implicit solver's form)" | Braun and Willett 2013 | none | NOT FIT (C6) | rests on the unread implicit update; PDF 0005 l.19 gives a Newton-Raphson iteration for general n, so the source does not confine the solver to n = 1 |
| docs/requirements/hyd/basin-fate-is-a-process.md ref l.110-112 | stack ordering and local-minimum routing | Braun and Willett 2013 | none | FIT | ordering s.2, local minima s.6 read |
| docs/requirements/hyd/depressions-are-nodes-no-catalogue-floor.md ref l.91-93 | as above | Braun and Willett 2013 | none | FIT | as above |
| docs/requirements/ter/snapshot-carries-ages-and-rates.md ref l.89-92 | not stated | Braun and Willett 2013 | none | NOT VERIFIED | no body use names it |
| registry core.checkerboard_divergence_mode (statistic, threshold, anchors) | unaveraged divergence hides and returns the mode; r_d = 0.5; V4 checkerboard control | Gassmann 2011, read | s.7.2 p.2717; s.8 pp.2717, 2719; Table 1; Fig. 5 | FIT | PDF 0014 r_d = 0.5; PDF 0015 "V4 version exhibits a more intense checkerboard" |
| registry core.fsphere_normal_modes (threshold, anchors) | a zero-frequency non-geostrophic mode under averaging | Gassmann 2011 | s.7.2 p.2717 | FIT | read whole |
| docs/decisions/0059 l.27, 30, 74-79, 118, 241 | mode faint at standard depths; averaging hides it; V4 against V8; edge inner product | Gassmann 2011 | ss.6, 7.2, 8, 9 | FIT | passages as row |
| docs/decisions/0059 l.150-159 | blended kinetic energy; least-squares blend | Gassmann 2013, read | s.3.3 eq 27; App. B B11, B20, B21 | FIT | PDF 0006, PDF 0023 |
| docs/decisions/0013-atmosphere-core-triangle-cgrid.md l.38-41, ref l.158 | an energy-consistent formulation is the Hollingsworth remedy | Gassmann 2013 | none | FIT | App. B, s.6.3 read |
| src/Reductions/error_bound.jl l.8-17, l.48-52 | ERROR_BOUND_K = 1 and error_bound from eq 2.6 | Higham 1993, read | eq. 2.6 | FIT | PDF 0003 (2.6) |
| src/Reductions/error_bound.jl l.34-41; test/reductions/error_bound.jl l.33 | validity_limit: "Higham's n * u <= 1 (1993, discussion following eq. 3.11)" as the count where gamma_{n-1} of eq 2.6 stops being a bound | Higham 1993 | discussion after eq 3.11 | NOT FIT (C6, C2) | the passage is s.3 (not read) and is about compensated summation: PDF 0009 l.27 "As long as nu <= 1, the constant in this bound is independent of n, and so the bound is a significant improvement over the bounds (2.6)". The finiteness of gamma_{n-1} follows from gamma_n = nu/(1 - nu), PDF 0002 l.37 (p.784), inside the read section 2 |
| test/reductions/fixtures.jl l.29 | magnitude an upper bound on sum|x_i| (eq 2.6) | Higham 1993 | eq. 2.6 | FIT | PDF 0003 |
| docs/plans/fiddlybits-52v.3-fields.md l.461 | residual at most gamma_D * M "in the model of Higham (1993, eq. 1.2, with 2.2 and 3.3)" | Higham 1993 | eqs 1.2, 2.2, 3.3 | NOT FIT (C6) | eq (1.2) is s.1 (PDF 0002 l.7) and eq (3.3) is s.3 (PDF 0005 l.25); the row read s.2 only |
| docs/decisions/0029-reproducibility-policy.md l.10-12, l.50-53, ref l.117 | fixed-order pairwise summation; compensated summation for accumulators | Higham 1993 | none | NOT FIT (C6) | pairwise and compensated summation are s.3 (PDF 0005-0009), not read |
| docs/decisions/0044-explicit-fma-in-bitwise-mode.md ref l.434-436 | "The bound Reductions.error_bound carries" | Higham 1993 | none | FIT | eq 2.6 |
| docs/requirements/num/closure-tolerance-from-floating-point.md ref l.74 | a tolerance derived from the accumulator's epsilon | Higham 1993 | none | FIT | eq 2.6 |
| docs/requirements/ter/closure-ledgers-at-every-conversion.md ref l.72-74 | "The bound a derived tolerance is computed from" | Higham 1993 | none | FIT | eq 2.6 |
| docs/requirements/num/precision-is-a-type-parameter.md ref l.99 | not stated | Higham 1993 | none | NOT VERIFIED | reference list only |
| docs/requirements/num/thread-invariance-and-backend-agreement.md ref l.102 | not stated | Higham 1993 | none | NOT VERIFIED | reference list only |
| registry core.hollingsworth_check (statistic, anchors) | internal; a one-level model at external depth does not show it | Hollingsworth 1983, read | s.1 p.417 | FIT | PDF 0001 |
| docs/decisions/0059 l.33-35, 152, 165 | internal; growth ~ f u / c; modified grad K; dissipation did not stop it | Hollingsworth 1983 | ss.1, 3, 5, 8; eq 7 | FIT | PDF 0001, 0002, 0006, 0008, 0011 |
| docs/decisions/0013 l.38-41, ref l.155 | every vector-invariant C-grid core checked against the instability | Hollingsworth 1983 | none | FIT | read whole |
| docs/decisions/0026-analytic-and-conservation-oracles.md l.65, ref l.220 | the Hollingsworth check an acceptance item | Hollingsworth 1983 | none | FIT | read whole |
| docs/decisions/0044 l.53, l.325, ref l.427-433 | fma the single correctly rounded operation | IEEE 754-2019, read | cl. 5.4.1 | FIT | PDF 0034 |
| test/backends/transcendentals.jl l.222-225 | fma correctly rounded, required of fusedMultiplyAdd | IEEE 754-2019 | none | FIT | PDF 0034 |
| src/Provenance/key.jl l.220, l.596 (file edited by fiddlybits-52v.6.26) | canonical bytes are the value's IEEE 754 bit pattern | IEEE 754-2019 | none | FIT (mention) | names the binary encoding; no number or law drawn |
| docs/decisions/0045-precision-pinned-constants-are-named-not-whole-files.md ref l.118-120 | cl. 5.4.2, the conversion the Float32 round trip goes through | IEEE 754-2019 | cl. 5.4.2 | NOT FIT (C6) | the passage supports the use: PDF 0035 "If the conversion is ... to a narrower precision in the same radix, the result shall be rounded as specified in Clause 4. Conversion to a format with the same radix but wider precision and range is always exact." The row does not name 5.4.2 |
| docs/decisions/0056-a-reduction-in-type-a-converts-each-operand-before-it-operates.md ref l.110-116 | cl. 3.6 Table 3.5: binary32 p = 24, binary64 p = 53 | IEEE 754-2019 | cl. 3.6, Table 3.5 | NOT FIT (C6) | the passage supports the use: PDF 0024 Table 3.5 "p, precision in bits" 24, 53. The row does not name 3.6 |
| src/Reductions/error_bound.jl l.20-30 (ERROR_BOUND_ULP_MARGIN, Derived) | "IEEE 754 round-to-nearest puts a correctly-rounded Float64 product within half a Float64 ulp" | IEEE 754-2019 | none | NOT FIT (C6) | rests on the rounding attributes (clause 4) and correct rounding of multiplication; the row read only the fusedMultiplyAdd entry |
| docs/requirements/num/precision-is-a-type-parameter.md l.12-13, l.51-53, ref l.97 | stagnation below half an ulp is "a property of IEEE arithmetic" | IEEE 754-2019 | none | NOT FIT (C6) | rests on round-to-nearest (clause 4), not read |
| docs/requirements/num/boundary-arithmetic-guarded-at-definition.md ref l.92 | not stated | IEEE 754-2019 | none | NOT VERIFIED | reference list only |
| registry core.hollingsworth_check (statistic, threshold, anchors) | power method App. B; zonal balanced flow s.4; non-depth-weighted s.2.2; cell KE grows s.5.1, Table 1 | Peixoto 2018, read | as stated | FIT | PDF 0005, 0010, 0015, 0017 |
| docs/decisions/0059 l.37-41, 162-167, 220 | as above | Peixoto 2018 | ss.1, 4, 5.1, 7 | FIT | as row |
| src/EarthRatios/EarthRatios.jl l.40-51 | solar_constant_unit 1361 W/m^2 | Prsa 2016, read | Table 1, nominal TSI | FIT | PDF 0003 Table 1 |
| docs/decisions/0059 l.200-203 | Z-grid dispersion insensitive to deformation radius; analysis linear | Randall 1994, read | s.3, Fig. 2, s.4 | FIT | PDF 0004-0006 |
| registry core.checkerboard_divergence_mode (statistic, anchors) | the f-sphere configuration | Thuburn 2009, read | s.4.3 p.8330 | FIT | read whole; "4.3. Longitude-latitude grid on the f-sphere" PDF 0010 |
| registry core.fsphere_normal_modes (statistic, threshold, anchors) | f = 1.4584e-4, Phi_0 = 1e5, a = 6371220 m as a ratio; mode counts; Figs 10, 11 | Thuburn 2009 | ss.4.3, 4.4, 4.5 | FIT | PDF 0011 l.7 "a = 6371220 m, ... f = 1.4584 x 10^-4"; PDF 0012 "642 are geostrophic modes and 2558 are inertia-gravity modes" |
| docs/decisions/0059 l.49, 67-71, 83-90, 197-200 | eq 33 weights; eq 39; stationary geostrophic modes; footnote 2 | Thuburn 2009 | as stated | FIT | PDF 0008, 0011-0014 |
| src/EarthRatios/EarthRatios.jl l.53-63 | pressure_unit 101325 Pa | CODATA 2018, read | Table XXXI | FIT | PDF 0052 |
| src/Systems/constants.jl l.19-22 | G = 6.67430e-11 | CODATA 2018 | Table XXX p.033105-45 | FIT | PDF 0046 |
| src/Systems/constants.jl l.32-46 | sigma from exact k, h, c of Table XXX | CODATA 2018 | Table XXX p.033105-45 | FIT | PDF 0046 |
| docs/plans/fiddlybits-52v.4-system.md l.441 | Earth() values IAU and CODATA | CODATA 2018 | none | FIT | Tables XXX, XXXI |
| registry core.checkerboard_divergence_mode (statistic, anchors) | Gauss divergence eq 6; first-order error eqs 7 and 10 | Wan 2013, read | s.4.2 eqs 6, 7, 10 p.740 | FIT | PDF 0006 |
| docs/decisions/0059 l.27-28, 82, 98-100, 127-132, 194, 234-238 | ss.4.2, 4.3, 5.2, 5.9, 8; eq 20 | Wan 2013 | as stated | FIT | PDF 0006-0008 and read whole |
| docs/decisions/0005-one-mesh-icosahedral-triangles.md l.176, 214-218, ref l.266-268 | ICON grid orientation, a vertex at each pole (p.738); wavenumber-five imprint (p.747) | Wan 2013 | pp.738, 747 | FIT (anchor column silent) | PDF 0004 l.10 vertices at the North and South Poles; PDF 0013 l.9 "near the pentagon points (cf. Sect. 3), resulting in wavenumber 5 patterns near 26.6 N/S" |
| docs/decisions/0013 l.33-37, ref l.148 | the operational triangle core's divergence-averaging filter | Wan 2013 | none | FIT | s.4.3 read |
| docs/decisions/0016-atmosphere-physics-scope.md l.16-17, ref l.194 | the core per 0013 | Wan 2013 | none | FIT | read whole |
| docs/requirements/ter/mesh-carries-both-dual-measures.md ref l.94-97 | not stated | Wan 2013 | none | NOT VERIFIED | reference list only |
| docs/decisions/0059 l.92-108, 227, 240 | one-ring velocity averaging; (A1)-(A3); time-averaged fluxes; fourth-order divergence damping | Zaengl 2015, read | ss.2.3, 2.4, 2.5, App. A | FIT | PDF 0005, PDF 0013 |
| docs/decisions/0005 ref l.272-275 | a reference of the mesh decision (exact nesting, refinement); no body locator | Zaengl 2015 | none | NOT FIT (C6) | the source's nesting (abstract PDF 0001 l.19; s.1 PDF 0002) is what the row states was not read |
| docs/decisions/0013 ref l.151-154 (body "Formulate general, implement the limit first") | ICON non-hydrostatic core as the general formulation the hydrostatic core is a limit of | Zaengl 2015 | none | NOT FIT (C6) | the row: "Not read for the general formulation" |
| docs/decisions/0016 l.16-17, ref l.195 | "the general non-hydrostatic deep-atmosphere formulation (F5)" | Zaengl 2015 | none | NOT FIT (C6) | as above |
| registry core.hollingsworth_check (statistic, threshold, anchors) | sigma from the converged amplification; ICON triangle least stable | Lapolli 2023, read (preprint) | s.4.5.1 pp.31-32 | FIT | PDF 0031-0032 |
| docs/decisions/0059 l.39-40 | ICON triangle C-grid among the least stable | Lapolli 2023 | s.4.5.1 p.32 | FIT | PDF 0001 l.26, PDF 0031 |
| docs/decisions/0059 l.172-178, 217-224 | density-weighted mass matrix; no-go theorem; Kelvin defect | Korn 2026, read (preprint) | s.1, Thm 2.6, Thm 4.6, Cor 5.20 | FIT | PDF 0001, 0008, 0016, 0032 |
| docs/decisions/0059 l.107-112, 130, 135-138 | filtering divergence breaks continuity; implicit filter energy and curl term; diffusion does not mitigate; oscillatory higher order | Wolfram 2013, read | ss.2.1, 3.1, 3.3, 3.5, 4.1 eq 18, 5.4.1, 6 | FIT | PDF 0002-0014 |

Open branch fiddlybits-52v.4.5 (test/planets/earth.jl; not on main, file edited by that branch):

| where | use | source | locator | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| earth.jl Sun mass (Sourced) | (GM)^N_sun = 1.3271244e20 / G | Prsa 2016 | Table 1 | NOT FIT (C6) | value is in Table 1 (PDF 0003 l.42) but the row is read for TSI only |
| earth.jl planet mass (Sourced) | (GM)^N_E = 3.986004e14 / G | Prsa 2016 | Table 1 | NOT FIT (C6) | Table 1 PDF 0003 l.47; not named |
| earth.jl orbit semi_major_axis locator | "the IAU 2012 astronomical unit au = 149597870700 m of Prsa et al. (2016)" | Prsa 2016 | Table 1 text | NOT FIT (C6, C5) | Prsa restates it: PDF 0003 l.101-103 "Resolution B2 of the XXVIII General Assembly of the IAU in 2012 defined the astronomical unit ... 149,597,870,700 m"; the defining text is IAU 2012 Resolution B2, not in the index |
| earth.jl Sun luminosity bracket | ends 3.8261e26, 3.8289e26 "solar-cycle-23-averaged TSI measurement (Prsa et al. 2016)" | Prsa 2016 | none | NOT FIT (C6) | PDF 0003 l.103-104 "L = 4 pi (1 au)^2 S = (3.8275 +/- 0.0014) x 10^26 W"; not named |
| earth.jl Sun radius bracket | ends 6.95518e8, 6.95798e8 "Haberreiter et al. (2008) ... (Prsa et al. 2016)" | Prsa 2016 for Haberreiter 2008 | none | NOT FIT (C6, C5) | PDF 0003 l.132-136 "Haberreiter et al. value (695 658 +/- 140 km)"; a measurement quoted through Prsa |
| earth.jl numerics exner_reference_pressure | 101325 Pa | CODATA 2018 | Table XXXI | FIT (value) | PDF 0052 |

#### Not-fit cases

1. Textor 2006 in REQ aerosol tracers (docs/requirements/atm/aerosol-tracers-one-particle-description-and-physical-sinks.md l.99-100, l.123-125).
   Use: emission, burden and lifetime per species against the AeroCom spread; the reference calls
   the spread "the Earth bar". Category C6, with a C7 note. The row is read for burdens and
   lifetimes (PDF 0011, Table 10), not emission diversity. "The inter-model spread that is the
   Earth bar" contradicts the requirement's own item 6 (REPORT rows), and decision 0025 takes a
   tier-2 bar from a model's own residual; an inter-model spread is a tier-3 basis. Fix class (b):
   read the emission diversities of Table 10 and extend the row's anchor (INDEX.md is edited by
   fiddlybits-k6b); reword the reference to "the inter-model spread the REPORT rows are shown
   against" (requirements fork to confirm).

2. Berger 1978 eq. 2 in decision 0004 (l.407-411, l.462). Use: the precessional parameter
   e sin(varpi-tilde). Category C6. Eq (2) exists and supports it (PDF 0001 l.20), but the row
   names only Fig. 1 and the Appendix definitions. Fix class (b), a documentation step with the
   passage already verified here: extend the row's anchor to eq. 2 once INDEX.md is free.

3. Berger 1978 daily-insolation form, in registry system.orbit_mean_insolation (statistic l.185,
   anchors l.191) and docs/plans/fiddlybits-52v.5-time.md l.29-30 and l.288. Use: the
   instantaneous geometry judged against Berger's daily-insolation form on every system.*
   instance, including the synthetic non-Earth instances (docs/oracles/README.md, Registration).
   - Category C6: Appendix eqs (8) to (10) and cos H0 = -tan(phi) tan(delta) (PDF 0005-0006) are
     not named by the row.
   - Category C3: the form takes "All the angles which locate the earth on its orbit ... as being
     constant over the whole day" and "the factor 86.4 provides W in kJ m-2 day-1" (PDF 0006
     l.11, l.19), with T "tropical year of 365.2422 mean solar days" (PDF 0005). It is valid only
     where the solar day is short against the orbital period, and its constant is Earth's day.
     A synchronous or slow rotator is outside it, and fiddlybits-52v.4.5 carries a synchronous
     instance.
   Fix class (b): extend the anchor to eqs (8) to (10). The statistic, a provisional unregistered
   entry, either states the validity condition (86.4 replaced by the declared mean solar day, the
   arm run only where the solar day is short against the year) or restricts the arm to instances
   that meet it. That is a registry-only merge; registry.toml is edited by fiddlybits-k6b,
   52v.6.26 and 52v.8.13. It touches no registered bar.

4. Braun and Willett 2013 in decision 0015 (l.78, l.83, ref l.128). Use: "implicit incision has
   no CFL constraint"; the implicit incision's steepest receiver. Category C6. The row itself says
   "the implicit update itself is not yet read". The scheme is section 4 (PDF 0004 l.35 to PDF
   0005 l.27), which qualifies the claim: "our method is not fully implicit (with respect to
   drainage area) but relies on the assumption that the rate of change of the geometry of the
   drainage network is slow in comparison to the rate of change of the elevation". Fix class (b):
   read s.4 and extend the anchor. If the reading shows the unconditional "no CFL constraint"
   needs the drainage-area qualifier, that changes a decision's statement (flag for the user).

5. Braun and Willett 2013 in docs/requirements/ter/gravity-enters-through-the-law.md (l.16, ref
   l.117). Use: "slope exponent n = 1 (the implicit solver's form)". Category C6. It rests on the
   unread implicit update, and the source gives a Newton-Raphson iteration for general n (PDF 0005
   l.19), so n = 1 is not the solver's only form. Fix class (b): read s.4, then either say the
   predecessor's solver used n = 1 or cite the closed form for n = 1.

6. Higham 1993 in src/Reductions/error_bound.jl validity_limit docstring (l.34-41) and the testset
   name in test/reductions/error_bound.jl l.33.
   - Use: the term count above which gamma_{n-1} of eq 2.6 is not a finite positive bound, cited
     as "n * u <= 1 (1993, discussion following eq. 3.11)".
   - Categories C6 and C2. That passage is section 3, which the row does not name as read. It
     states the compensated-summation constant is independent of n "As long as nu <= 1" (PDF
     0009 l.27), not a condition on gamma_{n-1}.
   - The condition follows from the definition gamma_n = nu/(1 - nu) (PDF 0002 l.37, p.784),
     inside the read section 2.
   - Fix class (a), a locator correction, the correct source already read: cite "the definition
     of gamma_n following eq. 2.2, p. 784" in both places. Neither file is edited by an open
     branch. This is a docstring and testset-name correction; no value moves.

7. Higham 1993 in docs/plans/fiddlybits-52v.3-fields.md l.461. Use: residual at most gamma_D * M
   "in the model of Higham (1993, eq. 1.2, with 2.2 and 3.3)". Category C6. Eq (1.2) is section 1
   (PDF 0002 l.7) and eq (3.3) is section 3 (PDF 0005 l.25); the row read section 2. Fix class
   (b): read eq 1.2 and s.3 through eq 3.3, and extend the anchor.

8. Higham 1993 in decision 0029 (l.10-12, l.50-53, ref l.117). Use: fixed-order pairwise
   summation and compensated summation as the reproducible and accumulator forms. Category C6.
   Both methods are section 3 (PDF 0005-0009), not read. Fix class (b): read s.3 (pairwise and
   compensated, eqs 3.5 to 3.11) and extend the anchor.

9. IEEE 754-2019 cl. 5.4.2 in decision 0045 (ref l.118-120). Use: the conversion the Float32
   round trip goes through. Category C6. Passage verified here (PDF 0035, quoted above) and it
   supports the use; the row names only 5.4.1. Fix: extend the row's anchor once INDEX.md is free.
   It is class (a) in substance, but INDEX.md is edited by fiddlybits-k6b, so class (b).

10. IEEE 754-2019 cl. 3.6 Table 3.5 in decision 0056 (ref l.110-116). Use: binary32 p = 24,
    binary64 p = 53. Category C6. Verified (PDF 0024). Fix as case 9.

11. IEEE 754-2019 in src/Reductions/error_bound.jl l.20-30, ERROR_BOUND_ULP_MARGIN (Derived).
    Use: a correctly rounded Float64 product is within half an ulp under round-to-nearest.
    Category C6. It rests on the rounding-direction attributes (clause 4) and correct rounding of
    multiplication (5.4.1 multiplication entry), not the fusedMultiplyAdd entry the row read. Fix
    class (b): read clause 4.3 (roundTiesToEven) and extend the anchor; the comment may then name
    the clause.

12. IEEE 754-2019 in docs/requirements/num/precision-is-a-type-parameter.md (l.12-13, l.51-53,
    ref l.97). Use: stagnation below half an ulp "a property of IEEE arithmetic". Category C6.
    It rests on round-to-nearest, clause 4, not read. Fix class (b): as case 11, plus a clause
    locator in the reference.

13 to 15. Zaengl et al. 2015 in decision 0005 (ref l.272-275), decision 0013 (ref l.151-154,
    s. "Formulate general, implement the limit first") and decision 0016 (l.16-17, ref l.195).
    Use: in 0013 and 0016, the ICON non-hydrostatic core as the general formulation (F5) the
    hydrostatic core is a limit of; in 0005, a mesh reference with no stated locator, whose
    subject is exact nesting and refinement. Category C6. The row states "Not read for the
    general formulation or nesting". Fix class (b): read s.2.1 and 2.2 (the equation set) and the
    nesting description, and extend the anchor with locators in the three decisions. If the
    reading does not support F5 as stated, that touches the basis of decision 0013 and 0016
    (flag for the user).

Open branch fiddlybits-52v.4.5 (test/planets/earth.jl):

16 to 20. Prsa et al. 2016 cited beyond its read passage: Sun and Earth mass parameters (Table 1),
    the IAU 2012 au, the luminosity bracket ends from L = (3.8275 +/- 0.0014) x 10^26 W, and the
    radius bracket ends from Haberreiter et al. 2008 quoted by Prsa. Category C6 for all; C5 for
    the au (primary: IAU 2012 Resolution B2) and for the Haberreiter radius (primary: Haberreiter,
    Schmutz and Kosovichev 2008, ApJL 675, L53). Evidence: PDF 0003 l.42, 47, 101-104, 132-136.
    Fix class (b): Prsa's Table 1 GM rows and the passages at PDF 0003 l.95-136 are read and the
    row's anchor extended before 52v.4.5 merges, since lint_sourced reads status by row and not by
    passage. The two C5 items either cite their primaries (fetch IAU 2012 Resolution B2 and
    Haberreiter 2008, both open access) or keep Prsa with the secondary nature stated. The
    bracket ends are not Sourced values, so the lint does not see them. Changing a locator here
    changes no declared value.

A row grouping for the parent. Every case except 6 is carried by an INDEX.md anchor extension
after reading the named passage. All of them could be one row, "INDEX.md read rows name every
passage their citing uses rest on", with this boundary: docs/references/INDEX.md, plus the
citing lines named above for locators. It depends on fiddlybits-k6b merging. Case 3's C3 half is
a separate registry-only row (system.orbit_mean_insolation validity). Cases 16 to 20 belong with
fiddlybits-52v.4.5.

#### Fetch failures and paywalled sources

None. All twenty sources are held under /home/cfutro/git/fiddlybits/references/pdf with page text
under references/text. The open-access primaries that cases 16 to 20 would add, which this scope
did not fetch: "IAU 2012 Resolution B2 on the re-definition of the astronomical unit of length"
(IAU, XXVIII General Assembly, Beijing 2012) and Haberreiter, M., Schmutz, W., Kosovichev, A. G.
2008, "Solving the Discrepancy between the Seismic and Photospheric Solar Radius", ApJL 675, L53
(10.1086/529492; identifier from memory, confirm before fetching).
