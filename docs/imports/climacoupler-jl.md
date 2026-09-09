# ClimaCoupler.jl

**What it is.** The driver that runs CliMA's atmosphere, land, ocean and sea ice
models together in one Julia process: a component interface of getters and
setters keyed by symbol, a field-exchange step, a turbulent-flux calculator that
the coupler owns, area-fraction bookkeeping across surfaces, a checkpointer, a
diagnostics handler, and a global energy and water conservation check.

**What of it is used.** Nothing. This is a survey record. It is surveyed because
decision 0009 fixes how this project couples components, and ClimaCoupler.jl is
the nearest thing in the ecosystem to that design: one process, sequential
components, exchange in memory rather than through files. The shapes are close
enough that the differences are the interesting part.

## The question, answered

**Does it admit one writer per quantity?** No, and it does not try to. Coupler
state is a single `ClimaCore` `Field` of `NamedTuple` on a two-dimensional
boundary space, allocated in `Interfacer.init_coupler_fields` from a flat list of
symbols returned by `Interfacer.default_coupler_fields()`. Every entry is a
scalar of the run's float type. Nothing in the type records who writes a given
entry; ownership is whatever the sequence of calls in `SimCoordinator.step!`
happens to produce. A component contributes by extending `get_field(sim,
Val(:name))` and `update_field!(sim, Val(:name), value)`, and `FieldExchanger`
pulls and pushes by name. The one place ownership is actually contested,
`FieldExchanger.update_surface_fractions!`, resolves it by precedence rather than
by declaration: if the ocean model can supply all three area fractions it does,
and otherwise the fractions are derived from the land fraction and the ice
concentration. There is no assembly-time check of the kind decision 0009 requires,
no read-write graph, and therefore no cycle detection and no lagged-edge
declaration; the intra-step order is written out longhand in `step!`.

**Does it assume its own component set and its own field names?** Both. The
component taxonomy is baked into the type hierarchy:
`AbstractAtmosSimulation`, `AbstractSurfaceSimulation` and, under the latter,
`AbstractLandSimulation`, `AbstractOceanSimulation` and `AbstractSeaIceSimulation`,
with `AbstractImplicitFluxSimulation` beside them. `ConservationChecker` and
`FieldExchanger` dispatch on exactly these; a component that is not an
atmosphere and not a surface contributes nothing to either. The constructor
enumerates the four slots by name, offers `:bucket`, `:integrated` or `:nothing`
for land, `:oceananigans`, `:slab`, `:prescribed` or `:nothing` for ocean,
`:clima_seaice`, `:prescribed` or `:nothing` for sea ice, and notes that the
atmosphere cannot be nothing.

The field names are the second half. `default_coupler_fields()` is a hard-coded
list of about twenty-six symbols including `land_area_fraction`,
`ocean_area_fraction`, `ice_area_fraction`, `T_atmos`, `q_tot_atmos`,
`q_liq_atmos`, `q_ice_atmos`, `rho_atmos`, `height_int`, `height_sfc`,
`height_delta`, `u_int`, `v_int`, `F_lh`, `F_sh`, `F_turb_moisture`, two
turbulent momentum-flux components, `SW_d`, `LW_d`, `emissivity`, `T_sfc`,
`P_liq`, `P_snow`, and four scratch scalars named `scalar_temp1` through
`scalar_temp4`. The set is extensible: `add_coupler_fields!` lets a component add
its own, and `init_coupler_fields` deduplicates. But the defaults encode one
planet's surface: three phases of water in the atmosphere, liquid and snow
precipitation, a land-ocean-ice partition, two shortwave albedos and one
broadband emissivity. Names are `Symbol`s and correctness of the name is not
checked anywhere: the required-field list for an atmosphere in `Interfacer.jl`
contains `Val{:turblent_energy_flux}`, a misspelling of the name used everywhere
else, so that arm of the intended error fallback is dead and the generic fallback
catches the case instead. A stringly-typed exchange surface with no declaration
is exactly what that typo demonstrates.

