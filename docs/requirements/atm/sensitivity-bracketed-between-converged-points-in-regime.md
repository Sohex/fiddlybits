+++
id = "REQ-ATM-014"
title = "A sensitivity is a chord between two converged runs that share everything but one input, carries its pair identity and regime, and is never carried across a regime boundary; a derived design quantity's thresholds are declared before it is derived"
old_path = ["/home/cfutro/docs/world/notes/audits/design-flux-two-point-response.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's flux and albedo experiments across several builds.

- A sensitivity of 0.94 K per W/m2, measured across a flux step in which sea ice
  fell from 11 to 2 per cent, was applied to an albedo step in a state with 0.02
  per cent ice; the prediction was 299.4 K and the measurement 295.2 K, the
  realised 0.33 K per W/m2 within 6 per cent of the bare Planck response. Two
  sensitivities on one planet differed threefold, and every extrapolation that
  used the first outside its regime was wrong by that factor
  (`parameter-decisions.md`, "The sensitivity used for every extrapolation was
  measured in the wrong regime"). The later chord across the ice transition, 201
  K per unit flux ratio, was accurate at an interior point to 0.03 K where the
  concavity argument had predicted a bound.
- Two converged points 0.055 apart in flux differed by 8.5 K in the global mean,
  but the land's coldest-month temperature at 60 to 70 degrees warmed 20 to 25 K
  while the same bands' warmest month cooled: a uniform shift of the field
  understated the cold tail by a factor of three, so the derivation projected per
  cell between the two points and marked everything outside them as
  extrapolation (this audit, "The amplification is large"). The projection was
  linear where sea-ice retreat is a threshold, and both runs sat on surfaces
  without the terms that moderate extremes; both limits were stated.
- A design criterion's cap had been inferred from the anchor it was meant to
  constrain rather than declared; the derivation, once codified, refused on its
  own guard (a band's warm-season response was negative, so there was nothing
  to scale by), and the anchor stood by decision with the unmet cap recorded as
  such rather than re-declared to fit. A coincidence, the same value justified
  by two unrelated arguments, was recorded as a coincidence (`inherited-earth-
  constants.md` finding 5; this audit, "The derivation does not run").
- The chord on the configured build was 173 K per unit flux ratio by three
  estimators agreeing to 0.17; both arms had to be bought together because the
  staged surface's digest differed from every existing run's, and a pair taken
  across that seam would have measured the surface as well as the flux
  (`flux-slope-bracket.md`). The slope was better determined than either arm's
  asymptote because the arms erred together.
- The surface-to-planetary attenuation of an albedo change was declared at 0.5
  and measured at 0.29 to 0.47 on four pairs, with the equilibrium ratio (0.42 to
  0.53) rejected because it contains the feedback the slope already carries
  (`albedo-attenuation.md`).

## Why it carries

A generic builder sweeps rotation, obliquity, gravity, stellar type and flux
(the M4b sweeps), and every configuration has its own ice, cloud and water-vapour
regimes with their own local slopes. A sensitivity is a property of the pair it
was measured on. The class "reuse a coefficient outside the regime it was
measured in" is epistemic and survives any language; what a design can do is
make a sensitivity a value that carries its provenance and refuses use outside
it, and make a derived design quantity's derivation a step whose thresholds are
registered before it runs (decision 0025, anti-tuning).

## What this system must do

1. Every sensitivity, slope or attenuation is a `Bracketed` value of a
   `Sensitivity` type carrying the two run identities by hash, the one input
   that differed, the regime descriptors at both ends (ice fraction, cloud
   state, surface state, profile), the estimator, and its spread (decision
   0010).
2. A `Sensitivity` refuses arithmetic with a state whose regime descriptors lie
   outside its pair's, and any projection beyond the chord is labelled
   extrapolation in the artifact it produces.
3. Both arms of a pair share every input but one, by hash; a pair assembled
   across a change of surface, code or profile is refused at construction.
4. Responses are projected per cell or per band between the two points, never
   as a global shift, and the projection's linearity assumption is a declared
   limit where a threshold process (ice, snow, cloud) lies inside the chord.
5. A derived design quantity (a flux placing a configuration in a declared
   climate band, an epoch, any parameter chosen against a criterion) is derived
   by a registered step whose thresholds and caps are declared before it runs; a
   threshold fitted to its own answer is refused, and a criterion no candidate
   satisfies is recorded as unmet rather than redeclared (decision 0025).
6. A forcing-to-response conversion uses the forcing attenuation, never the
   equilibrium ratio that contains the feedbacks the slope already carries.

## Enforced by

- Decision 0010 (run identity by hash), decision 0025 (a bar fixed before
  the value it judges has been seen; `answers:` discipline), decision 0007 (`Bracketed`
  swept).
- The `Sensitivity` type and its regime check; the M4b sweeps (decision 0034)
  that make the regime dependence of every slope a measured table.
- The failure-classes review (decision 0028): row "coefficient reused across a
  regime".

## References

- Budyko, M. I. (1969). *The effect of solar radiation variations on the climate
  of the Earth.* Tellus 21(5), 611-619.
  DOI: 10.1111/j.2153-3490.1969.tb00466.x (to confirm).
- North, G. R. (1975). *Theory of Energy-Balance Climate Models.* J. Atmos. Sci.
  32(11), 2033-2043. DOI: 10.1175/1520-0469(1975)032<2033:TOEBCM>2.0.CO;2 (to
  confirm). The energy-balance analysis in which the climate sensitivity is a
  function of the ice edge and changes discontinuously across the ice-albedo
  transition, the mechanism behind the threefold difference measured here.
