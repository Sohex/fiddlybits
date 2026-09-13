# One recipe for the dispositions the suites in this directory build, so a test
# overrides the one part it is checking and states nothing else.

module DispositionFixtures

using Fiddlybits: Dispositions, Dimensions

"A `Locator` that constructs without refusing."
locator(; identifier = "10.1007/s10569-017-9805-5", table = "Table 1") =
    Dispositions.Locator(identifier = identifier, table = table)

"A `Sourced` that constructs without refusing."
sourced(; value = 1.0, dim = Dimensions.DIMENSIONLESS, locator = locator()) =
    Dispositions.Sourced(value = value, dim = dim, locator = locator)

"The field names a `Derived` fixture is checked against."
const KNOWN_FIELDS = (:mass, :radius)

"A `Derived` that constructs without refusing."
derived(; value = 1.0, dim = Dimensions.DIMENSIONLESS, from = (:mass,),
         rule = :rule, fields = KNOWN_FIELDS) =
    Dispositions.Derived(value = value, dim = dim, from = from, rule = rule,
                          fields = fields)

"A `Bracketed` that constructs without refusing."
bracketed(; value = 1.0, dim = Dimensions.DIMENSIONLESS, low = 0.0, high = 2.0,
           pushes_down = "a smaller mass", pushes_up = "a larger mass",
           sweep = :sweep) =
    Dispositions.Bracketed(value = value, dim = dim, low = low, high = high,
                           pushes_down = pushes_down, pushes_up = pushes_up,
                           sweep = sweep)

"An `Irreducible` that constructs without refusing."
irreducible(; value = 1.0, dim = Dimensions.DIMENSIONLESS,
             argument = "no observation of this world to fit",
             sensitivity = "notes/findings/fixture-sensitivity.md") =
    Dispositions.Irreducible(value = value, dim = dim, argument = argument,
                             sensitivity = sensitivity)

"A `Closure` that constructs without refusing."
closure(; law = :law, coefficient = bracketed(), levels = (3, 4)) =
    Dispositions.Closure(law = law, coefficient = coefficient, levels = levels)

end # module DispositionFixtures
