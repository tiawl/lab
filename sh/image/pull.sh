#! /usr/bin/env bash

image_pull () {
  shift

  local endpoint method img
  img="${1}${sep[image]}${2}${sep[image]}${3}${sep[tag]}${4}"
  endpoint="http://${version[api]}/images/create?fromImage=${img}"
  method='POST'
  readonly endpoint method img

  req_id="$(( req_id + 1 ))"
  jq -n -r 'include "jq/module-color"; reset(bold(colored("'"${req_id}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" "${endpoint}" \
    | jq -r 'include "jq/module-color"; reset(bold(colored("'"${req_id}"'"; '"$(color)"'))) + " > image pull '"${img}"' > " + .status + (if .progress | length > 0 then " " else "" end) + .progress' >&2
}
