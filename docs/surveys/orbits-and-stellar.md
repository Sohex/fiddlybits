+++
epic = "fiddlybits-bon"
title = "Orbits and stellar: JuliaAstro, starry, Korg.jl, vplanet"
trees = [
  "/home/cfutro/git/JuliaAstro (64 repositories)",
  "/home/cfutro/git/starry",
  "/home/cfutro/git/Korg.jl",
  "/home/cfutro/git/vplanet",
]
status = "filed"
date = 2026-09-09
+++

## What this group is, and what to take away

JuliaAstro is an umbrella of 64 repositories. All but three are observational-astronomy
tooling read and dismissed in one clause: FITS and other file formats, image reduction
and viewing, radio interferometry, plate-solving and coordinate-frame conversion,
photometry and periodogram search, X-ray and UV/optical/IR spectral fitting against
instrument data, and the organisation's own site and workshop material. None of it
generates a spectrum, solves an orbit to rounding, or computes an occultation; it reads
what a telescope already produced. `starry` and `Korg.jl` are single repositories read
on their own merits; `vplanet` is the architectural cousin named directly in the brief.

Three findings matter most:

1. **Decision 0008's Kepler requirement already has an answer in the ecosystem, and it
   is two files inside a package that is otherwise correctly dismissed.**
   `AstroLib.jl/src/kepler_solver.jl` implements Markley (1995): a closed-form,
   non-iterative solve of Kepler's equation for any eccentricity in `[0, 1]`, four
   transcendental evaluations, no series truncation, no calendar dependency, machine
   precision by the author's own claim. It is exactly the shape decision 0008 asks for
   and exactly the thing `Insolation.jl` (already surveyed, `docs/imports/insolation-jl.md`)
   was rejected for not having. The rest of `AstroLib.jl` is Julian-date-keyed ephemeris
   utilities (`helio_jd`, `precess`, `bprecess`) and is dismissed on the same grounds as
   every ephemeris package in this group.
2. **The two packages that do closed-form transit and eclipse geometry each fall short
   of this project's generality in a different way.** `Transits.jl`'s
   `PolynomialLimbDark` implements Agol, Luger and Foreman-Mackey (2020) exactly, but
   its `Mn`/`Nn` recursion buffers are mutated in place inside the struct
   (`downwardM!`/`upwardM!` in `src/polynomial/poly.jl`), so a single instance is not
   safely shared across concurrent evaluations; and `SecondaryLimbDark`
   (`src/secondary.jl`) is hard-wired to exactly two bodies (a primary and one flipped
   secondary), with no path to a moon occulting a star for a planet. `starry` is more
   general in principle — spherical-harmonic surface maps, a reflected-light
   (Oren-Nayar) term, and a `System`/Kepler class that sums pairwise occultations over
   however many bodies are declared — but it is Python and C++, so it is read as an
   algorithm, never a dependency.
3. **`Korg.jl` and `vplanet`'s `STELLAR` module are complementary in exactly the gap
   decision 0004 has.** Korg synthesizes a spectrum from `(Teff, logg, [M/H])` against
   an interpolated MARCS model atmosphere; it has no stellar-evolution step and cannot
   go from `(mass, age, metallicity)` to those inputs on its own. `vplanet`'s `STELLAR`
   module is a grid-interpolated evolutionary track (Baraffe et al.) that does exactly
   that conversion, stated generally in mass and age rather than fitted to one star, for
   the low end of the main sequence. Neither reaches from decision 0004's foundational
   parameters to a spectrum by itself; a `Sourced` stellar model for this project would
   need to compose something shaped like the first with something shaped like the
   second. Both are read as algorithms; neither is a dependency (Korg because its shape
   is a full LTE synthesis pipeline for stellar spectroscopy, not a k-table generator;
   vplanet because it is C, and the module in question is one physics package inside a
   monolithic ODE-integrator binary with no boundary to import across).

