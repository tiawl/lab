#! /usr/bin/env bash

network_ip_list () { #HELP <network>\t\t\t\t\t\t\tList all ip addresses used on <network>
  shift

  local endpoint method http_code
  endpoint="http://${version[docker_api]}/networks/${1}"
  method='GET'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed --file <(printf '%s' "${sed[colored_http_code]}"); }

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq --raw-output '.Containers | to_entries[].value.IPv4Address | sub("/[0-9]+$"; "")'
  } 3>&"${HTTP_CODE[1]}"

  exec {HTTP_CODE[1]}>&-
  readl http_code <&"${HTTP_CODE[0]}"
  printf '%s\n' "${http_code}" >&2
}
