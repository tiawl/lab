#! /usr/bin/env bash

main () {
  # shell scripting: always consider the worst env
  # part 1: unalias everything
  \command set -C -e -u -o pipefail
  \command unalias -a
  \command unset -f command
  command unset -f unset
  unset -f set
  unset -f local
  unset -f readonly
  unset -f shopt

  shopt -s lastpipe

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

  not () { if ! "${@}"; then return 0; else return 1; fi; }
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
  #harden bc
  harden curl
  harden env
  harden id
  harden jq
  #harden mktemp
  harden protoc
  harden sed
  harden shuf
  harden ssh
  harden tar

  req_id='0'
  rainbow="$(printf '%s\n' '21' '27' '33' '39' '45' '51' '50' '49' '48' '47' '46' '82' '118' '154' '190' '226' '220' '214' '208' '202' '196' '197' '198' '199' '200' '201' '165' '129' '93' '57' | shuf)"
  uid="$(id -u)"
  version='0.1.0'
  readonly uid version

  declare -A sep loc project encode_me
  sep['image']='/'
  sep['tag']=':'
  sep['container']='.'
  loc['image']="local${sep['image']}"
  project['container']="lab${sep['container']}"
  project['image']="lab${sep['image']}"

  color () {
    set -- ${rainbow}
    local n
    n="$(( (req_id % 30) + 1 ))"
    readonly n
    printf '%s\n' "${!n}"
  }

  encode () {
    declare -A encoded
    encoded['{']='%7B'
    encoded['}']='%7D'
    encoded[':']='%3A'
    encoded['"']='%22'
    encoded['/']='%2F'
    encoded['?']='%3F'
    encoded['&']='%26'
    encoded['=']='%3D'
    encoded['.']='%2E'

    local str char
    str="${1}"
    for char in ${!encoded[@]}
    do
      str="${str//"${char}"/"${encoded["${char}"]}"}"
    done
    printf '%s\n' "${str}"
  }

  req () {
    str starts "${2}" '/'

    local socket_path api_version method endpoint encoded_endpoint key
    socket_path='/var/run/docker.sock'
    api_version='v1.48'
    method="${1}"
    encoded_endpoint="http://${api_version}${2}"
    endpoint="${encoded_endpoint}"
    for key in ${!encode_me[@]}
    do
      encoded_endpoint="${encoded_endpoint}${key}=$(encode "${encode_me["${key}"]}")"
      endpoint="${endpoint}${key}=${encode_me["${key}"]}"
    done
    endpoint="${endpoint//\"/\\\"}"
    readonly socket_path api_version method encoded_endpoint endpoint
    shift 2
    declare -A encode_me

    jq -n -r 'include "jq/module-color"; colored("'"${req_id}"'"; '"$(color)"') + " '"${method^^}"' '"${endpoint}"'"' >&2

    case "${method}" in
    ( 'get' ) curl -s --unix-socket "${socket_path}" -X GET "${@}" "${encoded_endpoint}" ;;
    ( 'post' ) curl -s --unix-socket "${socket_path}" -X POST "${@}" "${encoded_endpoint}" ;;
    ( 'del' ) curl -s --unix-socket "${socket_path}" -X DELETE "${@}" "${encoded_endpoint}" ;;
    ( * ) return 1 ;;
    esac
  }

  container_create () {
    shift
      req_id="$(( req_id + 1 ))"
      req post "/containers/create?name=${project['container']}${1}&Hostname=${1}&Image=${project['image']}${1}${sep['tag']}${version}"
  }

  container () {
    case "${1}" in
    ( 'create' ) container_create "${@}" ;;
    ( 'start' ) printf 'TODO\n' ;;
    ( 'stop' ) : ;;
    ( 'remove' ) : ;;
    ( 'up' ) printf 'TODO\n' ;;
    ( 'down' ) : ;;
    ( 'created' ) : ;;
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

  image_build () {
    decode_buildkit_protobuf () {
      base64 -d \
        | protoc --decode=moby.buildkit.v1.StatusResponse -I ./protobuf protobuf/api/services/control/control.proto
    }

    shift
    local dir img
    dir="${1}"
    img="${dir}:${version}"
    declare -A encode_me
    encode_me['buildargs']="{\"FROM\":\"${2}\"}"
    readonly dir img

    req_id="$(( req_id + 1 ))"
    tar -c -f - "./dockerfiles/${dir}" \
      | req post "/build?dockerfile=./dockerfiles/${dir}/Dockerfile&version=2&t=${project['image']}${img}&" --data-binary @- --header 'Content-Type: application/x-tar' --no-buffer \
      | jq -r '. | if .id == "moby.buildkit.trace" then .aux else empty end' \
      | decode_buildkit_protobuf \
      | sed -f ./sed/protobuf2json.sed \
      | jq -r -f ./jq/image-build-logging.jq --arg req_id "${req_id}" --arg color "$(color)" --arg image "${project['image']}${dir}" >&2
  }

  image_pull () {
    shift
    if not image tagged "${3}" "${4}"
    then
      local img
      img="${1}/${2}/${3}:${4}"
      readonly img
      req_id="$(( req_id + 1 ))"
      req post "/images/create?fromImage=${img}" --no-buffer \
        | jq -r 'include "jq/module-color"; colored("'"${req_id}"'"; '"$(color)"') + " > image pull '"${img}"' > " + .status + (if .progress | length > 0 then " " else "" end) + .progress' >&2
    fi
  }

  image_tag () {
    shift
    local new_repo old_tag
    new_repo="${loc['image']}${1}"
    old_tag="${1}:${2}"
    readonly new_repo old_tag
    if not image tagged "${new_repo}" "${version}"
    then
      req_id="$(( req_id + 1 ))"
      req post "/images/${old_tag}/tag?repo=${new_repo}&tag=${version}"
    fi
  }

  image_tagged () {
    shift
    local tag
    tag="${1}:${2}"
    readonly tag
    declare -A encode_me
    encode_me['filters']="{\"reference\":{\"${tag}\":true}}"
    req_id="$(( req_id + 1 ))"
    req get '/images/json?' \
      | jq -e '. | length > 0' > /dev/null
  }

  image () {
    case "${1}" in
    ( 'build' ) image_build "${@}" ;;
    ( 'pull' ) image_pull "${@}" ;;
    ( 'tag' ) image_tag "${@}" ;;
    ( 'remove' ) : ;;
    ( 'tagged' ) image_tagged "${@}" ;;
    ( * ) return 1 ;;
    esac
  }

  local alpine_version
  alpine_version='3.21'
  readonly alpine_version

  image pull 'docker.io' 'library' 'alpine' "${alpine_version}"
  image tag 'alpine' "${alpine_version}"

  image build 'bounce' "${loc['image']}alpine${sep['tag']}${version}"
  container create 'bounce'
}

main "${@}"
