#! /usr/bin/env bash

network_ip_get () {
  shift

  local endpoint method
  endpoint="http://${version[docker_api]}/containers/${1}/json"
  method='GET'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  {
    {
      curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out '%{stderr}%{scheme} %{response_code}\n' "${endpoint}" 2>&3 \
        | gojq --raw-output '.NetworkSettings.Networks[$net].IPAddress' --arg net "${2:-bridge}" >&4
    } 3>&1 4>&5 | sed --file <(printf '%s' "${sed[colored_http_code]}") >&2
  } 5>&1
}
