#! /usr/bin/env bash

network_ip_list () { #HELP <network>|List all ip addresses used on <network>
  shift

  local endpoint method http_code
  endpoint="http://${version[docker_api]}/networks/${1}"
  method='GET'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed "${sed[colored_http_code]}"; }
  defer 'exec {HTTP_CODE[1]}>&- 3>&-; readl http_code <&${HTTP_CODE[0]}; wait "${HTTP_CODE_PID}" 2> /dev/null || :; printf "%s\n" "${http_code}" >&2'

  exec 3>&${HTTP_CODE[1]}

  curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
    | gojq --raw-output '.Containers | to_entries[].value.IPv4Address | sub("/[0-9]+$"; "")'
}
