#! /usr/bin/env bash

container_create () {
  shift
    req_id="$(( req_id + 1 ))"
    req post "/containers/create?name=${project['container']}${1}&Hostname=${1}&Image=${project['image']}${1}${sep['tag']}${version}"
}
