#! /usr/bin/env bash

container () {
  case "${1}" in
  ( 'create' ) container_create "${@}" ;;
  ( 'start' ) printf 'TODO\n' ;;
  ( 'stop' ) : ;;
  ( 'remove' ) : ;;
  ( 'up' ) printf 'TODO\n' ;;
  ( 'down' ) : ;;
  ( 'created' ) : ;;
  ( 'running' ) : ;;
  ( 'resource' ) container_resource "${@}" ;;
  ( * ) return 1 ;;
  esac
}
