+++
id = "REQ-TER-013"
title = "Gravity enters terrain through the erosion law, isostasy and strength, never as a scaling applied to heights at export"
old_path = ["/home/cfutro/git/vesper/notes/audits/orogen-gravity.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's terrain generator ran tectonics, erosion and basin detection
in dimensionless units and applied `reliefScale = g_ref / g` to positive
heights at export, so two builds differing only in gravity were bit-identical
in every hash. The audit found the shortcut exact for the fluvial landscape,
but only under two conditions nobody had declared. First, the stream-power law
had slope exponent n = 1 (the implicit solver's form), and at steady state
`K A^m S = U` with `K ~ rho g` gives `S ~ 1/g`, which uniform 1/g reproduces;
at n = 2 the correct scaling is `g^(-1/2)` and the export was over-correcting
relief by about 14 per cent. "n = 1 is a choice, and nothing in the generator
states it." Second, the network had to be at grade: measured on the build's
settings anything with ten or more upstream cells was at grade after twelve
iterations, and single-cell headwaters carried 13.6 per cent residual relief
against 7.8 per cent when run at the correct gravity, a 5.7 per cent local
difference confined to the finest headwaters; a lower erosion setting would
have left the landscape transient and the equivalence weaker, and nothing
warned of it. Bathymetry was correctly left unscaled because g multiplies
every term of the isostatic balance and cancels; for the same reason
isostatically compensated plateaus are gravity-independent, so uniform 1/g on
land over-suppressed them, and separating strength-supported from compensated
relief needed a crustal-thickness field the generator did not carry. The angle
of repose is gravity-independent and two orders below what the mesh resolved.

Glacial erosion carried no gravity term at all, and adding one was refused for
a structural reason. The honest bracket at 1.306 Earth gravities ran from
`g^0.6` (flux conserved, erosion proportional to velocity) to `g^6` (thickness
conserved, quarrying or abrasion squared), a factor of 4.2 whose width was set
by WHICH QUANTITY IS CONSERVED, a choice the generator could not make because
it carried no thickness, sliding velocity or effective pressure. A snow column
integrating only local mass balance was not a substitute: it is zero where a
glacier erodes and anti-correlated with the thickness needed, and substituting
it would have imposed the thickness-fixed limb while appearing to measure it.
"A rigorous factor multiplying a heuristic reads as more trustworthy than it
is." The dimensionless glacial altitude gate was gravity-invariant because both
strength-limited relief and the dry-adiabatic freezing height go as 1/g. From
the hydrography note: the gravity term and the slope exponent are one question
and cannot be settled separately, or the factor is double-counted.

## Why it carries

Decision B1 states the requirement: stream-power incision with K in SI, gravity
entering through K, isostasy and strength-limited relief, never as an export
scaling. The evidence is why: the shortcut is exact only under conditions
nobody declared, silently wrong when they fail, irreparable for glacial
erosion without prognostic ice state, and it makes terrain independent of the
one parameter a builder must sweep (M4b). A generic builder gets its terrain's
gravity dependence from the laws, or it does not have one.

## What this system must do

- The incision law is written once, in discharge, in 0015: `dz/dt = U - K Q^m S^n`
  with `Q` the accumulated runoff from hydrology, `K = rho_w g k_e`, `k_e`
  `Bracketed` with the dimension `Pa^-1 m^(1-3m) s^(m-1)`, and the form `Sourced`.
  An Earth field coefficient enters only through the conversion rule of 0015
  (dividing out the fitting landscape's `rho_w g`, mean runoff and year). Gravity is
  in `K` exactly once; sill incision (REQ-HYD-008) points to 0015 and carries no
  gravity factor of its own.
- The slope exponent n is declared with disposition `Bracketed` and swept; no
  solver form is allowed to fix it silently. The concavity `theta = m/n` is
  `Bracketed` and `m` is `Derived = theta n`, so a swept `n` keeps the concavity the
  oracle tests instead of moving it.
- Sediment continuity with deposition is part of the law (Yuan et al. 2019
  form), so the steady-state argument is not the only regime the system runs.
- Flexural isostasy from the densities and the crustal thickness per province
  class of the lithosphere block of System (0004), `Bracketed` with Earth as the
  reported distance, and the elastic thickness from the yield isotherm on the same
  geotherm (0015). This system holds no crust-production law, so a "computed"
  crustal thickness means `Derived` from those declared inputs and the orogen's
  integrated uplift under Airy; the gap between that and a crust-production model
  is a declared absence with its interface named. With `g` explicit in every term
  of the isostatic balance, bathymetry and compensated plateaus are gravity-free by
  computation.
- Strength-limited relief through a Culmann-type limit `H_c ~ 1/(rho g)` with
  `Sourced` strength, applied as a process (landsliding lowers peaks), never as
  a clamp (REQ-TER-014).
- Glacial erosion is evaluated only where the cryosphere (B6) supplies
  thickness, sliding velocity and effective pressure from a shallow-ice solve
  with `(rho g)^n` explicit and a Weertman sliding law. The law is the two-limb
  form of 0015, `E_g = K_g N^r |u_b|^l`, with `r` `Bracketed` between the abrasion
  end (Hallet 1979) and the quarrying end (Iverson 2012), `l` `Bracketed` between
  the linear and the squared sliding ends, and `K_g` carrying `Pa^-r m^(1-l)
  s^(l-1)`. A velocity-only form `K_g |u_b|^l` carries gravity through `u_b` alone
  and cannot express the flux-conserved to thickness-conserved bracket recorded
  above; the pressure limb is what does, and the bracket's width is now the
  declared spread of `r` and `l`, not a choice the formulation hides.
- No height is scaled at export; the heightmap and the state are the same
  numbers.
- The gravity sweep oracle: at steady state relief scales as `g^(-1/n)`, which
  is 1/g at n = 1 (the analytic result the old shortcut relied on); the deviation
  at other n and off grade is the test that gravity entered through the law, and
  the registry states the general form, not the n = 1 case.

## Enforced by

- A3 dispositions: no export-scaling constant can exist; `Derived` refuses a
  disagreeing caller value.
- C3: stream-power steady profiles and relief scaling; Halfar dome (B6).
- M4b gravity sweep against published gravity identities.
- Lint: `g` appears only inside laws, never as a post-multiplication of a
  state array.

## References

- Whipple, K. X., Tucker, G. E. (1999). "Dynamics of the stream-power river
  incision model: Implications for height limits of mountain ranges, landscape
  response timescales, and research needs". Journal of Geophysical Research
  104(B8), 17661-17674. DOI: 10.1029/1999JB900120.
- Braun, J., Willett, S. D. (2013). "A very efficient O(n), implicit and
  parallel method to solve the stream power equation governing fluvial
  incision and landscape evolution". Geomorphology 180-181, 170-179.
  DOI: 10.1016/j.geomorph.2012.10.008.
- Yuan, X. P., Braun, J., Guerit, L., Rouby, D., Cordonnier, G. (2019). "A New
  Efficient Method to Solve the Stream Power Law Model Taking Into Account
  Sediment Deposition". Journal of Geophysical Research: Earth Surface 124,
  1346-1365. DOI: 10.1029/2018JF004867.
- Airy, G. B. (1855). "On the computation of the effect of the attraction of
  mountain-masses, as disturbing the apparent astronomical latitude of stations
  in geodetic surveys". Philosophical Transactions of the Royal Society 145,
  101-104. DOI: 10.1098/rstl.1855.0003.
- Turcotte, D. L., Schubert, G. (2014). "Geodynamics", third edition. Cambridge
  University Press. DOI: 10.1017/CBO9780511843877. Flexural isostasy.
- Schmidt, K. M., Montgomery, D. R. (1995). "Limits to Relief". Science
  270(5236), 617-620. DOI: 10.1126/science.270.5236.617.
- Montgomery, D. R. (2001). "Slope distributions, threshold hillslopes, and
  steady-state topography". American Journal of Science 301, 432-454.
  DOI: 10.2475/ajs.301.4-5.432.
- Glen, J. W. (1955). "The creep of polycrystalline ice". Proceedings of the
  Royal Society A 228, 519-538. DOI: 10.1098/rspa.1955.0066.
- Weertman, J. (1957). "On the Sliding of Glaciers". Journal of Glaciology
  3(21), 33-38. DOI: 10.3189/S0022143000024709.
- Iverson, N. R. (2012). "A theory of glacial quarrying for landscape evolution
  models". Geology 40(8), 679-682. DOI: 10.1130/G33079.1.
- Hallet, B. (1979). "A theoretical model of glacial abrasion". Journal of
  Glaciology 23(89), 39-50. DOI: 10.3189/S0022143000029725.

## Amendments

- 2026-09-08: incision law pointed to its single definition in 0015 (discharge form, `k_e` dimension, conversion rule), `theta` Bracketed with `m` Derived (rows 1 and 9), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: "computed crustal thickness" replaced by Derived from the lithosphere block of System (0004) with the crust-production gap a declared absence (row 7), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: glacial erosion given the effective-pressure limb with `r`, `l` Bracketed and `K_g`'s dimension; the velocity-only form named as unable to carry the recorded bracket (row 3); gravity oracle stated as `g^(-1/n)` (row 10), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the glacial-erosion pressure exponent renamed `r`; Hallet 1979 identifier filled, from notes/findings/2026-09-08-implicit-earth-audit.md
