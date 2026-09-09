# SurfaceFluxes.jl

*Julia identifiers are transliterated to ASCII below where the source spells them
with Greek letters; the transliteration is noted at first use.*

**What it is.** A standalone Monin-Obukhov surface-layer solver: given an interior
state, a surface state and a height difference, it solves for the stability
parameter (`zeta` in the source) and returns the friction velocity, the scalar
scales, the exchange coefficients and the surface fluxes. It holds no grid, no
state and no clock; `src/` is eleven files of pointwise scalar functions plus two
parameter modules.

**What of it is used.** Nothing. This is a survey record, and this project builds
its own surface layer under decision 0018 (evaporation row) and decision 0016.

**Are the universal functions parameterised by struct.** Yes, thoroughly, and this
is the part of the package worth reading. `src/UniversalFunctions.jl` declares
`AbstractUniversalFunctionParameters{FT}` and three concrete bundles,
`BusingerParams`, `GryanikParams` and `GrachevParams`, each a `Base.@kwdef struct`
whose fields are required keywords with no in-struct defaults. The three functions
`phi` (the non-dimensional gradient), `psi` (its point-value integral) and `Psi`
(its layer-averaged integral, Nishizawa and Kitamura 2018) dispatch jointly on the
parameter type and on a transport type, one of `MomentumTransport`,
`HeatTransport`, `MomentumVariance` or `HeatVariance`; the finite-difference and
finite-volume schemes are themselves types, `PointValueScheme` and
`LayerAverageScheme`. The generalisation is real rather than nominal: the
docstring of the private helper for the layer-averaged momentum integral records
that the published Eq. A5 hard-codes a denominator valid only at one value of the
unstable coefficient, and the implementation replaces it with the general form in
that coefficient. A package that had merely wrapped a fit would not have found
that.

**Which constants are genuinely dimensionless.** The von Karman constant
(`von_karman_const` on `SurfaceFluxesParameters`); the neutral Prandtl number
`Pr_0`; the stable linear coefficients `a_m` and `a_h`; the unstable coefficients
`b_m` and `b_h` inside the fourth-root and square-root terms; the matching
stability `zeta_a` and the transition coefficient in the Gryanik and Grachev
branches; the variance-function coefficients of Panofsky, Wyngaard and Tan, which
appear as bare literals in `phi(..., MomentumVariance())` and
`phi(..., HeatVariance())` rather than as struct fields. All of these are
surface-layer similarity numbers and none carries a planet. The Raupach canopy
roughness relation in `src/roughness_lengths.jl` is likewise dimensionless in the
canopy height and area index.

**Which constants are fitted at one gravity and one air density.** The whole
`COARE3RoughnessParams` surface, and it is worth separating what is in it.
`momentum_roughness` for that type is the sum of a smooth-flow limit and a
Charnock rough-flow limit. The Charnock limit divides by gravity explicitly
(`z0_rough = alpha * ustar^2 / grav`), so gravity is carried, but the Charnock
coefficient itself is interpolated linearly between a low and a high value over a
low and a high wind speed, four numbers fitted to one ocean under one atmosphere.
The smooth limit multiplies a fixed coefficient (0.11, Smith 1988) by a kinematic
viscosity of air held as a scalar field `kinematic_visc` on the roughness struct,
not as a function of temperature and pressure. To recover the ten-metre wind the
function evaluates a neutral log profile against a bare `FT(10)`, an Earth
observational reference height welded into the physics. The scalar roughness is a
dimensional fit in metres to COARE and HEXOS data, `min(1.1e-4, 5.5e-5 *
Re_star^-0.6)`. On the gustiness side, `DeardorffGustinessSpec` computes a
convective velocity as the cube root of the buoyancy flux times `gustiness_zi`, a
*fixed* boundary-layer height held on the parameter set, scaled by
`gustiness_coeff`; the docstring says plainly that the height is assumed fixed.
A boundary-layer depth is precisely what decision 0016 derives from the declared
system, so this is a constant standing where a derivation belongs.

**Does it take gravity and the thermodynamic state from the caller.** Gravity,
yes, and cleanly: every use site reads `SFP.grav(param_set)`, which forwards to
the caller's `ThermodynamicsParameters`. The buoyancy flux is written
`(grav / rho_sfc) * (...)` and the Obukhov length as minus the cube of the
friction velocity over the von Karman constant times the buoyancy flux, so the
Obukhov length reads the supplied gravity exactly as decision 0018 requires.
The thermodynamic state is the problem. `SurfaceFluxesParameters` holds a
`thermo_params` field and forwards every field name of `ThermodynamicsParameters`
by metaprogramming, and the use sites call `TD.gas_constant_air`, `TD.cp_m`,
`TD.dry_static_energy`, `TD.vapor_static_energy`, `TD.virtual_pottemp` and
`TD.Parameters.Rv_over_Rd`. That vocabulary is one condensable in one bulk gas by
naming: `Rv_over_Rd` is the reciprocal of the composition ratio REQ-ATM-017 calls
`epsilon`, and it is reached for by a name that already says which two gases. The
package does not read a gas-property group; it reads a dry-air-plus-water-vapour
parameter struct. Supplying REQ-ATM-017's group to this package would mean
projecting it onto that struct field by field, which is a translation layer, and
decision 0003's rule is that there are none.

