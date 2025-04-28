#! /usr/bin/env bash

network_ip_list () { #HELP <network>\t\t\t\t\t\t\tList all ip addresses used on <network>
  shift

  local endpoint method
  endpoint="http://${version[docker_api]}/networks/${1}"
  method='GET'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  {
    {
      curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
        | gojq --raw-output '.Containers | to_entries[].value.IPv4Address | sub("/[0-9]+$"; "")' >&4
    } 3>&1 4>&5 | sed --file <(printf '%s' "${sed[colored_http_code]}") >&2
  } 5>&1
}
