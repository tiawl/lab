#! /usr/bin/env bash

network_ip () {
  shift
  case "${1}" in
  ( 'get' ) network_ip_get "${@}" ;;
  ( 'list' ) : ;;
  ( * ) return 1 ;;
  esac
}
