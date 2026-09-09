# ClimaLand.jl

*Julia identifiers are transliterated to ASCII below where the source spells them
with Greek letters.*

**What it is.** A land model with standalone components (soil, canopy, snow,
inland water, surface water, and a bucket) and an integrated `LandModel` that
composes them on a shared domain, driven either by prescribed atmospheric forcing
or by a coupler.

**What of it is used.** Nothing. Decision 0018 specifies this project's land
column.

**The column's structure.** The integrated `LandModel` in `src/integrated/land.jl`
holds a soil model, a canopy model, a snow model, a soil carbon-dioxide
biogeochemistry model and optionally a slab lake, and it is one column per surface
point shared by all of them. That is the same architectural choice decision 0018
makes and it should be recorded as genuine convergence: the two-column arrangement
the predecessor suffered is not what CliMA built either. Component by component:

- **Soil.** `EnergyHydrology` couples Richards equation in mixed form with a soil
  heat equation carrying phase change, over multiple vertical layers. The
  hydrology closure is a type, `vanGenuchten` or `BrooksCorey`, taking its shape
  parameters explicitly. Runoff is a submodule with a TOPMODEL saturated fraction.
  Boundary conditions are types: `WaterFluxBC`, `MoistureStateBC`, `FreeDrainage`,
  `HeatFluxBC`, `TemperatureStateBC`, combined by `WaterHeatBC`.
- **Canopy.** Sunlit and shaded assimilation with a choice of Farquhar
  photosynthesis or the P-model, an optimality or Medlyn stomatal conductance,
  plant hydraulics, two-stream canopy radiative transfer, autotrophic respiration,
  biomass, an optimal leaf area index and solar-induced fluorescence. Turbulent
  fluxes go through `SurfaceFluxes.jl`.
- **Snow.** A bulk single-layer pack based on UEB, prognostic in snow water
  equivalent, depth or bulk density, and a bulk temperature. Albedo is either a
  constant or a zenith-angle fit.

**How deeply Earth is wired in.** Deeply, and the naming says so before the code
does: the parameter set is a struct called `LandParameters` and the variable is
called `earth_param_set` at every call site in the tree, in twenty or more files.
It is not a system that happens to be Earth; it is Earth's parameter set passed
around by that name.

- **The parameter block.** `LandParameters` carries gravity, a mean sea level
  pressure `MSLP`, a thermal conductivity of air `K_therm`, a vapour diffusivity
  `D_vapor`, the Stefan-Boltzmann constant, a freezing temperature, water's molar
  mass, the universal gas constant, Planck's constant, the speed of light and
  Avogadro's number, plus nested thermodynamics, surface-flux and insolation
  parameter sets. Gravity is threaded properly to its use sites (the snow
  overburden and the soil freezing-point depression both read it), so the
  gravity question has a clean answer. But `K_therm` and `D_vapor` are again
  scalars where REQ-ATM-017 requires members of a `Derived` group evaluated at
  the local state, and this is a second copy of the same two constants that
  `CloudMicrophysics.AirProperties` holds.
- **Photosynthesis with Earth oxygen.** Yes, twice. The Farquhar parameters carry
  a field documented as "Intercelluar O2 concentration (mol/mol); taken to be
  constant", filled from a `ClimaParams` key for the intercellular oxygen
  concentration, and the effective Michaelis-Menten parameter is formed as the
  carbon-dioxide constant times one plus that oxygen concentration over the
  oxygen constant. So the oxygen mole fraction of one atmosphere enters as a
  fixed field rather than from a declared composition. Worse, the P-model
  computes the carbon-dioxide compensation point by scaling its reference value
  by the local pressure divided by a bare literal `101325.0` written into the
  expression. That is Earth's standard sea-level pressure as an unlabelled
  denominator in a physics kernel, and it is the clearest implicit-Earth leak
  found anywhere in this group.
- **A fixed day length.** Clean negative on a literal, and worse in substance.
  There is no day-length constant and no `86400` in the source. Instead the model
  carries a `Dates.DateTime` start date and advances a clock in seconds against
  it, takes the day of year from `Dates.dayofyear`, and gets the solar zenith
  angle from `Insolation.jl` with an `InsolationParameters` set. The day and the
  year therefore come from the proleptic Gregorian calendar and from one orbit,
  across a component boundary, which for this project is a heavier commitment
  than a constant would be.
- **A fixed geothermal or zero bottom heat flux.** Clean negative on a fixed
  value: `HeatFluxBC` wraps a caller-supplied function, so a basal heat flux
  derived per province and age, as decision 0018 requires, could be supplied.
  There is no shipped geothermal constant. The failure is on the other side:
  nothing requires a bottom heat flux to be declared, and the shipped integrated
  configuration reaches for `FreeDrainage` and `EnergyWaterFreeDrainage` at the
  bottom, so the default is silence rather than a refusal.
- **Pedotransfer functions.** The closures are general and the data is Earth's.
  `vanGenuchten` and `BrooksCorey` take the air-entry inverse potential and the
  pore-size index as constructor arguments and derive the remaining exponents; no
  regression is baked into the closure. But `src/standalone/Soil/spatially_varying_parameters.jl`
  fills those parameters from NetCDF artifacts by name: the van Genuchten and
  saturated-conductivity maps of Gupta et al. 2020, the Rosetta pedotransfer
  outputs, SoilGrids texture fractions, and a CLM soil albedo map. That is the
  common and useful case the plan asks about: general code, Earth data.
