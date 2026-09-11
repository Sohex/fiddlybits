# The memory budget: docs/plans/fiddlybits-52v.7-kernels.md, section "The
# budget".

using ..Verdicts: refuse

"""
    budget(declarations)

Total bytes from a plain description of what a run will allocate, one entry
per field with its element type and extent. `declarations` is a vector of
tuples `(name::String, element_type, extent::Integer)` where `element_type`
is a concrete type whose `sizeof` is known. Refuses at the point of reading
when a field is malformed: negative extent, or an element type whose size
cannot be taken.
"""
function budget(declarations)
    total = 0
    for (name, element_type, extent) in declarations
        if extent < 0
            refuse("field extent",
                   "Backends.budget",
                   "field $(name) has negative extent $(extent); extent must be non-negative")
        end
        try
            field_bytes = sizeof(element_type) * extent
            total += field_bytes
        catch err
            refuse("element type",
                   "Backends.budget",
                   "field $(name): cannot take sizeof($(element_type)): $(err)")
        end
    end
    return total
end

"""
    refuse_over(declarations, ceiling)

Refuse before allocating when the high-water estimate exceeds the declared
ceiling. `ceiling` is in bytes. Refuses with the fields in descending size
and their byte counts so the reader sees what to cut. Takes no action when
the estimate is within the ceiling.
"""
function refuse_over(declarations, ceiling)
    total = budget(declarations)
    if total > ceiling
        sizes = [(name, sizeof(element_type) * extent)
                 for (name, element_type, extent) in declarations]
        sort!(sizes, by = x -> x[2], rev = true)
        fields_with_sizes = join(["$(name) ($(bytes) bytes)" for (name, bytes) in sizes], ", ")
        refuse("memory budget",
               "Backends.refuse_over",
               "total $(total) bytes exceeds ceiling $(ceiling) bytes; fields in descending size: $(fields_with_sizes)")
    end
end
