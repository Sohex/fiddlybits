# GPUCompiler.jl fuses a plain multiply-add unconditionally on the GPU; the @noinline barrier makes both backends agree by matching the CPU's less accurate answer, and muladd matches the correctly rounded one on both

Measured on 2026-09-11 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090), Julia 1.12.7, `CUDA.jl` 6.3.1, `GPUCompiler.jl` 2.6.0, `KernelAbstractions.jl`
0.9.42, Fiddlybits at commit `6428cd01e1191d4da088e88855c2a0a95ccf8036`. The reference is
the same computation at 256 bits, rounded once to `Float64`.

fiddlybits-52v.7.2 measured, while building the device layer, that a plain
`y[i] = a * x[i] + y[i]` kernel disagrees between the CPU and GPU backends and that
routing the multiply through a `@noinline` barrier (`Backends.nofuse_mul`) restores
agreement. This row reproduces that measurement directly, with a reference value and a
third variant, and locates the mechanism.

## The locator

`~/.julia/packages/GPUCompiler/wym4d/src/ptx.jl:320`, inside `mcgen`, the method for
`job::CompilerJob{PTXCompilerTarget}`, `GPUCompiler.jl` 2.6.0. The function builds the
`llc` command line that turns the module's LLVM IR into PTX:

```
# Match nvcc by leaving eligible multiply-add pairs contractible for ptxas.
cmd = `$(NVPTX_LLVM_Backend_jll.llc()) $input
          -mtriple=$(llvm_triple(target))
          -mcpu=$(cpu_name(target))
          -mattr=+ptx$(target.ptx.major)$(target.ptx.minor)
          -nvptx-fma-level=1
          -filetype=$filetype
          -o $output`
```

`-nvptx-fma-level=1` is on this line unconditionally: every `CompilerJob` that reaches
`mcgen` gets it, independent of `job.config`'s optimisation level and of any fast-math
or contract flag set earlier in the pipeline. `llc`'s NVPTX backend takes
`-nvptx-fma-level` as its own switch, separate from LLVM's general `contract`
fast-math flag on individual instructions, and level 1 tells it to contract an eligible
multiply-add pair whether or not the IR carries `contract`. The comment above the line
states the intent: match `nvcc`.

## The three variants, measured

Vector case, `N = 1024`, one thread per element, formula shared with
`test/backends/fixtures.jl`'s `BackendFixtures.seeded_vector`: `x[i] = mod(31i + 7,
97)/20 - 2`, `y0[i] = 2 x[i]`, `a = 1.3`. Result magnitude `|y[i]|` in `[0.0, 9.24]`. The
plain and noinline-barrier variants ran through `Fiddlybits.Backends.axpy!`
(`Backends.axpy_fused_kernel!` and `Backends.axpy_bitwise_kernel!`); the muladd variant
is a kernel written for this probe, `y[i] = muladd(a, x[i], y[i])`, launched the same
way `Backends.launch!` launches the other two.

| variant | max ulps, CPU vs GPU | elements differing, of 1024 | max ulps, CPU vs reference | max ulps, GPU vs reference |
|---|---|---|---|---|
| plain (`a*x[i]+y[i]`) | 1 | 203 | 1 | 0 |
| `@noinline` barrier (`nofuse_mul`) | 0 | 0 | 1 | 1 |
| `muladd(a, x[i], y[i])` | 0 | 0 | 0 | 0 |

Ulp distance is the absolute difference between the two values' monotonic bit-pattern
orderings (`reinterpret(Int64, ::Float64)`, sign-folded), exact for finite nonzero
`Float64`.

The plain kernel disagrees between backends at about a fifth of the elements tested, by
one ulp where it disagrees, and the GPU side is the one that matches the reference: a
GPU launch rounds the exact mathematical value once, because `-nvptx-fma-level=1`
contracts the multiply and the add into one hardware fused-multiply-add instruction,
while the CPU rounds twice, once after the multiply and once after the add, which is
where its one ulp goes. The `@noinline` barrier removes the disagreement by moving the
GPU to the CPU's answer, not the other way: both backends round twice through the
barrier, so they agree with each other and both miss the reference by one ulp on the
same elements the plain kernel did on the GPU side only. `muladd` is exact on both
backends at every element tested: Julia's `muladd` lowers to a true fused
multiply-add on the CPU backend here (this host has hardware FMA) as well as on the
GPU backend, so it is both bitwise cross-backend and correctly rounded, where the
barrier is only the former.

## The probe

```julia
using Fiddlybits: Backends
using CUDA
using KernelAbstractions

const N = 4^5
seeded_vector(::Type{T}, n) where {T} = T[T(mod(i * 31 + 7, 97)) / T(20) - T(2) for i in 1:n]

function order_key(x::Float64)
    i = reinterpret(Int64, x)
    return i < 0 ? typemin(Int64) - i : i
end
ulp_distance(a::Float64, b::Float64) = abs(order_key(a) - order_key(b))

@kernel function axpy_muladd_kernel!(y, a, @Const(x))
    i = @index(Global)
    y[i] = muladd(a, x[i], y[i])
end

function launch_muladd!(y, a, x, backend::Backends.Backend)
    dev = Backends.ka_backend(backend)
    compiled = axpy_muladd_kernel!(dev, Backends.workgroup(backend))
    compiled(y, a, x; ndrange = length(y))
    KernelAbstractions.synchronize(dev)
    return y
end

x = seeded_vector(Float64, N)
y0 = seeded_vector(Float64, N) .* 2.0
a = 1.3

ref = Vector{Float64}(undef, N)
setprecision(BigFloat, 256) do
    for i in 1:N
        ref[i] = Float64(big(a) * big(x[i]) + big(y0[i]))
    end
end

cpu = Backends.CPU(64)
gpu = Backends.GPU(64)
```

Plain and barrier results come from `Backends.axpy!(copy(y0), a, x, cpu)` and the same
call with the arrays moved to `gpu` through `Backends.on`, once with `cpu`/`gpu` as
declared above (plain) and once with `Backends.CPU(64; bitwise = true)` /
`Backends.GPU(64; bitwise = true)` (barrier). The muladd results come from
`launch_muladd!` on the same arrays and backends. Invoked as `qrun -p gpu-share --
julia --startup-file=no --project=. probe.jl` from the repository root, so
`Fiddlybits` resolves from its own `Project.toml`.

## What this changes

`Backends.nofuse_mul`'s docstring in `src/Backends/kernels.jl` names this finding by
path, which is what fiddlybits-52v.7.2's review deferred to this row.

The barrier buys cross-backend bitwise agreement at the cost of the GPU's free
correctly-rounded answer; `muladd` buys both here. Whether decision 0029's bitwise mode
should route through `muladd` instead of the `@noinline` barrier is a design question
this finding does not settle by itself, since it turns on whether every kernel shape
bitwise mode has to support can be written with the multiply and the add adjacent in
source (`muladd` needs that; the barrier does not, and `Backends.stencil_gather_bitwise_kernel!`
accumulates into a running sum rather than a bare add) and on whether every target
architecture the project runs bitwise mode on carries hardware FMA. That question is
filed as fiddlybits-52v.7.10.
