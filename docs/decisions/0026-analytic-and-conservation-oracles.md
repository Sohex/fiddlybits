+++
id = "0026"
title = "Analytic and conservation oracles, with tolerances derived rather than chosen"
status = "accepted"
date = 2026-09-08
+++

## Decision

Every operator, solver and coupling exchange has at least one oracle with a right
answer. For each oracle the record states what "wrong" looks like, so a test that
cannot fail is not admitted (failure class: a check that cannot fail is not a check).

### The manufactured-solution rule

For every partial differential operator (horizontal dynamics, vertical advection and
diffusion, soil heat, unsaturated soil water, snow enthalpy, groundwater, hillslope
diffusion, stream-power incision, ocean tracer advection), a smooth manufactured
solution is chosen, its source term generated symbolically at test time or committed
with the generating script, and the error norm measured at three or more
resolutions. The test asserts the *observed convergence order* against the designed
order. Wrong: observed order below the designed order by more than a declared margin
at the two finest resolutions, or an error that does not decrease. A first-order
result on a second-order scheme is a sign error, an off-by-one in a stencil, or a
boundary that is not what the scheme claims. For every operator whose coefficient
carries gravity or a water property (stream-power incision, groundwater, hillslope
diffusion, shallow ice), the manufactured source term is generated with `g`, `rho_w`
and `mu` as symbols and the convergence order is asserted at two points of the
gravity sweep, so a coefficient that silently absorbed a planet's gravity fails the
order test rather than passing at one value. The hydrostatic pressure identity (the
column integral of `rho g dz` from the modelled density and the declared gravity
reproduces the pressure every consumer reads) is a per-commit identity run at a
declared spread of gravity, because it is the one place gravity enters the seawater
thermodynamics.

### Dynamical-core cases, run across a parameter spread

The standard cases are parameterised by radius, rotation rate, gravity, the gas
constants of the mixture (REQ-ATM-017), surface pressure and the case's own thermal
profile and relaxation rates, all owned by the case's forcing struct in SI units with
times in seconds; each is run at the published case's own values (published answer)
and at a declared spread of other parameters (the analytic parts stay analytic; the
rest become REPORT and a regression reference). The core reads none of the case's
literals; a case literal reaching the core is a named mutation. Every elapsed time
and every forcing timescale in these cases is stated in seconds: on the arm at the
published case's values the published "day" is written as its seconds and the
published bar applies; on the spread arms the elapsed times and the relaxation rates
scale with the rotation period by a rule the registry entry states, and the verdict
is REPORT. No registry statistic is stated in days.

| case | what is exact | wrong means |
|---|---|---|
| advection of a cosine bell | the field after one revolution | norms above the published band for the scheme class; shape distortion |
| steady geostrophic flow | the state at all times | any error growth: the balance, the Coriolis term or the metric terms are wrong |
| flow over an isolated mountain; Rossby-Haurwitz wave | high-resolution reference solutions | norms outside the published band |
| baroclinic steady state | the initial state | surface-pressure error growing beyond the published bound: hydrostatic balance or the vertical coordinate is wrong |
| baroclinic wave | published multi-model | wave breaks at the wrong elapsed time; minimum surface pressure outside the published range |
| idealised radiative-convective forcing (Held-Suarez) | the published climatology | jet strength or latitude outside the published spread; angular momentum not conserved within the ledger bound |
| reduced-radius small-planet cases | published norms | norms exceeded |
| moist baroclinic wave | published | as above, and total water not conserved |
| the same idealised forcing at fractional and multiple rotation rates | published scaling of cell edge and jet count | outside the published scaling |

Two items specific to the triangle C-grid are named acceptance items: the spurious
checkerboard divergence mode must be demonstrably suppressed, and the discretisation
must pass the Hollingsworth check for vector-invariant momentum forms. A graded
refinement region must show no reflected-wave growth.

### Column and process solvers

