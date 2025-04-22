#! /usr/bin/env bash

main () {
  # shell scripting: always consider the worst env
  # part 1: unalias everything

  dirname () {
    \command set -- "${1:-.}"
    \command set -- "${1%%"${1##*[!/]}"}"

    [ "${1##*/*}" ] && \command set -- '.'

    \command set -- "${1%/*}"
    \command set -- "${1%%"${1##*[!/]}"}"
    \command printf '%s\n' "${1:-/}"
  }

  if [[ -z "${BASH_ENV:-}" ]]
  then
    \command exec -c env -i BASH_ENV="$(CDPATH='' \command cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && \command printf '%s\n' "${PWD}")/sh/utils.sh" bash --norc --noprofile "${BASH_SOURCE[0]}" || exit 1
  fi

  # cleanup done: now it is time to define needed functions

  on errexit noclobber errtrace functrace nounset pipefail lastpipe

  old_ifs="${IFS}"
  readonly old_ifs

  IFS=$'\n'

  # TODO: use sdir
  sdir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && printf '%s' "${PWD}")"
  readonly sdir

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

  global tmp usr uid home
  tmp="$(mktemp --directory)"
  usr="${USER:-"$(id --user --name)"}"
  uid="${UID:-"$(id --user)"}"
  home="${HOME:-"$(printf '%s' ~)"}"
  readonly tmp usr uid home

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

  source "${sdir}/sh/orchestrator.sh"

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
  buildargs[USER]="${usr}"
  buildargs[SSH_HOME]="/home/${buildargs[USER]}/.ssh"
  buildargs[UID]="${uid}"
  path[BOUNCE_SSH_KEY]="${buildargs[SSH_HOME]}/${buildargs[KEY_NAME]}"
  path[SSH_HOME]="${home}/.ssh"
  readonly path

  image build 'bounce'
  container create 'bounce'
  container resource copy 'bounce' "${path[BOUNCE_SSH_KEY]}" "${path[SSH_HOME]}"
  container resource copy 'bounce' "${path[BOUNCE_SSH_KEY]}.pub" "${path[SSH_HOME]}"

  container start 'bounce'

  local bounce_ip
  bounce_ip="$(network ip get 'bounce')"
  readonly bounce_ip

  ssh-keygen -R "${bounce_ip}"
  ssh -i "${path[SSH_HOME]}/${buildargs[KEY_NAME]}" "${buildargs[USER]}@${bounce_ip}"

  # docker container rm -f lab.bounce; docker image prune --all -f; docker buildx prune -f; ./lab.sh

  container stop 'bounce'
}

main "${@}"
