# The artifact key, the code version and the run id: docs/plans/fiddlybits-52v.6-provenance.md,
# section "The key"; decision 0010; REQ-PROV-002. SHA-256 over the canonical serialisation
# for keys and UUID version 4 for run ids, as docs/imports/sha-uuids.md records them.
# Every word is written little-endian at a fixed width, and every member named by a name
# is written in sorted name order.

using SHA: sha256
using UUIDs: UUIDs, UUID, uuid4
using ..Verdicts: Refusal, refuse
using ..Backends: bitwise
using ..Systems: Systems, System, Checked, read_keywords, require_type
using ..Mesh: Mesh, write_le!, write_symbol!, write_digest!
using ..Coupling: Coupling, Declaration

# ---------------------------------------------------------------- canonical serialisation

"The byte that opens a `Float16`, `Float32` or `Float64` in `canonical_bytes`."
const TAG_FLOAT = 0x01

"The byte that opens a signed integer in `canonical_bytes`."
const TAG_SIGNED = 0x02

"The byte that opens an unsigned integer in `canonical_bytes`."
const TAG_UNSIGNED = 0x03

"The byte that opens a `Bool` in `canonical_bytes`."
const TAG_BOOL = 0x04

"The byte that opens a `Symbol` in `canonical_bytes`."
const TAG_SYMBOL = 0x05

"The byte that opens a `String` in `canonical_bytes`."
const TAG_STRING = 0x06

"The byte that stands for `nothing` in `canonical_bytes`."
const TAG_NOTHING = 0x07

"The byte that opens a `Tuple` in `canonical_bytes`."
const TAG_TUPLE = 0x08

"The byte that opens a `NamedTuple` in `canonical_bytes`."
const TAG_NAMED_TUPLE = 0x09

"The byte that opens an `Array` in `canonical_bytes`."
const TAG_ARRAY = 0x0a

"The byte that opens an immutable struct in `canonical_bytes`."
const TAG_STRUCT = 0x0b

"The byte that opens a type in `canonical_bytes`."
const TAG_TYPE = 0x0c

"The byte that stands for a `:` step of a path in `parameter_digest`."
const TAG_COLON = 0x0d

"The name that opens the bytes `parameter_digest` hashes."
const PARAMETER_DOMAIN = :fiddlybits_parameter_subset

"The name that opens the bytes `ArtifactKey` hashes."
const KEY_DOMAIN = :fiddlybits_artifact_key

"The site every refusal of the canonical serialisation names."
const CANONICAL_SITE = "Provenance.canonical_bytes"

"Refuses a value of type `T`, which has no canonical serialisation."
no_serialisation(T) = refuse("canonical serialisation", CANONICAL_SITE,
                             "a value of type $(T) has no canonical serialisation")

"Writes the count `n` as a `UInt64` word."
write_count!(io::IO, n::Integer) = write_le!(io, UInt64(n))

"""
    write_type!(io, T)

Writes the type `T`: its module's full name as a count and each name, its own name, and
a count of its parameters followed by each, a type written by `write_type!` after
`TAG_TYPE` and any other parameter by `write_canonical!`. Refuses a `T` that is not a
`DataType`.
"""
function write_type!(io::IO, T)
    T isa DataType || no_serialisation(T)
    path = fullname(parentmodule(T))
    write_count!(io, length(path))
    foreach(name -> write_symbol!(io, name), path)
    write_symbol!(io, nameof(T))
    write_count!(io, length(T.parameters))
    for p in T.parameters
        if p isa Type
            write(io, TAG_TYPE)
            write_type!(io, p)
        else
            write_canonical!(io, p)
        end
    end
    return io
end

"Writes the UTF-8 bytes of `s` after their count; refuses a string that is not valid UTF-8."
function write_utf8!(io::IO, s::String)
    isvalid(s) || refuse("canonical serialisation", CANONICAL_SITE, "$(repr(s)) is not valid UTF-8")
    bytes = codeunits(s)
    write_count!(io, length(bytes))
    write(io, bytes)
    return io
end

