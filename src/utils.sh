#! /bin/sh

not () { if ! "${@}"; then return 0; else return 1; fi; }
eq () { if [ "${1}" == "${2}" ]; then return 0; else return 1; fi; }
gt () { return "$(( ${1} > ${2} ? 0 : 1 ))"; }
lt () { return "$(( ${1} < ${2} ? 0 : 1 ))"; }
ge () { if not lt "${1}" "${2}"; then return 0; else return 1; fi; }
le () { if not gt "${1}" "${2}"; then return 0; else return 1; fi; }

can () {
  case "${1}" in
  ( 'not' ) if not can "${2}" "${3}"; then return 0; else return 1; fi ;;
  ( 'exec' ) if [ -x "${2}" ]; then return "${n:-0}"; else return "$(( 1 - ${n:-0} ))"; fi ;;
  esac
}

is () {
  case "${1}" in
  ( 'not' ) if not is "${2}" "${3}"; then return 0; else return 1; fi ;;
  ( 'present' ) if [ -e "${2}" ]; then return 0; else return 1; fi ;;
  ( 'file' ) if [ -f "${2}" ]; then return 0; else return 1; fi ;;
  ( 'dir' ) if [ -d "${2}" ]; then return 0; else return 1; fi ;;
  ( 'socket' ) if [ -S "${2}" ]; then return 0; else return 1; fi ;;
  ( 'cmd') if is present "$(command -v "${2}" 2> /dev/null || :)"; then return 0; else return 1; fi ;;
  # bash-only
  ( 'array' ) case "$(declare -p "${2}" 2> /dev/null)" in ( "declare -a ${2}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  # bash-only
  ( 'map' ) case "$(declare -p "${2}" 2> /dev/null)" in ( "declare -A ${2}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  # bash-only
  ( 'func' ) if declare -F "${2}" > /dev/null; then return 0; else return 1; fi ;;
  esac
}

str () {
  case "${1}" in
  ( 'not' ) if not str "${2}" "${3}" "${4:-}"; then return 0; else return 1; fi ;;
  ( 'empty' )  if [ -z "${2}" ]; then return 0; else return 1; fi ;;
  ( 'in' ) case "${3}" in ( *" ${2} "* ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'starts' ) case "${2}" in ( "${3}"* ) return 0 ;; ( * ) return 1 ;; esac ;;
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
    ( 'errexit'|'noclobber'|'errtrace'|'functrace'|'nounset'|'pipefail' ) shopt -o -s -q "${1}" ;;
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
    ( 'errexit'|'noclobber'|'errtrace'|'functrace'|'nounset'|'pipefail' ) shopts -o -u -q "${1}" ;;
    ( 'lastpipe'|'globstar' ) shopt -u -q "${1}" ;;
    ( * ) exit 1 ;;
    esac
    shift
  done
}

# bash-only
trap_add () {
  local stage
  stage='0'
  if is not func 'trap_exit_0'
  then
    trap -- 'trap_exit_0' EXIT
  fi
  while is func "trap_exit_$(( ++stage ))"; do :; done
  (( stage-- ))
  eval "trap_exit_${stage} () { ${*}; trap_exit_$(( stage + 1 )); }; trap_exit_$(( stage + 1 )) () { :; }"
}

# TODO: how to make it works for setup.sh ?? bash-only
global -A sep version path
sep[image]='/'
sep[tag]=':'
sep[container]='.'
version[docker_api]='v1.48'
path[docker_socket]='/var/run/docker.sock'
readonly sep
