# The kernel launch: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer".

import KernelAbstractions

"""
    launch!(kernel, backend::Backend, n::Integer, args...)

Compile `kernel` (a `KernelAbstractions.@kernel` function) for `backend`'s
device at `backend`'s workgroup size, launch it over `n` work items with
`args`, and synchronize before returning.
"""
function launch!(kernel, backend::Backend, n::Integer, args...)
    dev = ka_backend(backend)
    compiled = kernel(dev, workgroup(backend))
    compiled(args...; ndrange = n)
    KernelAbstractions.synchronize(dev)
    return nothing
end
