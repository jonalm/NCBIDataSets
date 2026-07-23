"""
    DatasetsError(cmd, code, stderr)

Thrown when a wrapped `datasets` invocation exits non-zero. Carries the `Cmd`,
the exit `code`, and the captured `stderr` for a readable message.
"""
struct DatasetsError <: Exception
    cmd::Cmd
    code::Int
    stderr::String
end

function Base.showerror(io::IO, e::DatasetsError)
    println(io, "DatasetsError: command exited with code ", e.code)
    println(io, "  command: ", e.cmd)
    isempty(strip(e.stderr)) || print(io, "  stderr: ", strip(e.stderr))
end

# Run a wrapped binary; return captured stdout.
#
# `progress=true` (download/rehydrate) lets the binary write its progress bar
# straight to our stderr so long downloads show progress instead of looking
# frozen — but only when stderr is an interactive terminal. When stderr is
# redirected or captured (pipes, CI logs, Documenter doctest capture) an ANSI
# progress bar is just line-noise, so we fall back to capturing stderr like the
# `progress=false` (summary) path does. In the capture path stderr is surfaced in
# the DatasetsError on failure and otherwise discarded.
function _run(bin::Cmd, args::AbstractVector{<:AbstractString};
              progress::Bool = false, env = Pair{String,String}[])
    cmd = `$bin $args`
    # Inject env vars (e.g. NCBI_API_KEY) explicitly; via the environment, not
    # argv, so secrets never appear in `ps` or in a DatasetsError's command echo.
    isempty(env) || (cmd = addenv(cmd, env...))
    out = IOBuffer()
    if progress && stderr isa Base.TTY
        proc = run(pipeline(ignorestatus(cmd); stdout = out, stderr = stderr))
        proc.exitcode == 0 ||
            throw(DatasetsError(cmd, proc.exitcode, "(stderr streamed to terminal above)"))
    else
        err = IOBuffer()
        proc = run(pipeline(ignorestatus(cmd); stdout = out, stderr = err))
        proc.exitcode == 0 || throw(DatasetsError(cmd, proc.exitcode, String(take!(err))))
    end
    return String(take!(out))
end