## Commits read

Each JuliaAstro repository is its own git checkout under `/home/cfutro/git/JuliaAstro/`;
this record was built by reading each at the commit its working tree carried on
2026-09-09. The six repositories with a closer look below, by name and short hash:

| repo | commit |
| --- | --- |
| JuliaAstro/AstroLib.jl | 288bcfd |
| JuliaAstro/Orbits.jl | 978b378 |
| JuliaAstro/Transits.jl | 2d6ce2a |
| starry | b72dff08 |
| Korg.jl | 431412e4 |
| vplanet | dd55da7e |

The remaining 61 JuliaAstro repositories, by name and short hash, for the record: ASDF2.jl
fb081ea, ASDF.jl c379c1f, Astroalign.jl 11bbe0c, AstroAngles.jl fb61293, AstroImages.jl
7e218c5, AstroImageView.jl 56c72b6, Astrometry.jl b578002, AstroTime.jl 6157af3, AURIS.jl
666dda7, BackgroundMeshes.jl 04791a3, BoxLeastSquares.jl c90abc0, CALCEPHBuilder b55b795,
CALCEPH.jl c6305e6, Casacore.jl 905b0c5, CCDReduction.jl 18660b9, CFITSIOBuilder eb691bc,
CFITSIO.jl 1b9f641, Cosmology.jl 5f0d99c, DustExtinction.jl dbff4e0, EarthOrientation.jl
30b8017, EphemerisSources.jl 8a711ac, ERFABuilder af9f8fe, ERFA.jl b5e4d3f, fireplace
d159d16, FITSFiles.jl 870e4ee, FITSIO.jl da70a0f, FITSWCS.jl 8c5db57,
GeneralAstrodynamics.jl 301718ca, Healpix.jl 40b233e, JuliaAstro.github.io 76286d27,
LACosmic.jl 84b7e70, learn-JuliaAstro bf767ed, LombScargle.jl c5ac924, MeasurementSets.jl
47d6c64, PhotometricFilters.jl c6e3765, Photometry.jl 6386fc9, Planck.jl 5f80499,
PSFModels.jl 7586f52, PulsarSearch.jl 05ea453, PythonCallTest.jl 1551557, Radix.jl
9e9be61, Reproject.jl 45c87ea, SAOImageDS9.jl 4981a53, ScienceDataModel.jl 027c063,
SDMTables.jl 096f129, SkyCoords.jl 60bb231, SOFA.jl 4162d80, SolarPosition.jl a973fe5,
SpectralFitting.jl ea6bb30, SpectrumBase.jl e3b22ad, SPICEBuilder 6d8f20b, SPICE.jl
fe40c85, UnitfulAstro.jl f314b98, UVOIRSpectra.jl dbe8d82, VOTables.jl fe4c885, WCS.jl
83f2310, WCSLIBBuilder 911482e, WCSLIB.jl df1cdf4, workshop 6672150, XPA.jl c1d7d12,
XraySpectra.jl c054849.

