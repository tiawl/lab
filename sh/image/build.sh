#! /usr/bin/env bash

image_build () {
  decode_buildkit_protobuf () {
    base64 -d \
      | protoc --decode=moby.buildkit.v1.StatusResponse -I ./protobuf protobuf/api/services/control/control.proto
  }

  shift
  local dir img
  dir="${1}"
  img="${dir}:${version}"
  declare -A encode_me
  encode_me['buildargs']="{\"FROM\":\"${2}\"}"
  readonly dir img

  req_id="$(( req_id + 1 ))"
  tar -c -f - "./dockerfiles/${dir}" \
    | req post "/build?dockerfile=./dockerfiles/${dir}/Dockerfile&version=2&t=${project['image']}${img}&" --data-binary @- --header 'Content-Type: application/x-tar' --no-buffer \
    | jq -r '. | if .id == "moby.buildkit.trace" then .aux else empty end' \
    | decode_buildkit_protobuf \
    | sed -f ./sed/protobuf2json.sed \
    | jq -r -f ./jq/image-build-logging.jq --arg req_id "${req_id}" --arg color "$(color)" --arg image "${project['image']}${dir}" >&2
}
