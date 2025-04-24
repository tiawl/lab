#! /usr/bin/env bash

lab () {
  # shell scripting: always consider the worst env

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
    \command exec -c env -i BASH_ENV="$(CDPATH='' \command cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && \command printf '%s\n' "${PWD}")/src/utils.sh" bash --norc --noprofile "${BASH_SOURCE[0]}" "${@}" || \command exit 1
  fi

  # cleanup done: now it is time to define needed functions

  on errexit noclobber errtrace functrace nounset pipefail lastpipe

  global sdir old_ifs
  sdir="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && printf '%s' "${PWD}")"
  old_ifs="${IFS}"
  readonly sdir old_ifs

  source "${sdir}/src/harden.sh"

  harden env
  harden id
  #harden mktemp
  harden ssh
  harden ssh-keygen

  global usr uid home req_id
  usr="${USER:-"$(id --user --name)"}"
  uid="${UID:-"$(id --user)"}"
  home="${HOME:-"$(printf '%s' ~)"}"
  req_id='0'
  readonly usr uid home

  global -A loc project
  loc[image]="local${sep[image]}"
  project[container]="lab${sep[container]}"
  project[image]="lab${sep[image]}"
  version[alpine]='3.21'
  readonly loc project

  global -a rainbow
  rainbow=( '21' '27' '33' '39' '45' '51' '50' '49' '48' '47' '46' '82' '118' '154' '190' '226' '220' '214' '208' '202' '196' '197' '198' '199' '200' '201' '165' '129' '93' '57' )

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
    n="$(( (req_id % 30) + 1 ))"
    readonly n
    printf '%s' "${!n}"
  }

  shuffle rainbow

  orchestrator () {
    printf '%b\033[1m%s\033[0m > orchestrator %s\n' "\033[38;5;$(color)m" "$(( ++req_id ))" "${*}" >&2
    "${sdir}/orchestrator.sh" "${@}"
  }

  if not orchestrator image tag defined "${loc[image]}alpine" "${version[alpine]}"
  then
    orchestrator image pull 'docker.io' 'library' 'alpine' "${version[alpine]}"
    orchestrator image prune "${loc[image]}alpine${sep[tag]}*"
    orchestrator image tag create 'alpine' "${version[alpine]}" "${loc[image]}alpine" "${version[alpine]}"
    orchestrator image remove 'alpine' "${version[alpine]}"
  fi

  local -A buildargs
  buildargs[FROM]="${loc[image]}alpine${sep[tag]}${version[alpine]}"
  buildargs[KEY_NAME]='host2lab'
  buildargs[USER]="${usr}"
  buildargs[SSH_HOME]="/home/${buildargs[USER]}/.ssh"
  buildargs[UID]="${uid}"
  path[BOUNCE_SSH_KEY]="${buildargs[SSH_HOME]}/${buildargs[KEY_NAME]}"
  path[SSH_HOME]="${home}/.ssh"
  readonly path

  orchestrator image build "${project[image]}bounce" "${sdir}/dockerfiles/bounce" "${#buildargs[@]}" "${!buildargs[@]}" "${buildargs[@]}"
  orchestrator container create "${project[container]}bounce" "${project[image]}bounce" 'bounce'
  trap_add orchestrator image builder cleanup
  orchestrator container resource copy "${project[container]}bounce" "${path[BOUNCE_SSH_KEY]}" "${path[SSH_HOME]}"
  orchestrator container resource copy "${project[container]}bounce" "${path[BOUNCE_SSH_KEY]}.pub" "${path[SSH_HOME]}"

  orchestrator container start "${project[container]}bounce"
  trap_add orchestrator container stop "${project[container]}bounce"

  local bounce_ip
  bounce_ip="$(orchestrator network ip get "${project[container]}bounce")"
  readonly bounce_ip

  ssh_keygen -R "${bounce_ip}"
  ssh -i "${path[SSH_HOME]}/${buildargs[KEY_NAME]}" "${buildargs[USER]}@${bounce_ip}"

  # docker container rm -f lab.bounce; docker image prune --all -f; docker buildx prune -f; ./lab.sh
  
}

lab "${@}"
