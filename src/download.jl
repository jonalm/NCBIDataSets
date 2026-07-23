# `download_*` -> DataPackage.
#
# CLI shape:  datasets download <type...> <id-kind> <id...> [flags]
# The id-kind (accession/taxon/symbol/...) is a positional subcommand, not a
# flag, so we pull exactly one identifier keyword out and map the rest to flags.
#
# Each public function takes the common, verified flags as explicit keywords
# (discoverable + documented) and forwards any other keyword through `kwargs...`
# to the binary (the long tail of NCBI flags), so the wrapper stays
# forward-compatible at zero maintenance.

# Identifier kinds accepted per data type (keyword -> CLI subcommand via kebab).
const _GENOME_IDS  = (:accession, :taxon)
const _GENE_IDS    = (:gene_id, :symbol, :accession, :taxon, :locus_tag)
const _TAX_IDS     = (:taxon,)
const _VGENOME_IDS = (:accession, :taxon)

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

_tempzip() = tempname() * ".zip"

function _download(subcmd::Vector{String}, idkinds;
                   filename::Union{Nothing,AbstractString} = nothing,
                   ambiguous = (), api_key = nothing, kw...)
    idsub, idval, rest = _split_id(idkinds, kw; ambiguous)
    out = filename === nothing ? _tempzip() : String(filename)
    args = String["download"]
    append!(args, subcmd)
    push!(args, idsub)
    append!(args, _idvalues(idval))
    push!(args, "--filename", out)
    append!(args, buildflags(; rest...))
    _run(_datasets_cmd(), args; progress = true, env = _apikey_env(api_key))
    return DataPackage(out)
end

"""
    download_genome(; <identifier>, kwargs...) -> DataPackage

Download a genome data package. Identifier (exactly one): `accession` or `taxon`.

Common flags as keywords: `include` (e.g. `["genome","protein","gff3"]`),
`reference`, `assembly_level`, `assembly_source`, `annotated`, `dehydrated`,
`chromosomes`, `search`, `released_after`, `released_before`, `mag`, `preview`,
`filename`. Any other `datasets download genome` flag passes through as a keyword
(`snake_case` → `--kebab-case`).

```julia
pkg = download_genome(accession="GCF_000005845.2")          # E. coli K-12
pkg = download_genome(taxon="bos taurus", dehydrated=true)
```
"""
function download_genome(; accession = nothing, taxon = nothing,
        include = nothing, reference::Bool = false,
        assembly_level = nothing, assembly_source = nothing, annotated::Bool = false,
        dehydrated::Bool = false, chromosomes = nothing, search = nothing,
        released_after = nothing, released_before = nothing, mag = nothing,
        preview::Bool = false, filename = nothing, kwargs...)
    return _download(["genome"], _GENOME_IDS; filename,
        accession, taxon, include, reference, assembly_level, assembly_source,
        annotated, dehydrated, chromosomes, search, released_after, released_before,
        mag, preview, kwargs...)
end

"""
    download_gene(; <identifier>, kwargs...) -> DataPackage

Identifier (exactly one): `gene_id`, `symbol`, `accession`, `locus_tag`, or
`taxon`. Note: with `symbol`/`locus_tag`, `taxon` becomes the species filter
(`--taxon`, default human); given alone it is the identifier (`gene taxon …`).

Common flags: `ortholog`, `include` (e.g. `["rna","protein"]`), `preview`,
`filename`.
"""
function download_gene(; gene_id = nothing, symbol = nothing, accession = nothing,
        taxon = nothing, locus_tag = nothing,
        ortholog = nothing, include = nothing, preview::Bool = false,
        filename = nothing, kwargs...)
    return _download(["gene"], _GENE_IDS; filename, ambiguous = (:taxon,),
        gene_id, symbol, accession, taxon, locus_tag,
        ortholog, include, preview, kwargs...)
end

"""
    download_taxonomy(; taxon, kwargs...) -> DataPackage

Common flags: `children`, `parents`, `rank`, `include`, `filename`.
"""
function download_taxonomy(; taxon = nothing,
        children::Bool = false, parents::Bool = false, rank = nothing,
        include = nothing, filename = nothing, kwargs...)
    return _download(["taxonomy"], _TAX_IDS; filename,
        taxon, children, parents, rank, include, kwargs...)
end

"""
    download_virus_genome(; <identifier>, kwargs...) -> DataPackage

Identifier (exactly one): `accession` or `taxon`. Common flags: `host`,
`lineage`, `geo_location`, `complete_only`, `refseq`, `annotated`, `include`,
`released_after`, `updated_after`, `filename`.
"""
function download_virus_genome(; accession = nothing, taxon = nothing,
        host = nothing, lineage = nothing, geo_location = nothing,
        complete_only::Bool = false, refseq::Bool = false, annotated::Bool = false,
        include = nothing, released_after = nothing, updated_after = nothing,
        filename = nothing, kwargs...)
    return _download(["virus", "genome"], _VGENOME_IDS; filename,
        accession, taxon, host, lineage, geo_location, complete_only, refseq,
        annotated, include, released_after, updated_after, kwargs...)
end

"""
    download_virus_protein(name; kwargs...) -> DataPackage

Download a virus protein data package by protein name (e.g. `"spike"`). Common
flags: `host`, `lineage`, `geo_location`, `complete_only`, `refseq`, `annotated`,
`include`, `released_after`, `updated_after`, `filename`.
"""
function download_virus_protein(name::AbstractString;
        host = nothing, lineage = nothing, geo_location = nothing,
        complete_only::Bool = false, refseq::Bool = false, annotated::Bool = false,
        include = nothing, released_after = nothing, updated_after = nothing,
        filename::Union{Nothing,AbstractString} = nothing, api_key = nothing, kwargs...)
    out = filename === nothing ? _tempzip() : String(filename)
    args = String["download", "virus", "protein", String(name), "--filename", out]
    append!(args, buildflags(; host, lineage, geo_location, complete_only, refseq,
        annotated, include, released_after, updated_after, kwargs...))
    _run(_datasets_cmd(), args; progress = true, env = _apikey_env(api_key))
    return DataPackage(out)
end
