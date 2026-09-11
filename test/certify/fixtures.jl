# The stand-in certification case: a synthetic 4^k layout with a stencil-shaped
# gather over flat index tables, built without Mesh, which sits above Backends.
# The plan (docs/plans/fiddlybits-52v.7-kernels.md, section "Oracles") declares
# the stand-in and the verify row records that it is one.

using Fiddlybits: Backends, Reductions

module CertifyFixtures

using Fiddlybits: Backends, Reductions

const FANOUT = 4
const DEPTH = 5
const N_CELLS = FANOUT^DEPTH
const NK = FANOUT
const STEPS = 20

"Every term one cell of the step sums: the NK the gather reads and the one the
field coupling adds."
const TERMS = NK + 1

"The coupling angle between the two fields, in radians, as a power of two so the
same value is exact at Float32 and Float64."
const COUPLING = 1 / 64

"""
    neighbours(n)

The neighbour table of the `4^k` layout: the other `FANOUT - 1` cells of a
cell's own quad, then the cell at the same position in the next quad.
"""
function neighbours(n::Integer)
    nb = Matrix{Int32}(undef, NK, n)
    nq = div(n, FANOUT)
    for i in 1:n
        q = div(i - 1, FANOUT)
        r = mod(i - 1, FANOUT)
        for k in 1:(FANOUT - 1)
            nb[k, i] = Int32(FANOUT * q + mod(r + k, FANOUT) + 1)
        end
        nb[FANOUT, i] = Int32(FANOUT * mod(q + 1, nq) + r + 1)
    end
    return nb
end

"""
    weights(T, n)

The gather weights, every column summing to one, from a fixed formula rather
than a draw.
"""
function weights(::Type{T}, n::Integer) where {T}
    w = Matrix{T}(undef, NK, n)
    for i in 1:n
        raw = [Float64(mod(i * 7 + k * 13, 17) + 1) for k in 1:NK]
        s = sum(raw)
        for k in 1:NK
            w[k, i] = T(raw[k] / s)
        end
    end
    return w
end

field_u(::Type{T}, n::Integer) where {T} = T[T(mod(i * 31 + 7, 97)) / T(20) - T(2) for i in 1:n]
field_v(::Type{T}, n::Integer) where {T} = T[T(mod(i * 53 + 11, 89)) / T(30) - T(1) for i in 1:n]

"""
    make_step(n, nb, w64; scale = 1)

One step of the stand-in case, at whatever floating point type the state
carries: each field gathered over the stencil in a fixed order, then the two
gathered fields mixed by a rotation of angle `COUPLING`. `scale` multiplies
every weight, which is how a test injects a defect of a named relative
magnitude.
"""
function make_step(n::Integer, nb::AbstractMatrix, w64::AbstractMatrix; scale::Real = 1)
    function step!(state::Vector{Vector{T}}) where {T}
        u, v = state[1], state[2]
        w = T.(w64) .* T(scale)
        ut = Vector{T}(undef, n)
        vt = Vector{T}(undef, n)
        for i in 1:n
            au = zero(T)
            av = zero(T)
            for k in 1:NK
                au += u[nb[k, i]] * w[k, i]
                av += v[nb[k, i]] * w[k, i]
            end
            ut[i] = au + T(COUPLING) * av
            vt[i] = av - T(COUPLING) * au
        end
        copyto!(u, ut)
        copyto!(v, vt)
        return state
    end
    return step!
end

"""
    stand_in()

The stand-in case, its neighbour table and its weight table.
"""
function stand_in()
    nb = neighbours(N_CELLS)
    w64 = weights(Float64, N_CELLS)
    fields = [field_u(Float64, N_CELLS), field_v(Float64, N_CELLS)]
    return Backends.EnsembleCase("stencil-4^5", fields, make_step(N_CELLS, nb, w64)), nb, w64
end

"""
    roundoff(case)

The divergence one step of the candidate at `Float32` injects, in the one norm
`Backends.divergence` returns: the per-cell bound of `Reductions.error_bound`,
which is the one definition of this quantity in the tree, at the `TERMS` terms
one cell sums and the largest absolute value the step can reach, summed over
every cell of every field. The term count is checked against
`Reductions.validity_limit` before it is read.
"""
function roundoff(case::Backends.EnsembleCase)
    TERMS < Reductions.validity_limit(Float32) ||
        error("the stand-in case sums $(TERMS) terms per cell, which Reductions.error_bound " *
              "refuses at Float32")
    magnitude = maximum(maximum(abs, f) for f in case.fields) * (1 + COUPLING)
    ncells = sum(length, case.fields)
    return ncells * Reductions.error_bound(Float32, TERMS, magnitude)
end

"""
    injected(nb, w64, relative)

A candidate whose `Float32` path scales every weight by `1 + relative` and whose
`Float64` path does not. The certification asks whether a kernel at `Float32`
stays inside the envelope of its own `Float64` run, so the defect it can see is
one the two paths do not share; a defect present in both is the reference path's
to catch (decision 0027, test/backends/reference_agreement.jl).
"""
function injected(nb::AbstractMatrix, w64::AbstractMatrix, relative::Real)
    good = make_step(N_CELLS, nb, w64)
    bad = make_step(N_CELLS, nb, w64; scale = 1 + relative)
    return function (state::Vector{Vector{T}}) where {T}
        return T === Float32 ? bad(state) : good(state)
    end
end

"""
    constant_case()

A case whose step overwrites the state with the same values every time, so no
perturbation reaches the next step and the envelope is not measurable.
"""
function constant_case()
    fields = [field_u(Float64, FANOUT)]
    frozen = copy(fields[1])
    step!(state) = (copyto!(state[1], eltype(state[1]).(frozen)); state)
    return Backends.EnsembleCase("constant", fields, step!)
end

"""
    zero_case()

A case whose only field is all zeros, so it has no field with a scale an ulp can
be taken of.
"""
zero_case() = Backends.EnsembleCase("zero", [zeros(Float64, FANOUT)], state -> state)

"""
    doubling_case()

A case whose step doubles the state, so at `Float64` it leaves the finite range
after 1024 steps and the divergence at and after that step cannot be measured.
"""
function doubling_case()
    fields = [fill(1.0, FANOUT)]
    step!(state) = (state[1] .*= 2; state)
    return Backends.EnsembleCase("doubling", fields, step!)
end

"""
    small_case()

A case with fewer usable sites than `Backends.ENSEMBLE_MEMBERS`, so its ensemble
is exhaustive.
"""
function small_case()
    n = FANOUT^2
    nb = neighbours(n)
    w64 = weights(Float64, n)
    fields = [field_u(Float64, n), field_v(Float64, n)]
    return Backends.EnsembleCase("stencil-4^2", fields, make_step(n, nb, w64))
end

end # module CertifyFixtures

const CASE, CASE_NB, CASE_W = CertifyFixtures.stand_in()
const CASE_ENVELOPE = Backends.envelope(CASE, CertifyFixtures.STEPS)
const CASE_ROUNDOFF = CertifyFixtures.roundoff(CASE)
