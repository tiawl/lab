#! /usr/bin/env bash

container_status_get () { #HELP <container>\t\t\t\t\t\tReturn the status of the given <container>
  shift

  local http_code

  coproc HTTP_CODE { sed "${sed[colored_http_code]}"; }
  defer 'exec {HTTP_CODE[1]}>&-; readl http_code <&${HTTP_CODE[0]}; wait "${HTTP_CODE_PID}" 2> /dev/null || :; printf "%s\n" "${http_code}" >&2'

  {
    _container_state "${1}" 2>&3 | gojq --raw-output '.State.Status'
  } 3>&${HTTP_CODE[1]}
}
