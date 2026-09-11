# The dirty arm of the package-image check: a package on the load path that is never
# loaded, so it is never precompiled and Base.isprecompiled answers false for it.

module NotPrecompiled
end
