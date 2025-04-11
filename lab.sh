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
  not () { set -f; if ! ${@}; then set +f; return 0; else set +f; return 1; fi; }
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

  harden base64
  harden curl
  harden id
  harden jq
  harden mktemp
  harden protoc
  harden sed
  harden shuf
  harden ssh
  harden tar

  req_id='0'
  rainbow="$(printf '%s\n' '21' '27' '33' '39' '45' '51' '50' '49' '48' '47' '46' '82' '118' '154' '190' '226' '220' '214' '208' '202' '196' '197' '198' '199' '200' '201' '165' '129' '93' '57' | shuf)"
  tmp="$(mktemp --directory '/tmp/tmp.XXXXXXXX')"
  uid="$(id -u)"
  version='0.1.0'
  readonly tmp uid version

  color () {
    set -- ${rainbow}
    local n
    n="$(( (req_id % 30) + 1 ))"
    readonly n
    printf '%s\n' "${!n}"
  }

  req () {
    str starts "${2}" '/'

    local socket_path method endpoint
    socket_path='/var/run/docker.sock'
    method="${1}"
    endpoint="http://v1.48${2}"
    readonly socket_path method endpoint
    shift 2

    jq -n -r 'include "jq/module-color"; colored("'"${req_id}"'"; '"$(color)"') + " '"${method^^}"' '"${endpoint}"'"' >&2

    case "${method}" in
    ( 'get' ) curl -s --unix-socket "${socket_path}" -X GET "${@}" "${endpoint}" ;;
    ( 'post' ) curl -s --unix-socket "${socket_path}" -X POST "${@}" "${endpoint}" ;;
    ( 'del' ) curl -s --unix-socket "${socket_path}" -X DELETE "${@}" "${endpoint}" ;;
    ( * ) return 1 ;;
    esac
  }

  # image build utily
  decode_buildkit_protobuf () {
    base64 -d \
      | protoc --decode=moby.buildkit.v1.StatusResponse -I ./resources resources/api/services/control/control.proto
  }

  # image build utily
  protobuf2json () {
    sed '# Add double quotes for PROTOBUF message fields -> JSON keys
         s/^\(\s*\)\([^:]*\):/\1"\2":/

         # Add double quotes for PROTOBUF message types -> JSON keys
         s/^\(\s*\)\(\S*\) {/\1"\2": {/

         # Add opened and closed braces for each message type -> JSON object
         s/^"/{"/
         s/^}$/}}/

         # Append every input line to the SED hold space
         H

         # The first line overwrites the SED hold space
         1h

         # Delete every line not the last from output
         $!d

         # Switch the contents of the SED hold space and the SED pattern space
         x

         # Remove new line char when just after { char
         s/{\n\s*/{/g

         # Remove new line char when just before } char
         s/\n\s*}/}/g

         # Replace all other new line chars with commas
         s/\n\s*/,/g

         # Add opened and closed brackets as first and last characters of the final output => JSON array
         s/^/[/
         s/$/]/'
  }

  container () {
    req_id="$(( req_id + 1 ))"
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
    req_id="$(( req_id + 1 ))"
    case "${1}" in
    ( 'create' ) : ;;
    ( 'remove' ) : ;;
    ( * ) return 1 ;;
    esac
  }

  volume () {
    req_id="$(( req_id + 1 ))"
    case "${1}" in
    ( 'create' ) : ;;
    ( 'remove' ) : ;;
    ( * ) return 1 ;;
    esac
  }

  image () {
    req_id="$(( req_id + 1 ))"
    case "${1}" in
    ( 'build' )
      tar -c -f - "./dockerfiles/${2}" \
        | req post "/build?dockerfile=./dockerfiles/${2}/Dockerfile&version=2&t=lab/${2}:${version}" --data-binary @- --header 'Content-Type: application/x-tar' --no-buffer \
        | jq -r '. | if .id == "moby.buildkit.trace" then .aux else empty end' \
        | decode_buildkit_protobuf \
        | protobuf2json \
        | jq -r 'include "jq/module-color"; .[] | .vertexes, .statuses | if has("started") and has("completed") then (colored("'"${req_id}"'"; '"$(color)"') + " > image build lab.'"${2}"' > " + (. | if has("name") then .name else .ID end)) else empty end' >&2 ;;
    ( 'pull' )
      req post "/images/create?fromImage=${2}/${3}/${4}:${5}" --no-buffer \
        | jq -r 'include "jq/module-color"; colored("'"${req_id}"'"; '"$(color)"') + " > image pull '"${2}/${3}/${4}:${5}"' > " + .status + (if .progress | length > 0 then " " else "" end) + .progress'  >&2 ;;
    ( 'tag' ) req post "/images/${2}:${3}/tag?repo=${4}&tag=${5}" ;;
    ( 'remove' ) : ;;
    ( 'tagged' )
      req get '/images/json' -G --data-urlencode "filters={\"reference\":{\"${2}:${3}\":true}}" 'http://v1.48/images/json' \
        | jq -e '. | length > 0' > /dev/null ;;
    ( * ) return 1 ;;
    esac
  }

  local alpine_version
  alpine_version='3.21'
  readonly alpine_version

  if not image tagged 'alpine' "${alpine_version}"
  then
    image pull 'docker.io' 'library' 'alpine' "${alpine_version}"
  fi
  if not image tagged 'local.alpine' "${version}"
  then
    image tag 'alpine' "${alpine_version}" 'local.alpine' "${version}"
  fi

  image build 'test'
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
