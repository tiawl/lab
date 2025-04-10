#! /usr/bin/env bash

main () {
  set -eux
  mkdir -p api/services/control api/types google/rpc solver/pb sourcepolicy/pb
  curl -s --output google/rpc/status.proto https://raw.githubusercontent.com/googleapis/googleapis/master/google/rpc/status.proto
  curl -s --output api/services/control/control.proto https://raw.githubusercontent.com/moby/buildkit/master/api/services/control/control.proto
  curl -s --output api/types/worker.proto https://raw.githubusercontent.com/moby/buildkit/master/api/types/worker.proto
  curl -s --output solver/pb/ops.proto https://raw.githubusercontent.com/moby/buildkit/master/solver/pb/ops.proto
  curl -s --output sourcepolicy/pb/policy.proto https://raw.githubusercontent.com/moby/buildkit/master/sourcepolicy/pb/policy.proto
  for gen in api/types/worker.proto api/services/control/control.proto google/rpc/status.proto
  do
    sed -i 's@github.com/moby/buildkit/@@g' "${gen}"
  done
}

main "${@}"
