# ClimaOcean.jl

*Julia identifiers are transliterated to ASCII below where the source spells them
with Greek letters.*

**What it is.** At the commit read, a configuration and re-export layer for
running Earth ocean and sea-ice simulations with Oceananigans. It is not a model.

**What of it is used.** Nothing.

**What it wraps.** Two things. First, `Oceananigans.jl`, whose grids, fields,
operators and models it builds on directly. Second, and now carrying most of the
substance, a package named `NumericalEarth.jl`, from which ClimaOcean re-exports
whole modules: a data-wrangling layer with named Earth products (ETOPO
bathymetry, the ECCO and GLORYS ocean states, the EN4 profiles, the JRA55
atmospheric reanalysis), a bathymetry module, and modules named for atmospheres,
oceans, sea ices, lands, radiations, Earth system models and interface
computations. The package name is the disclosure.

Its own remaining source is: named ocean configurations by resolution and grid
family (a one-degree, half-degree, sixth-degree and tenth-degree tripolar ocean, a
latitude-longitude ocean, an ORCA ocean) with matching sea-ice configurations; an
Ocean Model Intercomparison Project simulation driver with its diagnostics; a
strait-transport diagnostic with named sections; an initial-condition tracer
diffuser; a download helper with a fallback mirror; and two vertical mixing
schemes translated from other Earth models, a K-profile parameterisation following
Large, McWilliams and Doney as implemented in MITgcm, and the NEMO turbulent
kinetic energy closure.

**Is anything usable when the ocean is not Oceananigans.** Essentially nothing of
the code. Every kernel in the two mixing-scheme directories imports Oceananigans
by name and by symbol: the interpolation and vertical derivative operators, the
vertical spacing accessor, `Field`, `Center` and `Face`, the boundary-condition
getter, the Coriolis parameter at a vertex location, and the static column depth
at a cell centre. The configurations are grid constructors. The data wrangling is
Earth reanalysis by product name. Remove Oceananigans and there is no residue.

One artefact is usable as a *document* rather than as code, and it is the only
thing in this package worth carrying away. `KPPParameters` is a flat struct of
named coefficients with keyword defaults, sectioned by comment into boundary-layer
depth, velocity scales, Monin-Obukhov universal functions for momentum, the same
for scalars, interior shear instability, an internal-wave background (annotated
with the MITgcm variable names it was taken from), interior convective
instability, nonlocal transport, and two numerical safeguards. Reading it
separates, in one place, which of the K-profile numbers are dimensionless (a
critical Richardson number and an asymptotic interior one, the surface-layer
fraction, the universal-function coefficients and matching stabilities, the
nonlocal transport coefficient, the Stokes-drift coefficient, and yet another von
Karman constant) from which are dimensional and fitted to Earth's ocean (the
shear-instability maximum viscosity and diffusivity, the internal-wave background
viscosity and diffusivity, the convective viscosity and diffusivity, and the
stratification threshold at which convection is declared). Decision 0017 already
requires exactly that separation, with the dimensionless numbers `Sourced` and
every dimensional interior diffusivity a `Closure` in the resolved shear and
stratification with a `Bracketed` coefficient. The struct is a useful
line-by-line checklist against which to confirm that separation was made
completely, and nothing more. Note also that its von Karman constant is a third
independent copy of that number in this ecosystem, alongside
`SurfaceFluxes.SurfaceFluxesParameters` and whatever the atmosphere holds; C5's
"name the authoritative copy" has no answer here.

**Assumptions it carries, checked item by item.**

| item | finding |
| --- | --- |
| A1, calendar | the Gregorian calendar throughout the forcing path: JRA55, ECCO, GLORYS and EN4 are date-indexed Earth products and the simulation driver is written to them |
| A2, planetary constants | none of its own; it inherits Oceananigans' mutable global defaults object with Earth's gravity, radius and rotation rate |
| A3, Earth literals | clean negative for literals in its own source; the Earth content is in dataset names and in named resolutions, which is heavier |
| A6, grid and index base | tripolar and latitude-longitude grids named in the exported function names, with the resolution in degrees in the name. Structured, one-based, Oceananigans' halo conventions |
| precision | inherited from Oceananigans' mutable default float type |
| threading and GPU | inherited: KernelAbstractions, CUDA, MPI through Oceananigans |
| mutable global state | inherited: Oceananigans' defaults object. Its own out-of-band state is the download cache, reached through a helper with a fallback mirror, which makes a run depend on network reachability of Earth datasets |
| B4, comment against value | the K-profile parameter file states in its first line that the defaults are calibrated Large 1994 and MITgcm values; comment and provenance agree |
| B5, clamps and limiters | two are declared as such on the parameter struct, a minimum boundary-layer depth and a minimum friction velocity, plus a boolean that limits the boundary-layer depth in stable conditions. Decision 0017 forbids a friction-velocity floor in the sea-ice basal exchange for the same reason it is suspect here: a floor with no refusal is a fail-open |
| C1, use site per constant | read for the K-profile coefficients; the NEMO closure was read shallowly |
| C3, declared against demonstrated | no non-Earth capability is declared. The whole package is the demonstration of one planet |
| C4, fail-open branches | the download-with-fallback path substitutes a mirror silently; the two minima above substitute silently |
| C5, second copies | a von Karman constant independent of the one in `SurfaceFluxes`, as above |
| D2, boundary field by field | the interface computations are re-exported from `NumericalEarth` and were not read; the boundary is not this project's concern because nothing here is adoptable |
| D4, conservation identity | the strait-transport diagnostic is a transport budget with a right answer in advance, but it is a diagnostic of an Earth configuration, not a portable identity |

**Where it is Earth-fitted in its data but general in its code.** The question does
not really apply: this package *is* the Earth data half of an ocean model, by
design and by the name of the package it now depends on. The general half lives
upstream in Oceananigans and is recorded there.

**Licence.** MIT. **Version.** 0.10.0, read against commit
`940e551532aaaea8995e83ac5a2eddc799054119` on `main`, dated 2026-06-03. Read
deeply in `src/ClimaOcean.jl` and the K-profile parameter and boundary-layer
files; read shallowly in the NEMO turbulent-kinetic-energy files, the ocean and
sea-ice configuration files and the simulation driver, each of which was checked
for what it depends on rather than for its physics. `NumericalEarth.jl` itself was
not read; the re-export list is the evidence for what it carries, and a separate
record would be needed before anything there could be judged.

**Verdict: do not adopt.** It is a set of Earth configurations and Earth dataset
readers over Oceananigans, with no component that survives the removal of
Oceananigans; the only durable value in it is the K-profile parameter struct read
as a checklist of which mixing-scheme numbers are dimensionless and which are
dimensional Earth-ocean fits, which decision 0017 already requires to be separated.
