#! /usr/bin/env bash

image_tagged () {
  shift

  local filters endpoint logged_endpoint method
  filters="{\"reference\":{\"${1}${sep[tag]}${2}\":true}}"
  method='GET'
  endpoint="http://${version[api]}/images/json?filters="
  logged_endpoint="${endpoint}${filters}"
  endpoint="${endpoint}$(urlencode "${filters}")"
  readonly filters endpoint logged_endpoint method

  req_id="$(( req_id + 1 ))"
  jq -n -r 'include "jq/module-color"; reset(bold(colored("'"${req_id}"'"; '"$(color)"'))) + " '"${method}"' '"${logged_endpoint//\"/\\\"}"'"' >&2

  curl --silent --show-error --request "${method}" --unix-socket "${path[socket]}" "${endpoint}" \
    | jq -e '. | length > 0' > /dev/null
}
