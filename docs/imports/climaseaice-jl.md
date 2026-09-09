# ClimaSeaIce.jl

*Julia identifiers are transliterated to ASCII below where the source spells them
with Greek letters.*

**What it is.** A sea-ice package built on Oceananigans fields, grids and kernel
launching. `SeaIceModel` evolves ice thickness, ice concentration, an optionally
prognostic ice salinity and a top surface temperature. Dynamics are a
`SeaIceMomentumEquation` with a choice of elasto-visco-plastic rheology, a viscous
rheology, or a free-drift stress balance, with a landfast basal stress and
explicit or split-explicit momentum solvers. Thermodynamics are a
`SlabThermodynamics`, with a separate enthalpy-method model in its own module.

**What of it is used.** Nothing. Decision 0017 specifies this project's sea ice.

**What the thermodynamics assumes about seawater composition and the freezing
point.** One struct answers the question. `LinearLiquidus{FT}` holds two fields, a
freshwater melting temperature and a slope, and `melting_temperature` returns the
first minus the slope times the salinity. The constructor's defaults are a slope
of 0.054 and a freshwater melting temperature of zero, and the docstring states
that the defaults assume salinity in practical salinity units and temperature in
degrees Celsius. Four consequences, and they are the point of this record.

1. **The composition enters once, through a single fitted slope, with no declared
   validity domain.** The linear liquidus is a straight-line fit to the
   Reference-Composition seawater liquidus over the range of Earth ocean
   salinities. It is Reference-Composition-bound in exactly the way the
   implicit-Earth audit found seawater property fits to be, and in the way
   decision 0017 records TEOS-10 to be. But TEOS-10 at least has a stated validity
   domain in salinity, temperature and pressure that REQ-OCN-003 can refuse
   against. A two-number linear fit has none: there is no salinity, no solute and
   no temperature at which this function declines to answer. Where 0017 has a
   composition fence with a refusal, this package has a slope.
2. **There is no pressure dependence.** The melting temperature is a function of
   salinity alone. The freezing point does not fall with depth, so the ice-water
   equilibrium at the ice base is a surface-pressure relation applied wherever it
   is called, on any world at any surface pressure.
3. **The unit carries the assumption.** Practical salinity is a conductivity ratio
   calibrated against Earth's reference composition, so the argument's unit, not
   only the slope, encodes the composition. This is the review method's warning
   that a unit is a place a constant can hide, in its cleanest form: a reader
   checking the slope against a source would still not have found the assumption
   in the argument.
4. **The default composition is fresh water, silently.** `SeaIceModel` defaults
   `ice_salinity` to zero and the bottom heat boundary condition
   `IceWaterThermalEquilibrium` defaults its salinity to zero, so a model
   constructed without an explicit salinity runs a freshwater liquidus and a
   freezing point at the freshwater value with no refusal and no report. Decision
   0003's rule against a silent default across a component boundary is broken
   here, and the boundary in question is the one to the ocean.

**How it compares with the Winton three-layer scheme decision 0017 names.** It is
not Winton, and the gap is exactly where the composition would have to enter.
`SlabThermodynamics` holds a single prognostic top surface temperature, top and
bottom heat boundary conditions, an internal heat-flux model and a
concentration-evolution rule. The internal flux is either a `ConductiveFlux`,
documented in the source as a single-layer Fourier flux with a constant
conductivity whose default is annotated as appropriate for freshwater ice, or an
`IceSnowConductiveFlux`, documented as resistors in series for the ice-plus-snow
path. There is no interior ice temperature, no upper and lower ice layer, no
brine-pocket heat capacity, and no salinity-and-temperature-dependent
conductivity. Winton's whole contribution is that the liquidus appears *inside*
the upper layer's heat capacity and inside the conductivity, so that brine
pockets store latent heat and conduct differently as the ice warms; decision 0017
requires the liquidus slope to be read there from the one freezing-point function
of REQ-OCN-003, and requires the brine-conductivity coefficient to be `Bracketed`
between thin first-year and thick multiyear ice. This package puts the liquidus
only at the ice-water boundary and holds the conductivity as one number.

`PhaseTransitions` does carry a temperature-dependent latent heat, formed as a
reference latent heat plus the difference of the liquid and solid volumetric heat
capacities times the departure from a reference temperature, with all four
material constants held as scalars. That is a linear sensible-heat correction to
the latent heat, not Winton's brine term, and it should not be mistaken for one.

What the package does have that 0017 also names: a concentration-evolution rule
citing Hibler 1979 for partitioning thermodynamic volume change between lateral
and vertical growth, which is the family 0017's lead-closing law comes from; a
free-drift stress balance, which is what 0017 adopts; and an elasto-visco-plastic
rheology, which 0017 defers with its reason. The available structure is therefore
adjacent to what 0017 wants and short of it in precisely the thermodynamic
interior.

