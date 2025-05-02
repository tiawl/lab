#! /usr/bin/env bash

main () {
  set -C -e -u -x -o pipefail
  shopt -s lastpipe extglob

  mkdir --parents vendor/api/services/control vendor/api/types vendor/google/protobuf vendor/google/rpc vendor/solver/pb vendor/sourcepolicy/pb
  curl --silent --show-error --output vendor/google/protobuf/any.proto https://raw.githubusercontent.com/protocolbuffers/protobuf/refs/heads/main/src/google/protobuf/any.proto
  curl --silent --show-error --output vendor/google/protobuf/timestamp.proto https://raw.githubusercontent.com/protocolbuffers/protobuf/refs/heads/main/src/google/protobuf/timestamp.proto
  curl --silent --show-error --output vendor/google/rpc/status.proto https://raw.githubusercontent.com/googleapis/googleapis/master/google/rpc/status.proto
  curl --silent --show-error --output vendor/api/services/control/control.proto https://raw.githubusercontent.com/moby/buildkit/master/api/services/control/control.proto
  curl --silent --show-error --output vendor/api/types/worker.proto https://raw.githubusercontent.com/moby/buildkit/master/api/types/worker.proto
  curl --silent --show-error --output vendor/solver/pb/ops.proto https://raw.githubusercontent.com/moby/buildkit/master/solver/pb/ops.proto
  curl --silent --show-error --output vendor/sourcepolicy/pb/policy.proto https://raw.githubusercontent.com/moby/buildkit/master/sourcepolicy/pb/policy.proto
  for gen in vendor/api/types/worker.proto vendor/api/services/control/control.proto vendor/google/rpc/status.proto
  do
    sed --in-place 's@github.com/moby/buildkit/@vendor/@; s@google/rpc/@vendor/\0@; s@google/protobuf/@vendor/\0@' "${gen}"
  done
  protoc -o ./descriptor_sets/control.proto --include_imports --proto_path=. ./vendor/api/services/control/control.proto
}

main "${@}"
