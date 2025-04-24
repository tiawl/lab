#! /usr/bin/env bash

image_build () {
  shift

  decode_buildkit_protobuf () {
    # TODO: use jq @base64d instead of base64 -d
    base64 --decode \
      | protoc --decode=moby.buildkit.v1.StatusResponse --proto_path="${sdir}/protobuf" "${sdir}/protobuf/api/services/control/control.proto"
  }

  local repo context buildargs_size json method tag logged_endpoint endpoint replace_me
  repo="${1}"
  context="${2}"
  buildargs_size="${3}"
  method='POST'
  replace_me='XXXXXXXXXX'
  readonly repo context buildargs_size method replace_me

  shift 3

  local -a curl_cmd
  curl_cmd=('curl' '--silent' '--fail' '--request' "${method}" '--unix-socket' "${path[docker_socket]}" '--data-binary' '@-' '--header' 'Content-Type: application/x-tar' '--no-buffer' '--write-out' "%{stderr}%{scheme} %{response_code}\n")

  json="$(jq --monochrome-output --null-input --compact-output '$ARGS.positional | [.[:$n], .[$n:]] | transpose | map({ (first): last }) | add' --argjson n "${buildargs_size}" --args "${@}")"
  endpoint="http://${version[docker_api]}/build?version=2&t=${repo}${sep[tag]}${replace_me}&buildargs="
  logged_endpoint="${endpoint}${json}"
  tag="$({
    tar --directory "${context}" --create --file=- --sort=name --mtime='UTC 2019-01-01' --group=0 --owner=0 --numeric-owner .
    printf '%s\n' "${curl_cmd[@]}" "${logged_endpoint}"
  } | sha256sum)"
  tag="${tag%% *}"
  tag="${tag:0:10}"
  logged_endpoint="${logged_endpoint/"${replace_me}"/"${tag}"}"
  endpoint="${endpoint/"${replace_me}"/"${tag}"}$(urlencode "${json}")"
  readonly tag json logged_endpoint endpoint

  if not image tag defined "${repo}" "${tag}"
  then
    image prune "${repo}${sep[tag]}*"

    printf '%s %s\n' "${method}" "${logged_endpoint//\"/\\\"}" >&2

    {
      tar --directory "${context}" --create --file=- . \
        | "${curl_cmd[@]}" "${endpoint}" 2>&4 \
        | { jq --raw-output --unbuffered '. | if (.id == "moby.buildkit.trace") then .aux elif has("errorDetail") then ("vertexes {\n  error: \"" + .errorDetail.message + "\"\n}\n" | halt_error(0)) else empty end' 2>&3 \
        | decode_buildkit_protobuf; } 3>&1 \
        | sed --unbuffered --file "${sdir}/sed/protobuf2json.sed" \
        | jq --unbuffered --raw-output --from-file "${sdir}/jq/image-build-logging.jq" --arg image "${repo}" >&2
    } 4>&1 | sed --file "${sdir}/sed/colored_http_code.sed" >&2
  fi
}