## Table

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| ASDF2.jl | superseded pure-Julia ASDF container reader, folded into ASDF.jl | - | not pertinent | - |
| ASDF.jl | Advanced Scientific Data Format container reader/writer | - | not pertinent | - |
| Astroalign.jl | image registration/alignment for observational frames | - | not pertinent | - |
| AstroAngles.jl | sexagesimal angle string parsing and formatting | - | not pertinent | - |
| AstroImages.jl | FITS image display and plotting | - | not pertinent | - |
| AstroImageView.jl | unmaintained FITS image viewer | - | not pertinent | - |
| AstroLib.jl | general astronomical-utility grab-bag; almost entirely Julian-date-keyed ephemeris helpers, except two files | 0008 | algorithmic reference | now |
| Astrometry.jl | astrometric plate-solving (fitting a WCS to a star field) | - | not pertinent | - |
| AstroTime.jl | calendar and leap-second time-scale conversion (UTC/TAI/TT) | - | not pertinent, calendar-tied | - |
| AURIS.jl | radio-interferometry visibility-processing utilities | - | not pertinent | - |
| BackgroundMeshes.jl | image background estimation for photometry | - | not pertinent | - |
| BoxLeastSquares.jl | box-least-squares periodogram for transit detection in survey photometry | - | not pertinent | - |
| CALCEPHBuilder | binary-artifact builder for CALCEPH.jl | - | not pertinent | - |
| CALCEPH.jl | JPL/INPOP planetary ephemeris file reader, keyed to Julian dates | - | not pertinent, calendar-tied | - |
| Casacore.jl | radio-interferometry measurement-set I/O | - | not pertinent | - |
| CCDReduction.jl | CCD image reduction (bias/dark/flat) | - | not pertinent | - |
| CFITSIOBuilder | deprecated binary-artifact builder | - | not pertinent | - |
| CFITSIO.jl | FITS file I/O, C library wrapper | - | not pertinent | - |
| Cosmology.jl | cosmological distance and expansion-history calculators | - | not pertinent, wrong physics domain | - |
| DustExtinction.jl | interstellar dust extinction curves for observational photometry | - | not pertinent | - |
| EarthOrientation.jl | IERS Earth-orientation parameter tables, keyed to MJD | - | not pertinent, calendar-tied | - |
| EphemerisSources.jl | registry and loader for ephemeris data sources (JPL DE, INPOP), keyed to calendar epochs | - | not pertinent, calendar-tied | - |
| ERFABuilder | binary-artifact builder | - | not pertinent | - |
| ERFA.jl | archived wrapper of the IAU SOFA algorithms (precession, nutation, calendar time scales) | - | not pertinent, calendar-tied | - |
| fireplace | community discussion forum, no code | - | not pertinent | - |
| FITSFiles.jl | low-level FITS reader | - | not pertinent | - |
| FITSIO.jl | FITS file I/O | - | not pertinent | - |
| FITSWCS.jl | pure-Julia FITS World Coordinate System transforms | - | not pertinent | - |
| GeneralAstrodynamics.jl | spacecraft mission-design toolkit (Lambert, patched conics, Hohmann transfers); its `kepler()` solves the universal-variable Kepler problem by iterative Newton, not the closed form AstroLib.jl already carries | 0008 | not pertinent (checked; see AstroLib.jl) | - |
| Healpix.jl | equal-area full-sky pixelization for CMB and imaging maps | - | not pertinent to this group | - |
| JuliaAstro.github.io | the organisation's documentation website | - | not pertinent | - |
| LACosmic.jl | cosmic-ray removal from CCD images | - | not pertinent | - |
| learn-JuliaAstro | workshop teaching notebooks | - | not pertinent | - |
| LombScargle.jl | periodogram for irregularly sampled photometric/RV time series | - | not pertinent | - |
| MeasurementSets.jl | radio-interferometry measurement-set format | - | not pertinent | - |
| Orbits.jl | Keplerian-orbit position/geometry layer used by Transits.jl; rides on AstroLib.jl's Kepler solver | 0008, 0032 | algorithmic reference | now |
| PhotometricFilters.jl | photometric bandpass filter curve library (its "KEPLER" entry is the space telescope, not the equation) | - | not pertinent | - |
| Photometry.jl | aperture and PSF photometry on images | - | not pertinent | - |
| Planck.jl | archived; its blackbody function is folded into Korg.jl | - | not pertinent standalone | - |
| PSFModels.jl | point-spread-function models for image fitting | - | not pertinent | - |
| PulsarSearch.jl | pulsar search and folding pipeline | - | not pertinent | - |
| PythonCallTest.jl | empty test scaffold | - | not pertinent | - |
| Radix.jl | X-ray photo-ionized-plasma spectral simulator (XSTAR port) | - | not pertinent, wrong physics regime | - |
| Reproject.jl | image reprojection between WCS frames | - | not pertinent | - |
| SAOImageDS9.jl | interface to the DS9 image viewer | - | not pertinent | - |
| ScienceDataModel.jl | Science Data Model file-format I/O | - | not pertinent | - |
| SDMTables.jl | Science Data Model table types | - | not pertinent | - |
| SkyCoords.jl | celestial coordinate-frame conversions (ICRS/Galactic/FK5) | - | not pertinent | - |
| SOFA.jl | IAU Standards of Fundamental Astronomy wrapper (precession, nutation, calendar time scales), successor to ERFA.jl | - | not pertinent, calendar-tied | - |
| SolarPosition.jl | a family of terrestrial solar-position algorithms (NOAA, SPA, Michalsky, PSA, USNO), every entry point keyed to `DateTime` | 0008 | not pertinent, calendar-tied (same failure mode as Insolation.jl, see docs/imports/insolation-jl.md) | - |
| SpectralFitting.jl | X-ray spectral model fitting against observed data | - | not pertinent | - |
| SpectrumBase.jl | abstract interface for observational spectra | - | not pertinent | - |
| SPICEBuilder | binary-artifact builder | - | not pertinent | - |
| SPICE.jl | NASA NAIF SPICE toolkit wrapper (ephemeris kernels tied to calendar epochs) | - | not pertinent, calendar-tied | - |
| Transits.jl | closed-form analytic transit/eclipse flux via Green's theorem and elliptic integrals (Agol, Luger, Foreman-Mackey 2020) | 0032 | algorithmic reference | M4 |
| UnitfulAstro.jl | astronomical unit definitions for Unitful.jl | - | not pertinent to this group (a units package, not orbit or spectrum physics) | - |
| UVOIRSpectra.jl | JWST extracted-spectrum loader | - | not pertinent | - |
| VOTables.jl | archived VOTable format I/O | - | not pertinent | - |
| WCS.jl | FITS World Coordinate System wrapper | - | not pertinent | - |
| WCSLIBBuilder | binary-artifact builder | - | not pertinent | - |
| WCSLIB.jl | deprecated WCS wrapper | - | not pertinent | - |
| workshop | AAS meeting workshop teaching materials | - | not pertinent | - |
| XPA.jl | XPA messaging client (DS9 IPC) | - | not pertinent | - |
| XraySpectra.jl | X-ray spectral response and PHA I/O | - | not pertinent | - |
| starry | Python/C++ analytic occultation, phase-curve and reflected-light package (Luger et al. 2019) | 0032 | algorithmic reference | M4 |
| Korg.jl | pure-Julia LTE stellar spectral synthesis from model atmospheres and line lists | 0004, 0016 | algorithmic reference | M4 |
| vplanet | C simulator of tidal, rotational, stellar and atmospheric-escape evolution of planetary systems (EQTIDE, THERMINT, ATMESC, STELLAR named modules) | 0004, 0032 | algorithmic reference | see per-module timing below |

