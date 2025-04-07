#! /usr/bin/env bash

main () {
  # shell scripting: always consider the worst env
  # part 1: unalias everything
  \command set -Ceu
  \command unalias -a
  \command unset -f command
  command unset -f unset
  unset -f set
  unset -f readonly
  unset -f local
  unset -f readonly

  old_ifs="${IFS}"
  readonly old_ifs

  IFS=$'\n'

  # shell scripting: always consider the worst env
  # part 2: remove already defined functions
  local func
  for func in $(set)
  do
    func="${func#"${func%%[![:space:]]*}"}"
    func="${func%"${func##*[![:space:]]}"}"
    case "${func}" in
    ( *' ()' ) unset -f "${func%' ()'}" ;;
    ( * ) ;;
    esac
  done
  IFS="${old_ifs}"

  # cleanup done: now it is time to define needed functions

  shopt -s expand_aliases
  not () { if ! ${@}; then return 0; else return 1; fi; }
  eq () { if [[ "${1}" == "${2}" ]]; then return 0; else return 1; fi; }
  gt () { return "$(( ${1} > ${2} ? 0 : 1 ))"; }
  lt () { return "$(( ${1} < ${2} ? 0 : 1 ))"; }
  ge () { if not lt "${1}" "${2}"; then return 0; else return 1; fi; }
  le () { if not gt "${1}" "${2}"; then return 0; else return 1; fi; }

  can () {
    local n
    if eq "${1}" 'not'; then n=1; shift; fi
    readonly n
    case "${1}" in
    ( exec ) if [[ -x "${2}" ]]; then return "${n:-0}"; else return "$(( 1 - ${n:-0} ))"; fi ;;
    esac
  }

  str () {
    case "${1}" in
    ( empty )  if [[ -z "${2}" ]]; then return 0; else return 1; fi ;;
    ( in )     case "${3}" in ( *" ${2} "* ) return 0 ;; ( * ) return 1 ;; esac ;;
    ( starts ) case "${2}" in ( "${3}"* ) return 0 ;; ( * ) return 1 ;; esac ;;
    esac
  }

  # 1) fail if no external tool exists with the specified name
  # 2) wrap the external tool as a function
  harden () {
    local dir flag

    IFS=':'
    for dir in ${PATH}
    do
      if can exec "${dir}/${1}"
      then
        eval "${1} () { ${dir}/${1} \"\${@}\"; }"
        flag='true'
        break
      fi
    done
    IFS="${old_ifs}"

    if not eq "${flag:-}" 'true'
    then
      printf 'This script needs "%s" but can not find it\n' "${1}" >&2
      return 1
    fi
  }

  harden curl
  harden id
  harden mktemp
  harden ssh
  harden tar

  tmp="$(mktemp --directory '/tmp/tmp.XXXXXXXX')"
  uid="$(id -u)"
  version='0.1.0'
  readonly tmp uid version

  req () {
    str starts "${2}" '/'

    local socket_path method endpoint
    socket_path='/var/run/docker.sock'
    method="${1}"
    endpoint="http://v1.48${2}"
    readonly socket_path method endpoint
    shift 2

    case "${method}" in
    ( 'get' ) curl -s --unix-socket "${socket_path}" -X GET "${@}" "${endpoint}" ;;
    ( 'post' ) curl -s --unix-socket "${socket_path}" -X POST "${@}" "${endpoint}" ;;
    ( 'del' ) curl -s --unix-socket "${socket_path}" -X DELETE "${@}" "${endpoint}" ;;
    ( * ) return 1 ;;
    esac
  }

  container () {
    case "${1}" in
    ( 'create' ) printf 'TODO\n' ;;
    ( 'start' ) printf 'TODO\n' ;;
    ( 'stop' ) : ;;
    ( 'remove' ) : ;;
    ( 'up' ) printf 'TODO\n' ;;
    ( 'down' ) : ;;
    ( 'running' ) : ;;
    ( * ) return 1 ;;
    esac
  }

  network () {
    case "${1}" in
    ( 'create' ) : ;;
    ( 'remove' ) : ;;
    ( * ) return 1 ;;
    esac
  }

  volume () {
    case "${1}" in
    ( 'create' ) : ;;
    ( 'remove' ) : ;;
    ( * ) return 1 ;;
    esac
  }

  # define a new function for each external tool: allow to standardize external tools for an expensive speed loss
  containerize () {
    # cwd: mount to define the current working directory of the tool
    # match & match2: mounts to define identical absolute path between host and container
    eval "${1} () {
      container up \${cwd:+\"--volume\"} \${cwd:+\"\${cwd}:/home/nobody/\"} \
        \${match:+\"--volume\"} \${match:+\"\${match}:\${match}\"} \
        \${match2:+\"--volume\"} \${match2:+\"\${match2}:\${match2}\"} \
        --rm --interactive 'lab/oneshot' ${1} \"\${@}\"
      unset cwd match match2
    }"
  }

  image () {
    case "${1}" in
    ( 'build' )
      tar -c -f "${tmp}/context.tar" "./dockerfiles/${1}"
      req post "/build?dockerfile=./dockerfiles/${1}/Dockerfile&t=lab/${1}:${version}" --data-binary @- --header 'Content-Type: application/x-tar' --no-buffer < "${tmp}/context.tar"
      rm -rf "${tmp}" ;;
    ( 'pull' ) printf 'TODO\n' ;;
    ( 'tag' ) printf 'TODO\n' ;;
    ( 'remove' ) : ;;
    ( 'tagged' ) : ;;
    ( * ) return 1 ;;
    esac
  }

  image pull "alpine:3.21"
  image tag "alpine:3.21" "local.alpine:${version}"
  image build oneshot
}

main "${@}"

# ----------------------------------------------------------------------------
# MEMO: tests with curl
# ----------------------------------------------------------------------------
#
# regular:
# curl -s --unix-socket /var/run/docker.sock -X DELETE http://v1.45/containers/hardcore_jang?force=true
#
# filters/urlencode:
# curl -s --unix-socket /var/run/docker.sock 'http://1.45/images/json' -X GET -G --data-urlencode 'filters={"reference":{"172.17.2.3:5000/mywhalefleet/tiawl.local.*":true}}'
#
# attach:
# curl -s -N -T - -X POST --unix-socket ./docker.sock 'http://1.45/containers/aaebdff75c380b80556b9c2ce65b2c62ba4cdd59427d3f269d5a61d7b8a087b0/attach?stdout=1&stdin=1&stderr=1&stream=1' -H 'Upgrade: tcp' -H 'Connection: Upgrade'
#
# build:
# tar c -f context.tar -C /tmp .
# curl -s --unix-socket /var/run/docker.sock -X POST --data-binary @- --header 'Content-Type: application/x-tar' --no-buffer http://v1.45/build?dockerfile=Dockerfile&t=reg/proj/my-img:my-tag < context.tar
