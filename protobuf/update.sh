#! /usr/bin/env bash

main () {
  set -C -e -u -x -o pipefail
  shopt -s lastpipe

  mkdir --parents api/services/control api/types google/rpc solver/pb sourcepolicy/pb
  curl --silent --show-error --output google/rpc/status.proto https://raw.githubusercontent.com/googleapis/googleapis/master/google/rpc/status.proto
  curl --silent --show-error --output api/services/control/control.proto https://raw.githubusercontent.com/moby/buildkit/master/api/services/control/control.proto
  curl --silent --show-error --output api/types/worker.proto https://raw.githubusercontent.com/moby/buildkit/master/api/types/worker.proto
  curl --silent --show-error --output solver/pb/ops.proto https://raw.githubusercontent.com/moby/buildkit/master/solver/pb/ops.proto
  curl --silent --show-error --output sourcepolicy/pb/policy.proto https://raw.githubusercontent.com/moby/buildkit/master/sourcepolicy/pb/policy.proto
  for gen in api/types/worker.proto api/services/control/control.proto google/rpc/status.proto
  do
    sed --in-place 's@github.com/moby/buildkit/@@g' "${gen}"
  done
}

main "${@}"
