#! /usr/bin/env bash

image_tag_create () {
  shift

  local endpoint method
  endpoint="http://${version[docker_api]}/images/${1}${sep[tag]}${2}/tag?repo=${3}&tag=${4}"
  method='POST'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | jq '.' >&2
  } 3>&1 | sed --file "${sdir}/sed/colored_http_code.sed" >&2
}
