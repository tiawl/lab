#! /usr/bin/env bash

_container_state () {
  local endpoint method
  method='GET'
  endpoint="http://${version[docker_api]}/containers/${1}/json"
  readonly endpoint method

  printf '%s %s\n' "${method}" "$(url decode "${endpoint}")" >&2

  curl --silent --fail --request "${method}" --unix-socket "${path[docker_socket]}" --write-out "%{stderr}%{scheme} %{response_code}\n" "${endpoint}"
}

container_status () {
  shift
  case "${1}" in
  ( 'get' ) container_status_get "${@}" ;;
  ( 'created' ) container_status_created "${@}" ;;
  ( 'running' ) container_status_running "${@}" ;;
  ( 'healthy' ) container_status_healthy "${@}" ;;
  ( * ) return 1 ;;
  esac
}
