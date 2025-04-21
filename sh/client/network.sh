#! /usr/bin/env bash

network () {
  case "${1}" in
  ( 'create' ) : ;;
  ( 'remove' ) : ;;
  ( 'ip' ) network_ip "${@}" ;;
  ( * ) return 1 ;;
  esac
}
