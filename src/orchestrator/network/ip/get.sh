#! /usr/bin/env bash

network_ip_get () { #HELP <container> <network>\t\t\t\t\t\tList <container> ip address on <network_id>
  shift

  local endpoint method http_code
  endpoint="http://${version[docker_api]}/containers/${1}/json"
  method='GET'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed "${sed[colored_http_code]}"; }
  defer 'exec {HTTP_CODE[1]}>&-; readl http_code <&${HTTP_CODE[0]}; wait "${HTTP_CODE_PID}" 2> /dev/null || :; printf "%s\n" "${http_code}" >&2'

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out '%{stderr}%{scheme} %{response_code}\n' "${endpoint}" 2>&3 \
      | gojq --raw-output '.NetworkSettings.Networks[$net].IPAddress' --arg net "${2:-bridge}"
  } 3>&${HTTP_CODE[1]}
}
