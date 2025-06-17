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
  eq () { return "$(( 1 - (${1} == ${2}) ))"; }
  gt () { return "$(( 1 - (${1} > ${2}) ))"; }
  lt () { return "$(( 1 - (${1} < ${2}) ))"; }
  ge () { return "$(( 1 - (${1} >= ${2}) ))"; }
  le () { return "$(( 1 - (${1} <= ${2}) ))"; }

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
    error 'Can not find /etc/os-release'
  fi

  dist="$(. /etc/os-release && printf '%s\n' "${ID}")"
  readonly dist

  case "${dist}" in
  ( 'ubuntu'|'debian' )
    install () {
      set -- "${1%"${1##*[![:space:]]}"} " "${2}"

      while gt "${#1}" '0'
      do
        if has not "${1%% *}"
        then
          sudo apt-get update --assume-yes

          set -f
          sudo apt-get install --assume-yes ${2}
          set +f

          break
        fi
        set -- "${1#* }" "${2}"
      done
    }

    install 'base64 env mktemp sha256sum shuf tee' coreutils
    install bc bc
    install bash bash
    install curl curl
    install git git
    install gojq gojq
    install protoc protobuf-compiler
    install sed sed
    install tar tar ;;
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
  if is not present "${daemon_json}" || not gojq --exit-status --null-input --slurpfile dest "${daemon_json}" --slurpfile src "${daemon_conf}" '$dest == $src' > /dev/null
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

  tmp="$(mktemp --directory)"
  readonly tmp

  #git clone -- 'https://github.com/tiawl/placid' "${tmp}"
  cp -r ../placid/. "${tmp}"

  env --ignore-environment SDIR="${tmp}" BASH_ENV="${tmp}/src/utils.sh" bash --norc --noprofile "${tmp}/compile.sh"

  mv "${tmp}/bin/placid" ~/.local/bin/
  rm -rf "${tmp}"
)

setup "${@}"
