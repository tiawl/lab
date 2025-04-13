#! /usr/bin/env bash

volume () {
  req_id="$(( req_id + 1 ))"
  case "${1}" in
  ( 'create' ) : ;;
  ( 'remove' ) : ;;
  ( * ) return 1 ;;
  esac
}
