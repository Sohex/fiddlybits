# The device layer: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer".

using ..Verdicts: refuse
import KernelAbstractions
import CUDA

"""
    Backend

The device a kernel runs on (decision 0011). `CPU` and `GPU` are the two
concrete backends. Which backend a component runs on is part of the
component declaration, which sits above this module; this module defines
only the type.
"""
abstract type Backend end

"""
    CPU(; bitwise = false)
    CPU(workgroup; bitwise = false)

The CPU backend. `CPU()` launches every kernel at the workgroup size
`launch_workgroup` chooses; `CPU(workgroup)` pins every launch to the
KernelAbstractions workgroup size `workgroup`, and refuses a `workgroup` below
1. `bitwise` selects the debug arithmetic of decision 0029: pure Julia
arithmetic, no fast-math, no implicit fused multiply-add, the same on every
backend.

A backend is plain data, so a kernel can take one as an argument: the pin is
held as an `Int`, `0` when there is none.
"""
struct CPU <: Backend
    pin::Int
    bitwise::Bool
end
CPU(; bitwise::Bool = false) = CPU(0, bitwise)
CPU(workgroup::Integer; bitwise::Bool = false) = CPU(pin_of(workgroup, "Backends.CPU"), bitwise)

"""
    GPU(; bitwise = false)
    GPU(workgroup; bitwise = false)

The GPU backend (CUDA), launching at the workgroup size `launch_workgroup`
chooses, or pinned to `workgroup`, with the same `bitwise` meaning, the same
refusal and the same plain-data layout as `CPU`.
"""
struct GPU <: Backend
    pin::Int
    bitwise::Bool
end
GPU(; bitwise::Bool = false) = GPU(0, bitwise)
GPU(workgroup::Integer; bitwise::Bool = false) = GPU(pin_of(workgroup, "Backends.GPU"), bitwise)

"""
    pin_of(workgroup, site)

`Int(workgroup)`. Refuses at `site` when `workgroup` is below 1.
"""
function pin_of(workgroup::Integer, site::AbstractString)
    workgroup >= 1 ||
        refuse("backend workgroup", site, "workgroup $workgroup is below 1")
    return Int(workgroup)
end

"""
    workgroup(backend::Backend)

The KernelAbstractions workgroup size `backend` is pinned to, or `nothing`
when `launch_workgroup` chooses it per launch.
"""
workgroup(b::Backend) = b.pin == 0 ? nothing : b.pin

"""
    at_workgroup(backend, workgroup)

`backend` pinned to the KernelAbstractions workgroup size `workgroup`, keeping
its kind (`CPU` or `GPU`) and its `bitwise` flag. A kernel whose layout fixes
its workgroup, one workgroup per block or segment of shared memory, launches
through this.
"""
at_workgroup(backend::CPU, workgroup::Integer) = CPU(workgroup; bitwise = bitwise(backend))
at_workgroup(backend::GPU, workgroup::Integer) = GPU(workgroup; bitwise = bitwise(backend))

"""
    launch_workgroup(backend::Backend, n::Integer)

The KernelAbstractions workgroup size `launch!` launches a kernel over `n`
work items at on `backend`: the pinned `workgroup(backend)` when there is one,
and otherwise the rule of
docs/decisions/0058-a-launch-workgroup-is-chosen-per-launch-from-the-work-item-count.md.

On `CPU`, 1: every block is one work item.

On `GPU`, the smallest power of two whose block count `cld(n, workgroup)` is
at most the card's `GPU_BLOCKS_AT_ONCE` entry, and never more than the card's
warp size (`CUDA.warpsize`). Refuses, naming the card, when `GPU_BLOCKS_AT_ONCE`
holds no entry for it.
"""
launch_workgroup(backend::CPU, n::Integer) = something(workgroup(backend), 1)

function launch_workgroup(backend::GPU, n::Integer)
    pinned = workgroup(backend)
    pinned === nothing || return pinned
    warp, blocks = gpu_launch_shape()
    return gpu_launch_workgroup(n, warp, blocks)
end

"""
    gpu_launch_workgroup(n, warp, blocks)

The smallest power of two `w` with `cld(n, w) <= blocks`, or `warp` when that
is smaller.
"""
gpu_launch_workgroup(n::Integer, warp::Integer, blocks::Integer) =
    Int(min(warp, nextpow(2, max(1, cld(n, blocks)))))

"""
    GPU_BLOCKS_AT_ONCE

Card name, as `CUDA.name` reports it, to the largest power-of-two count of
CUDA blocks at which every per-lane kernel of `Reductions`, launched one
thread per block, runs at the cost of one block on that card:
notes/findings/2026-09-13-the-launch-workgroup-is-set-by-blocks-at-once-and-the-warp.md
measures it.
"""
const GPU_BLOCKS_AT_ONCE = Dict("NVIDIA GeForce RTX 4090" => 128)

