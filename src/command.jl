# A `datasets` invocation as a first-class value.
#
# Every `download_*`/`summary_*`/`rehydrate` call is, underneath, the same shape:
#     datasets <verb> <subcmd...> <identifier> <fixed flags> <user flags>
# `_DatasetsCommand` captures that shape, `_argv` lowers it to the process
# argument vector (pure — no binary, no network, so the whole assembly is
# directly testable), and `_invoke` runs it through the one shared incantation
# (binary + api-key env + `_run`). The four call sites differ only in verb,
# subcommand, identifier shape, and fixed flags.

# Identifier kinds accepted per data type (keyword -> CLI subcommand via kebab).
const _GENOME_IDS  = (:accession, :taxon)
const _GENE_IDS    = (:gene_id, :symbol, :accession, :taxon, :locus_tag)
const _TAX_IDS     = (:taxon,)
const _VGENOME_IDS = (:accession, :taxon)

# The identifier is one of three shapes:
#   _IdKind     — an id-kind subcommand + values:  `accession GCF_1`  (genome/gene/…)
#   _Positional — a bare positional value:         `protein spike`    (virus protein)
#   nothing     — no identifier:                   (rehydrate, uses --directory)
struct _IdKind
    sub::String
    values::Vector{String}
end
struct _Positional
    values::Vector{String}
end

struct _DatasetsCommand
    verb::String
    subcmd::Vector{String}
    id::Union{_IdKind,_Positional,Nothing}
    flags::Vector{String}
end

# Pick the single identifier keyword; everything else (incl. `nothing` defaults)
# becomes flags. `ambiguous` lists keys that are identifier kinds *unless* a
# non-ambiguous identifier is also given, in which case they are demoted to
# filter flags. This is the gene case: `taxon` alone -> `gene taxon human`, but
# with `symbol` -> `gene symbol BRCA1 --taxon human`.
function _split_id(idkinds, kw; ambiguous = ())
    present = [k for k in keys(kw) if k in idkinds && kw[k] !== nothing]
    nonamb = filter(k -> !(k in ambiguous), present)
    candidates = isempty(nonamb) ? present : nonamb
    length(candidates) == 1 || throw(ArgumentError(
        "provide exactly one identifier of $(idkinds); got " *
        (isempty(candidates) ? "none" : string(candidates))))
    k = only(candidates)
    idsub = replace(String(k), "_" => "-")               # gene_id -> "gene-id"
    rest = [kk => kw[kk] for kk in keys(kw) if kk != k && kw[kk] !== nothing]
    return idsub, kw[k], rest
end

_idvalues(v) = String[string(v)]
_idvalues(v::AbstractVector) = String[string(x) for x in v]   # multiple accessions

# Identifier-kind verbs: the constructor resolves the identifier (via `_split_id`,
# which also demotes ambiguous kinds to filter flags) and lowers the remaining
# keywords to flags. `fixed` are the verb's literal flags (e.g. `--as-json-lines`),
# placed before the user flags so the argv matches the hand-built ones it replaces.
function _DatasetsCommand(verb, subcmd, idkinds::Tuple;
                          fixed = String[], ambiguous = (), kw...)
    idsub, idval, rest = _split_id(idkinds, kw; ambiguous)
    flags = String[fixed; buildflags(; rest...)]
    return _DatasetsCommand(String(verb), collect(String, subcmd),
                            _IdKind(idsub, _idvalues(idval)), flags)
end

# Positional / no-identifier verbs (virus protein, rehydrate): no id-kind split,
# every keyword is a flag. `ambiguous` is meaningless here (there is no identifier
# to resolve) but is accepted and ignored for symmetry with the id-kind
# constructor above — that way a stray `ambiguous=` can never slip into `kw...`
# and lower to a bogus `--ambiguous` flag.
function _DatasetsCommand(verb, subcmd, id::Union{_Positional,Nothing} = nothing;
                          fixed = String[], ambiguous = (), kw...)
    flags = String[fixed; buildflags(; kw...)]
    return _DatasetsCommand(String(verb), collect(String, subcmd), id, flags)
end

# Lower an identifier to its argv fragment.
_idargs(::Nothing)      = String[]
_idargs(i::_IdKind)     = String[i.sub; i.values]
_idargs(i::_Positional) = i.values

"""
    _argv(cmd::_DatasetsCommand) -> Vector{String}

Lower a command to the process argument vector. Pure — no binary, no network —
so the whole assembly is testable directly.
"""
_argv(c::_DatasetsCommand) = String[c.verb; c.subcmd; _idargs(c.id); c.flags]

# Run a command through the single shared `datasets` incantation: the JLL binary,
# the api-key env injection, and `_run`. `run` is an injected seam defaulting to
# the real `_run` — the substitution point for a fake binary (Candidate 2); no
# adapter uses it yet. Returns captured stdout; result-wrapping (DataPackage /
# `_parse_jsonl` / directory) stays with each verb.
function _invoke(c::_DatasetsCommand; progress::Bool = false, api_key = nothing, run = _run)
    return run(_datasets_cmd(), _argv(c); progress, env = _apikey_env(api_key))
end
