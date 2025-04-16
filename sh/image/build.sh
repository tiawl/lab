#! /usr/bin/env bash

image_build () {
  decode_buildkit_protobuf () {
    base64 -d \
      | protoc --decode=moby.buildkit.v1.StatusResponse -I "${sdir}/protobuf" "${sdir}/protobuf/api/services/control/control.proto"
  }

  shift
  local buildargs repo method tag logged_endpoint endpoint replace_me
  repo="${1}"
  method='POST'
  replace_me='XXXXXXXXXX'

  declare -a curl_cmd
  curl_cmd=('curl' '--silent' '--show-error' '--request' "${method}" '--unix-socket' "${path[socket]}" '--data-binary' '@-' '--header' 'Content-Type: application/x-tar' '--no-buffer')

  buildargs="{\"FROM\":\"${2}\"}"
  endpoint="http://${version[api]}/build?dockerfile=dockerfiles/${repo}/Dockerfile&version=2&t=${project[image]}${repo}${sep[tag]}${replace_me}&buildargs="
  logged_endpoint="${endpoint}${buildargs}"
  tag="$({
    tar -C "${sdir}" -c -f - --sort=name --mtime='UTC 2019-01-01' --group=0 --owner=0 --numeric-owner "dockerfiles/${repo}"
    printf '%s\n' "${curl_cmd[@]}" "${logged_endpoint}"
  } | sha256sum)"
  tag="${tag%% *}"
  tag="${tag:0:10}"
  logged_endpoint="${logged_endpoint/"${replace_me}"/"${tag}"}"
  endpoint="${endpoint/"${replace_me}"/"${tag}"}$(urlencode "${buildargs}")"
  readonly repo method tag buildargs replace_me logged_endpoint endpoint

  if not image tagged "${repo}" "${tag}"
  then
    image prune "${repo}${sep[tag]}*"

    req_id="$(( req_id + 1 ))"
    jq -n -r 'include "jq/module-color"; reset(bold(colored("'"${req_id}"'"; '"$(color)"'))) + " '"${method}"' '"${logged_endpoint//\"/\\\"}"'"' >&2

    tar -C "${sdir}" -c -f - "dockerfiles/${repo}" \
      | "${curl_cmd[@]}" "${endpoint}" \
      | { jq --raw-output --unbuffered '. | if (.id == "moby.buildkit.trace") then .aux elif has("errorDetail") then ("vertexes {\n  error: \"" + .errorDetail.message + "\"\n}\n" | halt_error(0)) else empty end' 2>&3 \
      | decode_buildkit_protobuf; } 3>&1 \
      | sed --file "${sdir}/sed/protobuf2json.sed" \
      | jq --raw-output --from-file "${sdir}/jq/image-build-logging.jq" --arg req_id "${req_id}" --arg color "$(color)" --arg image "${project[image]}${repo}" >&2
  fi
}
