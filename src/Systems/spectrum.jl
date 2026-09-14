# A star's spectrum: interpolated in a carried stellar atmosphere grid, or Bracketed
# per wavelength. docs/plans/fiddlybits-52v.4-system.md, section "The struct";
# decision 0004, the stars.

using ..Verdicts: refuse
using ..Dimensions: Dim
using ..Dispositions: Bracketed, Derived, value, dimension

"The dimension of a surface flux density per unit wavelength: mass length^-1 time^-3."
const SPECTRAL_FLUX = Dim{1,-1,-3,0,0}()

"The stellar quantities a spectrum grid may take as an axis, by name, each in SI."
const GRID_AXES = (:effective_temperature, :surface_gravity, :metal_mass_fraction)

"The Star fields each grid axis is computed from."
const GRID_AXIS_INPUTS = (effective_temperature = (:luminosity, :radius),
                          surface_gravity = (:mass, :radius),
                          metal_mass_fraction = (:metal_mass_fraction,))

"""
    SpectrumGrid(; identifier, axes, nodes, wavelengths, flux, present)

A stellar atmosphere grid carried by the system: `identifier` (the input manifest's
identifier, part of the run identity), the named `axes` drawn from `GRID_AXES`, the
strictly increasing `nodes` of each axis, the strictly increasing positive
`wavelengths` in metres, the surface flux density per wavelength `flux` indexed by
node along each axis and then by wavelength, and `present`, which marks the nodes the
grid holds.
"""
struct SpectrumGrid{FT,N,M}
    identifier::String
    axes::NTuple{N,Symbol}
    nodes::NTuple{N,Vector{FT}}
    wavelengths::Vector{FT}
    flux::Array{FT,M}
    present::Array{Bool,N}

    function SpectrumGrid{FT,N,M}(::Checked, identifier, axes, nodes, wavelengths, flux,
                                  present) where {FT,N,M}
        return new{FT,N,M}(identifier, axes, nodes, wavelengths, flux, present)
    end
end

"`true` when `v` holds at least two entries, each above the one before."
strictly_increasing(v::AbstractVector) = length(v) >= 2 && all(v[i] < v[i+1] for i in 1:length(v)-1)

function SpectrumGrid(; kwargs...)
    site = "Systems.SpectrumGrid"
    k, _ = read_keywords(site, values(kwargs),
                         (:identifier, :axes, :nodes, :wavelengths, :flux, :present), ())
    (k.identifier isa AbstractString && !isempty(k.identifier)) || refuse(
        "identifier", site, "the grid names no identifier")
    axes = require_names("axes", site, k.axes)
    for a in axes
        a in GRID_AXES || refuse(
            "axes", site, "$(a) is not a grid axis; the axes are $(join(GRID_AXES, ", "))")
    end
    N = length(axes)
    nodes = require_length("nodes", site, k.nodes, N, "axis")
    wavelengths = require_type("wavelengths", site, k.wavelengths, Vector{<:AbstractFloat})
    FT = eltype(wavelengths)
    (strictly_increasing(wavelengths) && wavelengths[1] > zero(FT)) || refuse(
        "wavelengths", site, "the wavelengths are not positive and strictly increasing")
    for (a, n) in zip(axes, nodes)
        (n isa Vector{FT} && strictly_increasing(n)) || refuse(
            "nodes", site, "the nodes of $(a) are not a strictly increasing Vector{$(FT)}")
    end
    shape = Tuple(length(n) for n in nodes)
    flux = require_type("flux", site, k.flux, Array{FT,N + 1})
    size(flux) == (shape..., length(wavelengths)) || refuse(
        "flux", site,
        "the flux has size $(size(flux)) where $((shape..., length(wavelengths))) is required")
    present = require_type("present", site, k.present, Array{Bool,N})
    size(present) == shape || refuse(
        "present", site, "the node mask has size $(size(present)) where $(shape) is required")
    return SpectrumGrid{FT,N,N + 1}(Checked(), String(k.identifier), axes, nodes,
                                    wavelengths, flux, present)
end

