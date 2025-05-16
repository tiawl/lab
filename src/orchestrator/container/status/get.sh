#! /usr/bin/env bash

container_status_get () { #HELP <container>|Return the status of the given <container>
  shift

  local endpoint method http_code
  method='GET'
  endpoint="http://${version[docker_api]}/containers/${1}/json"
  readonly endpoint method

  printf '%s %s\n' "${method}" "$(url decode "${endpoint}")" >&2

  coproc HTTP_CODE { sed "${sed[colored_http_code]}"; }
  defer 'exec {HTTP_CODE[1]}>&- 3>&-; readl http_code <&${HTTP_CODE[0]}; wait "${HTTP_CODE_PID}" 2> /dev/null || :; printf "%s\n" "${http_code}" >&2'

  exec 3>&${HTTP_CODE[1]}

  curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
    | gojq --raw-output '.State.Status'
}
