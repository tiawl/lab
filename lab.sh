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

  old_ifs="${IFS}"
  readonly old_ifs

  IFS=$'\n'

  ## shell scripting: always consider the worst env
  ## part 2: remove already defined functions
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

  ## cleanup done: now it is time to define needed functions

  harden () {
    local dir

    IFS=':'
    for dir in ${PATH}
    do
      if [ -x "${dir}/${1}" ]
      then
        eval "${1} () { ${dir}/${1} \"\${@}\"; }"
        flag='true'
        break
      fi
    done
    IFS="${old_ifs}"

    if [ "${flag:-}" != 'true' ]
    then
      printf 'This script needs "%s" but can not find it\n' "${1}" >&2
      return 1
    fi
    unset flag
  }

  harden curl
  harden ssh

  req () {
    assert_ge "${#}" '2'
    assert_starts_with "${2:-}" '/'

    local socket_path method endpoint
    socket_path='/var/run/docker.sock'
    method="${1:-}"
    endpoint="http://v1.48${2}"
    readonly socket_path method endpoint
    shift 2

    case "${method:-}" in
    ( 'get' ) curl -s --unix-socket "${socket_path}" -X GET "${@}" "${endpoint}" ;;
    ( 'post' ) curl -s --unix-socket "${socket_path}" -X POST "${@}" "${endpoint}" ;;
    ( 'del' ) curl -s --unix-socket "${socket_path}" -X DELETE "${@}" "${endpoint}" ;;
    ( * ) return 1 ;;
    esac
  }

  container () {
    case "${1:-}" in
    ( 'create' ) printf 'TODO\n' ;;
    ( 'start' ) printf 'TODO\n' ;;
    ( 'stop' ) printf 'TODO\n' ;;
    ( 'remove' ) printf 'TODO\n' ;;
    ( 'up' ) printf 'TODO\n' ;;
    ( 'down' ) printf 'TODO\n' ;;
    ( * ) return 1 ;;
    esac
  }

  image () {
    case "${1:-}" in
    ( 'build' ) printf 'TODO\n' ;;
    ( 'pull' ) printf 'TODO\n' ;;
    ( 'tag' ) printf 'TODO\n' ;;
    ( 'remove' ) printf 'TODO\n' ;;
    ( * ) return 1 ;;
    esac
  }

  network () {
    case "${1:-}" in
    ( 'create' ) printf 'TODO\n' ;;
    ( 'remove' ) printf 'TODO\n' ;;
    ( * ) return 1 ;;
    esac
  }

  volume () {
    case "${1:-}" in
    ( 'create' ) printf 'TODO\n' ;;
    ( 'remove' ) printf 'TODO\n' ;;
    ( * ) return 1 ;;
    esac
  }
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
# curl -s --data-binary @- --header 'Content-Type: application/x-tar' --no-buffer --unix-socket /var/run/docker.sock -X POST http://v1.45/build?dockerfile=Dockerfile&t=reg/proj/my-img:my-tag < context.tar
