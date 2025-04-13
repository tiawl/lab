#! /usr/bin/env bash

network () {
  req_id="$(( req_id + 1 ))"
  case "${1}" in
  ( 'create' ) : ;;
  ( 'remove' ) : ;;
  ( * ) return 1 ;;
  esac
}
