#! /usr/bin/env bash

init () {
  # global sdir
  # sdir="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && printf '%s' "${PWD}")"
  # readonly sdir

  harden base64
  #harden bc
  harden cat
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

  local backend
  if is socket '/var/run/containerd/containerd.sock'
  then
    backend='containerd'
  elif is socket '/var/run/docker.sock'
  then
    backend='docker'
  else
    error 'No available backend'
  fi

  # TODO: remove this later
  backend='docker'
  readonly backend

  # TODO: manage DOCKERD_HOST, BUILDKITD_HOST, CONTAINERD_HOST env vars
}

orchestrator () {
  init

  case "${1:-}" in
  ( image|container|network|volume|runner|version|help ) "${@}" ;;
  ( * ) help ;;
  esac
}
