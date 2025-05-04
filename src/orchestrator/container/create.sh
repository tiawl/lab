#! /usr/bin/env bash

container_create () { #HELP <container_name> <image> <container_hostname>\t\tCreate a new container from <image>
  shift

  local json endpoint logged_endpoint method img http_code
  img="${2}"
  json="{\"Hostname\":\"${3}\",\"Image\":\"${img}${sep[tag]}$(image tag list "${img}")\"}"
  endpoint="http://${version[docker_api]}/containers/create?name=${1}"
  logged_endpoint="${endpoint}&$(gojq --null-input --raw-output '['"${json}"' | to_entries[] | .key + "=" + .value] | join("&")')"
  method='POST'
  readonly json endpoint logged_endpoint method img

  printf '%s %s\n' "${method}" "${logged_endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed --file <(printf '%s' "${sed[colored_http_code]}"); }

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --header 'Content-Type: application/json' --data "${json}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq '.' >&2
  } 3>&"${HTTP_CODE[1]}"

  exec {HTTP_CODE[1]}>&-
  readl http_code <&"${HTTP_CODE[0]}"
  printf '%s\n' "${http_code}" >&2
}
