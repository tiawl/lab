#! /usr/bin/env bash

image_list () {
  shift
  local pattern
  pattern="${1}"
  readonly pattern
  declare -A encode_me
  encode_me[filters]="{\"reference\":{\"${pattern}\":true}}"
  req_id="$(( req_id + 1 ))"
  req get '/images/json?' \
    | jq '.[].RepoTags[]'
}
