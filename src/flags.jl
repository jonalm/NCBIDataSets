# Keyword -> CLI flag mapping.
#
#   reference = true              -> ["--reference"]
#   reference = false / nothing   -> []                       (omitted)
#   assembly_level = "chromosome" -> ["--assembly-level", "chromosome"]
#   include = ["genome", "gff3"]  -> ["--include", "genome,gff3"]   (comma list)
#   search  = ["a", "b"]          -> ["--search", "a", "--search", "b"]  (repeated)
#
# snake_case keyword -> --kebab-case flag. Used both for the curated explicit
# kwargs of each download_*/summary_* function and for the `kwargs...`
# passthrough (the long tail of NCBI flags we don't surface explicitly).

# Flags that NCBI takes as repeated occurrences rather than a comma list. Their
# values may contain commas/spaces (e.g. --search "Broad Institute"), so joining
# would be wrong.
const _REPEATABLE = (:search,)

_flagname(k::Symbol) = "--" * replace(String(k), "_" => "-")

_flagvalue(v) = string(v)
_flagvalue(v::AbstractVector) = join(string.(v), ",")
_flagvalue(v::Tuple) = join(string.(v), ",")

function buildflags(; kwargs...)
    args = String[]
    for (k, v) in kwargs
        v === nothing && continue
        flag = _flagname(k)
        if v isa Bool
            v && push!(args, flag)                       # presence flag
        elseif k in _REPEATABLE && (v isa AbstractVector || v isa Tuple)
            for x in v
                push!(args, flag, string(x))             # repeated flag
            end
        else
            push!(args, flag, _flagvalue(v))
        end
    end
    return args
end
