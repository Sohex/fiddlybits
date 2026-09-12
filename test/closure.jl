# The closed-vocabulary check, for every suite that closes one: Events, Verdicts and
# Time today, and the vocabularies named in the fields and system plans later. One
# definition, in a module of its own, because `test/runtests.jl` includes every suite
# into `Main` and a second definition there replaces the first
# (`docs/decisions/0049-the-gate-runs-its-suites-as-processes.md` for the same shape
# on the suite list).
#
# A suite reaches it with
#
#     isdefined(@__MODULE__, :VocabularyClosure) ||
#         include(joinpath(@__DIR__, "..", "closure.jl"))
#     using .VocabularyClosure: closed_set, Fixture
#
# so the second suite to load in one process includes nothing, and a suite that
# defines `closed_set` of its own raises `invalid method definition` rather than
# taking the name in silence
# (notes/findings/2026-09-12-a-silent-method-overwrite-in-main.md).
# `test/build/shared_helper.jl` holds both as tests.

module VocabularyClosure

using InteractiveUtils: subtypes

"""
    closed_set(T, enumeration)

`(undeclared, unreachable)`: the subtypes of `T` that `enumeration` omits, and the
entries of `enumeration` that are not subtypes of `T`. Both empty means the
enumeration is the whole of `T`.
"""
function closed_set(T::Type, enumeration)
    declared = Set(typeof(v) for v in enumeration)
    present = Set(subtypes(T))
    return (sort(collect(setdiff(present, declared)), by = string),
            sort(collect(setdiff(declared, present)), by = string))
end

"""
A hierarchy no module under test declares, with a partial and a whole enumeration of
it, so every caller of `closed_set` has a positive control to fire on each side.
"""
module Fixture
    abstract type Colour end
    struct Red <: Colour end
    struct Blue <: Colour end
    partial() = (Red(),)
    whole() = (Red(), Blue())
end

end # module VocabularyClosure
