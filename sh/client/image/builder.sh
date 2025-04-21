#! /usr/bin/env bash

image_builder () {
  shift
  case "${1}" in
  ( 'cleanup' ) image_builder_cleanup ;;
  ( * ) return 1 ;;
  esac
}
