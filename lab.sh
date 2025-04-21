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
  set -f
  for func in $(set)
  do
    func="${func#"${func%%[![:space:]]*}"}"
    func="${func%"${func##*[![:space:]]}"}"
    case "${func}" in
    ( *' ()' ) unset -f "${func%' ()'}" ;;
    ( * ) ;;
    esac
  done
  set +f
  IFS="${old_ifs}"

  # cleanup done: now it is time to define needed functions

  dirname () {
    local parent
    parent="${1:-.}"

    if [[ "${parent}" != *[!/]* ]]
    then
      printf '/\n'
      return
    fi

    parent="${parent%%"${parent##*[!/]}"}"

    if [[ "${parent}" != */* ]]
    then
      printf '.\n'
      return
    fi

    parent="${parent%/*}"
    parent="${parent%%"${parent##*[!/]}"}"

    printf '%s\n' "${parent:-/}"
  }

  # TODO: use sdir
  sdir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && printf '%s\n' "${PWD}")"
  readonly sdir

  source "${sdir}/sh/utils.sh"
  source "${sdir}/sh/harden.sh"

  harden base64
  #harden bc
  harden curl
  harden env
  harden git
  harden id
  harden jq
  harden mktemp
  harden protoc
  harden sed
  harden sha256sum
  #harden shuf
  harden ssh
  harden tar
  #harden tee

  global tmp uid
  tmp="$(mktemp --directory)"
  uid="$(id --user)"
  readonly tmp uid

  cleanup () {
    image builder cleanup
    rm --recursive --force "${tmp}"
  }

  trap 'cleanup' EXIT

  var set req_id 0

  global -A sep loc project version path
  global -a rainbow
  sep[image]='/'
  sep[tag]=':'
  sep[container]='.'
  loc[image]="local${sep[image]}"
  project[container]="lab${sep[container]}"
  project[image]="lab${sep[image]}"
  version[project]="$(git -C "${sdir}" describe --match *.*.* --tags --abbrev=9)"
  version[project]="${version[project]%-*}"
  version[project]="${version[project]%\.*}.${version[project]#*-}"
  version[alpine]='3.21'
  version[api]='v1.48'
  path[socket]='/var/run/docker.sock'
  rainbow=( '21' '27' '33' '39' '45' '51' '50' '49' '48' '47' '46' '82' '118' '154' '190' '226' '220' '214' '208' '202' '196' '197' '198' '199' '200' '201' '165' '129' '93' '57' )
  readonly sep loc project version

  shuffle () {
    local i array_i size max rand
    local -n array
    array="${1}"

    size="${#array[*]}"
    max="$(( 32768 / size * size ))"

    for ((i=size-1; i>0; i--))
    do
      while (( (rand="${RANDOM}") >= max )); do :; done
      rand="$(( rand % (i+1) ))"
      array_i="${array[i]}"
      array[i]="${array[rand]}"
      array[rand]="${array_i}"
    done
  }

  color () {
    set -- "${rainbow[@]}"
    local n
    var get req_id
    n="$(( ("${REPLY[req_id]}" % 30) + 1 ))"
    readonly n
    printf '%s\n' "${!n}"
  }

  shuffle rainbow

  source "${sdir}/sh/client.sh"

  if not image tag exist "${loc[image]}alpine" "${version[alpine]}"
  then
    image pull 'docker.io' 'library' 'alpine' "${version[alpine]}"
    image prune "${loc[image]}alpine${sep[tag]}*"
    image tag create 'alpine' "${version[alpine]}" "${loc[image]}alpine" "${version[alpine]}"
    image remove 'alpine' "${version[alpine]}"
  fi

  global -A buildargs
  buildargs[FROM]="${loc[image]}alpine${sep[tag]}${version[alpine]}"
  buildargs[KEY_NAME]='host2lab'
  buildargs[USER]='user'
  buildargs[SSH_HOME]="/home/${buildargs[USER]}/.ssh"
  buildargs[UID]="${uid}"
  path[BOUNCE_SSH_KEY]="${buildargs[SSH_HOME]}/${buildargs[KEY_NAME]}"
  path[SSH_HOME]="${HOME}/.ssh"
  readonly path

  image build 'bounce'
  container create 'bounce'
  container resource copy 'bounce' "${path[BOUNCE_SSH_KEY]}" "${path[SSH_HOME]}"
  container resource copy 'bounce' "${path[BOUNCE_SSH_KEY]}.pub" "${path[SSH_HOME]}"

  # docker container rm -f lab.bounce; docker image prune --all -f; docker buildx prune -f; ./lab.sh
  # docker start lab.bounce; ssh-keygen -R 172.17.0.2; ssh -i /home/user/.ssh/host2lab user@172.17.0.2
}

main "${@}"
