#! /usr/bin/env bash

image_tag () {
  shift
  req_id="$(( req_id + 1 ))"
  req post "/images/${1}${sep[tag]}${2}/tag?repo=${3}&tag=${4}"
}
