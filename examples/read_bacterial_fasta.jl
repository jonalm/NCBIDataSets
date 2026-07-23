# Download a bacterial genome FASTA from NCBI, read its metadata, and read the
# sequences with FASTX.jl.
#
# This uses the examples/ environment (examples/Project.toml), which dev-depends
# on NCBIDataSets and adds FASTX — FASTX is not a dependency of the package itself.
# Run from the NCBIDataSets project root:
#   julia --project=examples examples/read_bacterial_fasta.jl

##
using NCBIDataSets
using FASTX

const ACCESSION = "GCF_000005845.2"   # Escherichia coli K-12 MG1655

# 1. Download only the genomic FASTA (no protein/gff3/etc). Returns a .zip-backed DataPackage.
pkg = download_genome(accession = ACCESSION, include = ["genome"])

# 2. Unzip into a directory-backed DataPackage.
#    Qualify `extract` — FASTX also exports a name `extract`, so the bare call is ambiguous.
dir = NCBIDataSets.extract(pkg)

##
# 2b. Extract the metadata for this accession from the package's data report.
#     report(pkg) reads the *_data_report.jsonl inside the .zip natively (no extra
#     fetch, works offline) and returns a Vector{NamedTuple} — one row per accession.
#     Nested objects stay nested NamedTuples; keys are snake_cased from NCBI camelCase.
#
#     No-download alternative — query the API directly (needs no `pkg`):
#         md = only(summary_genome(accession = ACCESSION))
rows = report(pkg)
md = only(rows)                              # single accession -> one row
println("Accession:     ", md.accession)
println("Organism:      ", md.organism.organism_name, " (tax_id ", md.organism.tax_id, ")")
println("Report fields: ", keys(md))         # discover everything else available

##
# 3. Locate the genomic FASTA inside ncbi_dataset/data/<accession>/*_genomic.fna
function find_fasta(root)
    for (base, _, files) in walkdir(root)
        for f in files
            @info f
            endswith(f, "_genomic.fna") && return joinpath(base, f)
        end
    end
    error("no *_genomic.fna found under $root")
end

fasta = find_fasta(dir.path)
println("FASTA: ", fasta)

# 4. Read it with FASTX.jl — print each record's id and length.
open(FASTAReader, fasta) do reader
    for record in reader
        println(identifier(record), "\t", seqsize(record), " bp")
    end
end

