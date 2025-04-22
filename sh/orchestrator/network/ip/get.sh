#! /usr/bin/env bash

network_ip_get () {
  shift

  local endpoint method
  endpoint="http://${version[api]}/containers/${project[container]}${1}/json"
  method='GET'
  readonly endpoint method

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" --write-out "%{stderr}$(printf "%$(( ${#REPLY[req_id]} + 1 ))s")> HTTP %{response_code}\n" "${endpoint}" \
    | jq --raw-output '.NetworkSettings.Networks[$net].IPAddress' --arg net "${2:-bridge}"
}
