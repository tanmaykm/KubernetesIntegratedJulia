using Tar, CodecZlib, GoogleCodeSearch, Sockets, JSON

const paths = (
    inputs = joinpath(workdir, "inputs"),
    downloaded = joinpath(workdir, "downloaded"),
    extracted = joinpath(workdir, "extracted"),
    index = joinpath(workdir, "index"),
)

function fetch_sources()
    mkpath(paths.downloaded)
    for name in readdir(paths.downloaded)
        rm(joinpath(paths.downloaded, name))
    end
    for name in readdir(paths.inputs)
        src = joinpath(paths.inputs, name)
        dest = joinpath(paths.downloaded, name)
        cp(src, dest)
    end
end

function extract_sources()
    mkpath(paths.extracted)
    for name in readdir(paths.extracted)
        rm(joinpath(paths.extracted, name), recursive=true)
    end
    for name in readdir(paths.downloaded)
        src = joinpath(paths.downloaded, name)
        dest = joinpath(paths.extracted, name)

        tar_gz = open(src)
        tar = GzipDecompressorStream(tar_gz)
        Tar.extract(tar, dest)
    end
end

function index_sources()
    ctx = Ctx(store=paths.index)
    for name in readdir(paths.index)
        rm(joinpath(paths.index, name))
    end
    for path in readdir(paths.extracted)
        index(ctx, joinpath(paths.extracted, path))
    end
end

function run_search_server()
    ctx = Ctx(store=paths.index)
    run_http(ctx; host=ip"0.0.0.0", port=5555)
end
