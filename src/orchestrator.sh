#! /usr/bin/env bash

orchestrator () {
  global sdir
  sdir="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && printf '%s' "${PWD}")"
  readonly sdir

  harden base64
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

  # TODO: manage DOCKERD_HOST, BUILDKITD_HOST, CONTAINERD_HOST env vars

  case "${1:-}" in
  ( image|container|network|volume|runner ) "${@}" ;;
  ( * ) help ;;
  esac
}