**What does it do about conservation, and is it separable?** `ConservationChecker`
is a small, self-contained module and would be separable if it were worth
separating. It is not, on this project's terms. It keeps two mutable structs,
`EnergyConservationCheck` and `WaterConservationCheck`, each holding a `sums`
`NamedTuple` of per-component histories plus a running total, and
`check_conservation!` appends one entry per call. Three things are wrong for
decision 0009:

- It is a drift check on endpoints, not a ledger on an exchange. The test is
  `abs((total[end] - total[1]) / total[end]) < 1e-4`. It compares the current
  global total against the first one ever recorded. It cannot say which crossing
  leaked, and it cannot classify the residual's time signature into a leak, an
  omitted stock or rounding, because it never resolves the residual per exchange.
- The tolerance is chosen, not derived. `1e-4` is a literal in both branches, a
  relative threshold with no relation to the number of terms summed, the machine
  epsilon or the magnitudes involved. Decision 0009 derives a ledger tolerance
  from floating point and refuses to choose one.
- It fails open. In the energy check, for a surface component,
  `if isnothing(get_field(sim, Val(:energy)))` sets that component's contribution
  to zero and continues; the component still counts in the total, contributing
  nothing, and the assertion still passes. The fallback that makes this reachable
  is in `Interfacer.jl`: `get_field(::AbstractComponentSimulation, ::Val{:energy})
  = nothing` and the same for `:water`. The water check's version of the branch is
  worse than zero: it substitutes the integral of net precipitation minus
  evaporation over the component's area fraction for the stock it could not read.
  A component that does not report its water is credited with the flux instead.

The assertion is also conditional twice over: it fires only when
`check_conservation!` is called with `runtime_check = true`, and `SimCoordinator`
calls it only in the slabplanet configurations. In the configuration with a real
ocean and a real land model the check accumulates numbers for a plot and asserts
nothing.

## Assumptions it carries

| assumption | present | how a leak would be caught here |
| --- | --- | --- |
| Earth defaults | in the field names and the component taxonomy rather than in numbers: three water phases, snow, a land-ocean-seaice partition. Numerically the coupler holds no planetary constant of its own; it carries a `thermo_params` and hands physics to `Thermodynamics.jl`, `SurfaceFluxes.jl` and `Insolation.jl`, each surveyed separately | n/a; not adopted |
| calendar or time | yes, unavoidably. `CoupledSimulation` carries a `start_date`; `TimeManager` mixes `Dates.DateTime`, `Dates.Period`, `ClimaUtilities.ITime` and float seconds, and `EveryCalendarDtSchedule` exists precisely so a callback can fire on a calendar month, which requires a Gregorian calendar. `365.25` days per year appears in `simulated_years_per_day` and `86400` seconds per day in `compact_time_str`, both in reporting rather than in physics, but both are statements of a day and a year (A1) | n/a; decision 0008 has one clock in SI seconds and no calendar below the render layer |
| grid or mesh | yes. Every coupler field lives on a `ClimaCore.Spaces.AbstractSpace` boundary space, in practice the cubed-sphere surface of `ClimaAtmos`; `Interfacer.remap!` moves fields between component spaces. Decision 0012 already refuses the cubed sphere, and the coupler is not usable without it | n/a |
| index base | 1-based Julia throughout; no on-disk index crosses this boundary | n/a; clean negative |
| precision | parameterised on `FT` at the `CoupledSimulation` type; `init_coupler_fields` builds every entry at that type. A clean negative | n/a |
| threading and GPU | `ClimaComms` device and context, MPI-aware, GPU-capable; the coupler itself does no kernel work, it broadcasts over `ClimaCore` fields. Decision 0009 does not want distributed memory, so the MPI machinery is surface area with no use here | n/a |
| mutable global state | the conservation-check structs are `mutable struct` holding growing vectors, and the schedules in `ClimaDiagnostics` that the coupler uses are documented as stateful and not reusable across simulations. Not global, but stateful in a way that makes two simulations in one process interfere if a schedule object is shared | n/a |
| fail-open branches | three, all recorded above: `get_field(..., Val(:energy)) = nothing` and its `Val(:water)` twin feeding the zero-contribution and the flux-substitution branches of the conservation check; `update_field_warning`, which emits a warning at `maxlog = 1` and skips the update when a component does not extend `update_field!` for a name the coupler pushes; and `get_field(::AbstractSurfaceSimulation, ::Val{:emissivity}) = 1.0`, a blackbody default supplied silently across a component boundary. The last is exactly the pattern decision 0009's "no silent default across a component boundary" exists to refuse | n/a |
| clamps and limiters | `update_surface_fractions!` asserts that land, ocean and ice fractions sum to one at every point, which is a real conservation identity and the one place the module refuses rather than warns (B5, D4) | n/a |

