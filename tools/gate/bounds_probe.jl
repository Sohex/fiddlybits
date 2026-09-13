#!/usr/bin/env julia
# Whether the process running this compiles bounds checks into the kernels it launches
# under `@inbounds`, on the CPU backend and on the card. Decision 0055.
#
#   julia [--check-bounds=yes] --project tools/gate/bounds_probe.jl <arm>...
#
# Prints `check_bounds = <n>` (`Base.JLOptions().check_bounds`), then one TOML line per
# arm, in the order given, as `<arm> = "<verdict>"` and `<arm>_detail = "<text>"`. The
# card also writes its own kernel exception report to stdout; a reader keeps only the
# lines `Gate.probe_verdicts` reads.
#
# An arm that raises on the card may leave the device unusable for the arms after it,
# so a caller puts such an arm last.

module BoundsProbe

using CUDA
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits: Backends
import TOML

"""
The arms `run_arm` knows, by name:

- `marker_cpu`, `marker_gpu`: a kernel writing `boundscheck_marker()` called under
  `@inbounds`; `"checked"` when every element reads 1, `"elided"` when every element
  reads 0. A second kernel calls the marker without `@inbounds`, and any element of it
  that does not read 1 makes the verdict `"instrument failed"`.
- `read_inbounds_cpu`, `read_inbounds_gpu`: a kernel over four work items reading
  `xs[i + 1]` of a four-element `xs` under `@inbounds`, so the last item reads index 5.
- `zero_inbounds_cpu`, `zero_inbounds_gpu`: the same kernel reading `xs[i - 1]`, so the
  first item reads index 0.
- `negative_inbounds_cpu`, `negative_inbounds_gpu`: the same kernel over a
  sixteen-element `xs` reading `xs[i - 8]`, so every item reads an index from -7 to -4.
- `view_inbounds_cpu`, `view_inbounds_gpu`: the same kernel over `view(parent, 5:8)` of
  an eight-element `parent`, reading `xs[i - 1]`, so the first item reads index 0 of the
  view, which is `parent[4]`.
- `read_checked_*`, `zero_checked_*`, `negative_checked_*`, `view_checked_*`: each of
  the four reads without `@inbounds`.

A read arm's verdict is `"silent"`, `"raised at launch"` or `"raised at completion"`:
where `Backends.launch!` and `Backends.complete!` put the error, if anywhere.
"""
const ARMS = Tuple(vcat(["marker_cpu", "marker_gpu"],
                        [string(kind, "_", form, "_", dev) for kind in ("read", "zero", "negative", "view")
                         for form in ("inbounds", "checked") for dev in ("cpu", "gpu")]))

"""
The element count of the array read, the offset added to the work item's index, and
the range of it the kernel is given as `xs` (`nothing` for the whole array), per read
kind.
"""
const READS = Dict("read" => (4, 1, nothing), "zero" => (4, -1, nothing),
                   "negative" => (16, -8, nothing), "view" => (8, -1, 5:8))

@kernel function read_past_inbounds!(out, @Const(xs), offset)
    i = @index(Global)
    @inbounds out[i] = xs[i + offset]
end

@kernel function read_past_checked!(out, @Const(xs), offset)
    i = @index(Global)
    out[i] = xs[i + offset]
end

"1.0 when the `@boundscheck` block in its body is compiled, 0.0 when it is elided."
@inline function boundscheck_marker()
    r = 0.0
    @boundscheck r = 1.0
    return r
end

@kernel function marker_inbounds!(out)
    i = @index(Global)
    out[i] = @inbounds boundscheck_marker()
end

@kernel function marker_checked!(out)
    i = @index(Global)
    out[i] = boundscheck_marker()
end

backend_for(arm::AbstractString) =
    endswith(arm, "_gpu") ? Backends.GPU(4) :
    endswith(arm, "_cpu") ? Backends.CPU(4) :
    error("probe arm $(arm) names no backend; it ends _cpu or _gpu")

"""
    run_arm(arm)

`(verdict, detail)` for one of `ARMS`, run in this process. `detail` is the error's
own message for a raised read, the values read for a marker or a silent read. Refuses
an arm not in `ARMS`.
"""
function run_arm(arm::AbstractString)
    arm in ARMS || error("probe arm $(arm) is not one of $(join(ARMS, ", "))")
    backend = backend_for(arm)
    host = Backends.CPU(1)
    if startswith(arm, "marker")
        under = Backends.on(fill(-7.0, 4), backend)
        Backends.launch!(marker_inbounds!, backend, 4, under)
        Backends.complete!(backend)
        control = Backends.on(fill(-7.0, 4), backend)
        Backends.launch!(marker_checked!, backend, 4, control)
        Backends.complete!(backend)
        values, controls = Backends.on(under, host), Backends.on(control, host)
        detail = "under @inbounds $(values), without $(controls)"
        all(==(1.0), controls) || return ("instrument failed", detail)
        all(==(1.0), values) && return ("checked", detail)
        all(==(0.0), values) && return ("elided", detail)
        return ("instrument failed", detail)
    end
    kind, form = split(arm, "_")[1:2]
    kernel = form == "inbounds" ? read_past_inbounds! : read_past_checked!
    count, offset, range = READS[kind]
    whole = Backends.on(collect(1.0:Float64(count)), backend)
    xs = range === nothing ? whole : view(whole, range)
    out = Backends.on(fill(-7.0, 4), backend)
    try
        Backends.launch!(kernel, backend, 4, out, xs, offset)
    catch err
        return ("raised at launch", sprint(showerror, err))
    end
    try
        Backends.complete!(backend)
    catch err
        return ("raised at completion", sprint(showerror, err))
    end
    return ("silent", "read $(Backends.on(out, host))")
end

"""
    main(arms)

Print `check_bounds` and every arm's verdict and detail as TOML lines, flushing after
each, and return 0. An arm that throws outside the read it is about prints the verdict
`"probe failed"` with the error.
"""
function main(arms::Vector{String})
    TOML.print(stdout, Dict("check_bounds" => Int(Base.JLOptions().check_bounds)))
    flush(stdout)
    for arm in arms
        verdict, detail = try
            run_arm(arm)
        catch err
            ("probe failed", sprint(showerror, err))
        end
        TOML.print(stdout, Dict(arm => verdict))
        TOML.print(stdout, Dict(arm * "_detail" => first(replace(detail, '\n' => ' '), 400)))
        flush(stdout)
    end
    return 0
end

end # module BoundsProbe

(abspath(PROGRAM_FILE) == @__FILE__) && exit(BoundsProbe.main(ARGS))
