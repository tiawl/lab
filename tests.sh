#! /usr/bin/env bash

tests () {
  set -C -e -u -o pipefail
  shopt -s lastpipe extglob

  sdir="$(CDPATH='' cd -- "$(dirname -- "${0}")" > /dev/null 2>&1; pwd)"
  readonly sdir

  shopt -s globstar
  bats --show-output-of-passing-tests --print-output-on-failure "${sdir}"/test/**/*.sh
}

tests "${@}"
