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

  source sh/utils.sh
  source sh/harden.sh

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

  source sh/client.sh

  local alpine_version
  alpine_version='3.21'
  readonly alpine_version

  image pull 'docker.io' 'library' 'alpine' "${alpine_version}"
  image tag 'alpine' "${alpine_version}"

  image build 'bounce' "${loc['image']}alpine${sep['tag']}${version}"
  container create 'bounce'
}

main "${@}"
