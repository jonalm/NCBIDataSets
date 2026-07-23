using NCBIDataSets
using Test

const N = NCBIDataSets

# Live NCBI calls (network + the datasets binary) are opt-in. Documenter is only
# needed for the README doctests, which are themselves network tests, so load it
# here at top level (`using` is illegal inside the `@testset` below).
const RUN_NETWORK = get(ENV, "NCBIDATASETS_NETWORK_TESTS", "") == "1"
if RUN_NETWORK
    using Documenter
end

@testset "NCBIDataSets" begin

    @testset "flag mapping" begin
        @test N.buildflags(reference = true) == ["--reference"]
        @test N.buildflags(reference = false) == String[]
        @test N.buildflags(foo = nothing) == String[]
        @test N.buildflags(assembly_level = "chromosome") == ["--assembly-level", "chromosome"]
        @test N.buildflags(include = ["genome", "gff3"]) == ["--include", "genome,gff3"]
        @test N.buildflags(geo_location = "USA") == ["--geo-location", "USA"]
        # --search repeats instead of comma-joining (values may contain commas/spaces)
        @test N.buildflags(search = ["Broad Institute", "C57BL/6J"]) ==
              ["--search", "Broad Institute", "--search", "C57BL/6J"]
        @test N.buildflags(search = "one") == ["--search", "one"]
    end

    @testset "identifier split" begin
        idsub, idval, rest = N._split_id(N._GENE_IDS, (gene_id = "672", limit = 10))
        @test idsub == "gene-id"
        @test idval == "672"
        @test rest == [:limit => 10]

        # nothing-valued identifier kwargs are ignored (so explicit-kwarg defaults work)
        idsub2, idval2, _ = N._split_id(N._GENOME_IDS, (accession = nothing, taxon = "human"))
        @test idsub2 == "taxon" && idval2 == "human"

        # accession value may be a vector (multiple accessions)
        _, idval3, _ = N._split_id(N._GENOME_IDS, (accession = ["GCF_1", "GCF_2"],))
        @test N._idvalues(idval3) == ["GCF_1", "GCF_2"]

        @test_throws ArgumentError N._split_id(N._GENOME_IDS, (foo = 1,))                    # none
        @test_throws ArgumentError N._split_id(N._GENOME_IDS, (accession = "x", taxon = "y")) # two
    end

    @testset "gene taxon ambiguity" begin
        # taxon alone -> identifier (`gene taxon human`)
        idsub, idval, rest = N._split_id(N._GENE_IDS, (taxon = "human",); ambiguous = (:taxon,))
        @test idsub == "taxon" && idval == "human" && isempty(rest)

        # taxon + symbol -> symbol is the identifier, taxon demoted to --taxon filter
        idsub, idval, rest = N._split_id(N._GENE_IDS, (symbol = "BRCA1", taxon = "human"); ambiguous = (:taxon,))
        @test idsub == "symbol" && idval == "BRCA1"
        @test rest == [:taxon => "human"]
    end

    @testset "api key (resolved Julia-side, injected via env)" begin
        withenv("NCBI_API_KEY" => "ABC123") do
            @test N.api_key() == "ABC123"
            @test N._apikey_env(nothing) == ["NCBI_API_KEY" => "ABC123"]   # from env
            @test N._apikey_env("XYZ") == ["NCBI_API_KEY" => "XYZ"]        # explicit overrides
            @test N._apikey_env(false) == ["NCBI_API_KEY" => ""]           # suppress
        end
        withenv("NCBI_API_KEY" => nothing) do
            @test N.api_key() === nothing
            @test N._apikey_env(nothing) == Pair{String,String}[]          # unset -> none
            @test N._apikey_env("XYZ") == ["NCBI_API_KEY" => "XYZ"]
        end
    end

    @testset "snake_case key conversion" begin
        @test N._snakecase("organismName") == "organism_name"
        @test N._snakecase("taxId") == "tax_id"
        @test N._snakecase("assemblyInfo") == "assembly_info"
        @test N._snakecase("checkmInfo") == "checkm_info"
        @test N._snakecase("host") == "host"            # already lowercase, unchanged
    end

    @testset "jsonl -> Vector{NamedTuple}" begin
        # camelCase keys as the binary actually emits them
        jsonl = """
        {"accession":"GCF_1","organism":{"organismName":"Homo sapiens","taxId":9606}}
        {"accession":"GCF_2","organism":{"organismName":"Mus musculus","taxId":10090},"annotationInfo":{"name":"x"}}
        """
        rows = N._parse_jsonl(jsonl)

        @test length(rows) == 2
        @test rows[1].accession == "GCF_1"
        @test rows[1].organism.organism_name == "Homo sapiens"   # snake_cased + nested
        @test rows[1].organism.tax_id == 9606

        # top-level unification: row 1 lacks annotation_info -> missing
        @test rows[1].annotation_info === missing
        @test rows[2].annotation_info.name == "x"
        @test keys(rows[1]) == keys(rows[2])                     # uniform schema

        ct = coltable(rows)                                      # Tables.jl path
        @test ct.accession == ["GCF_1", "GCF_2"]
    end

    # Live NCBI calls — opt in (needs network).
    if RUN_NETWORK
        @testset "network (live NCBI)" begin
            pkg = download_virus_genome(accession = "NC_045512.2")
            @test isfile(pkg.path)
            rows = report(pkg)
            @test !isempty(rows)

            srows = summary_genome(accession = "GCF_000005845.2")  # E. coli
            @test !isempty(srows)
            @test haskey(srows[1], :accession)
        end

        # Run every ```jldoctest``` snippet in the README against live NCBI, so its
        # shown output can't drift from what the code actually returns. Documenter
        # doctests markdown pages under a source directory, so copy the README into
        # an isolated temp dir as its single page.
        readme = joinpath(pkgdir(NCBIDataSets), "README.md")
        mktempdir() do dir
            cp(readme, joinpath(dir, "index.md"))
            Documenter.doctest(dir, [NCBIDataSets]; testset = "README doctests (live NCBI)")
        end
    else
        @info "Skipping live-network tests. Set NCBIDATASETS_NETWORK_TESTS=1 to enable."
    end

end
