module Kernel

using StaticArrays
using LinearAlgebra

buf = MVector{3,Float64}(0.0, 0.0, 0.0)
box = MMatrix{2,2,Float64}(0.0, 0.0, 0.0, 0.0)
mac = @MVector [1.0, 2.0, 3.0]
mbx = @MMatrix [1.0 0.0; 0.0 1.0]

out = MVector{3,Float64}(0.0, 0.0, 0.0)
mul!(out, SMatrix{3,3,Float64}(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0), SVector{3,Float64}(1.0, 2.0, 3.0))

draw_a() = @SVector rand(3)
draw_b() = @SMatrix rand(2, 2)
draw_c() = rand(SVector{3,Float64})
draw_d() = randn(MMatrix{2,2,Float64})

end
