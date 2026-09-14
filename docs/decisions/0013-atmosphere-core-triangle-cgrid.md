+++
id = "0013"
title = "The atmosphere core: finite volume on the triangle C-grid, formulated non-hydrostatic and deep, with the hydrostatic limit implemented first"
status = "accepted"
date = 2026-09-08
+++

## Decision

The atmosphere's dynamical core is a finite-volume discretisation of the primitive
equations on the triangle C-grid of decision 0005: mass and thermodynamic variables
at triangle centres, normal velocity components on the three edges. Shallow water is
built and validated first; the three-dimensional core follows on the same operators.

### Why not spectral, and why not the hexagonal dual

A spectral core needs quadrature nodes on latitude rings for its transforms. The
icosahedral mesh has no rings, so a spectral atmosphere means a second grid and a
crossing to the mesh at every coupling step, which is the class of defect the whole
design exists to remove. The predecessor's spectral model is used as a reference arm
(decision 0012), never as a component.

The hexagonal dual (mass at vertices, velocity on edges, vorticity at triangle
centres), which is what several icosahedral cores use, is rejected because a hexagon
is never a union of finer triangles: exact nesting and identical ledger closure
across levels would be lost for the atmosphere and ocean, and the cell area the core
used would differ from the cell area the reductions used, which is the predecessor's
"two answers about its own cell areas" defect rebuilt on purpose.

### The triangle C-grid's known pathology, recorded

On the bisected icosahedron there are 1.5 edges per triangle, so the C-grid carries
1.5 normal-velocity degrees of freedom per mass cell: too few, where the hexagonal
C-grid carries three, too many. The consequence for triangles is a spurious
checkerboard divergence mode. The operational triangle-grid core suppresses it with
a divergence-averaging filter, and this design adopts that remedy as a named part of
the discretisation rather than as a tuning. Separately, every vector-invariant
C-grid core, on any polygon, must be checked against the Hollingsworth instability,
which arises from an inconsistency between the kinetic-energy gradient and the
vorticity-flux terms of the momentum equation; an energy-consistent formulation of
those terms is the remedy. Both are named acceptance items of the shallow-water and
baroclinic gates.

### Formulate general, implement the limit first

The equations, prognostic variables and vertical coordinate are chosen for the
general system: non-hydrostatic, with a prognostic vertical velocity, and a deep
atmosphere in which the radius is not treated as constant with height and the full
Coriolis vector is retained. The hydrostatic, shallow-atmosphere core is implemented
first as the limit of that system with the vertical acceleration removed and the
radius held at its surface value. The general solver is then an additional
vertically implicit solve on the same state, never a rewrite.

The thermodynamic variables of the core (density, virtual potential temperature,
the Exner pressure) are defined once, in terms of the gas-mixture property group of
REQ-ATM-017: the specific gas constant, the heat capacities, their ratio `kappa`
and the ratio `epsilon` of the condensable's molar mass to the mixture's are
`Derived` from the declared composition, and the reference pressure of the Exner
function is a declared field of the system struct, never a literal in the core.
The reference core's published formulation carries every one of these as a
literal of the one atmosphere it was built for, and those literals are
dimensionless, so a lint on dimensional literals does not catch them; the
atmosphere's own lint (REQ-ATM-017) does.

The reasons this is not a runtime question:

- At the spacings a coupled global run uses, hydrostatic and non-hydrostatic cores
  give the same answer; the difference is in what local refinement (decision 0005)
  can reach. Below a declared fraction of the scale height, convection becomes
  explicitly resolved, and a non-hydrostatic core gets right what no
  parameterisation does: the diurnal cycle of precipitation, orographic rain on
  steep terrain, downslope winds through passes, storm organisation. A hydrostatic
  core refined to that spacing produces wrong dynamics, so hydrostatic caps
  refinement depth for the atmosphere.
- The convective parameterisation carries two `Bracketed` Earth-fitted numbers
  (entrainment rate, closure time). They are two rows of the oracle registry's
  list of `Bracketed` and `Irreducible` atmosphere constants, which is reviewed at
  every milestone (decision 0007) and which no prose claims to be.
  Convection-permitting runs are the only known route to removing the convective
  pair.
- Hydrostatic validity is a property of the configuration, not a constant. It
  requires horizontal spacing much larger than the scale height, and on a
  low-gravity, hot, or light-gas world the scale height can be tens of kilometres.
  The shallow-atmosphere approximation fails on the same worlds for the same reason.
  A generic builder cannot take either approximation for granted.

The solver checks the validity of the hydrostatic limit against the configuration
and the level (spacing against scale height) and refuses refinement below the limit
until the general solver exists.

### Vertical structure and dissipation

A hybrid terrain-following vertical coordinate compatible with both solvers; levels
placed per the ladder of decision 0005; a sponge at the top with a timescale derived
from the resolved gravity-wave spectrum, not declared in days. Numerical dissipation
is the scheme's own plus a fourth-order filter whose coefficient is a `Closure`
(decision 0007): a sourced scaling in the spacing and the eddy velocity, swept across
levels.

### The fallback ladder

The shallow-water gate is the go/no-go on the triangle C-grid. If it fails after a
bounded effort declared at the start of that milestone, the fallbacks in order are:

