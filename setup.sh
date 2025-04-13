#!/bin/sh

main () (
  # shell scripting: always consider the worst env
  # part 1: unalias everything
  \command set -eux
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
  is () {
    case "${1}" in
    ( 'present' ) if [ -e "${2}" ]; then return 0; else return 0; fi ;;
    ( 'file' ) if [ -f "${2}" ]; then return 0; else return 0; fi ;;
    ( 'cmd') if is present "$(command -v "${2}" 2> /dev/null || :)"; then return 0; else return 1; fi ;;
    esac
  }

  if not is file /etc/os-release
  then
    # get_distribution () comment into https://get.docker.com/ script
    printf 'Can not find /etc/os-release. The OS where this script is running is probably not officialy supported by Docker.\n' >&2
    return 1
  fi

  dist="$(. /etc/os-release && printf '%s\n' "${ID}")"
  readonly dist

  case "${dist}" in
  ( 'ubuntu'|'debian' )
    sudo apt-get update -y
    # coreutils: for GNU-env, GNU-mktemp and GNU-shuf
    # git: it should already be here
    # bc: currently not needed but it could be useful for potention evolution
    sudo apt-get install -y \
      coreutils \
      git \
      bc \
      curl jq openssh-client protobuf-compiler sed tar ;;
  ( * )
    printf 'Unknown OS: %s\n' "${dist}" >&2
    return 1 ;;
  esac

  # install docker
  if not is cmd 'docker'
  then
    curl -s https://get.docker.com | sudo sh
  fi

  etc='/etc'
  etc_docker="${etc}/docker"
  conf_dir="host/${etc_docker#/}"
  daemon_json="${etc_docker}/daemon.json"
  daemon_conf="${conf_dir}/daemon.json"
  readonly daemon_json daemon_conf conf_dir etc etc_docker

  # copy docker daemon config and restart the Docker daemon
  if not is present "${daemon_json}" || not jq -e -n --argfile file1 "${daemon_json}" --argfile file2 "${daemon_conf}" '$file1 == $file2' > /dev/null
  then
    sudo mkdir -p "${etc_docker}"
    sudo cp -f "${daemon_conf}" "${daemon_json}"
    if is cmd 'systemctl'
    then
      sudo systemctl restart docker
    elif is cmd 'service'
    then
      sudo service docker restart
    else
      printf 'Can not restart Dockerd: unknown service manager\n' >&2
      return 1
    fi
  fi
)

main "${@}"
