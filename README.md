# NCBIDataSets.jl

Idiomatic Julia interface to the [NCBI `datasets` command-line tool (find/download
biological sequence, annotation and metadata)](https://www.ncbi.nlm.nih.gov/datasets/docs/v2/getting_started/).

**Hybrid design:** retrieval (`download_*`, `rehydrate`) shells out to the
binary; **data reports** (the JSON-Lines metadata inside a data package) are
read *natively in Julia* into a `Vector{NamedTuple}` that satisfies the
[Tables.jl](https://github.com/JuliaData/Tables.jl) interface — so you pipe them
into `DataFrame`, `CSV.write`, Arrow, etc. yourself, with no DataFrames
dependency here.

> NCBI's companion `dataformat` tool only flattens those same JSON-Lines reports
> to TSV/CSV/Excel — work this package does natively via Tables.jl — so it is
> deliberately **not** bundled (it has no public source and would drag in a large
> gRPC/protobuf/xlsx dependency stack). For tabular files, write a report through
> any Tables.jl sink, e.g. `CSV.write("genomes.tsv", report(pkg); delim='\t')`.

## Installation

The `datasets` CLI ships as the
[`NCBIDatasets_jll`](https://github.com/JuliaBinaryWrappers/NCBIDatasets_jll.jl)
binary artifact, so there is no manual build or download step — instantiating the
project fetches it:

```sh
cd NCBIDataSets
julia --project -e 'using Pkg; Pkg.instantiate()'
```

## Usage

The wrapper mirrors the whole `datasets` v2
[command surface](https://www.ncbi.nlm.nih.gov/datasets/docs/v2/). Each data type
has a `summary_*` (query metadata from the API, no download) and a `download_*`
(fetch a data package you then read with `report`). `summary_*` and
`report(download_*)` both return a `Vector{NamedTuple}` — a Tables.jl row table
with nested objects preserved and keys snake-cased from the binary's camelCase.

The examples below are executed as doctests against live NCBI (see
[Development](#development)), so the shown output is the real, current output.

```jldoctest readme
julia> using NCBIDataSets
```

### Genome — `summary_genome` / `download_genome`

Identifier (exactly one): `accession` or `taxon`.

```jldoctest readme
julia> rows = summary_genome(accession="GCF_000005845.2");   # E. coli K-12 MG1655

julia> rows[1].organism.organism_name
"Escherichia coli str. K-12 substr. MG1655"

julia> rows[1].assembly_info.assembly_level
"Complete Genome"
```

The rows are a Tables.jl row table — `coltable` turns them into columns (or pipe
into `DataFrame`, `CSV.write`, Arrow, …):

```jldoctest readme
julia> ct = coltable(rows);          # NamedTuple of column vectors

julia> ct.accession
1-element Vector{String}:
 "GCF_000005845.2"
```

`download_genome` returns a `DataPackage` handle; `report` reads its data report:

```jldoctest readme
julia> pkg = download_genome(accession="GCF_000005845.2");

julia> reportfiles(pkg)
1-element Vector{String}:
 "ncbi_dataset/data/assembly_data_report.jsonl"

julia> report(pkg)[1].organism.organism_name
"Escherichia coli str. K-12 substr. MG1655"
```

### Gene — `summary_gene` / `download_gene`

Identifier (exactly one): `gene_id`, `symbol`, `accession`, `locus_tag`, or
`taxon`. With `symbol`/`locus_tag`, `taxon` is the species filter (not the
identifier).

```jldoctest readme
julia> g = summary_gene(gene_id=672);          # human BRCA1

julia> (g[1].symbol, g[1].description, g[1].taxname)
("BRCA1", "BRCA1 DNA repair associated", "Homo sapiens")
```

```jldoctest readme
julia> pkg = download_gene(symbol="BRCA1", taxon="human");   # taxon filters the species

julia> report(pkg)[1].gene_id
"672"
```

### Taxonomy — `summary_taxonomy` / `download_taxonomy`

Identifier: `taxon` (a name or NCBI Taxonomy ID). The report nests everything
under a `taxonomy` field.

```jldoctest readme
julia> t = summary_taxonomy(taxon="human")[1].taxonomy;

julia> (t.tax_id, t.rank, t.current_scientific_name.name)
(9606, "SPECIES", "Homo sapiens")
```

```jldoctest readme
julia> pkg = download_taxonomy(taxon="human");

julia> report(pkg)[1].taxonomy.current_scientific_name.name
"Homo sapiens"
```

### Virus — `summary_virus_genome` / `download_virus_genome` / `download_virus_protein`

`summary` covers virus genomes; `download` covers virus genomes (by `accession`
or `taxon`) and virus proteins (by protein name).

```jldoctest readme
julia> v = summary_virus_genome(accession="NC_045512.2")[1];   # SARS-CoV-2

julia> (v.virus.organism_name, v.length, v.completeness)
("Severe acute respiratory syndrome coronavirus 2", 29903, "COMPLETE")
```

```jldoctest readme
julia> pkg = download_virus_genome(accession="NC_045512.2");

julia> report(pkg)[1].accession
"NC_045512.2"
```

```jldoctest readme
julia> pkg = download_virus_protein("rdrp", refseq=true);   # RdRp, RefSeq only

julia> report(pkg)[1].virus.organism_name
"Severe acute respiratory syndrome coronavirus 2"
```

### Large / dehydrated downloads — `rehydrate`

`dehydrated=true` fetches only a `fetch.txt` manifest; `rehydrate` then pulls the
actual data files (extracting the zipped package to a directory first). Use this
for large downloads like a whole genome assembly or the human genome.

```jldoctest readme
julia> pkg = download_genome(accession="GCF_000005845.2", dehydrated=true);

julia> rpkg = rehydrate(pkg);

julia> isdir(rpkg.path)
true
```

### Tabular export (what NCBI's `dataformat` would do) — done Julia-side

```julia
using CSV
CSV.write("genomes.tsv", report(pkg); delim='\t')
```

### Calling convention

- One function per data type: `download_genome`, `download_gene`,
  `download_taxonomy`, `download_virus_genome`, `download_virus_protein`, and the
  matching `summary_*` (`summary` has no virus-protein form, mirroring the CLI).
- Provide **exactly one identifier** keyword — `accession`, `taxon`, `symbol`,
  `gene_id`, `locus_tag` (which kinds are valid depends on the data type). For
  gene, `taxon` alongside `symbol`/`locus_tag` is the species filter, not the
  identifier.
- **Common flags are explicit, documented keywords** per function (see each
  docstring) — `reference`, `include`, `assembly_level`, `host`, `report`,
  `limit`, … `Bool` → presence flag, vectors → comma lists (`include=["genome",
  "gff3"]` → `--include genome,gff3`), `search` repeats.
- **Any other flag passes through** as a keyword (`snake_case` → `--kebab-case`),
  so the wrapper tracks new NCBI flags for free; run
  `datasets download genome --help` for the full catalog.

## Development

```sh
julia --project -e 'using Pkg; Pkg.test()'   # offline unit tests
NCBIDATASETS_NETWORK_TESTS=1 julia --project -e 'using Pkg; Pkg.test()'  # + live NCBI
```

The live test set also runs every `jldoctest` snippet in this README through
[Documenter](https://github.com/JuliaDocs/Documenter.jl)'s `doctest`, so the
shown output can't silently drift from what the code actually returns.

## API key

An NCBI API key is optional — it only raises the request rate limit (5 → 10
req/s); no data is gated. The package resolves it **on the Julia side** from the
`NCBI_API_KEY` environment variable and injects it into the binary's environment
(never as an argument, so it can't leak via `ps` or error messages).

```julia
api_key()                              # what will be used (from NCBI_API_KEY), or nothing
summary_genome(taxon="human")          # uses NCBI_API_KEY automatically
summary_genome(taxon="human"; api_key="…")    # override for this call
summary_genome(taxon="human"; api_key=false)  # suppress an inherited key
```
