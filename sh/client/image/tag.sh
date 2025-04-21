#! /usr/bin/env bash

image_tag () {
  shift
  case "${1}" in
  ( 'create' ) image_tag_create "${@}" ;;
  ( 'list' ) image_tag_list "${@}" ;;
  ( 'exist' ) image_tag_exist "${@}" ;;
  ( * ) return 1 ;;
  esac
}
