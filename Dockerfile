FROM julia:1.6.0

RUN mkdir -p /project/data
WORKDIR /project

COPY Manifest.toml /project/Manifest.toml
COPY Project.toml /project/Project.toml
COPY src /project/src

RUN julia --project=/project -e 'using Pkg; Pkg.instantiate(); Pkg.API.precompile()'
ENTRYPOINT [ "julia", "--project=/project", "/project/src/main.jl" ]