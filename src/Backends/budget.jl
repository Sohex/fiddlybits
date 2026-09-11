# The memory budget: docs/plans/fiddlybits-52v.7-kernels.md, section "The
# budget".

using ..Verdicts: refuse

"""
    budget(declarations)

Total bytes from a plain description of what a run will allocate, one entry
per field with its element type and extent. `declarations` is a vector of
tuples `(name::String, element_type, extent::Integer)` where `element_type`
is a concrete type whose `sizeof` is known. Refuses at the point of reading
when a field is malformed: negative extent, an element type whose size
cannot be taken, or when the total exceeds the representable range.
"""
function budget(declarations)
    total = 0
    for (name, element_type, extent) in declarations
        if extent < 0
            refuse("field extent",
                   "Backends.budget",
                   "field $(name) has negative extent $(extent); extent must be non-negative")
        end

        field_size = try
            sizeof(element_type)
        catch err
            refuse("element type",
                   "Backends.budget",
                   "field $(name): cannot take sizeof($(element_type)): $(err)")
        end

        field_bytes = try
            Base.Checked.checked_mul(field_size, extent)
        catch err
            if err isa OverflowError
                refuse("memory overflow",
                       "Backends.budget",
                       "field $(name) with extent $(extent) has product that exceeds representable range")
            else
                rethrow(err)
            end
        end

        total = try
            Base.Checked.checked_add(total, field_bytes)
        catch err
            if err isa OverflowError
                refuse("memory overflow",
                       "Backends.budget",
                       "field $(name) with $(field_bytes) bytes causes total to exceed representable range; current total is $(total)")
            else
                rethrow(err)
            end
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
