#! /usr/bin/env bash

volume () {
  case "${1}" in
  ( 'create' ) : ;;
  ( 'remove' ) : ;;
  ( * ) return 1 ;;
  esac
}
