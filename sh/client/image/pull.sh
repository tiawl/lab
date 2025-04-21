#! /usr/bin/env bash

image_pull () {
  shift

  local endpoint method img
  img="${1}${sep[image]}${2}${sep[image]}${3}${sep[tag]}${4}"
  endpoint="http://${version[api]}/images/create?fromImage=${img}"
  method='POST'
  readonly endpoint method img

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" --no-buffer "${endpoint}" \
    | jq --unbuffered --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " > image pull '"${img}"' > " + .status + (if .progress | length > 0 then " " else "" end) + .progress' >&2
}