| solver | analytic reference | wrong means |
|---|---|---|
| unsaturated soil water | early-time infiltration proportional to the square root of time (sorptivity); transient exponential-conductivity solution; steady evaporation from a water table; the late-time gravity-driven limit (infiltration rate tending to `K_s = k rho_w g / mu`) across a gravity sweep, because the sorptivity law is the gravity-free limit of Richards and cannot see a wrong or missing `rho_w g` in the head conversion | departure from the square-root law on the finest grid; mass not conserved (the mixed-form discretisation is exact to roundoff); late-time rate not at `K_s`, or not scaling linearly with g |
| soil heat, snow, sea-ice growth | Stefan problem: thickness proportional to the square root of time; Neumann solution with phase change; periodic damping depth and phase lag at the system's solar day and orbital period, run at two declared rotation periods and two orbital periods | growth exponent not one half; latent heat not conserved; a damping depth that does not move with the declared rotation or orbit |
| stream-power incision | steady-state profile linear in the chi coordinate, with chi integrated in discharge (the law is `dz/dt = U - K Q^m S^n`, 0015); slope-discharge relation with concavity equal to the exponent ratio under uniform runoff; relief scaling as `(U/K)^(1/n)`, hence as `g^(-1/n)` through `K = rho_w g k_e` | concavity not equal to the exponent ratio under uniform runoff; relief not scaling as `g^(-1/n)` across a gravity sweep, or the coefficient `k_e` moving across the sweep (gravity entered twice) |
| thermal subsidence and isostasy | compensated depth-age curve and plateau height invariant under a gravity sweep with the lithosphere block of `System` (0004) held; ridge depth moving only with the declared water inventory | any gravity dependence of a compensated depth; a ridge depth that does not move with the water inventory |
| hillslope diffusion | parabolic steady profile under uniform uplift; `D` derived from the incision coefficient at the sub-grid scale (0015) so the parabola's `D` is not a free number, and the gravity sweep moves the curvature as `K` moves | curvature not equal to minus uplift over diffusivity |
| lake cascade | single basin area from the water balance; two- and three-basin chains with a spill cap on a synthetic paraboloid hypsometry, closed form | water not conserved through a spill; negative area; fixed point not reached |
| steady unconfined groundwater | Dupuit-Forchheimer between two fixed heads; Laplacian eigenvalues on the sphere; the Dupuit mound height scaling as `mu / (rho_w g)` across a gravity sweep and a water-temperature sweep with permeability held | eigenvalue relative error growing with wavenumber faster than the discretisation predicts; mound height not scaling as `1/g`, or the permeability moving with gravity (conductivity was tabulated instead of permeability) |
| fast river routing | Darcy-Weisbach reach velocity, delay scaling as `g^(-1/2)` with friction factor, hydraulic radius and slope held | delay exponent not -1/2; a Manning-form velocity passing the dimension check |
| ocean | linear barotropic gyres with the two classical western-boundary closures; geostrophic adjustment; Rossby wave dispersion, each run at a declared spread of beta, f, g and depth as the dynamical-core cases are, the expected answer being the closed form evaluated at the test's `System` and never the published Earth number | boundary-layer width or transport wrong at any point of the spread |
| sea-ice drift | steady free drift under surface stress, quadratic ocean drag and Coriolis: closed-form angle and speed ratio at the test's f, densities and drag coefficients, including the f-to-zero limit | angle or ratio off the closed form; a branch at small f |
| strait transport | rotating hydraulic control on a synthetic sill: closed-form transport at the test's reduced gravity and f in the wide, narrow and non-rotating limits | transport off the closed form; the non-rotating limit reached by a branch rather than continuously |
| seawater properties | TEOS-10, freezing-point and carbonate check values at the published (S_A, T, p) points; refusal by name outside a declared domain or outside the Reference-Composition tolerance of the declared solute composition | check value missed; a refusal that does not fire on the planted out-of-domain state or composition |
| convection and boundary layer | dry adiabatic adjustment conserves dry static energy exactly; surface similarity reproduces the neutral log law; neutral drag over water reproduces the log law with the Charnock roughness and scales inversely with gravity | energy not conserved; neutral drag not logarithmic; roughness over water not scaling with gravity |
| gas-mixture property group | known dry-air values on the Earth instance; tabulated pure-gas and binary values on synthetic CO2-bulk and H2-He instances; pure-gas limit of the mixing rules; Clausius-Clapeyron integral of the saturation curve | a member off its source's stated uncertainty; a member that does not move between the instances (an air value left in place) |
| photosynthesis | assimilation-versus-internal-CO2 curves at published temperature responses, the fixture declaring its O2 partial pressure, total pressure and temperature; a second fixture at another O2 partial pressure in which the compensation point moves as half the O2 partial pressure over the specificity factor | wrong shape at the carboxylation-to-regeneration transition; a compensation point that does not move with O2 (the direct-fit defect) |
| land gravity identities | field capacity matric pressure proportional to g; saturated conductivity proportional to g at fixed intrinsic permeability and temperature; hydraulic height ceiling proportional to 1/g at zero path resistance; saltation threshold proportional to the square root of g | any exponent not the derived one: a stored Earth head, conductivity or threshold |
| rotation and orbit invariance | the same biosphere run at two rotation periods moves only `BiologicallyEntrained` quantities; at two orbit lengths only `AccumulatedSum` and `SeasonalEvent` quantities (REQ-BIO-001) | any other quantity moving: a hidden day or year |
| fire spread | Rothermel's published cases including a slope case at the source's gravity, air density and O2; at a second gravity only the Froude-scaled wind and slope factors and the air-density term move | the published slope factor moving with gravity (it carries none); a burn outside the `Sourced` oxygen flammability window |
| hydraulic frame check | two consistent pressure frames of the soil hydraulic states agree; a mixed head-and-pressure frame, and a conductivity carried in m/s across a change of gravity or temperature, differ by the derived ratio (REQ-PED-007) | agreement of the mixed frame: a head stored at another planet's gravity |
| soil element pools | linear pool model: steady stock equals input over rate, closed form | pools not at that value after spin-up; an element not conserved |
| ice flow | the similarity dome solution of the shallow-ice equations; the Halfar timescale scaling as `g^-n` and the pressure-melting depth as `1/(rho_i g)` across a gravity sweep (REQ-CRY-002) | dome radius or height evolution off the closed form; volume not conserved; timescale exponent not `-n` |
| glacial erosion | the two-limb law `E_g = K_g N^r u_b^l` on a prescribed ice field recovers r and l as log-log slopes; `K_g` invariant across a gravity sweep | an exponent not recovered; a velocity-only mutation (r pinned at zero) not caught; `K_g` moving with gravity |

