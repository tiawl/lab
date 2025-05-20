#! /usr/bin/env bash

not () { ! "${@}"; }
eq () { (( "${1}" == "${2}" )); }
gt () { (( "${1}" > "${2}" )); }
lt () { (( "${1}" < "${2}" )); }
ge () { (( "${1}" >= "${2}" )); }
le () { (( "${1}" <= "${2}" )); }

can () {
  case "${1}" in
  ( 'not' ) shift; not can "${@}" ;;
  ( 'exec' ) [[ -x "${2}" ]] ;;
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

  if str not empty "${1##*/*}"
  then
    set -- '.'
  fi

  set -- "${1%/*}"
  set -- "${1%%"${1##*[!/]}"}"
  printf '%s\n' "${1:-/}"
}

is () {
  case "${1}" in
  ( 'not' ) shift; not is "${@}" ;;
  ( 'present' ) [[ -e "${2}" ]] ;;
  ( 'file' ) [[ -f "${2}" ]] ;;
  ( 'dir' ) [[ -d "${2}" ]] ;;
  ( 'socket' ) [[ -S "${2}" ]] ;;
  ( 'array' ) case "$(declare -p "${2}" 2> /dev/null)" in ( "declare -a ${2}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'map' ) case "$(declare -p "${2}" 2> /dev/null)" in ( "declare -A ${2}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'func' ) declare -F "${2}" > /dev/null ;;
  ( 'var' ) [[ -v "${2}" ]] ;;
  ( 'set' ) [[ -o "${2}" ]] || shopt -q "${2}" 2> /dev/null ;;
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
  ( 'empty' ) [[ -z "${2}" ]] ;;
  ( 'eq' ) [[ "${2}" == "${3}" ]] ;;
  ( 'in' ) case "${3}" in ( *" ${2} "* ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'starts' ) case "${2}" in ( "${3}"* ) return 0 ;; ( * ) return 1 ;; esac ;;
  ( 'ends' ) case "${2}" in ( *"${3}" ) return 0 ;; ( * ) return 1 ;; esac ;;
  esac
}

readl () {
  IFS= read -r "${@}" || eq "${?}" 1
}

error () {
  printf "${1}"$'\n' "${@:2}" >&2
  return 1
}

global () {
  declare -g "${@}"
}

on () {
  while gt "${#}" 0
  do
    if not set -o "${1}" 2> /dev/null
    then
      compgen -A shopt -X \!"${1}" "${1}" > /dev/null
      shopt -s -q "${1}"
    fi
    shift
  done
}

off () {
  while gt "${#}" 0
  do
    if not set +o "${1}" 2> /dev/null
    then
      compgen -A shopt -X \!"${1}" "${1}" > /dev/null
      shopt -u -q "${1}"
    fi
    shift
  done
}

source () {
  case "${-}" in
  ( *T* ) trap -- "$(trap -p RETURN)" RETURN ;;
  esac
  . "${@}"
}

capture () {
  set -- "$(shopt -p)"
  source /proc/self/fd/0 <<< "restore () {
    ${1//$'\n'/; }
    set -- \"${-}\"
    while gt \"\${#1}\" 0
    do
      set -\"\${1%\"\${1#?}\"}\" 2> /dev/null || :
      set -- \"\${1#?}\"
    done
    unset -f \"\${FUNCNAME[0]}\"
  }"
}

defer () {
  local stage prev_return_trap prev_err_trap pfx
  stage='0'
  pfx="__${FUNCNAME[0]#s}_${FUNCNAME[1]}_"
  if is not func "${pfx}0"
  then
    prev_return_trap="$(trap -p RETURN)"
    trap -- "if str eq \"\${FUNCNAME[0]}\" \"${FUNCNAME[1]}\"; then ${pfx}0; ${prev_return_trap:-trap - RETURN}; ${prev_err_trap:-trap - ERR}; fi" RETURN
    prev_err_trap="$(trap -p ERR)"
    trap -- "${pfx}0; ${prev_return_trap:-trap - RETURN}; ${prev_err_trap:-trap - ERR}" ERR
  fi
  while is func "${pfx}$(( ++stage ))"; do :; done
  (( stage-- ))
  source /proc/self/fd/0 <<< "${pfx}${stage} () { ${*}; ${pfx}$(( stage + 1 )); unset \"\${FUNCNAME[0]}\"; }; ${pfx}$(( stage + 1 )) () { unset \"\${FUNCNAME[0]}\"; }; declare -t -f ${pfx}${stage} ${pfx}$(( stage + 1 ))"
}

# sdefer definition:
set -- "$(declare -f defer)" "${@}"
source /proc/self/fd/0 <<< "s${1/'${*}'/'(${*})'}"
shift

# 1) fail if no external tool exists with the specified name
# 2) wrap the external tool as a function
harden () {
  local hardened alias reserved char cmd
  alias="${2:-"${1}"}"
  reserved="$(compgen -A keyword -A builtin)"
  char='|'
  readonly alias reserved char

  case "${char}${reserved//$'\n'/"${char}"}${char}" in
  ( "${char}${alias}${char}" ) error 'You can not harden or alias an Bash keyword or builtin' ;;
  ( * ) : ;;
  esac

  if type -P "${1}" > /dev/null
  then
    cmd="$(type -P "${1}")"
    if can exec "${cmd}"
    then
      source /proc/self/fd/0 <<< "${alias} () { ${cmd} \"\${@}\"; }"
    else
      error 'This script needs "%s" but can not find it' "${1}"
    fi
  else
    error 'This script needs "%s" but can not find it' "${1}"
  fi

  hardened="$(if is func hardened; then hardened; fi)"
  readonly hardened
  source /proc/self/fd/0 <<< "hardened () {
    printf \"%s\n\" ${hardened:+"'"}${hardened//$'\n'/"' '"}${hardened:+"'"} '${2:-"${1//-/_}"}'
  }"
}

shuffle () {
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
  global -A sep version path
  sep[image]='/'
  sep[tag]=':'
  sep[container]='.'
  version[docker_api]='v1.49'
  path[docker_socket]='/var/run/docker.sock'
  readonly sep
}

url () {
  case "${1}" in
  ( encode )
    local LC_ALL=C
    local i reply encoded
    for (( i = 0; i < ${#2}; i++ ))
    do
      : "${2:i:1}"
      case "${_}" in
      ( [a-zA-Z0-9.~_-] ) printf -v reply '%c' "${_}" ;;
      ( * ) printf -v reply '%%%02X' "'${_}" ;;
      esac
      encoded="${encoded:-}${reply}"
    done
    printf '%s\n' "${encoded}" ;;
  ( decode )
    : "${2//+/ }"
    printf '%b\n' "${_//%/\\x}" ;;
  esac
}
