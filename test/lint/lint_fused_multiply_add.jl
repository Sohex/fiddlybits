# lint_fused_multiply_add: decision 0044, section "What the lint checks".
# Walks the expression tree Meta.parseall returns for every source file under
# root and refuses two shapes: a call to `+` or `-` with two or more arguments
# one of which is a call to `*`, or a `+=` or `-=` whose right-hand side is,
# and a call to `muladd`. A site is read as source bitwise mode compiles
# unless it stands in the false arm of a conditional whose test is a call to
# `bitwise`, or inside a function the list file names as reached only by fast
# mode, or under an entry of the list file's exemption table. A site a call to
# `bitwise` guards through any other shape is unclassified, and an
# unclassified site is refused with its own text.

const ADD_OPS = (:+, :-)
const ADD_ASSIGN = (Symbol("+="), Symbol("-="))
const SHORT_CIRCUIT = (Symbol("&&"), Symbol("||"))
const MUL_OP = :*
const FUSED_NAME = :muladd
const MODE_TEST = :bitwise

"The last name of a callee, so that `muladd` and `Base.muladd` give the same symbol."
function callee(ex)
    ex isa Symbol && return ex
    ex isa QuoteNode && return callee(ex.value)
    if ex isa Expr
        ex.head === :. && return callee(ex.args[end])
        ex.head === :quote && return callee(ex.args[1])
    end
    return nothing
end

"`true` when `ex` is a call to the function named `name`."
function is_call(ex, name::Symbol)
    ex isa Expr || return false
    ex.head === :call || return false
    isempty(ex.args) && return false
    return callee(ex.args[1]) === name
end

"`true` when a call to `bitwise` stands anywhere inside `ex`."
function holds_mode_test(ex)
    is_call(ex, MODE_TEST) && return true
    ex isa Expr || return false
    return any(holds_mode_test, ex.args)
end

"The signature under any number of `where` clauses."
unwrap_where(sig) = sig isa Expr && sig.head === :where ? unwrap_where(sig.args[1]) : sig

"The name a function definition signature declares, or `nothing`."
function def_name(sig)
    sig isa Symbol && return sig
    sig isa Expr || return nothing
    sig.head === :where && return def_name(sig.args[1])
    sig.head === :(::) && return def_name(sig.args[1])
    sig.head === :call && return def_name(sig.args[1])
    sig.head === :. && return def_name(sig.args[end])
    return nothing
end

"""
    def_of(ex)

The name `ex` defines a function under, or `nothing`. The short form
`f(x) = ...` and the long form `function f(x) ... end` both count; an
assignment whose left side is not a call does not. A definition wrapped in
`@inline`, `@kernel` or a docstring is reached by the walk descending into
the macro call and meeting the definition itself.
"""
function def_of(ex)
    ex isa Expr || return nothing
    ex.head === :function || ex.head === :(=) || return nothing
    length(ex.args) == 2 || return nothing
    sig = unwrap_where(ex.args[1])
    sig isa Expr && sig.head === :call || return nothing
    return def_name(sig)
end

"""
    Walker

One file's walk: the refusals it raised, the function names it saw defined,
the path it reads, and the fast-mode-only names and exemptions the list file
declares.
"""
struct Walker
    path::String
    fast_only::Set{Symbol}
    exemptions::Vector{Any}
    found::Vector{LintSupport.Site}
    defined::Set{Symbol}
    used::Set{Int}
end

Walker(path, fast_only, exemptions) =
    Walker(path, fast_only, exemptions, LintSupport.Site[], Set{Symbol}(), Set{Int}())

"The text of one offending expression, on one line, as Julia prints it."
site_text(ex) = replace(string(ex), r"\s+" => " ")

"`:fast` when any enclosing function is named fast-mode-only, and `mode` otherwise."
mode_here(w::Walker, names, mode) = any(n -> n in w.fast_only, names) ? :fast : mode

"`true` when an exemption names the function `name` and the text `text`, marking it used."
function exempt!(w::Walker, name, text::AbstractString)
    for (k, e) in enumerate(w.exemptions)
        e["path"] == w.path || continue
        Symbol(e["function"]) === name || continue
        e["found"] == text || continue
        push!(w.used, k)
        return true
    end
    return false
end

"Record one refusal under `prohibition`, unless the list file exempts it."
function refuse!(w::Walker, line::Int, names, prohibition::AbstractString, ex)
    text = site_text(ex)
    name = isempty(names) ? nothing : names[end]
    exempt!(w, name, text) && return nothing
    push!(w.found, LintSupport.Site(w.path, line, prohibition * ": " * text))
    return nothing