These closed forms are stated in head, thickness or rate units and are blind to a
planetary constant hidden inside a conductivity or rate conversion (a hydraulic head
in metres absorbs the product of density and gravity). What catches that is not
these oracles but the material-form rule of the import checklist (REQ-PROC-008,
Tier B) and the mutation that substitutes an Earth value for one `Derived` field on a
non-Earth configuration (REQ-SYS-101); each column oracle is therefore run on
`Earth()` and on a synthetic non-Earth instance so the conversion is exercised at two
gravities.

### Conservation ledgers

Every coupling exchange passes through a ledger for each conserved quantity: dry
air mass, total energy, water, salt, carbon, nitrogen, phosphorus, and atmospheric
angular momentum; sea-ice mass and salt across advection, ridging and the freezing
and melting exchange are ledgers of the same kind, with the same derived bound. The
ledger records stocks before, fluxes, stocks after and the residual.

*The tolerance is not chosen.* For a ledger over N terms of magnitude up to M in the
working precision, the roundoff bound is a small fixed multiple of N times the
machine epsilon times M (a pairwise-summed ledger may use the square root of N). The
residual is reported in units of that bound. Closures are computed on in-memory
state, never on written output; a check that must read a file measures the file's
written quantum first and refuses a tolerance under a margin of that quantum.

*Wrong, by signature.* A residual growing linearly in time is a leak (a flux counted
once). A constant offset is a stock omitted from the inventory. A random walk of the
roundoff size is roundoff. The ledger report fits the three shapes and names the
class, because the three have different fixes and the predecessor chased a stock
omission as a leak.

### Radiation and the photon currency

- Grey and semi-grey analytic atmospheres (the isothermal grey slab under the
  Eddington approximation; the two-band analytic temperature profile). Exact.
