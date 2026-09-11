# The memory budget: docs/plans/fiddlybits-52v.7-kernels.md, section "The
# budget".

using ..Verdicts: refuse

"""
    budget(declarations)

Total bytes from a plain description of what a run will allocate, one entry
per field with its element type and extent. `declarations` is a vector of
tuples `(name::String, element_type, extent::Integer)` where `element_type`
is a concrete type whose `sizeof` is known.
"""
function budget(declarations)
    total = 0
    for (name, element_type, extent) in declarations
        total += sizeof(element_type) * extent
    end
    return total
end

"""
    refuse_over(declarations, ceiling)

Refuse before allocating when the high-water estimate exceeds the declared
ceiling. `ceiling` is in bytes. Refuses with the fields in descending size
so the reader sees what to cut. Takes no action when the estimate is within
the ceiling.
"""
function refuse_over(declarations, ceiling)
    total = budget(declarations)
    if total > ceiling
        sizes = [(name, sizeof(element_type) * extent)
                 for (name, element_type, extent) in declarations]
        sort!(sizes, by=x -> x[2], rev=true)
        names_descending = join([name for (name, _) in sizes], ", ")
        refuse("memory budget",
               "Backends.refuse_over",
               "total $(total) bytes exceeds ceiling $(ceiling) bytes; fields in descending size: $(names_descending)")
    end
end
