#! /usr/bin/env bash

image_tag_compute() { #HELP <context> [<buildargs>]|Compute a tag from <context> and <buildargs>
  shift

  : "$({
    tar --directory "${1}" --create --file=- --sort=name --mtime='UTC 2019-01-01' --group=0 --owner=0 --numeric-owner .
    shift
    declare -f image_build
    printf '%s\n' "${@}"
  } | sha256sum)"
  : "${_%% *}"
  printf '%s' "${_:0:20}"
}
