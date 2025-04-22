#! /usr/bin/env bash

image_tag_create () {
  shift

  local endpoint method
  endpoint="http://${version[api]}/images/${1}${sep[tag]}${2}/tag?repo=${3}&tag=${4}"
  method='POST'
  readonly endpoint method

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" --write-out "%{stderr}$(printf "%$(( ${#REPLY[req_id]} + 1 ))s")> HTTP %{response_code}\n" "${endpoint}"
}
