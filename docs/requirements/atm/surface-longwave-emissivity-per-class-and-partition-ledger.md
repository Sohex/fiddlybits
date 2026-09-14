+++
id = "REQ-ATM-008"
title = "Surface longwave emissivity is derived per surface class from hemispherical spectra weighted by the surface's own Planck function, the reflected downwelling is debited at the surface, and a per-level energy ledger catches a partition defect the column ledger cannot"
old_path = ["/home/cfutro/git/vesper/notes/audits/surface-longwave.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's longwave routine and on a spectral library.

- Land emissivity was exactly 1.0 by a bare literal with no comment, unit or
  source, the only large radiative literal in the module with no coverage
  anywhere in the tree (`opaque-constants.md` finding 6). Surface net longwave is
  `-eps (sigma Ts^4 - LWdown)`, exactly linear in the emissivity, so the cost
  needed no run: 3.36 W/m2 over land, one-signed, against a land-mean loss of
  51.9 W/m2 (finding 2, "The measurement").
- Derived per rock class from hemispherical reflectance spectra, Planck-weighted
  over 8 to 14 um with a solid-to-particulate preparation bracket, the land mean
  was 0.936 (0.919 to 0.952). Only hemispherical measurements were read, because
  Kirchhoff needs the hemisphere and a bidirectional reflectance gives an upper
  bound. Halite was held out because a pure optically thick powder is the wrong
  preparation for a crust. The spectra stopped at 14 um and the surface radiated
  mostly beyond it, so the out-of-band bound (a blackbody outside the band)
  compressed every contrast.
- Whether a per-cell field bought anything over a scalar at the field's own mean
  was decided by a criterion fixed before any spectrum was read: 1.4 W/m2, the
  model's own dry-adiabatic energy sink. The field was worth 0.47 W/m2 (0.17 at
  the compressing bound) and was refused; on the native mesh the spread was three
  times larger, so a finer level reopens it by measurement rather than argument.
- The correction for a non-black surface, `(1 - eps) LWdown` reflected upward,
  ran over levels 1 to NLEV on an array dimensioned NLEV, so the surface level
  never received it: the reflected flux was propagated up through every
  atmospheric level and never taken off the surface budget the land and ocean
  components settle. The column conserved; the partition did not. It was
  invisible while land was black and worth 0.02 of the downward longwave over
  every ocean and sea-ice cell in every run (finding 1).

## Why it carries

Emissivity is a property of a material weighted by the surface's own Planck
function, which depends on the surface temperature and not on the star, so the
derivation transfers to any configuration and the source spectra are the same
libraries REQ-ATM-002 reads for reflectance. The partition finding is a shape
bug: a loop that cannot reach the level it exists for. A column energy ledger
cannot see it; a ledger per level, with the surface as its own level, can, and
an array whose shape is the ladder plus the surface cannot express it at all.
The field-versus-scalar criterion generalises: a spatial refinement is bought
against a bar fixed before the measurement, in the model's own non-conservation
currency.

## What this system must do

1. Broadband (or per longwave band) emissivity per surface class is derived from
   hemispherical reflectance spectra weighted by the Planck function over the
   tile's own temperature range, with a preparation bracket and the out-of-band
   assumption declared (decision 0016, N-band surface properties). Tiles carry
   their class, so the scalar-versus-field question is resolved by the tile
   structure rather than by a separate field (decision 0018).
2. The reflected downwelling longwave is applied at the surface and at every
   level; the surface is a level of the radiation's vertical ladder in type, so
   no loop can omit it (decision 0006).
3. The energy ledger closes per level and at the surface separately, not only
   over the column, and its residual's spatial and temporal signature is
   classified (decision 0026).
4. Any per-cell refinement of a surface property is bought against a criterion
   fixed before the measurement, stated in the currency of the model's own
   non-conservation, and re-run at each finer level rather than argued.
5. Earth oracle: land-mean broadband emissivity by biome and desert class
   against published values as REPORT rows (decision 0025).

## Enforced by

- Decision 0006 (level ladder as a type including the surface), decision 0009
  (ledgers at every exchange), decision 0026 (per-level closure, tolerance from
  floating point).
- The mutation run (decision 0027): a mutation that drops the surface level from
  the reflection loop must be caught by the per-level ledger.
- The registry pre-registration rule for the refinement criterion (decision
  0025).

## References

- Meerdink, S. K., Hook, S. J., Roberts, D. A., Abbott, E. A. (2019). *The
  ECOSTRESS spectral library version 1.0.* Remote Sensing of Environment 230,
  111196. DOI: 10.1016/j.rse.2019.05.015. Hemispherical rock and mineral spectra
  in the thermal window.
- Baldridge, A. M., Hook, S. J., Grove, C. I., Rivera, G. (2009). *The ASTER
  spectral library version 2.0.* Remote Sensing of Environment 113(4), 711-715.
  DOI: 10.1016/j.rse.2008.11.007.
