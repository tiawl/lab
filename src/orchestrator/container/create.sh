#! /usr/bin/env bash

container_create () {
  shift

  local json endpoint logged_endpoint method img
  img="${2}"
  json="{\"Hostname\":\"${3}\",\"Image\":\"${img}${sep[tag]}$(image tag list "${img}")\"}"
  endpoint="http://${version[docker_api]}/containers/create?name=${1}"
  logged_endpoint="${endpoint}&$(jq --null-input --raw-output '['"${json}"' | to_entries[] | .key + "=" + .value] | join("&")')"
  method='POST'
  readonly json endpoint logged_endpoint method img

  printf '%s %s\n' "${method}" "${logged_endpoint//\"/\\\"}" >&2

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --header 'Content-Type: application/json' --data "${json}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | jq '.' >&2
  } 3>&1 | sed --file "${sdir}/sed/colored_http_code.sed" >&2
}
