#! /usr/bin/env bash

image_tagged () {
  shift
  local tag
  tag="${1}${sep[tag]}${2}"
  readonly tag
  declare -A encode_me
  encode_me[filters]="{\"reference\":{\"${tag}\":true}}"
  req_id="$(( req_id + 1 ))"
  req get '/images/json?' \
    | jq -e '. | length > 0' > /dev/null
}