**Assumptions it carries, checked item by item.**

| item | finding |
| --- | --- |
| A1, calendar | clean negative: no `Dates` import anywhere in `src/`, no day, no year, no epoch |
| A2, planetary constants | clean negative for a block of its own: gravity is a forwarded accessor onto the caller's thermodynamics parameters, and nothing else planetary is held |
| A3, Earth literals | clean negative in `src/`: none of the gravity, radius, rotation, solar or pressure literals appears. The Earth values enter through the `ClimaParams` extension `ext/CreateParametersExt.jl`, which fills every field of every struct from named TOML keys, and that is the documented construction path |
| A6, grid and index base | clean negative: no arrays, no indices, no grid. The parameter structs define `Base.broadcastable(ps) = tuple(ps)` so they broadcast as scalars over whatever field type the caller has |
| precision | clean negative: `FT`-generic throughout; the strings `Float32` and `Float64` do not appear in `src/` |
| threading and GPU | clean negative: no `CUDA`, no `KernelAbstractions` in `src/`; the code is `@inline` scalar functions using `ifelse` rather than branches, which is what makes it kernel-safe, and `test/runtests_gpu.jl` exercises it |
| mutable global state | clean negative: no `global`, no `const` dictionary, no `Ref` in `src/` |
| B4, comment against value | the comment on `gustiness_zi` reads "[m] Boundary layer height for gustiness (if fixed)" and the Deardorff docstring repeats that the height is assumed fixed; comment and value agree, and both name the assumption |
| B5, clamps and limiters | the stability parameter saturates at `zeta_max = FT(100)`; the Raupach path floors the friction velocity at `FT(1e-4)` with the comment "Sufficient for very calm conditions"; `max(ustar, eps(FT))` and `max(deltaU, eps(FT))` guard divisions; the variance functions take `min(zeta, 0)`; the solver defaults to absolute and relative tolerances of `1e-2` |
| C1, use site per constant | read for `grav`, `von_karman_const`, the Charnock coefficient, `gustiness_zi` and `kinematic_visc`; none is overridden by a later stage |
| C3, declared against demonstrated | the non-Earth capability is declared by the struct signature and demonstrated nowhere: every shipped default is Earth's and the regression suite, including `test_coare3_literature.jl`, checks against Earth field campaigns |
| C4, fail-open branches | clean negative on the solver: it returns a `converged` flag alongside the root and saturates rather than substituting silently, and there is a `test_convergence_flag.jl` for it. The `max(x, eps)` guards above are silent substitutions, but they bind only at zero wind |
| C5, second copies | `z0m_fixed` and `z0s_fixed` on `SurfaceFluxesParameters` duplicate `z0m` and `z0s` on `ConstantRoughnessParams`, and the extension fills both from the same two TOML keys; neither is named authoritative |
| D2, boundary field by field | units are documented per field in the docstrings (metres, m/s, W/m2); there is no array orientation and no calendar dimension to check |
| D4, conservation identity | `test/test_energy_budget_closure.jl` exists upstream and closes the surface energy budget; the identity has a right answer in advance |

**Where it is Earth-fitted in its data but general in its code.** The universal
function module is general code with the coefficients as struct fields. The
roughness and gustiness modules are the reverse: the code shape is fixed by the
fit (a linear Charnock interpolation, a power law in a roughness Reynolds number,
a fixed boundary-layer height) and no struct field would make them general.

**Licence.** Apache 2.0. **Version.** 1.2.1, read against commit
`0d22849b96fdda715bbe04ab844f2490af272514` on `main`, dated 2026-09-01.

**Verdict: borrow ideas only.** The universal-function half is exactly the
dimensionless, struct-parameterised, transport-type-dispatched form this project
wants and should be reproduced in shape, but the package cannot be taken without
`Thermodynamics.jl`'s one-condensable-in-dry-air parameter struct, and its
roughness and gustiness surface is a set of ocean and boundary-layer fits at one
gravity, one air density and a fixed reference height.

**What would move the verdict.** If the `UniversalFunctions` submodule were
separately packaged, with no `Thermodynamics` dependency, it would be a candidate
for adopt as infrastructure. It is not, and this survey adopts nothing. Were that
adoption ever proposed, the test that would catch the leak is a similarity-function
identity oracle at two gravities and two gas mixtures asserting the same
dimensionless profile, plus the dimensionless-literal lint of REQ-ATM-017 item 4
run over the imported surface; the decision that would have to be taken is an
amendment to 0012 moving the package from "borrow ideas" to "adopt as
infrastructure" and naming the pin.
