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
| threading | a chunk is compressed by Blosc's global interface: `zcompress` for a `BloscCompressor` (Zarr.jl 0.10.2 `src/Compressors/blosc.jl`, lines 49-65) calls `Blosc.set_compressor` and `Blosc.compress`, and `Blosc.compress` (Blosc.jl 0.7.3 `src/Blosc.jl`, lines 109-119, 74-98) calls `blosc_compress` (lines 37-40); the reference path's indexed write reaches the same call (`src/ZArray.jl` `writeblock!` line 336, `compress_raw` lines 383-386, `src/pipeline.jl` lines 1-8, `src/Compressors/Compressors.jl` lines 29 and 33-37, with no filter for a numeric element type, `src/ZArray.jl` lines 440 and 484-492). The header Blosc_jll 1.21.7+0 installs (`include/blosc.h`, lines 120-124) says a program using Blosc from several threads at once uses only `blosc_compress_ctx` and `blosc_decompress_ctx`, the interface lines 225-230 describe as working without the global lock. Each chunk file is written under its own key through `store_writechunk` (Zarr.jl `src/Storage/Storage.jl` line 84, reached from `write_items!` at lines 258-286) | every Blosc call the store makes through Zarr, the reference path's array write and read and the writer's encode stage, runs under `Provenance.BLOSC_LOCK`; chunk keys are distinct by chunk index; `test/provenance/writer.jl` holds the writer's chunks byte-identical to the reference path's |
| compressed size | a chunk of `n` bytes compresses to at most `n + BLOSC_MAX_OVERHEAD` bytes: `blosc.h` lines 32-37 define `BLOSC_MAX_OVERHEAD` as the minimum header length, and lines 159-161 guarantee compression into `nbytes + BLOSC_MAX_OVERHEAD`; Blosc.jl mirrors it as `MAX_OVERHEAD` (`src/Blosc.jl` line 14) and `compress` allocates `src_size + MAX_OVERHEAD` bytes before shrinking to the compressed length (lines 109-113) | the writer charges each chunk its bytes plus `Zarr.Blosc.MAX_OVERHEAD` (`Provenance.write_charge`); `provenance.write_ceiling_held` in `test/provenance/writer.jl` |
| mutable global state | none | n/a |
| fail-open branches | none: every array is written with no fill value (`fill_value = nothing`); Zarr.jl 0.10.2 itself raises an `ArgumentError` reading an absent chunk with no fill value rather than substituting one (`ZArray.jl`, `uncompress_raw!`, lines 358-360) | `read_array` refuses an absent chunk by name before that read is reached, in `test/provenance/store.jl` |
| compressor availability | some Python compressors are absent | the manifest names the compressor; a read refuses an unknown one |

**Licence.** MIT. **Version.** 0.10.2, pinned; `to verify` the v3 status before
any migration.

**Checklist items applied.** A6 index base, C3 v3 is declared capability only,
C4 missing chunk refused, not fail-open (recorded), D2 every array's attributes
checked on read, D4 an extensive field's integral before write equals after read.
