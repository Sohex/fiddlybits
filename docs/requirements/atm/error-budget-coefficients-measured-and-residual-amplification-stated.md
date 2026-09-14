+++
id = "REQ-ATM-016"
title = "An error-budget conversion coefficient is measured on paired arms with a null pair and a declared denominator; a quantity that is a residual of two large terms carries its amplification and its propagated uncertainty, and an amplification factor is applied only to perturbations of the kind it was measured for"
old_path = ["/home/cfutro/git/vesper/notes/audits/hydrological-sensitivity.md", "/home/cfutro/git/vesper/notes/audits/albedo-attenuation.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's error budget, which priced every item in kelvin and
informed a decision taken in millimetres of runoff.

- Land precipitation and land evaporation responded at +2.19 and +2.42 per cent
  per kelvin across two converged runs, stable to a few per cent across 5-, 10-
  and 20-orbit windows; their difference, runoff, responded at +0.64 to +1.13
  per cent per kelvin across the same windows, a factor of 1.8 from inputs that
  agreed to a few per cent. Runoff was 15 per cent of precipitation, so each
  amplified channel was twenty times the residual and a 1 per cent wobble in
  either input was 13 per cent on the answer (`hydrological-sensitivity.md`
  finding 2). The kelvin-to-runoff conversion was good to a factor of two, inside
  a budget that declared itself a factor-of-two instrument for ordering.
- The amplification `P/R` (6.5) is the right factor for a perturbation that
  moves the hydrological cycle without moving the temperature (a dust
  suppression, a circulation change) and the wrong factor for every kelvin-
  priced item: `2.19 x 6.51 = 14.3` per cent per kelvin against the true
  `2.19 x 6.51 - 2.42 x 5.51 = 0.92`, an order of magnitude, because the two
  amplified terms nearly annihilate (finding 3). The lake evaporation limb was
  carried as a bracket between the land rate and the Clausius-Clapeyron
  convexity, and reached the basin count only, because runoff contains no lake
  evaporation (finding 4). The direction, warming closes basins, survived every
  re-measurement.
- The surface-to-planetary attenuation of an albedo change had been declared
  at 0.5 with the honest claim being a factor of two; measured on four paired
  equilibrated spin-ups differing in one key, it was 0.29 to 0.47 on the staged
  denominator and 0.31 to 0.66 on the diagnosed one, a factor of 1.45 from the
  choice of denominator, and only the staged one composes with a budget whose
  items are staged deltas (`albedo-attenuation.md`). A null pair (identical
  surface, different executables and routes to equilibrium) separated by
  -0.007 K, 460 times below the signal. The rule for whether one constant
  survives (span within 1.5, 1.5 to 2 with both columns, beyond 2 refused) was
  registered before the numbers, and so was the exclusion test for a pair that
  prices the swap rather than the attenuation. The equilibrium planetary-albedo
  ratio sat above the attenuation because it contained the feedbacks the slope
  already carried, and using it would count them twice. A proposed arm was
  refused because its predicted separation did not clear three times the
  instrument's quadrature half-width over most of the bracket, and another was
  bought at a wider step for that reason.
- The response had to be measured under the same land mean the amplification
  was, because two builds are two land means; a cross-build read was
  defensible for the attenuation (a property of the modelled atmosphere) and not
  for the hydrological response.

## Why it carries

Every configuration's error budget will convert between currencies (kelvin,
W/m2, millimetres, basin counts, tile areas), and some of its quantities will be
residuals of large terms: runoff, net surface energy, salt balance, carbon
balance. The arithmetic of a residual's uncertainty and the distinction between
an amplification and a sensitivity are generic and survive any model. The
measurement discipline for a coefficient (paired arms, one input, a null pair,
a declared denominator, a shape rule fixed first, arms sized against the
instrument) is the same discipline REQ-ATM-014 requires for a sensitivity.

## What this system must do

1. Every coefficient that converts one budget currency into another is
   `Bracketed`, measured on paired arms that differ in one input by hash, with a
   null pair (same inputs, independent integrations) establishing the
   instrument floor, and stored with its pair identities, denominator convention
   and regime (REQ-ATM-014).
2. The denominator of a coefficient is declared: a staged boundary condition or a
   diagnosed field are different quantities and only the one the budget's items
   are denominated in composes with it.
3. A quantity that is a small residual of large terms carries its amplification
   (the ratio of each term to the residual) and reports the uncertainty of the
   residual propagated from the terms, never the terms' own; a budget states its
   tolerance (ordering at a factor of two, or a number) and refuses a use that
   wants more.
4. An amplification factor is applied only to perturbations of the kind it was
   measured for; a kelvin-priced item goes through the full derivative in which
   the amplified terms cancel, and a design that needs the amplification names
   the perturbation class it applies to.
5. A rule deciding the shape of a coefficient (constant, constant with spread,
   or field) is registered before the arms run, with the exclusion test for a
   pair that measures something else; the equilibrium ratio containing the
   feedbacks is never used where the forcing attenuation is meant.
6. An arm is bought only when its predicted separation clears three times the
   instrument's measured scatter; a refused arm is recorded with the contrast or
   length that would make it buyable.
7. A coefficient composes only with amplifications measured on the same
   configuration and profile; the budget refuses a cross-configuration pairing
   unless the coefficient is a property that survives the change and the record
   says why.

## Enforced by

- Decision 0025 (pre-registration; pattern metrics; hold-outs) and decision 0029
  (A/A scatter before any bar).
- A `Budget` type carrying currency, coefficient provenance, denominator and
  amplification class, refusing composition across configurations.
- The ledger residual classification of decision 0026, which gives a residual's
  time signature rather than a point value.

## References

- Held, I. M., Soden, B. J. (2006). *Robust Responses of the Hydrological Cycle to
  Global Warming.* J. Climate 19(21), 5686-5699. DOI: 10.1175/JCLI3990.1 (to
  confirm). The scaling of precipitation and evaporation with temperature at a
  rate well below the Clausius-Clapeyron rate, which is why their difference is
  a residual whose sign and size are a property of the configuration.
