#! /usr/bin/env bash

container_create () {
  shift

  local json endpoint logged_endpoint method img
  img="${project[image]}${1}"
  
  json="{\"Hostname\":\"${1}\",\"Image\":\"${img}${sep[tag]}$(tag list "${img}")\"}"
  endpoint="http://${version[api]}/containers/create?name=${project[container]}${1}"
  logged_endpoint="${endpoint}&$(jq --null-input --raw-output '['"${json}"' | to_entries[] | .key + "=" + .value] | join("&")')"
  method='POST'
  readonly json endpoint logged_endpoint method img

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${logged_endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" --header 'Content-Type: application/json' --data "${json}" "${endpoint}" | jq '.'
}