"""
    write_canonical!(io, x)

Writes `x` to `io` in the layout `canonical_bytes` states; refuses what it refuses.
"""
function write_canonical!(io::IO, x::Union{Float16,Float32,Float64})
    write(io, TAG_FLOAT)
    write(io, UInt8(sizeof(x)))
    write(io, htol(reinterpret(bits_type(x), x)))
    return io
end

"The unsigned integer type of the width of the float `x`."
bits_type(::Float16) = UInt16
bits_type(::Float32) = UInt32
bits_type(::Float64) = UInt64

function write_canonical!(io::IO, x::Bool)
    write(io, TAG_BOOL)
    write(io, x ? 0x01 : 0x00)
    return io
end

function write_canonical!(io::IO, x::Union{Int8,Int16,Int32,Int64})
    write(io, TAG_SIGNED)
    write_le!(io, Int64(x))
    return io
end

function write_canonical!(io::IO, x::Union{UInt8,UInt16,UInt32,UInt64})
    write(io, TAG_UNSIGNED)
    write_le!(io, UInt64(x))
    return io
end

function write_canonical!(io::IO, x::Symbol)
    write(io, TAG_SYMBOL)
    write_symbol!(io, x)
    return io
end

function write_canonical!(io::IO, x::String)
    write(io, TAG_STRING)
    write_utf8!(io, x)
    return io
end

write_canonical!(io::IO, ::Nothing) = write(io, TAG_NOTHING)

function write_canonical!(io::IO, x::Tuple)
    write(io, TAG_TUPLE)
    write_count!(io, length(x))
    foreach(y -> write_canonical!(io, y), x)
    return io
end

function write_canonical!(io::IO, x::NamedTuple)
    write(io, TAG_NAMED_TUPLE)
    write_count!(io, length(x))
    for name in sort(collect(keys(x)))
        write_symbol!(io, name)
        write_canonical!(io, x[name])
    end
    return io
end

function write_canonical!(io::IO, x::Array)
    write(io, TAG_ARRAY)
    write_type!(io, typeof(x))
    write_count!(io, ndims(x))
    foreach(n -> write_count!(io, n), size(x))
    for i in eachindex(x)
        isassigned(x, i) || refuse("canonical serialisation", CANONICAL_SITE,
                                   "an $(typeof(x)) holds an unassigned element")
        write_canonical!(io, x[i])
    end
    return io
end

function write_canonical!(io::IO, x::Type)
    write(io, TAG_TYPE)
    write_type!(io, x)
    return io
end

function write_canonical!(io::IO, x)
    T = typeof(x)
    (x isa Function || x isa Module || ismutable(x) || !isstructtype(T)) && no_serialisation(T)
    write(io, TAG_STRUCT)
    write_type!(io, T)
    names = sort([String(n) for n in fieldnames(T)])
    write_count!(io, length(names))
    for n in names
        isdefined(x, Symbol(n)) || refuse("canonical serialisation", CANONICAL_SITE,
                                          "a $(T) holds no value in its field $(n)")
        write_symbol!(io, Symbol(n))
        write_canonical!(io, getfield(x, Symbol(n)))
    end
    return io
end

"""
    canonical_bytes(x)

The canonical serialisation of the value `x`, as a `Vector{UInt8}`. Every count and
integer is an eight-byte little-endian word. By kind of value:

- a `Float16`, `Float32` or `Float64`: `TAG_FLOAT`, its width in bytes as one byte, and
  its IEEE 754 bit pattern little-endian at that width;
- a `Bool`: `TAG_BOOL` and `0x01` or `0x00`;
- a signed integer of at most 64 bits: `TAG_SIGNED` and its value as an `Int64`; an
  unsigned one: `TAG_UNSIGNED` and its value as a `UInt64`;
- a `Symbol` or a `String`: `TAG_SYMBOL` or `TAG_STRING`, the count of its UTF-8
  bytes and the bytes;
- `nothing`: `TAG_NOTHING`;
- a `Tuple`: `TAG_TUPLE`, its length and each element in position order;
- a `NamedTuple`: `TAG_NAMED_TUPLE`, its length, and for each name in sorted order the
  name's count and UTF-8 bytes and then its value;
- an `Array`: `TAG_ARRAY`, its type, its number of dimensions, each size, and each
  element in column-major order;
- a type: `TAG_TYPE` and the type;
- an immutable struct: `TAG_STRUCT`, its type, its number of fields, and for each field
  name in sorted order the name's count and UTF-8 bytes and then its value.

A type is its module's full name as a count and each name, its own name, and its
parameters as a count and each, a type after `TAG_TYPE`. Refuses, quantity
`"canonical serialisation"`, any other value, among them a `BigFloat`, an integer wider
than 64 bits, a mutable struct other than an `Array` or a `String`, a function, a
module, an array element or struct field with no value, and a string that is not valid
UTF-8.
"""
function canonical_bytes(x)
    io = IOBuffer()
    write_canonical!(io, x)
    return take!(io)
