#! /usr/bin/env bash

image_builder_prune () { #HELP\t\t\t\t\t\t\tRemove build cache
  local endpoint method http_code
  endpoint="http://${version[docker_api]}/build/prune?all=true"
  method='POST'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed --file <(printf '%s' "${sed[colored_http_code]}"); }

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq '.' >&2
  } 3>&"${HTTP_CODE[1]}"

  exec {HTTP_CODE[1]}>&-
  readl http_code <&"${HTTP_CODE[0]}"
  printf '%s\n' "${http_code}" >&2
}
