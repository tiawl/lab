#! /usr/bin/env bash

container_create () {
  shift

    declare -a json2queryparam
    json2queryparam+=("{\"Hostname\":\"${1}\",\"Image\":\"${project['image']}${1}${sep['tag']}${version}\"}")

    req_id="$(( req_id + 1 ))"
    req post "/containers/create?name=${project['container']}${1}"
}
