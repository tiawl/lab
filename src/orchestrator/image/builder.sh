#! /usr/bin/env bash

image_builder () {
  shift
  case "${1}" in
  ( 'prune' ) image_builder_prune ;;
  ( * ) return 1 ;;
  esac
}
