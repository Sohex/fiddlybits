# ClimaDiagnostics.jl, ClimaAnalysis.jl and ClimaUtilities.jl

**What they are.** The organisation's output and plumbing layer, taken together
because they share a verdict and because each is only intelligible beside the
other two. `ClimaDiagnostics.jl` defines what a diagnostic is, when it is
computed, how it is reduced over time, and writes it. `ClimaAnalysis.jl` reads
what was written back and post-processes it. `ClimaUtilities.jl` is the shared
plumbing underneath both: a time type, artifact access, file readers, regridders,
time-varying and space-varying inputs, and output path generation.

**What of them is used.** Nothing. This is a survey record. They are surveyed
because decision 0010 fixes the artifact store, and these are the packages that
would have to sit on it if any of them were adopted.

## The question, answered

**Is any of it usable against a content-addressed Zarr store with
semantics-carrying arrays?** No, and the reason is not the file format. Zarr is
absent from all three, but that is the shallow half. The deep half is that
nothing in the three carries the attributes decision 0010 makes mandatory. An
array written by `ClimaDiagnostics.NetCDFWriter` carries a short name, a long
name, units, a standard name and its dimensions. It does not carry a support
identity, a semantics tag, a time-semantics tag, a dimension in the sense of
decision 0007's dimension algebra, an owner, or an interval with both bounds.
The store this project builds refuses to open an array missing any of those, so
a `ClimaDiagnostics` writer output would be refused at the door, and a
`ClimaAnalysis` reader would have no place to put them if they were present:
`OutputVar` holds `attributes`, `dims`, `dim_attributes` and `data`, and its
identity for a dimension comes from matching the dimension's name against a fixed
list of English words.

**Do they assume NetCDF with a calendar and a latitude-longitude grid?** In three
different ways.

*NetCDF.* `ClimaDiagnostics` has four writers behind an `AbstractWriter` abstract
type with an extension point (`write_field!`, and optionally `interpolate_field!`,
`Base.close` and `sync`), so the format is genuinely swappable in the type system:
`DummyWriter`, `DictWriter` in memory, `HDF5Writer` for raw `ClimaCore` fields,
`NetCDFWriter` for remapped ones. `ClimaAnalysis` is not swappable in the same
way. `read_var` opens an `NCDatasets.NCDataset` directly and there is no
abstraction beneath it; the constructor `OutputVar(dims, data)` does let an
`OutputVar` be built in memory from any source, which is the one seam. In
`ClimaUtilities`, NetCDF is behind package extensions (`NCFileReaderExt`,
`ClimaUtilitiesClimaCoreNCDatasetsExt`), which is the cleanest of the three.

*Calendar.* `ClimaDiagnostics` writes the time axis with `units = "s"` and
`standard_name = "time"` and no `calendar` attribute at all, which is a clean
negative and exactly the shape decision 0008 wants. Beside it, `add_date_maybe!`
writes a separate `date` variable derived from the writer's `start_date` when one
was supplied, so a calendar enters as an optional second axis rather than as the
time axis itself. That is a good separation. The calendar returns in
`Schedules.EveryCalendarDtSchedule`, which holds a `Dates.Period` and a
`Dates.DateTime` start date so that a diagnostic can be emitted monthly, and a
month is not a fixed period. `ClimaAnalysis` recognises `date` as a dimension
name and decodes `NCDatasets.CFTime` types. `ClimaUtilities.TimeVaryingInputs`
offers `PeriodicCalendar` as a boundary method for extrapolating a forcing
outside its data range, which presumes a repeating year.

*Latitude and longitude.* This is where it binds hardest.
`ClimaDiagnostics.netcdf_writer_coordinates.jl` remaps a `ClimaCore` field onto a
target grid before writing; for a cubed-sphere space that target is a regular
longitude-latitude grid spanning the usual ranges in degrees, with
`units = "degrees_east"` and `units = "degrees_north"`, and a default point
count derived from the number of elements per cubed-sphere panel direction times
the unique degrees of freedom, with twice as many longitudes as latitudes.
`ClimaUtilities`' `InterpolationsRegridder` interpolates source data indexed by
`(longitude, latitude, z)` onto a `ClimaCore` space, with default extrapolation
boundary conditions of periodic in longitude, flat in latitude, and throw in the
vertical, and it reorders the coordinate tuple because the CF conventions put
longitude first. `ClimaAnalysis` names its dimensions from fixed lists:

    LONGITUDE_NAMES = ["long", "lon", "longitude"]
    LATITUDE_NAMES  = ["lat", "latitude"]
    TIME_NAMES      = ["t", "time", "valid_time"]
    DATE_NAMES      = ["date"]
    ALTITUDE_NAMES  = ["z", "z_reference", "z_physical", "height"]
    PRESSURE_NAMES  = ["pfull", "pressure_level"]

