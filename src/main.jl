# Runs the pipeline stage provided as argument

using Pkg

const projectdir = get(ENV, "PROJECTDIR", "/project")
const workdir = joinpath(projectdir, "data")

Pkg.activate(projectdir)

include("utils.jl")

const command = ARGS[1]

if command == "fetch_sources"
    fetch_sources()
    sleep(10)           # delay for demo purposes
elseif command == "extract_sources"
    extract_sources()
    sleep(10)           # delay for demo purposes
elseif command == "index_sources"
    index_sources()
    sleep(10)           # delay for demo purposes
elseif command == "run_search_server"
    run_search_server()
else
    error("unknown command $command")
end
