# NCDatasets.jl

**What it is.** A CF-aware NetCDF reader and writer.

**What of it is used.** Export only, in the render layer, for handing artifacts to
CF tools. Never read by any physics module.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | CF tools downstream assume a 6371 km sphere and a 365-day calendar unless told otherwise | the export writes the declared sphere radius and a `calendar = "none"` time axis with the geometry declaration carried from the predecessor's `lib/nc_geometry.py` pattern |
| calendar or time | `DateTime` decoding of time units | time is exported in seconds since the run epoch with no calendar; `test/render/no_calendar.jl` asserts no `Dates` type reaches the writer |
| grid or mesh | assumes lat/lon or a declared unstructured layout | the export declares the mesh as an unstructured grid with cell boundaries |
| index base | 1-based in memory, 0-based on disk | handled by the library |
| mutable global state | none | n/a |

**Licence.** MIT. **Version.** `to pin`.

**Checklist items applied.** A1 (the library's calendar support is not used), A2
(no radius default is used; ours is written), D2 (every exported field carries
units, support and time attributes).
