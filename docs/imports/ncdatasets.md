# NCDatasets.jl

**What it is.** A CF-aware NetCDF reader and writer.

**What of it is used.** Export only, in the render layer, for handing artifacts to
CF tools. Never read by any physics module.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | CF tools downstream assume a 6371 km sphere unless told otherwise | the export writes the field's own `sphere_radius` and the `crs` grid mapping's `earth_radius` from the support's radius, never a default; `read_netcdf` refuses a `crs` whose `earth_radius` differs from the declared radius, naming it, in `test/io/netcdf_export.jl` |
| calendar or time | `DateTime` decoding of time units | the export writes `t0_seconds`, `t1_seconds` or `t_seconds` as plain `Float64` seconds since the run epoch, never a `Dates.DateTime` or a calendar attribute, asserted in `test/io/netcdf_export.jl`; `test/lint/lint_calendar.jl` refuses `Dates` anywhere in `src/` outside Render |
| grid or mesh | assumes lat/lon or a declared unstructured layout | the export declares `mesh_kind`, `mesh_level` and `cell_corner` as its own unstructured grid, and `read_netcdf` refuses a file missing any of `GEOMETRY_ATTRIBUTES` or whose `cell_corner`, `cell_area`, `lat` or `lon` do not match what the declaration rebuilds, naming it, in `test/io/netcdf_export.jl` |
| index base | 1-based in memory, 0-based on disk | handled by the library |
| mutable global state | none | n/a |

**Licence.** MIT. **Version.** 0.14.15, pinned.

**Checklist items applied.** A1 (the library's calendar support is not used), A2
(no radius default is used; ours is written), D2 (every exported field carries
units, support and time attributes).
