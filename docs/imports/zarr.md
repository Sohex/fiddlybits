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
| calendar or time | none; time is an ordinary array plus our attributes | the store refuses an array missing `t0`, `t1`, `time_semantics` |
| grid or mesh | none | the store refuses an array missing `support_id` |
| index base | 0-based on disk, translated to 1-based in memory | decision F7; `test/io/index_roundtrip.jl` writes and reads a known index field |
| precision | element type stored as declared | the manifest records the element type; a read asserts it |
| threading | chunk writes from threads are safe when chunks do not overlap | chunk ranges are hierarchy ranges, disjoint by construction |
| mutable global state | none | n/a |
| fail-open branches | a missing chunk reads as the fill value | fill value is set to NaN for floats and the read asserts no NaN in a written range |
| compressor availability | some Python compressors are absent | the manifest names the compressor; a read refuses an unknown one |

**Licence.** MIT. **Version.** `to pin` in the 0.10 series; `to verify` the v3
status before any migration.

**Checklist items applied.** A6 index base, C3 v3 is declared capability only,
C4 fill-value fail-open (recorded), D2 every array's attributes checked on read,
D4 an extensive field's integral before write equals after read.
