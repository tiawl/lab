#! /usr/bin/env bash

image_tag_compute() { #HELP <context>\tCreate a tag <new_image>:<new_tag> that refers to\n\t\t\t\t\t\t\t\t\t\t\t<image_source>:<tag_source>
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
