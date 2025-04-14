#! /usr/bin/env bash

image_pull () {
  shift

  local img
  img="${1}${sep[image]}${2}${sep[image]}${3}${sep[tag]}${4}"
  readonly img
  req_id="$(( req_id + 1 ))"
  req post "/images/create?fromImage=${img}" --no-buffer \
    | jq -r 'include "jq/module-color"; colored("'"${req_id}"'"; '"$(color)"') + " > image pull '"${img}"' > " + .status + (if .progress | length > 0 then " " else "" end) + .progress' >&2
}
