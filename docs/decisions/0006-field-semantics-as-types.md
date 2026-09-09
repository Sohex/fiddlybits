+++
id = "0006"
title = "Field semantics, time semantics, dimension and support are type parameters of every field"
status = "accepted"
date = 2026-09-08
+++

## Decision

A field is a value of type `Field{S, T, D, L, A}`: `S` its semantics, `T` its time
semantics, `D` its SI dimension, `L` the mesh level it lives on, `A` the array type
holding its raw floats. Every operator that changes a field's support, time support
or dimension dispatches on those parameters, and an operator that is not defined for
a combination does not exist; there is no fallback.

### The closed vocabularies

Semantics `S`, a closed set. Adding one is a deliberate act with a test to pass:

- `Extensive`: a total per cell (kilograms, joules). Coarsens by sum.
- `Intensive`: a state (kelvin, a mixing ratio). Has no plain coarsen; the caller
  names what a coarse cell is: an area mean, a masked mean, or a quantile table.
- `FluxDensity`: per square metre per second. Coarsens by area-weighted mean so the
  integral is conserved.
- `Fraction`: dimensionless on the unit interval. Coarsens by area-weighted mean.
- `CategoricalLabel{Legend}`: one class per cell, the legend read from the artifact,
  never an integer code. Coarsens to a `CategoricalFraction{Legend}` histogram; is
  never centre-sampled.
- `CategoricalFraction{Legend}`: one fraction per legend entry, summing to one.
- `VectorComponent{Basis}`: a component in a named basis (`cartesian`, `east_north`,
  `edge_normal`). Only the Cartesian basis may change support; east-north is lifted
  to Cartesian at the source geometry's local frames and projected at the
  destination's, because east at one longitude is not east at another.
- `Quantiles{P}`: an area-weighted quantile table at declared probabilities. It is a
  table, not a moment; it cannot be re-aggregated or refined, and the share of a cell
  past a threshold is read out of it.

Time semantics `T`: `Static`, `Instantaneous`, `IntervalMean`, `IntervalAccumulation`,
`EndpointState`. Reductions in time dispatch the same way: accumulations sum, means
are duration-weighted, instantaneous values refuse without a sampling rule, endpoint
states take the last.

Dimension `D`: an SI exponent signature carried on the type, backed by a runtime
dimension algebra on the host. The element type inside the array is a plain float;
units do not enter kernels.

### Sketch

```julia
struct Field{S<:Semantics, T<:TimeSemantics, D<:Dim, L, A<:AbstractArray}
    data::A                  # (ncells(L), extra...) raw Float32/Float64; device or host
    support::Support{L}      # family digest + level; shape is never identity
    time::TimeSupport{T}     # explicit t0, t1 in SI seconds
    prov::Provenance         # content key, the one writer, the parameter subset hash, run id
end

coarsen(f::Field{Extensive,T,D,L}, ::Level{L2})              = segmented_sum(f, L2)
coarsen(f::Field{FluxDensity,T,D,L}, ::Level{L2})            = segmented_area_mean(f, L2)
coarsen(f::Field{Intensive,T,D,L}, ::Level{L2}, ::AreaMean)  = segmented_area_mean(f, L2)
coarsen(f::Field{Intensive,T,D,L}, ::Level{L2}, ::ToQuantiles{P}) where P = segmented_quantiles(f, L2, P)
coarsen(::Field{VectorComponent{:east_north}}, ::Level) = refuse("lift to :cartesian at the source first")
coarsen(::Field{Quantiles}, ::Level) = refuse("a quantile table is not re-aggregable; recompute from the fine field")
```

Every operator returns the field and a ledger (decision 0009). The state store
refuses to accept a field whose ledger is open.

### Making a missing method a build failure

In Julia a missing method is a runtime `MethodError`, not a compile error. Two things
raise that to the strength the design needs: an enumeration test walks every
semantics type against every operator and asserts each pair either has a method or
appears in the declared refusal table; and a static analysis pass in continuous
integration reports unresolved calls on the component code paths. Together, an
undeclared reduction is a red build.

## Alternatives considered

- **Semantics as a runtime attribute checked by the operator.** The predecessor did
  this in Python (a declared vocabulary in a configuration file, a gate that checked
  every reduction function was claimed by exactly one term). It worked, and it is the
  origin of this design, but it caught mistakes at gate time rather than at
  dispatch, and nothing stopped a caller reaching past the gate. Lost to the type
  parameter, which is the same contract enforced by the method table.
- **Units on the element type** (a quantity type inside the array). Mixed-unit
  arithmetic inside kernels multiplies compile time and breaks library calls
  (reductions, sorts, transforms). Lost; the dimension lives on the field type and
  the element is a float.
- **A default reduction for intensive fields** (an area mean). The predecessor's
  record has the case: averaging a continuous field over every region in a cell
  dragged a coastal rock albedo toward open water. Lost; an intensive field's
  coarsening names its operator or refuses.

## Consequences

- Reductions are segmented kernels over contiguous child ranges (decision 0005).
- Quantile tables are computed by an in-block bitonic sort over a fixed
  power-of-four segment, exactly, not by a sketch.
- The vector crossing is a lift to three Cartesian components at the source frames,
  a remap of those, and a projection at the destination frames.
- Oracles implied: a constant field coarsens to a constant; an extensive integral is
  preserved to rounding; a solid-body rotation lifted, remapped and projected returns
  itself; the semantics-closure enumeration; every array written to the store carries
  semantics, time semantics, dimension, owner and interval, and the store refuses one
  that does not.

## References

- The predecessor's declared support vocabulary and the gate that required every
  reduction to be claimed by exactly one term:
  `/home/cfutro/docs/world/config/spatial_support.yaml`,
  `/home/cfutro/docs/world/lib/gridding.py`, `/home/cfutro/docs/world/lib/remap.py`.
- The predecessor's argument that a mesh-to-grid loss passes a conservation check
  exactly and needs an inventory:
  `/home/cfutro/docs/world/notes/audits/land-mosaic-support-reductions.md`,
  `/home/cfutro/docs/world/config/spatial_conversion.yaml`.
- Oceananigans.jl's location-typed fields, borrowed as an idea and not as code
  (decision 0012).
