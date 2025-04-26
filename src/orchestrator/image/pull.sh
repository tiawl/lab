#! /usr/bin/env bash

image_pull () {
  shift

  local endpoint method img
  img="${1}${sep[image]}${2}${sep[image]}${3}${sep[tag]}${4}"
  endpoint="http://${version[docker_api]}/images/create?fromImage=${img}"
  method='POST'
  readonly endpoint method img

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --no-buffer --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq --raw-output '"image pull '"${img}"' > " + .status + (if .progress | length > 0 then " " else "" end) + .progress' >&2
  } 3>&1 | sed --file <(printf '%s' "${sed[colored_http_code]}") >&2
}
