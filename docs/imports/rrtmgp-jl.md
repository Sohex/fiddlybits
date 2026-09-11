# RRTMGP.jl

**What it is.** The CliMA Julia port of RTE+RRTMGP: a correlated-k gas-optics
lookup evaluated per g-point, plus the radiative-transfer solvers that carry the
result through a column (two-stream shortwave, two-stream and non-scattering
longwave, and a single-band gray path that needs no tables). It is a column
solver: its whole spatial model is `(nlay, ncol)`.

**Why it was surveyed.** Decision 0016 generates this project's own
k-distribution per declared composition and per declared spectrum. The shipped
tables are Earth-fitted, but the two-stream machinery is not, so the only
question worth asking is whether the solver can be driven from tables generated
here. It can, and the record below names the path and the price.

## The table-loading path, by function and file

The solver never reads a file. `RRTMGPSolver` (`src/api/solver.jl`) takes a
keyword `lookups`; only when it is `nothing` does the constructor call
`lookup_tables(grid_params, radiation_method)`, and that function exists only in
the package extension `ext/RRTMGPNCDatasetsExt.jl`, which opens the artifact
files named by `ArtifactPaths.get_lookup_filename(:gas, :sw)` and passes the
NetCDF dataset to the constructors `LookUpLW(ds, FT, DA)` and
`LookUpSW(ds, FT, DA)` in `ext/lookup_constructors.jl`. Those constructors
produce plain immutable structs of arrays (`src/optics/LookUpTables.jl`) that are
then wrapped in a `LookupBundle` (`src/api/lookup_bundle.jl`).

So there are two doors. The NetCDF door demands the shipped Earth files by name
and asserts their Earth gas list. The struct door does not: a `LookupBundle`
built directly from `LookUpLW`/`LookUpSW` values that this project fills in
itself reaches the solver without NCDatasets, without the artifact, and without
either assertion, because both assertions live in the extension. The package
even documents that door: `save_lookup_tables`/`load_lookup_tables` serialise a
bundle for use "without NCDatasets".

## What a generated table must satisfy

The struct door is not free. `LookUpSW` and `LookUpLW` are not a bag of
coefficients; they are the RRTMGP correlated-k data model, and the kernels in
`src/optics/gas_optics.jl` require its shape:

- **Band and g-point structure is free.** `n_bnd`, `n_gpt`, `n_eta`, `n_p_ref`,
  `n_t_ref` are all read from array sizes (`get_n_bnd`, `get_n_gases`,
  `get_n_eta`). Nothing hard-codes 14 or 16 bands, 224 or 256 g-points. Band
  limits are carried as wavenumbers in `BandData.bnd_lims_wn` and a g-point to
  band map. This is the half that is general.
- **Exactly two major species per band per atmosphere half.**
  `key_species` is `(2, n_atmos_layers, n_bnd)` with `n_atmos_layers == 2`, and
  `compute_gas_optics_core` reads `tropo = p_lay > p_ref_tropo ? 1 : 2`, takes
  `ig = key_species[1:2, tropo, ibnd]`, and interpolates `kmajor` on the binary
  mixing parameter formed from those two. A generated table must be cast in that
  form: a lower and an upper atmosphere split at one declared pressure, and a
  major pair per band with a reference volume-mixing-ratio table `vmr_ref` on the
  same temperature axis. Decision 0016's equivalent-extinction overlap does not
  map onto this without being re-expressed.
- **Minor gases carry the RRTMGP scaling flags.** `LookUpMinor.gasdata` is four
  rows: minor gas index, scaling gas index, scales-with-density, and
  scale-by-complement, and `compute_tau_minor` applies
  `density_fact = 0.01 * p_lay / t_lay` (hectopascals per kelvin) and
  `dry_fact = 1 / (1 + vmr_h2o)`. That second factor is the water assumption in
  the kernel: the minor-gas scaling converts a wet mixing ratio to a dry one on
  the assumption that the condensable is the one non-dry constituent. A bulk
  composition in which the abundant variable species is not water gets the wrong
  scaling unless the generated minor entries are pre-corrected.
