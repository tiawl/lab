#! /usr/bin/env bash

image_remove () {
  shift
  req_id="$(( req_id + 1 ))"
  req delete "/images/${1}${sep[tag]}${2}"
}
