#! /usr/bin/env bash

encode () {
  declare -A encoded
  encoded['{']='%7B'
  encoded['}']='%7D'
  encoded[':']='%3A'
  encoded['"']='%22'
  encoded['/']='%2F'
  encoded['?']='%3F'
  encoded['&']='%26'
  encoded['=']='%3D'
  encoded['.']='%2E'

  local str char
  str="${1}"
  for char in ${!encoded[@]}
  do
    str="${str//"${char}"/"${encoded["${char}"]}"}"
  done
  printf '%s\n' "${str}"
}

req () {
  str starts "${2}" '/'

  local socket_path api_version method endpoint encoded_endpoint key
  socket_path='/var/run/docker.sock'
  api_version='v1.48'
  method="${1}"
  encoded_endpoint="http://${api_version}${2}"
  endpoint="${encoded_endpoint}"
  for key in ${!encode_me[@]}
  do
    encoded_endpoint="${encoded_endpoint}${key}=$(encode "${encode_me["${key}"]}")"
    endpoint="${endpoint}${key}=${encode_me["${key}"]}"
  done
  endpoint="${endpoint//\"/\\\"}"
  readonly socket_path api_version method encoded_endpoint endpoint
  shift 2
  declare -A encode_me

  jq -n -r 'include "jq/module-color"; colored("'"${req_id}"'"; '"$(color)"') + " '"${method^^}"' '"${endpoint}"'"' >&2

  case "${method}" in
  ( 'get' ) curl -s --unix-socket "${socket_path}" -X GET "${@}" "${encoded_endpoint}" ;;
  ( 'post' ) curl -s --unix-socket "${socket_path}" -X POST "${@}" "${encoded_endpoint}" ;;
  ( 'del' ) curl -s --unix-socket "${socket_path}" -X DELETE "${@}" "${encoded_endpoint}" ;;
  ( * ) return 1 ;;
  esac
}