- **Water and ozone occupy fixed slots under the global-mean storage.**
  `get_vmr(::VmrGM, ig, ...)` in `src/optics/VolumeMixingRatios.jl` maps
  `ig == 1` to `vmr_h2o` and `ig == 3` to `vmr_o3` and treats every other index
  as a well-mixed scalar. This is a solver-side constant, not a loader-side one.
  The escape is the other storage type: `Vmr` holds `(ngas, nlay, ncol)` and has
  no fixed slot, so a declared composition with an arbitrary gas list must use
  `Vmr` and never `VmrGM`. `LookUpLW.idx_h2o` is still consulted once per point,
  in `compute_gas_optics_core`, to fetch the water mixing ratio for the minor
  scaling above; a table with no water must still point that index somewhere.
- **The shortwave source must be spectrally resolved but is scaled by the
  caller.** `LookUpSW.solar_src_scaled` is the per-g-point fraction of the total,
  normalised at load time; `LookUpSW.solar_src_tot` is carried but is not what
  the solver uses. `rte_sw_2stream!` computes
  `flux_dn_dir_top = bcs_sw.toa_flux[gcol] * solar_frac * cos_zenith[gcol]`, and
  `toa_flux` is a per-column caller-supplied array in `SwBCs`
  (`src/optics/BCs.jl`). So the instellation is the caller's, per column, and
  only the spectral shape comes from the table. This is the cleanest thing in
  the package for this project's purposes.
- **Rayleigh is data, not code.** `compute_tau_rayleigh` interpolates
  `rayl_lower`/`rayl_upper` from the table and multiplies by
  `(vmr_h2o + 1) * col_dry`. There is no air-fitted Rayleigh formula in the
  solver; decision 0016 item 4 computes the cross-sections from refractive-index
  dispersion and would supply them here. The one residual assumption is again
  that water is the single correction to the dry column.

## Where the shipped-data path welds Earth in

These are all in the NetCDF door, and all of them are avoided by the struct door,
but they are worth recording because they are what a naive adoption would hit:

- `_assert_canonical_gas_slots` (`ext/lookup_constructors.jl`) refuses to load a
  table unless `idx_gases["h2o"] == 1` and `idx_gases["o3"] == 3`, by name.
- `RRTMGPNCDatasetsExt.lookup_tables` asserts
  `sort(keys(idx_gases_sw)) == sort(RRTMGP.gas_names_sw())`, and
  `gas_names_sw()` (`src/api/getters.jl`) is a literal list of twenty-one Earth
  species: h2o, cfc11, h2o_self, co2, cfc12, hfc134a, cfc22, ch4, hfc23, ccl4,
  hfc143a, co, no2, n2, o2, o3, h2o_frgn, hfc32, n2o, cf4, hfc125. A shortwave
  table with a different gas list is refused at load.
- The shortwave solar source is not read; it is reconstructed from a solar-cycle
  model of one star:
  `solar_source_quiet + (mg_index - 0.1495954) * solar_source_facular +
  (sb_index - 0.00066696) * solar_source_sunspot`, with the two offsets as
  literals and the two indices read from `mg_default` and `sb_default` in the
  file. A generated table would have to carry three source arrays and two index
  scalars purely to satisfy this arithmetic, or bypass the loader.
- The longwave loader refuses a file whose `temperature_Planck` axis does not lie
  between 100 and 500 kelvin, which is a guard against a real upstream defect but
  is also a declared temperature envelope.
- The MERRA aerosol table is a fixed name-to-index map of terrestrial aerosol
  species (dust bins, sea salt bins, sulfate, black and organic carbon), asserted
  against `RRTMGP.aerosol_index_map()`.

## Earth in the solver itself

Less than expected, but not none:

- **`compute_col_gas_kernel!`** (`src/optics/gas_optics.jl`) computes the column
  amount from the hydrostatic relation with
  `g0 = helmert1 - helmert2 * cos(2 * pi * lat / 180)` where
  `helmert2 = 0.02586` is a literal and `helmert1` is `grav` from the parameter
  set. That is the Helmert latitude formula for one planet's gravity field,
  welded into a kernel; it fires whenever a latitude array is passed, and is
  bypassed only by passing `lat = nothing`. The moist molar mass in the same
  kernel is `mol_m_dry + mol_m_h2o * vmr_h2o`, one condensable in one bulk.
