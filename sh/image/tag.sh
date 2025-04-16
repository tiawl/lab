#! /usr/bin/env bash

image_tag () {
  shift

  local endpoint method
  endpoint="http://${version[api]}/images/${1}${sep[tag]}${2}/tag?repo=${3}&tag=${4}"
  method='POST'
  readonly endpoint method

  req_id="$(( req_id + 1 ))"
  jq -n -r 'include "jq/module-color"; reset(bold(colored("'"${req_id}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" "${endpoint}"
}
