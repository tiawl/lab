#! /usr/bin/env bash

container_resource () {
  shift
  case "${1}" in
  ( 'copy' ) container_resource_copy "${@}" ;;
  ( * ) return 1 ;;
  esac
}
