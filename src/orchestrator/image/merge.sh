#! /usr/bin/env bash

image_merge () { #HELP <repository> <tag> <base> <context> <buildargs> [<context> <buildargs>] [...]|Build an image from multiple Dockerfiles
  shift

  local repo tag i prev
  repo="${1}"
  tag="${2}"
  prev="${3}"
  i='1'
  readonly repo tag

  shift 3

  while gt "${#}" 0
  do
    # TODO: check FROM is not used into buildargs
    image build "${repo}" "stage-${i}" "${1}" 'FROM' "${prev}" "${2}"
    shift 2
    prev="${repo}${sep[tag]}stage-${i}"
    (( i++ ))
  done

  (( i-- ))
  image tag create "{repo}" "stage-${i}" "${repo}" "${tag}"
}
