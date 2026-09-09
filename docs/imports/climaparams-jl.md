# ClimaParams.jl

**What it is.** A single flat TOML file of physical constants and model
parameters, plus a thin reader that types the values, merges override files over
the defaults, and records which parameters were read. Decision 0012 already names
it as the origin of the read-logging idea behind decision 0007's tracking
wrapper, and lists its default-plus-override shape as the implicit-Earth pattern
this project refuses. This record checks both claims against the source.

**Read against.** Commit `300c657aeed040f7b6d21b09c1fd8f4599eb5014` on `main`,
`Project.toml` version 1.1.9, read 2026-09-09. Files read in full or in the
relevant part: `src/ClimaParams.jl` (the whole package is this one module),
`src/parameters.toml`, `docs/src/toml.md`, `docs/src/param_retrieval.md`,
`test/toml_consistency.jl`, `test/toml_format.jl`.

**What of it would be used.** Nothing. It is surveyed for its design, and
because Thermodynamics.jl reaches it through a package extension, so any
adoption there would pull it in.

## The read-logging design, and what it is not

**What it actually records.** `ParamDict{FT}` holds two dictionaries: `data`,
the merged defaults and overrides with their metadata, and `override_dict`,
kept for tracking. Every read goes through `log_component!(pd, names,
component)`, which mutates the entry in place:

    data[key]["used_in"] = unique([data[key]["used_in"]..., component])

`component` is a free-form string the caller passes. `Base.getindex` logs the
string `"getindex"`. `get_parameter_values(toml_dict, name_map, "Thermodynamics")`
logs the string `"Thermodynamics"` against each name in the map.
`write_log_file` then writes out every entry that has acquired a `"used_in"` key,
and the result is itself a valid parameter file that can be fed back as an
override to reproduce the run.

**How it differs from the tracking wrapper decision 0007 wants, in four ways.**

1. *It logs the construction, not the run.* The read happens once, when a
   component's parameter struct is built. Thermodynamics.jl's
   `ext/CreateParametersExt.jl` makes one `get_parameter_values` call with a
   26-entry name map and copies all 26 values into an immutable struct; every
   subsequent read is a field access on that struct and is invisible to
   ClimaParams. Decision 0007's wrapper "logs every field access during a dry
   run of each component on a tiny mesh", which is a measurement of what the
   kernels actually touch. ClimaParams measures what a constructor asked for.
2. *There is nothing to be a subset of.* Decision 0007's test is `recorded is a
   subset of declared`. Under ClimaParams the recorded set and the declared set
   are the same object: the name map is both the declaration and the thing that
   does the reading, so the test is true by construction and cannot fail. That
   is the "a check that cannot fail is not a check" rule, and it is the reason
   this project's wrapper has to sit below the parameter struct rather than at
   it.
3. *The component identity is a string, not a type.* Nothing connects
   `"Thermodynamics"` to a component, and two components can log the same
   string. Decision 0010 computes artifact keys from declared dependency sets,
   which needs the component identity to be the thing the build knows about.
4. *The check runs in one direction only.* `check_override_parameter_usage`
   finds override keys that were never read, which catches a typo in an override
   file. There is no check anywhere that a component read a parameter it did not
   declare, and none that a value came from an override rather than a default.

**The whole mechanism is opt-in and warns rather than refuses.**
`log_parameter_information(pd, filepath; strict::Bool = false)` is the entry
point, it is called by nothing inside the package, and its default is to `@warn`
on an unused override rather than error. A run that never calls it produces no
record at all and no complaint. That is a fail-open branch by decision 0007's
standard (C4), and it is the second reason the idea has to be rebuilt here
rather than imported: this project needs the record to be a test that runs, not
a file a careful operator remembers to write.

**Reading mutates.** `log_component!` writes into `pd.data` on every read, so
`toml_dict["planet_radius"]` is a mutation. There is no lock and no
documentation of thread safety. The dictionary is a host-side setup object and
never reaches a kernel, so this is contained; but it means a parameter read is
not a pure function and cannot be one.

## Where the values come from, and the silent default

**One flat global namespace, shipped with the package.** `create_toml_dict(FT)`
defaults `default_file` to `joinpath(@__DIR__, "parameters.toml")`, the file
bundled inside the package. That file holds 678 parameters in a single flat
namespace with no sections in the TOML sense; names must be globally unique
across every CliMA component, from `universal_gas_constant` to
`michaelis_constant_for_oxygen`. `create_toml_dict(FT)` with no override
argument returns the complete default set and warns about nothing.

**It defaults to Earth, and says so.** The file's own section comment reads
`## Planetary and Orbital Parameters (Earth Defaults)`, and the block under it
carries `planet_radius = 6371000`, `day = 86400`,
`angular_velocity_planet_rotation = 7.2921159e-5`,
`gravitational_acceleration = 9.81`, and `mean_sea_level_pressure = 101325`.
The thermodynamic block carries `gas_constant_dry_air = 287.0`,
`isobaric_specific_heat_dry_air = 1004.5` and `gas_constant_vapor = 461.5`.
Every one of these is supplied to any caller who names nothing. This is the
implicit-Earth pattern in its clearest form: a default that nothing declares,
reaching a component that never asked whether it was on Earth. Decision 0012's
verdict on this point is confirmed by the source.

