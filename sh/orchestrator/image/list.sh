#! /usr/bin/env bash

image_list () {
  shift

  local filters endpoint logged_endpoint method
  filters="{\"reference\":{\"${1}\":true}}"
  method='GET'
  endpoint="http://${version[api]}/images/json?filters="
  logged_endpoint="${endpoint}${filters}"
  endpoint="${endpoint}$(urlencode "${filters}")"
  readonly filters endpoint logged_endpoint method

  var incr req_id
  var get req_id
  jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${logged_endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" --write-out "%{stderr}$(printf "%$(( ${#REPLY[req_id]} + 1 ))s")> HTTP %{response_code}\n" "${endpoint}" \
    | jq --raw-output '.[].RepoTags[]'
}
