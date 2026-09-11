module Transcendentals

const PIO2_A = 1.5707963267341256
const PIO2_B = 6.077100506303966e-11
const TWO_OVER_PI = 0.6366197723675814
const TRIG_ARGUMENT_LIMIT = 262144.0
const SIN_SERIES = (-0.16666666666666666, 0.008333333333333333,
                    -0.0001984126984126984, 2.7557319223985893e-6)

@inline horner(z::Float64, c::Tuple{Float64}) = c[1]

@inline function sin_core(r::Float64, rlo::Float64)
    z = r * r
    return r - fma(0.5, rlo, z * 2.0)
end

@inline function quadrant_reduce(x::Float64)
    n = round(x * TWO_OVER_PI)
    return fma(-n, PIO2_A, x) - n * PIO2_B
end

end
