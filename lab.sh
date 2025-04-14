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
    local tmp="${1:-.}"

    if [[ "${tmp}" != *[!/]* ]]
    then
      printf '/\n'
      return
    fi

    tmp="${tmp%%"${tmp##*[!/]}"}"

    if [[ "${tmp}" != */* ]]
    then
      printf '.\n'
      return
    fi

    tmp="${tmp%/*}"
    tmp="${tmp%%"${tmp##*[!/]}"}"

    printf '%s\n' "${tmp:-/}"
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
  #harden mktemp
  harden protoc
  harden sed
  harden sha256sum
  harden ssh
  harden tar

  req_id='0'
  uid="$(id -u)"
  readonly uid

  declare -A sep loc project version
  declare -a rainbow
  sep[image]='/'
  sep[tag]=':'
  sep[container]='.'
  sep[hash]='-'
  loc[image]="local${sep[image]}"
  project[container]="lab${sep[container]}"
  project[image]="lab${sep[image]}"
  version[project]="$(git -C "${sdir}" describe --match *.*.* --tags --abbrev=9)"
  version[project]="${version[project]%-*}"
  version[project]="${version[project]%\.*}.${version[project]#*-}"
  version[alpine]='3.21'
  version[api]='v1.48'
  rainbow=( '21' '27' '33' '39' '45' '51' '50' '49' '48' '47' '46' '82' '118' '154' '190' '226' '220' '214' '208' '202' '196' '197' '198' '199' '200' '201' '165' '129' '93' '57' )

  shuffle () {
    local i tmp size max rand
    declare -n array="${1}"

    size="${#array[*]}"
    max="$(( 32768 / size * size ))"

    for ((i=size-1; i>0; i--))
    do
      while (( (rand="${RANDOM}") >= max )); do :; done
      rand="$(( rand % (i+1) ))"
      tmp="${array[i]}"
      array[i]="${array[rand]}"
      array[rand]="${tmp}"
    done
  }

  color () {
    set -- "${rainbow[@]}"
    local n
    n="$(( (req_id % 30) + 1 ))"
    readonly n
    printf '%s\n' "${!n}"
  }

  shuffle rainbow

  source "${sdir}/sh/client.sh"

  if not image tagged "${loc[image]}alpine" "${version[alpine]}"
  then
    image pull 'docker.io' 'library' 'alpine' "${version[alpine]}"
    image prune "${loc[image]}alpine${sep[tag]}*"
    image tag 'alpine' "${version[alpine]}" "${loc[image]}alpine" "${version[alpine]}"
    image remove 'alpine' "${version[alpine]}"
  fi

  image build 'bounce' "${loc[image]}alpine${sep[tag]}${version[alpine]}"
  container create 'bounce'
}

main "${@}"
