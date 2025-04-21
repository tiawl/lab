#! /usr/bin/env bash

image_build () {
  decode_buildkit_protobuf () {
    base64 --decode \
      | protoc --decode=moby.buildkit.v1.StatusResponse --proto_path="${sdir}/protobuf" "${sdir}/protobuf/api/services/control/control.proto"
  }

  shift
  local json repo method tag logged_endpoint endpoint replace_me
  repo="${1}"
  method='POST'
  replace_me='XXXXXXXXXX'

  local -a curl_cmd
  curl_cmd=('curl' '--silent' '--show-error' '--request' "${method}" '--unix-socket' "${path[socket]}" '--data-binary' '@-' '--header' 'Content-Type: application/x-tar' '--no-buffer')

  json="$(jq --monochrome-output --null-input --compact-output '$ARGS.positional | [.[:$n], .[$n:]] | transpose | map({ (first): last }) | add' --argjson n ${#buildargs[@]} --args "${!buildargs[@]}" "${buildargs[@]}")"
  endpoint="http://${version[api]}/build?version=2&t=${project[image]}${repo}${sep[tag]}${replace_me}&buildargs="
  logged_endpoint="${endpoint}${json}"
  tag="$({
    tar --directory "${sdir}/dockerfiles/${repo}" --create --file=- --sort=name --mtime='UTC 2019-01-01' --group=0 --owner=0 --numeric-owner .
    printf '%s\n' "${curl_cmd[@]}" "${logged_endpoint}"
  } | sha256sum)"
  tag="${tag%% *}"
  tag="${tag:0:10}"
  logged_endpoint="${logged_endpoint/"${replace_me}"/"${tag}"}"
  endpoint="${endpoint/"${replace_me}"/"${tag}"}$(urlencode "${json}")"
  readonly repo method tag json replace_me logged_endpoint endpoint

  if not image tag exist "${repo}" "${tag}"
  then
    image prune "${repo}${sep[tag]}*"

    var incr req_id
    var get req_id
    jq --null-input --raw-output 'include "jq/module-color"; reset(bold(colored("'"${REPLY[req_id]}"'"; '"$(color)"'))) + " '"${method}"' '"${logged_endpoint//\"/\\\"}"'"' >&2

    tar --directory "${sdir}/dockerfiles/${repo}" --create --file=- . \
      | "${curl_cmd[@]}" "${endpoint}" \
      | { jq --raw-output --unbuffered '. | if (.id == "moby.buildkit.trace") then .aux elif has("errorDetail") then ("vertexes {\n  error: \"" + .errorDetail.message + "\"\n}\n" | halt_error(0)) else empty end' 2>&3 \
      | decode_buildkit_protobuf; } 3>&1 \
      | sed --unbuffered --file "${sdir}/sed/protobuf2json.sed" \
      | jq --unbuffered --raw-output --from-file "${sdir}/jq/image-build-logging.jq" --arg req_id "${REPLY[req_id]}" --arg color "$(color)" --arg image "${project[image]}${repo}" >&2
  fi
}
