#! /usr/bin/env bash

image_build () {
  decode_buildkit_protobuf () {
    base64 -d \
      | protoc --decode=moby.buildkit.v1.StatusResponse -I "${sdir}/protobuf" "${sdir}/protobuf/api/services/control/control.proto"
  }

  shift
  local repo tag
  repo="${1}"

  # TODO: add the curl command into the sha
  tag="$(tar -C "${sdir}" -c -f - --sort=name --mtime='UTC 2019-01-01' --group=0 --owner=0 --numeric-owner "dockerfiles/${repo}" | sha256sum)"
  tag="${tag%% *}"
  tag="${version[project]}${sep[hash]}${tag:0:10}"
  readonly repo tag

  if not image tagged "${repo}" "${tag}"
  then
    image prune "${repo}${sep[tag]}*"

    declare -A encode_me
    encode_me[buildargs]="{\"FROM\":\"${2}\"}"

    req_id="$(( req_id + 1 ))"
    tar -C "${sdir}" -c -f - "dockerfiles/${repo}" \
      | req post "/build?dockerfile=dockerfiles/${repo}/Dockerfile&version=2&t=${project[image]}${repo}${sep[tag]}${tag}&" --data-binary @- --header 'Content-Type: application/x-tar' --no-buffer \
      | jq -r '. | if .id == "moby.buildkit.trace" then .aux else empty end' \
      | decode_buildkit_protobuf \
      | sed -f "${sdir}/sed/protobuf2json.sed" \
      | jq -r -f "${sdir}/jq/image-build-logging.jq" --arg req_id "${req_id}" --arg color "$(color)" --arg image "${project[image]}${repo}" >&2
  fi
}
