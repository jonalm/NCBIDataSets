# Binary accessors.
#
# The `datasets` CLI is shipped as the `NCBIDatasets_jll` binary artifact. The JLL
# packages only `datasets`; `dataformat` is intentionally not bundled — tabular
# export is done Julia-side via Tables.jl (see README).

# `Cmd` accessor over the JLL-provided binary.
_datasets_cmd() = NCBIDatasets_jll.datasets()
