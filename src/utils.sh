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

global () {
  if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
  declare -g "${@}"
}

on () {
  if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
  while gt "${#}" 0
  do
    case "${1}" in
    ( 'errexit'|'noclobber'|'nounset'|'pipefail' ) shopt -o -s -q "${1}" ;;
    ( 'lastpipe'|'globstar' ) shopt -s -q "${1}" ;;
    ( * ) exit 1 ;;
    esac
    shift
  done
}

off () {
  if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
  while gt "${#}" 0
  do
    case "${1}" in
    ( 'errexit'|'noclobber'|'nounset'|'pipefail' ) shopt -o -u -q "${1}" ;;
    ( 'lastpipe'|'globstar' ) shopt -u -q "${1}" ;;
    ( * ) exit 1 ;;
    esac
    shift
  done
}

defer () {
  if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
  local stage fn prev_trap
  stage='0'
  fn="${FUNCNAME[*]}"
  fn="${fn// /_}"
  if is not func "__${fn}_0"
  then
    prev_trap="$(trap -p RETURN)"
    trap -- "if str not eq \"\${FUNCNAME[0]}\" \"${FUNCNAME[0]}\"; then __${fn}_0; ${prev_trap:-trap - RETURN}; fi" RETURN
  fi
  while is func "__${fn}_$(( ++stage ))"; do :; done
  (( stage-- ))
  eval "__${fn}_${stage} () { ${*}; __${fn}_$(( stage + 1 )); unset \"\${FUNCNAME[0]}\"; }; __${fn}_$(( stage + 1 )) () { unset \"\${FUNCNAME[0]}\"; }; declare -t -f __${fn}_${stage} __${fn}_$(( stage + 1 ))"
}

# 1) fail if no external tool exists with the specified name
# 2) wrap the external tool as a function
harden () {
  if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
  local old_ifs dir flag
  old_ifs="${IFS}"
  readonly old_ifs

  IFS=':'
  set -f
  for dir in ${PATH}
  do
    if can exec "${dir}/${1}"
    then
      eval "${1//-/_} () { ${dir}/${1} \"\${@}\"; }"
      flag='true'
      break
    fi
  done
  set +f
  IFS="${old_ifs}"

  if str not eq "${flag:-}" 'true'
  then
    printf 'This script needs "%s" but can not find it\n' "${1}" >&2
    return 1
  fi
}

shuffle () {
  if str not eq "$(basename "${BASH:-unknown}")" 'bash'; then return 1; fi
  local i array_i size max rand
  local -n array
  array="${1}"
  size="${#array[*]}"
  max="$(( 32768 / size * size ))"
  i="$(( size - 1 ))"

  while gt "${i}" '0'
  do
    while ge "$(( rand=${RANDOM} ))" "${max}"; do :; done
    rand="$(( rand % (i+1) ))"
    array_i="${array[i]}"
    array[i]="${array[rand]}"
    array[rand]="${array_i}"
    (( i-- ))
  done
}

bash_setup () {
  if str eq "$(basename "${BASH:-unknown}")" 'bash'
  then
    global -A sep version path
    sep[image]='/'
    sep[tag]=':'
    sep[container]='.'
    version[docker_api]='v1.48'
    path[docker_socket]='/var/run/docker.sock'
    readonly sep
  fi
}