**Assumptions it carries, checked item by item.**

| item | finding |
| --- | --- |
| A1, calendar | clean negative: no calendar of its own, no day, no year. The clock is Oceananigans', whose time is a plain number of SI seconds |
| A2, planetary constants | clean negative for a block of its own. It inherits one: the momentum equation's gravitational acceleration defaults to Oceananigans' mutable global defaults object, as do the float types of the liquidus, the phase transitions, the radiative emission, both rheologies and the external stress |
| A3, Earth literals | clean negative for planetary literals. The dimensional constants present are substance properties rather than planetary ones: solid and liquid densities, solid and liquid heat capacities, a reference latent heat of fusion, snow and ice conductivities, an emissivity of one and the Stefan-Boltzmann constant. Every one is a scalar at a reference state rather than a function of state, which is the same shape as the air-property finding against `CloudMicrophysics` |
| A6, grid and index base | Oceananigans structured grids, with surface fields at the centre-centre-nothing location and the associated halo conventions. Not this project's mesh |
| precision | the float type of every constructed struct is read from Oceananigans' *mutable* default at call time, so two structs built either side of a change to that global carry different precisions with nothing recording which is authoritative |
| threading and GPU | KernelAbstractions through Oceananigans' kernel launcher, with `Adapt.adapt_structure` defined on the slab thermodynamics, the phase transitions and the heat boundary conditions so they reach a device |
| mutable global state | inherited from Oceananigans and read at construction, as above |
| B4, comment against value | the comments are accurate and are the evidence: the conductivity default is annotated as appropriate for freshwater ice, and the liquidus docstring states the practical-salinity and Celsius assumption outright. Nothing is hidden; it is simply assumed |
| B5, clamps and limiters | not surveyed exhaustively. The rheology and momentum modules were read only for their structure |
| C1, use site per constant | read for the liquidus slope (the bottom heat boundary condition and the top melting constraint), the ice salinity (both defaults) and the gravitational acceleration (the free-surface term of the momentum equation) |
| C3, declared against demonstrated | the salinity dependence is declared by the struct and demonstrated only within Earth ocean salinities; there is no positive control that the liquidus refuses anything |
| C4, fail-open branches | the two zero-salinity defaults above are the clearest fail-open in this group: the model runs, produces numbers, and reports nothing |
| C5, second copies | the freezing point of fresh water appears as the liquidus intercept and, separately, as the zero of the Celsius temperature convention the whole package uses; and the ice salinity appears both as a model tracer and as a field on the bottom boundary condition |
| D2, boundary field by field | the ice-ocean boundary reads the ocean's surface salinity tracer directly by index, in practical salinity units, against a temperature in degrees Celsius, with the unit contract carried only in a docstring. Nothing checks it on either side |
| D4, conservation identity | not evaluated here |

**Where it is Earth-fitted in its data but general in its code.** Neither half is
general. The liquidus is Earth's ocean in two numbers inside the code, and the
material constants are scalars where functions of state belong. The general parts
of the package are the dynamics (a stress balance and a rheology, which carry any
composition) and the concentration-evolution structure.

**Why this matters beyond the verdict.** The implicit-Earth audit found that
seawater property fits are Reference-Composition-bound, and decision 0017
responded by declaring the saline limb `Irreducible` inside a
Reference-Composition anomaly tolerance and refused beyond it. This package is the
worked demonstration that the binding can be *tighter* than TEOS-10's while
looking looser: a linear liquidus presents as two configurable numbers and is in
fact a fit with no domain, so a configuration outside its range gets an answer
instead of a refusal. That is the case 0017's refusal boundary exists to catch,
and it is worth citing when REQ-OCN-003's validity-domain rule is implemented.

**Licence.** Apache 2.0. **Version.** 0.5.8, read against commit
`5a5b97fa6923da529242d285798861872e0ce2cd` on `main`, dated 2026-09-03. Read
deeply in `src/SeaIceThermodynamics/` and `src/sea_ice_model.jl`; read shallowly
in `src/Rheologies/`, `src/SeaIceDynamics/`, `src/sea_ice_advection.jl` and
`src/EnthalpyMethodSeaIceModel.jl`, which were checked for their structure and
their constants and not for their numerics.

**Verdict: do not adopt.** Its thermodynamics is a single-layer slab with a
constant freshwater-ice conductivity rather than the Winton three-layer scheme
decision 0017 names, its freezing point is a two-parameter linear liquidus in
practical salinity with no pressure dependence and no validity domain to refuse
against, its ice and boundary salinity default silently to fresh, and it inherits
Oceananigans' mutable global gravity and float type together with a structured
grid this project does not have.
