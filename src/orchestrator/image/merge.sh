#! /usr/bin/env bash

image_merge () { #HELP <repository> <image> [<context> <buildargs>] [<context> <buildargs>] [...]|Build an image from multiple Dockerfiles
  shift

  local repo i prev
  repo="${1}"
  prev="${2}"
  i='1'
  readonly repo

  shift 2

  while gt "${#}" 0
  do
    on noglob
    image build "${repo}" "stage-${i}" "${1}" 'FROM' "${prev}" ${2}
    off noglob
    shift 2
    prev="${repo}${sep[tag]}stage-${i}"
    (( i += 1 ))
  done
}
