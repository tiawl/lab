#! /usr/bin/env bash

image_list () {
  shift

  local filters endpoint logged_endpoint method
  filters="{\"reference\":{\"${1}\":true}}"
  method='GET'
  endpoint="http://${version[docker_api]}/images/json?filters="
  logged_endpoint="${endpoint}${filters}"
  endpoint="${endpoint}$(urlencode "${filters}")"
  readonly filters endpoint logged_endpoint method

  printf '%s %s\n' "${method}" "${logged_endpoint//\"/\\\"}" >&2

  {
    {
      curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}" 2>&3 \
        | gojq --raw-output '.[].RepoTags[]' >&4
    } 3>&1 4>&5 | sed --file "${sdir}/sed/colored_http_code.sed" >&2
  } 5>&1
}
