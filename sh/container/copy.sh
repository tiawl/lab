#! /usr/bin/env bash

container_copy () {
  shift

  local endpoint method
  endpoint="http://${version[api]}/containers/${project[container]}${1}/archive?path=${2}"
  method='GET'
  readonly endpoint method

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" --output - "${endpoint}" \
    | tar --extract --directory "${3}"
}