end

# ---------------------------------------------------------------- the parameter subset

"""
    write_path!(io, path)

Writes the path `path`: its count of steps, and each step, a field name as a `Symbol`
and a position as a signed integer by `write_canonical!`, and `:` as `TAG_COLON`.
"""
function write_path!(io::IO, path::Tuple)
    write_count!(io, length(path))
    for step in path
        step isa Colon ? write(io, TAG_COLON) : write_canonical!(io, step)
    end
    return io
end

"""
    expand_path(x, path)

The colon-free paths `path` stands for from `x`: each `:` replaced by every position of
the tuple it steps over, positions in increasing order, the steps read by
`Systems.at_path`.
"""
function expand_path(x, path::Tuple)
    i = findfirst(step -> step isa Colon, path)
    i === nothing && return Tuple[path]
    prefix, rest = path[1:(i - 1)], path[(i + 1):end]
    n = length(Systems.at_path(x, prefix))
    return reduce(vcat, (expand_path(x, (prefix..., j, rest...)) for j in 1:n); init = Tuple[])
end

"""
    path_block(site, name, system, path)

The bytes of one declared path: the path by `write_path!`, the count of the colon-free
paths `expand_path` gives for it, and for each the path and the value it reaches from
`system` by `write_canonical!`. Refuses at `site`, naming the component `name` and the
path, a value `canonical_bytes` refuses.
"""
function path_block(site::AbstractString, name::Symbol, system::System, path::Tuple)
    io = IOBuffer()
    write_path!(io, path)
    reached = expand_path(system, path)
    write_count!(io, length(reached))
    for p in reached
        write_path!(io, p)
        try
            write_canonical!(io, Systems.at_path(system, p))
        catch err
            err isa Refusal || rethrow()
            refuse("system_fields", site, "$(name) declares $(path), which reaches $(p): $(err.reason)")
        end
    end
    return take!(io)
end

"""
    parameter_digest(declaration, system)

The SHA-256 digest, as an `NTuple{32,UInt8}`, of the values `system` holds at the paths
`declaration.system_fields` names: `PARAMETER_DOMAIN`, the count of paths, and each
path's `path_block` in sorted byte order, so the order the paths are declared in reaches
no digest. Refuses, naming the component and the path, a path that does not reach
through `system` by `Systems.reaches` and a reached value `canonical_bytes` refuses.
"""
function parameter_digest(declaration::Declaration, system::System)
    site = "Provenance.parameter_digest"
    blocks = Vector{UInt8}[]
    for path in declaration.system_fields
        Systems.reaches(system, path) || refuse(
            "system_fields", site,
            "$(declaration.name) declares $(path), which does not reach through the system")
        push!(blocks, path_block(site, declaration.name, system, path))
    end
    io = IOBuffer()
    write_symbol!(io, PARAMETER_DOMAIN)
    write_count!(io, length(blocks))
    foreach(b -> write(io, b), sort!(blocks))
    return Tuple(sha256(take!(io)))
end

# ---------------------------------------------------------------- the code version

"The lengths in hexadecimal digits of a git object id in git's sha1 and sha256 object formats."
const OBJECT_ID_LENGTHS = (40, 64)

