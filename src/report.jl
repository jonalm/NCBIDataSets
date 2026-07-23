# JSON-Lines data report -> Vector{NamedTuple}.

# camelCase -> snake_case. The `datasets` binary emits camelCase JSON keys
# (organismName, taxId) — despite the OpenAPI schema using snake_case — so we
# convert for idiomatic Julia field access. Already-lowercase
# keys pass through unchanged.
function _snakecase(s::AbstractString)
    s1 = replace(s, r"([a-z0-9])([A-Z])" => s"\1_\2")        # taxId -> tax_Id
    s2 = replace(s1, r"([A-Z]+)([A-Z][a-z])" => s"\1_\2")    # HTTPServer -> HTTP_Server
    return lowercase(s2)
end

# Recursively convert parsed JSON: objects -> NamedTuple, arrays -> Vector,
# keys -> snake_case Symbol.
_to_nt(x) = x
_to_nt(x::AbstractVector) = [_to_nt(e) for e in x]
function _to_nt(d::AbstractDict)
    isempty(d) && return NamedTuple()
    ks = Tuple(Symbol(_snakecase(String(k))) for k in keys(d))
    vs = Tuple(_to_nt(v) for v in values(d))
    return NamedTuple{ks}(vs)
end

# Top-level unification: union of keys across records, absent -> `missing`,
# so the result is a uniform, Tables.jl-friendly row table. Nested objects are
# left faithful (not recursively unified).
function _unify(rows::AbstractVector)
    isempty(rows) && return NamedTuple[]
    allkeys = Symbol[]
    seen = Set{Symbol}()
    for r in rows, k in keys(r)
        k in seen || (push!(seen, k); push!(allkeys, k))
    end
    kt = Tuple(allkeys)
    return [NamedTuple{kt}(Tuple(get(r, k, missing) for k in kt)) for r in rows]
end

function _parse_jsonl(str::AbstractString)
    rows = NamedTuple[]
    for line in eachline(IOBuffer(str))
        isempty(strip(line)) && continue
        push!(rows, _to_nt(JSON.parse(line)))
    end
    return _unify(rows)
end

_isjsonl(name) = endswith(name, ".jsonl")

# Prefer the primary "*_data_report.jsonl"; else the first .jsonl entry.
function _primary_report(jsonls)
    isempty(jsonls) && return nothing
    i = findfirst(n -> endswith(n, "_data_report.jsonl"), jsonls)
    return i === nothing ? first(jsonls) : jsonls[i]
end

"""
    reportfiles(pkg::DataPackage) -> Vector{String}

List the JSON-Lines **data report** entries inside a data package.
"""
function reportfiles(p::DataPackage)
    r = _zipreader(p)
    return filter(_isjsonl, [zip_name(r, i) for i in 1:zip_nentries(r)])
end

"""
    report(pkg::DataPackage; file=nothing) -> Vector{NamedTuple}

Read a **data report** from a downloaded data package and return it as a
`Vector{NamedTuple}` — a Tables.jl-compatible row table. Nested objects are
preserved as nested `NamedTuple`s; top-level fields absent from a record are
`missing`.

Reads the primary `*_data_report.jsonl` by default; pass `file=` to pick another
(see [`reportfiles`](@ref)). Get columns with [`coltable`](@ref), or pipe into
any Tables.jl sink (`DataFrame`, `CSV.write`, Arrow, …).
"""
function report(p::DataPackage; file::Union{Nothing,AbstractString} = nothing)
    r = _zipreader(p)
    names = [zip_name(r, i) for i in 1:zip_nentries(r)]
    target = file === nothing ? _primary_report(filter(_isjsonl, names)) :
             (file in names ? file : nothing)
    target === nothing && error("NCBIDataSets: no report file " *
        (file === nothing ? "(*_data_report.jsonl)" : "'$file'") * " found in $(p.path)")
    return _parse_jsonl(zip_readentry(r, target, String))
end

"""
    coltable(rows) -> NamedTuple of vectors

Convert report rows (a Tables.jl row table) into a column table.
"""
coltable(rows) = Tables.columntable(rows)