end

"The mode of the arm of a conditional or short-circuit `cond` guards, reached when `cond` is false."
false_arm_mode(cond, mode) = mode === :fast ? :fast :
                             is_call(cond, MODE_TEST) ? :fast :
                             holds_mode_test(cond) ? :unknown : mode

"The mode of the arm reached when `cond` is true."
true_arm_mode(cond, mode) = mode === :fast ? :fast :
                            is_call(cond, MODE_TEST) ? mode :
                            holds_mode_test(cond) ? :unknown : mode

"""
    walk!(w, ex, line, names, mode)

Walk `ex` and refuse every site of either prohibition whose mode is
`:bitwise` or `:unknown`. `line` is the line of the last statement entered,
`names` the stack of enclosing function names, `mode` the mode the site
compiles in. Returns the line the walk ended on.
"""
function walk!(w::Walker, ex, line::Int, names::Vector{Symbol}, mode::Symbol)
    ex isa Expr || return line
    here = mode_here(w, names, mode)
    tag(kind) = here === :unknown ? "unclassified " * kind : kind

    if ex.head === :call && length(ex.args) >= 3 && callee(ex.args[1]) in ADD_OPS
        if here !== :fast && any(a -> is_call(a, MUL_OP), ex.args[2:end])
            refuse!(w, line, names, tag("multiply feeds add"), ex)
        end
    elseif ex.head in ADD_ASSIGN && length(ex.args) == 2
        if here !== :fast && is_call(ex.args[2], MUL_OP)
            refuse!(w, line, names, tag("multiply feeds add"), ex)
        end
    elseif ex.head === :call && !isempty(ex.args) && callee(ex.args[1]) === FUSED_NAME
        here === :fast || refuse!(w, line, names, tag("muladd"), ex)
    end

    name = def_of(ex)
    inner = names
    if name !== nothing
        push!(w.defined, name)
        inner = vcat(names, name)
    end

    if ex.head in (:if, :elseif) && length(ex.args) >= 2
        cond = ex.args[1]
        line = walk!(w, cond, line, inner, mode)
        walk!(w, ex.args[2], line, inner, true_arm_mode(cond, mode))
        length(ex.args) >= 3 && walk!(w, ex.args[3], line, inner, false_arm_mode(cond, mode))
        return line
    end

    if ex.head in SHORT_CIRCUIT && length(ex.args) == 2
        cond = ex.args[1]
        line = walk!(w, cond, line, inner, mode)
        guard = ex.head === SHORT_CIRCUIT[1] ? true_arm_mode(cond, mode) : false_arm_mode(cond, mode)
        walk!(w, ex.args[2], line, inner, guard)
        return line
    end

    for arg in ex.args
        if arg isa LineNumberNode
            line = arg.line
        else
            line = walk!(w, arg, line, inner, mode)
        end
    end
    return line
end

"""
    lint_fused_multiply_add(root)

Every site under `root` that decision 0044's two prohibitions refuse, every
site the rule cannot classify, and every list-file entry that named nothing
in a file `root` holds.
"""
function lint_fused_multiply_add(root::AbstractString)
    cfg = LintSupport.list("fused_multiply_add.toml")
    fast_only = Set{Symbol}(Symbol(e["function"]) for e in cfg["fast_mode_only"])
    exemptions = cfg["exemption"]
    found = LintSupport.Site[]
    used = Set{Int}()
    defined = Dict{String,Set{Symbol}}()

    for path in LintSupport.sources(root)
        any(e -> startswith(path, e), cfg["exempt"]) && continue
        tree = Meta.parseall(read(joinpath(root, path), String); filename = path)
        w = Walker(path, fast_only, exemptions)
        walk!(w, tree, 0, Symbol[], :bitwise)
        append!(found, w.found)
        union!(used, w.used)
        defined[path] = w.defined
    end

    for (k, e) in enumerate(exemptions)
        haskey(defined, e["path"]) && !(k in used) &&
            push!(found, LintSupport.Site("lists/fused_multiply_add.toml", 0,
                                          "exemption named nothing: " * e["function"]))
    end
    for e in cfg["fast_mode_only"]
        haskey(defined, e["path"]) && !(Symbol(e["function"]) in defined[e["path"]]) &&
            push!(found, LintSupport.Site("lists/fused_multiply_add.toml", 0,
                                          "fast_mode_only named nothing: " * e["function"]))
    end
    return found
end
