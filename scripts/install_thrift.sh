#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools/thrift
curl -fsSL --retry 3 https://archive.apache.org/dist/thrift/0.25.0/thrift-0.25.0.tar.gz -o .tools/thrift/source.tar.gz
python3 -c "import hashlib,pathlib; assert hashlib.sha256(pathlib.Path('.tools/thrift/source.tar.gz').read_bytes()).hexdigest() == '66da4707214c54c94bac082103dc67adaf9e08925662700f269170a7b534b214'"
tar -xzf .tools/thrift/source.tar.gz -C .tools/thrift
cmake -S .tools/thrift/thrift-0.25.0 -B .tools/thrift/build -DBUILD_LIBRARIES=OFF -DBUILD_TESTING=OFF -DBUILD_TUTORIALS=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build .tools/thrift/build --target thrift-compiler --parallel 2
.tools/thrift/build/compiler/cpp/bin/thrift --version
