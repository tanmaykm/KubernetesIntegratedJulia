#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p ${DIR}/inputs ${DIR}/moreinputs
rm -rf ${DIR}/inputs/* ${DIR}/moreinputs/*

wget -O ${DIR}/inputs/Kuber.jl-v0.5.1.tar.gz https://github.com/JuliaComputing/Kuber.jl/archive/refs/tags/v0.5.1.tar.gz
wget -O ${DIR}/inputs/JSON.jl-0.21.2.tar.gz https://github.com/JuliaIO/JSON.jl/archive/refs/tags/v0.21.2.tar.gz

wget -O ${DIR}/moreinputs/Swagger.jl-v0.3.3.tar.gz https://github.com/JuliaComputing/Swagger.jl/archive/refs/tags/v0.3.3.tar.gz
