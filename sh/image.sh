#! /usr/bin/env bash

source_dir () {
  local file
  for file in "${sdir}/sh/image/"*
  do
    source "${file}"
  done
}

source_dir

image () {
  case "${1}" in
  ( 'build' ) image_build "${@}" ;;
  ( 'pull' ) image_pull "${@}" ;;
  ( 'tag' ) image_tag "${@}" ;;
  ( 'list' ) image_list "${@}" ;;
  ( 'remove' ) image_remove "${@}" ;;
  ( 'prune' ) image_prune "${@}" ;;
  ( 'tagged' ) image_tagged "${@}" ;;
  ( * ) return 1 ;;
  esac
}