"The digits of a git object id."
const HEX_DIGITS = "0123456789abcdef"

"""
    require_object_id(quantity, site, id)

`id` when it is a `String` of lowercase hexadecimal digits of one of
`OBJECT_ID_LENGTHS`; refuses at `site` naming `quantity` otherwise.
"""
function require_object_id(quantity::AbstractString, site::AbstractString, id)
    id isa String || refuse(quantity, site, "a $(typeof(id)) where a git object id, a String, is required")
    (length(id) in OBJECT_ID_LENGTHS && all(c -> c in HEX_DIGITS, id)) || refuse(
        quantity, site,
        "$(repr(id)) is not a git object id, $(join(OBJECT_ID_LENGTHS, " or ")) lowercase " *
        "hexadecimal digits")
    return id
end

"""
    CodeVersion(; commit, tree, manifest, julia, dirty)

The code a run ran: `commit`, the git commit checked out; `tree`, the git object id of
the `src` tree at that commit; `manifest`, the git object id of `Manifest.toml` at that
commit; `julia`, the `VersionNumber` of the Julia that ran it; and `dirty`, `true` when
`src` or `Manifest.toml` differs from that commit in the working tree. The three ids
are git object ids of one length. `ArtifactKey` hashes `tree`, `manifest`, `julia` and
`dirty`, and not `commit`. Built by `read_code_version`, or from a run's record.
"""
struct CodeVersion
    commit::String
    tree::String
    manifest::String
    julia::VersionNumber
    dirty::Bool

    CodeVersion(::Checked, c, t, m, j, d) = new(c, t, m, j, d)
end

function CodeVersion(; kwargs...)
    site = "Provenance.CodeVersion"
    k, _ = read_keywords(site, values(kwargs), (:commit, :tree, :manifest, :julia, :dirty), ())
    commit = require_object_id("commit", site, k.commit)
    tree = require_object_id("tree", site, k.tree)
    manifest = require_object_id("manifest", site, k.manifest)
    length(commit) == length(tree) == length(manifest) || refuse(
        "object id", site,
        "the commit, tree and manifest ids have $(length(commit)), $(length(tree)) and " *
        "$(length(manifest)) digits, and one repository names its objects at one length")
    julia = require_type("julia", site, k.julia, VersionNumber)
    dirty = require_type("dirty", site, k.dirty, Bool)
    return CodeVersion(Checked(), commit, tree, manifest, julia, dirty)
end

"""
    git_output(site, root, args)

The standard output of `git -C root` with `args`, stripped, run with every `GIT_`
environment variable removed so the repository read is the one at `root`. Refuses at
`site`, quantity `"code version"`, when git cannot be run or exits unsuccessfully,
with what it wrote to standard error.
"""
function git_output(site::AbstractString, root::AbstractString, args::Cmd)
    env = [k => v for (k, v) in ENV if !startswith(k, "GIT_")]
    cmd = setenv(`git -C $(root) $(args)`, env)
    out, err = IOBuffer(), IOBuffer()
    ok = try
        success(pipeline(cmd; stdout = out, stderr = err))
    catch e
        e isa Base.IOError || rethrow()
        refuse("code version", site, "git could not be run at $(root): $(sprint(showerror, e))")
    end
    ok || refuse("code version", site,
                 "git -C $(root) $(join(args.exec, " ")) failed: $(strip(String(take!(err))))")
    return String(strip(String(take!(out))))
end

