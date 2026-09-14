+++
id = "REQ-ATM-011"
title = "Snow and ice albedo carry grain size, impurity load and solar zenith angle as predictors, per band under the declared spectrum, with no coefficient imported from a solar fit"
old_path = ["/home/cfutro/git/vesper/notes/audits/snow-albedo-grain.md", "/home/cfutro/git/vesper/notes/audits/snow-albedo-zenith.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Derived offline from spectral snow reflectance libraries and the predecessor's own
star-weighted albedo constants, on a planet with 32 degrees of obliquity under a
4965 K host.

- The model's snow albedo was a linear ramp in surface temperature between two
  endpoints, per band, blended toward a canopy value; the endpoints were a fixed
  mixture of clear ice, frost and three granular snows with the clear-ice
  fraction solved to hit a solar broadband target. They differed in ice
  fraction, not grain size, and the ramp between them was not an ageing law
  (`snow-albedo-grain.md`, "What the model ships"). Three grain-resolved spectra
  were compiled in and read nowhere.
- Weighted against the host, the same snow at the same grain size was roughly a
  tenth of an albedo darker than under the Sun, growing with grain size; band 1
  agreed to thousandths, band 2 carried all of it. A property of the light, not
  of the snow.
- The published quadratic-in-log-radius form transfers and its coefficients do
  not: any axis offset (illumination geometry, radius versus diameter) lands
  four times harder on the constant than on the slope, the constant was a tenth
  apart between library and model while the near-infrared slope agreed to a
  hundredth, and a dust darkening scales against the slope through `(r/r0)^s`.
  The zenith form read out of a third-party implementation was not the paper's:
  it squared the angle difference rather than the whole bracket and reversed the
  sign on the low-sun side (failure class 9, a form taken from an implementation
  of a citation).
- The direct-beam albedo of a semi-infinite scattering medium is the diffuse
  albedo raised to the escape function `K(mu0) = (3/7)(1 + 2 mu0)`, which has no
  coefficients, is per band by construction, is bounded by its own shape, and
  identifies a model with no zenith angle as quoting the `mu0 = 2/3` value
  (`snow-albedo-zenith.md`, "The form"). The zenith span of broadband snow albedo
  (0.19 on cold snow to 0.36 on warm) was half to all of the whole temperature
  ramp's range (0.375): a missing predictor worth as much as the one the model
  had. The host made the span 1.39 times the solar one. The sign flipped with
  latitude, so a global mean would have destroyed it; poleward of 60 degrees it
  was -8 W/m2 per unit snow area. The model's open-ocean Fresnel formula was the
  wrong form and the right location.
- Dust deposition reached neither snow nor soil; the offline flux was 2 to 20
  g/m2 per Earth year over the snow bands where the literature works with
  end-of-season loads of 1 to 5 g/m2 and finds 0.03 to 0.08 of albedo. A flux
  cannot be handed to a receiver that needs a load: the coupling needs a
  surface-layer reservoir with melt concentration and a grain size for the
  darkening to scale against (`absent-and-inherited-physics.md` finding 2).

## Why it carries

Decision 0018 specifies multilayer snow with prognostic grain size and impurity
mass and SNICAR-class snow optics; decision 0016 an N-band surface albedo per
class. Grain size, impurity and zenith angle are the three predictors a
temperature ramp cannot express, and every one is larger under a redder star,
which is the opposite of the usual transfer caution: an Earth effect that is
bigger here. The coefficient lesson generalises to every optical
parameterisation: take the form from the paper, fit or compute the coefficients
under the declared spectrum, and keep the axis conventions (radius, geometry,
band edges) as declared quantities beside them.

## What this system must do

1. Snow albedo per band is computed from ice optical constants over a grain-size
   axis (Mie spheres under the volume-to-area equivalence, or a tabulated
   two-stream solution), integrated against the declared spectrum's band edges;
   no coefficient fitted under a solar spectrum is imported (decisions 0016,
   0018).
2. Grain size is prognostic per snow layer through metamorphism, whose rate
   constants are `Bracketed` (mechanisms: isothermal metamorphism at the low end,
   strong-gradient metamorphism at the high end) with the snow population and
   temperature-gradient range they were fitted on (Flanner and Zender 2006) and whose vapour-diffusion
   term reads the condensable's diffusivity in the declared mixture from
   REQ-ATM-017; impurity mass per layer is a state fed by the aerosol deposition
   flux with melt concentration and loss with the pack (decisions 0018, 0022), and
   the darkening scales with grain size as the source's collapsed predictor does,
   with its validity range declared.
3. The radiation reads the snow-covered fraction and the blended diffuse albedo
   from the land column and applies the direct-beam escape function per band to
   the direct fraction only, with the diffuse fraction unmodified; the same
   treatment applies to sea ice and glacier ice.
4. Axis conventions are declared quantities: effective radius (not diameter),
   the reference illumination geometry of any tabulated value, and the band
   edges of any comparison.
5. Oracles: pure-snow spectral albedo against the published two-stream results
   under the solar spectrum on the Earth instance; monotonicity in grain size in
   every band; the escape-function normalisation identity (decision 0026).

## Enforced by

- Decisions 0016, 0018, 0022; REQ-ATM-002 (per-band operations only).
- Decision 0009: the `Exchange` refuses a flux offered to a receiver whose
  semantics is a load.
- The oracle registry rows above and the mutation run (decision 0027): a
  broadband factor or a temperature-only ramp must be caught.

## References

- Dang, C., Brandt, R. E., Warren, S. G. (2015). *Parameterizations for narrowband
  and broadband albedo of pure snow and snow containing mineral dust and black
  carbon.* J. Geophys. Res. Atmos. 120(11), 5446-5468.
  DOI: 10.1002/2014JD022646. Eqs. (5) and (7), Tables 1 and 3.
- Wiscombe, W. J., Warren, S. G. (1980). *A Model for the Spectral Albedo of
  Snow. I: Pure Snow.* J. Atmos. Sci. 37(12), 2712-2733.
  DOI: 10.1175/1520-0469(1980)037<2712:AMFTSA>2.0.CO;2 (to confirm).
- Warren, S. G., Wiscombe, W. J. (1980). *A Model for the Spectral Albedo of
  Snow. II: Snow Containing Atmospheric Aerosols.* J. Atmos. Sci. 37(12),
  2734-2745. DOI: 10.1175/1520-0469(1980)037<2734:AMFTSA>2.0.CO;2 (to confirm).
- Warren, S. G., Brandt, R. E. (2008). *Optical constants of ice from the
  ultraviolet to the microwave: A revised compilation.* J. Geophys. Res. 113,
  D14220. DOI: 10.1029/2007JD009744 (to confirm).
- Flanner, M. G., Zender, C. S. (2006). *Linking snowpack microphysics and albedo
  evolution.* J. Geophys. Res. 111, D12208. DOI: 10.1029/2005JD006834. The
  grain-growth rate tables the metamorphism bracket is declared over.
- Flanner, M. G., Zender, C. S., Randerson, J. T., Rasch, P. J. (2007).
  *Present-day climate forcing and response from black carbon in snow.*
  J. Geophys. Res. 112, D11202. DOI: 10.1029/2006JD008003 (to confirm). The
  SNICAR structure decision 0018 names.
- Marshall, S. E. (1986). *Parameterization of Snow Albedo for Climate Models.*
  In Kukla, G., Barry, R. G., Hecht, A. and Wiesnet, D. (eds), Snow Watch '85,
  Glaciological Data Report GD-18, World Data Center A for Glaciology, 215-223.
  No DOI; held as `marshall1986-parameterization-snow-albedo-climate-models.pdf`.
  The zenith-angle effective-radius form Dang et al. (2015) Eq. (5) follows; the
  same parameterisation appears in her 1989 thesis (NCAR Cooperative Thesis,
  University of Colorado), which is not held because this proceedings paper and
  Dang et al. carry everything the requirement takes from it.

## Amendments

- 2026-09-08: dispositioned the metamorphism rate constants as Bracketed and routed vapour diffusivity through REQ-ATM-017 (audit row 22), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: both ends named for the metamorphism rate constants, from notes/findings/2026-09-08-implicit-earth-audit.md
