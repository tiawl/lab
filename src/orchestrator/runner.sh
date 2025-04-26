#! /usr/bin/env bash

runner () {
  case "${1}" in
  ( 'exec' ) runner_exec "${@}" ;;
  ( * ) return 1 ;;
  esac
}
