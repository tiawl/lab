#! /usr/bin/env bash

image () {
  case "${1}" in
  ( 'build' ) image_build "${@}" ;;
  ( 'pull' ) image_pull "${@}" ;;
  ( 'list' ) image_list "${@}" ;;
  ( 'remove' ) image_remove "${@}" ;;
  ( 'prune' ) image_prune "${@}" ;;
  ( 'builder' ) image_builder "${@}" ;;
  ( 'tag' ) image_tag "${@}" ;;
  ( * ) return 1 ;;
  esac
}
