# CloudMicrophysics.jl

*Julia identifiers are transliterated to ASCII below where the source spells them
with Greek letters.*

**What it is.** A library of cloud and precipitation parameterisations: a zero-,
one- and two-moment bulk scheme, a non-equilibrium condensation scheme, the P3
predicted-particle-properties scheme, aerosol activation, homogeneous and
heterogeneous ice nucleation, and aerosol nucleation. It holds no grid and no
state; every function takes a parameter struct and scalar state and returns a
tendency.

**What of it is used.** Nothing. This project builds its own microphysics under
decision 0016, reading gas properties from REQ-ATM-017.

**Is the scheme parameterised by struct.** Yes, and the layout is the strongest
thing in the package. `src/parameters/` holds one file and one `@kwdef` struct per
scheme, each with a second constructor taking a `ClimaParams` dictionary and an
explicit name map from TOML keys to struct fields, so the wiring between a named
constant and the field it lands in is written out in one place and can be read.
Terminal velocity is a type (`Blk1MVelTypeRain`, `Blk1MVelTypeSnow`,
`StokesRegimeVelType`, `SB2006VelType`, and four `Chen2022VelType` variants) that
dispatch selects; so are the aerosol species, the ice-nucleation modes and the
size distributions. This is the shape decision 0016 wants for a composable column.

**Is the condensable by declaration or by hard-coding.** By hard-coding, at the
level of vocabulary rather than of a literal. `src/ThermodynamicsInterface.jl` is
the single door through which the whole package reaches thermodynamics, and every
member of it names water: the vapour gas constant, the freezing temperature, the
latent heats of vaporisation, sublimation and fusion, the liquid and ice heat
capacities, `saturation_vapor_pressure_over_liquid` and `..._over_ice`,
`liquid_fraction`, `internal_energy_liquid`, `internal_energy_ice`, and the phase
tags `TD.Liquid()` and `TD.Ice()` passed into `Thermodynamics.jl`.
`WaterProperties` holds exactly two fields, the liquid and ice densities. The
Koehler activation, the ice-nucleation water-activity parameterisations and the
P3 mass-size relations are water-phase physics by construction, not by
configuration. There is no species index anywhere.

**What a different condensable would require.** Not a configuration change. It
would require a new saturation curve, new latent heats as functions of
temperature, a new surface tension, new solid and liquid densities and heat
capacities, a new triple point, and a new set of ice-habit mass-size relations,
none of which is keyed by species. The interface itself would have to be rewritten
because its function names encode the phases of water. This is the same finding
REQ-ATM-017 records against this project's own founding documents, seen in a
mature package: the condensable was water everywhere by silence.

**Do fall speeds carry air density and gravity explicitly.** Two shapes, and the
difference between them is the useful result of this reading.

The one-moment rain fall speed carries them explicitly. `get_v0` for
`Blk1MVelTypeRain` returns the square root of eight times a density factor times
gravity times a length scale, divided by three times a drag coefficient, where the
density factor is the ratio of liquid density to air density less one. That is a
drag balance with gravity, both densities and the drag coefficient all visible; a
different gravity or a different bulk gas enters through terms the kernel already
has. Only the drag coefficient and the size-relation exponents are fits. The
Stokes-regime velocity has the same virtue, gravity over a viscosity times a
density contrast, but divides by the constant `nu_air` discussed below.

The Chen 2022 fall speeds, which are the default for the modern paths, do not.
`Chen2022_vel_coeffs` evaluates the published tables with air density appearing
inside an exponential, as a base raised to a fitted exponent, and subtracted
inside the exponent of the size power law; gravity does not appear at all, and the
returned coefficients are converted from millimetre units by raising a bare
thousand to the fitted exponent. The drag physics is absorbed into the fit, so
there is no term through which another gravity could enter. The one-moment snow
fall speed is the same in kind: `get_v0` for `Blk1MVelTypeSnow` simply returns a
fitted dimensional coefficient.

**Does autoconversion carry them explicitly.** No. The Seifert and Beheng scheme
carries a field named `SB2006_reference_air_density` on five separate parameter
structs, and autoconversion, accretion, cloud and rain self-collection and the
evaporation Reynolds number each scale by that reference density over the local
density, or by its square root. That is a fitted reference air density used as a
denominator, exactly the pattern decision 0018 names for the dust scheme and calls
an `EarthRatios` denominator rather than a constant of the kernel. The kinetic
coefficients themselves are dimensional fits with no density or gravity content at
all.