- **A unit that hides a constant.** Matric potential is carried as a head in
  metres and the van Genuchten inverse air-entry potential in reciprocal metres,
  so gravity and the water density are absorbed into the unit rather than written.
  The soil heat module then reintroduces both explicitly in the freezing-point
  depression, which multiplies gravity by a potential in metres and divides by the
  latent heat of fusion. Two conventions coexist in one component; decision 0018
  requires matric-potential quantities to carry gravity explicitly, and this
  package does so in one place and not the other.

**Judged against decision 0018's one land column.** The one-column choice matches.
Almost nothing else does. There is no tile mosaic: a search of the tree for a tile
concept returns only a phrase in an artifact description, so there is no elevation
band, no lake tile, no glacier tile, no bare tile, no wetland tile, and above all
no island tile, and an island inside a partly-land cell is therefore rounded away.
The snow is a bulk single layer with a constant or zenith-angle albedo, where 0018
requires a multilayer pack with prognostic grain size, impurity mass, a named
pore-gas conduction term and a per-band two-stream albedo. There is no glacier
surface mass balance and no dust emission. Orographic downscaling by the column's
own lapse rate does not exist because there are no sub-grid units to downscale to.

**Assumptions it carries, checked item by item.**

| item | finding |
| --- | --- |
| A1, calendar | a `Dates.DateTime` clock, `dayofyear`, and artifacts keyed by Earth calendar year, one of them defaulted to a specific year in a function signature; the year and the day are the Gregorian ones |
| A2, planetary constants | `LandParameters` is the block; every member is runtime-settable and every member defaults to Earth's through `ClimaParams`; the variable holding it is named `earth_param_set` throughout |
| A3, Earth literals | `6.378e6` as a `radius_earth` keyword default in the `Plane` and box domain constructors and in a docstring; `101325.0` inside the P-model compensation point; `101325` and a Stefan-Boltzmann times 280 K to the fourth as default prescribed-atmosphere drivers. Each accounted for above |
| A6, grid and index base | ClimaCore spaces: `Point`, `Column`, `ColumnEnsemble`, `Plane`, `HybridBox`, `SphericalShell`. There is no icosahedral option. Julia's one-based indexing with ClimaCore's own vertical and horizontal index conventions |
| precision | `FT`-generic; both `Float32` and `Float64` are supported and documented |
| threading and GPU | through `ClimaComms` device and context, with the device taken from the domain's space; no direct `CUDA` in the model code |
| mutable global state | clean negative on a mutable parameter object. The out-of-band state is the artifact store: `LazyArtifacts` and `@clima_artifact` download named Earth datasets (MODIS leaf area index, ERA5 and other forcing, soil parameter maps) on first use |
| B4, comment against value | the comment on the intercellular oxygen field says "taken to be constant", which is accurate and is the assumption; the `radius_earth` keyword is named for what it is |
| B5, clamps and limiters | a floor on the depressed freezing temperature with the comment that a zero would divide to NaN later; texture fractions renormalised by their sum where it exceeds one; the usual saturation clamps in the retention curves. Not read exhaustively |
| C1, use site per constant | read for gravity (snow overburden, soil freezing-point depression), the intercellular oxygen (Michaelis-Menten), the reference pressure (P-model compensation point) and `radius_earth` (domain construction) |
| C3, declared against demonstrated | `Column` and `ColumnEnsemble` domains are declared and exercised, which is the shape a column-only use would want; no non-Earth capability is declared anywhere |
| C4, fail-open branches | the bottom boundary defaults to free drainage with no refusal if nothing is declared; the prescribed-atmosphere constructor supplies a full set of Earth default drivers as function keywords |
| C5, second copies | `K_therm` and `D_vapor` on `LandParameters` duplicate `CloudMicrophysics.AirProperties`; a freezing temperature and a water molar mass are held both here and on the nested thermodynamics parameters |
| D2, boundary field by field | the component exchanges are typed and unit-documented, but the atmosphere boundary carries a `DateTime` and a day of year, which is a calendar dimension in the exchange |
| D4, conservation identity | upstream tests exist for total water and total energy per area across the integrated model; not run here |

**Licence.** Apache 2.0. **Version.** 1.12.1, read against commit
`c865270ac01daad0fb942c6163e0d7d87e69e3ff` on `main`, dated 2026-09-04. This is
the largest tree in this group and it was read selectively: deeply in
`src/shared_utilities/Parameters.jl` and `Domains.jl`, `src/standalone/Soil/`
boundary conditions, retention models and heat parameterisations,
`src/standalone/Vegetation/photosynthesis_farquhar.jl` and `pmodel.jl`, and
`src/standalone/Snow/`; shallowly in the biogeochemistry, plant hydraulics,
diagnostics and simulation-driver layers, which were checked for Earth defaults
and not otherwise.

**Verdict: do not adopt.** The one-column architecture agrees with decision 0018
and is worth citing as independent support for it, but the package has no tile
mosaic and therefore no island, a bulk single-layer snowpack where 0018 needs a
grain-size and impurity pack, Earth's oxygen and Earth's sea-level pressure inside
the photosynthesis kernels, a Gregorian calendar and an Insolation orbit across
its driver boundary, and a parameter set that the source itself calls the Earth
parameter set.
