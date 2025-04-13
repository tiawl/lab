#! /usr/bin/env bash

image_tag () {
  shift
  local new_repo old_tag
  new_repo="${loc['image']}${1}"
  old_tag="${1}:${2}"
  readonly new_repo old_tag
  if not image tagged "${new_repo}" "${version}"
  then
    req_id="$(( req_id + 1 ))"
    req post "/images/${old_tag}/tag?repo=${new_repo}&tag=${version}"
  fi
}