**Yes, it could silently supply a default this project forbids, and the path is
short.** A component that names a parameter in its map gets a value whether or
not the configuration mentioned it. A configuration that overrides
`gravitational_acceleration` but forgets `angular_velocity_planet_rotation` gets
Earth's rotation rate with no warning, because the unused-override check looks
only at keys that were supplied. There is no "this key was not overridden"
diagnostic anywhere in the package.

**A calendar is in the parameter file.** `[epoch_time]` has `type = "datetime"`
and is described as "J2000 epoch (Jan 1, 2000 11:58:55.816 UTC) as a DateTime";
`_get_typed_value` maps `"datetime"` to `Dates.DateTime`, which is a proleptic
Gregorian calendar. `[day] value = 86400` is a length of a day in seconds, and
the anomalistic year is stated as a multiple of it. Decision 0008's one clock in
SI seconds has no room for either.

**Two constant sets for one quantity (C5), unchecked.** The file states
`gas_constant_dry_air = 287.0` and, separately, `molar_mass_dry_air = 0.02897`
alongside `universal_gas_constant = 8.3144598`. The two disagree in the fifth
significant figure, and nothing in the package notices, because there is no
notion of a derivation. It also states
`adiabatic_exponent_dry_air = 0.28571428571` with the description "derived from
$R_d/c_{pd}$ or 2/7", which is a frozen derived quantity: a number written down
beside the fields it claims to follow from, with no code enforcing the relation
(B4, and exactly the failure decision 0007's `Derived` disposition exists to
prevent).

**A description can outlive the value it describes.**
`merge_override_default_values` merges per attribute, so an override that sets
only `value` inherits the default entry's `description`. A configuration that
changes gravity keeps the default's prose. The predecessor's method note that a
comment is evidence about intent and never about the value has a mechanism here.

**A tuning channel exists, and is kept out of the defaults.**
`docs/src/toml.md` documents optional `prior`, `constraint`, `L1` and `L2`
attributes, carried through untouched for EnsembleKalmanProcesses.jl to
calibrate against. ClimaParams itself reads only `value`, `type`, `tag` and
`used_in`. Recording the clean half: `test/toml_format.jl` asserts
`!haskey(entry, "prior")` and `!haskey(entry, "constraint")` for every entry in
the shipped default file, so no default value arrives carrying a calibration
prior. The channel is real, but it is confined to override files.

**What the format does require.** `test/toml_format.jl` asserts every default
entry has `value`, `type` and a non-empty `description`, and enforces
description conventions (ends in a full stop, balanced maths delimiters, units
written without a slash between letters). It does not require a citation, and
`docs/src/toml.md` calls the description only "strongly recommended". Many
entries do carry a DOI in their prose, but nothing checks that any does. There
is no disposition, no validity range, no uncertainty and no bracket anywhere in
the schema. A `Sourced` value in this project's sense is not expressible.

## Assumptions it carries

**Earth defaults.** Present and central; see above. This is the package's
defining assumption, not an incidental one.

**Calendar or time representation.** Present: `epoch_time` as a
`Dates.DateTime`, `day` in seconds, and a year length derived from it.