- Line-by-line references. For the solar spectrum, the published set of atmospheric
  profiles with line-by-line clear-sky fluxes at the top and bottom of the atmosphere
  is a downloadable oracle; those profiles are one composition at one gravity, so
  they are the Earth arm and nothing more. **For any other declared spectrum,
  composition, pressure range or gravity there is no shipped reference, so one is
  generated offline** with a line-by-line code for the declared (spectrum,
  composition, pressure-temperature range, gravity through the column mass of each
  pressure level), on the published profile set for the Earth arm and on profiles
  drawn from the declared system's own state brackets otherwise, and committed with
  its generating script and hashes. The generated reference shares its spectroscopy
  (line list, broadening partner, continuum) with the table generator, so it
  validates the k-distribution reduction and not the spectroscopy's applicability to
  the declared bulk gas; the broadening-partner identity of the registry is the
  positive control for that gap (REQ-ATM-003 item 4, decision 0016 item 1). The
  radiation pipeline must accept any stellar type, any bulk composition and any
  combination of sources, so this generation is a build step, not a one-off.
  Tolerance: the reference's own stated accuracy. Wrong: a bias across all profiles
  (a band missing or double counted), or a residual correlating with water-vapour
  path (a continuum term).
- Blackbody identities: the integral of the Planck function equals the
  Stefan-Boltzmann flux; the photon count over a window under a blackbody has a closed
  form and the two changes of variable (wavelength, frequency) must agree; the Sun
  through the same integral over the photosynthetic window reproduces the known
  quanta-per-joule figure. Tolerance: quadrature. Wrong: anything else.
- Band surface albedo: the band split of a published reflectance spectrum integrated
  against the solar spectrum must reproduce its measured broadband value before it is
  trusted under another star; and the bands must differ for a spectrally sloped
  surface (a structure that can carry variation and holds one value is a defect).

### Mesh and crossing identities

The sum of cell areas equals the sphere's area to roundoff at every level; children's
areas sum to the parent's; a constant field coarsens to a constant; an extensive
field's integral is preserved under coarsening to roundoff; a solid-body rotation
lifted to Cartesian at the source frames and projected at the destination frames
returns itself; the children-of-parent relation is an identity; every cell has the
declared valence. Each is a per-commit test.

### System, clock and star identities

The identities decision 0008 implies (Kepler period, the declared epoch event, the
solar-sidereal relation for prograde, retrograde and synchronous instances,
orbit-mean insolation against latitude, obliquity and eccentricity, multi-source
instellation reducing to single-source, a test case's damping, a case literal declared in rotations in its forcing struct,
giving the same per-step fraction at two rotation rates, time encode and decode as inverses),
the gravity and figure identities of decision 0004 (`g(r, phi)` reducing to the
point-mass form at zero rotation; the hydrostatic figure reproducing its closed
form), and the gas-mixture property group of REQ-ATM-017 reproducing its closed
forms are the `system.*` section of the registry. Each runs per commit on `Earth()`
and on a synthetic non-Earth instance with closed forms, because a `Derived` field
validated on one configuration is validated by coincidence.

### Positive controls

A test that has never failed has not been shown able to. Decision 0027's mutation run
executes the whole oracle suite against named deliberate breaks, and every mutation
must be caught by at least one oracle. The mutation list includes an Earth constant
restored where a `System`-derived quantity belongs (a stored head, a conductivity in
m/s, a compensation point fitted at one oxygen, a 24-hour or 365-day literal), and
each must be caught by the identity above that names it.

## Alternatives considered

- *Tolerances chosen by experience.* Rejected: a chosen tolerance is a number that
  can be moved when a test fails. A derived bound cannot.
- *Convergence tests on real cases only.* Rejected: a real case has no exact answer,
  so a wrong order cannot be distinguished from a hard problem. Manufactured
  solutions give the order a right answer.
- *A single global energy check instead of per-exchange ledgers.* Rejected: a global
  check cannot localise a leak, and two errors that nearly cancel pass it.

## Consequences

- Every kernel author writes the oracle before the kernel, and the oracle names the
  wrong-looking outcome.
