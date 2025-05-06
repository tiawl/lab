#! /usr/bin/env bash

image_tag_defined () { #HELP <image> <tag>\t\t\t\t\t\tSucceed if the <image>:<tag> is found. Fail otherwise
  shift

  local filters endpoint logged_endpoint method http_code
  filters="{\"reference\":{\"${1}${sep[tag]}${2}\":true}}"
  method='GET'
  endpoint="http://${version[docker_api]}/images/json?filters="
  logged_endpoint="${endpoint}${filters}"
  endpoint="${endpoint}$(urlencode "${filters}")"
  readonly filters endpoint logged_endpoint method

  printf '%s %s\n' "${method}" "${logged_endpoint//\"/\\\"}" >&2

  coproc HTTP_CODE { sed "${sed[colored_http_code]}"; }
  defer 'exec {HTTP_CODE[1]}>&-; readl http_code <&${HTTP_CODE[0]}; wait "${HTTP_CODE_PID}" 2> /dev/null || :; printf "%s\n" "${http_code}" >&2'

  {
    curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
      | gojq --exit-status '. | length > 0' > /dev/null
  } 3>&${HTTP_CODE[1]}
}
