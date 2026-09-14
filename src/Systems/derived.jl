# The Derived fields of a System, enumerated from the struct, and each recomputed
# from its inputs by its named rule. docs/plans/fiddlybits-52v.4-system.md, section
# "Oracles" (system.derived_fields_reproduce); decision 0007.

using ..Verdicts: refuse
using ..Dispositions: Disposition, Derived, value

"""
    derived_fields(system)

Every `Derived` value `system` holds, as `(path, derived)` pairs in field order,
found by walking the struct: `path` is the tuple of field names and tuple positions
that reaches the value from `system`.
"""
function derived_fields(system::System)
    found = Tuple{Tuple,Derived}[]
    walk_derived!(found, (), system)
    return found
end

walk_derived!(found, path::Tuple, d::Derived) = push!(found, (path, d))
walk_derived!(found, path::Tuple, ::Disposition) = nothing

function walk_derived!(found, path::Tuple, x::Tuple)
    for (i, y) in enumerate(x)
        walk_derived!(found, (path..., i), y)
    end
end

function walk_derived!(found, path::Tuple, x)
    parentmodule(typeof(x)) === (@__MODULE__) || return nothing
    for name in fieldnames(typeof(x))
        walk_derived!(found, (path..., name), getfield(x, name))
    end
end

"The value `path` reaches from `x`, a field name or a tuple position per step."
at_path(x, path::Tuple) = foldl((y, step) -> step isa Symbol ? getfield(y, step) : y[step],
                                path; init = x)

"""
    rederive(system, path)

The value of the `Derived` field at `path` in `system`, recomputed from the inputs
`system` holds by the rule the field names. Refuses a path that reaches no `Derived`
value, and a rule this module does not carry.
"""
function rederive(system::System{FT}, path::Tuple) where {FT}
    site = "Systems.rederive"
    d = at_path(system, path)
    d isa Derived || refuse("path", site, "$(path) reaches no Derived value")
    parent = at_path(system, path[1:end-1])
    rule = d.rule
    if rule === :stefan_boltzmann_effective_temperature
        return effective_temperature(FT, value(parent.luminosity), value(parent.radius))
    elseif rule === :stellar_model_luminosity || rule === :stellar_model_radius
        s = evaluate_stellar_model(parent.structure, parent.mass, parent.age,
                                   parent.metal_mass_fraction, site)
        return rule === :stellar_model_luminosity ? s.luminosity : s.radius
    elseif rule === :grid_interpolation
        star = at_path(system, path[1:end-2])
        axes = spectrum_axes(FT, value(star.mass), value(star.radius),
                             value(star.effective_temperature), value(star.metal_mass_fraction))
        return interpolate(parent.grid, Tuple(axes[a] for a in parent.grid.axes), site)
    elseif rule === :interior_model_radius
        return value(resolve_radius(parent.bulk, parent.mass, NamedTuple(), site))
    elseif rule === :synchronous_rotation_period
        return orbital_period(system, system.orbits.planet)
    elseif rule === :flux_semi_major_axis
        return semi_major_axis_from_flux(FT, value(system.stars[parent.primary.index].luminosity),
                                         value(parent.flux_at_semi_major_axis))
    end
    refuse("rule", site, "no rule named $(rule) is carried")
end
