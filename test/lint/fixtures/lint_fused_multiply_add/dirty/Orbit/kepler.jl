module Kepler

@inline naive_kepler_residual(E, e, M) = E - e * sin(E) - M

@inline arm_by_negation(a, b, c, backend) = !bitwise(backend) ? a * b + c : fma(a, b, c)

@inline function arm_by_conjunction(a, b, c, wide, backend)
    if bitwise(backend) && wide
        return muladd(a, b, c)
    else
        return fma(a, b, c)
    end
end

end
