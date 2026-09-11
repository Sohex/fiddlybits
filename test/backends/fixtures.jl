# Shared synthetic inputs for the Backends suite: fixed formulas so every run
# sees the same numbers, and no dependency on Mesh, which sits above this
# module.

module BackendFixtures

const N_CELLS = 4^5
const NK = 4

"The floating point error bound for a fixed-order sum of `n` terms about
`magnitude` in absolute value (Higham 1993), derived from `T`'s own epsilon
rather than chosen."
fp_tolerance(::Type{T}, n::Integer, magnitude::Real) where {T} = n * eps(T) * T(magnitude)

"A vector of `n` values of type `T` from a fixed formula, not a random draw."
seeded_vector(::Type{T}, n::Integer) where {T} = T[T(mod(i * 31 + 7, 97)) / T(20) - T(2) for i in 1:n]

"A synthetic `nk` by `n` neighbour and weight table from a fixed formula,
shaped like `Mesh.Stencils` but built without it."
function stencil_tables(::Type{T}, n::Integer, nk::Integer) where {T}
    neighbour = Matrix{Int32}(undef, nk, n)
    weight = Matrix{T}(undef, nk, n)
    for i in 1:n, k in 1:nk
        neighbour[k, i] = mod1(i + k * 37 - 11, n)
        weight[k, i] = T(mod(i * 7 + k * 13, 101) - 50) / T(50)
    end
    return neighbour, weight
end

end # module BackendFixtures