"""
    read_code_version(root)

The `CodeVersion` of the git working tree at `root`, read from git: the commit `HEAD`
names, the ids of `src` and `Manifest.toml` at `HEAD` relative to `root`, the running
Julia's `VERSION`, and `dirty` when `git status` lists any change to `src` or
`Manifest.toml`, an untracked file under `src` among them. A change anywhere else does
not make it dirty. Refuses, quantity `"code version"`, a `root` that is not a
directory, is not in a git working tree, or whose `HEAD` holds no `src` tree or no
`Manifest.toml`.
"""
function read_code_version(root::AbstractString)
    site = "Provenance.read_code_version"
    isdir(root) || refuse("code version", site, "$(root) is not a directory")
    git_output(site, root, `rev-parse --is-inside-work-tree`) == "true" || refuse(
        "code version", site, "$(root) is not in a git working tree")
    status = git_output(site, root, `status --porcelain=v1 --untracked-files=all -- src Manifest.toml`)
    return CodeVersion(commit = git_output(site, root, `rev-parse --verify HEAD`),
                       tree = git_output(site, root, `rev-parse --verify HEAD:./src`),
                       manifest = git_output(site, root, `rev-parse --verify HEAD:./Manifest.toml`),
                       julia = VERSION, dirty = !isempty(status))
end

"""
    loaded_code_version()

`read_code_version` at the directory of the package this module was loaded from.
Refuses, quantity `"code version"`, when the package has no directory, and whatever
`read_code_version` refuses.
"""
function loaded_code_version()
    root = pkgdir(parentmodule(@__MODULE__))
    root === nothing && refuse("code version", "Provenance.loaded_code_version",
                               "the loaded package has no directory")
    return read_code_version(root)
end

# ---------------------------------------------------------------- the run id

"""
    RunID(; uuid)

A run's identity: `uuid`, a version 4 UUID with the variant bits `10`. Refuses a `uuid`
of any other version or variant. `mint_run_id` makes a new one.
"""
struct RunID
    uuid::UUID

    RunID(::Checked, u::UUID) = new(u)
end

function RunID(; kwargs...)
    site = "Provenance.RunID"
    k, _ = read_keywords(site, values(kwargs), (:uuid,), ())
    u = require_type("uuid", site, k.uuid, UUID)
    version = UUIDs.uuid_version(u)
    version == 4 || refuse("uuid", site, "$(u) is a version $(version) UUID, and a run id is version 4")
    (u.value >> 62) & 0x3 == 0x2 || refuse(
        "uuid", site, "$(u) does not carry the variant bits 10 of a version 4 UUID")
    return RunID(Checked(), u)
end

"A new `RunID`, from `UUIDs.uuid4`."
mint_run_id() = RunID(uuid = uuid4())

# ---------------------------------------------------------------- the key

"""
    ArtifactKey

The content key of one artifact: `digest`, the SHA-256 digest `ArtifactKey(; ...)`
computes; `code`, the `CodeVersion` it was computed under; and `dirty`, `true` when
`code` or any input key is dirty. Two keys are equal when their digests are. It names
no artifact by any name.
"""
struct ArtifactKey
    digest::NTuple{32,UInt8}
    code::CodeVersion
    dirty::Bool

    ArtifactKey(::Checked, digest, code, dirty) = new(digest, code, dirty)
end

Base.:(==)(a::ArtifactKey, b::ArtifactKey) = a.digest == b.digest
Base.hash(k::ArtifactKey, h::UInt) = hash(k.digest, h)

"""
    require_inputs(site, declaration, inputs)

`inputs` when it is a `NamedTuple` of `ArtifactKey` naming exactly the quantities
`declaration` reads; refuses at `site`, naming the quantity, a value that is not a key,
a read quantity with no key, and a key for a quantity the declaration does not read.
"""
function require_inputs(site::AbstractString, declaration::Declaration, inputs)
    inputs isa NamedTuple || refuse(
        "inputs", site, "a $(typeof(inputs)) where a NamedTuple of ArtifactKey is required")
    given = sort(collect(keys(inputs)))
    for q in given
        inputs[q] isa ArtifactKey || refuse(
            String(q), site, "the input key of $(q) is a $(typeof(inputs[q])), not an ArtifactKey")
    end
    read = sort([r.quantity for r in declaration.reads])
    for q in read
        haskey(inputs, q) || refuse(
            String(q), site, "$(declaration.name) reads $(q), and no input key is given for it")
    end
    for q in given
        q in read || refuse(
            String(q), site, "an input key is given for $(q), which $(declaration.name) does not read")
    end
    return inputs
end

