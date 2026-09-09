# DynamicQuantities.jl

**What it is.** Physical dimensions as an isbits value type with rational
exponents, so dimension algebra is cheap and does not create a type per unit.

**What of it is used.** The host-side dimension algebra behind `Dim{M,L,T,Theta,N}` on
the `Field` type, and dimension checks at operator boundaries. Never inside a
kernel; kernels see raw floats.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none in the dimension algebra; the unit registry carries symbolic constants | only SI base dimensions are used; `test/params/lint_earth.jl` forbids the registry's named constants in physics modules |
| precision | quantity values are `Float64` by default | values never live inside quantities; dimensions only |
| GPU | quantities are isbits but are not used on device | lint: no `Quantity` type in any `@kernel` |

**Licence.** Apache-2.0 `to verify`. **Version.** `to pin`.

**Checklist items applied.** A2 (the unit registry is a constant block; none of
it is used), C1 (dimension checks are applied at operator call sites, tested by
`test/fields/dimension_refusal.jl`).
