#! /usr/bin/env bash

image_build () { #HELP <repository> <context> [<key> <value>] [<key> <value>] [...]\tBuild an image from a Dockerfile
  shift

  filter_docker_output () {
    gojq --join-output --raw-output '. | if (.id == "moby.buildkit.trace") then (.aux | @base64d) elif has("errorDetail") then ("vertexes {\n  error: \"" + .errorDetail.message + "\"\n}\n" | halt_error(1)) else empty end'
  }

  decode_buildkit_protobuf () {
    protoc --decode=moby.buildkit.v1.StatusResponse --descriptor_set_in=<(base64 -d <<< "${buf[descriptor_set_control]}") --proto_path=/dev/fd <(printf '%s' "${buf[vendor_control]}")
  }

  local repo context json method tag endpoint replace_me
  repo="${1}"
  context="${2}"
  method='POST'
  replace_me='XXXXXXXXXX'
  readonly repo context method replace_me

  shift 2

  local -a curl_cmd
  curl_cmd=('curl' '--silent' '--fail' '--request' "${method}" '--unix-socket' "${path[docker_socket]}" '--data-binary' '@-' '--header' 'Content-Type: application/x-tar' '--no-buffer' '--write-out' "%{stderr}%{scheme} %{response_code}\n")

  json="$(gojq --monochrome-output --null-input --compact-output '[$ARGS.positional | range(length/2|ceil) as $i | .[2 * $i:2 * $i + 2] | {(first): last}] | add' --args "${@}")"
  endpoint="http://${version[docker_api]}/build?version=2&t=${repo}${sep[tag]}${replace_me}&buildargs=$(url encode "${json}")"
  tag="$({
    tar --directory "${context}" --create --file=- --sort=name --mtime='UTC 2019-01-01' --group=0 --owner=0 --numeric-owner .
    printf '%s\n' "${curl_cmd[@]}" "${endpoint}"
  } | sha256sum)"
  tag="${tag%% *}"
  tag="${tag:0:10}"
  endpoint="${endpoint/"${replace_me}"/"${tag}"}"
  readonly tag json endpoint

  if not image tag defined "${repo}" "${tag}"
  then
    image prune "${repo}${sep[tag]}*"

    printf '%s %s\n' "${method}" "$(url decode "${endpoint}")" >&2

    local json_object http_code
    coproc HTTP_CODE { sed "${sed[colored_http_code]}"; }
    defer 'exec {HTTP_CODE[1]}>&- 4>&-; readl http_code <&${HTTP_CODE[0]}; wait "${HTTP_CODE_PID}" 2> /dev/null || :; printf "%s\n" "${http_code}" >&2'

    exec 4>&${HTTP_CODE[1]}

    tar --directory "${context}" --create --file=- . \
      | "${curl_cmd[@]}" "${endpoint}" 2>&4 \
      | while read -r json_object
        do
          printf '%s' "${json_object}" \
            | {
                filter_docker_output 2>&3 \
                  | decode_buildkit_protobuf
              } 3>&1 \
            | sed "${sed[protobuf2json]}" \
            | gojq --raw-output "${jq[image-build-logging]}" --arg image "${repo}" >&2
        done
  fi
}
