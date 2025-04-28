#! /usr/bin/env bash

image_builder_prune () { #HELP\t\t\t\t\t\t\tRemove build cache
  local endpoint method
  endpoint="http://${version[docker_api]}/build/prune?all=true"
  method='POST'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq '.' >&2
  } 3>&1 | sed --file <(printf '%s' "${sed[colored_http_code]}") >&2
}
