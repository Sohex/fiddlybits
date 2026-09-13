# Locator: docs/plans/fiddlybits-52v.4-system.md, section "The five dispositions";
# decision 0007; REQ-SYS-001.

using ..Verdicts: refuse

"""
    Locator(; identifier, table)

The work a `Sourced` value is taken from: its identifier, and the table or equation
the value comes from. `identifier` is either a bare DOI or, for a row of
`docs/references/INDEX.md` with no DOI, that row's file key (its first column).
"""
struct Locator
    identifier::String
    table::String

    function Locator(; identifier::AbstractString, table::AbstractString)
        isempty(identifier) && refuse(
            "locator", "Dispositions.Locator", "the identifier is empty")
        isempty(table) && refuse(
            "locator", "Dispositions.Locator",
            "$(identifier) names no table or equation")
        return new(String(identifier), String(table))
    end
end
