#! /usr/bin/env bash

container_create () {
  shift

    local json endpoint logged_endpoint method
    json="{\"Hostname\":\"${1}\",\"Image\":\"${project[image]}${1}\"}"
    endpoint="http://${version[api]}/containers/create?name=${project[container]}${1}"
    logged_endpoint="${endpoint}&$(jq -r -n '['"${json}"' | to_entries[] | .key + "=" + .value] | join("&")')"
    method='POST'
    readonly json endpoint logged_endpoint method

    req_id="$(( req_id + 1 ))"
    jq -n -r 'include "jq/module-color"; reset(bold(colored("'"${req_id}"'"; '"$(color)"'))) + " '"${method}"' '"${logged_endpoint//\"/\\\"}"'"' >&2

    curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" --header 'Content-Type: application/json' --data "${json}" "${endpoint}"
}
