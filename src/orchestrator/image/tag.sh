#! /usr/bin/env bash

image_tag () {
  shift
  case "${1}" in
  ( 'compute' ) image_tag_compute "${@}" ;;
  ( 'create' ) image_tag_create "${@}" ;;
  ( 'list' ) image_tag_list "${@}" ;;
  ( 'defined' ) image_tag_defined "${@}" ;;
  ( * ) return 1 ;;
  esac
}
