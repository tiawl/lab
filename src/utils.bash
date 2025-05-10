#! /usr/bin/env bash

. "${sdir:-"${SDIR}"}/src/utils.sh" #SKIP

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
  local stage prev_return_trap pfx
  stage='0'
  pfx="__${FUNCNAME[0]#s}_${FUNCNAME[1]}_"
  if is not func "${pfx}0"
  then
    prev_return_trap="$(trap -p RETURN)"
    trap -- "if str eq \"\${FUNCNAME[0]}\" \"${FUNCNAME[1]}\"; then ${pfx}0; ${prev_return_trap:-trap - RETURN ERR}${prev_return_trap:+ ERR}; fi" RETURN
    trap -- "if str eq \"\${FUNCNAME[0]}\" \"${FUNCNAME[1]}\"; then ${pfx}0; fi" ERR
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
  local old_ifs dir flag hardened alias reserved char
  old_ifs="${IFS}"
  alias="${2:-"${1}"}"
  reserved="$(compgen -A keyword -A builtin)"
  char='|'
  readonly old_ifs alias reserved char

  case "${char}${reserved//$'\n'/"${char}"}${char}" in
  ( "${char}${alias}${char}" )
    printf 'You can not harden or alias an Bash keyword or builtin\n' >&2
    return 1 ;;
  ( * ) : ;;
  esac

  IFS=':'
  set -f
  for dir in ${PATH}
  do
    if can exec "${dir}/${1}"
    then
      source /proc/self/fd/0 <<< "${alias} () { ${dir}/${1} \"\${@}\"; }"
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
  version[docker_api]='v1.48'
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
