# The closed-vocabulary check, for every suite that closes one: Events, Verdicts,
# Time and Fields today, and the vocabularies named in the system plan later. One
# definition, `closed_type_set`, with a door for a vocabulary enumerated by instance
# and one for a vocabulary enumerated by type. In a module of its own, because
# `test/runtests.jl` includes every suite into `Main` and a second definition there
# replaces the first
# (`docs/decisions/0049-the-gate-runs-its-suites-as-processes.md` for the same shape
# on the suite list).
#
# A suite reaches it with
#
#     isdefined(@__MODULE__, :VocabularyClosure) ||
#         include(joinpath(@__DIR__, "..", "closure.jl"))
#     using .VocabularyClosure: closed_set, Fixture           # enumerated by instance
#     using .VocabularyClosure: closed_type_set, TypeFixture   # enumerated by type
#
# so the second suite to load in one process includes nothing, and a suite that
# defines `closed_set` of its own raises `invalid method definition` rather than
# taking the name in silence
# (notes/findings/2026-09-12-the-overwrite-warning-reaches-one-door-of-two.md).
# `test/build/shared_helper.jl` holds both as tests.

module VocabularyClosure

using InteractiveUtils: subtypes

"""
    closed_type_set(T, types)

`(undeclared, unreachable)`: the subtypes of `T` that `types` omits, and the entries
of `types` that are not subtypes of `T`. Both empty means `types` is the whole of
`T`. `subtypes` returns a parametric subtype as its `UnionAll`, so an enumeration
naming the head and nothing else matches it.
"""
function closed_type_set(T::Type, types)
    declared = Set(types)
    present = Set(subtypes(T))
    return (sort(collect(setdiff(present, declared)), by = string),
            sort(collect(setdiff(declared, present)), by = string))
end

"""
    closed_set(T, enumeration)

The same for a vocabulary enumerated by one instance per type: `typeof` each entry
and read `closed_type_set`. A vocabulary with a parametric member has no one instance
to stand for it and is enumerated by its types, so it reads `closed_type_set`
directly; `Fields.semantics_types()` is the one that does.
"""
closed_set(T::Type, enumeration) = closed_type_set(T, (typeof(v) for v in enumeration))

"""
A hierarchy no module under test declares, with a partial and a whole enumeration of
it by instance, so every caller of `closed_set` has a positive control to fire on
each side.
"""
module Fixture
    abstract type Colour end
    struct Red <: Colour end
    struct Blue <: Colour end
    partial() = (Red(),)
    whole() = (Red(), Blue())
end

"""
The same for `closed_type_set`, enumerated by type and carrying a parametric member,
which is what an instance enumeration cannot reach. Kept apart from `Fixture` because
adding a parametric subtype to that hierarchy would put a member in it that
`Fixture.whole()` cannot name.
"""
module TypeFixture
    abstract type Tone end
    struct Flat <: Tone end
    struct Graded{N} <: Tone end
    partial() = (Flat,)
    whole() = (Flat, Graded)
end

end # module VocabularyClosure