"""
    ArtifactKey(; code, declaration, system, inputs, quantity, support, operator_version)

The key of the artifact `quantity` written by the component `declaration` declares: the
SHA-256 digest of `KEY_DOMAIN`, then

1. the code version, the tuple `(code.tree, code.manifest, string(code.julia),
   code.dirty)` by `canonical_bytes`;
2. the declared parameter subset, `parameter_digest(declaration, system)`;
3. the input keys, `inputs` a `NamedTuple` from each quantity `declaration` reads to
   the `ArtifactKey` it was read from, as a count and, in sorted name order, the name
   and the key's digest;
4. the support id, `support.digest`;
5. the operator, the tuple `(declaration.name, quantity, the name of the type of
   declaration.backend, bitwise(declaration.backend), UInt64(operator_version))` by
   `canonical_bytes`.

Every keyword is required. Refuses a keyword of the wrong type; `inputs` that
`require_inputs` refuses; a `quantity` `declaration` does not write; a `support` at
another level than `declaration.level`; a negative `operator_version`; and whatever
`parameter_digest` refuses. A dirty code version gives a key; `admit` refuses it.
"""
function ArtifactKey(; kwargs...)
    site = "Provenance.ArtifactKey"
    k, _ = read_keywords(site, values(kwargs),
                         (:code, :declaration, :system, :inputs, :quantity, :support,
                          :operator_version), ())
    code = require_type("code", site, k.code, CodeVersion)
    declaration = require_type("declaration", site, k.declaration, Declaration)
    system = require_type("system", site, k.system, System)
    inputs = require_inputs(site, declaration, k.inputs)
    quantity = require_type("quantity", site, k.quantity, Symbol)
    any(w -> w.quantity === quantity, declaration.writes) || refuse(
        "quantity", site, "$(declaration.name) declares no write of $(quantity)")
    support = require_type("support", site, k.support, Mesh.Support)
    support.level == declaration.level || refuse(
        "support", site,
        "a support at level $(support.level), and $(declaration.name) writes at level " *
        "$(declaration.level)")
    version = checked_word(require_type("operator_version", site, k.operator_version, Integer),
                           "operator_version", site)

    io = IOBuffer()
    write_symbol!(io, KEY_DOMAIN)
    write_canonical!(io, (code.tree, code.manifest, string(code.julia), code.dirty))
    write_digest!(io, parameter_digest(declaration, system))
    names = sort(collect(keys(inputs)))
    write_count!(io, length(names))
    for q in names
        write_symbol!(io, q)
        write_digest!(io, inputs[q].digest)
    end
    write_digest!(io, support.digest)
    write_canonical!(io, (declaration.name, quantity, nameof(typeof(declaration.backend)),
                          bitwise(declaration.backend), version))
    dirty = code.dirty || any(q -> inputs[q].dirty, names)
    return ArtifactKey(Checked(), Tuple(sha256(take!(io))), code, dirty)
end

# ---------------------------------------------------------------- the store's door

"""
    ScratchRun(; run, code)

A write outside the keyed store: the `RunID` `run` it belongs to and the `CodeVersion`
`code` that ran, dirty or not.
"""
struct ScratchRun
    run::RunID
    code::CodeVersion

    ScratchRun(::Checked, r, c) = new(r, c)
end

function ScratchRun(; kwargs...)
    site = "Provenance.ScratchRun"
    k, _ = read_keywords(site, values(kwargs), (:run, :code), ())
    return ScratchRun(Checked(), require_type("run", site, k.run, RunID),
                      require_type("code", site, k.code, CodeVersion))
end

"""
    admit(key::ArtifactKey)
    admit(scratch::ScratchRun)

What the store calls before it writes: `key` when it is not dirty, refusing it,
quantity `"code version"`, when it is; and `scratch` whatever its code version.
"""
function admit(key::ArtifactKey)
    key.dirty && refuse(
        "code version", "Provenance.admit",
        "the key rests on a code version with uncommitted changes (commit " *
        "$(key.code.commit), or an input key's); a keyed artifact is refused and a " *
        "ScratchRun is admitted")
    return key
end

admit(scratch::ScratchRun) = scratch
