#! /usr/bin/env bash

network () {
  case "${1}" in
  ( 'create' ) : ;;
  ( 'remove' ) : ;;
  ( * ) return 1 ;;
  esac
}
