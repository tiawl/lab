#! /usr/bin/env bash

orchestrator () {
  dirname () {
    \command set -- "${1:-.}"
    \command set -- "${1%%"${1##*[!/]}"}"

    [ "${1##*/*}" ] && \command set -- '.'

    \command set -- "${1%/*}"
    \command set -- "${1%%"${1##*[!/]}"}"
    \command printf '%s\n' "${1:-/}"
  }

  if [[ -z "${BASH_ENV:-}" ]]
  then
    \command exec -c env -i BASH_ENV="$(CDPATH='' \command cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && \command printf '%s\n' "${PWD}")/src/utils.sh" bash --norc --noprofile "${BASH_SOURCE[0]}" "${@}" || exit 1
  fi

  on errexit noclobber nounset pipefail lastpipe

  # TODO: use sdir
  global sdir
  sdir="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && printf '%s' "${PWD}")"
  readonly sdir

  #harden bc
  harden curl
  harden env
  harden gojq
  #harden mktemp
  harden protoc
  harden sed
  harden sha256sum
  #harden shuf
  harden tar
  #harden tee

  local file backend
  if is socket '/var/run/containerd/containerd.sock'
  then
    backend='containerd'
  elif is socket '/var/run/docker.sock'
  then
    backend='docker'
  else
    printf 'No available backend\n' >&2
    return 1
  fi

  # TODO: remove this later
  backend='docker'
  readonly backend

  on globstar
  for file in "${sdir}/src/orchestrator"/**/*.sh
  do
    source "${file}"
  done
  off globstar

  # TODO: manage DOCKERD_HOST, BUILDKITD_HOST, CONTAINERD_HOST env vars

  "${@}"
}

orchestrator "${@}"