1. A Z-grid formulation on the same triangles: mass, vorticity and divergence at cell
   centres, velocity reconstructed from them. It has no C-grid modes, keeps the
   hierarchy and the exact nesting, and costs one elliptic solve per step.
2. A cubed-sphere finite-volume core: exact nesting on quadrilaterals, no Gaussian
   grid, at the price of panel seams.

Never a spectral core.

## Alternatives considered

- **Spectral transform core.** Lost on the second grid.
- **Hexagonal-dual C-grid** (the TRiSK family). Lost on exact nesting; recorded above.
- **Hydrostatic only, as a permanent choice.** Lost on the three outcome arguments
  above; the design rule of decision 0003 (cheap route on the general formulation)
  applies.
- **Non-hydrostatic solver first.** Lost because it adds the hardest part of the
  numerics to the long pole with no benefit at coupled spacings; it arrives when a
  refinement or a configuration needs it.
- **A cubed sphere from the start.** Second choice in decision 0005; here the last
  fallback.

## Consequences

- The ocean core (decision 0017) shares the horizontal operators; writing them once
  buys both fluids.
- The shallow-water gate's acceptance list includes: the standard shallow-water test
  suite at the designed convergence order; the checkerboard divergence mode
  demonstrably suppressed; the Hollingsworth check passed; a graded refinement region
  with no reflected-wave growth. The baroclinic gate adds the steady-state and
  baroclinic-wave tests and the idealised forced climatology against the reference
  arm.
- Oracles implied beyond those: total angular momentum conserved within the ledger
  bound; total energy conserved within the ledger bound under adiabatic forcing;
  the small-planet scaled tests at the published norms.
- Every standard case is a `System` instance plus a forcing struct that owns the
  case's own reference pressure, thermal profile, wind amplitude and relaxation
  rates, all in SI units with times in seconds; the core reads none of them. The
  published cases are defined at one planet's values and are run there for the
  published answer (decision 0026); a case literal that reaches the core is a
  named mutation of decision 0027 that the parameter-spread runs must catch.

## References

- Wan, H., et al. "The ICON-1.2 hydrostatic atmospheric dynamical core on triangular
  grids - Part 1: Formulation and performance of the baseline version." Geoscientific
  Model Development 6 (2013). DOI: 10.5194/gmd-6-735-2013
- Zaengl, G., Reinert, D., Ripodas, P., Baldauf, M. "The ICON (ICOsahedral
  Non-hydrostatic) modelling framework of DWD and MPI-M: Description of the
  non-hydrostatic dynamical core." Quarterly Journal of the Royal Meteorological
  Society 141 (2015). DOI: 10.1002/qj.2378
- Hollingsworth, A., Kallberg, P., Renner, V., Burridge, D. M. "An internal symmetric
  computational instability." Quarterly Journal of the Royal Meteorological Society
  109 (1983). DOI: 10.1002/qj.49710946012
- Gassmann, A. "A global hexagonal C-grid non-hydrostatic dynamical core (ICON-IAP)
  designed for energetic consistency." Quarterly Journal of the Royal Meteorological
  Society 139 (2013). DOI: 10.1002/qj.1960
- White, A. A., Bromley, R. A. "Dynamically consistent, quasi-hydrostatic equations
  for global models with a complete representation of the Coriolis force." Quarterly
  Journal of the Royal Meteorological Society 121 (1995). DOI: 10.1002/qj.49712152202
- Williamson, D. L., Drake, J. B., Hack, J. J., Jakob, R., Swarztrauber, P. N. "A
  standard test set for numerical approximations to the shallow water equations in
  spherical geometry." Journal of Computational Physics 102 (1992).
  DOI: 10.1016/S0021-9991(05)80016-6
- Jablonowski, C., Williamson, D. L. "A baroclinic instability test case for
  atmospheric model dynamical cores." Quarterly Journal of the Royal Meteorological
  Society 132 (2006). DOI: 10.1256/qj.06.12
- Held, I. M., Suarez, M. J. "A Proposal for the Intercomparison of the Dynamical
  Cores of Atmospheric General Circulation Models." Bulletin of the American
  Meteorological Society 75 (1994). DOI: 10.1175/1520-0477(1994)075<1825:APFTIO>2.0.CO;2
- The predecessor's audit on its two cell-area answers:
  `/home/cfutro/docs/world/notes/audits/ocean-grid-crossing.md`.

## Amendments

- 2026-09-08: named the core's thermodynamic variables and their gas-mixture group as Derived from the declared composition with the Exner reference pressure a declared field (audit row 1), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: replaced the ten-kilometre convection-permitting figure with a declared fraction of the scale height (audit row 33), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: replaced the claim that convection is the one place the atmosphere carries Earth-fitted numbers with a pointer to the registry's list (audit pattern 5), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: made every standard test case a System instance plus a forcing struct owning its own literals in SI seconds, none read by the core (audit row 17), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
- 2026-09-14: the reference pressure of the Exner function is `Irreducible`: a fixed reference only rescales potential temperature by a constant factor, so no measurement or catalogue selects one. It is not `Sourced` to CODATA's standard atmosphere, which states a unit of pressure and nothing about this convention. User decision of 2026-09-14, raised by notes/findings/2026-09-14-an-audit-of-source-fitness.md; Earth() on fiddlybits-52v.4.5 carries its declaration.
