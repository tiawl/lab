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
  set -f
  for char in ${!encoded[@]}
  do
    str="${str//"${char}"/"${encoded["${char}"]}"}"
  done
  set +f
  printf '%s\n' "${str}"
}

# TODO: remove this and manage request in each docker client function
req () {
  str starts "${2}" '/'

  local socket_path method endpoint encoded_endpoint key done
  socket_path='/var/run/docker.sock'
  method="${1^^}"
  set -f
  for key in ${!encode_me[@]}
  do
    encoded_endpoint="${encoded_endpoint:-}${encoded_endpoint:+&}${key}=$(encode "${encode_me["${key}"]}")"
    endpoint="${endpoint:-}${endpoint:+&}${key}=${encode_me["${key}"]}"
  done
  for key in ${!json2queryparam[@]}
  do
    endpoint="${endpoint:-}$(jq -r -n '"&" + (['"${json2queryparam["${key}"]}"' | to_entries[] | .key + "=" + .value] | join("&"))')"
    if str empty "${done:-}"
    then
      set -- "${@}" '-H' 'Content-Type: application/json'
      done='true'
    fi
    set -- "${@}" '--data' "${json2queryparam["${key}"]}"
  done
  set +f
  encoded_endpoint="http://${version[api]}${2}${encoded_endpoint:-}"
  endpoint="http://${version[api]}${2}${endpoint:-}"
  readonly socket_path method endpoint encoded_endpoint

  shift 2
  declare -A encode_me
  declare -a json2queryparam

  jq -n -r 'include "jq/module-color"; colored("'"${req_id}"'"; '"$(color)"') + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  case "${method}" in
  ( 'GET'|'POST'|'DELETE' ) curl -s --unix-socket "${socket_path}" -X "${method}" "${@}" "${encoded_endpoint}" ;;
  ( * ) return 1 ;;
  esac
}
