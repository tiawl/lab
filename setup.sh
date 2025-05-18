#! /bin/sh

setup () (
  # shell scripting: always consider the worst env
  # part 1: unalias everything
  \command set -e -u -x
  \command unalias -a
  \command unset -f command
  command unset -f unset
  unset -f set
  unset -f readonly

  old_ifs="${IFS}"
  readonly old_ifs

  IFS='
'

  # shell scripting: always consider the worst env
  # part 2: remove already defined functions
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

  not () { ! "${@}"; }
  eq () { (( "${1}" == "${2}" )); }
  gt () { (( "${1}" > "${2}" )); }
  lt () { (( "${1}" < "${2}" )); }
  ge () { (( "${1}" >= "${2}" )); }
  le () { (( "${1}" <= "${2}" )); }

  is () {
    case "${1}" in
    ( 'not' ) shift; not is "${@}" ;;
    ( 'present' ) [ -e "${2}" ] ;;
    ( 'file' ) [ -f "${2}" ] ;;
    ( 'dir' ) [ -d "${2}" ] ;;
    ( 'socket' ) [ -S "${2}" ] ;;
    esac
  }

  can () {
    case "${1}" in
    ( 'not' ) shift; not can "${@}" ;;
    ( 'exec' ) [ -x "${2}" ] ;;
    esac
  }

  str () {
    case "${1}" in
    ( 'not' ) shift; not str "${@}" ;;
    ( 'empty' ) [ -z "${2}" ] ;;
    ( 'eq' ) [ "${2}" = "${3}" ] ;;
    esac
  }

  dirname () {
    set -- "${1:-.}"
    set -- "${1%%"${1##*[!/]}"}"

    if not str empty "${1##*/*}"
    then
      set -- '.'
    fi

    set -- "${1%/*}"
    set -- "${1%%"${1##*[!/]}"}"
    printf '%s\n' "${1:-/}"
  }

  sdir="$(CDPATH='' cd -- "$(dirname -- "${0}")" > /dev/null 2>&1; pwd)"
  readonly sdir

  has () {
    case "${1}" in
    ( 'not' ) shift; not has "${@}" ;;
    ( * ) can exec "$(command -v "${1}" 2> /dev/null || :)" ;;
    esac
  }

  if is not file /etc/os-release
  then
    # get_distribution () comment into https://get.docker.com/ script
    error 'Can not find /etc/os-release. The OS where this script is running is probably not officialy supported by Docker.'
  fi

  dist="$(. /etc/os-release && printf '%s\n' "${ID}")"
  readonly dist

  case "${dist}" in
  ( 'ubuntu'|'debian' )
    if has not base64 && \
       has not env && \
       has not mktemp && \
       has not sha256sum && \
       has not shuf && \
       has not tee && \
       has not bc && \
       has not bash && \
       has not curl && \
       has not git && \
       has not gojq && \
       has not protoc && \
       has not sed && \
       has not tar
    then
      sudo apt-get update --assume-yes

      # coreutils: GNU-base64, GNU-env, GNU-mktemp, GNU-sha256sum, GNU-shuf and GNU-tee
      # bc: currently not needed but it could be useful for potention evolution
      sudo apt-get install --assume-yes \
        coreutils \
        bc \
        bash curl git gojq protobuf-compiler sed tar
    fi ;;
  ( * ) error 'Unknown OS: %s' "${dist}" ;;
  esac

  # install docker
  if has not 'docker'
  then
    curl --silent --show-error https://get.docker.com | sudo sh
  fi

  etc='/etc'
  etc_docker="${etc}/docker"
  conf_dir="${sdir}/host/${etc_docker#/}"
  daemon_json="${etc_docker}/daemon.json"
  daemon_conf="${conf_dir}/daemon.json"
  readonly daemon_json daemon_conf conf_dir etc etc_docker

  # copy docker daemon config and restart the Docker daemon
  if is not present "${daemon_json}" || not gojq --exit-status --null-input --slurpfile file1 "${daemon_json}" --slurpfile file2 "${daemon_conf}" '$file1 == $file2' > /dev/null
  then
    sudo mkdir --parents "${etc_docker}"
    sudo cp --force "${daemon_conf}" "${daemon_json}"
    sudo systemctl restart docker
  fi

  if is not present /etc/ssh/ssh_config.d/accept-new.conf
  then
    sudo cp "${sdir}/host/etc/ssh/ssh_config.d/accept-new.conf" /etc/ssh/ssh_config.d
  fi

  # TODO: add buildkitd socket

  exec env --ignore-environment SDIR="${sdir}" BASH_ENV="${sdir}/src/utils.sh" bash --norc --noprofile "${sdir}/compile.sh"
)

setup "${@}"
