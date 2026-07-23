# NCBI API key handling, resolved on the Julia side (rather than relying on the
# binary implicitly reading the environment). The resolved key is injected into
# the child process's *environment* (see `_run`'s `env` argument) — never as an
# `--api-key` argument — so it can't leak via `ps` or a DatasetsError's command
# echo. An API key is optional; it only raises NCBI's rate limit (5 -> 10 req/s).

"""
    api_key() -> Union{String,Nothing}

The NCBI API key the package will use by default, read from the `NCBI_API_KEY`
environment variable (`nothing` if unset). Override per call with the `api_key=`
keyword on any `datasets`-backed function (`api_key="…"` to set, `api_key=false`
to suppress an inherited key).
"""
api_key() = get(ENV, "NCBI_API_KEY", nothing)

# Env pairs to inject for a call, given the per-call `api_key` keyword:
#   nothing -> use NCBI_API_KEY from the environment (if any)
#   false   -> suppress (override the child's key to empty)
#   String  -> use that key
function _apikey_env(explicit)
    explicit === false && return ["NCBI_API_KEY" => ""]
    key = explicit === nothing ? api_key() : String(explicit)
    (key === nothing || isempty(key)) ? Pair{String,String}[] : ["NCBI_API_KEY" => key]
end
