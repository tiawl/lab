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
  ( 'cmd') if is present "$(command -v "${2}" 2> /dev/null || :)"; then return 0; else return 1; fi ;;
  ( 'array' ) if [[ "$(declare -p "${2}")" =~ 'declare -a' ]]; then return 0; else return 1; fi ;;
  esac
}

str () {
  case "${1}" in
  ( 'not' ) if not str "${2}" "${3}" "${4:-}"; then return 0; else return 1; fi ;;
  ( 'empty' )  if [ -z "${2}" ]; then return 0; else return 1; fi ;;
  ( 'in' )     case "${3}" in ( *" ${2} "* ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'starts' ) case "${2}" in ( "${3}"* ) return 0 ;; ( * ) return 1 ;; esac ;;
  esac
}
