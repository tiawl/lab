#! /usr/bin/env bash

container_resource_copy () { #HELP <container_name> <container_path> <host_path>\t\t\tCopy files/folders from a container to the local filesystem
  shift

  local endpoint method http_code
  endpoint="http://${version[docker_api]}/containers/${1}/archive?path=${2}"
  method='GET'
  readonly endpoint method

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed --file <(printf '%s' "${sed[colored_http_code]}"); }

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --output - --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | tar --extract --directory "${3}"
  } 3>&"${HTTP_CODE[1]}"

  exec {HTTP_CODE[1]}>&-
  readl http_code <&"${HTTP_CODE[0]}"
  printf '%s\n' "${http_code}" >&2
}
