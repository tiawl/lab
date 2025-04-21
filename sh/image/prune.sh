#! /usr/bin/env bash

image_prune () {
  shift
  local img
  set -f
  for img in $(image list "${1}")
  do
    image remove "${img%:*}" "${img#*:}"
  done
  set +f
}
