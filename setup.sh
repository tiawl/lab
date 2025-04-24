#! /bin/sh

main () (
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

  dirname () {
    set -- "${1:-.}"
    set -- "${1%%"${1##*[!/]}"}"

    [ "${1##*/*}" ] && set -- '.'

    set -- "${1%/*}"
    set -- "${1%%"${1##*[!/]}"}"
    printf '%s\n' "${1:-/}"
  }

  sdir="$(CDPATH='' cd -- "$(dirname -- "${0}")" > /dev/null 2>&1; pwd)"
  readonly sdir

  . "${sdir}/src/utils.sh"

  if is not file /etc/os-release
  then
    # get_distribution () comment into https://get.docker.com/ script
    printf 'Can not find /etc/os-release. The OS where this script is running is probably not officialy supported by Docker.\n' >&2
    return 1
  fi

  dist="$(. /etc/os-release && printf '%s\n' "${ID}")"
  readonly dist

  case "${dist}" in
  ( 'ubuntu'|'debian' )
    sudo apt-get update --assume-yes
    # coreutils: GNU-env, GNU-mktemp, GNU-sha256sum, GNU-shuf and GNU-tee
    # bc: currently not needed but it could be useful for potention evolution
    sudo apt-get install --assume-yes \
      coreutils \
      bc \
      bash curl git jq openssh-client protobuf-compiler sed tar ;;
  ( * )
    printf 'Unknown OS: %s\n' "${dist}" >&2
    return 1 ;;
  esac

  # install docker
  if is not cmd 'docker'
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
  if is not present "${daemon_json}" || not jq --exit-status --null-input --argfile file1 "${daemon_json}" --argfile file2 "${daemon_conf}" '$file1 == $file2' > /dev/null
  then
    sudo mkdir --parents "${etc_docker}"
    sudo cp --force "${daemon_conf}" "${daemon_json}"
    sudo systemctl restart docker
  fi

  if is not present /etc/ssh/ssh_config.d/accept-new.conf
  then
    sudo cp "${sdir}/host/etc/ssh/ssh_config.d/accept-new.conf" /etc/ssh/ssh_config.d
  fi

  # TODO: add systemd buildkitd socket
)

main "${@}"
