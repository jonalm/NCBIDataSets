"""
    NCBIDataSets

Idiomatic Julia interface to the NCBI `datasets` command-line tool, shipped as
the `NCBIDatasets_jll` binary artifact.

Hybrid design: retrieval (`download_*`, `rehydrate`) shells out to the binary;
**data reports** are read natively in Julia into `Vector{NamedTuple}`
(Tables.jl-compatible) via JSON.jl — no DataFrames dependency. Tabular export
(the job of NCBI's separate `dataformat` tool) is therefore done Julia-side via
any Tables.jl sink (CSV.jl, XLSX.jl, DataFrames); `dataformat` is not bundled.
"""
module NCBIDataSets

using JSON
using Tables
using ZipArchives: ZipReader, zip_name, zip_nentries, zip_readentry
import NCBIDatasets_jll

export DataPackage,
    download_genome, download_gene, download_taxonomy,
    download_virus_genome, download_virus_protein,
    summary_genome, summary_gene, summary_taxonomy, summary_virus_genome,
    report, reportfiles, coltable,
    rehydrate, extract,
    api_key,
    DatasetsError

include("binaries.jl")
include("errors.jl")
include("flags.jl")
include("apikey.jl")
include("package.jl")
include("report.jl")
include("download.jl")
include("summary.jl")
include("rehydrate.jl")

end # module NCBIDataSets
