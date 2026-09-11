# A struct-of-arrays column state costs nothing on the device, and per-cell state stays in registers to 192 elements

Measured on 2026-09-10 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090, compute capability 8.9), Julia 1.12.7, `CUDA.jl` 6.3.1, `KernelAbstractions.jl`
0.9.42, `StructArrays.jl` 0.7.3 at `54d754578858e0d37e1d7b54c0455fce2fada1df`,
`StaticArrays.jl` 1.9.20 at `8935f7091f8376314e482eb6c8c29d478b9ba38b`. Register counts
and local-memory sizes are the compiler's own, read from the compiled kernel rather than
inferred; kernels are compiled but not launched where only the resource counts are wanted.

Decision 0011 puts the column state in a cells-first layout and fuses column physics into
few kernels per step. Two questions stood in the way of writing that: whether the
array-of-structs syntax costs anything against hand-written flat arrays, and how long a
per-cell state vector can be before the compiler stops keeping it in registers.

## A StructArray of a column-state struct compiles to the same kernel as flat arrays

The subject is an eight-field `isbits` struct of Float32, in a `StructArray` of one
million cells, adapted to the device by `Adapt.adapt(CuArray, ...)`.

The adaptation is the one-line `replace_storage(adapt(to), s)` the package's Adapt
extension defines, and it works as advertised: every component becomes a `CuArray`, the
round trip back to the host compares equal field by field, and
`KernelAbstractions.get_backend` on the whole array returns the CUDA backend by agreement
of its components. A `KernelAbstractions` kernel indexing the struct array and a kernel
taking eight separate device arrays produced bitwise identical output over the million
cells.

The resource counts are identical too, and the interesting case is a kernel that reads
only two of the eight fields:

| kernel, reading two of eight fields | registers | local memory |
|---|---|---|
| whole-struct `getindex`, `c = s[i]` | 12 | 0 |
| two flat device arrays | 12 | 0 |
| component indexing, `s.t[i] * s.q[i]` | 12 | 0 |

The optimised device IR of the whole-struct kernel contains two float loads, not eight.
Reconstructing the struct on `getindex` is free: the unused loads are eliminated before
code generation, so a kernel pays for the fields it reads and not for the fields the
struct declares. The three ways of writing the same access are the same kernel.

Mixed element types survive the same path. A four-field struct of Float32, Int32, Bool and
UInt8 adapts with each component in its own device array of its own type, and a kernel
branching on the Bool field matched a host computation of the same expression bitwise over
a million cells.

## Per-cell state in registers: an SVector spills at 256, an MVector at 32

The subject is a kernel that loads L consecutive Float32 values per thread into a
stack-allocated vector, takes their mean and then their variance, which is the shape of a
column physics step: two passes over the whole state.

| L | SVector registers | SVector local bytes | suggested block | blocks resident per streaming multiprocessor at 128 threads |
|---|---|---|---|---|
| 16 | 27 | 0 | 768 | 12 |
| 32 | 40 | 0 | 768 | 12 |
| 64 | 72 | 0 | 896 | 7 |
| 128 | 152 | 0 | 384 | 3 |
| 192 | 207 | 0 | 256 | 2 |
| 256 | 255 | 1064 | 256 | 2 |
| 384 | 255 | 2192 | 256 | 2 |
| 512 | 255 | 3248 | 256 | 2 |

Nothing spills below 256 elements. The register count rises by about one per element, the
hardware limit of 255 per thread is reached between 192 and 256, and past that the vector
goes to local memory. So the answer to the question the survey asked is that the immutable
static vector is free of spilling for any per-cell state this project is likely to declare,
and the constraint that binds first is occupancy rather than correctness: by 64 elements
only seven blocks of 128 threads are resident per multiprocessor, and by 128 elements only
three.

The mutable form behaves differently and worse:

| L | MVector registers | MVector local bytes |
|---|---|---|
| 8 | 15 | 0 |
| 16 | 24 | 0 |
| 32 | 40 | 128 |
| 64 | 40 | 256 |
| 128 | 39 | 512 |

An `MVector` written element by element in a loop goes to local memory from 32 elements,
the whole vector, and the register count then stops rising because the state is no longer
in registers at all. The rule this gives is plain: per-cell state is an immutable `SVector`
rebuilt functionally, and a mutable one is a local-memory array wearing a stack-allocation
name.

## What this changes

The column state is a `StructArray` of an `isbits` struct with no penalty and with the
Adapt and `get_backend` integration already present upstream, so `docs/imports/
structarrays-jl.md` recommends it. Per-cell state vectors are `SVector`, with `MVector`
refused in a kernel, and the kernel-shape rule is written against occupancy rather than
against spilling: a column state longer than about sixty-four Float32 values costs
residency, and that is where the atmosphere's kernel-launch bound from decision 0011 needs
re-checking against register pressure instead.
