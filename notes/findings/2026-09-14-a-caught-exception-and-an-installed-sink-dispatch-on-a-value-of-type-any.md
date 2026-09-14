# A caught exception and an installed sink dispatch on a value of type Any, and no form that keeps what wait_queued refuses and what moved calls removes the dispatch

Measured on 2026-09-14 on yggdrasil, Julia 1.12.7, JET 0.12.1, CUDA.jl and CUDACore 6.3.1,
from `main` at `a4e8c2d`. The row is `fiddlybits-52v.3.23`. The subject is the two
`report_opt` `RuntimeDispatchReport` findings the static pass of `test/fields/static_pass.jl`
reports on the tree once its operator walk runs on `Backends.GPU`: one in
`Fiddlybits.Backends.wait_queued` (`src/Backends/launch.jl`) and one in
`Fiddlybits.Events.moved` (`src/Events/Events.jl`).

## The instrument

- **The pass.** `StaticPass.run_pass` with every `julia` through `Gate.in_checkout`, as
  `tools/nightly/run.jl` calls it, from one `qrun` job with a card share, on the unmodified
  tree against `test/fields/static_pass.toml` with the two entries naming this row removed.
- **The report.** `JET.report_opt` with `target_modules = (Fiddlybits,)`, printed in full, on
  `Backends.complete!` at `Backends.GPU` and at `CuArray{Float64, 1, DeviceMemory}`, and on
  `Events.moved` at `(Vector{Float64}, Symbol, Symbol)` and at that `CuArray` type.
- **The forms.** Small functions in a scratch module, each one way of writing the same
  call, analysed by `report_opt` with that module as the target and run once to read what
  they return. The wait throws a value read from a `Ref{Any}`, so what it throws is not
  inferred. A first round threw `error("boom")` directly; Julia 1.12 inferred the caught value
  as `ErrorException`, and the form `wait_queued` has read 0 reports there, so that round could
  not tell the forms apart and is not used below.

## The pass, before any change

    static pass: NEW   report_opt RuntimeDispatchReport in Fiddlybits.Backends.wait_queued (src/Backends/launch.jl): runtime dispatch detected at src/Backends/launch.jl:185
    static pass: NEW   report_opt RuntimeDispatchReport in Fiddlybits.Events.moved (src/Events/Events.jl): runtime dispatch detected at src/Events/Events.jl:358
    static pass: tree on julia 1.12.7 with JET 0.12.1: 16 findings, 2 new, 0 stale, 2333 methods and 60 operator calls analysed, 25 device kernels left out

## Where each dispatch is

- **wait_queued**, reached from `complete_on` at `CUDABackend` and at the `CuArray` type, with
  the closure argument concrete in both: `sprint(showerror, %101::Any)::String`. The call to
  `sprint` itself is the dispatch. `err` from `catch err` is `Any`, because what
  `KernelAbstractions.synchronize` and `CUDA.synchronize` raise is not inferred.
- **moved**, at both array types: `%4::Any(%5::Fiddlybits.Events.Moved)::Any`. The callee is
  the value read from `MOVE_SINK`, a `Ref{Any}`.

## The forms of the refusal's message

Each form's refusal text is given for a thrown `ErrorException("boom")`,
`DimensionMismatch("sizes")` and `1`. The form `wait_queued` has gives
`"boom; tail" | "DimensionMismatch: sizes; tail" | "1; tail"`.

| form | reports | where | text |
| --- | --- | --- | --- |
| `sprint(showerror, err)`, as `wait_queued` has (control) | 1 | the function | the same |
| `error_text(@nospecialize(err)) = sprint(showerror, err)` | 1 | `error_text` | the same |
| `sprint(showerror, err; context = nothing)` | 1 | the function, at `Core.kwcall` | the same |
| `sprint(showerror, err; sizehint = 0)` | 1 | the function, at `Core.kwcall` | the same |
| `showerror(io, err)` into an `IOBuffer` | 1 | the function, at `showerror(::IOBuffer, ::Any)` | the same |
| `barrier(err)`, one method, no `@nospecialize` | 1 | the function, at `barrier(::Any)` | the same |
| `sprint(showerror, err::Exception)` | 1 | the function, at `Tuple{typeof(sprint), typeof(showerror), Exception}` | `TypeError` for the thrown `1` |
| `invoke(sprint, Tuple{Function,Any}, showerror, err)` | 0 | none | the same |

`sprint(showerror, x)` at `x::Any` outside any `try` also reads 1 report. In this Julia a
call whose argument is inferred `Any` is a dispatch in the calling frame whether the callee
has one method or many; a `@nospecialize` argument makes the call site static and the same
`Any` then reaches a call in the callee. Julia's `base/show.jl` gives `show(io::IO,
@nospecialize(x))`, and no `@nospecialize` door into `showerror`; `show` prints
`ErrorException("boom")` where `showerror` prints `boom`.

## The forms of the sink call

Each form was called once with a sink that pushes its record onto a vector; every form's sink
received the one record.

| form | reports | where |
| --- | --- | --- |
| `SINK[](r)` with `SINK::Ref{Any}`, as `moved` has (control) | 1 | the function, at `Tuple{Any, Rec}` |
| `call_sink(@nospecialize(s), r) = s(r)` | 1 | `call_sink`, at `Tuple{Any, Rec}` |
| `SINKF[](r)` with `SINKF::Ref{Function}` | 1 | the function, at `Tuple{Function, Rec}` |
| `Base.invokelatest(SINK[], r)` | 0 | none |

`Core.invoke isa Core.Builtin` and `Core.invokelatest isa Core.Builtin` both read `true`. The
two forms that read 0 reports are the two that call a builtin, which the analysis does not
enter; each still selects a method at runtime.

## What this says

- No form that shows any raised value through `showerror` removes the dispatch from a
  Fiddlybits frame. The forms either keep it where it is, move it into a helper, or call a
  builtin that still looks the method up at runtime. The `err::Exception` assertion also
  changes what a thrown non-exception raises.
- No form that calls any installed callable removes the dispatch either. Narrowing the
  `Ref` to `Function` keeps it; the helper moves it; `invokelatest` hides it.
- Removing either dispatch means changing what the function accepts. `wait_queued` would
  refuse only error types it names, each shown through a concrete call, and rethrow the rest
  (`fiddlybits-52v.3.24`). The sinks of decision 0046 would take a declared concrete type
  rather than any callable (`fiddlybits-52v.3.25`).
