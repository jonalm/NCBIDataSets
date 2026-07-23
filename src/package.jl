"""
    DataPackage(path)

Handle to an NCBI **data package** — either the downloaded `.zip` or an
extracted directory. Returned by the `download_*` functions; pass it to
[`report`](@ref), [`rehydrate`](@ref) or [`extract`](@ref).
Wrap an already-downloaded package with `DataPackage("path/to/pkg.zip")`.
"""
struct DataPackage
    path::String
    DataPackage(path::AbstractString) = new(String(path))
end

Base.show(io::IO, p::DataPackage) = print(io, "DataPackage(", repr(p.path), ")")

_iszip(p::DataPackage) = isfile(p.path) && endswith(p.path, ".zip")
_isdir(p::DataPackage) = isdir(p.path)

function _zipreader(p::DataPackage)
    _iszip(p) || error("NCBIDataSets: $(p.path) is not a .zip data package")
    return ZipReader(read(p.path))
end

_default_extract_dir(p::DataPackage) = _iszip(p) ? first(splitext(p.path)) : p.path

"""
    extract(pkg::DataPackage, dest=<zip name w/o .zip>) -> DataPackage

Extract a zipped data package to `dest` and return a directory-backed
`DataPackage`. A package that is already a directory is returned unchanged.
"""
function extract(p::DataPackage, dest::AbstractString = _default_extract_dir(p))
    _isdir(p) && return p
    r = _zipreader(p)
    for i in 1:zip_nentries(r)
        name = zip_name(r, i)
        endswith(name, "/") && continue
        out = joinpath(dest, name)
        mkpath(dirname(out))
        write(out, zip_readentry(r, i))
    end
    return DataPackage(dest)
end

# Ensure an extracted directory (rehydrate operates on an unzipped package).
_ensure_dir(p::DataPackage) = _isdir(p) ? p : extract(p)