"""
    gpu_blocks_at_once(card)

`GPU_BLOCKS_AT_ONCE[card]`. Refuses, naming the card, when it holds no entry.
"""
function gpu_blocks_at_once(card::AbstractString)
    haskey(GPU_BLOCKS_AT_ONCE, card) && return GPU_BLOCKS_AT_ONCE[card]
    refuse("GPU launch shape", "Backends.launch_workgroup",
           "no block count is measured for the card $card in Backends.GPU_BLOCKS_AT_ONCE; " *
           "measure it as notes/findings/2026-09-13-the-launch-workgroup-is-set-by-blocks-at-once-and-the-warp.md " *
           "does, or pin the launch with Backends.at_workgroup")
end

"""
    GPU_LAUNCH_SHAPES
    GPU_LAUNCH_SHAPES_LOCK
    GPU_LAUNCH_SHAPE_LAST

A process-lifetime cache: CUDA device id to `(warp size, blocks at once)`
for that device, filled by `gpu_launch_shape` on its first launch there, and
the lock that guards it. `GPU_LAUNCH_SHAPE_LAST` holds the entry last read,
packed by `pack_launch_shape`, and is read without the lock; it is zero before
the first.
"""
const GPU_LAUNCH_SHAPES = Dict{Int,Tuple{Int,Int}}()
const GPU_LAUNCH_SHAPES_LOCK = ReentrantLock()
const GPU_LAUNCH_SHAPE_LAST = Threads.Atomic{Int}(0)

"""
    pack_launch_shape(id, warp, blocks)
    unpack_launch_shape(packed)

`id + 1` in the bits from 40 up, `warp` in bits 20 to 39 and `blocks` in bits
0 to 19 of one `Int`, and back to `(id, warp, blocks)`. Refuses a `warp` or
`blocks` outside `1:2^20-1`, or a negative `id`.
"""
function pack_launch_shape(id::Int, warp::Int, blocks::Int)
    (id >= 0 && 0 < warp < 2^20 && 0 < blocks < 2^20) ||
        refuse("GPU launch shape", "Backends.launch_workgroup",
               "device $id, warp size $warp and block count $blocks do not pack into one Int")
    return ((id + 1) << 40) | (warp << 20) | blocks
end

unpack_launch_shape(packed::Int) = ((packed >> 40) - 1, (packed >> 20) & (2^20 - 1), packed & (2^20 - 1))

"""
    gpu_launch_shape()

`(warp size, blocks at once)` for the CUDA device this task launches on:
`CUDA.warpsize` of the device and `gpu_blocks_at_once` of its name, read once
per device and process, and returned from `GPU_LAUNCH_SHAPE_LAST` when that
holds this device.
"""
function gpu_launch_shape()
    id = Int(CUDA.deviceid(CUDA.device()))
    last_id, warp, blocks = unpack_launch_shape(GPU_LAUNCH_SHAPE_LAST[])
    last_id == id && return (warp, blocks)
    shape = lock(GPU_LAUNCH_SHAPES_LOCK) do
        get!(GPU_LAUNCH_SHAPES, id) do
            dev = CUDA.device()
            (Int(CUDA.warpsize(dev)), gpu_blocks_at_once(CUDA.name(dev)))
        end
    end
    GPU_LAUNCH_SHAPE_LAST[] = pack_launch_shape(id, shape...)
    return shape
end

"""
    bitwise(backend::Backend)

Whether `backend` runs in bitwise debug mode (decision 0029). A kernel
branches on this to route a multiply that feeds an add through the fusion
barrier instead of letting it fuse on the GPU backend; a kernel with a
transcendental in it also branches on this to choose the project's own
polynomial implementation over the platform library, once one exists
(fiddlybits-52v.7.8).
"""
bitwise(b::Backend) = b.bitwise

"""
    array_type(backend::Backend)

The array type `adapt_for` moves a struct's arrays to for `backend`.
"""
array_type(::CPU) = Array
array_type(::GPU) = CUDA.CuArray

"""
    ka_backend(backend::Backend)

The `KernelAbstractions.Backend` `launch!` compiles `backend`'s kernel for.
Refuses when `backend` is `GPU` and CUDA reports no functional device.
"""
ka_backend(::CPU) = KernelAbstractions.CPU()
function ka_backend(::GPU)
    CUDA.functional() ||
        refuse("GPU backend", "Backends.ka_backend", "CUDA reports no functional device on this host")
    return CUDA.CUDABackend()
end