and `conventional_dim_name` maps a variant onto the canonical member. A
dimension's meaning is its English name. An unstructured cell index is not in
the list and has no way to enter it, so an icosahedral field has no
representation in `ClimaAnalysis` short of being remapped to a longitude-latitude
raster first, which is the remapping decision 0010 exists to avoid.

**The worst single item is in `ClimaAnalysis`.** `average_lat(var; ignore_nan =
true, weighted = false)` defaults to an unweighted mean over rows. Decision 0010
names an unweighted mean over rows as one of the three traps a conventional
NetCDF tool sets, and this is that trap, shipped as the default of the function
whose name a user reaches for. The weighted version exists
(`weighted_average_lat`, and `weighted_average_lonlat` for the correct joint
average rather than an average of averages, which the docstring is careful to
distinguish), and the weight is `cosd(lat)` on a unit sphere with no radius
anywhere in `Numerics.jl`, so the machinery is right and only the default is
wrong. It is wrong in the direction that produces a plausible number.

## Assumptions they carry

| assumption | present | how a leak would be caught here |
| --- | --- | --- |
| Earth defaults | one numeric: `ClimaDiagnostics`' `FakePressureLevelsMethod` uses a scale height of 7000 m to sample vertical levels in a simplified hydrostatic balance, an Earth atmosphere's value used to choose output levels rather than in physics. `ClimaAnalysis` carries the Earth-shaped degree ranges and the `cosd` weighting; no radius, and no gravity. `ClimaUtilities` carries none of its own, but `ClimaArtifacts` is the door through which Earth datasets arrive | n/a; not adopted |
| calendar or time | described above: an SI-seconds time axis with no calendar attribute (clean, and worth noting), an optional `date` companion axis, a `Dates.Period` calendar schedule, `PeriodicCalendar` extrapolation, and CF time decoding on read | n/a |
| grid or mesh | yes, in all three: a `ClimaCore` space on one side and a longitude-latitude raster on the other, with named-dimension identity in between | n/a |
| index base | 1-based in memory; 0-based never surfaces because nothing here writes a cell index as data. Clean negative | n/a |
| precision | `ClimaDiagnostics` writers are parameterised on the float type and write the time axis at that type; `ClimaAnalysis`' `OutputVar` is parameterised on its array type, but `add_date_maybe!` fixes the `date` variable at `Float64` unconditionally. Minor and recorded | n/a |
| threading and GPU | `ClimaComms`-aware; `ClimaArtifacts` synchronises a download so only the root rank fetches and the rest wait on a barrier; `InterpolationsRegridder` copies the entire source dataset to the GPU on every process, which is a memory assumption rather than a correctness one | n/a |
| mutable global state | yes, one clear instance: `ClimaUtilities.ClimaArtifacts` holds `const ACCESSED_ARTIFACTS::Set{String}` at module level and pushes every artifact name into it on access. It is deliberate and it is the good half of the design, since it is what lets a run report which inputs it actually touched, but it is process-global and never reset, so two runs in one process share one set. Separately, `ClimaDiagnostics`' schedules are documented as stateful and explicitly not reusable across simulations | n/a |
| fail-open branches | `ClimaAnalysis.units(var)` returns the empty string when the `units` attribute is absent, so a variable with no declared unit is silently unitless and arithmetic between two such variables proceeds. `average_lat`'s unweighted default, above. `ClimaUtilities`' interpolation boundary methods default to `Throw`, which is a refusal and the right choice, and `Flat` and `PeriodicCalendar` are opt-in; that half is clean | n/a |
| clamps and limiters | none of consequence in the surveyed surface; the vertical `RealPressureLevelsMethod` targets a fixed set of pressure levels shaped like a reanalysis product's, which is a choice of output levels and not a limiter | n/a |

## Which half is Earth-fitted and which is general

There is very little Earth-fitted data here; these are plumbing packages and the
data flows through them. What is welded is a coordinate convention, not a planet:
a field is identified by an English dimension name, positioned on a degree
longitude and latitude, and written on a raster. That convention travels by name
and would have to travel by coordinate for this project, which is the inversion
decision 0010 and the conventions-travel-by-name rule both refuse.

## What is worth carrying anyway