64 JuliaAstro repositories plus starry, Korg.jl and vplanet: 67 trees surveyed. 61 not
pertinent, 6 algorithmic reference, 0 import review, 0 oracle arm.

## Closer looks

### AstroLib.jl -- `src/kepler_solver.jl`, `src/trueanom.jl`

Bears on decision 0008: "the true anomaly is obtained by solving Kepler's equation to
rounding for any eccentricity below one, never by a series truncated in eccentricity."
`kepler_solver(M, e)` throws `DomainError` outside `e in [0, 1]`, reduces `M` into
`[-pi, pi]`, and then follows Markley (1995) *Celestial Mechanics and Dynamical
Astronomy* 63: a sequence of closed-form algebraic and trigonometric steps (no loop, no
convergence tolerance) that the paper and the docstring both claim is accurate to
machine precision over the whole elliptic range. `trueanom(E, e)` is the one-line
half-angle conversion from eccentric to true anomaly. Both are scalar, type-generic
(`promote_type`), and contain no allocation, no `Dates` import and no array indexing —
nothing stops them running inside a GPU kernel per column per radiation step. The
`DomainError` on out-of-range `e` would need to become the profile's own guard
(`NotEvaluable`, per decision 0008's vocabulary) rather than a thrown exception if
called from device code.

The question the closer look must answer: does Markley's method hold to rounding (not
merely "small error") at the eccentricities decision 0034's M0 synthetic instances
declare (`SyntheticNonEarth()` names "high eccentricity" explicitly), checked against a
Newton iteration run to convergence as the reference, and does it stay closed-form
(no branch divergence) when it is the body of a `KernelAbstractions` kernel rather than
a scalar call. The rest of the package — `helio_jd`, `precess`, `bprecess`, `helio_rv`,
everything in `common.jl` and `utils.jl` outside these two files — takes a `jd::Real`
Julian date or a `DateTime` and is dismissed with every other ephemeris package here.