## What is worth carrying anyway

Three ideas, none of them code.

- `get_field_error`. The generic fallback `get_field(sim, val::Val{X}) = error(
  "undefined field ... for ...")`, with the required names listed explicitly per
  component kind so the error names the field and the component. This is the
  right instinct, and decision 0009 does the same job earlier and better by
  checking at `assemble` rather than at first read.
- `add_coupler_fields!`. A component declaring the extra quantities it needs the
  exchange to carry, rather than the exchange enumerating them. Decision 0009's
  read and write declarations subsume this and add the level and the coarsening
  operator, which ClimaCoupler has no analogue of; it remaps with a fixed
  `remap!` and the operator is not part of any declaration.
- The `flux_accumulators` slot. The coupler accumulates fluxes over a coupling
  interval rather than sampling them at the endpoints, which is what closing a
  ledger over an `Interval{t0, t1}` requires.

**Licence.** Apache 2.0. **Version.** Read against `main` at version 0.2.3,
2026-09-09. Nothing is pinned; nothing is adopted.

**Checklist items applied.** A1: `365.25` and `86400` in `TimeManager`, both in
reporting; the `start_date` on `CoupledSimulation` and the `Dates.Period`
schedules; recorded. A2: no planetary constant block of its own; constants are
delegated to `thermo_params` and the surveyed physics packages. A3: no Earth
literal from the grep list in the used surface; clean negative. A6: the boundary
space is a `ClimaCore` space and every field is bound to it; the rebuild trigger
is the whole grid. B4: the `1e-4` in `ConservationChecker` carries no comment
justifying it; the `isnothing` branches carry comments describing what they do
and not that they weaken the check. B5: the area-fraction sum assertion.
C1: `1e-4` read at both use sites; both are the same endpoint-drift test.
C3: global conservation is a declared capability with a test
(`test/conservation_checker_tests.jl`) but the shipped configuration only asserts
it in slabplanet mode, so the demonstrated capability is narrower than the
declared one. C4: the three fail-open branches above. C5: coupler fields and
component state are two live copies of the same quantities, synchronised by
`import_atmos_fields!` and `update_model_sims!`; the coupler field is
authoritative only between those two calls and nothing records which is
authoritative when. D2: the boundary is a flat symbol-keyed `NamedTuple` of
scalars with no units, no support identity, no interval and no owner attached to
any entry; nothing is checked on either side. D4: the only identity with a right
answer in advance is the area-fraction sum, which does refuse.

**Verdict: do not adopt.** Its exchange is a flat, symbol-keyed record of one
planet's surface quantities on a cubed-sphere boundary space with no declared
writer, and its conservation check is an endpoint drift test against a chosen
tolerance that credits a component reporting no stock with zero or with a flux,
which is fail-open at exactly the place decision 0009 requires a refusal.

**Nothing here needs a new decision.** Decision 0009 already states the design
this record measures ClimaCoupler against, and the measurement is that the two
differ on ownership, on ledger granularity and on tolerance derivation rather
than on any point the decision left open. The one thing this record adds is
evidence for decision 0009's `assemble` check: the misspelled
`Val{:turblent_energy_flux}` in the upstream required-field list is what a
stringly-typed exchange surface costs, and an assembly-time graph over declared
reads and writes would have refused it at construction.