- **`ClimaUtilities.ITime`.** The closest thing in the organisation to decision
  0008's clock, and better than a float in one respect this project should note.
  It is an integer counter times a `Dates.FixedPeriod`, so a time is exact and
  two times of different resolution promote to a common period rather than
  drifting; the epoch is `Union{Nothing, Dates.DateTime}` and `date(t)` on a
  time with no epoch errors with "Time does not have epoch information" rather
  than substituting one; comparing an `ITime` to a bare `Number` errors; and
  promotion of two times with incompatible epochs errors with "Cannot find common
  epoch". Restricting the period to `Dates.FixedPeriod` is the load-bearing
  choice, because a month and a year are not fixed periods and are therefore
  unrepresentable. The package's own docstring says being agnostic of `Dates` is
  a design goal it has not reached. Decision 0008 chose a float in SI seconds;
  this record is the note that an exact integer clock is the alternative that was
  available, and that its refusals (no epoch, no common epoch, no comparison with
  a bare number) are the shape decision 0008's `Interval` and `SimTime` should
  keep.
- **`accessed_artifacts()`.** Recording which inputs a run actually read, as
  opposed to which it declared, is a cheap positive control on the input
  manifests in `docs/inputs/`, and it is the same instinct as decision 0007's
  parameter read tracking that decision 0012 already credits `ClimaParams.jl`
  with.
- **The separation of `time` from `date` in the NetCDF writer.** An SI-seconds
  axis with no calendar attribute, and a calendar rendering beside it as a second
  variable, is exactly decision 0008's "a calendar is a rendering concern" made
  concrete in a file. The export path of decision 0010 should look like this.
- **`weighted_average_lonlat`'s docstring** distinguishing a joint weighted
  average from an average of averages. The distinction is real, the packages that
  get it wrong are many, and this project's integrators should carry the same note.

**Licence.** Apache 2.0, all three. **Versions.** Read against `main` on
2026-09-09: `ClimaDiagnostics` 0.3.9, `ClimaAnalysis` 0.5.23, `ClimaUtilities`
0.1.32. Nothing is pinned; nothing is adopted.

**Checklist items applied.** A1: the day and the year are stated in
`ClimaDiagnostics.Schedules` as `Dates.Period` values and in `ClimaUtilities`'
`PeriodicCalendar`; the time axis itself is stated once, in seconds, with no
calendar. A2: no planetary constant block in any of the three. A3: of the Earth
literals grepped for, none appear; the only Earth-shaped number found is the
7000 m scale height in `ClimaDiagnostics`' vertical sampling, which is not on the
grep list and is recorded here. A6: the compile-time bound is the target point
count, defaulted from cubed-sphere panel elements; the rebuild trigger is the
grid. B4: the `weighted = false` default of `average_lat` is not flagged in its
own docstring as a trap, and the docstring's only note is that `weighted = true`
weights by the cosine of latitude; the comment is accurate and the default is
still wrong. B5: no limiter of consequence; the interpolation boundary methods
default to `Throw`, recorded as a clean negative. C1: `average_lat` read at its
use sites in `Var.jl`; `cosd` weighting confirmed in `Numerics.jl` and no radius
found. C3: `AbstractWriter` is a declared extension point in `ClimaDiagnostics`
with four shipped implementations, so a store-backed writer is a demonstrated
capability at the type level even though no non-file writer ships; `ClimaAnalysis`
declares no equivalent reader abstraction. C4: the empty-string units default and
the unweighted-mean default, both recorded. C5: `ACCESSED_ARTIFACTS` is a second
live copy of the input set, process-global and never reset; the manifest would be
the authoritative copy here. D2: every array crossing these boundaries carries a
name, units and dimension names, and none carries a support identity, a semantics
tag, an owner or an interval; that is the whole finding. D4: no conservation
identity is available in these packages to run.

## Verdict

**ClimaDiagnostics.jl: do not adopt.** Its writer abstraction is genuinely
extensible and its time axis is calendar-free, but everything it writes is a
`ClimaCore` field remapped onto a longitude-latitude raster whose default
resolution is derived from cubed-sphere panel elements, and no array it emits
carries the support identity, semantics, owner or interval that decision 0010
makes mandatory.

**ClimaAnalysis.jl: do not adopt.** A dimension's meaning is its English name
matched against a fixed list that has no member for an unstructured cell index,
and the default latitude average is unweighted, which is the exact trap decision
0010 names.

**ClimaUtilities.jl: borrow ideas only.** Its regridders, file readers and
time-varying inputs assume a longitude-latitude source and a `ClimaCore` target
and so cannot be adopted, but `ITime`'s exact integer clock with a refusing
epoch, and `accessed_artifacts()`' record of what a run really read, are two
designs worth carrying.

**No adoption is recommended, so no test and no decision is named.** Were a later
decision to revisit `ITime` as an alternative to decision 0008's float clock, the
decision to take is an amendment to 0008 on the clock's representation, and the
test that would catch the assumption it carries is the encode-and-decode
inverse oracle 0008 already implies, extended to assert that no `Dates` type and
no calendar reaches the clock: `ITime`'s `period` field is a `Dates.FixedPeriod`
and would have to become a count of SI seconds for that assertion to hold.