### Orbits.jl -- `src/keplerian/`

Bears on decision 0008 (the position/anomaly layer the clock needs) and decision 0032
(it is what `Transits.jl` calls for orbital geometry). `KeplerianOrbit`
(`src/keplerian/constructor.jl`) is a typed struct built from any of several
observationally-natural parameterisations (period or semi-major axis; inclination or
impact parameter; stellar density, mass or radius) with `AstroLib.trueanom` and
`AstroLib.kepler_solver` doing the actual anomaly solve (`src/keplerian/keplerian.jl`,
`compute_true_anomaly`). `_position` rotates the orbital-plane position into the
reference frame with `Rotations.RotZXZ(Omega, -incl, omega)` and returns it as an
`SVector`, so the shape (static, allocation-free, GPU-friendly) is right.

The question the closer look must answer, and the reason this is a caution rather than
an unqualified recommendation: the constructor's own docstring states "if no stellar
parameters are given, the central body is assumed to be the Sun" — a silent default
across exactly the boundary decision 0004 forbids one at ("no silent default across a
component boundary; check at the point of reading"). Whether that default is reachable
from this project's constructor call sites (it would not be, if every field decision
0004 requires is always passed) is the thing to confirm before treating this as a safe
shape to imitate; it is not a reason to use the package, only to read its position
functions as a worked example of the rotation and the static-array return type.

### Transits.jl -- `src/polynomial/`, `src/secondary.jl`

Bears on decision 0032: "eclipses and transits by moons or companion stars... are pure
functions of the system struct and the clock," evaluated "per column per step."
`PolynomialLimbDark` (`src/polynomial/poly.jl`) implements Agol, Luger and
Foreman-Mackey (2020) directly, with the elliptic-integral pieces in
`src/polynomial/elliptic.jl`: for an arbitrary-order polynomial limb-darkening law it
returns the occulted flux fraction from the impact parameter and radius ratio using
closed-form boundary integrals, falling back to numerical series only in named
degenerate cases (`series.jl`). It handles one occulter over one limb-darkened disk;
`SecondaryLimbDark` (`src/secondary.jl`) extends this to a primary and a secondary
eclipse by literally flipping the orbit (`Orbits.flip`) and re-running the primary
solver with swapped bodies — it is arithmetic for exactly two bodies, with no
generalisation to a third (a moon occulting a star for a planet is not representable
without composing instances by hand, and nothing in the package tracks which pairs of a
larger system are even in mutual view).

