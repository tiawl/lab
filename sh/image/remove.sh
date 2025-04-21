#! /usr/bin/env bash

image_remove () {
  shift

  local endpoint method
  endpoint="http://${version[api]}/images/${1}${sep[tag]}${2}"
  method='DELETE'
  readonly endpoint method

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" "${endpoint}" \
    | jq '.'
}