- **`compute_relative_humidity_kernel!`** uses the Magnus form with 17.67,
  29.65, 0.263 and a reference temperature of 273.16 kelvin: a water-in-air
  saturation fit inside the library. It feeds only the relative-humidity-
  dependent aerosol optics, and the docstring makes computing it the host's
  responsibility, so it can be left uncalled.
- **`default_parameters(FT)`** (`src/api/standalone.jl`) returns gravity 9.81,
  dry-air molar mass 0.02897 and water molar mass 0.018015 as literals; the
  `ClimaParams` extension reads the same seven quantities from a TOML dictionary
  whose defaults are the same body. `RRTMGPParameters` itself is a plain struct
  of seven fields, so it can simply be constructed from the declared system.
- **`solve_gray`** defaults `toa_flux = 1361`, `surface_pressure = 1.0e5`,
  `top_pressure = 9.0e3`, `surface_albedo = 0.2`, and an optical-thickness
  parameterisation fitted to one atmosphere
  (`GrayOpticalThicknessOGorman2008`, defaults 7.2 at the equator and 1.8 at the
  poles; `GrayOpticalThicknessSchneider2004` defaults 300 kelvin surface and a
  60 kelvin equator-to-pole contrast). `AtmosphereProfile` defaults
  `p_sfc = 101325.0` and `z_top = 45.0e3`. All are convenience front doors,
  all are keyword-overridable, and none is reached by the `RRTMGPSolver`
  constructor.
- **No solar constant in the solver.** `1361` appears only as the `solve_gray`
  and `solve` keyword default; the two-stream kernels contain no irradiance.
- **No radius.** Deep-atmosphere geometry enters as
  `deep_atmosphere_inverse_scaling`, an `(nlev, ncol)` array the host supplies.
- **No pressure range in code.** The range is the table's: `p_ref_min` and
  `t_ref_min`/`t_ref_max` are fields read off the loaded table.
- The two-stream coefficients themselves are clean: `sw_2stream_coeffs` is
  Zdunkowski PIFM with Meador and Weaver's direct-beam solution, and
  `lw_2stream_coeffs` uses the Fu et al. diffusivity secant 1.66. Both are
  angular approximations of the transfer equation, not planetary fits.

## Assumptions it carries

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | in the shipped data and in the `solve_gray`, `AtmosphereProfile` and `default_parameters` front doors; the Helmert latitude-gravity literal and the Magnus saturation fit are the two in kernels | this project would construct `RRTMGPParameters` from the declared system, pass `lat = nothing`, and never call `compute_relative_humidity!`; a lint on the used surface would assert none of `solve_gray`, `solve`, `AtmosphereProfile` or `default_parameters` is called |
| calendar or time | none; the solver has no clock and no time argument | n/a |
| grid or mesh | none horizontally: `RRTMGPGridParams` carries `nlay`, `ncol` and a device only, and the column index is opaque | n/a; the mesh stays on this side of the boundary |
| index base | 1-based throughout; gas indices, band and g-point limits are 1-based, and `key_species` is offset by one against `vmr_ref` inside `compute_interp_frac_eta` | any generated table has to be written in the same base; an assertion that a generated `bnd_lims_gpt` covers `1:n_gpt` exactly once |
| precision | `FT` is a type parameter end to end; `float32_consistency.jl` upstream compares Float32 against Float64 broadband fluxes at a ratcheted threshold | this project's own FP32 certification would extend to the radiation path |
| threading and GPU model | `ClimaComms.@threaded` over columns on the CPU, and hand-written CUDA kernels in `ext/cuda`; not KernelAbstractions, so no CPU-GPU kernel identity and NVIDIA only | this project's reference-path comparison per kernel does not exist upstream and would have to be built here |
| mutable global state | `_get_artifact_path()` resolves a package-global Julia artifact; nothing else | not reached on the struct door |
| fail-open branches | `clip!` (`src/api/grid_adaptation.jl`) silently clamps every layer and level temperature into `[t_ref_min, t_ref_max]` and every pressure up to `p_ref_min`, with no refusal and no report; `compute_interp_frac_press` additionally clamps the pressure index into range; `compute_interp_frac_eta` substitutes 0.5 for the mixing parameter when the column mixture is non-positive | a state outside the generated table's range must refuse, not clamp; this is the single most important thing to wrap if the solver is ever adopted |

## Checklist items applied

