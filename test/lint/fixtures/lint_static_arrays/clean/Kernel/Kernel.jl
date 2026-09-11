module Kernel

using StaticArrays

function combine(a::SVector{3,Float64}, b::SVector{3,Float64})
    return a * 2.0 .+ b
end

function operate(m::SMatrix{3,3,Float64}, v::SVector{3,Float64})
    return m * v
end

function counter_draw(seed::Int, index::Int)
    return Float64((seed * 6364136223846793005 + index) % 1000) / 1000.0
end

function state(seed::Int)
    x = counter_draw(seed, 1)
    y = counter_draw(seed, 2)
    z = counter_draw(seed, 3)
    return SVector(x, y, z)
end

end
