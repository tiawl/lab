#! /usr/bin/env bash

container_status () {
  shift
  case "${1}" in
  ( 'get' ) container_status_get "${@}" ;;
  ( 'created' ) container_status_created "${@}" ;;
  ( 'running' ) container_status_running "${@}" ;;
  ( 'healthy' ) container_status_healthy "${@}" ;;
  ( * ) return 1 ;;
  esac
}
