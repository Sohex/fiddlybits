# Locator: docs/plans/fiddlybits-52v.4-system.md, section "The five dispositions";
# decision 0007; REQ-SYS-001.
#
# Both fields are required and neither may be empty, so there is no constructor that
# takes an identifier alone.

using ..Verdicts: refuse

"""
    Locator(; identifier, table)

The work a `Sourced` value is taken from: its identifier, as carried into
`docs/references/INDEX.md`, and the table or equation the value comes from.
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
