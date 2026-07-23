# `summary_*` query the NCBI API for **data report** metadata (no package
# download) and return a Vector{NamedTuple}, identical in shape to report(pkg).
# `--as-json-lines` is forced so each output line is one record for uniform
# parsing. Same curated-explicit-kwargs + passthrough pattern as download_*.

function _summary(subcmd::Vector{String}, idkinds::Tuple; ambiguous = (), api_key = nothing, kw...)
    cmd = _DatasetsCommand("summary", subcmd, idkinds;
                           fixed = String["--as-json-lines"], ambiguous, kw...)
    return _parse_jsonl(_invoke(cmd; api_key))
end

"""
    summary_genome(; <identifier>, kwargs...) -> Vector{NamedTuple}

Genome metadata report straight from the API (no download). Identifier (exactly
one): `accession` or `taxon`. Common flags: `report` (`"genome"`/`"sequence"`/
`"ids_only"`), `limit`, `reference`, `assembly_level`, `assembly_source`,
`annotated`, `search`, `released_after`, `released_before`, `mag`.
"""
function summary_genome(; accession = nothing, taxon = nothing,
        report = nothing, limit = nothing, reference::Bool = false,
        assembly_level = nothing, assembly_source = nothing, annotated::Bool = false,
        search = nothing, released_after = nothing, released_before = nothing,
        mag = nothing, kwargs...)
    return _summary(["genome"], _GENOME_IDS;
        accession, taxon, report, limit, reference, assembly_level, assembly_source,
        annotated, search, released_after, released_before, mag, kwargs...)
end

"""
    summary_gene(; <identifier>, kwargs...) -> Vector{NamedTuple}

Identifier (exactly one): `gene_id`, `symbol`, `accession`, `locus_tag`, or
`taxon` (with `symbol`/`locus_tag`, `taxon` is the species filter). Common
flags: `ortholog`, `report`, `limit`.
"""
function summary_gene(; gene_id = nothing, symbol = nothing, accession = nothing,
        taxon = nothing, locus_tag = nothing,
        ortholog = nothing, report = nothing, limit = nothing, kwargs...)
    return _summary(["gene"], _GENE_IDS; ambiguous = (:taxon,),
        gene_id, symbol, accession, taxon, locus_tag,
        ortholog, report, limit, kwargs...)
end

"""
    summary_taxonomy(; taxon, kwargs...) -> Vector{NamedTuple}

Common flags: `children`, `parents`, `rank`, `report`, `limit`.
"""
function summary_taxonomy(; taxon = nothing,
        children::Bool = false, parents::Bool = false, rank = nothing,
        report = nothing, limit = nothing, kwargs...)
    return _summary(["taxonomy"], _TAX_IDS;
        taxon, children, parents, rank, report, limit, kwargs...)
end

"""
    summary_virus_genome(; <identifier>, kwargs...) -> Vector{NamedTuple}

Identifier (exactly one): `accession` or `taxon`. Common flags: `host`,
`lineage`, `geo_location`, `complete_only`, `refseq`, `annotated`, `report`,
`limit`, `released_after`, `updated_after`.
"""
function summary_virus_genome(; accession = nothing, taxon = nothing,
        host = nothing, lineage = nothing, geo_location = nothing,
        complete_only::Bool = false, refseq::Bool = false, annotated::Bool = false,
        report = nothing, limit = nothing, released_after = nothing,
        updated_after = nothing, kwargs...)
    return _summary(["virus", "genome"], _VGENOME_IDS;
        accession, taxon, host, lineage, geo_location, complete_only, refseq,
        annotated, report, limit, released_after, updated_after, kwargs...)
end
