+++
id = "REQ-ATM-001"
title = "The stellar spectrum is flux-conserved onto the radiation grid and checked against an independent rendering with a tolerance derived before the measurement"
old_path = ["/home/cfutro/git/vesper/notes/audits/stellar-spectrum-oracle.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's stellar-spectrum pipeline: a BT-Settl model grid
interpolated between two temperature points and resampled onto a two-band GCM's
2048-point wavelength grid, for a mid-K host whose band-1 (below 0.75 um) flux
share was the one number carrying the star's colour into the surface energy
balance.

- The shipped file was not the source. The resampler was a point sample
  (`np.interp`) of an R ~ 130,000 spectrum onto an R ~ 775 grid; a point sample
  lands in the continuum more often than in a line core, line density is highest
  in the blue, and band 1 was biased high by 0.00196. A flux-conserving rebin onto
  the same grid reproduced the source integral to 0.000003 (section "The
  mechanism, demonstrated without the oracle").
- An independent rendering of the same grid points (a second project's R = 100
  degradation of the same release) agreed with the source to 0.000325, so the
  source data and the interpolation were validated and the residual was
  attributed to the resampler rather than argued about.
- The tolerance, 0.0010 absolute on the band fraction, was assembled before the
  oracle value was computed from six terms each bounded without the oracle:
  resolution 0.000011, degradation kernel 0.000016, truncation 0.000017, blend
  treatment 0.000069, discretisation 0.000007, and two renderings of one grid
  point 0.00032 to 0.00038. A crude worst-case bound would have been 0.0036, 300
  times the measured term, and would have made the check unable to fail.
- The errors the check exists to detect were tabulated beside it: rounding to a
  grid temperature instead of interpolating, +0.0063 or -0.0114; the wrong
  surface gravity, +0.0041; the wrong metallicity, +0.0114 or -0.0084. Every one
  is 4 to 11 times the tolerance, and the falsification was stated in advance.
- The star's most consequential undeclared parameter, metallicity, lived only in
  a build script and a provenance file, nowhere the configuration could see.
- The downstream cost of the defect was 0.005 K and 0.5 per cent of gross primary
  productivity through the photosynthetically active fraction: small, and not
  the point.

## Why it carries

A generic builder ingests a spectrum for every configuration, from stellar
models, from a declared function or from several sources at once (decisions 0004,
0032), and integrates every reflectance, absorptance and photon current against it
(REQ-ATM-002, REQ-ATM-003). A spectrum is a flux density; resampling it by any
operator other than an integral is a semantics error of exactly the kind decision
0006 makes a type error. The test-design lesson generalises to every oracle the
system registers: a tolerance is derived from terms that do not depend on the
answer, it is smaller than every error the check must detect by a stated factor,
and that table is part of the registration.

## What this system must do

1. The stellar spectrum is a `Field` of flux-density semantics; changing its
   support (to the radiation grid, to a band, to a photon count) is an integral,
   never a point sample (decision 0006).
2. Effective temperature, surface gravity, metallicity and the interpolation
   rule between model grid points are declared in `System` or derived from mass,
   age and metallicity (decision 0004); any spectrum artifact carries them and a
   content hash in the run identity (decision 0010).
3. The band shares, the Rayleigh-weighted integral and the photosynthetically
   active share are computed at source resolution when the spectrum is built and
   stored beside it; the consumer's integral over the resampled grid is compared
   against the stored value on every read, with a tolerance set by the
   flux-conserving rebin's own residual.
4. Every registered oracle carries a tolerance derived from independently
   bounded terms, the table of errors it must detect with their ratio to the
   tolerance, and a falsification statement written before the first value is
   compared (decisions 0025, 0026). An oracle whose tolerance exceeds the smallest
   error in its table is refused at registration.
5. An external rendering used once to validate a source is recorded with its
   provenance and is repeatable from the record; the standing check needs nothing
   outside the repository.

## Enforced by

- Decision 0006: a flux-density field has no `interpolate`; `coarsen` is the
  integral.
- The oracle registry (decision 0025) with its registration rule; the
  blackbody and photon-currency identities of decision 0026 as the analytic tier
  for any spectrum.
- Decision 0010: spectrum hash in the artifact key of every optical property.
- The mutation run (decision 0027): a mutation that rounds to a grid temperature
  or swaps the resampler must be caught by the stored-integral check.

## References

- Allard, F., Homeier, D., Freytag, B. (2012). *Models of very-low-mass stars,
  brown dwarfs and exoplanets.* Phil. Trans. R. Soc. A 370(1968), 2765-2777.
  DOI: 10.1098/rsta.2011.0269 (to confirm). The BT-Settl model grid the finding
  was measured on, and the class of source a declared spectrum is drawn from.
