#! /usr/bin/env bash

tag () {
  case "${1}" in
  ( 'list' ) tag_list "${@}" ;;
  ( * ) return 1 ;;
  esac
}
