#! /usr/bin/env bash

container_stop () { #HELP <container_name>\t\t\t\t\t\tStop running <container_name>
  shift

  local endpoint method http_code
  endpoint="http://${version[docker_api]}/containers/${1}/stop?t=1"
  method='POST'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed --file <(printf '%s' "${sed[colored_http_code]}"); }
  defer 'exec {HTTP_CODE[1]}>&-'
  defer 'readl http_code <&"${HTTP_CODE[0]}"; wait ${HTTP_CODE_PID}'
  defer 'printf "%s\n" "${http_code}" >&2'

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq '.' >&2
  } 3>&"${HTTP_CODE[1]}"
}
