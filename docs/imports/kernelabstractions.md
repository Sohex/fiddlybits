# KernelAbstractions.jl

**What it is.** A portable kernel language for Julia: `@kernel` functions with
`@index` that compile to CUDA, ROCm, oneAPI, Metal or a multithreaded CPU backend.

**What of it is used.** `@kernel`, `@index(Global)`, `@Const`, backend selection,
`synchronize`, and the CPU backend as the fallback and as the reference for every
GPU kernel. Nothing else.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none | n/a |
| calendar or time | none | n/a |
| grid or mesh | none; kernels index flat arrays | `test/mesh/stencil_valence.jl` asserts stencil tables are the only geometry a kernel sees |
| index base | 1-based `@index`; workgroup indices 1-based | decision F7: 1-based in kernels; `CellId` refuses arithmetic at the host boundary; `test/params/lint_index_base.jl` greps kernels for `- 1` and `+ 1` on cell indices |
| precision | element type follows the array | `FT` is a type parameter end to end; `repro.fp32_kernel_certification` |
| threading and GPU model | CPU backend splits the index range across threads; reductions are the caller's responsibility | no `@atomic` in physics kernels (lint); segmented reductions with fixed order; `repro.thread_count_bitwise` |
| mutable global state | none in the API | n/a |
| fail-open branches | a kernel launched with an out-of-range `ndrange` on the CPU backend silently does nothing for the excess | every launch asserts `ndrange == length(target)`; the reference path compares full arrays |

**Licence.** MIT. **Version.** `to pin` at the 0.9 series in use on Julia 1.12;
verify Enzyme interaction is not relied upon (decision F8 defers it).

**Checklist items applied.** A1 none, A2 none, A3 none, A6 index base (recorded),
C3 the CPU backend's determinism is a demonstrated capability only with our own
fixed-order reductions, C4 the `ndrange` fail-open (recorded), D4 the reference
path comparison per kernel.
