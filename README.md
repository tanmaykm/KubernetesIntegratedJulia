# Kubernetes Integrated Julia Applications

## Webinar
- What is Kubernetes (k8s)
- Kuber.jl - Julia Package for interacting with Kubernetes
    - Basic APIs - get, put, delete
    - Monitoring Cluster Events - the watch API
- Example: Code Search Server on Kubernetes
    - Pipeline to crawl sources, download and index them
    - Serve HTTP APIs to search the index
    - Update index periodically

### Search server
- [search server methods](src/utils.jl)
- [main](src/main.jl)

### Kubernetes integration
- [Dockerfile](Dockerfile)
- [driver](src/k8sutils.jl)

### References

- [Slides](KubernetesIntegratedJuliaApplications.pdf)
- [Kuber.jl](https://github.com/JuliaComputing/Kuber.jl)
- [GoogleCodeSearch.jl](https://github.com/tanmaykm/GoogleCodeSearch.jl)

### Screencasts

#### Using Kuber.jl

`asciinema play screencasts/462454.cast`

[![Screencast - Using Kuber.jl](https://asciinema.org/a/462454.svg)](https://asciinema.org/a/462454)

#### Search server pipeline

`asciinema play screencasts/462469.cast`

[![Screencast - Search server pipeline](https://asciinema.org/a/462469.svg)](https://asciinema.org/a/462469)
