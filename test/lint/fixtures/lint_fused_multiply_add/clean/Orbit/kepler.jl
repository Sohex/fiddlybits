module Kepler

@inline fma_add(a, b, c, backend) = bitwise(backend) ? fma(a, b, c) : muladd(a, b, c)

@inline function arm_by_if(a, b, c, backend)
    if bitwise(backend)
        return fma(a, b, c)
    else
        return a * b + c
    end
end

@inline function arm_by_short_circuit(a, b, c, backend)
    bitwise(backend) || return muladd(a, b, c)
    return fma(a, b, c)
end

@inline naive_kepler_residual(E, e, M) = E - e * sin(E) - M

@inline function sin_core(r, rlo, v, w)
    return fma(0.5, rlo, -(v * w))
end

@inline horner(z, c) = fma(horner(z, Base.tail(c)), z, c[1])

end
