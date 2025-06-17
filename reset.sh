#! /bin/sh

reset () {
  # TODO: replace docker calls with placid
  docker container rm -f $(docker container ls -q --filter 'name=^lab\.' --filter 'status=exited' --filter 'status=running' --filter 'status=created')
  docker network rm -f $(docker network ls -q --filter 'name=^lab\.')
  # TODO: same thing for volumes or not ??
  docker image prune --all -f
  docker buildx prune -f
  ./setup.sh
  placid runner exec ./runners/lab.yml
}

reset "${@}"