The question the closer look must answer: `PolynomialLimbDark`'s `n_max`-length `Mn`,
`Nn` buffer arrays live inside the struct and are mutated in place by
`downwardM!`/`upwardM!` on every `compute` call (`poly.jl`, lines around 170-200) —
whether that in-place recursion can be restructured to stack-allocated, per-call
buffers (a `StaticArrays` `MVector` sized to the profile's declared limb-darkening
order) without losing the closed-form structure, since a single shared mutable instance
cannot be reused concurrently across cells in a `KernelAbstractions` launch as written.
A second, smaller question: whether the differentiability this algorithm is known for
(`ChainRulesCore` `frule`/`rrule` are defined in `poly-grads.jl`/`quad-grads.jl`) is
needed here at all, since decision 0032 does not currently ask for a gradient of the
eclipse fraction.

### starry -- `starry/_core/`, `starry/kepler.py`

Bears on decision 0032, as the more general treatment of the same problem. `starry` is
Python with a C++ (`pybind11`/Eigen) numerical core, so it is read only, never a
dependency; it is included because it generalises past what `Transits.jl` does in two
ways this project needs. First, its surface maps are spherical-harmonic expansions
rather than radially symmetric limb-darkening polynomials, and it carries a reflected-
light term (`starry/_core/ops/lib/include/reflected/oren_nayar.py`) — the moon-
reflecting-starlight case decision 0032 names explicitly. Second, `starry/kepler.py`
defines a `System` of a primary and arbitrary secondaries, each with its own orbit, and
sums flux over the system by evaluating pairwise occultations (each still a closed-form
Green's-theorem solve) rather than hard-wiring a two-body relationship the way
`Transits.jl`'s `SecondaryLimbDark` does.

The question a closer look at the algorithm (not the code, which is not portable)
should answer: does the pairwise-sum construction extend correctly to the specific case
this project needs — a moon occulting a star as seen from a planet, i.e., the observer
is not one of the two occulting bodies — or is `starry`'s pairwise sum only proven for
occultations as seen from a fixed external observer (the transiting-planet use case it
was built for), in which case the geometry, not just the code, would need rederiving
for an on-planet observer before any of this is usable as a reference for the
column-per-step evaluation decision 0032 asks for.

### Korg.jl -- `src/line_absorption.jl`, `src/statmech.jl`, `src/ContinuumAbsorption/`, `src/linelist.jl`, `src/atmosphere.jl`

Bears on decision 0016 (the offline k-table build reads line lists and computes
continuous opacities) and decision 0004 (the stellar spectrum and its domain fence).
Korg reads VALD, Kurucz (short/long, air/vacuum), MOOG, MOOG-air and Turbospectrum
linelist formats natively (`read_linelist`, `src/linelist.jl`), and ExoMol separately
via `load_ExoMol_linelist` (marked experimental) — ExoMol is one of the two sources
decision 0016 names (Tennyson et al. 2016); HITRAN/HITEMP, the primary sources decision
0016 needs for molecular absorbers, are not among Korg's readers, because Korg's
linelists are atomic/stellar-line formats, a different community and a different line
shape convention than HITRAN's. `voigt_hjerting(alpha, v)` (`src/line_absorption.jl`)
is a scalar Voigt-Hjerting function taking the reduced parameters directly, with no
stellar-atmosphere state threaded through it — usable standing alone. Partition
functions (`src/statmech.jl`) are read as a `Dict{Species, Function}` of tabulated
`log(T)` curves (Barklem-derived data) and used inside `saha_ion_weights`, again a
scalar evaluation independent of the rest of the synthesis pipeline. Continuum opacity
(`ContinuumAbsorption/absorption_H.jl`, `absorption_ff_positive_ion.jl`,
`absorption_H2_CIA.jl`, `scattering.jl`) covers H- bound-free/free-free, Rayleigh
scattering and collision-induced absorption, the same physics categories decision 0016
prices, evaluated per (temperature, density) point.

What Korg cannot do without something upstream of it: `interpolate_marcs(Teff, logg,
...)` (`src/atmosphere.jl`) interpolates a model atmosphere from the SDSS-MARCS grid, a
separate "cool dwarf" grid resampled for `Teff <= 4000 K, logg >= 3.5`, and a
metal-poor extension, each with its own declared bounds and a thrown
`AtmosphereInterpolationError` outside them — the domain-fenced `Sourced`-law shape
decision 0004 wants, but the grid's own axes are `(Teff, logg, [M/H])`, not `(mass,
age, metallicity)`. Korg has no evolutionary step from mass and age to `Teff` and
`logg`; every abundance is expressed as a solar-relative offset
(`format_A_X`, default `Korg.bergemann_2025_solar_abundances`) scaled by a single
metallicity and alpha-enhancement knob, with individual-element overrides layered on
top — workable for an arbitrary declared bulk composition in principle, but the
default linelist, default solar-abundance pattern and the MARCS grid's own construction
are all built around FGK-type, near-solar-composition photospheres; the "cool dwarf"
extension is the one place the grid reaches toward M dwarfs, and nothing in the package
reaches toward hotter or more exotic declared spectra.

The question the closer look must answer: whether the MARCS grid's declared domain
(its `Teff`/`logg`/`[M/H]` bounds and the M-dwarf extension's own limits) is wide
enough to cover the stellar parameter space decision 0034's `SyntheticSynchronous()`
instance implies (an M-dwarf spectrum), and, if a stellar-evolution model is later
carried per decision 0004, whether its own `(Teff, logg)` outputs land inside that
domain — because Korg's refusal-outside-the-hull behaviour is exactly the shape decision
0004 wants, but only if the hull the run's declared stars fall into is the hull Korg was
built on.

### vplanet -- `src/eqtide.c`, `src/stellar.c`, `src/atmesc.c`, `src/thermint.c`

Bears on decision 0032's declared absences (tides, rotation-state evolution, obliquity
stability) and decision 0004's `Sourced` stellar model and the lithosphere block.
vplanet is C, and its four physics modules are compiled into one ODE-integrator binary
with no library boundary to import across; every closer look here is of the
formulation, never the code.

`EQTIDE` (`src/eqtide.c`) carries both the Constant-Phase-Lag and Constant-Time-Lag
tidal models named in decision 0032's references (Murray and Dermott 1999): explicit
functions for `da/dt`, `de/dt`, `d(obliquity)/dt` and the rotation-rate equilibrium
under each model (`fdCPLDsemiDt`, `fdCPLDeccDt`, `fdCPLDoblDt`, `fdCPLEqRotRate` and
their CTL counterparts), each stated in the orbital elements and the tidal `Q`/lag
parameters, not fitted to a particular planet-star pair. This is nearly the exact shape
of the interface decision 0032 asks the tides component to declare (reads: orbital
elements, spin state; writes: their rates; a ledger for the dissipated energy).

`STELLAR` (`src/stellar.c`) is a Baraffe-grid-interpolated evolutionary track:
`fdLuminosityFunctionBaraffe(dAge, dMass)`, and matching functions for radius,
gyration radius and temperature, plus a family of XUV saturation-fraction and
saturation-time models (`ReadSatXUVFrac`, `ReadXUVBeta`, the "Engle" early/mid-late
fits) for high-energy flux history. General in its two arguments (mass, age); fitted in
its data (the Baraffe grid, whose own coverage is toward the low-mass end of the main
sequence).

`ATMESC` (`src/atmesc.c`) carries energy-limited and diffusion-limited (water) escape
regimes and a Roche-lobe radius (`WriteRocheRadius`), each a function of the stellar
XUV flux, the planet's gravity and its atmospheric composition rather than a fit to one
planet.

`THERMINT` (`src/thermint.c`) is a mantle-convection thermal-evolution model:
Arrhenius mantle viscosity as a function of temperature and melt fraction
(`fdViscUMan`, `fdDynamicViscosity`), core-mantle boundary heat flow and core cooling
(`fdTDotCore`), stated in terms decision 0004's lithosphere block already carries
(mantle potential temperature, thermal expansivity, density) rather than as an
Earth-specific rate.

The question a closer look at each module must answer, since none of these four is
scheduled on decision 0034's milestone list yet:

- `EQTIDE`: does the CPL/CTL pair, evaluated on the declared eccentricity and
  obliquity of a synthetic high-eccentricity instance, reproduce the sign and rough
  magnitude of the circularisation and spin-down timescales published for a comparable
  real system (an oracle-arm question, not just a shape question), before this
  project's own tides component is drafted.
- `STELLAR`: whether the Baraffe grid's declared mass-age domain (and its lack of a
  metallicity axis) is wide enough to serve as the low-mass wing of the `Sourced`
  stellar model decision 0004 wants, or only ever a comparison point for it.
- `ATMESC`: whether decision 0002's scope fence admits an escape component at all, and
  if it does, whether the energy-limited/diffusion-limited regime split is the right
  first cut or an Earth-thermosphere-shaped simplification.
- `THERMINT`: whether the Arrhenius viscosity law's fitted constants are available in a
  form decision 0004's `Bracketed` lithosphere-block dispositions could cite as one end
  of a bracket, once a mechanism (rather than a declared initial condition) is wanted
  for mantle potential temperature.

## Recommended rows, with timing

1. Read AstroLib.jl's `kepler_solver.jl` and `trueanom.jl` against decision 0008's
   Kepler oracle (verdict: algorithmic reference) -- **now**, because decision 0008 is
   accepted and the M0 gate's `system.*` oracle section needs exactly this solve
   validated to rounding before the clock module can be built.
2. Read Orbits.jl's `KeplerianOrbit` position layer for its rotation convention and its
   silent solar-default (verdict: algorithmic reference, with a caution) -- **now**,
   alongside row 1, as the worked example for the clock module's position functions at
   M0.
3. Read Transits.jl's `poly.jl`/`elliptic.jl` solver and its in-place `Mn`/`Nn` buffers
   against decision 0032's per-column eclipse/transit fraction, and whether a
   stack-allocated restructure survives (verdict: algorithmic reference) -- **M4**, when
   the radiation pipeline's per-source, per-column geometry is built.
4. Read starry's pairwise multi-body occultation sum and reflected-light term, and
   settle whether its geometry is proven for an on-planet observer rather than only an
   external one (verdict: algorithmic reference) -- **M4**, alongside row 3.
5. Read Korg.jl's Voigt-Hjerting function, partition-function tables, continuum-opacity
   terms and ExoMol loader against decision 0016's offline k-table build, and check the
   MARCS grid's domain against the M-dwarf synthetic instance (verdict: algorithmic
   reference) -- **M4**, when the radiation pipeline's line-by-line build step is
   written.
6. Read vplanet's `STELLAR` module's Baraffe-grid tracks against decision 0004's
   `Sourced` stellar-model requirement, as the low-mass-end candidate that would need
   to sit upstream of something Korg-shaped (verdict: algorithmic reference) -- **M4**,
   timed with row 5 since both feed the same declared spectrum.
7. Read vplanet's `EQTIDE` CPL/CTL formulation against decision 0032's tidal
   declared-absence interface (verdict: algorithmic reference) -- **not yet milestoned**;
   read when the tides/rotation-evolution component is planned, which decision 0034's
   milestone list does not yet name.
8. Read vplanet's `ATMESC` escape regimes as a candidate shape for an atmospheric-escape
   absence interface, contingent on decision 0002's scope fence (verdict: algorithmic
   reference) -- **not yet milestoned**.
9. Read vplanet's `THERMINT` mantle-viscosity and core-cooling formulation against
   decision 0004's lithosphere block (verdict: algorithmic reference) -- **M1** at the
   earliest, since that is where the lithosphere block is first consumed (terrain
   subsidence and basal heat flux), though the block itself stays a declared initial
   condition rather than gaining a thermal-evolution mechanism at M1.
