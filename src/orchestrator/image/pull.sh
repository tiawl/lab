#! /usr/bin/env bash

image_pull () { #HELP <registry> <project> <image> <tag>\t\t\t\tDownload <image> from <registry>
  shift

  local endpoint method img http_code
  img="${1}${sep[image]}${2}${sep[image]}${3}${sep[tag]}${4}"
  endpoint="http://${version[docker_api]}/images/create?fromImage=${img}"
  method='POST'
  readonly endpoint method img

  printf '%s %s\n' "${method}" "${endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed --file <(printf '%s' "${sed[colored_http_code]}"); }

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --no-buffer --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq --raw-output '"image pull '"${img}"' > " + .status + (if .progress | length > 0 then " " else "" end) + .progress' >&2
  } 3>&"${HTTP_CODE[1]}"

  exec {HTTP_CODE[1]}>&-
  IFS= read -r http_code <&"${HTTP_CODE[0]}" || :
  printf '%s\n' "${http_code}" >&2
}
