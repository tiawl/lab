#! /usr/bin/env bash

container () {
  case "${1}" in
  ( 'copy' ) container_copy "${@}" ;;
  ( 'create' ) container_create "${@}" ;;
  ( 'start' ) printf 'TODO\n' ;;
  ( 'stop' ) : ;;
  ( 'remove' ) : ;;
  ( 'up' ) printf 'TODO\n' ;;
  ( 'down' ) : ;;
  ( 'created' ) : ;;
  ( 'running' ) : ;;
  ( * ) return 1 ;;
  esac
}
