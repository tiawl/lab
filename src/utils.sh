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
  ( 'uint' ) case "${2}" in ( ''|*[!0-9]* ) return 1 ;; ( * ) return 0 ;; esac ;;
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

read_http_code () {
  IFS= read -r http_code || eq "${?}" 1
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

capture () {
  set -- "$(shopt -p)"
  eval "restore () {
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

trim () {
  local -n ref="${1}"
  ref="${ref%"${ref##*[![:space:]]}"}"
  ref="${ref#"${ref%%[![:space:]]*}"}"
}

defer () {
  local opt
  for opt in errexit errtrace functrace
  do
    if is not set "${opt}"
    then
      error '%s bash option must be enabled to use defer: %s' "${opt}" "${-}"
    fi
  done

  local stage pfx ppfx c old_ifs prev_return_trap prev_err_trap caller_id min max x fn_prev_return_trap fn_prev_err_trap fn_prev_return_trap_def fn_prev_err_trap_def prev_err_trap_arg
  local -a caller
  old_ifs="${IFS}"
  stage='0'
  c='_'
  prev_return_trap="$(trap -p RETURN)"
  prev_return_trap="${prev_return_trap#"trap -- '' RETURN"}"
  readonly old_ifs c prev_return_trap

  caller=("${BASH_LINENO[@]:2}" "${FUNCNAME[@]:1}")
  min='0'
  max="$(( ${#caller[@]} -1 ))"
  while lt "${min}" "${max}"
  do
    x="${caller["${min}"]}"
    caller["${min}"]="${caller["${max}"]}"
    caller["${max}"]="${x}"
    (( min++, max-- ))
  done
  ppfx="${c}${c}deferred${c}"
  IFS="${c}"
  caller_id="${caller[*]}"
  IFS="${old_ifs}"
  pfx="${ppfx}${caller_id}${c}"
  fn_prev_return_trap="${c}${c}restore${c}previous${c}return${c}trap${c}${caller_id}"
  fn_prev_err_trap="${c}${c}restore${c}previous${c}err${c}trap${c}${caller_id}"
  readonly pfx ppfx caller caller_id fn_prev_return_trap fn_prev_err_trap

  if is not func "${pfx}0"
  then
    prev_err_trap="$(trap -p ERR)"
    prev_err_trap="${prev_err_trap#"trap -- '' ERR"}"
    prev_err_trap_arg="${prev_err_trap%"' ERR"}"
    prev_err_trap_arg="${prev_err_trap_arg#"trap -- '"}"
    fn_prev_return_trap_def="${fn_prev_return_trap} () {
      ${prev_return_trap:-trap - RETURN}
    }"
    fn_prev_err_trap_def="${fn_prev_err_trap} () {
      ${prev_err_trap:-trap - ERR}
    }"
    readonly prev_err_trap prev_err_trap_arg fn_prev_return_trap_def fn_prev_err_trap_def
    trap -- "
      if str eq \"\${FUNCNAME[*]}\" \"${FUNCNAME[*]:1}\"
      then
        ${pfx}0 RETURN
        ${fn_prev_return_trap}
        ${fn_prev_err_trap}
        unset -f ${fn_prev_return_trap} ${fn_prev_err_trap}
      fi
    " RETURN
    trap -- "
      ${pfx}0 ERR
      unset -f ${fn_prev_return_trap} ${fn_prev_err_trap}
      ${prev_err_trap_arg}
    " ERR
  fi
  while is func "${pfx}$(( ++stage ))"; do :; done
  (( stage-- ))
  eval "
    ${pfx}${stage} () {
      $(
        if is not func "${pfx}0"
        then
          printf '%s\n%s' "${fn_prev_return_trap_def}" "${fn_prev_err_trap_def}"
        fi
      )
      local before after restore_err_trap
      on noglob
      before=(\$(compgen -A function -X '!${ppfx}*0'))
      off noglob
      if str eq \"\${1}\" RETURN
      then
        restore_err_trap=\"\$(trap -p ERR)\"
        ${fn_prev_err_trap}
      fi
      if ! { ${*}; }
      then
        false
      fi
      if str eq \"\${1}\" RETURN
      then
        eval \"\${restore_err_trap}\"
      fi
      on noglob
      after=(\$(compgen -A function -X '!${ppfx}*0'))
      off noglob
      if str not eq \"\${before[*]}\" \"\${after[*]}\"
      then
        local deferred
        for deferred in \$(gojq -n -r '\$ARGS.positional | group_by(.) | .[] | select(length == 1) | .[0]' --args \"\${before[@]}\" \"\${after[@]}\")
        do
          \${deferred} \"\${1}\"
        done
      fi
      ${pfx}$(( stage + 1 )) \"\${1}\"
      unset -f \"\${FUNCNAME[0]}\"
    }
    ${pfx}$(( stage + 1 )) () {
      unset -f \"\${FUNCNAME[0]}\"
    }
  "
}

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
      eval "${alias} () { ${cmd} \"\${@}\"; }"
    else
      error 'This script needs "%s" but can not find it' "${1}"
    fi
  else
    error 'This script needs "%s" but can not find it' "${1}"
  fi

  hardened="$(if is func hardened; then hardened; fi)"
  readonly hardened
  eval "hardened () {
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

nchar () {
  local -n ref="${1}"
  if not eq "${#2}" '1'
  then
    error 'Second argument must be a lonely char'
  fi
  : "${ref//[^"${2}"]}"
  printf -v "${!ref}" '%d' "${#_}"
}

gengetopt () {
  local reset_ifs c short short_noarg short_1arg long_1arg_pattern opts
  local -a opt long long_1arg
  c=':'
  readonly c
  reset_ifs="${IFS}"
  until eq "${#}" '0'
  do
    local ncolon="${1}"
    nchar ncolon "${c}"
    if not eq "${ncolon}" '2'
    then
      error 'Each argument must match this pattern: "short-form%clong-form%cnb-args"' "${c}" "${c}"
    fi
    on noglob
    IFS="${c}"
    opt=( ${1} )
    IFS="${reset_ifs}"
    off noglob
    shift
    if gt "${#opt[0]}" '1'
    then
      error 'short-form must be a lonely char or omitted'
    fi
    if eq "${#opt[1]}" '1'
    then
      error 'long-form must be a string of at least 2 chars or omitted'
    fi
    if str empty "${opt[0]}" && str empty "${opt[1]}"
    then
      error 'You can not omit neither short-form and long-form'
    fi
    if is not uint "${opt[2]}"
    then
      error 'nb-args must be an unsigned integer'
    fi
    case "${opt[0]}${opt[1]}" in
    ( *[[:space:]]* ) error 'Space chars forbidden into short-form and long-form' ;;
    esac
    if str not empty "${opt[0]}"
    then
      case "${short}" in
      ( *"${opt[0]}"* ) error '"%s" short-form is already used' "${opt[0]}" ;;
      esac
    fi
    if str not empty "${opt[1]}"
    then
      IFS=' '
      case " ${long[*]} " in
      ( *" ${opt[1]} "* ) error '"%s" long-form is already used' "${opt[1]}" ;;
      esac
      IFS="${reset_ifs}"
    fi
    if str not empty "${opt[0]}"; then short="${short:-}${opt[0]}"; fi
    if str not empty "${opt[1]}"; then long+=( "${opt[1]}" ); fi
    case "${opt[2]}" in
    ( '0' )
      if str not empty "${opt[0]}"; then short_noarg="${short_noarg:-}${opt[0]}"; fi ;;
    ( '1' )
      if str not empty "${opt[0]}"; then short_1arg="${short_1arg:-}${opt[0]}"; fi
      if str not empty "${opt[1]}"; then long_1arg+=( "--${opt[1]}=*" ); fi ;;
    esac
    opts="${opts}${opts:+        }( ${opt[0]:+-}${opt[0]}${opt[0]:+"${opt[1]:+|}"}${opt[1]:+--}${opt[1]} )${opt[0]:+" getopt['${opt[0]}']='true';"}${opt[1]:+" getopt['${opt[1]}']='true';"} shift ${opt[2]} ;;"$'\n'
  done
  IFS='|'
  long_1arg_pattern="${long_1arg[*]}"
  IFS="${reset_ifs}"
  eval "
    getopt () {
      unset -v getopt
      global -A getopt
      until eq \"\${#}\" '0'
      do
        case \"\${1}\" in${short_noarg:+"
        # Handle '-abc' the same as '-a -bc' for short-form no-arg options
        ( -[${short_noarg}]?* ) set -- \"\${1%\"\${1#??}\"}\" \"-\${1#??}\" \"\${@:2}\"; continue ;;"$'\n'}${short_1arg:+"
        # Handle '-foo' the same as '-f oo' for short-form 1-arg options
        ( -[${short_1arg}]?* ) set -- \"\${1%\"\${1#??}\"}\" \"\${1#??}\" \"\${@:2}\"; continue ;;"$'\n'}${long_1arg_pattern:+"
        # Handle '--file=file1' the same as '--file file1' for long-form 1-arg options
        ( ${long_1arg_pattern} ) set -- \"\${1%%=*}\" \"\${1#*=}\" \"\${@:2}\"; continue ;;"$'\n'}
        ${opts}
        ( * ) error 'Unknown option: \"%s\"' \"\${1}\" ;;
        esac
        shift
      done
      unset -f \"\${FUNCNAME[0]}\"
    }
  "
}
