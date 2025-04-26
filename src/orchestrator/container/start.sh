#! /usr/bin/env bash

container_start () {
  shift

  local endpoint method
  endpoint="http://${version[docker_api]}/containers/${1}/start"
  method='POST'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq '.' >&2
  } 3>&1 | sed --file <(printf '%s' "${sed[colored_http_code]}") >&2
}
