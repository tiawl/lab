#! /usr/bin/env bash

builder_prune () {
  local endpoint method
  endpoint="http://${version[api]}/build/prune?all=true"
  method='POST'
  readonly endpoint method

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" "${endpoint}" \
    | jq '.'
}

builder () {
  case "${1}" in
  ( 'prune' ) builder_prune ;;
  ( * ) return 1 ;;
  esac
}
