#! /usr/bin/env bash

runner () {
  case "${1}" in
  ( 'dry' ) runner_dry "${@}" ;;
  ( 'exec' ) runner_exec "${@}" ;;
  ( * ) return 1 ;;
  esac
}
