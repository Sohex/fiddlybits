# CUDA.jl

**What it is.** The Julia CUDA stack: `CuArray`, kernel compilation, streams,
memory management, and wrapped libraries (CUBLAS, CUSPARSE, CUFFT).

**What of it is used.** `CuArray` as the device array behind `Field`, the
KernelAbstractions backend, memory queries for the profile budget, and
`CUSPARSE` only behind the same interface as the CPU sparse solve if a GPU
groundwater solve is ever wanted. No CUBLAS in the physics path.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none | n/a |
| calendar or time | none | n/a |
| grid or mesh | none | n/a |
| index base | 1-based arrays | decision F7 |
| precision | `Float64` runs at a small fraction of `Float32` throughput on consumer hardware; library reductions may reassociate | reservoirs and ledgers in FP64 accumulators regardless of `FT`; no library reductions in the ledger path; `repro.backend_ulp_envelope` |
| threading and GPU model | asynchronous streams; unsynchronised reads are undefined | every exchange synchronises before a ledger is computed; the bitwise debug mode |
| mutable global state | the default stream and the memory pool are process-global | one process per run; the profile records the device |
| fail-open branches | fast-math and FMA contraction differ from CPU | production mode carries the measured envelope; debug mode disables contraction and asserts bitwise |

**Licence.** MIT. **Version.** `to pin`; `to verify` the driver and toolkit
versions on this host.

**Checklist items applied.** A3 none, A6 none, B5 memory-pool limits are the
only limiter and are read into the profile budget, C4 FMA contraction (recorded),
D4 the ledger closure on device against the CPU reference path.
