#! /usr/bin/env bash

image_merge () { #HELP <repository> <tag> <base> <context> <buildargs> [<context> <buildargs>] [...]|Build an image from multiple Dockerfiles
  shift

  local repo tag i from args
  repo="${1}"
  tag="${2}"
  from="${3}"
  i='1'
  readonly repo tag

  shift 3

  while gt "${#}" 0
  do
    args="$(gojq --monochrome-output --null-input --compact-output "${2}"' + {FROM: "'"${from}"'"}')"
    if gt "${#}" 2
    then
      image build "${repo}" "${tag}-stage-${i}" "${1}" "${args}"
    else
      image build "${repo}" "${tag}" "${1}" "${args}"
    fi
    shift 2
    from="${repo}${sep[tag]}${tag}-stage-${i}"
    (( i++ ))
  done

  image prune "${repo}${sep[tag]}${tag}-stage-*"
}
