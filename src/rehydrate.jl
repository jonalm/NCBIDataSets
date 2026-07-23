"""
    rehydrate(pkg::DataPackage; kwargs...) -> DataPackage

Rehydrate a dehydrated data package — download the actual data files listed in
its `fetch.txt`. The CLI operates on an unzipped directory, so a zipped package
is extracted first; the returned `DataPackage` is directory-backed. Extra
keywords become flags (e.g. `max_workers=10` → `--max-workers 10`).

```julia
pkg = download_genome(accession="GCF_000001405.40", dehydrated=true)
rehydrate(pkg)
```
"""
function rehydrate(p::DataPackage; api_key = nothing, kw...)
    dir = _ensure_dir(p)
    cmd = _DatasetsCommand("rehydrate", String[], nothing;
                           fixed = String["--directory", dir.path], kw...)
    _invoke(cmd; progress = true, api_key)
    return dir
end