**The air-property finding, and why it bears on REQ-ATM-017.**
`src/parameters/AirProperties.jl` declares a struct of exactly three scalars: the
thermal conductivity of air, the diffusivity of water vapour, and the kinematic
viscosity of air. They are numbers, not functions of temperature and pressure.
`G_func_liquid` and `G_func_ice` in `src/Common.jl`, the condensation and
deposition growth coefficient on which activation and non-equilibrium growth rest,
divide by the first two. REQ-ATM-017 item 2 requires precisely these three as
`Derived` members of one property group evaluated from the declared composition at
the local temperature and pressure, and item 5 requires a refusal outside a
per-gas relation's range. Adopting this package would freeze all three at one
mixture at one state and pass a floor rather than a refusal when they are small.
`AerosolActivationParameters` compounds it: the surface tension of water is a
single scalar field rather than the temperature-dependent IAPWS function
REQ-ATM-017 item 3 names, alongside water's molar mass, the two condensate
densities and gravity.

**Assumptions it carries, checked item by item.**

| item | finding |
| --- | --- |
| A1, calendar | clean negative: no `Dates`, no day, no year, no epoch anywhere in `src/` |
| A2, planetary constants | gravity appears as a runtime field on `Blk1MVelTypeRain`, `StokesRegimeVelType` and `AerosolActivationParameters`, and is forwarded from `Thermodynamics` in the parcel model; each is settable, each defaults to Earth's through `ClimaParams` |
| A3, Earth literals | clean negative in `src/`: none of the gravity, radius, rotation, solar or pressure literals is present. The values live in `ClimaParams` and in `src/parameters/toml/` |
| A6, grid and index base | clean negative: no arrays, no indices, no grid; the package is pointwise and is driven from outside |
| precision | clean negative: `FT`-generic; `get_v0` even uses integer literals deliberately, with a comment, to avoid promoting to `Float64` |
| threading and GPU | clean negative: no `CUDA` or `KernelAbstractions` in `src/`; scalar `@inline` functions, with `test/gpu_tests.jl` and `test/gpu_clima_core_test.jl` upstream |
| mutable global state | clean negative in the tendency path. `src/ArtifactCalling.jl` uses `LazyArtifacts` to fetch emulator and calibration datasets, which is an out-of-band Earth data door, but it is outside the schemes |
| B4, comment against value | one live mismatch, and the package records it against itself: a `TODO` in the rain velocity constructor states that rain's length scale is mapped to the TOML key for the snow flake length scale, that the two agree numerically today, and that calibrating the rain key alone would leave rain fall speeds scaled by the snow value. A name hiding a condition, exactly as the review method warns |
| B5, clamps and limiters | numerical floors on the vapour diffusivity, the thermal conductivity and the saturation vapour pressure inside the growth coefficient; a floor on the density factor in `get_v0`; a clamp of vapour content to non-negative; a floor of air density at zero in the Chen coefficients; and a whole limiter file, `SB2006_limiters.toml` |
| C1, use site per constant | read for gravity in the one-moment and Stokes velocities, for the reference air density in autoconversion and accretion, and for the three air properties in the growth coefficient |
| C3, declared against demonstrated | the package's non-Earth capability is not declared at all; every shipped parameter file and every test is Earth's atmosphere |
| C4, fail-open branches | the floors above are silent substitutions with no refusal threshold. There is no branch that reports having substituted |
| C5, second copies | the liquid water density is a field on four separate structs (`WaterProperties`, `Blk1MVelTypeRain`, `StokesRegimeVelType`, `AerosolActivationParameters`), all filled from the same TOML key, none named authoritative. That is the predecessor's four copies of one quantity, in a package |
| D2, boundary field by field | units are given per field in the docstrings and the parameter structs; specific contents are per kilogram of moist air, which the caller must match |
| D4, conservation identity | `test/bulk_tendencies_tests.jl` and the moment-consistency tests check that the bulk tendencies are consistent between moments; the identity has a right answer in advance |

**Where it is Earth-fitted in its data but general in its code.** The one-moment
drag-balance fall speed and the parameter-struct layout are general code. The Chen
2022 tables, the Seifert and Beheng reference density, the three constant air
properties, and the whole water vocabulary are Earth in the code, not only in the
data, because there is no term through which another value could enter.

**Licence.** Apache 2.0. **Version.** 0.39, read against commit
`62003325953e63334bb6f77a9a34f34cf0b94ed6` on `main`, dated 2026-09-03. Read
deeply in `src/parameters/`, `src/Common.jl`, `src/Microphysics1M.jl`,
`src/Microphysics2M.jl` and `src/ThermodynamicsInterface.jl`; read shallowly in
`src/P3*.jl`, `src/IceNucleation.jl` and `src/Nucleation.jl`, which were checked
for the condensable question and not otherwise.

**Verdict: borrow ideas only.** The one struct per scheme with an explicit TOML
name map, and the one-moment fall speed written as a drag balance in gravity and
both densities, are both worth reproducing; but the condensable is water in the
function names rather than in a declaration, the modern fall speeds and the
autoconversion absorb gravity and a reference air density into fitted tables, and
the three air transport properties are scalars where REQ-ATM-017 requires a
`Derived` group.
