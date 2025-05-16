#! /usr/bin/env bash

container_start () { #HELP <container_name>|Start stopped <container_name>
  shift

  local endpoint method http_code
  endpoint="http://${version[docker_api]}/containers/${1}/start"
  method='POST'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed "${sed[colored_http_code]}"; }
  defer 'exec {HTTP_CODE[1]}>&- 3>&-; readl http_code <&${HTTP_CODE[0]}; wait "${HTTP_CODE_PID}" 2> /dev/null || :; printf "%s\n" "${http_code}" >&2'

  exec 3>&${HTTP_CODE[1]}

  curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
    | gojq '.' >&2
}
