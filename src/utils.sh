#! /bin/sh

not () { ! "${@}"; }
eq () { (( "${1}" == "${2}" )); }
gt () { (( "${1}" > "${2}" )); }
lt () { (( "${1}" < "${2}" )); }
ge () { not lt "${1}" "${2}"; }
le () { not gt "${1}" "${2}"; }

can () {
  case "${1}" in
  ( 'not' ) shift; not can "${@}" ;;
  ( 'exec' ) [ -x "${2}" ] ;;
  esac
}

is () {
  case "${1}" in
  ( 'not' ) shift; not is "${@}" ;;
  ( 'present' ) [ -e "${2}" ] ;;
  ( 'file' ) [ -f "${2}" ] ;;
  ( 'dir' ) [ -d "${2}" ] ;;
  ( 'socket' ) [ -S "${2}" ] ;;
  ( 'cmd') is present "$(command -v "${2}" 2> /dev/null || :)" ;;
  # bash-only
  ( 'array' ) case "$(declare -p "${2}" 2> /dev/null)" in ( "declare -a ${2}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  # bash-only
  ( 'map' ) case "$(declare -p "${2}" 2> /dev/null)" in ( "declare -A ${2}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  # bash-only
  ( 'func' ) declare -F "${2}" > /dev/null ;;
  esac
}

str () {
  case "${1}" in
  ( 'not' ) shift; not str "${@}" ;;
  ( 'empty' ) [ -z "${2}" ] ;;
  ( 'eq' ) [ "${2}" == "${3}" ] ;;
  ( 'in' ) case "${3}" in ( *" ${2} "* ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'starts' ) case "${2}" in ( "${3}"* ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'ends' ) case "${2}" in ( *"${3}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  esac
}

# bash-only
global () {
  declare -g "${@}"
}

# bash-only
on () {
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

# bash-only
off () {
  while gt "${#}" 0
  do
    case "${1}" in
    ( 'errexit'|'noclobber'|'nounset'|'pipefail' ) shopts -o -u -q "${1}" ;;
    ( 'lastpipe'|'globstar' ) shopt -u -q "${1}" ;;
    ( * ) exit 1 ;;
    esac
    shift
  done
}

# bash-only
defer () {
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

# TODO: how to make it works for setup.sh ?? bash-only
global -A sep version path
sep[image]='/'
sep[tag]=':'
sep[container]='.'
version[docker_api]='v1.48'
path[docker_socket]='/var/run/docker.sock'
readonly sep
