# Zarr.jl

**What it is.** A Julia reader and writer for the Zarr chunked array format, with
compressors and store backends.

**What of it is used.** Writing and reading v2 stores for every artifact, with
attributes on each array; chunking aligned to hierarchy ranges. Nothing that
depends on v3 until its path in Zarr.jl stabilises.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none | n/a |
| calendar or time | none; time is an ordinary array plus our attributes | the store refuses an array missing `time_semantics` or `interval` (the placement record nesting `t0` and `t1` for an interval), naming the attribute, in `test/provenance/store.jl` |
| grid or mesh | none | the store refuses an array missing `support_id` |
| index base | 0-based on disk, translated to 1-based in memory | decision F7; `test/io/index_roundtrip.jl` writes and reads a known index field |
| precision | element type stored as declared | the manifest records the element type; a read asserts it |
| threading | chunk writes from threads are safe when chunks do not overlap | chunk ranges are hierarchy ranges, disjoint by construction |
| mutable global state | none | n/a |
| fail-open branches | none: every array is written with no fill value (`fill_value = nothing`); Zarr.jl 0.10.2 itself raises an `ArgumentError` reading an absent chunk with no fill value rather than substituting one (`ZArray.jl`, `uncompress_raw!`, lines 358-360) | `read_array` refuses an absent chunk by name before that read is reached, in `test/provenance/store.jl` |
| compressor availability | some Python compressors are absent | the manifest names the compressor; a read refuses an unknown one |

**Licence.** MIT. **Version.** 0.10.2, pinned; `to verify` the v3 status before
any migration.

**Checklist items applied.** A6 index base, C3 v3 is declared capability only,
C4 missing chunk refused, not fail-open (recorded), D2 every array's attributes
checked on read, D4 an extensive field's integral before write equals after read.