"""
    interpolate(grid, point, site)

The flux of `grid` at `point`, one value per axis in `grid.axes` order, by
multilinear interpolation in the enclosing cell. Refuses at `site` a coordinate
outside its axis's node range, and a cell whose corner of non-zero weight is not
present in the grid; every point outside the convex hull of the present nodes meets
one of the two.
"""
function interpolate(grid::SpectrumGrid{FT,N}, point::NTuple{N,FT},
                     site::AbstractString) where {FT,N}
    lower = Vector{Int}(undef, N)
    fraction = Vector{FT}(undef, N)
    for a in 1:N
        x = point[a]
        nodes = grid.nodes[a]
        (nodes[1] <= x <= nodes[end]) || refuse(
            "spectrum", site,
            "$(grid.axes[a]) = $(x) lies outside [$(nodes[1]), $(nodes[end])], the " *
            "span of the grid $(grid.identifier), so the point is outside its convex hull")
        i = min(searchsortedlast(nodes, x), length(nodes) - 1)
        lower[a] = i
        fraction[a] = (x - nodes[i]) / (nodes[i+1] - nodes[i])
    end
    out = zeros(FT, length(grid.wavelengths))
    index = Vector{Int}(undef, N)
    for corner in 0:(2^N - 1)
        weight = one(FT)
        for a in 1:N
            up = isodd(corner >> (a - 1))
            weight *= up ? fraction[a] : one(FT) - fraction[a]
            index[a] = up ? lower[a] + 1 : lower[a]
        end
        iszero(weight) && continue
        grid.present[index...] || refuse(
            "spectrum", site,
            "the node $(Tuple(grid.nodes[a][index[a]] for a in 1:N)) on the axes " *
            "$(grid.axes) is absent from the grid $(grid.identifier), so the point " *
            "is outside the convex hull of the nodes it holds or in a hole of the grid")
        f = view(grid.flux, index..., :)
        for w in eachindex(out)
            out[w] = fma(weight, f[w], out[w])
        end
    end
    return out
end

"""
    GridSpectrum

A star's spectrum interpolated in a carried grid: the grid, the point it was read
at in the grid's axis order, the wavelengths, and the surface flux density as a
`Derived` value.
"""
struct GridSpectrum{FT,N,M,K}
    grid::SpectrumGrid{FT,N,M}
    point::NTuple{N,FT}
    wavelengths::Vector{FT}
    surface_flux_density::Derived{Vector{FT},typeof(SPECTRAL_FLUX),K}
end

"""
    BracketedSpectrum(; wavelengths, surface_flux_density)

A star's spectrum declared where no grid is carried: strictly increasing positive
`wavelengths` in metres and one `Bracketed` surface flux density per wavelength.
"""
struct BracketedSpectrum{FT}
    wavelengths::Vector{FT}
    surface_flux_density::Vector{Bracketed{FT,typeof(SPECTRAL_FLUX)}}

    function BracketedSpectrum{FT}(::Checked, wavelengths, density) where {FT}
        return new{FT}(wavelengths, density)
    end
end

function BracketedSpectrum(; kwargs...)
    site = "Systems.BracketedSpectrum"
    k, _ = read_keywords(site, values(kwargs), (:wavelengths, :surface_flux_density), ())
    wavelengths = require_type("wavelengths", site, k.wavelengths, Vector{<:AbstractFloat})
    FT = eltype(wavelengths)
    (strictly_increasing(wavelengths) && wavelengths[1] > zero(FT)) || refuse(
        "wavelengths", site, "the wavelengths are not positive and strictly increasing")
    density = require_type("surface_flux_density", site, k.surface_flux_density,
                           AbstractVector)
    length(density) == length(wavelengths) || refuse(
        "surface_flux_density", site,
        "$(length(density)) values where $(length(wavelengths)), one per wavelength, " *
        "are required")
    for d in density
        require_disposition("surface_flux_density", site, d, FT, SPECTRAL_FLUX, (Bracketed,))
        require_interval("surface_flux_density", site, d, zero(FT), true, typemax(FT), true)
    end
    return BracketedSpectrum{FT}(Checked(), wavelengths,
                                 Vector{Bracketed{FT,typeof(SPECTRAL_FLUX)}}(density))
end

"""
    resolve_spectrum(spectrum, star, fields, site)

The spectrum a star carries. A `SpectrumGrid` is interpolated at the star's own
values of the grid's axes, taken by name from the `NamedTuple` `star`, and returned
as a `GridSpectrum` whose `Derived` value names the Star fields in `fields` it was
computed from; a `BracketedSpectrum` of the star's type is returned as it is.
Refuses anything else at `site`.
"""
function resolve_spectrum(grid::SpectrumGrid{FT,N}, star::NamedTuple, fields,
                          site::AbstractString) where {FT,N}
    point = Tuple(FT(star[a]) for a in grid.axes)
    density = interpolate(grid, point, site)
    from = Tuple(unique(Iterators.flatten(GRID_AXIS_INPUTS[a] for a in grid.axes)))
    derived = Derived(value = density, dim = SPECTRAL_FLUX, from = from,
                      rule = :grid_interpolation, fields = fields)
    return GridSpectrum(grid, point, grid.wavelengths, derived)
end

resolve_spectrum(spectrum::BracketedSpectrum, star::NamedTuple, fields,
                 site::AbstractString) = spectrum

resolve_spectrum(spectrum, star::NamedTuple, fields, site::AbstractString) = refuse(
    "spectrum", site,
    "a $(typeof(spectrum)) where a SpectrumGrid or a BracketedSpectrum is required")
