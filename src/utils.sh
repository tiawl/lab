#! /bin/sh

not () { ! "${@}"; }
eq () { (( "${1}" == "${2}" )); }
gt () { (( "${1}" > "${2}" )); }
lt () { (( "${1}" < "${2}" )); }
ge () { (( "${1}" >= "${2}" )); }
le () { (( "${1}" <= "${2}" )); }

can () {
  case "${1}" in
  ( 'not' ) shift; not can "${@}" ;;
  ( 'exec' ) [ -x "${2}" ] ;;
  esac
}

basename () {
  set -- "${1%"${1##*[!/]}"}" "${2:-}"
  set -- "${1##*/}" "${2:-}"
  set -- "${1%"${2:-}"}"
  printf '%s\n' "${1:-/}"
}

dirname () {
  set -- "${1:-.}"
  set -- "${1%%"${1##*[!/]}"}"

  [ "${1##*/*}" ] && set -- '.'

  set -- "${1%/*}"
  set -- "${1%%"${1##*[!/]}"}"
  printf '%s\n' "${1:-/}"
}

is () {
  case "${1}" in
  ( 'not' ) shift; not is "${@}" ;;
  ( 'present' ) [ -e "${2}" ] ;;
  ( 'file' ) [ -f "${2}" ] ;;
  ( 'dir' ) [ -d "${2}" ] ;;
  ( 'socket' ) [ -S "${2}" ] ;;
  ( 'array' )
    if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
    case "$(declare -p "${2}" 2> /dev/null)" in ( "declare -a ${2}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'map' )
    if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
    case "$(declare -p "${2}" 2> /dev/null)" in ( "declare -A ${2}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'func' )
    if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
    declare -F "${2}" > /dev/null ;;
  esac
}

has () {
  case "${1}" in
  ( 'not' ) shift; not has "${@}" ;;
  ( * ) can exec "$(command -v "${1}" 2> /dev/null || :)" ;;
  esac
}

str () {
  case "${1}" in
  ( 'not' ) shift; not str "${@}" ;;
  ( 'empty' ) [ -z "${2}" ] ;;
  ( 'eq' ) [ "${2}" = "${3}" ] ;;
  ( 'in' ) case "${3}" in ( *" ${2} "* ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'starts' ) case "${2}" in ( "${3}"* ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'ends' ) case "${2}" in ( *"${3}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  esac
}

readl () {
  IFS= read -r "${@}" || eq "${?}" 1
}
