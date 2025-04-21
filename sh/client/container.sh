#! /usr/bin/env bash

container () {
  case "${1}" in
  ( 'create' ) container_create "${@}" ;;
  ( 'start' ) container_start "${@}" ;;
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
