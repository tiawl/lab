#! /bin/sh

reset () {

  # TODO: replace docker calls with placid

  containers="$(docker container ls -q --filter 'name=^lab\.' --filter 'status=exited' --filter 'status=running' --filter 'status=created')"
  if [ -n "${containers:-}" ]
  then
    set -f
    docker container rm -f ${containers}
    set +f
  fi

  networks="$(docker network ls -q --filter 'name=^lab\.')"
  if [ -n "${networks:-}" ]
  then
    set -f
    docker network rm -f ${networks}
    set +f
  fi

  # TODO: same thing for volumes or not ??

  docker image prune --all -f
  docker buildx prune -f
  ./setup.sh
  placid runner exec ./runners/lab.yml
}

reset "${@}"
