using Tar, CodecZlib, GoogleCodeSearch, Sockets, JSON

# A simple search server for demo.
#
# - Fetches source code for Julia packages from github releases
# - Extracts them
# - Indexes them using GoogleCodeSearch.jl
# - Serves a REST API that provides results using the index
#
# To simplify things and highlight the important parts, we use
# - only certain pre-downloaded sources, from the file system
# - a single index, no incremental re-indexing
# - the search server provided by GoogleCodeSearch.jl

const paths = (
    inputs = joinpath(workdir, "inputs"),           # the pre-fetched source bundles
    downloaded = joinpath(workdir, "downloaded"),   # just copy those here and pretend we fetched from github
    extracted = joinpath(workdir, "extracted"),     # extract the tar bundles here
    index = joinpath(workdir, "index"),             # and create the index here
)

function fetch_sources()
    mkpath(paths.downloaded)                        # create working path if it does not exist
    for name in readdir(paths.downloaded)           # clean up any old downloaded sources
        rm(joinpath(paths.downloaded, name))
    end
    for name in readdir(paths.inputs)               # fetch all inputs into downloaded folder
        src = joinpath(paths.inputs, name)
        dest = joinpath(paths.downloaded, name)
        cp(src, dest)
    end
end

function extract_sources()
    mkpath(paths.extracted)                         # create working path if it does not exist
    for name in readdir(paths.extracted)            # clean up any old extracted sources
        rm(joinpath(paths.extracted, name), recursive=true)
    end
    for name in readdir(paths.downloaded)
        src = joinpath(paths.downloaded, name)
        dest = joinpath(paths.extracted, name)

        tar_gz = open(src)
        tar = GzipDecompressorStream(tar_gz)
        Tar.extract(tar, dest)                      # extract all downloaded bundles
    end
end

function index_sources()
    ctx = Ctx(store=paths.index)                    # initialize code search
    for name in readdir(paths.index)                # clean up the old index
        rm(joinpath(paths.index, name))
    end
    for path in readdir(paths.extracted)            # create a new index
        index(ctx, joinpath(paths.extracted, path))
    end
end

function run_search_server()
    ctx = Ctx(store=paths.index)                    # initialize context pointing to index
    run_http(ctx; host=ip"0.0.0.0", port=5555)      # start the search server
end
