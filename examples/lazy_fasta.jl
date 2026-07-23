# A lazy, cached accession -> local FASTA path resolver, built on LazyFiles'
# AbstractLazyBlob extension interface (see the LazyFiles README "Extending").
#
#   f = LazyFasta("GCF_000005845.2")
#   path = f()      # downloads via NCBIDataSets on a cache miss; returns the
#                   # cached *_genomic.fna path on a hit (no network)
#
# A LazyFasta *is* a LazyFiles blob, so caching, atomic writes, the cache root,
# `clear_from_cache`, and the `()` call syntax all come from LazyFiles. It needs
# no fetch config (downloading needs no credentials), so it only declares *where*
# it caches (`cache_subpath`) and *how* it fetches (`fetch!`).
#
# Run the demo:
#   LAZYFILES_CACHE_DIR=~/.cache/lazyfiles julia --project=examples examples/lazy_fasta.jl

using NCBIDataSets
import LazyFiles
using LazyFiles: AbstractLazyBlob, NoConfig, cache_dir!

"""
    LazyFasta(accession)
    f()  -> local path to the genome's *_genomic.fna, downloading on a cache miss

A handle to a genome assembly's FASTA, cached under
`<cache>/ncbi_fasta/<accession>.fna`. Calling it downloads via
`download_genome(include=["genome"])` on first use and serves from cache after.
Resolves to `nothing` only if the package has no genomic FASTA; a real failure
(bad accession, network) raises.
"""
struct LazyFasta <: AbstractLazyBlob
    accession::String
end

# where it caches
LazyFiles.cache_subpath(f::LazyFasta) = ("ncbi_fasta", f.accession * ".fna")

function _find_genomic_fna(root)
    for (base, _, files) in walkdir(root)
        for name in files
            endswith(name, "_genomic.fna") && return joinpath(base, name)
        end
    end
    return nothing
end

# how it fetches: download + extract, then copy the *_genomic.fna into `dest`.
# Leaving `dest` untouched (no FASTA found) makes the handle resolve to `nothing`.
function LazyFiles.fetch!(f::LazyFasta, dest::AbstractString; config::NoConfig = NoConfig(), verbose::Bool = false)
    verbose && @info "cache miss; downloading genome" accession = f.accession
    dir = NCBIDataSets.extract(download_genome(accession = f.accession, include = ["genome"]))
    src = _find_genomic_fna(dir.path)
    src === nothing || cp(src, dest; force = true)
    return nothing
end

"""
    fasta_path(accession; cache_dir, verbose=false) -> String | Nothing

Convenience wrapper: `LazyFasta(accession)()`.
"""
fasta_path(accession::AbstractString; kwargs...) = LazyFasta(accession)(; kwargs...)

# ---------------------------------------------------------------------------
# Demo: resolve twice — first call downloads, second is a pure cache hit.
# ---------------------------------------------------------------------------
if abspath(PROGRAM_FILE) == @__FILE__
    cache_dir!(get(ENV, "LAZYFILES_CACHE_DIR", joinpath(homedir(), ".cache", "lazyfiles")))

    acc = "GCF_000005845.2"   # E. coli K-12 MG1655

    p1 = fasta_path(acc; verbose = true)
    t1 = mtime(p1)
    println("1st call: ", p1)

    p2 = fasta_path(acc; verbose = true)   # no "cache miss" log expected
    println("2nd call: ", p2)

    @assert p1 == p2
    @assert mtime(p2) == t1   # unchanged mtime => served from cache, not re-downloaded
    println("cache hit confirmed (mtime unchanged): ", basename(p2))
end