- The offline line-by-line generator is part of the radiation build, not a test
  fixture, because it runs for every declared spectrum, composition and gravity.
- Ledger reports are typed (leak, omission, roundoff) and a milestone gate reads the
  type, not only the magnitude.

## References

- Williamson, D. L., et al. "A standard test set for numerical approximations to the
  shallow water equations in spherical geometry." Journal of Computational Physics
  102 (1992). DOI: 10.1016/S0021-9991(05)80016-6.
- Jablonowski, C., and D. L. Williamson. "A baroclinic instability test case for
  atmospheric model dynamical cores." Quarterly Journal of the Royal Meteorological
  Society 132 (2006). DOI: 10.1256/qj.06.12.
- Held, I. M., and M. J. Suarez. "A Proposal for the Intercomparison of the Dynamical
  Cores of Atmospheric General Circulation Models." Bulletin of the American
  Meteorological Society 75 (1994). DOI: 10.1175/1520-0477(1994)075<1825:APFTIO>2.0.CO;2.
- Hollingsworth, A., P. Kallberg, V. Renner, and D. M. Burridge. "An internal
  symmetric computational instability." Quarterly Journal of the Royal Meteorological
  Society 109 (1983). DOI: 10.1002/qj.49710946012.
- Celia, M. A., E. T. Bouloutas, and R. L. Zarba. "A general mass-conservative
  numerical solution for the unsaturated flow equation." Water Resources Research 26
  (1990). DOI: 10.1029/WR026i007p01483.
- Pincus, R., et al. "Radiative flux and forcing parameterization error in aerosol-free
  clear skies." Geophysical Research Letters 42 (2015). DOI: 10.1002/2015GL064291.
  (the RFMIP clear-sky profile set; DOI of the profile dataset itself: to confirm)
- Guillot, T. "On the radiative equilibrium of irradiated planetary atmospheres."
  Astronomy and Astrophysics 520 (2010). DOI: 10.1051/0004-6361/200913396.
- Halfar, P. "On the dynamics of the ice sheets 2." Journal of Geophysical Research 88
  (1983). DOI: 10.1029/JC088iC10p06043.
- Roache, P. J. "Code Verification by the Method of Manufactured Solutions." Journal of
  Fluids Engineering 124 (2002). DOI: 10.1115/1.1436090.
- Predecessor records of the derived-tolerance and residual-signature lessons:
  `/home/cfutro/docs/world/notes/audits/closure-tolerance-under-written-precision.md`,
  `/home/cfutro/docs/world/notes/audits/closure-stocks-are-incomplete.md`,
  `/home/cfutro/docs/world/notes/audits/stellar-spectrum-oracle.md`.

## Amendments

- 2026-09-08: dynamical-core elapsed times and forcing timescales are stated in seconds with the spread-arm scaling rule in the registry entry; line-by-line references are generated per (spectrum, composition, gravity) with the published profile set as the Earth arm only; the column closed forms are noted as blind to a hidden planetary constant and run at two gravities; a system, clock and star identities section names the registry's system.* rows, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08 (atmosphere area): the dynamical-core cases own their thermal profile and relaxation rates in a forcing struct the core never reads; the line-by-line reference validates the k-distribution reduction with the broadening-partner identity as its positive control; gas-mixture, damping-depth and Charnock-roughness rows added to the column table, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08 (ocean area): ocean analytic cases run at a declared parameter spread with the closed form as the expected answer; free-drift, strait-control and seawater-property rows added; sea-ice ledgers and the hydrostatic identity named, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08 (terrain area): the manufactured source terms carry g, rho_w and mu as symbols with the order asserted at two gravities; the soil-water, stream-power, hillslope, groundwater and ice-flow rows carry their gravity scalings; subsidence, fast-routing and glacial-erosion rows added, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08 (biosphere area): the photosynthesis row declares its O2 and pressure and gains the compensation-point identity; land gravity identities, rotation and orbit invariance, fire spread and the hydraulic frame check rows added; the mutation list names the restored-Earth-constant breaks, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: cross-area review: the damping identity names a test case's forcing-struct literal, not the model sponge; the glacial-erosion pressure exponent renamed `r`, from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
