#! /usr/bin/env bash

network_ip_list () {
  shift

  local endpoint method
  endpoint="http://${version[api]}/networks/${project[network]}${1}"
  method='GET'
  readonly endpoint method

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" --write-out "%{stderr}$(printf "%$(( ${#REPLY[req_id]} + 1 ))s")> HTTP %{response_code}\n" "${endpoint}" \
    | jq --raw-output '.Containers | to_entries[].value.IPv4Address | sub("/[0-9]+$"; "")'
}
