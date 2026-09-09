# Julia 1.12

**What it is.** The language runtime, pinned at the 1.12 series (1.12.7 on this
host).

**What of it is used.** Multiple dispatch on the `Field` and disposition types,
`Base.Threads` for the CPU backend, stdlib `LinearAlgebra`, `SparseArrays`,
`Random`, `UUIDs`, `SHA`, `TOML`, `Test`. The `juliac --trim` static compilation
path is not relied upon.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| index base | 1-based arrays and ranges | decision F7 |
| precision | `Float64` literals by default; `1/3` is `Float64` | `FT` is threaded as a type parameter; a lint refuses untyped float literals in kernels (`test/params/lint_literals.jl`) |
| threading | `Threads.@threads` scheduling order is not deterministic | no reduction depends on thread order; fixed-order pairwise reductions; `repro.thread_count_bitwise` |
| mutable global state | `Random.default_rng()` is task-local and seeded at startup | never used; counter-based RNG keyed on physical identity |
| math library | `exp`, `log`, `sin` differ by ulps between CPU and GPU implementations | the bitwise debug mode uses one pure-Julia implementation on both backends |
| BLAS | multithreaded and reassociating | not used in the physics path |
| precompilation | latency | PrecompileTools workloads; a CI sysimage |

**Licence.** MIT. **Version.** 1.12 series, pinned in `Project.toml` compat.

**Checklist items applied.** A6 (1-based), C4 (default RNG and BLAS as fail-open
conveniences, both excluded), D4 (thread-count bitwise identity).