**Grid or mesh.** Clean negative. No grid, no topology, no resolution and no
mesh parameter appears in the reader; the file holds some resolution-dependent
model coefficients for other CliMA packages, but ClimaParams itself knows
nothing of a discretisation.

**Index base.** Clean negative. The only arrays are TOML array-valued
parameters, returned as `Vector`s of the declared type and never indexed by the
package.

**Precision.** `FT` is a type parameter of `ParamDict` and every `"float"` entry
is converted to it on read; `float_type(pd)` exists so downstream constructors
derive `FT` rather than hard-coding one, and `test/toml_consistency.jl` asserts
that a `Float32` and a `Float64` dictionary are unequal and that both load. The
conversion is silent: a value that does not survive `Float32` is truncated with
no diagnostic.

**Threading and GPU model.** Clean negative in the sense that matters: the
package is host-side setup, has no kernels, no `CUDA` and no threading. Not
clean in one respect noted above: reading mutates the dictionary, with no lock,
so concurrent reads are unsafe.

**Mutable global state.** Clean negative at module scope. The only module-level
`const` is `NAMESTYPE`, a type alias. All mutable state is inside a `ParamDict`
instance the caller holds.

**Clamps, floors and limiters (B5).** Clean negative. The package computes
nothing; it reads, types and merges.

## Licence and version

**Licence.** Apache 2.0, Caltech, 2020-2026 (`LICENSE`, `NOTICE`).

**Version.** 1.1.9 at commit `300c657aeed040f7b6d21b09c1fd8f4599eb5014`, `main`,
read 2026-09-09. Not pinned; nothing depends on it.

**Checklist items applied.** A1 (a day, a year and a J2000 epoch each stated
once in `parameters.toml`, with `Dates.DateTime` as the calendar type), A2 (the
planetary constant block located and headed "Earth Defaults"; every member is a
default with a runtime override and none is derived), A3 (`6371000`, `86400`,
`7.2921159e-5`, `9.81` and `101325` all present and accounted for, in the
default file rather than in code), A6 (no grid or index-base assumption; clean),
B4 (the `adiabatic_exponent_dry_air` description claims a derivation the code
does not perform; recorded), B5 (no clamp or limiter; clean), C1 (the
description-inheriting merge and the unused-override check each opened and
read), C3 (the read-log is a declared capability with a demonstration in
`test/toml_consistency.jl`, which round-trips a written log file back through
`create_toml_dict`; what has no demonstration is any check on a parameter that
was not overridden), C4 (`log_parameter_information` is opt-in and `strict`
defaults to `false`, so an unused override warns and a missing override is
silent), C5 (`gas_constant_dry_air` against `universal_gas_constant /
molar_mass_dry_air`, and `adiabatic_exponent_dry_air` against `R_d / cp_d`; no
authoritative copy is named by the package), D2 (not applicable; the boundary
carries scalars and typed vectors, no field arrays).

## Verdict

**Borrow ideas only**, which confirms decision 0012's existing placement, with
one qualification that the reading turned up: the idea decision 0007 took from
this package is the *record*, not the *tracking*. ClimaParams logs which
parameters a component's constructor pulled out of a dictionary, at construction
time, keyed by a caller-supplied string, with the resulting file replayable as an
override; it does not measure which parameters a component's kernels read, and
under its design the subset test of decision 0007 could not fail, because the
name map is at once the declaration and the reader. The replayable log is the
part worth keeping; the measurement decision 0007 describes has no counterpart
here and has to be built.

The other idea worth carrying, stated so a later decision can cite it: the
one-directional usage check. Catching an override key that nothing read is a
real and cheap protection against a typo in a configuration, and this project
should own the same check on its own configuration files, alongside the check
ClimaParams lacks, that no component received a value the configuration did not
name.

No adopt recommendation is made, so no named test and no enabling decision is
required. The package is refused as infrastructure for the reason decision 0012
already gives, now with the source behind it: `create_toml_dict(FT)` returns 678
Earth-defaulted values to a caller who declared nothing, its schema has no place
to record a disposition, a validity range or a citation, and its parameter file
carries a Gregorian epoch and a day in seconds. Adopting it would mean adopting
the default, and decision 0007's constructor exists precisely to have none.