**A1** none: no day, no year, no calendar anywhere in the tree. **A2** one
parameter block, `RRTMGPParameters`, seven members, every one a runtime field
with an Earth literal only in `default_parameters`. **A3** the Earth-literal grep
finds `1361` (four sites, all `solve_gray`/`solve` keyword defaults), `101325`
(two sites, `AtmosphereProfile`), and `9.81` (one site, `default_parameters`);
`6371`, `6.371e6` and `7.2921e-5` are absent, and the notable literal the grep
does not catch is `helmert2 = 0.02586`. **A6** no compile-time grid bound; the
one structural bound is `n_atmos_layers == 2`, which is the correlated-k data
model rather than a grid. **B4** the comment beside `helmert2` says "second
constant of Helmert formula" and the value matches that formula, so intent and
value agree and the problem is the formula, not the comment; the comment beside
`solar_src_tot` says "Total solar irradiation" and the field is in fact unused by
the solvers, which is a comment that overstates. **B5** the limiters are the
temperature and pressure clamps of `clip!`, the pressure-index clamp, the
mixing-parameter substitution, the `k_min` and `resonance_window` floors in the
two-stream coefficients (numerical, documented, and defensible), and the
direct-beam energy rescaling `Rdir + Tdir <= 1 - T0`. **C1** every carried
constant above has a use site read. **C3** the capability this project would
depend on, driving the solver from an externally built `LookupBundle`, is
declared (the `lookups` keyword, `save_lookup_tables`, the extension boundary)
but is not demonstrated: every test in `test/` builds its bundle from the shipped
artifacts, and there is no upstream test of a table with a different gas list,
band count or reference-pressure split. That test would have to be written here.
**C4** the clamps above are the fail-open branches, and they are the reason a
generated table cannot simply be handed over. **C5** the authoritative copy of
the gas list is the loaded table's `idx_gases` map; `gas_names_sw()` is a second
copy, and the extension asserts them equal, which is the right shape but pins the
one list. **D2** the boundary is read field by field: states are `(nlay, ncol)`
and fluxes are `(ncol, nlev)`, so the two are transposed with respect to each
other, and pressures are pascals, wavenumbers are per centimetre, column amounts
are molecules per square centimetre, and cloud extinction is square metres per
gram. Every one of those is a place a unit can hide. **D4** the identity with a
right answer in advance is the gray-atmosphere analytic solution, which the
package already runs with no tables at all, plus energy closure across the column
under a non-scattering longwave solve.

**Licence.** Apache 2.0, with the original RTE+RRTMGP Fortran carried under
BSD 3-Clause (`LICENSE_original`, Atmospheric and Environmental Research and the
Regents of the University of Colorado). Both are compatible with use here;
neither permits vendoring without carrying the notices.

**Version.** Read against `main` at commit
`f174987dab6ff605d274f83c74f5dc2c7a4234ae` (2026-09-01), `Project.toml`
version 1.0.0. Shipped data is Pincus et al., RRTMGP data version 1.9.

## Verdict

**Borrow ideas only.** The two-stream solvers and the correlated-k evaluation are
genuinely general and the caller supplies the instellation, but the lookup struct
is the RRTMGP data model rather than a table format, the minor-gas and
column-amount kernels assume water is the one variable species, and the
out-of-range behaviour is a silent clamp where this project must refuse; the
ideas to carry are the shape of the g-point loop, the separation of the
per-g-point spectral fraction from the caller's total flux, and the two-stream
coefficient forms with their numerical guards.

Should a later decision reverse this and adopt the solver as infrastructure, it
would need: a decision recording that the k-distribution generator of 0016 emits
the RRTMGP two-major-species-per-band form with a declared troposphere split, a
wrapper that refuses rather than clamps outside the generated table's pressure
and temperature range, `Vmr` storage rather than `VmrGM` so no gas slot is fixed,
`lat = nothing` so the Helmert formula never fires, and the named tests
`test/radiation/generated_table_roundtrip.jl` (a bundle built here drives the
solver and reproduces the gray analytic answer at the single-band limit),
`test/radiation/out_of_range_refuses.jl` (a state outside the table refuses
rather than clamping, with the positive control that an in-range state passes),
and `test/lint/lint_rrtmgp_front_doors.jl` (no call reaches `solve_gray`,
`solve`, `AtmosphereProfile`, `default_parameters` or `compute_relative_humidity!`).
